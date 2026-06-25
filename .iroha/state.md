最新サマリー (2026-06-25): 忖度なし評価(74)→論文リサーチ(LLM の 7 弱点ルーブリック＋CoALA 3 層)→批判役と合意→90 点ロードマップ実装。偽フルチャット根治・keys-only ローカル index・enforced JIT recall(headless/config gate/selfcheck)・hybrid recall・失敗の Reflexion 化。selftest 39→58 green・CI green・全 push。Projects 2 件目(iroha-for-agents)登録で横断層を実証。

直近セッション:
- 2026-06-25 — 90点ロードマップ実装と検証 — Complete
- 2026-06-25 — 徹底評価とドッグフーディング再開 — Complete
- 2026-06-24 — Notion 連携の設計と Phase 1 実装 — WIP

未完了 / 次にやること:
- [ ] `bash hooks/recall-inject.sh --selfcheck --live` で実 headless+Notion MCP 往復を最終確認
- [ ] [carried 2x] 検索のスケール検証（数百セッション規模）／ SessionEnd 自動保存（Phase 3・任意）
- [ ] 既存 Session ページのハイライト折りたたみリトロフィット（再保存で自動反映）

決定・各回の記録・スタックの正本は Notion（Decisions / Sessions / Projects DB）。このミラーには転記しない。実装前に /iroha:recall で過去の決定・類似実装・失敗を確認（hybrid＋enforced JIT）。
