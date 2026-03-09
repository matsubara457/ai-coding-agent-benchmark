# Sonnet 4.6 ベンチマーク コード生成指示

## 手順

1. Claude Code で `/model` コマンドを実行して **Sonnet 4.6** に切り替える
2. 以下のプロンプトをそのまま貼り付ける
3. 完了後、`./benchmark/run_full_benchmark.sh sonnet-4.6` でテストを実行する

---

## 貼り付け用プロンプト

```
以下のタスクを実行してください。並列で構いません。

benchmark/spec/PROMPT.md の仕様に従って、4言語 × 5回 = 計20個の Todo REST API を生成してください。

### 言語ごとの要件

#### TypeScript (5回)
- 出力先: benchmark/results/sonnet-4.6/typescript/run-{1,2,3,4,5}/
- ファイル名: app.ts
- package.json も生成（express, better-sqlite3, @types/* 等）
- tsx で直接実行可能にすること

#### Python (5回)
- 出力先: benchmark/results/sonnet-4.6/python/run-{1,2,3,4,5}/
- ファイル名: app.py
- requirements.txt も生成（fastapi, uvicorn, aiosqlite 等）

#### Rust (5回)
- 出力先: benchmark/results/sonnet-4.6/rust/run-{1,2,3,4,5}/
- ファイル名: src/main.rs
- Cargo.toml も生成（actix-web, rusqlite 等）

#### Ruby (5回)
- 出力先: benchmark/results/sonnet-4.6/ruby/run-{1,2,3,4,5}/
- ファイル名: app.rb
- Gemfile も生成（sinatra, sqlite3, rackup, puma 等）
- 重要: Sinatra 4.x では rackup gem が必須。Gemfile に必ず含めること

### 共通ルール
- 各 run は独立した実装（コピペ禁止、毎回ゼロから生成）
- ポートは 8080 固定
- SQLite ファイル名は todos.db
- コードは1ファイルに収める
- 仕様は benchmark/spec/PROMPT.md を参照
```
