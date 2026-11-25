# Go アーキテクチャ指針（リポジトリ規約がない場合の既定値）

## まず既存構成に合わせる
- リポジトリが Clean Architecture / レイヤード / ヘキサゴナル / フラット構成のどれを採っているかを `exploration.md` で確認し、**新しい構成スタイルを持ち込まない**
- 同種の機能がすでにあれば、そのディレクトリ構成・命名・DI 方法をそのまま踏襲する

## パッケージ
- パッケージは「何を提供するか」で名付ける（`user`, `billing`）。`util` / `common` / `helpers` を作らない
- 外部に公開しないものは `internal/` に置く
- 循環依存を作らない。ドメイン層はインフラ（DB・HTTP・外部 SDK）に依存しない
- `init()` とパッケージレベルの可変グローバル状態を避け、コンストラクタで依存を注入する

## インターフェース
- インターフェースは **利用する側** のパッケージで、必要なメソッドだけ定義する（小さく保つ）
- 「Accept interfaces, return structs」
- テストのためだけのインターフェース乱立は避け、既存のモック方針（mockgen / mockery / 手書き fake）に従う

## エラー
- 下位で `%w` ラップして文脈を付け、境界（HTTP ハンドラ・gRPC・CLI）で 1 回だけログ出力＋外部表現に変換する
- 期待される失敗はセンチネル（`var ErrNotFound = errors.New(...)`）または型付きエラーで表し、呼び出し側は `errors.Is` / `errors.As` で判定
- エラーメッセージは小文字始まり・句点なし

## context
- 第 1 引数 `ctx context.Context`。構造体フィールドに保持しない
- リクエストスコープ値（ユーザー ID、トレース ID）以外を `context.WithValue` に入れない

## 並行性
- goroutine を起動する側が終了まで責任を持つ（`errgroup`, `sync.WaitGroup.Go`）
- チャネルの close は送信側のみ

## テスト
- table-driven + `t.Run`。外部 I/O は境界でフェイク化、DB は既存方針（testcontainers / sqlmock / 実 DB）
- 公開 API の振る舞いをテストし、実装詳細に過度に依存しない
- 統合テストは build tag や `testing.Short()` で分ける既存の流儀に従う
