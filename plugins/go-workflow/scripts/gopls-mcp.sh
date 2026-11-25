#!/usr/bin/env bash
# gopls の MCP サーバー（`gopls mcp`）を起動するラッパー。
# PATH / GOBIN / GOPATH/bin の順に gopls を探す。見つからなければ自動ダウンロードはせず、
# 導入方法を stderr に出して終了する（MCP は失敗表示になり、エージェントは git grep 等にフォールバックする）。
for bin in "$(command -v gopls 2>/dev/null)" "$(go env GOBIN 2>/dev/null)/gopls" "$(go env GOPATH 2>/dev/null)/bin/gopls" "$HOME/go/bin/gopls"; do
  if [ -n "$bin" ] && [ -x "$bin" ] && "$bin" mcp -help >/dev/null 2>&1; then
    exec "$bin" mcp
  fi
done
echo "go-workflow: gopls (with 'mcp' support, v0.20+) not found. install: go install golang.org/x/tools/gopls@latest" >&2
exit 1
