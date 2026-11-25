---
name: quality
description: go-workflow の Phase 4。format → modernize(go fix) → go mod tidy → build → vet → golangci-lint → test(-race, coverage) → govulncheck を実行し、失敗は go-build-resolver に最小変更で修正させて最大3回まで再実行する。リポジトリの Makefile / Taskfile / .claude/go-workflow.json のコマンドを優先する。単体でも「/go-workflow:quality」で使える。
argument-hint: "[--run=<RUN_DIR>] [--no-fix] [--all]"
disable-model-invocation: true
---

# Phase 4: lint / format / test / modernize

入力: $ARGUMENTS

> サブエージェントはプラグインの名前空間付きで起動する（例: `subagent_type: "go-workflow:go-architect"`）。リポジトリの `.claude/agents/` に同じ役割のエージェントがあればそちらを優先してよい。

RUN_DIR: `--run=` 指定、なければ `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh latest`（なければ `new quality` で作成）。

## スクリプト

```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/quality.sh" --fix --log "$RUN_DIR/quality.log"
```

- `--fix`: format と modernize を自動修正モードで実行（既定。`--no-fix` 指定時は付けない＝チェックのみ）
- `--base <ref>`: golangci-lint を `--new-from-rev` で差分のみに限定（既存の大量の警告に埋もれないようにする。既定でベースブランチを渡す）
- `--all`: 差分限定をやめ全体を対象にする
- コマンドの解決順: `.claude/go-workflow.json` の `commands.*` → Makefile / Taskfile の同名ターゲット → 既定コマンド
- 最終行に `QUALITY: PASS` / `QUALITY: FAIL (<失敗ステップ>)` を出力し、失敗時は終了コード 1
- ステップの結果: `PASS` / `FAIL`（要修正）/ `WARN`（チェックモードで modernize 提案あり）/ `SKIP`（ツール未導入・設定で無効）/ `ENV`（例: golangci-lint が古い Go でビルドされている等、環境の不整合）
- `SKIP` と `ENV` はゲートを止めないが、**必ずユーザーに報告し、スクリプトが出した対処コマンド（再インストール等）を提示**する。PR 本文にも「未実施」として記載する

`.claude/go-workflow.json` が存在しなければベースブランチは `context.md` の `default_branch` を使い、`--base origin/<default_branch>` を付けて実行します。

## modernize の範囲

`--fix` 時の `go fix`（Go 1.26+）/ modernize は **変更したパッケージのみ** に適用されます（スクリプトが `git diff` から対象パッケージを算出）。リポジトリ全体のモダナイズは差分が膨らむため、必要ならユーザーの合意を得て別 PR にします。

## カバレッジ

`--log` を指定するとテストは `-coverprofile=<RUN_DIR>/coverage.out` 付きで実行され、ログ末尾の `## Coverage` に全体と **変更パッケージごと** のステートメントカバレッジが出ます（Makefile の test ターゲットを使う場合は出ません）。
変更パッケージのカバレッジが極端に低い（目安 60% 未満、またはリポジトリ規約の閾値未満）場合は、テスト不足として go-implementer にテスト追加を依頼するか、理由を PR 本文に書きます。

## 手順（最大 3 回）

1. `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh phase "$RUN_DIR" quality iter` してからスクリプトを実行
2. `QUALITY: PASS` → 自動修正で生じた差分（`git diff --stat`）を確認し、`run-dir.sh phase ... quality done "<要約・カバレッジ>"` で記録して完了
3. `QUALITY: FAIL` → `go-build-resolver` を起動（RUN_DIR と失敗ステップ名を渡す。最小変更で直し、設定の緩和・テスト削除・理由なし `//nolint` は禁止）→ 再実行。ロジックの誤りで設計判断が要る場合は `go-implementer`（モード `fix-quality`）に回す
4. 3 回で通らない場合は停止し、失敗内容と推定原因をユーザーに報告する
   - 既存コード由来の失敗（今回の差分と無関係な lint 警告や flaky テスト）と判断した場合は、根拠（`git stash` 前でも失敗する等）を示してユーザーに続行可否を確認する

リポジトリに lint / test 用の独自 skill や pre-commit / lefthook 設定がある場合は、それも実行して結果を `quality.log` に追記します。
