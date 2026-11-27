#!/usr/bin/env bash
# PreToolUse hook (Edit/Write/MultiEdit):
#  1. Changes to existing lint / format / CI configs → ask the user
#     Keeps agents from loosening configs to pass checks, so they fix the code instead
#  2. Adding //nolint without a reason → deny
# Disable: {"hooks": {"protectConfig": false}} in .claude/go-workflow.json
# So that a bug in the hook never blocks tools, it does nothing and exits 0 in unexpected situations (fail-open).
set -u

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

proj=${CLAUDE_PROJECT_DIR:-$(pwd)}
conf="$proj/.claude/go-workflow.json"
if [ -f "$conf" ] && [ "$(jq -r '.hooks.protectConfig // true' "$conf" 2>/dev/null)" = "false" ]; then
  exit 0
fi

emit() { # $1: ask|deny, $2: reason
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

base=$(basename "$file")
case "$base" in
  .golangci.yml|.golangci.yaml|.golangci.toml|.golangci.json|.editorconfig|.pre-commit-config.yaml|lefthook.yml|lefthook.yaml|.commitlintrc*|commitlint.config.*)
    [ -f "$file" ] && emit ask "[go-workflow] This edit changes an existing lint/format config ($base). The rule is to fix the code rather than loosen the config to pass checks. Allow it only if the user intends to change the config."
    ;;
esac
case "$file" in
  */.github/workflows/*)
    [ -f "$file" ] && emit ask "[go-workflow] This edit changes a CI workflow ($base). Do not allow it unless the change was agreed on for this task."
    ;;
esac

case "$file" in
  *.go)
    # Text being added (content for Write, new_string for Edit, edits[].new_string for MultiEdit)
    added=$(printf '%s' "$input" | jq -r '[.tool_input.content, .tool_input.new_string, (.tool_input.edits // [] | .[].new_string)] | map(select(. != null)) | join("\n")' 2>/dev/null)
    before=$(printf '%s' "$input" | jq -r '[.tool_input.old_string, (.tool_input.edits // [] | .[].old_string)] | map(select(. != null)) | join("\n")' 2>/dev/null)
    new_nolint=$(printf '%s\n' "$added" | grep -E '//[[:space:]]*nolint' || true)
    if [ -n "$new_nolint" ]; then
      # Skip nolint lines that already existed
      bad=$(printf '%s\n' "$new_nolint" | while IFS= read -r line; do
        printf '%s\n' "$before" | grep -qF -- "$line" && continue
        # Violation unless it has the form //nolint:<linter> // <reason>
        printf '%s\n' "$line" | grep -qE '//[[:space:]]*nolint:[a-zA-Z0-9_,-]+[[:space:]]*//[[:space:]]*[^[:space:]]' || printf '%s\n' "$line"
      done)
      [ -n "$bad" ] && emit deny "[go-workflow] A //nolint without a reason cannot be added. Fix the code first. If it is truly needed, write it as '//nolint:<linter> // <specific reason>'. Line: $(printf '%s' "$bad" | head -n 1 | sed 's/^[[:space:]]*//')"
    fi
    ;;
esac
exit 0
