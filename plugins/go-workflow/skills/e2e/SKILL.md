---
name: e2e
description: go-workflow の Phase 5（Web のみ）。アプリを起動し、Playwright MCP で設計書の E2E シナリオ（正常系・異常系・権限）をブラウザ操作で確認、スクリーンショット付きで e2e.md に記録する。失敗は go-implementer で修正し Phase 4 から再確認。単体でも「/go-workflow:e2e」で使える。
argument-hint: "[--run=<RUN_DIR>] [--url=http://localhost:8080]"
disable-model-invocation: true
---

# Phase 5: Playwright による動作確認

入力: $ARGUMENTS

> サブエージェントはプラグインの名前空間付きで起動する（例: `subagent_type: "go-workflow:go-architect"`）。リポジトリの `.claude/agents/` に同じ役割のエージェントがあればそちらを優先してよい。

RUN_DIR: `--run=` 指定、なければ `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh latest`。

## 実行判定

次のいずれかなら SKIP し、`run-dir.sh phase "$RUN_DIR" e2e skip "<理由>"` で記録:
- `--no-e2e` が指定された
- `context.md` の `web: false`
- 差分（`git diff --name-only <base>...` + 未コミット）が HTTP ハンドラ / ルーティング / ミドルウェア / テンプレート / 静的ファイル / フロントエンド / API スキーマに及ばない

## 起動情報の決定

優先順:
1. 引数 `--url=`
2. `.claude/go-workflow.json` の `web.startCommand` / `web.baseURL` / `web.healthcheck` / `web.env`
3. 推定: Makefile の `run` / `dev` / `serve` ターゲット、`compose.yaml` / `docker-compose.yml`、`air.toml`、`cmd/*/main.go` の listen アドレス、README の起動手順

推定に自信がない場合（DB 等の依存サービスが必要、複数候補がある）は AskUserQuestion で確認し、回答を `.claude/go-workflow.json` に保存するか提案する（保存はユーザーの同意後）。

## Playwright MCP の確認

本プラグインは `.mcp.json` で Playwright MCP（`@playwright/mcp`）を同梱しています。ツールが見つからない場合は ToolSearch で `playwright browser` を検索してから判断し、それでもなければ `/mcp` での有効化をユーザーに案内し、API レベル（curl）の確認だけ行って SKIP 扱いにします。

## 手順（最大 2 回）

1. `go-e2e-tester` を起動（RUN_DIR、起動情報、design.md のシナリオ。スクリーンショットは `RUN_DIR/e2e/` に保存）
2. 結果を `RUN_DIR/e2e.md` に保存
3. PASS → 完了。FAIL → 失敗が実装起因なら `go-implementer`（モード `fix-e2e`）で修正 → Phase 4（quality）→ 再度この Phase。テストシナリオ・環境起因ならユーザーに報告
4. 2 回で解決しなければユーザーに判断を仰ぐ
5. 起動したサーバーが残っていないことを確認（`lsof -i :<port>`）
6. `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh phase "$RUN_DIR" e2e done|skip|fail "<シナリオ数・結果 or SKIP 理由>"`
