# AI Coding Agent ベンチマーク 2026

AI Coding Agent (Claude Code) で **TypeScript / Python / Rust / Ruby** の4言語を同じ Todo REST API 仕様で5回ずつ生成し、成功率・コード品質を実測比較したベンチマーク。

**Opus 4.6** と **Sonnet 4.6** の2モデルで検証。

## 結果サマリー

### Opus 4.6（最上位モデル）

| 言語 | テスト合格率 | ビルド成功率 | 平均コード行数 | 特記事項 |
|------|------------|------------|-------------|---------|
| TypeScript | 100% (35/35) | 100% (5/5) | 115行 | 最安定。Express+SQLiteは鉄板 |
| Python | 100% (35/35) | 100% (5/5) | 122行 | FastAPI生成が安定 |
| Rust | 100% (35/35) | 100% (5/5) | 173行 | コード量1.5倍、ビルド60秒超 |
| Ruby | 100% (35/35) | 80% (4/5) | 105行 | コード最短だが依存関係でハマる |

**総合: 133/140 (95.0%)**

### Sonnet 4.6（高速モデル）

| 言語 | テスト合格率 | ビルド成功率 | 特記事項 |
|------|------------|------------|---------|
| TypeScript | 100% (35/35) | 100% (5/5) | Opus同等 |
| Python | 91.4% (32/35) | 100% (5/5) | Flask選択時にUnicodeエスケープ問題 |
| Rust | 100% (35/35) | 100% (5/5) | Opus同等 |
| Ruby | 85.7% (30/35) | 100% (5/5) | sqlite3 gem 2.0 API変更未対応 |

**総合: 132/140 (94.3%)**

## 構成

```
benchmark/
├── spec/PROMPT.md              # 共通仕様書（全言語同一プロンプト）
├── test/test_api.sh            # 共通テストスクリプト
├── run_benchmark.sh            # 単体ベンチマークランナー
├── run_full_benchmark.sh       # 全言語一括テストランナー
└── results/
    ├── opus-4.6/               # Opus 4.6 生成コード
    │   ├── typescript/run-{1-5}/
    │   ├── python/run-{1-5}/
    │   ├── rust/run-{1-5}/
    │   └── ruby/run-{1-5}/
    └── sonnet-4.6/             # Sonnet 4.6 生成コード
        ├── typescript/run-{1-5}/
        ├── python/run-{1-5}/
        ├── rust/run-{1-5}/
        └── ruby/run-{1-5}/
```

## テスト項目 (7テスト)

1. GET /todos が 200 を返す
2. GET /todos が配列を返す
3. POST /todos が 201 を返す
4. POST /todos が title を含むオブジェクトを返す
5. POST 後の GET で作成したアイテムが取得できる
6. PUT /todos/1 で更新できる
7. DELETE /todos/1 で削除できる

## 検証環境

- macOS Darwin 24.3.0 (Apple Silicon)
- Claude Code (Opus 4.6 / Sonnet 4.6)
- Node.js v22.16.0 / Python 3.14.3 / Rust 1.93.1 / Ruby 4.0.1
