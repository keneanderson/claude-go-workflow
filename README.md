# go-dev-marketplace

Go 開発用の Claude Code プラグインマーケットプレイス。

| プラグイン | 内容 |
|------------|------|
| [go-workflow](plugins/go-workflow/README.md) | 確認質問 → 設計(Opus) → 設計レビュー(Opus) → 実装(Sonnet) → lint/format/test/modernize/coverage → Playwright E2E → 実装レビューループ(Sonnet、指摘は Opus で検証) → Definition of Done → PR 作成 → git 操作 |

## インストール

```bash
claude plugin marketplace add keneanderson/claude-go-workflow
```

```bash
claude plugin install go-workflow@go-dev-marketplace
```

チームで使う場合は、各リポジトリの `.claude/settings.json` に以下を入れると、trust 時にインストールが促されます。

```json
{
  "extraKnownMarketplaces": {
    "go-dev-marketplace": { "source": { "source": "github", "repo": "keneanderson/claude-go-workflow" } }
  },
  "enabledPlugins": { "go-workflow@go-dev-marketplace": true }
}
```

## 使い方

```
/go-workflow:dev ユーザー一覧 API にページネーションを追加する
/go-workflow:dev https://github.com/org/repo/issues/123 --git=print
/go-workflow:dev --resume
```

詳細は [plugins/go-workflow/README.md](plugins/go-workflow/README.md) を参照してください。

## 開発

```bash
claude plugin validate .
claude plugin validate ./plugins/go-workflow
claude plugin eval ./plugins/go-workflow --runs 3 --no-publish
```

## ライセンス

[MIT](LICENSE)
