**Latest (2026-06-26):** 三度目の反復評価で総合73/100。最大発見=実config `decisions_ds_id=DSID` が canonical な recall/audit/決定保存を黙殺(proactive recall は index 経由で動くため不可視)。`config.sh validate`(ID形の offline 自己監視)を追加し `--selfcheck`/selftest/audit に配線、実config を修復して根治。selftest 98→103 全green、1 commit。

## Recent sessions
- [2026-06-26 — config自己監視と三度目の評価](https://app.notion.com/p/38b822c6938a81a98378cb726b9c516d)
- [2026-06-26 — 精度rerank前段と完全性自己監視](https://app.notion.com/p/38b822c6938a81869424e9ceb358df3d)
- [2026-06-25 — 評価と保存バックログ実装](https://app.notion.com/p/38a822c6938a811eb58ad62cc504920a)
- [2026-06-25 — 評価とState発行前ガード](https://app.notion.com/p/38a822c6938a810b86d7f1f2f256e101)
- [2026-06-25 — トラスト根治とスケール実証](https://app.notion.com/p/38a822c6938a8189b9e6f5c84d304efa)

## Unfinished / Next
- [ ] Notionコンテンツ rot を `/iroha:audit` で修正: M-1(欠落決定「完全性: integrity floor 常設」をDB作成)・M-3(偽httpリンク3件 `search.sh`/`state-lint.sh`/`CLAUDE.md`)・recall 100% 陳腐化snippet・M-2(Projects に JavaScript 追記)・H-1(hybrid決定の scope明記)
- [ ] CI に `gitleaks`/`typos` 追加(pre-commit ⊋ CI=秘密スキャンの穴)
- [ ] ハイブリッド検索(BM25 ∪ dense)→ rerank(rerank単体では候補化漏れ=今の2 MISSを直せない)
- [ ] rerank 前段を非iroha/非日本語の実プロジェクトで実証(N=1脱出) [carried 2x]
- [ ] 旧 Session ページ群の体裁リトロフィット [carried 6x]

## Decisions
過去の判断・理由・却下案は [Decisions DB](https://app.notion.com/p/128c8c81e60d4443a82cabfd84eb243f) を参照。実装前に `/iroha:recall <topic>` で確認(UserPromptSubmit フックがローカル BM25 で関連決定を常時先出し)。
