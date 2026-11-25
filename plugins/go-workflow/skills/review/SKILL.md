---
name: review
description: go-workflow の Phase 6（実装レビューループ）。Sonnet の go-code-reviewer と go-security-reviewer（＋リポジトリ独自のレビュー agent）を並列実行し、確信度の高い指摘だけを採用、Critical/High は Opus の go-finding-verifier で検証してから go-implementer で修正 → quality 再実行 → 再レビューを最大3回繰り返す。単体でも「/go-workflow:review」で現在の差分に使える。
argument-hint: "[--run=<RUN_DIR>] [--base=<ref>] [--max-review=3]"
disable-model-invocation: true
---

# Phase 6: 実装レビュー ⇄ 修正ループ（sonnet + 検証 opus）

入力: $ARGUMENTS

> サブエージェントはプラグインの名前空間付きで起動する（例: `subagent_type: "go-workflow:go-code-reviewer"`）。リポジトリの `.claude/agents/` に同じ役割のエージェントがあればそちらを優先してよい。

スクリプト: `${CLAUDE_SKILL_DIR}/../../scripts/`（以下 `SCRIPTS`）
RUN_DIR: `--run=` 指定、なければ `bash SCRIPTS/run-dir.sh latest`（なければ `new review` で作成し `collect-context.sh` を実行）。
ベース: `--base=` 指定、なければ `context.md` の `default_branch`（`origin/<default_branch>` があればそちら）。

## 上限回数の考え方（既定 3 回）

- 1 回目で大半の指摘が出て、2 回目で修正確認と修正起因の回帰が見つかる。3 回目は収束確認
- それ以上回すと、レビュアーが軽微な指摘を出し続けて差分が膨らむ（churn）傾向があり、コストに見合わない
- 3 回で Critical/High が残るのは設計レベルの問題である可能性が高いため、人間に判断を戻す
- 誤検知を修正し続けることが churn の最大の原因なので、**修正前に検証ステップを挟む**

## 1 イテレーション（n = 1..上限）

1. `bash SCRIPTS/run-dir.sh phase "$RUN_DIR" review iter "round <n>"`
2. 以下を **同じメッセージで並列に** 起動:
   - `go-code-reviewer`（RUN_DIR、n、ベース、前回の `review-<n-1>.md`）。n ≥ 2 では **修正差分のみ** を対象にする再レビューとして、`git diff refs/go-workflow/<run>/pre-review-fix-<n-1>` を渡す（前回指摘の ADDRESSED / NOT ADDRESSED と、修正差分での新たな破損だけを見る。スコープ外の気付きはメモ止まりでループを延ばさない）
   - `go-security-reviewer`（RUN_DIR、モード `code`、n、ベース）。n ≥ 2 で前回セキュリティ指摘が 0 件かつ修正がセキュリティ関連箇所を触っていなければ省略可
   - `context.md` に検出された **リポジトリ独自のレビュー agent / skill**（名前に review / reviewer を含むもの等）
3. **フィルタ**: 確信度 80 未満の指摘、pre-existing（差分外）、linter で検出できる種類の指摘は捨てる（PR 本文の参考情報にも載せない）
4. **検証**: 残った Critical / High（セキュリティ含む）について、`go-finding-verifier` を **指摘ごとに並列** で起動（1 メッセージで最大 5 体。多い場合は関連する指摘をまとめて渡す）。REJECTED は「Won't fix（検証で誤検知）」、UNCERTAIN はユーザーに判断を仰ぐ
5. 統合結果を `RUN_DIR/review-<n>.md`（セキュリティは `security-<n>.md` も）に保存。各指摘に「採用 / Deferred / Won't fix」と理由を付ける
6. **トリアージ**:
   - CONFIRMED の Critical / High: 必ず修正
   - Medium: 原則修正。設計変更を伴う・スコープ外のものは Deferred として理由を記録
   - Low / Nit: 修正コストが小さいもののみ。残りは PR 本文の「残課題」へ
7. 修正対象が 0 件 → `bash SCRIPTS/run-dir.sh phase "$RUN_DIR" review done "<重大度別件数の推移>"` で終了
8. `bash SCRIPTS/checkpoint.sh save "$RUN_DIR" pre-review-fix-<n>` → `go-implementer`（モード `fix-review`、対象指摘 ID 一覧と指摘本文をそのまま）で修正 → Phase 4（quality）の手順で再チェック
   - 2 回目以降は、可能なら前回の go-implementer に SendMessage で続きを依頼する（文脈を保ったまま直せる）。使えなければ `implement.md` と前回の修正報告を渡して新しく起動する
   - **最終ラウンド**（n = 上限）でも同じ指摘が NOT ADDRESSED のまま残っている場合は、`go-implementer` を `model: opus` で新しく起動し、「前任者が N 回修正を試みた。review-*.md と implement.md に経緯がある」と伝えて引き継がせる（同じ実装者は自分の問題に気付けないことが多い）
   - 修正報告に「対象テストのコマンドと出力」がなければ、再レビューの前に go-implementer に追記させる
9. 修正で quality / テストが悪化して戻せない場合は `checkpoint.sh restore "$RUN_DIR" pre-review-fix-<n>` で戻し、別の修正方針を試す
10. 修正が Web の振る舞いに影響する場合は Phase 5 の該当シナリオのみ再確認
11. n += 1

上限到達時に CONFIRMED の Critical / High が残っていれば、残件・各案・推奨を提示して AskUserQuestion（「設計に戻る」「このまま PR 化（残件を明記）」「手動で対応」）。
