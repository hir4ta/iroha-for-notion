#!/usr/bin/env bash
# index.sh — local enumeration index for iroha memory (the completeness layer search lacks).
#
# On the Notion FREE plan, `query-data-sources` is paid, so the Decisions / Sessions DBs
# cannot be enumerated — only `notion-search` (semantic top-N) and `notion-fetch` (one page)
# work. That makes reliable dedup, supersede checks, and honest abstention impossible:
# you cannot reason about a set you cannot list. This keeps a tiny NDJSON index of KEYS ONLY
# (no content — Notion remains the single source of truth for content) so those operations
# see the COMPLETE set, not just search's top-N.
#
# Lives in the repo at <root>/.iroha/index.ndjson (committed, shared with the team like the
# State mirror). One JSON object per line: {type, id, topic, status, date, title, project}.
#   type    "decision" | "session"
#   id      the Notion page id (the upsert key)
#   topic   for decisions, the "<topic>" prefix of "<topic>: <choice>" (the dedup key)
#   status  "Active" | "Superseded" (decisions) / "Complete" | "WIP" | "Interrupted" (sessions)
# Sourceable library + CLI. Pure jq over a small file, no network.
set -u

# iroha_index_path <repo-root>  -> the repo-committed index file.
iroha_index_path() { printf '%s/.iroha/index.ndjson' "$1"; }

# iroha_index_upsert <root> <type> <id> <topic> <status> <date> [title] [project]
# Upsert by id: drop any existing line with the same id, then append the new one (so a
# status change — e.g. Active -> Superseded — replaces in place rather than duplicating).
iroha_index_upsert() {
  local root="$1" type="$2" id="$3" topic="$4" status="$5" date="$6" title="${7:-}" project="${8:-}"
  local f tmp line
  f="$(iroha_index_path "$root")"
  mkdir -p "$(dirname "$f")"
  [ -f "$f" ] || : >"$f"
  line=$(jq -nc \
    --arg type "$type" --arg id "$id" --arg topic "$topic" --arg status "$status" \
    --arg date "$date" --arg title "$title" --arg project "$project" \
    '{type:$type,id:$id,topic:$topic,status:$status,date:$date,title:$title,project:$project}') || return 1
  tmp="$(mktemp "${TMPDIR:-/tmp}/iroha-idx.XXXXXX")"
  # Keep every line whose id differs (tolerant of malformed lines via the 2>/dev/null), then
  # append the fresh record. fromjson? guards a half-written last line from killing the rewrite.
  jq -c --arg id "$id" 'select(.id != $id)' "$f" 2>/dev/null >"$tmp" || true
  printf '%s\n' "$line" >>"$tmp"
  mv "$tmp" "$f"
}

# iroha_index_find_topic <root> <topic>  -> matching decision lines (any status).
# The dedup/supersede key is the decision topic; this is how save-session sees whether a
# topic already has a row WITHOUT enumerating Notion. Case-insensitive on ASCII.
iroha_index_find_topic() {
  local root="$1" topic="$2" f
  f="$(iroha_index_path "$root")"
  [ -f "$f" ] || return 0
  jq -c --arg t "$topic" \
    'select(.type=="decision" and (.topic|ascii_downcase)==($t|ascii_downcase))' "$f" 2>/dev/null
}

# iroha_index_list <root> [type]  -> all lines, optionally filtered by type.
# This is the completeness primitive audit uses to enumerate the full set (then reconcile
# each id against Notion), instead of trusting search's partial recall.
iroha_index_list() {
  local root="$1" type="${2:-}" f
  f="$(iroha_index_path "$root")"
  [ -f "$f" ] || return 0
  if [ -n "$type" ]; then
    jq -c --arg t "$type" 'select(.type==$t)' "$f" 2>/dev/null
  else
    jq -c '.' "$f" 2>/dev/null
  fi
}

# CLI: usable from skills as `bash index.sh <cmd> ...`. Guarded so sourcing is a no-op.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  command -v jq >/dev/null 2>&1 || { echo "index.sh: jq is required" >&2; exit 1; }
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    path)       iroha_index_path "${1:-}" ;;
    upsert)     iroha_index_upsert "$@" ;;
    find-topic) iroha_index_find_topic "$@" ;;
    list)       iroha_index_list "$@" ;;
    *)
      echo "usage: index.sh <path|upsert|find-topic|list> ..." >&2
      exit 2
      ;;
  esac
fi
