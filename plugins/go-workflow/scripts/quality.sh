#!/usr/bin/env bash
# Go の品質チェックを順に実行する:
#   format → modernize → tidy → build → vet → lint → test → vuln
#
# usage: quality.sh [--fix] [--base <ref>] [--all] [--only a,b] [--skip a,b] [--log <file>]
#   --fix         format / modernize / tidy を自動修正モードで実行（なしならチェックのみ）
#   --base <ref>  変更ファイル・lint 差分の基準（例: origin/main）
#   --all         format / modernize を変更ファイル限定ではなく全体に適用
#   --only/--skip 実行するステップを絞る
#   --log <file>  出力をファイルにも追記
#   --cover <file> カバレッジプロファイルの出力先（既定: --log と同じディレクトリの coverage.out）
#
# コマンド解決順（ステップごと）:
#   1. .claude/go-workflow.json の commands.<step>（"skip" で無効化）
#   2. Makefile / Taskfile の同名ターゲット（format は fmt|format、vuln は vuln|govulncheck）
#   3. 既定コマンド
set -uo pipefail

fix=false; base=""; all=false; only=""; skip=""; log=""; cover=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fix) fix=true ;;
    --no-fix) fix=false ;;
    --base) base=${2:-}; shift ;;
    --base=*) base=${1#*=} ;;
    --all) all=true ;;
    --only) only=${2:-}; shift ;;
    --only=*) only=${1#*=} ;;
    --skip) skip=${2:-}; shift ;;
    --skip=*) skip=${1#*=} ;;
    --log) log=${2:-}; shift ;;
    --log=*) log=${1#*=} ;;
    --cover) cover=${2:-}; shift ;;
    --cover=*) cover=${1#*=} ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 1
conf="$root/.claude/go-workflow.json"

# go.mod がルートにない場合は 1 つ目の go.mod のディレクトリで実行
if [ ! -f go.mod ]; then
  m=$(find . -maxdepth 3 -name go.mod -not -path './vendor/*' 2>/dev/null | sort | head -n 1)
  [ -n "$m" ] && cd "$(dirname "$m")"
fi
moddir=$(pwd)

if [ -n "$log" ]; then
  mkdir -p "$(dirname "$log")"
  [ -n "$cover" ] || cover="$(cd "$(dirname "$log")" && pwd)/coverage.out"
  exec > >(tee -a "$log") 2>&1
fi

has_cmd() { command -v "$1" >/dev/null 2>&1; }
in_list() { case ",$2," in *",$1,"*) return 0 ;; esac; return 1; }

conf_cmd() { # $1: step
  [ -f "$conf" ] && has_cmd jq || return 1
  local v; v=$(jq -r --arg s "$1" '.commands[$s] // empty' "$conf" 2>/dev/null)
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  return 1
}

make_target() { # $@: 候補ターゲット名
  local t
  for t in "$@"; do
    if [ -f Makefile ] && grep -qE "^${t}:" Makefile; then printf 'make %s' "$t"; return 0; fi
    if { [ -f Taskfile.yml ] || [ -f Taskfile.yaml ]; } && has_cmd task && task --list-all 2>/dev/null | grep -qE "^\* ${t}:"; then
      printf 'task %s' "$t"; return 0
    fi
  done
  return 1
}

# ---------- 対象ファイル・パッケージ ----------
go_minor=$(go env GOVERSION 2>/dev/null | sed -E 's/^go1\.([0-9]+).*/\1/')
case "$go_minor" in ''|*[!0-9]*) go_minor=0 ;; esac

