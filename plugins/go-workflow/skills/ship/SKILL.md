---
name: ship
description: Phase 8 of go-workflow (git operations). Generates the commands for creating the branch, staging, committing, pushing and gh pr create, and runs them according to the mode (ask = confirm then run / run = run / print = show commands only). Can also be used on its own with "/go-workflow:ship".
argument-hint: "[--run=<RUN_DIR>] [--git=ask|run|print] [--draft]"
disable-model-invocation: true
---

# Phase 8: git operations

Input: $ARGUMENTS

> Launch subagents with the plugin namespace (for example `subagent_type: "go-workflow:go-architect"`). If the repository's `.claude/agents/` has an agent with the same role, you may prefer that one.

RUN_DIR: the `--run=` value, otherwise `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh latest`. If `pr.md` / `pr-meta.txt` do not exist, run the `/go-workflow:pr` procedure first.

## Modes

Priority: the `--git=` argument → `git.mode` in `.claude/go-workflow.json` → default `ask`

| Mode | Behavior |
|------|----------|
| `ask` (default) | Show the full set of commands and ask with AskUserQuestion: "Run everything (recommended)" / "Run up to the commit (no push)" / "Just show the commands" |
| `run` | Run without confirmation (only when the user specified this mode explicitly) |
| `print` | Do not run; show copy-ready commands in a `bash` code block and also save them to `RUN_DIR/git-commands.sh` |

## Safety rules (always, in every mode)

- Never use `git push --force` / `--force-with-lease`, `git reset --hard`, `git clean`, or rewrite history
- Never commit or push directly to the default branch (main / master / develop, or whatever `context.md` lists). If on the default branch, always create a new branch
- Do not use `git add -A` / `git add .`; add the changed files explicitly. Never add `.env`, keys, `*.pem`, files that look like credentials, or `.claude/go-workflow/`
- Before committing, check `git diff --cached --stat` to make sure no unintended files are included
- If a commit hook fails, do not bypass it with `--no-verify`; fix the cause and create a new commit
- Follow the commit message conventions (Conventional Commits, language, Co-Authored-By, etc.) from CLAUDE.md / AGENTS.md / CONTRIBUTING / commitlint settings / the recent `git log`

## Generated commands (example)

```bash
# 1. Branch (only if on the default branch or the branch name is unrelated)
git switch -c <BRANCH>

# 2. Staging (name the files explicitly)
git add path/to/a.go path/to/a_test.go ...
git diff --cached --stat

# 3. Commit (pass the message safely through a file)
git commit -F "$RUN_DIR/commit-msg.txt"

# 4. push
git push -u origin <BRANCH>

# 5. Create the PR
gh pr create --base <default_branch> --head <BRANCH> \
  --title "<TITLE>" --body-file "$RUN_DIR/pr.md" [--draft]
```

- For the commit message, put COMMIT from `pr-meta.txt` on the first line and the key points of the change (3–5 lines) in the body, save it to `RUN_DIR/commit-msg.txt`, then use it
- If the change splits into logical parts (e.g. a refactor and a feature, or generated files), you may propose splitting the commits
- If a PR already exists (`gh pr view --json url` succeeds), do not create a new one; propose updating the body with `gh pr edit --body-file`
- If `gh` is not authenticated or there is no remote, show only the push and PR creation commands

## Completion

Report the PR URL (if created) and record it with `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh phase "$RUN_DIR" ship done "<PR URL or print>"`. Mention that the checkpoints (`refs/go-workflow/*`) can be deleted once no longer needed with `git for-each-ref --format='%(refname)' refs/go-workflow/<run> | xargs -n1 git update-ref -d` (they are never pushed, so leaving them is harmless). If CI is set up, explain how to check its status with `gh pr checks`.
