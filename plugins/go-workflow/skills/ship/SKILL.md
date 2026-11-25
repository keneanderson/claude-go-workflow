---
name: ship
description: go-workflow の Phase 8（git 操作）。ブランチ作成・ステージング・コミット・push・gh pr create のコマンドを生成し、モード（ask=確認して実行 / run=実行 / print=コマンド提示のみ）に従って実行する。単体でも「/go-workflow:ship」で使える。
argument-hint: "[--run=<RUN_DIR>] [--git=ask|run|print] [--draft]"
disable-model-invocation: true
---

# Phase 8: git 操作

入力: $ARGUMENTS

> サブエージェントはプラグインの名前空間付きで起動する（例: `subagent_type: "go-workflow:go-architect"`）。リポジトリの `.claude/agents/` に同じ役割のエージェントがあればそちらを優先してよい。

RUN_DIR: `--run=` 指定、なければ `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh latest`。`pr.md` / `pr-meta.txt` がなければ先に `/go-workflow:pr` の手順を実行する。

## モード

優先順: 引数 `--git=` → `.claude/go-workflow.json` の `git.mode` → 既定 `ask`

| モード | 動作 |
|--------|------|
| `ask`（既定） | コマンド一式を提示し、AskUserQuestion で「すべて実行（推奨）」「コミットまで実行（push しない）」「コマンドだけ表示」から選んでもらう |
| `run` | 確認なしで実行（ユーザーがモードを明示した場合のみ） |
| `print` | 実行せず、コピーして使えるコマンドを `bash` コードブロックで提示し、`RUN_DIR/git-commands.sh` にも保存 |

## 安全ルール（どのモードでも厳守）

- `git push --force` / `--force-with-lease`、`git reset --hard`、`git clean`、履歴の書き換えをしない
- デフォルトブランチ（main / master / develop など `context.md` 記載のもの）に直接コミット・push しない。デフォルトブランチ上なら必ず新ブランチを切る
- `git add -A` / `git add .` を使わず、変更ファイルを明示して追加する。`.env`、鍵、`*.pem`、認証情報らしきファイル、`.claude/go-workflow/` は追加しない
- コミット前に `git diff --cached --stat` を確認し、意図しないファイルが入っていないか確かめる
- コミットフックが失敗したら `--no-verify` で回避せず、原因を直して新しいコミットを作る
- コミットメッセージの規約（Conventional Commits、言語、Co-Authored-By 等）は CLAUDE.md / AGENTS.md / CONTRIBUTING / commitlint 設定 / 直近の `git log` に従う

## 生成するコマンド（例）

```bash
# 1. ブランチ（デフォルトブランチ上 or ブランチ名が無関係な場合のみ）
git switch -c <BRANCH>

# 2. ステージング（ファイルを明示）
git add path/to/a.go path/to/a_test.go ...
git diff --cached --stat

# 3. コミット（メッセージはファイル経由で安全に渡す）
git commit -F "$RUN_DIR/commit-msg.txt"

# 4. push
git push -u origin <BRANCH>

# 5. PR 作成
gh pr create --base <default_branch> --head <BRANCH> \
  --title "<TITLE>" --body-file "$RUN_DIR/pr.md" [--draft]
```

- コミットメッセージは `pr-meta.txt` の COMMIT を 1 行目に、本文に変更の要点（3〜5 行）を書いて `RUN_DIR/commit-msg.txt` に保存してから使う
- 変更が論理的に分かれる場合（例: リファクタと機能追加、生成物）は、コミットを分ける案を提示してよい
- 既存の PR がある場合（`gh pr view --json url` が成功）は新規作成せず、`gh pr edit --body-file` で本文更新を提案する
- `gh` が未認証 / リモートがない場合は、push と PR 作成のコマンドだけを提示する

## 完了

PR URL（作成した場合）を報告し、`bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh phase "$RUN_DIR" ship done "<PR URL or print>"` で記録します。チェックポイント（`refs/go-workflow/*`）は不要になったら `git for-each-ref --format='%(refname)' refs/go-workflow/<run> | xargs -n1 git update-ref -d` で削除できることを案内します（push されないので残っていても害はない）。CI が設定されていれば `gh pr checks` で状態を確認する方法を案内します。
