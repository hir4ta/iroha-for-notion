#!/usr/bin/env bash
# config.sh — read/write the plugin's persisted config (Notion DB / page ids).
# Lives at ${CLAUDE_PLUGIN_DATA}/config.json (the plugin's persistent data dir).
# Sourceable library: pure jq over a small JSON file, no network. Holds only
# non-secret ids (auth is handled by the Notion MCP OAuth connection).
#
#   { "container_page_id": "...", "session_db_id": "...", "decisions_db_id": "...",
#     "state_pages": { "<project-key>": "<page_id>", ... } }
set -u

iroha_config_path() {
  # Stable per-user location: same path whether invoked from a skill, a hook, or the
  # CLI, and it survives plugin reinstalls. Override with IROHA_CONFIG_DIR for tests.
  local base="${IROHA_CONFIG_DIR:-$HOME/.iroha-for-notion}"
  printf '%s/config.json' "$base"
}

# Create the file with an empty skeleton if missing; echo its path.
iroha_config_ensure() {
  local f
  f="$(iroha_config_path)"
  if [ ! -f "$f" ]; then
    mkdir -p "$(dirname "$f")"
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

# iroha_decisions_md_path <project-root>  -> the project's decision log, kept IN THE REPO
# (<root>/.iroha/decisions.md). Committed so the whole team has an offline recall grep
# fallback (Notion search is the primary recall). Commit this file.
iroha_decisions_md_path() { printf '%s/.iroha/decisions.md' "$1"; }

# CLI: usable from skills as `bash config.sh <cmd> ...`. Guarded so sourcing is a no-op.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  case "${1:-}" in
    state-md-path) iroha_state_md_path "${2:-}" ;;
    decisions-md-path) iroha_decisions_md_path "${2:-}" ;;
    saved-dir) iroha_saved_dir ;;
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
