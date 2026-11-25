---
name: design-review
description: go-workflow の Phase 2（設計レビュー）。Opus の go-design-reviewer と go-security-reviewer を並列に走らせ、Blocker/Major があれば go-architect に改訂させ（最大2回）、最後にユーザー承認を取る。単体でも「/go-workflow:design-review」で使える。
argument-hint: "[--run=<RUN_DIR>]"
disable-model-invocation: true
---

# Phase 2: 設計レビュー → ユーザー承認

入力: $ARGUMENTS

> サブエージェントはプラグインの名前空間付きで起動する（例: `subagent_type: "go-workflow:go-architect"`）。リポジトリの `.claude/agents/` に同じ役割のエージェントがあればそちらを優先してよい。

RUN_DIR: `--run=` 指定、なければ `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh latest`。`design.md` がなければ停止して `/go-workflow:design` を案内。

## モデル選定の理由

設計の誤りは後工程すべてに波及し、修正コストが最も高い。一方で設計書は短く、レビューのトークンコストは小さい。
そのため **設計レビューは opus**（設計者と同じモデルだが、別コンテキスト・別の役割で独立に検証する）。セキュリティ観点は sonnet の専任エージェントで並列に確認する。

## 手順（最大 2 ラウンド）

1. 以下を **同じメッセージで並列に** 起動する:
   - `go-design-reviewer`（RUN_DIR、タスク）
   - `go-security-reviewer`（RUN_DIR、モード `design`、ラウンド番号）
   - リポジトリに設計レビュー用の agent / skill があれば（`context.md` 参照）それも並列で
2. 結果を `RUN_DIR/design-review.md` に統合して保存（ラウンド 2 は `design-review-2.md`）。各指摘に通し番号を振る
3. 判定:
   - Blocker / Major / セキュリティ Critical・High が **0 件** → 承認ステップへ
   - 1 件以上 → `go-architect` に「design.md と design-review.md を読み、Blocker/Major に対応して改訂せよ。Minor は妥当なら取り込み、取り込まない場合は理由を改訂履歴に書け」と依頼し、`design.md` を上書き → ラウンド 2 へ
   - ラウンド 2 でも残る → 残った指摘と両論をユーザーに提示して判断を仰ぐ
4. **ユーザー承認（必須）**: 設計書の要点（目的、変更ファイル、主要な設計判断、セキュリティ対策、テスト計画、未決事項）を 15 行程度で提示し、AskUserQuestion で
   - 「承認して実装へ（推奨）」（`--alternatives` で複数案を作った場合は、採用案の選択もここで行う）
   - 「修正指示を出す」→ 指示を受けて go-architect で改訂し、手順 1 からやり直し
   - 「中止」
5. `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh phase "$RUN_DIR" design-review done "<ラウンド数・指摘件数・承認>"`（各ラウンド開始時は `iter`、承認待ちの間は `waiting`）

Plan モードの場合は、手順 4 を ExitPlanMode（設計書の要点を plan として提示）で代替します。
