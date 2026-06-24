#!/usr/bin/env bash
# iroha-for-notion — local, offline recall. Greps the project's locally mirrored
# decisions for a query and prints matching decision blocks. Free: needs no Notion
# access (the Notion MCP query/search tools require a paid Business plan + AI).
# Usage: recall.sh <project-cwd> <query>
set -u

cwd="${1:-}"
query="${2:-}"
if [ -z "$cwd" ] || [ -z "$query" ]; then
  echo "usage: recall.sh <project-cwd> <query>" >&2
  exit 2
fi

# shellcheck disable=SC1091
. "${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/scripts/_lib/config.sh"

dec="$(iroha_decisions_md_path "$cwd")"
if [ ! -f "$dec" ]; then
  echo "（このプロジェクトのローカル決定ログはまだありません。/iroha-for-notion:save-session で蓄積されます）"
  exit 0
fi

# Print each "## ..." decision block whose text matches the query (case-insensitive
# substring; no regex, so the query is taken literally).
awk -v q="$query" '
  BEGIN { ql = tolower(q) }
  /^## / {
    if (NR > 1 && hit) printf "%s\n\n", buf
    buf = $0; hit = (index(tolower($0), ql) > 0); next
  }
  { buf = buf "\n" $0; if (index(tolower($0), ql) > 0) hit = 1 }
  END { if (hit) print buf }
' "$dec"
