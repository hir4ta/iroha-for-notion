**Latest (2026-06-25):** 反復評価(総合80/100・前回 rot 3件の根治が定着を実証)から、書き込み経路の無テストを `state-lint`(State 発行前バリデータ)で予防化し Tier A/B/C を実施。発見: 前回フラグの MRR 誤記が CHANGELOG に生存(audit の死角=repo doc → `H` チェック追加)、「abstention 100%」は英語ネガのみのアーティファクトで日本語領域外は leak(pure-lexical の本質的限界 → cross-domain に正直化、floor は据置)。`/iroha:check`(git×Decision 矛盾検知)を新設。selftest 72→80・recall-eval 11/11・scale 8/8 全 green・8 commits。

## Recent sessions
- [2026-06-25 — 評価とState発行前ガード](https://app.notion.com/p/38a822c6938a810b86d7f1f2f256e101)
- [2026-06-25 — トラスト根治とスケール実証](https://app.notion.com/p/38a822c6938a8189b9e6f5c84d304efa)
- [2026-06-25 — ローカルBM25リコール再設計](https://app.notion.com/p/38a822c6938a816092e3fb101f391cdb)
- [2026-06-25 — 90点ロードマップ実装と検証](https://app.notion.com/p/38a822c6938a813a9968ef7b2375b86b)
- [2026-06-25 — 徹底評価とドッグフーディング再開](https://app.notion.com/p/38a822c6938a812c92e2e40b02e39b13)

## Unfinished / Next
- [ ] 旧 Session ページ群の体裁リトロフィット（低優先・再保存で自動反映）[carried 3x]

見送り中（正本は Decisions DB・必要性が実測で出たら再評価）: リコール効果の計測ループ(C1=feedback 信号が系に無く実装不能) / ローカル semantic 段(recall 精度の真の対策だが no-token 不変を破壊) / Session property map のファイル化検証(C3=アーキ変更で過剰) / 多人数・多言語の実地検証(C4=2人目の実ユーザーが必要・コードでない) / SessionEnd 自動保存 / importance 学習 / reflection 層。

## Decisions
過去の判断・理由・却下案は [Decisions DB](https://app.notion.com/p/128c8c81e60d4443a82cabfd84eb243f) を参照。実装前に `/iroha:recall <topic>` で確認（UserPromptSubmit フックがローカル BM25 で関連決定を常時先出し）。
