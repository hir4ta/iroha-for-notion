**Latest (2026-06-26):** 三度目の評価→config妥当性の自己監視を実装し Critical(`decisions_ds_id=DSID` が canonical recall/audit/決定保存を黙殺)を根治(selftest 98→103)。続けて `/iroha:audit` 相当でコンテンツ rot を一掃: 欠落決定「完全性: integrity floor 常設」を DB 化、偽 http リンク3件・recall 100% 陳腐化・hybrid の scope・Projects 陳腐化(JavaScript 追記)を修正、CI に gitleaks/typos を追加(pre-commit とミラー)。全 green・4 commit。

## Recent sessions
- [2026-06-26 — config自己監視と三度目の評価](https://app.notion.com/p/38b822c6938a81a98378cb726b9c516d)
- [2026-06-26 — 精度rerank前段と完全性自己監視](https://app.notion.com/p/38b822c6938a81869424e9ceb358df3d)
- [2026-06-25 — 評価と保存バックログ実装](https://app.notion.com/p/38a822c6938a811eb58ad62cc504920a)
- [2026-06-25 — 評価とState発行前ガード](https://app.notion.com/p/38a822c6938a810b86d7f1f2f256e101)
- [2026-06-25 — トラスト根治とスケール実証](https://app.notion.com/p/38a822c6938a8189b9e6f5c84d304efa)

## Unfinished / Next
- [ ] ハイブリッド検索(BM25 ∪ dense)→ rerank(rerank 単体では候補化漏れ=今の2 MISS を直せない。recall@3=81% の本道)
- [ ] rerank 前段を非iroha/非日本語の実プロジェクトで実証(N=1 脱出) [carried 2x]
- [ ] 旧 Session ページ群の体裁リトロフィット(再保存で自動反映) [carried 6x]
- [ ] 小粒: `extract.sh` が `<teammate-message>` を人間 turn に計上(isMeta 類似の新ノイズ class)・`digest` の index 列挙化・`release.yml` の version/test ゲート

## Decisions
過去の判断・理由・却下案は [Decisions DB](https://app.notion.com/p/128c8c81e60d4443a82cabfd84eb243f) を参照。実装前に `/iroha:recall <topic>` で確認(UserPromptSubmit フックがローカル BM25 で関連決定を常時先出し)。
