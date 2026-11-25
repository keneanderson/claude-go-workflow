---
name: implement
description: go-workflow の Phase 3（実装）。承認済み design.md の実装ステップを縦に薄いスライス単位で Sonnet の go-implementer に実装させる。テストを先に書いて失敗を確認してから実装し、バッチごとにチェックポイントを保存する。単体でも「/go-workflow:implement」で使える。
argument-hint: "[--run=<RUN_DIR>] [--steps=1-3]"
disable-model-invocation: true
---

# Phase 3: 実装（sonnet）

入力: $ARGUMENTS

> サブエージェントはプラグインの名前空間付きで起動する（例: `subagent_type: "go-workflow:go-implementer"`）。リポジトリの `.claude/agents/` に同じ役割のエージェントがあればそちらを優先してよい。

スクリプト: `${CLAUDE_SKILL_DIR}/../../scripts/`（以下 `SCRIPTS`）
RUN_DIR: `--run=` 指定、なければ `bash SCRIPTS/run-dir.sh latest`。`design.md` がない、または `state.json` の `design-review` が done でない場合は、ユーザーに確認してから進める。

## 手順

1. `design.md` の「実装ステップ」を **バッチ** に分ける
   - 縦のスライス（1 つの振る舞いを型 → ロジック → ハンドラ → テストまで通す）を優先し、層ごとの横切りは避ける
   - 目安: 1 バッチ = 変更ファイル 10 個程度、各バッチ完了時点でビルドとテストが通る状態
   - 小さなタスクなら 1 バッチでよい
2. バッチごとに **順番に**（同じファイルを触る可能性があるため並列にしない）:
   1. `bash SCRIPTS/checkpoint.sh save "$RUN_DIR" pre-implement-<n>`
   2. `bash SCRIPTS/run-dir.sh phase "$RUN_DIR" implement iter "batch <n>: <ステップ番号>"`
   3. `go-implementer` を起動。プロンプト:
      - `RUN_DIR`、モード `implement`、担当ステップ番号と、そのステップの受け入れ条件
      - 「context.md / exploration.md のリポジトリ規約、design.md に従うこと。設計からの逸脱は報告すること」
      - 「振る舞いの追加・バグ修正は、先にテストを書いて **失敗することを確認（RED）** してから実装すること」
      - 前のバッチの実装結果の要約（変更ファイル・公開した型/関数）
   4. 報告を `RUN_DIR/implement.md` に追記し、`STATUS:` に応じて対応する（dev スキルの共通ルール参照）。DONE でも `git diff --stat` で実際に変更されたことを確認し、`go build ./... && go test ./<変更パッケージ>/...` を自分でも実行する
      - 同じバッチで 2 回 BLOCKED / 失敗が続いたら、`go-implementer` を `model: opus` で新しく起動し、「前任者が N 回試みた。implement.md に経緯がある」と伝えて引き継がせる
   5. 「設計からの逸脱」が重大（公開 API・DB スキーマ・セキュリティ方針の変更）なら、続行前にユーザーに確認する。実装が破綻した場合は `checkpoint.sh restore` で戻してやり直す
3. コード生成（`go generate`, sqlc, mockgen, wire, buf, templ）が絡む場合は、生成元の変更後にリポジトリのコマンドで再生成されているか確認する
4. `bash SCRIPTS/run-dir.sh phase "$RUN_DIR" implement done "<変更ファイル数>, 逸脱: <なし|あり>"`

リポジトリに実装用の独自 agent / skill（例: Go のコーディング規約をまとめたスキル）がある場合は、`go-implementer` へのプロンプトで「そのスキルの規約にも従うこと」と名前を挙げて伝えます。
