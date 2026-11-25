---
name: go-conventions
description: モダンな Go の書き方（バージョン別の新機能・置き換え表）、Go のセキュリティチェックリスト、アーキテクチャ指針。Go コードの設計・実装・レビュー時、「モダナイズして」「最新の Go の書き方で」「セキュリティ観点で見て」と言われたときに参照する。リポジトリの CLAUDE.md / AGENTS.md / rules が常に優先する。
---

# Go Conventions（汎用指針）

このスキルは **リポジトリ独自の規約がない部分を埋める既定値** です。優先順位は常に:

1. リポジトリの `CLAUDE.md` / `AGENTS.md` / `.claude/rules/**` / ADR / `CONTRIBUTING.md`
2. リポジトリ内の既存パターン
3. このスキル

## 参照ファイル

- [modern-go.md](${CLAUDE_SKILL_DIR}/modern-go.md) — Go バージョン別の新機能と「旧 → 新」置き換え表、`go fix`（modernize）の使い方
- [security.md](${CLAUDE_SKILL_DIR}/security.md) — Go のセキュリティチェックリスト
- [architecture.md](${CLAUDE_SKILL_DIR}/architecture.md) — パッケージ設計・レイヤー・エラー・テストの指針
- [definition-of-done.md](${CLAUDE_SKILL_DIR}/definition-of-done.md) — PR 前に毎回確認する完了の定義
- [pitfalls.md](${CLAUDE_SKILL_DIR}/pitfalls.md) — linter が拾いにくい Go の落とし穴（レビューで指摘するパターン集）

## 最重要ルール

- 使える機能は **`go.mod` の `go` ディレクティブ** で決まる（インストール済みの Go ではない）。新機能を使う前に必ず確認する
- 新規コードはモダンな書き方で書く。既存コードの一括モダナイズは差分が膨らむため、タスクのスコープ内（変更したファイル・関数）に限る。全体適用はユーザーの合意を得て別 PR にする
- 不確かな API は推測で使わず `go doc <pkg>.<Symbol>` で確認する
- コード理解には gopls MCP（`go_workspace` / `go_search` / `go_file_context` / `go_package_api` / `go_symbol_references` / `go_diagnostics` / `go_vulncheck`。ツール名は `mcp__plugin_go-workflow_gopls__*` など） が使えれば優先する: 編集前に `go_symbol_references` で影響範囲を確認し、編集後は `go_diagnostics` でビルドエラーを確認する
