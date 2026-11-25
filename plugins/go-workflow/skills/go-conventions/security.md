# Go セキュリティチェックリスト

各項目は「該当箇所があれば確認」。悪用シナリオを具体的に書けるものを優先して指摘する。

## 入力・インジェクション
- [ ] SQL はプレースホルダ（`?` / `$1`）。`fmt.Sprintf` / 文字列結合でクエリを組み立てていない。動的な ORDER BY / カラム名は許可リスト
- [ ] `exec.Command` は引数配列で呼び、`sh -c` にユーザー入力を渡さない
- [ ] HTML 出力は `html/template`（`text/template` で HTML を作らない）。`template.HTML` への変換はサニタイズ済みのみ
- [ ] リクエストボディは `http.MaxBytesReader` で上限。JSON は必要なら `DisallowUnknownFields`
- [ ] 数値・長さ・列挙値の範囲検証。ページネーションの上限
- [ ] ログに改行等を含むユーザー入力をそのまま書かない（slog の属性として渡す）

## 認証・認可
- [ ] すべてのハンドラで認可チェック。リソース ID は「所有者 = 現在のユーザー」で絞り込む（IDOR）
- [ ] 管理系エンドポイントのミドルウェア漏れ
- [ ] パスワードは `bcrypt` / `argon2id`。トークン比較は `subtle.ConstantTimeCompare`
- [ ] JWT は署名アルゴリズムを固定し、`exp` / `aud` / `iss` を検証

## ファイル・パス
- [ ] ユーザー入力を含むパスは `os.Root`（1.24+）または `filepath.IsLocal` + ルート配下の検証
- [ ] zip / tar 展開時のパストラバーサル（zip slip）とサイズ上限（zip bomb）
- [ ] 一時ファイルは `os.CreateTemp`、権限は最小（0600 / 0700）

## 外部通信
- [ ] ユーザー指定 URL へのアクセスは SSRF 対策（スキーム・ホスト許可リスト、プライベート IP の拒否、リダイレクト制御）
- [ ] `http.Client` にタイムアウト。`InsecureSkipVerify: true` なし
- [ ] レスポンスボディを `Close`、`io.LimitReader` で上限

## 秘密情報
- [ ] ハードコードされた鍵・パスワード・トークンがない（テスト用の明示的なダミーは可）
- [ ] 秘密情報・PII がログ / エラーメッセージ / API レスポンス / panic メッセージに出ない
- [ ] 乱数: 秘密用途は `crypto/rand`（`crypto/rand.Text()`）。`math/rand` は不可

## Web
- [ ] CSRF: `http.CrossOriginProtection`（1.25+）または既存の CSRF ミドルウェア
- [ ] CORS: `*` と credentials の併用なし、Origin 許可リスト
- [ ] Cookie: `Secure` / `HttpOnly` / `SameSite`
- [ ] セキュリティヘッダー（CSP, X-Content-Type-Options, frame-ancestors 等）は既存方針に従う
- [ ] `http.Server` の `ReadHeaderTimeout` / `ReadTimeout` / `WriteTimeout` / `IdleTimeout`

## 並行性・可用性
- [ ] 無制限の goroutine 起動がない（セマフォ / `errgroup.SetLimit`）
- [ ] 共有状態へのアクセスはロック or チャネル。`go test -race` で検出されない
- [ ] `context` のキャンセルが下流の I/O まで伝播する
- [ ] ユーザー入力から正規表現を組み立てない（または長さ制限）

## 依存関係
- [ ] 新しい依存はメンテナンス状況・ライセンス・必要性を確認
- [ ] `govulncheck ./...` で既知脆弱性がない
- [ ] `go.sum` の不自然な変更がない
