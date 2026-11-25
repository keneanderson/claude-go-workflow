# Modern Go リファレンス

`go.mod` の `go` ディレクティブ以下のバージョンの機能のみ使うこと。不確かなものは `go doc` で確認する。

## 旧 → 新 置き換え表

| 旧 | 新 | 最低バージョン |
|----|----|----------------|
| `interface{}` | `any` | 1.18 |
| `strings.Index` + スライス | `strings.Cut` / `CutPrefix` / `CutSuffix` | 1.18 / 1.20 |
| 複数エラーの自前結合 | `errors.Join`、`fmt.Errorf` で複数 `%w` | 1.20 |
| `sync/atomic.AddInt64(&x)` | `atomic.Int64` などの型 | 1.19 |
| `if a < b { m = a }` | `min(a, b)` / `max(a, b)` | 1.21 |
| map を for で全削除 | `clear(m)` | 1.21 |
| `sort.Slice` / 手書きの contains・index | `slices.Sort` / `slices.SortFunc` / `slices.Contains` / `slices.Index` | 1.21 |
| map のキー収集ループ | `slices.Sorted(maps.Keys(m))` | 1.23 |
| `log` / 外部ロガーの新規導入 | `log/slog`（既存ロガーがあればそれに従う） | 1.21 |
| `sync.Once` + 変数 | `sync.OnceFunc` / `OnceValue` / `OnceValues` | 1.21 |
| `v := v`（ループ変数のコピー） | 不要（1.22 から反復ごとに新しい変数） | 1.22 |
| `for i := 0; i < n; i++` | `for i := range n` | 1.22 |
| ルーター外部依存のための単純なパスマッチ | `mux.HandleFunc("GET /items/{id}", h)` + `r.PathValue("id")` | 1.22 |
| `math/rand` | `math/rand/v2`（秘密用途は `crypto/rand`） | 1.22 |
| `if x == "" { x = def }` | `cmp.Or(x, def)` | 1.22 |
| スライス結合の append 連鎖 | `slices.Concat` | 1.22 |
| コールバック式のイテレータ | `iter.Seq[T]` / `iter.Seq2[K,V]` + range-over-func | 1.23 |
| `context.WithCancel(context.Background())` in tests | `t.Context()` | 1.24 |
| `for i := 0; i < b.N; i++` | `for b.Loop()` | 1.24 |
| `filepath.Join(root, userPath)` + 自前検証 | `os.Root` / `os.OpenInRoot` | 1.24 |
| `json:",omitempty"`（構造体・time.Time のゼロ値） | `json:",omitzero"` | 1.24 |
| `strings.Split` で行/フィールド走査 | `strings.Lines` / `SplitSeq` / `FieldsSeq`（bytes も同様） | 1.24 |
| `tools.go` でツール依存を管理 | `go get -tool <pkg>` / `go tool <name>` | 1.24 |
| 秘密トークン生成の自前実装 | `crypto/rand.Text()` | 1.24 |
| `wg.Add(1); go func(){ defer wg.Done() ... }()` | `wg.Go(func(){ ... })` | 1.25 |
| 時間依存テストの sleep | `testing/synctest` | 1.25 |
| 自前の CSRF（Origin/Sec-Fetch-Site チェック） | `http.CrossOriginProtection` | 1.25 |
| `var target *MyErr; errors.As(err, &target)` | `target, ok := errors.AsType[*MyErr](err)` | 1.26 |
| `p := new(T); *p = v` / ポインタ用ヘルパ関数 | `new(v)`（式を取る `new`） | 1.26 |
| 型に属するのにパッケージレベルに置いた汎用関数 | ジェネリックメソッド `func (s Set[T]) Map[U any](...)`（インターフェースのメソッドには不可・ジェネリックメソッドでインターフェースは満たせない） | 1.27 |
| `i := strings.LastIndex(s, sep); s[:i], s[i+len(sep):]` | `strings.CutLast` / `bytes.CutLast` | 1.27 |
| `url.URL` / `url.Values` の手書きディープコピー | `URL.Clone()` / `Values.Clone()` | 1.27 |
| `github.com/google/uuid` 等の UUID 依存 | 標準ライブラリ `uuid` パッケージ（v3/v5 名前空間 UUID や DB の Scanner 連携に依存していないか確認してから） | 1.27 |
| synctest バブル内の `time.Sleep` + `synctest.Wait` | `synctest.Sleep` | 1.27 |
| synctest と組み合わせる `httptest.NewServer` | `httptest.NewTestServer`（インメモリの疑似ネットワーク） | 1.27 |
| JSON の新規コードで細かい挙動制御が必要 | `encoding/json/v2` + `encoding/json/jsontext`（v2 は不正 UTF-8 と重複キーを拒否する。既存の `encoding/json` は v2 実装の上で v1 の挙動を維持するので移行は必須ではない） | 1.27 |

