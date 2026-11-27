---
name: e2e
description: Phase 5 of go-workflow (web only). Starts the app, uses the Playwright MCP to walk through the design doc's E2E scenarios (happy path, error cases, permissions) in a browser, and records them with screenshots in e2e.md. Failures are fixed by go-implementer and re-checked from Phase 4. Can also be used on its own with "/go-workflow:e2e".
argument-hint: "[--run=<RUN_DIR>] [--url=http://localhost:8080]"
disable-model-invocation: true
---

# Phase 5: Behavior check with Playwright

Input: $ARGUMENTS

> Launch subagents with the plugin namespace (for example `subagent_type: "go-workflow:go-architect"`). If the repository's `.claude/agents/` has an agent with the same role, you may prefer that one.

RUN_DIR: the `--run=` value, otherwise `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh latest`.

## Whether to run

SKIP in any of these cases, and record it with `run-dir.sh phase "$RUN_DIR" e2e skip "<reason>"`:
- `--no-e2e` was given
- `web: false` in `context.md`
- The diff (`git diff --name-only <base>...` plus uncommitted changes) does not touch HTTP handlers / routing / middleware / templates / static files / frontend / API schemas

## Deciding how to start the app

In priority order:
1. The `--url=` argument
2. `web.startCommand` / `web.baseURL` / `web.healthcheck` / `web.env` in `.claude/go-workflow.json`
3. Inferred: Makefile `run` / `dev` / `serve` targets, `compose.yaml` / `docker-compose.yml`, `air.toml`, the listen address in `cmd/*/main.go`, the startup steps in the README

If you are not confident in the inference (dependent services such as a DB are needed, or there are several candidates), ask with AskUserQuestion and offer to save the answer to `.claude/go-workflow.json` (save only after the user agrees).

## Checking the Playwright MCP

This plugin bundles the Playwright MCP (`@playwright/mcp`) via `.mcp.json`. If the tools are not found, search for `playwright browser` with ToolSearch before deciding; if they are still missing, tell the user how to enable it with `/mcp`, do only API-level checks (curl), and treat the phase as SKIP.

## Procedure (up to 2 times)

1. Launch `go-e2e-tester` (RUN_DIR, startup information, the scenarios in design.md; screenshots go to `RUN_DIR/e2e/`)
2. Save the result to `RUN_DIR/e2e.md`
3. PASS → done. FAIL → if the failure is caused by the implementation, fix it with `go-implementer` (mode `fix-e2e`) → Phase 4 (quality) → this phase again. If it is caused by the test scenario or the environment, report to the user
4. If it is not resolved after 2 times, ask the user to decide
5. Make sure no server you started is left running (`lsof -i :<port>`)
6. `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh phase "$RUN_DIR" e2e done|skip|fail "<number of scenarios and result, or the SKIP reason>"`
