**Latest (2026-06-26):** 実使用フィードバック＋新鮮な4視点レビューで iroha を徹底改善。**Notion の構造**を整理(`States`/`Digests` フォルダで散らからない・決定に `Topic` 一級プロパティ＋By Topic view・大量データはページ階層でなくビューで捌く)、**保存処理**を効率化(`extract.sh all` で抽出を1パス集約・Decision を `pages[]` 一括・独立書込を並列)、**初回セットアップの3躓き**(新規プロジェクト保存の select 400・`.iroha/` gitignore・MCP 認証)を解消。recall の精度は単一強語マッチを守るため lexical を据え置き(coverage gate は実 recall を犠牲にすると selftest で実証＝却下)、精度向上は意味検索段の仕事と再確認。selftest 131・recall-eval 86%・pre-commit/CI 全 green。総合の天井=N=1 外部未実証は不変(mumei で実使用は開始)。

## Recent sessions
- [2026-06-26 — レビュー駆動の徹底改善(構造/効率/初回UX)](https://app.notion.com/p/38b822c6938a81a98378cb726b9c516d)
- [2026-06-26 — hybrid recall・決定lineage・commit check](https://app.notion.com/p/38b822c6938a81d3902ad1f98908ed67)
- [2026-06-26 — 精度rerank前段と完全性自己監視](https://app.notion.com/p/38b822c6938a81869424e9ceb358df3d)
- [2026-06-25 — 評価と保存バックログ実装](https://app.notion.com/p/38a822c6938a811eb58ad62cc504920a)
- [2026-06-25 — 評価とState発行前ガード](https://app.notion.com/p/38a822c6938a810b86d7f1f2f256e101)

## Unfinished / Next
- [ ] **N=1 脱出**: 非 iroha / 非日本語の実プロジェクトで iroha 全体を実証(総合の天井を上げる唯一の手)。mumei での実使用が端緒=その実使用フィードバックを本セッションで反映済。 [carried 4x]
- [ ] hybrid 93% は opt-in tier の数字・free tier は 86% のまま。opt-in tier 自体が iroha 外で未実証。
- [ ] `hybrid-eval.yml` を一度 workflow_dispatch で初回実走確認。
- [ ] write-time advisory フックは本セッションの実コミットで発火確認済(governing 決定を正しく提示・非ブロック)。残: `permissionDecision` 無し=非自動承認の最終確認のみ。
- [ ] 小粒: `extract.sh` が `<teammate-message>` を人間 turn に計上・`digest` の index 列挙化・`release.yml` の version/test ゲート・CI の setup-python@v5 Node20 警告(非ブロッキング)。

## Decisions
過去の判断・理由・却下案は [Decisions DB](https://app.notion.com/p/128c8c81e60d4443a82cabfd84eb243f) の **Active ビュー**(俯瞰は **By Topic** view)を参照。技術スタックは [Projects DB](https://app.notion.com/p/f29e289dbcad4a32a4b17fbef5c928e1)。実装前に `/iroha:recall <topic>` で確認(UserPromptSubmit フックがローカル BM25 で関連決定を常時先出し)。
