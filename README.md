# go-dev-marketplace

A Claude Code plugin marketplace for Go development.

| Plugin | Description |
|--------|-------------|
| [go-workflow](plugins/go-workflow/README.md) | Clarifying questions → design (Opus) → design review (Opus) → implementation (Sonnet) → lint/format/test/modernize/coverage → Playwright E2E → implementation review loop (Sonnet, findings verified by Opus) → Definition of Done → PR creation → git operations |

## Installation

```bash
claude plugin marketplace add keneanderson/claude-go-workflow
```

```bash
claude plugin install go-workflow@go-dev-marketplace
```

For team use, add the following to each repository's `.claude/settings.json`. Team members will be prompted to install the plugin when they trust the repository.

```json
{
  "extraKnownMarketplaces": {
    "go-dev-marketplace": { "source": { "source": "github", "repo": "keneanderson/claude-go-workflow" } }
  },
  "enabledPlugins": { "go-workflow@go-dev-marketplace": true }
}
```

## Usage

```
/go-workflow:dev Add pagination to the user list API
/go-workflow:dev https://github.com/org/repo/issues/123 --git=print
/go-workflow:dev --resume
```

See [plugins/go-workflow/README.md](plugins/go-workflow/README.md) for details.

## Development

```bash
claude plugin validate .
claude plugin validate ./plugins/go-workflow
claude plugin eval ./plugins/go-workflow --runs 3 --no-publish
```

## License

[MIT](LICENSE)
