# AI Coding Agent ベンチマーク 2026

AI Coding Agent (Claude Code) で **TypeScript / Python / Rust / Ruby** の4言語を同じ Todo REST API 仕様で5回ずつ生成し、成功率・コード品質を実測比較したベンチマーク。

## 結果サマリー

| 言語 | テスト合格率 | ビルド成功率 | 平均コード行数 | 特記事項 |
|------|------------|------------|-------------|---------|
| TypeScript | 100% (35/35) | 100% (5/5) | 115行 | 最安定。Express+SQLiteは鉄板 |
| Python | 100% (35/35) | 100% (5/5) | 122行 | FastAPI生成が安定 |
| Rust | 100% (35/35) | 100% (5/5) | 173行 | コード量1.5倍、ビルド60秒超 |
| Ruby | 100% (35/35) | 80% (4/5) | 105行 | コード最短だが依存関係でハマる |

## 構成

```
benchmark/
├── spec/PROMPT.md          # 共通仕様書（全言語同一プロンプト）
├── test/test_api.sh        # 共通テストスクリプト
├── run_benchmark.sh        # ベンチマークランナー
└── results/
    ├── typescript/run-{1-5}/  # 生成コード + result.json
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
- Claude Code (Claude Opus 4.6)
- Node.js v22.16.0 / Python 3.14.3 / Rust 1.93.1 / Ruby 4.0.1
