---
name: quality
description: Phase 4 of go-workflow. Runs format → modernize (go fix) → go mod tidy → build → vet → golangci-lint → test (-race, coverage) → govulncheck, has go-build-resolver fix failures with minimal changes, and re-runs up to 3 times. Prefers the repository's Makefile / Taskfile / .claude/go-workflow.json commands. Can also be used on its own with "/go-workflow:quality".
argument-hint: "[--run=<RUN_DIR>] [--no-fix] [--all]"
disable-model-invocation: true
---

# Phase 4: lint / format / test / modernize

Input: $ARGUMENTS

> Launch subagents with the plugin namespace (for example `subagent_type: "go-workflow:go-architect"`). If the repository's `.claude/agents/` has an agent with the same role, you may prefer that one.

RUN_DIR: the `--run=` value, otherwise `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh latest` (create one with `new quality` if none exists).

## Script

```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/quality.sh" --fix --log "$RUN_DIR/quality.log"
```

- `--fix`: run format and modernize in auto-fix mode (the default; omit it when `--no-fix` is given, which means check only)
- `--base <ref>`: limit golangci-lint to the diff with `--new-from-rev` (so the result is not buried under many existing warnings; pass the base branch by default)
- `--all`: drop the diff limit and target everything
- Command resolution order: `commands.*` in `.claude/go-workflow.json` → a Makefile / Taskfile target of the same name → the default command
- The last line is `QUALITY: PASS` / `QUALITY: FAIL (<failed steps>)`, with exit code 1 on failure
- Step results: `PASS` / `FAIL` (needs fixing) / `WARN` (modernize has suggestions in check mode) / `SKIP` (tool not installed or disabled in settings) / `ENV` (an environment mismatch, such as golangci-lint built with an older Go)
- `SKIP` and `ENV` do not stop the gate, but **always report them to the user and show the remedy command the script printed (reinstall, etc.)**. Also list them as "not run" in the PR body

If `.claude/go-workflow.json` does not exist, use `default_branch` from `context.md` as the base branch and run with `--base origin/<default_branch>`.

## Scope of modernize

With `--fix`, `go fix` (Go 1.26+) / modernize is applied **only to the changed packages** (the script works out the target packages from `git diff`). Modernizing the whole repository bloats the diff, so if it is needed, get the user's agreement and do it in a separate PR.

## Coverage

With `--log`, tests run with `-coverprofile=<RUN_DIR>/coverage.out`, and the `## Coverage` section at the end of the log shows statement coverage overall and **per changed package** (not available when the Makefile's test target is used).
If coverage of the changed packages is extremely low (roughly below 60%, or below the repository's threshold), treat it as missing tests and either ask go-implementer to add tests or explain why in the PR body.

## Procedure (up to 3 times)

1. Run `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh phase "$RUN_DIR" quality iter`, then run the script
2. `QUALITY: PASS` → check the diff produced by auto-fix (`git diff --stat`), record it with `run-dir.sh phase ... quality done "<summary, coverage>"`, and finish
3. `QUALITY: FAIL` → launch `go-build-resolver` (pass RUN_DIR and the failed step names; it fixes with minimal changes, and loosening configs, deleting tests and `//nolint` without a reason are forbidden) → re-run. If it is a logic error that needs a design decision, hand it to `go-implementer` (mode `fix-quality`)
4. If it still fails after 3 times, stop and report the failures and likely causes to the user
   - If you judge that a failure comes from existing code (lint warnings or flaky tests unrelated to this diff), show the evidence (e.g. it also fails before `git stash`) and ask the user whether to continue

If the repository has its own lint / test skills or pre-commit / lefthook settings, run them too and append the results to `quality.log`.
