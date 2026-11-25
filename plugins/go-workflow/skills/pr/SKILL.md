---
name: pr
description: go-workflow の Phase 7。go-pr-writer（sonnet）で PR タイトル・本文（概要・変更箇所・影響範囲・設計判断・セキュリティ・テスト・Playwright 動作確認・レビュー結果・デプロイ/ロールバック等）を作成し pr.md に保存する。リポジトリの PR テンプレートと規約を優先。単体でも「/go-workflow:pr」で使える。
argument-hint: "[--run=<RUN_DIR>] [--base=<ref>]"
disable-model-invocation: true
---

# Phase 7: PR タイトル・本文の作成（sonnet）

入力: $ARGUMENTS

> サブエージェントはプラグインの名前空間付きで起動する（例: `subagent_type: "go-workflow:go-architect"`）。リポジトリの `.claude/agents/` に同じ役割のエージェントがあればそちらを優先してよい。

RUN_DIR: `--run=` 指定、なければ `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh latest`（なければ `new pr` で作成し `collect-context.sh` を実行）。

## モデル選定の理由

PR 本文は差分の要約に加え「影響範囲」「互換性」の判断が要るため、haiku ではなく sonnet を使う。設計書・レビュー結果が揃っていれば opus は不要。

## 手順

0. **検証のやり直し（証拠の取得）**: これまでの結果を流用せず、PR の直前にチェックモード（自動修正なし）で実行し直す。build / vet / test は全体、format / modernize / lint は今回の差分が対象
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/quality.sh" --base origin/<default_branch> --log "$RUN_DIR/verify.log"
   ```
   `QUALITY: FAIL` なら PR を作らず Phase 4 に戻る。`go fix -diff` の提案（WARN）が今回の差分内にあれば直す。PR 本文の「テスト」「カバレッジ」はこの `verify.log` を根拠にする
0-b. **Definition of Done の確認**: リポジトリに DoD（`docs/definition-of-done.md`、CONTRIBUTING のチェックリスト）があればそれを、なければ `${CLAUDE_SKILL_DIR}/../go-conventions/definition-of-done.md` を使い（`.claude/go-workflow.json` の `dod` 配列はどちらの場合も追加項目として加える）、各項目を RUN_DIR の成果物と実際の差分で確認して `RUN_DIR/dod.md` に ✅ / ❌ / N/A と根拠を書く。❌ が「直せるもの」ならこの時点で直し（Phase 4 を再実行）、直せないものは PR 本文に明記する
1. `go-pr-writer` を起動（RUN_DIR、ベースブランチ）。単体実行で design.md 等がない場合は「差分のみから作成し、不明な項目は『要記入』と書くこと」と伝える
2. 返答の 1〜3 行目（`TITLE:` / `COMMIT:` / `BRANCH:`）を取り出し、本文を `RUN_DIR/pr.md`、メタ情報を `RUN_DIR/pr-meta.txt` に保存
3. 自分で検証:
   - 本文の「テスト」「動作確認」が `quality.log` / `e2e.md` の実際の結果と一致しているか（未実施を実施済みと書いていないか）
   - 秘密情報・内部 URL・個人情報が含まれていないか
4. タイトルと本文の冒頭をユーザーに提示する（全文は `RUN_DIR/pr.md` へのリンクで示す）
5. `bash ${CLAUDE_SKILL_DIR}/../../scripts/run-dir.sh phase "$RUN_DIR" pr done "<タイトル>"`
