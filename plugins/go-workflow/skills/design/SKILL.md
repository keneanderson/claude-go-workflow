---
name: design
description: go-workflow の Phase 1（確認質問 → 設計）。リポジトリ規約・既存コードを調査し、曖昧な点をユーザーに確認してから、Opus の go-architect で代替案比較・受け入れ条件・アーキテクチャ・セキュリティ・モダン Go・テスト計画を含む設計書を作る。単体でも「/go-workflow:design <タスク>」で使える。
argument-hint: "<タスク内容> [--run=<RUN_DIR>] [--alternatives]"
disable-model-invocation: true
---

# Phase 1: 確認質問 → 設計（Plan / opus）

入力: $ARGUMENTS

> サブエージェントはプラグインの名前空間付きで起動する（例: `subagent_type: "go-workflow:go-architect"`）。リポジトリの `.claude/agents/` に同じ役割のエージェントがあればそちらを優先してよい。

スクリプト: `${CLAUDE_SKILL_DIR}/../../scripts/`（以下 `SCRIPTS`）

## 単体実行の場合の準備

`/go-workflow:dev` から呼ばれていない場合:

1. `--run=` 指定があればそれを RUN_DIR に、なければ `bash SCRIPTS/run-dir.sh new <slug>` で作成
2. `RUN_DIR/context.md` がなければ `bash SCRIPTS/collect-context.sh "$RUN_DIR"`
3. `RUN_DIR/exploration.md` がなければ `go-explorer` エージェント（haiku）を起動して作成

## 1-a. 確認質問（`clarify`）

設計に入る前に、`task.md` と `exploration.md` を突き合わせて **推測が必要な点** を洗い出します。

- 対象: 要件の曖昧さ、エッジケース（空・重複・上限・同時実行）、エラー時の振る舞い、認可の範囲、後方互換の要否、スコープ外にするもの、性能要件
- 既存コードや規約から答えが出るものは質問しない（自分で調べて exploration.md に追記）
- 質問は AskUserQuestion でまとめて最大 4 問。各問に推奨案を先頭に置く
- 回答を `RUN_DIR/clarifications.md` に保存。質問が不要なら「なし」と記録して `clarify` を skip にする

## 1-b. 設計（`design`）

1. **リポジトリ独自の設計支援を確認**: `context.md` に設計・ADR 系の skill / agent（例: 設計書作成・ADR 作成・アーキテクト系のもの）や設計書テンプレート（`docs/design/template.md` 等）があれば、その構成・観点を `go-architect` に渡す
2. `go-architect` を起動する。プロンプトに含めるもの:
   - `RUN_DIR`、タスク（`task.md`）、`clarifications.md`
   - 「`context.md` / `exploration.md` を読み、リポジトリ規約を最優先にすること」
   - 「go ディレクティブ（context.md 記載）で使える機能のみ採用すること」
   - Web 判定が true なら「テスト計画に Playwright で確認する E2E シナリオ（正常系・異常系・権限）を具体的に書くこと」
3. `--alternatives` 指定時（または変更ファイルが 15 以上になりそうな大きな変更）は、`go-architect` を **3 体並列** で起動し、それぞれに方針を指定する: 「最小変更（既存を最大限再利用）」「クリーン（保守性・抽象化を重視）」「バランス（速度と品質の両立）」。結果の要点を比較表にしてユーザーに選んでもらい、選ばれた設計を採用する
4. 返ってきた設計書を `RUN_DIR/design.md` に保存
5. 設計書の「未決事項」にユーザー判断が必要なものが残っていれば AskUserQuestion で確認し、回答を反映して `go-architect` に改訂させる（軽微なものは自分で追記してよい）
6. `bash SCRIPTS/run-dir.sh phase "$RUN_DIR" design done "<設計の要約1行>"`

単体実行時は、完了後に設計書の要点をユーザーに提示し、「`/go-workflow:design-review` でレビューする」ことを案内します。
