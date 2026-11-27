---
name: pr
description: Phase 7 of go-workflow. Has go-pr-writer (sonnet) write the PR title and body (summary, changes, impact, design decisions, security, tests, Playwright check, review results, deploy/rollback, etc.) and saves it to pr.md. Prefers the repository's PR template and conventions. Can also be used on its own with "/go-workflow:pr".
argument-hint: "[--run=<RUN_DIR>] [--base=<ref>]"
disable-model-invocation: true
---

# Phase 7: Writing the PR title and body (sonnet)

Input: $ARGUMENTS

> Launch subagents with the plugin namespace (for example `subagent_type: "go-workflow:go-architect"`). If the repository's `.claude/agents/` has an agent with the same role, you may prefer that one.

RUN_DIR: the `--run=` value, otherwise `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh latest` (if none exists, create one with `new pr` and run `collect-context.sh`).

## Why this model

Besides summarizing the diff, the PR body needs judgment about "impact" and "compatibility", so it uses sonnet rather than haiku. With the design doc and review results in hand, opus is not needed.

## Procedure

0. **Re-run verification (gather evidence)**: do not reuse earlier results; re-run in check mode (no auto-fix) right before the PR. build / vet / test cover everything, while format / modernize / lint cover this diff
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/quality.sh" --base origin/<default_branch> --log "$RUN_DIR/verify.log"
   ```
   On `QUALITY: FAIL`, do not create the PR; go back to Phase 4. If `go fix -diff` has suggestions (WARN) inside this diff, fix them. The "Tests" and "Coverage" in the PR body are based on this `verify.log`
0-b. **Check the Definition of Done**: if the repository has a DoD (`docs/definition-of-done.md`, a checklist in CONTRIBUTING), use it; otherwise use `${CLAUDE_SKILL_DIR}/../go-conventions/definition-of-done.md` (in either case, add the `dod` array in `.claude/go-workflow.json` as extra items). Check each item against the RUN_DIR artifacts and the actual diff, and write ✅ / ❌ / N/A with evidence to `RUN_DIR/dod.md`. If a ❌ can be fixed, fix it now (re-run Phase 4); state those that cannot in the PR body
1. Launch `go-pr-writer` (RUN_DIR, base branch). When run on its own without design.md and the like, tell it to "write it from the diff only, and put 'TODO' for anything unknown"
2. Take lines 1–3 of the reply (`TITLE:` / `COMMIT:` / `BRANCH:`), and save the body to `RUN_DIR/pr.md` and the metadata to `RUN_DIR/pr-meta.txt`
3. Verify it yourself:
   - Do the "Tests" and "Behavior check" sections match the actual results in `quality.log` / `e2e.md` (nothing not run is described as done)?
   - Does it contain no secrets, internal URLs or personal information?
4. Show the title and the beginning of the body to the user (link to `RUN_DIR/pr.md` for the full text)
5. `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh phase "$RUN_DIR" pr done "<title>"`
