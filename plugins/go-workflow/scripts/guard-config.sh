#!/usr/bin/env bash
# PreToolUse フック（Edit/Write/MultiEdit）:
#  1. 既存の lint / format / CI 設定の変更 → ユーザー確認（ask）
#     エージェントがチェックを通すために設定を緩めるのを防ぎ、コード側で直させる
#  2. 理由のない //nolint の追加 → 拒否（deny）
# 無効化: .claude/go-workflow.json に {"hooks": {"protectConfig": false}}
# フック自体の不具合でツールを止めないよう、想定外の状況では何もせず exit 0（fail-open）。
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
    [ -f "$file" ] && emit ask "[go-workflow] 既存の lint/format 設定 ($base) を変更しようとしています。チェックを通すために設定を緩めるのではなく、コード側で直すのが原則です。ユーザーが設定変更を意図している場合のみ許可してください。"
    ;;
esac
case "$file" in
  */.github/workflows/*)
    [ -f "$file" ] && emit ask "[go-workflow] CI ワークフロー ($base) を変更しようとしています。タスクで合意した変更でなければ許可しないでください。"
    ;;
esac

case "$file" in
  *.go)
    # 追加されるテキスト（Write は content、Edit は new_string、MultiEdit は edits[].new_string）
    added=$(printf '%s' "$input" | jq -r '[.tool_input.content, .tool_input.new_string, (.tool_input.edits // [] | .[].new_string)] | map(select(. != null)) | join("\n")' 2>/dev/null)
    before=$(printf '%s' "$input" | jq -r '[.tool_input.old_string, (.tool_input.edits // [] | .[].old_string)] | map(select(. != null)) | join("\n")' 2>/dev/null)
    new_nolint=$(printf '%s\n' "$added" | grep -E '//[[:space:]]*nolint' || true)
    if [ -n "$new_nolint" ]; then
      # 既に存在していた nolint 行は対象外
      bad=$(printf '%s\n' "$new_nolint" | while IFS= read -r line; do
        printf '%s\n' "$before" | grep -qF -- "$line" && continue
        # //nolint:<linter> // <理由> の形式でなければ違反
        printf '%s\n' "$line" | grep -qE '//[[:space:]]*nolint:[a-zA-Z0-9_,-]+[[:space:]]*//[[:space:]]*[^[:space:]]' || printf '%s\n' "$line"
      done)
      [ -n "$bad" ] && emit deny "[go-workflow] 理由のない //nolint は追加できません。まずコードを直してください。どうしても必要なら '//nolint:<linter> // <具体的な理由>' の形式で書いてください。対象: $(printf '%s' "$bad" | head -n 1 | sed 's/^[[:space:]]*//')"
    fi
    ;;
esac
exit 0
