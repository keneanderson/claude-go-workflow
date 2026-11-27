#!/usr/bin/env bash
# Saves and restores snapshots (checkpoints) of the working tree without committing.
# It never touches the branch, index or working tree, and saves to refs/go-workflow/<run>/<name>
# (not under refs/heads, so a normal push does not include them).
#
#   checkpoint.sh save <RUN_DIR> <name>      save the current working tree (including untracked files, excluding .gitignore'd ones)
#   checkpoint.sh list <RUN_DIR>             list saved checkpoints
#   checkpoint.sh diff <RUN_DIR> <name>      diff from the checkpoint to now (stat)
#   checkpoint.sh restore <RUN_DIR> <name>   restore the working tree to the checkpoint (tracked files only; new files are not deleted)
set -euo pipefail

cmd=${1:-}; run_dir=${2:-}; name=${3:-}
[ -n "$cmd" ] && [ -n "$run_dir" ] || { sed -n '2,10p' "$0" >&2; exit 2; }
root=$(git rev-parse --show-toplevel)
cd "$root"
run=$(basename "$run_dir")
prefix="refs/go-workflow/$run"

case "$cmd" in
  save)
    [ -n "$name" ] || { echo "name required" >&2; exit 2; }
    tmp_dir=$(mktemp -d)
    tmp_index="$tmp_dir/index"
    trap 'rm -rf "$tmp_dir"' EXIT
    # Add everything to a temporary index so the real index stays untouched
    if git rev-parse --verify -q HEAD >/dev/null; then GIT_INDEX_FILE="$tmp_index" git read-tree HEAD; fi
    # RUN_DIR is already in .git/info/exclude, so -A does not include it
    GIT_INDEX_FILE="$tmp_index" git add -A -- .
    tree=$(GIT_INDEX_FILE="$tmp_index" git write-tree)
    parent=()
    git rev-parse --verify -q HEAD >/dev/null && parent=(-p HEAD)
    commit=$(git commit-tree "$tree" ${parent[@]+"${parent[@]}"} -m "go-workflow checkpoint: $name")
    git update-ref "$prefix/$name" "$commit"
    printf '%s %s\n' "$name" "$commit" | tee -a "$run_dir/checkpoints.txt"
    ;;
  list)
    git for-each-ref --format='%(refname:lstrip=3) %(objectname:short) %(creatordate:iso)' "$prefix/" ;;
  diff)
    git diff --stat "$prefix/$name" ;;
  restore)
    [ -n "$name" ] || { echo "name required" >&2; exit 2; }
    git rev-parse --verify -q "$prefix/$name" >/dev/null || { echo "no checkpoint: $name" >&2; exit 1; }
    # Also save the pre-restore state automatically (so the restore can be undone)
    bash "$0" save "$run_dir" "before-restore-$(date +%H%M%S)" >/dev/null
    git restore --source="$prefix/$name" --worktree -- .
    echo "restored worktree to checkpoint '$name' (index and branch untouched)."
    # Untracked files absent from the checkpoint are kept, not deleted, so report them
    snap=$(git ls-tree -r --name-only "$prefix/$name")
    extra=$(git ls-files --others --exclude-standard | while IFS= read -r f; do
      printf '%s\n' "$snap" | grep -qxF -- "$f" || printf '  %s\n' "$f"
    done)
    if [ -n "$extra" ]; then
      echo "untracked files created after the checkpoint were kept (delete them manually if unneeded):"
      printf '%s\n' "$extra"
    fi
    ;;
  *) echo "unknown command: $cmd" >&2; exit 2 ;;
esac
