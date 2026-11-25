#!/usr/bin/env bash
# 作業ツリーのスナップショット（チェックポイント）をコミットせずに保存・復元する。
# ブランチ・インデックス・作業ツリーには触れず、refs/go-workflow/<run>/<name> に保存する
# （refs/heads ではないため通常の push には含まれない）。
#
#   checkpoint.sh save <RUN_DIR> <name>      現在の作業ツリー（未追跡含む・.gitignore 対象は除外）を保存
#   checkpoint.sh list <RUN_DIR>             保存済み一覧
#   checkpoint.sh diff <RUN_DIR> <name>      チェックポイント → 現在 の差分（stat）
#   checkpoint.sh restore <RUN_DIR> <name>   作業ツリーをチェックポイントの内容に戻す（追跡ファイルのみ・新規ファイルは削除しない）
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
    # 実際のインデックスを汚さないよう一時インデックスで全体を add
    if git rev-parse --verify -q HEAD >/dev/null; then GIT_INDEX_FILE="$tmp_index" git read-tree HEAD; fi
    # RUN_DIR は .git/info/exclude 登録済みなので -A でも含まれない
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
    # 復元前の状態も自動で保存しておく（やり直し用）
    bash "$0" save "$run_dir" "before-restore-$(date +%H%M%S)" >/dev/null
    git restore --source="$prefix/$name" --worktree -- .
    echo "restored worktree to checkpoint '$name' (index and branch untouched)."
    # チェックポイントに存在しない未追跡ファイルは削除せず残しているので知らせる
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
