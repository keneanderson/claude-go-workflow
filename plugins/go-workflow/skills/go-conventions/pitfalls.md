# Go のよくある落とし穴（レビューで見つけたら指摘する）

linter で検出されにくく、レビューで拾うべきパターン。差分に含まれるものだけを対象にする。

## エラー
| パターン | 問題 |
|----------|------|
| `v, _ := f()`（err を捨てる） | 失敗が黙って無視される |
| `fmt.Errorf("...: %v", err)` | `%v` だとエラーチェーンが切れ、`errors.Is/As` が効かない。`%w` を使う |
| 内側のスコープで `x, err := ...` | 外側の `err` を覆い隠し、外側は nil のまま返る |
| `var e *MyErr; return e`（戻り値の型が `error`） | 型付き nil がインターフェースに入り `err != nil` が true になる |
| `http.Error(w, ...)` の後に `return` がない | ハンドラの処理が続いてしまう |
| `defer` があるのに `log.Fatal` / `os.Exit` | defer が実行されずにプロセスが終わる |
| `rows, _ := db.Query(...)` で Close しない / `rows.Err()` を見ない | 接続リーク / 途中のエラーを見逃す |

## 並行性
| パターン | 問題 |
|----------|------|
| context なしの `go func() { ... }()` | 止められずリークする |
| goroutine の中で `wg.Add(1)` | `Wait()` が先に返る競合。`wg.Go` か起動前に Add |
| `sync.Mutex` などを含む構造体の値レシーバ・値コピー | ロックがコピーされて保護されない |
| mutex なしの共有 map | データ競合（`-race` で落ちる、本番で fatal error） |
| `close(ch)` 後の送信、受信側での close | panic。close は送信側だけ |
| ループ内の `select { default: }` | ブロックせず CPU を食い続けるビジーループ |
| ホットループ内の `time.After` | 毎回タイマーを生成する。`time.NewTimer` + `Reset` |

## 値・型
| パターン | 問題 |
|----------|------|
| `int32(x)` など大きい整数の縮小変換 | 黙って桁あふれ。範囲チェックが必要 |
| `t1 == t2`（`time.Time`） | モノトニッククロック・ロケーションの違いで不一致。`t1.Equal(t2)` |
| `strings.Trim(s, "prefix")` | 部分文字列ではなく文字集合を削る。`strings.TrimPrefix` |
| `iota` を 0 から始めた列挙 | ゼロ値と最初の値が区別できない。`Unknown = iota` などを先頭に |
| スライスを返して呼び出し側が append | 元の配列を共有して書き換わる。必要なら `slices.Clone` |
| nil map への書き込み | panic。`make` で初期化 |
| `switch` の `fallthrough` | 次の case を条件なしで実行する |

## HTTP・I/O・パス
| パターン | 問題 |
|----------|------|
| `http.Get` / `http.DefaultClient` | タイムアウトなし |
| `resp.Body` を Close しない / 読み切らない | 接続が再利用されずリーク |
| `filepath.Join(base, userInput)` | `../` によるパストラバーサルは防げない。`os.Root` か `filepath.IsLocal` |
| ハンドラ内の `regexp.MustCompile` | リクエストごとにコンパイル。パッケージ変数へ |

## パフォーマンス
| パターン | 問題 |
|----------|------|
| ホットループ内の `defer` | 関数の終わりまで積み上がる |
| ループ内の文字列 `+=` | `strings.Builder` |
| 長さがわかっているスライスの append | `make([]T, 0, n)` で事前確保 |
| ループ内の DB クエリ | N+1。まとめて取得 |
