#!/usr/bin/env bash
# PostToolUse フック: Edit/Write された .go ファイルを整形する。失敗してもツール実行は妨げない。
# 無効化: .claude/go-workflow.json に {"hooks": {"formatOnEdit": false}}
# 独自コマンド: {"commands": {"formatFile": "gofumpt -w"}}（ファイルパスは末尾に付与される）
set -u

input=$(cat)
if command -v jq >/dev/null 2>&1; then
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
  file=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
fi

case "$file" in *.go) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0
head -n 5 "$file" | grep -q '^// Code generated .* DO NOT EDIT\.$' && exit 0

proj=${CLAUDE_PROJECT_DIR:-$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null || pwd)}
conf="$proj/.claude/go-workflow.json"
custom=""
if [ -f "$conf" ] && command -v jq >/dev/null 2>&1; then
  [ "$(jq -r '.hooks.formatOnEdit // true' "$conf" 2>/dev/null)" = "false" ] && exit 0
  custom=$(jq -r '.commands.formatFile // empty' "$conf" 2>/dev/null)
fi

if [ -n "$custom" ]; then
  (cd "$proj" && eval "$custom \"\$file\"") >/dev/null 2>&1
  exit 0
fi

if command -v goimports >/dev/null 2>&1; then
  goimports -w "$file" >/dev/null 2>&1
else
  gofmt -w "$file" >/dev/null 2>&1
fi
# リポジトリが gofumpt を採用している場合のみ gofumpt をかける
if command -v gofumpt >/dev/null 2>&1 && grep -qs 'gofumpt' "$proj"/.golangci.* "$proj/Makefile" 2>/dev/null; then
  gofumpt -w "$file" >/dev/null 2>&1
fi
exit 0
