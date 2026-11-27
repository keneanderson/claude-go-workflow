---
name: go-conventions
description: How to write modern Go (new features by version and a replacement table), a Go security checklist, and architecture guidelines. Refer to it when designing, implementing or reviewing Go code, and when asked to "modernize this", "use the latest Go idioms" or "look at it from a security angle". The repository's CLAUDE.md / AGENTS.md / rules always take precedence.
---

# Go Conventions (general guidelines)

This skill provides **defaults that fill the gaps where the repository has no conventions of its own**. The priority is always:

1. The repository's `CLAUDE.md` / `AGENTS.md` / `.claude/rules/**` / ADRs / `CONTRIBUTING.md`
2. Existing patterns in the repository
3. This skill

## Reference files

- [modern-go.md](${CLAUDE_SKILL_DIR}/modern-go.md) — new features by Go version, an "old → new" replacement table, and how to use `go fix` (modernize)
- [security.md](${CLAUDE_SKILL_DIR}/security.md) — Go security checklist
- [architecture.md](${CLAUDE_SKILL_DIR}/architecture.md) — guidelines for package design, layers, errors and tests
- [definition-of-done.md](${CLAUDE_SKILL_DIR}/definition-of-done.md) — the definition of done to check before every PR
- [pitfalls.md](${CLAUDE_SKILL_DIR}/pitfalls.md) — Go pitfalls linters rarely catch (patterns to flag in review)

## Most important rules

- The available features are determined by **the `go` directive in `go.mod`** (not the installed Go). Always check it before using a new feature
- Write new code in the modern style. Bulk-modernizing existing code bloats the diff, so limit it to the task's scope (changed files and functions). Applying it to everything needs the user's agreement and a separate PR
- Do not guess at uncertain APIs; check them with `go doc <pkg>.<Symbol>`
- To understand code, prefer the gopls MCP if available (`go_workspace` / `go_search` / `go_file_context` / `go_package_api` / `go_symbol_references` / `go_diagnostics` / `go_vulncheck`; tool names look like `mcp__plugin_go-workflow_gopls__*`): check the impact with `go_symbol_references` before editing, and check for build errors with `go_diagnostics` after editing
