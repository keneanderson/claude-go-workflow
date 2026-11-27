# Definition of Done (default)

The "definition of done" applied to every change by the same standard every time. While each task's **acceptance criteria** (design.md) ask "did we build the right thing?", the DoD asks "is the quality good enough to call it done?". A change is done only when it satisfies both.
If the repository has its own DoD (`docs/definition-of-done.md`, a checklist in CONTRIBUTING, `dod` in `.claude/go-workflow.json`), that takes precedence.

## Correctness
- [ ] All acceptance criteria in design.md are met
- [ ] Verified at runtime (not just that it compiles; the behavior was checked with tests, E2E or a local run)
- [ ] New behavior has tests that fail without the change and pass with it
- [ ] All existing tests pass (`go test -race`)
- [ ] Error cases and boundary values are handled

## Quality
- [ ] format / vet / lint / modernize PASS (reasons stated for any SKIP or ENV)
- [ ] No `//nolint` without a reason, debug output, commented-out code or abandoned TODOs
- [ ] The change stays within the task's scope (no unrelated refactoring)
- [ ] 0 CONFIRMED Critical / High findings in the implementation review

## Integration
- [ ] Added DB migrations, settings, environment variables and feature flags are in place, with steps documented
- [ ] Backward compatibility of public APIs, JSON and DB schemas was checked (breaking changes are stated)
- [ ] Generated code is up to date (matches its sources)

## Documentation
- [ ] Doc comments on exported identifiers
- [ ] Checked whether the README / API docs / CHANGELOG need updates
- [ ] Design decisions worth keeping are recorded in an ADR or similar (if the repository uses ADRs)

## Release readiness
- [ ] The security review PASSes (including govulncheck)
- [ ] New important paths have logs, metrics and traces
- [ ] The rollback method is clear
- [ ] The PR is created on the assumption that a human (the user) reviews it before merging
