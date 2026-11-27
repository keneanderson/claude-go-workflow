#!/usr/bin/env bash
# Wrapper that starts the gopls MCP server (`gopls mcp`).
# Looks for gopls in PATH, GOBIN, then GOPATH/bin. If none is found, it does not download one;
# it prints install instructions to stderr and exits (the MCP shows as failed and agents fall back to git grep and the like).
for bin in "$(command -v gopls 2>/dev/null)" "$(go env GOBIN 2>/dev/null)/gopls" "$(go env GOPATH 2>/dev/null)/bin/gopls" "$HOME/go/bin/gopls"; do
  if [ -n "$bin" ] && [ -x "$bin" ] && "$bin" mcp -help >/dev/null 2>&1; then
    exec "$bin" mcp
  fi
done
echo "go-workflow: gopls (with 'mcp' support, v0.20+) not found. install: go install golang.org/x/tools/gopls@latest" >&2
exit 1
