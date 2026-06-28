**Latest (2026-06-28):** 3 つの改善を入れて v0.4.0 をリリース — ①新しいプロジェクトでは記憶が十分たまるまで自動の関連表示を控える（中身が少ないと誤った関連付けをしやすいため）、②決めた瞬間に 1 行だけ記録できる軽量コマンド `/iroha:decide` を新設（重い保存を待たず記憶が育つ）、③Claude Code 標準のメモリと役割を分け、iroha は「チーム共有・人間が読める決定台帳」に集中する位置づけを明確化。実際に自分のプロジェクトで試し（ドッグフード）、過去の決定が記録から漏れていた 1 件を発見・修正し、決定の履歴をつなぐ id 比較のバグも直した。

## Recent sessions
- [2026-06-28 — save 本文の決定論レンダリング](https://app.notion.com/p/38d822c6938a8168ad5be2856b9a70dc)
- [2026-06-27 — HEAVY recall を Bun in-process 化](https://app.notion.com/p/38c822c6938a8163a391fdddc69a683a)

## Unfinished / Next
- [ ] N=1 脱出: 別プロジェクト mumei で compose 化した新 save フローを実走しフィードバック取得 [carried 3x]
- [ ] `state.md` の SessionStart 注入をネイティブ記憶に寄せて削るかは保留（positioning 判断・「ポジショニング」決定の Alternative ③）
- [ ] State 本文・決定 body（supersede lineage 行）の決定論レンダリングは後回し（YAGNI・小さく既存 lint 済み）
- [ ] GitHub 拡張 Phase 0（N=1 脱出後）: `gh` 境界付き PR 抽出 + Session↔PR の URL 連結 [carried 3x]

## Decisions
過去の判断・理由・却下案は [Decisions DB（Active ビュー）](https://app.notion.com/p/7544d1820fc247028948855c08becce2) を参照（リコール / 決定記録 / ポジショニング / HEAVY実行 / 依存方針 / 保存 の 6 件が Active）。技術スタックは未登録 — `/iroha:project` で Projects 行を作成すると相互リンクされる。
