---
name: design
description: Phase 1 of go-workflow (clarifying questions → design). Investigates the repository's conventions and existing code, confirms ambiguous points with the user, then has Opus go-architect write a design doc covering alternatives, acceptance criteria, architecture, security, modern Go and the test plan. Can also be used on its own with "/go-workflow:design <task>".
argument-hint: "<task> [--run=<RUN_DIR>] [--alternatives]"
disable-model-invocation: true
---

# Phase 1: Clarifying questions → design (Plan / opus)

Input: $ARGUMENTS

> Launch subagents with the plugin namespace (for example `subagent_type: "go-workflow:go-architect"`). If the repository's `.claude/agents/` has an agent with the same role, you may prefer that one.

Scripts: `${CLAUDE_SKILL_DIR}/../../scripts/` (referred to as `SCRIPTS` below)

## Setup when run on its own

When not called from `/go-workflow:dev`:

1. Use the `--run=` value as RUN_DIR if given; otherwise create one with `bash SCRIPTS/run-dir.sh new <slug>`
2. If `RUN_DIR/context.md` does not exist, run `bash SCRIPTS/collect-context.sh "$RUN_DIR"`
3. If `RUN_DIR/exploration.md` does not exist, launch the `go-explorer` agent (haiku) to create it

## 1-a. Clarifying questions (`clarify`)

Before designing, compare `task.md` with `exploration.md` and list the **points that would require guessing**.

- Look at: ambiguous requirements, edge cases (empty, duplicates, limits, concurrency), behavior on errors, authorization scope, whether backward compatibility is needed, what is out of scope, performance requirements
- Do not ask about anything the existing code or conventions answer (look it up yourself and add it to exploration.md)
- Ask at most 4 questions together with AskUserQuestion, with the recommended option first in each
- Save the answers to `RUN_DIR/clarifications.md`. If no questions are needed, record "none" and mark `clarify` as skip

## 1-b. Design (`design`)

1. **Check for the repository's own design support**: if `context.md` lists design / ADR skills or agents (e.g. ones for writing design docs, writing ADRs, or architecture) or a design doc template (`docs/design/template.md`, etc.), pass their structure and points of view to `go-architect`
2. Launch `go-architect`. Include in the prompt:
   - `RUN_DIR`, the task (`task.md`), `clarifications.md`
   - "Read `context.md` / `exploration.md` and give the repository's conventions top priority"
   - "Adopt only features available under the go directive (listed in context.md)"
   - If web detection is true: "In the test plan, write concrete E2E scenarios to check with Playwright (happy path, error cases, permissions)"
3. With `--alternatives` (or for a large change likely to touch 15 or more files), launch **3 `go-architect` agents in parallel**, each with a given approach: "minimal change (reuse existing code as much as possible)", "clean (favor maintainability and abstraction)", "balanced (both speed and quality)". Put the key points of the results in a comparison table, have the user choose, and adopt the chosen design
4. Save the returned design doc to `RUN_DIR/design.md`
5. If the design doc's "Open questions" still has items that need the user's decision, ask with AskUserQuestion and have `go-architect` revise with the answers (you may add minor ones yourself)
6. `bash SCRIPTS/run-dir.sh phase "$RUN_DIR" design done "<one-line summary of the design>"`

When run on its own, present the key points of the design doc to the user when done, and point to "review it with `/go-workflow:design-review`".
