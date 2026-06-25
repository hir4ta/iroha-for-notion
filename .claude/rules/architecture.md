# アーキテクチャ不変条件

- **Notion 連携は MCP 一本**。書き込みは Claude がスキル内で Notion MCP ツールを呼ぶ:
  `notion-create-database` (DB 作成) / `notion-create-pages` (DB 行 + Markdown 本文) /
  `notion-update-page` (`replace_content` で State 全置換) / `notion-search` (リコール、無料プランで動く)。
  **API トークンは使わない**。認証は MCP の OAuth のみ (配布ユーザーは MCP 接続だけ)。
- **relation プロパティは使わない**。MCP の relation 書き込みに既知バグ (makenotion/notion-mcp-server
  Issue #45)。Session↔Decision は **URL プロパティ**で連結。安定確認後にネイティブ relation へ昇格可。
- **決定論抽出は bash**。`scripts/extract.sh` が transcript JSONL から
  files / commands / meta / **prompts**(人間の実発言) / **stats**(メトリクス) /
  **tools**(ツール内訳) / **chat**(整形フルチャット・1ターン上限) を read-only で抽出
  （壊れ/切り詰め行は `fromjson?` でスキップし全滅させない）。stdout = 要求されたビューのみ、
  診断ログは **必ず stderr**。会話ハイライトの **You は `prompts` の実発言にアンカー**し、
  Claude が発言を創作しない／成功を誇張しない。
- **知性は Claude 本体 (スキル内)**。要約・決定抽出・Type 分類は `/save-session` の中で Claude が行う。
  コードから Anthropic API を呼ばない。
- **append 非対応を前提に設計**。Session ページ = 作成のみ (1 回で全部書く)、Project State = 毎回
  `replace_content` で全置換。逐次 append はしない。
- **データモデル**: Sessions + Decisions + Projects の **3 DB** + プロジェクト 1 枚の State ページ。
  ID は config.json にキャッシュ。**決定/ルールの正本は Decisions DB / CLAUDE.md** に一本化し、
  State / Session ページに全文転記しない (重複防止)。
- **3層メモリ**: Session=各回の出来事 / Decision=なぜ / **Projects (Architecture)=今の技術スタック**
  (言語・lib・CI・mermaid 図、手動更新 `/iroha:project`)。Projects は 1 行=1 プロジェクトの共有 DB、
  `Languages` のみ multi_select、横断検索 (同言語/同 lib の他プロジェクト) に使う。Architecture には
  「なぜ」を書かず Decisions へリンク。
- **リコールは `notion-search` 主体＋keys-only ローカル index で補完** (無料プランで
  `query-data-sources` が有料＝全件列挙不能なので、`.iroha/index.ndjson` に id/topic/status/date
  のみを持ち dedup・abstention・audit を**完全列挙**で行う。本文は Notion 正本＝二重の真実にしない)。
  `/iroha:recall` は Sessions/Decisions を semantic 検索し relevance+recency+importance で少数を
  edges-first に返す (該当無しは検索語スコープで正直に abstain)。supersede は `トピック:` 前方一致＋
  index で既存 Active を引く。
- **repo ミラーは `.iroha/state.md`（State 全文）と `.iroha/index.ndjson`（keys-only 列挙）の 2 つ**
  （ともに commit し teammate は pull で共有）。SessionStart hook は Notion 非到達なので `state.md`
  を注入。**決定の本文はローカルに持たない**（Notion 正本）が、無料プランの列挙不能を補う keys-only
  index（id/topic/status/date のみ・本文なし）は持つ＝本文の二重化ではないのでドリフトしない。
  config.json / saved マーカーは $HOME (マシン固有)。State の未完了は save 毎にトリアージ。
- **命名と履歴**: Session = `YYYY-MM-DD — 主題`、Decision = `トピック: 選択` (理由は Rationale、
  却下案は Alternatives 欄)。決定を覆す時は旧行を **Status=Superseded** にし上書きしない (心変わりも
  記憶)。Session ページのセクション構造は固定 (Metrics ダッシュボードは常設、任意は
  Architecture / Rules changed / Failures の 3 つ)。
- **冪等性**: `/init` は既存コンテナ/DB を検出したら再利用 (チーム参加 = 同じコマンド)。
  fallback = 複製可能 Notion テンプレート方式。
- **シークレットを持たない**。Notion 認証は MCP OAuth で完結。userConfig / env トークンは無し。
- **保存はリマインド・recall は enforced**。保存強制はしない (Stop の exit 2 ブロックは使わず
  ユーザーを閉じ込めない)；保存忘れは SessionStart で注意喚起。一方 recall は **UserPromptSubmit の
  enforced JIT 注入** (`recall-inject.sh` が bounded headless `claude -p` を発火・再帰ガード/timeout/
  cache/degrade 完備、`claude` や `timeout` 不在・未接続では無害に degrade) で、各プロンプトに関連
  決定を proactively 注入する。hook の注入テキスト（wrapper）は **配布コードなので英語**、本文の
  State は会話言語（= ユーザーデータ）。未完了 `- [ ]` 件数のバナーも算出して添える。
  `source=compact`（`/compact`・auto-compact 後）は現在セッションのトランスクリプトから会話
  (prompts ＋ chat 直近) を再注入してスレッドを復元する（行単位 cap でマルチバイト非分割。Notion
  非到達の不変は維持＝ローカル transcript のみ読む）。
- **派生スキルは正本を汚さない**。`/iroha:digest` (期間ロールアップ) と `/iroha:audit`
  (記憶の健全性監査=重複決定/State ドリフト/陳腐化の検出) は `notion-search` で読むだけ。
  digest は container 配下に使い捨ての Digest ページを 1 枚書く (専用 DB は作らない)。audit の
  修正系は `--fix`/確認時のみ、削除でなく `Status=Superseded` 等の **可逆操作**に限る。
