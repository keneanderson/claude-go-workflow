#!/usr/bin/env bash
# Manages go-workflow's artifact directory (RUN_DIR).
#   run-dir.sh new <slug>   create a new RUN_DIR and print its path
#   run-dir.sh latest       print the most recent RUN_DIR's path (exit code 1 if none)
#   run-dir.sh phase <RUN_DIR> <phase> <status> [note]
#                           record a phase's status in state.json and workflow.md
#                           status: running|done|skip|fail|waiting  (use status=iter to count an iteration)
#   run-dir.sh status [RUN_DIR]  show a summary of state.json (to decide where to resume)
# RUN_DIR is created at <repo>/.claude/go-workflow/runs/<timestamp>-<slug>/ and registered in
# .git/info/exclude, so it never shows up in the repository's diff.
set -euo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
base="$root/.claude/go-workflow/runs"

ensure_exclude() {
  local common
  common=$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 0
  local exclude="$common/info/exclude"
  mkdir -p "$(dirname "$exclude")"
  touch "$exclude"
  grep -qxF '.claude/go-workflow/runs/' "$exclude" || printf '%s\n' '.claude/go-workflow/runs/' >>"$exclude"
}

cmd=${1:-}
case "$cmd" in
  new)
    slug=$(printf '%s' "${2:-task}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40)
    [ -n "$slug" ] || slug=task
    dir="$base/$(date +%Y%m%d-%H%M%S)-$slug"
    mkdir -p "$dir/e2e"
    ensure_exclude
    {
      echo "# go-workflow run: $slug"
      echo
      echo "- started: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "- repo: $root"
      echo "- branch: $(git -C "$root" branch --show-current 2>/dev/null || echo '-')"
      echo
      echo "## Phases"
    } >"$dir/workflow.md"
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg slug "$slug" --arg started "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
        --arg branch "$(git -C "$root" branch --show-current 2>/dev/null)" \
        --arg head "$(git -C "$root" rev-parse HEAD 2>/dev/null)" '{
          slug: $slug, started: $started, branch_at_start: $branch, head_at_start: $head,
          current_phase: "context",
          phases: ([ "context","clarify","design","design-review","implement","quality","e2e","review","pr","ship" ]
                   | map({key: ., value: {status: "pending", iterations: 0, note: ""}}) | from_entries),
          options: {}
        }' >"$dir/state.json"
    fi
    printf '%s\n' "$dir" >"$base/.latest"
    printf '%s\n' "$dir"
    ;;
  phase)
    dir=${2:?RUN_DIR required}; ph=${3:?phase required}; st=${4:?status required}; note=${5:-}
    if command -v jq >/dev/null 2>&1 && [ -f "$dir/state.json" ]; then
      tmp=$(mktemp)
      jq --arg p "$ph" --arg s "$st" --arg n "$note" --arg t "$(date '+%Y-%m-%dT%H:%M:%S%z')" '
        .current_phase = $p
        | .phases[$p] = ((.phases[$p] // {status:"pending", iterations:0, note:""})
            | if $s == "iter" then .iterations += 1 | .status = "running" else .status = $s end
            | if $n != "" then .note = $n else . end
            | .updated = $t)' "$dir/state.json" >"$tmp" && mv "$tmp" "$dir/state.json"
    fi
    printf -- '- %s `%s` %s%s\n' "$(date '+%H:%M:%S')" "$ph" "$(printf '%s' "$st" | tr '[:lower:]' '[:upper:]')" "${note:+ — $note}" >>"$dir/workflow.md"
    ;;
  status)
    dir=${2:-$(bash "$0" latest)}
    [ -f "$dir/state.json" ] || { echo "no state.json in $dir" >&2; exit 1; }
    echo "RUN_DIR: $dir"
    jq -r '"current_phase: \(.current_phase)",
           (.phases | to_entries[] | "  \(.key): \(.value.status)\(if .value.iterations > 0 then " (iter \(.value.iterations))" else "" end)\(if .value.note != "" then " — \(.value.note)" else "" end)")' "$dir/state.json"
    next=$(jq -r '[.phases | to_entries[] | select(.value.status != "done" and .value.status != "skip")][0].key // "complete"' "$dir/state.json")
    echo "resume_from: $next"
    ;;
  latest)
    if [ -f "$base/.latest" ] && [ -d "$(cat "$base/.latest")" ]; then
      cat "$base/.latest"
    else
      latest=$(ls -1d "$base"/*/ 2>/dev/null | sort | tail -n 1 || true)
      [ -n "$latest" ] || { echo "no run directory under $base" >&2; exit 1; }
      printf '%s\n' "${latest%/}"
    fi
    ;;
  *)
    echo "usage: $0 new <slug> | latest | phase <RUN_DIR> <phase> <status> [note] | status [RUN_DIR]" >&2
    exit 2
    ;;
esac
