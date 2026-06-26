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
# State mirror). One JSON object per line:
#   {type, id, topic, status, date, title, project, text, supersedes}.
#   type    "decision" | "session"
#   id      the Notion page id (the upsert key)
#   topic   for decisions, the "<topic>" prefix of "<topic>: <choice>" (the dedup key)
#   status  "Active" | "Superseded" (decisions) / "Complete" | "WIP" | "Interrupted" (sessions)
#   supersedes  for decisions, the bare id of the immediate predecessor this decision REPLACED
#           (empty for an original decision). This makes the supersede LINEAGE walkable offline:
#           /iroha:history starts at the current Active decision for a topic and follows
#           `supersedes` back through "X -> Y -> Z" to show how (and why) the choice evolved. The
#           Notion side carries the same edge as a `Supersedes` URL property (URL-linked, like the
#           Session<->Decision link, to dodge the MCP relation-write bug). Optional / backward-
#           compatible: old rows without it simply have no recorded predecessor.
#   text    a short SEARCH SNIPPET (decision rationale / session summary, ~160 chars) — the
#           lexical-recall key for search.sh. It is a DERIVED key, regenerated on every save
#           (like an embedding would be), NOT canonical content: recall still fetches the full
#           text from Notion, so this cannot become a drifting second source of truth. It exists
#           because matching a prompt against the title alone misses rationale-level terms (e.g.
#           "do we need an API token?" should surface "Notion: MCP only", whose reason is the
#           token, not the title). Optional / backward-compatible: old rows without it match on
#           title+topic only.
# Sourceable library + CLI. Pure jq over a small file, no network.
set -u

# iroha_index_path <repo-root>  -> the repo-committed index file.
iroha_index_path() { printf '%s/.iroha/index.ndjson' "$1"; }

# iroha_index_upsert <root> <type> <id> <topic> <status> <date> [title] [project] [text] [supersedes]
# Upsert by id: drop any existing line with the same id, then append the new one (so a
# status change — e.g. Active -> Superseded — replaces in place rather than duplicating).
iroha_index_upsert() {
  local root="$1" type="$2" id="$3" topic="$4" status="$5" date="$6" title="${7:-}" project="${8:-}" text="${9:-}" supersedes="${10:-}"
  local f tmp line
  f="$(iroha_index_path "$root")"
  mkdir -p "$(dirname "$f")"
  [ -f "$f" ] || : >"$f"
  line=$(jq -nc \
    --arg type "$type" --arg id "$id" --arg topic "$topic" --arg status "$status" \
    --arg date "$date" --arg title "$title" --arg project "$project" --arg text "$text" \
    --arg supersedes "$supersedes" \
    '{type:$type,id:$id,topic:$topic,status:$status,date:$date,title:$title,project:$project,text:$text}
     + (if $supersedes=="" then {} else {supersedes:$supersedes} end)') || return 1
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

# iroha_index_chain <root> <id>  -> the supersede LINEAGE starting at <id>, newest first: <id>,
# then the predecessor it replaced (via .supersedes), and so on back to the original decision.
# One decision JSON per line. Bounded (a malformed cycle / long chain cannot loop forever) so it is
# safe to call from a skill. This is the offline primitive /iroha:history walks to show "X -> Y -> Z".
iroha_index_chain() {
  local root="$1" id="$2" f cur rec n=0
  f="$(iroha_index_path "$root")"
  [ -f "$f" ] || return 0
  cur="$id"
  while [ -n "$cur" ] && [ "$n" -lt 50 ]; do
    rec=$(jq -c --arg i "$cur" 'select(.type=="decision" and .id==$i)' "$f" 2>/dev/null | head -1)
    [ -z "$rec" ] && break
    printf '%s\n' "$rec"
    cur=$(printf '%s' "$rec" | jq -r '.supersedes // ""' 2>/dev/null)
    n=$((n + 1))
  done
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
    chain)      iroha_index_chain "$@" ;;
    list)       iroha_index_list "$@" ;;
    *)
      echo "usage: index.sh <path|upsert|find-topic|chain|list> ..." >&2
      exit 2
      ;;
  esac
fi