上記以外の 1.27 以降の機能は https://go.dev/doc/devel/release のリリースノートを確認してから使う（記憶で書かない）。

## Go のバージョンを上げるときの確認（1.27）

コードの書き換えではなく、事前確認が必要なもの:

- `go.mod` の `godebug` や `//go:debug` で、1.27 で削除された GODEBUG 設定（`asynctimerchan` など）を旧値に固定していないか → ビルドエラーになる（`git grep -n 'go:debug'; grep -n godebug go.mod`）
- `go test` が `stdversion` vet チェックを実行するようになり、go ディレクティブより新しい標準ライブラリ API の使用がテスト失敗になる → チェックを黙らせず、go ディレクティブを上げるかビルドタグで分ける
- `encoding/json` は v2 実装ベースになり、エラーメッセージの文言が変わりうる → エラー文字列を比較しているテストを確認
- macOS 向けビルドの最低対応バージョンが 13.0
- `go fix` に modernizer（`atomictypes`, `embedlit`, `slicesbackward`, `unsafefuncs`）が追加され、`fmtappendf` は削除。ツールチェーン更新後に `go fix -diff ./...` で確認

## 実行時の調査に使える新機能

- goroutine リーク: `runtime/pprof` の `goroutineleak` プロファイル（1.27 で正式、`/debug/pprof/goroutineleak`）。到達不能な同期プリミティブで止まった goroutine を検出する

## 自動モダナイズ（`go fix` / modernize）

- Go 1.26 以降: `go fix ./...` が modernize アナライザ群を実行する（`go fix -diff ./...` で差分確認のみ）
- Go 1.25 以前: `go run golang.org/x/tools/go/analysis/passes/modernize/cmd/modernize@latest -fix -test ./...`
- golangci-lint v2 を使っているリポジトリは `.golangci.yml` で `modernize` / `intrange` / `copyloopvar` / `usestdlibvars` などが有効か確認し、リポジトリの設定に従う
- 自動修正はタスクで触ったパッケージに限定するのが基本。全体に適用すると無関係な差分が大量に出る

## その他の現代的な慣習

- エラー: `fmt.Errorf("op: %w", err)`、比較は `errors.Is` / `errors.As`（`errors.AsType`）
- HTTP サーバー: `http.Server` に `ReadHeaderTimeout` などを必ず設定、`http.DefaultClient` ではなくタイムアウト付きクライアント
- JSON v2（`encoding/json/v2`）は 1.25〜1.26 では `GOEXPERIMENT=jsonv2` が必要なので使わない。1.27 以降は使ってよいが、既存の `encoding/json` からの置き換えは挙動差（不正 UTF-8・重複キーの拒否など）を確認してから
- テスト: table-driven + `t.Run`、`t.Cleanup`、`t.TempDir`、`t.Setenv`、`go test -race`
- 構造化ログ: `slog.InfoContext(ctx, "msg", "key", v)`、属性に PII を入れない
