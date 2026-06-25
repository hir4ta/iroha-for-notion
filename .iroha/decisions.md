## Notion 連携: MCP 一本
- Date: 2026-06-24
- Why: 配布のセットアップを MCP OAuth 接続のみに一本化。トークン管理が不要。
- Rejected: Notion API + トークン（二重セットアップが配布障壁）
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## 連結: relation でなく URL
- Date: 2026-06-24
- Why: MCP の relation 書き込みに既知バグ（notion-mcp-server #45）。
- Rejected: ネイティブ relation（安定確認後に昇格可）
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## 抽出は bash / 知性は Claude
- Date: 2026-06-24
- Why: コードから Anthropic API を呼ばない。要約/決定/分類は Claude がスキル内で担う。
- Rejected: コードから API を呼び出す
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## リコール: notion-search 主体
- Date: 2026-06-25
- Why: notion-search は無料で動きチーム横断で正本を引ける。grep はオフライン fallback。
- Rejected: ローカル grep のみ（単一マシン依存）/ query ツール依存（有料）
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## 命名: iroha に短縮
- Date: 2026-06-24
- Why: /iroha:save-session が簡潔。
- Rejected: iroha-for-notion: をコマンド接頭辞に使う（冗長）
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## 会話ログ: 全文でなくハイライト
- Date: 2026-06-24
- Why: 全文 append は単一セッションの context に収まらない。重要なやり取りだけチャット風に残す。
- Rejected: 全文 collapsed toggle / 要約のみ
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## 設定: 安定パス $HOME 配下
- Date: 2026-06-24
- Why: CLAUDE_PLUGIN_DATA が実行 context 毎に分岐し config が二重化した。
- Rejected: CLAUDE_PLUGIN_DATA をベースにする
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## テンプレ言語: 会話言語・既定英語
- Date: 2026-06-24
- Why: 世界配布想定。海外ユーザーを考慮。
- Rejected: 日本語固定 / 英語固定
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## State: ローカルミラー→hook 注入
- Date: 2026-06-24
- Why: hook は model を持たず Notion に到達できないため、ローカルミラーが必要。
- Rejected: hook から Notion を直接読み取る
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## 変更ファイル: 箇条書き表示
- Date: 2026-06-24
- Why: 視覚的な見やすさ（ユーザー要望）。
- Rejected: · 区切りの 1 行連結
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## タイトル規約: YYYY-MM-DD — 主題 / Decision 短主題
- Date: 2026-06-24
- Why: チーム共有で一覧の走査を速く。Calendar/Board は Name しか出さないので日付先頭。Decision は「トピック: 選択」の短文。
- Rejected: 自由文 / [Type] 主題
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## Session 構造を固定（コア固定＋任意2つ）
- Date: 2026-06-24
- Why: save するたびにセクションが変わると探しにくい。概要table・常時ルール転記は重複なので削除。
- Rejected: 完全固定（空でも全表示）/ 自由生成
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121

## 重複防止: 再保存ガード
- Date: 2026-06-24
- Why: save-session に冪等性が無く、再保存や同名決定で Decisions DB が汚染される。
- Rejected: 冪等性を入れない
- Session: https://app.notion.com/p/389822c6938a81b8832ae4aa55d62121
