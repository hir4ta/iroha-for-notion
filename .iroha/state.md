**Latest (2026-06-27):** opt-in の高精度リコール（dense 検索 + 再ランク）の重い処理を node 経由から Bun 内実行へ変え、外部ランタイム(node/npm)を撤廃。検索精度テスト(`rerank-eval`)の既存不具合も修正。ライブラリ導入を検討し `fast-check`(開発用 devDep)で `link-lint`/`extract.ts` の不変条件を property test、`Zod` は配布ユーザーに追加 `bun install` を強いて「単一セットアップ・無依存 FREE tier」を崩すため見送り**依存ゼロを維持**、`CONTRIBUTING` を Bun/TS へ更新。

## Recent sessions
- [2026-06-27 — HEAVY recall を Bun in-process 化](https://app.notion.com/p/38c822c6938a81aeade3c3ff45f0bbc0)
- [2026-06-27 — Bun/TS 移行と session-lint](https://app.notion.com/p/38c822c6938a810c8e25c6bdddce8792)

## Unfinished / Next
- [ ] N=1 脱出（最優先）: 非 iroha / 非日本語の実プロジェクトで iroha 全体を実証（総合の天井を上げる唯一の手）[carried 2x]
- [ ] GitHub 拡張 Phase 0（N=1 脱出後）: `gh` 境界付き PR 抽出 + golden eval・Session↔PR の URL 連結 [carried 2x]
- [ ] 巨大セッションのフルチャット逐語投稿の機械化（`extract.ts` の chat 出力を Notion へ機械投稿する小ツール）[carried 2x]
- [ ] `rerank-eval` の `TRUEQ` は現コーパス3決定依存 — 決定が増えたら再ラベル/拡張

## Decisions
過去の判断・理由・却下案は [Decisions DB（Active ビュー）](https://app.notion.com/p/db9931c0b38644ee99cebd50518a9a39) を参照。技術スタックは未登録 — `/iroha:project` で Projects 行を作成すると相互リンクされる。
