**Latest (2026-06-26):** 一次評価で「完全性・自己監視」と「リコール実効精度」を宿題と判定。研究＋実測の上で、精度=ローカル cross-encoder rerank 前段(opt-in, bge-reranker-v2-m3)で誤注入 4/4→0・recall 維持、完全性=決定論 integrity 自己監視(selftest/CI 常設)＋audit に Notion↔index 件数突合＋save に index 完全性検証を追加し、index の 7件欠落(C-1)を再生成、State 先行(C-2)を整合。selftest 85→98 全 green、3commit。

## Recent sessions
- [2026-06-26 — 精度rerank前段と完全性自己監視](https://app.notion.com/p/38b822c6938a81869424e9ceb358df3d)
- [2026-06-25 — 評価と保存バックログ実装](https://app.notion.com/p/38a822c6938a811eb58ad62cc504920a)
- [2026-06-25 — 評価とState発行前ガード](https://app.notion.com/p/38a822c6938a810b86d7f1f2f256e101)
- [2026-06-25 — トラスト根治とスケール実証](https://app.notion.com/p/38a822c6938a8189b9e6f5c84d304efa)
- [2026-06-25 — ローカルBM25リコール再設計](https://app.notion.com/p/38a822c6938a816092e3fb101f391cdb)

## Unfinished / Next
- [ ] rerank 前段を非iroha/非日本語の実プロジェクトで実証(N=1 脱出・精度の領域汎化を確認)
- [ ] 旧 Session ページ群の体裁リトロフィット(低優先・再保存で自動反映)[carried 5x]

## Decisions
過去の判断・理由・却下案は [Decisions DB](https://app.notion.com/p/128c8c81e60d4443a82cabfd84eb243f) を参照。実装前に `/iroha:recall <topic>` で確認(UserPromptSubmit フックがローカル BM25 で関連決定を常時先出し)。
