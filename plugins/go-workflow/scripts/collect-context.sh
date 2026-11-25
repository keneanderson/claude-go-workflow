#!/usr/bin/env bash
# リポジトリのコンテキスト（Go バージョン、Claude/AI 設定、ツール、Web 判定、PR テンプレート）を
# 決定的に収集して <RUN_DIR>/context.md に書き出し、標準出力にも出す。
#   collect-context.sh <RUN_DIR>
set -uo pipefail

run_dir=${1:?usage: collect-context.sh <RUN_DIR>}
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 1
out="$run_dir/context.md"
mkdir -p "$run_dir"

# 探索から除外するディレクトリ
prune=(-path ./vendor -prune -o -path ./node_modules -prune -o -path ./.git -prune -o -path ./.claude/go-workflow -prune -o)

find_files() { # $1: maxdepth, rest: find の条件
  local depth=$1; shift
  find . -maxdepth "$depth" "${prune[@]}" "$@" -print 2>/dev/null | sed 's|^\./||' | sort
}

frontmatter() { # $1: file, $2: key
  awk -v k="$2" 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1 { if (index($0, k":")==1) { sub(k":[ ]*", ""); print; exit } }' "$1" 2>/dev/null
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---------- git ----------
branch=$(git branch --show-current 2>/dev/null || echo "")
default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
if [ -z "$default_branch" ]; then
  for b in main master develop; do
    if git show-ref --verify --quiet "refs/heads/$b" || git show-ref --verify --quiet "refs/remotes/origin/$b"; then default_branch=$b; break; fi
  done
fi
dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
remote=$(git remote get-url origin 2>/dev/null || echo "")

# ---------- Go ----------
gomod=""
if [ -f go.mod ]; then gomod=go.mod; else gomod=$(find_files 3 -name go.mod | head -n 1); fi
module=""; go_directive=""; toolchain=""
if [ -n "$gomod" ]; then
  module=$(awk '/^module /{print $2; exit}' "$gomod")
  go_directive=$(awk '/^go /{print $2; exit}' "$gomod")
  toolchain=$(awk '/^toolchain /{print $2; exit}' "$gomod")
fi
go_installed=$( (cd "$(dirname "${gomod:-.}")" && go env GOVERSION) 2>/dev/null || echo "not found")
modules=$(find_files 4 -name go.mod)
gowork=""; [ -f go.work ] && gowork="go.work"

# ---------- Web 判定 ----------
web=false; web_reasons=""
add_reason() { web=true; web_reasons="$web_reasons
  - $1"; }
if [ -n "$gomod" ]; then
  for fw in github.com/labstack/echo github.com/gin-gonic/gin github.com/go-chi/chi github.com/gofiber/fiber \
            github.com/gorilla/mux connectrpc.com/connect github.com/a-h/templ github.com/danielgtaylor/huma \
            github.com/grpc-ecosystem/grpc-gateway; do
    grep -q "$fw" "$gomod" 2>/dev/null && add_reason "go.mod requires $fw"
  done
fi
if git grep -qE 'http\.(ListenAndServe|NewServeMux|HandleFunc)|&http\.Server\{' -- '*.go' 2>/dev/null; then add_reason "net/http server code"; fi
tmpl=$(find_files 4 \( -name '*.html' -o -name '*.tmpl' -o -name '*.gohtml' -o -name '*.templ' \) | head -n 3)
[ -n "$tmpl" ] && add_reason "templates: $(echo "$tmpl" | tr '\n' ' ')"
pkgjson=$(find_files 3 -name package.json | head -n 3)
[ -n "$pkgjson" ] && add_reason "frontend: $(echo "$pkgjson" | tr '\n' ' ')"
pwconf=$(find_files 4 -name 'playwright.config.*')

# ---------- 書き出し ----------
{
echo "# Repository Context"
echo
echo "<!-- machine-readable -->"
echo "repo_root: $root"
echo "remote: ${remote:-none}"
echo "branch: ${branch:-detached}"
echo "default_branch: ${default_branch:-unknown}"
echo "uncommitted_files: $dirty"
echo "go_module: ${module:-none}"
echo "go_mod_path: ${gomod:-none}"
echo "go_directive: ${go_directive:-unknown}"
echo "go_toolchain: ${toolchain:-none}"
echo "go_installed: $go_installed"
echo "web: $web"
echo

echo "## Go modules"
if [ -n "$modules" ]; then echo "$modules" | sed 's/^/- /'; else echo "- (go.mod not found)"; fi
[ -n "$gowork" ] && echo "- workspace: go.work"
echo

echo "## Claude / AI の設定ファイル（リポジトリ規約。存在するものは必ず読むこと）"
found_any=false
list_section() { # $1: title, rest: files
  local title=$1; shift
  [ $# -gt 0 ] || return 0
  [ -n "$1" ] || return 0
  found_any=true
  echo "### $title"
  for f in "$@"; do echo "- $f"; done
  echo
}
# shellcheck disable=SC2046
IFS=$'\n'
list_section "CLAUDE.md" $(find_files 4 \( -name CLAUDE.md -o -name CLAUDE.local.md \))
list_section "AGENTS.md" $(find_files 4 \( -name AGENTS.md -o -name AGENT.md \))
list_section ".claude/rules" $(find .claude/rules -type f 2>/dev/null | sort)
list_section "その他の AI 向け規約" $(ls -1 .github/copilot-instructions.md GEMINI.md .windsurfrules .cursorrules 2>/dev/null; find .cursor/rules .github/instructions -type f 2>/dev/null | sort)
list_section "開発ドキュメント" $(ls -1 CONTRIBUTING.md CONTRIBUTING.ja.md SECURITY.md docs/CONTRIBUTING.md 2>/dev/null; find docs -maxdepth 2 -type d \( -name adr -o -name adrs -o -name decisions -o -name architecture -o -name design \) 2>/dev/null | sort)
unset IFS

if ls .claude/agents/*.md >/dev/null 2>&1; then
  found_any=true
  echo "### .claude/agents（リポジトリ独自エージェント）"
  echo "| name | model | description |"
  echo "|------|-------|-------------|"
  for f in .claude/agents/*.md; do
    n=$(frontmatter "$f" name); m=$(frontmatter "$f" model); d=$(frontmatter "$f" description | cut -c1-160)
    echo "| ${n:-$(basename "$f" .md)} | ${m:--} | ${d//|//} |"
  done
  echo
fi
if ls .claude/skills/*/SKILL.md >/dev/null 2>&1; then
  found_any=true
  echo "### .claude/skills（リポジトリ独自スキル）"
  echo "| name | description |"
  echo "|------|-------------|"
  for f in .claude/skills/*/SKILL.md; do
    n=$(frontmatter "$f" name); d=$(frontmatter "$f" description | cut -c1-160)
    echo "| ${n:-$(basename "$(dirname "$f")")} | ${d//|//} |"
  done
  echo
fi
if ls .claude/commands/*.md >/dev/null 2>&1; then
  found_any=true
  echo "### .claude/commands"
  for f in .claude/commands/*.md; do echo "- /$(basename "$f" .md): $(frontmatter "$f" description | cut -c1-120)"; done
  echo
fi
for f in .claude/settings.json .mcp.json .claude/go-workflow.json; do
  [ -f "$f" ] && { found_any=true; echo "- 設定: $f"; }
done
if [ -f .mcp.json ] && has_cmd jq; then
  echo "  - MCP servers: $(jq -r '(.mcpServers // .) | keys | join(", ")' .mcp.json 2>/dev/null)"
fi
$found_any || echo "- （リポジトリ独自の Claude / AI 設定は見つからなかった。go-conventions の既定値を使う）"
echo

echo "## ツール"
if [ -f Makefile ]; then
  targets=$(grep -E '^[A-Za-z0-9][A-Za-z0-9_.-]*:([^=]|$)' Makefile | cut -d: -f1 | grep -v '^\.' | sort -u | tr '\n' ' ')
  echo "- Makefile targets: $targets"
fi
for tf in Taskfile.yml Taskfile.yaml taskfile.yml; do
  [ -f "$tf" ] && echo "- Taskfile: $tf$(has_cmd task && echo " (tasks: $(task --list-all 2>/dev/null | sed -n 's/^\* \([^:]*\):.*/\1/p' | tr '\n' ' '))")"
done
[ -f magefile.go ] && echo "- magefile.go"
golangci=$(ls -1 .golangci.yml .golangci.yaml .golangci.toml .golangci.json 2>/dev/null | head -n 1)
if [ -n "$golangci" ]; then
  echo "- golangci-lint config: $golangci (version: $(awk '/^version:/{print $2; exit}' "$golangci" | tr -d '"'"'"))"
fi
for f in .pre-commit-config.yaml lefthook.yml lefthook.yaml .commitlintrc .commitlintrc.json commitlint.config.js sqlc.yaml sqlc.yml buf.yaml buf.gen.yaml .mockery.yaml gqlgen.yml air.toml .air.toml compose.yaml compose.yml docker-compose.yml docker-compose.yaml Dockerfile; do
  [ -f "$f" ] && echo "- $f"
done
gen=$(git grep -l '^//go:generate' -- '*.go' 2>/dev/null | wc -l | tr -d ' ')
[ "$gen" != "0" ] && echo "- go:generate directives in $gen files"
ci=$(ls -1 .github/workflows/*.y*ml 2>/dev/null | tr '\n' ' ')
[ -n "$ci" ] && echo "- CI workflows: $ci"
echo -n "- installed:"
for t in golangci-lint goimports gofumpt staticcheck govulncheck gopls benchstat gh jq npx; do has_cmd "$t" && echo -n " $t"; done
echo
echo

echo "## Web 判定: $web"
[ -n "$web_reasons" ] && echo "$web_reasons" | sed '/^$/d'
[ -n "$pwconf" ] && echo "- playwright config: $pwconf"
echo

echo "## PR テンプレート"
pr_tmpl=$(find . .github docs -maxdepth 1 -type f -iname 'pull_request_template.md' 2>/dev/null | sed 's|^\./||' | sort -u; find .github -maxdepth 1 -type d -iname 'PULL_REQUEST_TEMPLATE' -exec find {} -type f \; 2>/dev/null)
if [ -n "$pr_tmpl" ]; then echo "$pr_tmpl" | sed 's/^/- /'; else echo "- なし（go-pr-writer の既定テンプレートを使う）"; fi
echo

if [ -f .claude/go-workflow.json ]; then
  echo "## .claude/go-workflow.json（プロジェクト設定）"
  echo '```json'
  cat .claude/go-workflow.json
  echo '```'
  echo
fi

echo "## 直近のコミット"
git log --oneline -n 10 2>/dev/null | sed 's/^/- /'
} >"$out"

cat "$out"
