---
name: review
description: Phase 6 of go-workflow (implementation review loop). Runs Sonnet go-code-reviewer and go-security-reviewer (plus the repository's own review agents) in parallel, keeps only high-confidence findings, verifies Critical/High findings with Opus go-finding-verifier, then fixes with go-implementer → re-runs quality → re-reviews, up to 3 times. Can also be used on its own with "/go-workflow:review" on the current diff.
argument-hint: "[--run=<RUN_DIR>] [--base=<ref>] [--max-review=3]"
disable-model-invocation: true
---

# Phase 6: Implementation review ⇄ fix loop (sonnet + opus verification)

Input: $ARGUMENTS

> Launch subagents with the plugin namespace (for example `subagent_type: "go-workflow:go-code-reviewer"`). If the repository's `.claude/agents/` has an agent with the same role, you may prefer that one.

Scripts: `${CLAUDE_SKILL_DIR}/../../scripts/` (referred to as `SCRIPTS` below)
RUN_DIR: the `--run=` value, otherwise `bash SCRIPTS/run-dir.sh latest` (if none exists, create one with `new review` and run `collect-context.sh`).
Base: the `--base=` value, otherwise `default_branch` from `context.md` (`origin/<default_branch>` if it exists).

## Why the limit is 3 rounds by default

- Round 1 surfaces most findings, and round 2 confirms the fixes and catches regressions they caused. Round 3 confirms convergence
- Beyond that, reviewers tend to keep raising minor findings and the diff bloats (churn), which is not worth the cost
- Critical/High findings still left after 3 rounds are likely design-level problems, so the decision goes back to a human
- Fixing false positives over and over is the biggest cause of churn, so **a verification step comes before any fix**

## One iteration (n = 1..limit)

1. `bash SCRIPTS/run-dir.sh phase "$RUN_DIR" review iter "round <n>"`
2. Launch the following **in parallel in the same message**:
   - `go-code-reviewer` (RUN_DIR, n, base, the previous `review-<n-1>.md`). For n ≥ 2, pass `git diff refs/go-workflow/<run>/pre-review-fix-<n-1>` as a re-review of **only the fix diff** (it looks only at whether previous findings are ADDRESSED / NOT ADDRESSED and at new breakage in the fix diff; out-of-scope observations are only noted and do not extend the loop)
   - `go-security-reviewer` (RUN_DIR, mode `code`, n, base). For n ≥ 2 it may be skipped if the previous round had 0 security findings and the fixes did not touch security-related code
   - **The repository's own review agents / skills** detected in `context.md` (those with review / reviewer in the name, etc.)
3. **Filter**: drop findings with confidence below 80, pre-existing issues (outside the diff), and kinds of findings a linter can detect (do not list them in the PR body as reference either)
4. **Verify**: for the remaining Critical / High findings (security included), launch `go-finding-verifier` **in parallel, one per finding** (up to 5 per message; if there are many, group related findings together). REJECTED becomes "Won't fix (false positive per verification)", and for UNCERTAIN, ask the user to decide
5. Save the merged result to `RUN_DIR/review-<n>.md` (and security to `security-<n>.md`). Mark each finding "Adopted / Deferred / Won't fix" with a reason
6. **Triage**:
   - CONFIRMED Critical / High: always fix
   - Medium: fix as a rule. Those that need design changes or are out of scope are recorded as Deferred with a reason
   - Low / Nit: only those that are cheap to fix. The rest go to "Remaining work" in the PR body
7. Nothing to fix → finish with `bash SCRIPTS/run-dir.sh phase "$RUN_DIR" review done "<count by severity over the rounds>"`
8. `bash SCRIPTS/checkpoint.sh save "$RUN_DIR" pre-review-fix-<n>` → fix with `go-implementer` (mode `fix-review`, with the list of finding IDs and the finding text as is) → re-check with the Phase 4 (quality) procedure
   - From round 2 on, if possible, ask the previous go-implementer to continue via SendMessage (it can fix with its context intact). If that is not available, launch a new one with `implement.md` and the previous fix report
   - In the **final round** (n = limit), if the same finding is still NOT ADDRESSED, launch a fresh `go-implementer` with `model: opus` and hand over with "the previous implementer tried to fix this N times; the history is in review-*.md and implement.md" (the same implementer often cannot see its own problem)
   - If the fix report lacks "the command and output of the relevant tests", have go-implementer add them before re-reviewing
9. If a fix makes quality / tests worse and cannot be undone, roll back with `checkpoint.sh restore "$RUN_DIR" pre-review-fix-<n>` and try a different fix
10. If the fix affects web behavior, re-check only the relevant scenarios from Phase 5
11. n += 1

If CONFIRMED Critical / High findings remain when the limit is reached, present the remaining items, the options and your recommendation, and ask with AskUserQuestion ("Go back to design" / "Open the PR as is (listing the remaining items)" / "Handle manually").