changed_go_files() {
  {
    [ -n "$base" ] && git diff --name-only --diff-filter=ACMR "$base"...HEAD 2>/dev/null
    git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | grep -E '\.go$' | sort -u | while read -r f; do
    # moddir 相対に変換し、存在するもののみ
    abs="$root/$f"
    [ -f "$abs" ] || continue
    case "$abs" in "$moddir"/*) printf '%s\n' "${abs#"$moddir"/}" ;; esac
  done | grep -vE '(^|/)(vendor|testdata)/' || true
}

files=$(changed_go_files)
pkgs=$(printf '%s\n' "$files" | sed '/^$/d' | xargs -n1 dirname 2>/dev/null | sort -u | sed 's|^|./|; s|^\./\.$|.|')

# ---------- 既定コマンド ----------
fmt_default() {
  local targets
  if $all; then targets=$(git ls-files '*.go' | grep -vE '(^|/)vendor/'); else targets=$files; fi
  [ -n "$targets" ] || { echo "(no changed .go files)"; return 0; }
  local tool="gofmt -s"; has_cmd goimports && tool="goimports"
  if $fix; then
    # shellcheck disable=SC2086
    printf '%s\n' $targets | xargs $tool -w
    if has_cmd gofumpt && grep -qs gofumpt .golangci.* Makefile; then printf '%s\n' $targets | xargs gofumpt -w; fi
  else
    local bad
    # shellcheck disable=SC2086
    bad=$(printf '%s\n' $targets | xargs $tool -l)
    [ -z "$bad" ] || { echo "unformatted files:"; echo "$bad"; return 1; }
  fi
}

modernize_default() {
  local target
  if $all; then target="./..."; else target=$(printf '%s ' $pkgs); fi
  [ -n "${target// /}" ] || { echo "(no changed packages)"; return 0; }
  if [ "$go_minor" -ge 26 ]; then
    if $fix; then
      # shellcheck disable=SC2086
      go fix $target
    else
      local d
      # shellcheck disable=SC2086
      d=$(go fix -diff $target 2>&1)
      [ -z "$d" ] || { echo "$d"; echo "modernize: suggestions above (run with --fix)"; return 3; }
    fi
  else
    local m="golang.org/x/tools/go/analysis/passes/modernize/cmd/modernize@latest"
    # shellcheck disable=SC2086
    if $fix; then go run "$m" -fix -test $target; else go run "$m" -test $target || return 3; fi
  fi
}

tidy_default() {
  if $fix; then go mod tidy; else go mod tidy -diff; fi
}

lint_default() {
  if has_cmd golangci-lint; then
    # golangci-lint はビルドに使った Go より新しい Go のコードを解析できない（panic する）
    local built
    built=$(golangci-lint version 2>&1 | sed -nE 's/.*built with go1\.([0-9]+).*/\1/p' | head -n 1)
    if [ -n "$built" ] && [ "$built" -lt "$go_minor" ]; then
      echo "golangci-lint is built with go1.$built but the toolchain is go1.$go_minor."
      echo "reinstall it with the current Go: go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest"
      return 5
    fi
    golangci-lint run ${base:+--new-from-rev="$base"} ./...
  elif has_cmd staticcheck; then
    staticcheck ./...
  else
    echo "golangci-lint / staticcheck not installed"; return 4
  fi
}

test_default() {
  local args="-count=1"
  [ "$(go env CGO_ENABLED)" = "1" ] && args="$args -race"
  [ -n "$cover" ] && args="$args -coverprofile=$cover -covermode=atomic"
  # shellcheck disable=SC2086
  go test $args ./...
}

coverage_report() { # 変更パッケージと全体のステートメントカバレッジ
  [ -n "$cover" ] && [ -s "$cover" ] || return 0
  echo
  echo "## Coverage"
  echo "- total: $(go tool cover -func="$cover" 2>/dev/null | awk '/^total:/{print $NF}')"
  local p ip
  for p in $pkgs; do
    ip=$(go list "$p" 2>/dev/null) || continue
    awk -v ip="$ip" 'NR>1 { split($1, a, ":"); f=a[1]; sub("/[^/]*$", "", f);
         if (f==ip) { n+=$2; if ($3>0) c+=$2 } }
         END { if (n>0) printf "- %s: %.1f%% (%d/%d statements)\n", ip, 100*c/n, c, n; else printf "- %s: no statements / no tests\n", ip }' "$cover"
  done
}

vuln_default() {
  if has_cmd govulncheck; then govulncheck ./...; else
    echo "govulncheck not installed (go install golang.org/x/vuln/cmd/govulncheck@latest)"; return 4
  fi
}

resolve() { # $1: step → 実行するコマンド文字列
  local step=$1 c
  if c=$(conf_cmd "$step"); then printf '%s' "$c"; return; fi
  case "$step" in
    format)    c=$(make_target fmt format) || c=fmt_default ;;
    modernize) c=$(make_target modernize) || c=modernize_default ;;
    tidy)      c=tidy_default ;;
    build)     c="go build ./..." ;;
    vet)       c=$(make_target vet) || c="go vet ./..." ;;
    lint)      c=$(make_target lint) || c=lint_default ;;
    test)      c=$(make_target test) || c=test_default ;;
    vuln)      c=$(make_target vuln govulncheck) || c=vuln_default ;;
  esac
  printf '%s' "$c"
}

# ---------- 実行 ----------
[ -n "$cover" ] && rm -f "$cover"
steps="format modernize tidy build vet lint test vuln"
summary=""; failed=""
echo "== go-workflow quality ($(date '+%Y-%m-%d %H:%M:%S')) dir=$moddir go=$(go env GOVERSION 2>/dev/null) fix=$fix base=${base:-none} all=$all"
echo "== changed go files: $(printf '%s\n' "$files" | sed '/^$/d' | wc -l | tr -d ' ')"

for s in $steps; do
  if [ -n "$only" ] && ! in_list "$s" "$only"; then continue; fi
  if [ -n "$skip" ] && in_list "$s" "$skip"; then summary="$summary
| $s | SKIP | --skip |"; continue; fi
  cmd=$(resolve "$s")
  if [ "$cmd" = "skip" ]; then summary="$summary
| $s | SKIP | go-workflow.json |"; continue; fi
  echo
  echo "### [$s] $cmd"
  start=$(date +%s)
  eval "$cmd"
  rc=$?
  dur=$(( $(date +%s) - start ))s
  case $rc in
    0) st=PASS ;;
    3) st=WARN ;;                    # modernize の提案あり（チェックモード）
    4) st=SKIP ;;                    # ツール未インストール
    5) st=ENV ;;                     # ツールと環境の不整合（要対応だがコードの問題ではない）
    *) st=FAIL; failed="$failed $s" ;;
  esac
  echo "### [$s] => $st (rc=$rc, $dur)"
  summary="$summary
| $s | $st | \`$cmd\` ($dur) |"
done

[ -n "$only" ] && ! in_list test "$only" || coverage_report

echo
echo "## Summary"
echo "| step | result | command |"
echo "|------|--------|---------|"
printf '%s\n' "$summary" | sed '/^$/d'
if $fix; then
  echo
  echo "## Auto-fix diff (git diff --stat)"
  git -C "$root" diff --stat
fi
echo
if [ -n "$failed" ]; then
  echo "QUALITY: FAIL (${failed# })"
  exit 1
fi
echo "QUALITY: PASS"
