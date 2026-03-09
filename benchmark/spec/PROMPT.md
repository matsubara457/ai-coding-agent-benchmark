# Todo REST API 仕様書（AI Coding Agent ベンチマーク用）

以下の仕様に従って、Todo REST API を1つのファイルで実装してください。

## 基本要件
- ポート 8080 で起動する HTTP サーバー
- データは SQLite に保存（ファイル名: `todos.db`）
- レスポンスは全て JSON 形式
- サーバー起動時にテーブルが存在しなければ自動作成

## データモデル

```
Todo {
  id: integer (自動採番)
  title: string (必須)
  completed: boolean (デフォルト: false)
  created_at: string (ISO 8601形式、自動設定)
}
```

## エンドポイント

### GET /todos
- 全Todoをリストで返す
- レスポンス: `[{"id":1,"title":"...","completed":false,"created_at":"..."},...]`

### POST /todos
- 新しいTodoを作成
- リクエストボディ: `{"title":"買い物に行く"}`
- レスポンス: 作成されたTodoオブジェクト（id, created_at含む）
- ステータスコード: 201

### PUT /todos/:id
- 指定IDのTodoを更新
- リクエストボディ: `{"title":"更新後","completed":true}`
- レスポンス: 更新後のTodoオブジェクト
- 存在しないID: 404

### DELETE /todos/:id
- 指定IDのTodoを削除
- レスポンス: `{"message":"deleted"}`
- 存在しないID: 404

## 制約
- 外部ライブラリの使用は最小限にすること
- コードは1ファイルに収めること（設定ファイルは別途可）
- エラーハンドリングは基本的なもので良い
