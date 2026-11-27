---
name: implement
description: Phase 3 of go-workflow (implementation). Has Sonnet go-implementer implement the approved design.md's implementation steps in thin vertical slices. Tests are written first and confirmed to fail before implementing, and a checkpoint is saved for each batch. Can also be used on its own with "/go-workflow:implement".
argument-hint: "[--run=<RUN_DIR>] [--steps=1-3]"
disable-model-invocation: true
---

# Phase 3: Implementation (sonnet)

Input: $ARGUMENTS

> Launch subagents with the plugin namespace (for example `subagent_type: "go-workflow:go-implementer"`). If the repository's `.claude/agents/` has an agent with the same role, you may prefer that one.

Scripts: `${CLAUDE_SKILL_DIR}/../../scripts/` (referred to as `SCRIPTS` below)
RUN_DIR: the `--run=` value, otherwise `bash SCRIPTS/run-dir.sh latest`. If there is no `design.md`, or `design-review` in `state.json` is not done, confirm with the user before proceeding.

## Procedure

1. Split the "Implementation steps" in `design.md` into **batches**
   - Prefer vertical slices (take one behavior through types → logic → handler → tests) and avoid horizontal layer-by-layer slices
   - Guideline: one batch ≈ 10 changed files, and the build and tests pass at the end of each batch
   - A small task can be a single batch
2. For each batch, **in order** (not in parallel, since batches may touch the same files):
   1. `bash SCRIPTS/checkpoint.sh save "$RUN_DIR" pre-implement-<n>`
   2. `bash SCRIPTS/run-dir.sh phase "$RUN_DIR" implement iter "batch <n>: <step numbers>"`
   3. Launch `go-implementer`. Prompt:
      - `RUN_DIR`, mode `implement`, the assigned step numbers and their acceptance criteria
      - "Follow the repository conventions in context.md / exploration.md and design.md. Report any deviation from the design"
      - "For new behavior or a bug fix, write the test first and **confirm it fails (RED)** before implementing"
      - A summary of the previous batches' results (changed files, exported types/functions)
   4. Append the report to `RUN_DIR/implement.md` and respond according to `STATUS:` (see the common rules in the dev skill). Even on DONE, confirm with `git diff --stat` that files actually changed, and run `go build ./... && go test ./<changed packages>/...` yourself
      - If the same batch is BLOCKED / fails twice in a row, launch a fresh `go-implementer` with `model: opus`, tell it "the previous implementer tried N times; the history is in implement.md", and hand the work over
   5. If a "deviation from the design" is significant (changes to a public API, the DB schema or the security policy), confirm with the user before continuing. If the implementation breaks down, roll back with `checkpoint.sh restore` and start over
3. If code generation is involved (`go generate`, sqlc, mockgen, wire, buf, templ), check that the generated code was regenerated with the repository's commands after the sources changed
4. `bash SCRIPTS/run-dir.sh phase "$RUN_DIR" implement done "<number of changed files>, deviations: <none|yes>"`

If the repository has its own implementation agent / skill (e.g. a skill that collects Go coding conventions), name it in the prompt to `go-implementer` and say "also follow that skill's conventions".
