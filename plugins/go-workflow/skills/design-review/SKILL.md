---
name: design-review
description: Phase 2 of go-workflow (design review). Runs Opus go-design-reviewer and go-security-reviewer in parallel, has go-architect revise the design if there are Blocker/Major findings (up to 2 rounds), and finally gets user approval. Can also be used on its own with "/go-workflow:design-review".
argument-hint: "[--run=<RUN_DIR>]"
disable-model-invocation: true
---

# Phase 2: Design review → user approval

Input: $ARGUMENTS

> Launch subagents with the plugin namespace (for example `subagent_type: "go-workflow:go-architect"`). If the repository's `.claude/agents/` has an agent with the same role, you may prefer that one.

RUN_DIR: the `--run=` value, otherwise `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh latest`. If there is no `design.md`, stop and point to `/go-workflow:design`.

## Why this model

Design mistakes propagate to every later phase and cost the most to fix. The design doc, on the other hand, is short, so the token cost of reviewing it is small.
So **the design review uses opus** (the same model as the designer, but verifying independently in a separate context with a different role). Security is checked in parallel by a dedicated sonnet agent.

## Procedure (up to 2 rounds)

1. Launch the following **in parallel in the same message**:
   - `go-design-reviewer` (RUN_DIR, task)
   - `go-security-reviewer` (RUN_DIR, mode `design`, round number)
   - If the repository has a design-review agent / skill (see `context.md`), run it in parallel too
2. Merge the results into `RUN_DIR/design-review.md` (round 2 goes to `design-review-2.md`). Number every finding
3. Decide:
   - **0** Blocker / Major / security Critical or High findings → go to the approval step
   - 1 or more → ask `go-architect` to "read design.md and design-review.md and revise the design to address the Blocker/Major findings. Adopt Minor findings if reasonable; if you do not, write the reason in the revision history", overwrite `design.md` → round 2
   - Still remaining after round 2 → present the remaining findings and both sides to the user and ask them to decide
4. **User approval (required)**: present the key points of the design doc (goal, changed files, key design decisions, security measures, test plan, open questions) in about 15 lines, and ask with AskUserQuestion:
   - "Approve and implement (recommended)" (if `--alternatives` produced several designs, the user also picks one here)
   - "Request changes" → take the instructions, have go-architect revise, and start again from step 1
   - "Cancel"
5. `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh phase "$RUN_DIR" design-review done "<rounds, number of findings, approval>"` (use `iter` at the start of each round, and `waiting` while waiting for approval)

In Plan mode, step 4 is replaced by ExitPlanMode (presenting the key points of the design doc as the plan).
