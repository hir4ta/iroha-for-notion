#!/usr/bin/env bash
# config.sh — read/write the plugin's persisted config (Notion DB / page ids).
# Lives at $HOME/.iroha-for-notion/config.json (override the dir with IROHA_CONFIG_DIR).
# Sourceable library: pure jq over a small JSON file, no network. Holds only
# non-secret ids (auth is handled by the Notion MCP OAuth connection):
#
#   { "container_page_id": "...",
#     "session_db_id": "...",   "session_ds_id": "...",
#     "decisions_db_id": "...", "decisions_ds_id": "...",
#     "projects_db_id": "...",  "projects_ds_id": "...",
#     "state_pages": { "<project-key>": "<page_id>", ... } }
set -u

iroha_config_path() {
  # Stable per-user location: same path whether invoked from a skill, a hook, or the
  # CLI, and it survives plugin reinstalls. Override with IROHA_CONFIG_DIR for tests.
  local base="${IROHA_CONFIG_DIR:-$HOME/.iroha-for-notion}"
  printf '%s/config.json' "$base"
}

# Create the file with an empty skeleton if missing or corrupt; echo its path. A
# corrupt config.json (e.g. an interrupted write) is backed up and reset, so get/set
# and /iroha:init recover instead of failing forever.
iroha_config_ensure() {
  local f
  f="$(iroha_config_path)"
  mkdir -p "$(dirname "$f")"
  if [ ! -f "$f" ]; then
    printf '{"state_pages":{}}\n' >"$f"
  elif ! jq -e . "$f" >/dev/null 2>&1; then
    mv "$f" "$f.corrupt.$$" 2>/dev/null || true
    printf '{"state_pages":{}}\n' >"$f"
  fi
  printf '%s' "$f"
}

# iroha_config_get <key>  -> value or empty
iroha_config_get() {
  local f
  f="$(iroha_config_ensure)"
  jq -r --arg k "$1" '.[$k] // empty' "$f"
}

# iroha_config_set <key> <value>
iroha_config_set() {
  local f tmp
  f="$(iroha_config_ensure)"
  tmp="$(mktemp "${TMPDIR:-/tmp}/iroha-cfg.XXXXXX")"
  jq --arg k "$1" --arg v "$2" '.[$k] = $v' "$f" >"$tmp" && mv "$tmp" "$f"
}

# iroha_config_get_state_page <project-key>  -> page id or empty
iroha_config_get_state_page() {
  local f
  f="$(iroha_config_ensure)"
  jq -r --arg p "$1" '.state_pages[$p] // empty' "$f"
}

# iroha_config_set_state_page <project-key> <page-id>
iroha_config_set_state_page() {
  local f tmp
  f="$(iroha_config_ensure)"
  tmp="$(mktemp "${TMPDIR:-/tmp}/iroha-cfg.XXXXXX")"
  jq --arg p "$1" --arg id "$2" '.state_pages[$p] = $id' "$f" >"$tmp" && mv "$tmp" "$f"
}

# iroha_state_md_path <project-root>  -> the project's State mirror, kept IN THE REPO
# (<root>/.iroha/state.md). Committed so a teammate who pulls it gets the latest State
# injected by their SessionStart hook, which cannot reach Notion. Commit this file.
iroha_state_md_path() { printf '%s/.iroha/state.md' "$1"; }

# iroha_saved_dir  -> directory of per-session "saved" markers (per-machine, in $HOME).
iroha_saved_dir() { printf '%s/saved' "$(dirname "$(iroha_config_path)")"; }

# iroha_transcript_path <project-root> <session-id>  -> this session's transcript JSONL, or empty.
# Claude Code stores it at $HOME/.claude/projects/<root-with-each-/-as-->/<session-id>.jsonl.
# Resolve that path DETERMINISTICALLY (no glob); only if the project root moved since launch do we
# fall back to a BOUNDED find by session id. (save-session used to locate it with
# `ls -t "$HOME/.claude/projects/"*"/<sid>.jsonl"` — a glob over every project dir that was observed
# to return empty and then hang for ~2 min; the deterministic path is instant and never globs.)
iroha_transcript_path() {
  local root="$1" sid="$2" projdir p
  projdir="$HOME/.claude/projects/$(printf '%s' "$root" | sed 's#/#-#g')"
  p="$projdir/$sid.jsonl"
  if [ -f "$p" ]; then printf '%s' "$p"; return 0; fi
  find "$HOME/.claude/projects" -maxdepth 2 -name "$sid.jsonl" -print 2>/dev/null | head -1
}

# CLI: usable from skills as `bash config.sh <cmd> ...`. Guarded so sourcing is a no-op.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  case "${1:-}" in
    state-md-path) iroha_state_md_path "${2:-}" ;;
    saved-dir) iroha_saved_dir ;;
    transcript-path) iroha_transcript_path "${2:-}" "${3:-}" ;;
    get) iroha_config_get "${2:-}" ;;
    set) iroha_config_set "${2:-}" "${3:-}" ;;
    get-state) iroha_config_get_state_page "${2:-}" ;;
    set-state) iroha_config_set_state_page "${2:-}" "${3:-}" ;;
    path) iroha_config_path ;;
    *)
      echo "usage: config.sh <get|set|get-state|set-state|path> ..." >&2
      exit 2
      ;;
  esac
fi
