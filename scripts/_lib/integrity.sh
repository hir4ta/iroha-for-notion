#!/usr/bin/env bash
# integrity.sh — deterministic, OFFLINE self-monitoring of the iroha memory substrate.
#
# A living memory's trust depends on its enumeration index being complete and internally
# consistent. Dogfooding surfaced two silent rot classes the prior self-checks missed: (1) the
# local keys-only index drifting out of sync with Notion (Active decisions present in Notion but
# absent from the index — so proactive recall and audit silently under-enumerate), and (2) the
# State mirror advancing past the newest saved Session (a memory hole: State describes work that
# was never captured as a Session). The skill-level `audit` needs Notion to catch the *count*
# side of (1); THIS catches everything checkable OFFLINE from the committed repo files, so it can
# run in selftest + CI + pre-push and a corrupt substrate can never reach green.
#
# The complementary network check (index row count vs the Notion DB count) lives in the `audit`
# skill, which can reach Notion; this file is the deterministic floor that runs with no network.
#
# Checks (pure bash + jq over <root>/.iroha/{index.ndjson,state.md}; no network):
#   1. index.ndjson parses — every non-empty line is valid JSON carrying at least {type,id}.
#   2. no duplicate ids (the upsert key) in the index — a dup means an upsert failed to replace.
#   3. no two Active decisions sharing a <topic> — the duplicate-Active rot (the defect that most
#      degrades recall). Promoted here from the audit skill into a tested, always-on guard.
#   4. State <-> index linkage — every page id linked from State's "## Recent sessions" block
#      resolves to a session row in the index. A dangling State->session link means State points
#      at work that was never indexed/saved: the memory-hole class (2).
#
# Usage: integrity.sh <repo-root>   (exit 0 = clean; exit 1 = issues printed, one per line)
set -u

# iroha_integrity <root>  -> 0 clean / 1 issues (each printed on its own line).
iroha_integrity() {
  local root="$1" issues=0 idx state
  idx="$root/.iroha/index.ndjson"
  state="$root/.iroha/state.md"

  # No index yet (fresh project) is not a failure — there is simply nothing to check.
  if [ ! -f "$idx" ]; then
    return 0
  fi

  # 1. Every non-empty line must be valid JSON with {type,id}. fromjson? would silently swallow a
  #    broken line elsewhere; here we WANT to flag it, so parse line-by-line and report the number.
  local bad
  bad=$(jq -rn --rawfile f "$idx" '
    ($f | split("\n") | map(select(length>0))) as $lines
    | [ range(0; ($lines|length)) as $i
        | ($lines[$i] | try (fromjson | if (.type and .id) then empty else "missing type/id" end)
                        catch "invalid JSON")
        | select(. != null) ] | length' 2>/dev/null)
  bad="${bad:-0}"
  if [ "$bad" -gt 0 ] 2>/dev/null; then
    echo "integrity: $bad malformed index line(s) (must be JSON with type+id) in $idx"
    issues=1
  fi

  # 2. Duplicate ids — the upsert key must be unique (a dup means a stale row was not replaced).
  local dupids
  dupids=$(jq -r '.id // empty' "$idx" 2>/dev/null | sort | uniq -d)
  if [ -n "$dupids" ]; then
    echo "integrity: duplicate index id(s): $(printf '%s' "$dupids" | tr '\n' ' ')"
    issues=1
  fi

  # 3. Duplicate-Active decisions on the same topic (pure jq — locale-safe for multibyte topics,
  #    unlike sort|uniq which mis-groups Japanese under some locales).
  local duptopics
  duptopics=$(jq -s -r '
    map(select(.type=="decision" and .status=="Active"))
    | group_by(.topic) | map(select(length>1)) | map(.[0].topic) | .[]' "$idx" 2>/dev/null)
  if [ -n "$duptopics" ]; then
    echo "integrity: duplicate Active decision topic(s) (one should be Superseded): $(printf '%s' "$duptopics" | tr '\n' ' ')"
    issues=1
  fi

  # 4. State -> index linkage. Extract page ids ONLY from the "## Recent sessions" block (the
  #    Decisions-DB link in the "## Decisions" block is not a session and must not be matched),
  #    normalize to bare 32-hex, and require each to exist as a session id in the index.
  if [ -f "$state" ]; then
    local linked sessions dangling
    linked=$(awk '/^## Recent sessions/{f=1; next} /^## /{f=0} f' "$state" \
      | grep -oE '[0-9a-f]{32}' | sort -u)
    if [ -n "$linked" ]; then
      sessions=$(jq -r 'select(.type=="session") | .id | gsub("-";"")' "$idx" 2>/dev/null | sort -u)
      dangling=$(comm -23 <(printf '%s\n' "$linked") <(printf '%s\n' "$sessions"))
      if [ -n "$dangling" ]; then
        echo "integrity: State 'Recent sessions' links a session missing from the index (State ahead of saved sessions): $(printf '%s' "$dangling" | tr '\n' ' ')"
        issues=1
      fi
    fi
  fi

  # 5. Supersede lineage — every decision's `supersedes` must point to an id that exists in the
  #    index. A dangling predecessor breaks the /iroha:history chain walk (and signals a bad save).
  local supref allids danglingsup
  supref=$(jq -r 'select(.type=="decision" and (.supersedes // "")!="") | .supersedes' "$idx" 2>/dev/null | sort -u)
  if [ -n "$supref" ]; then
    allids=$(jq -r '.id // empty' "$idx" 2>/dev/null | sort -u)
    danglingsup=$(comm -23 <(printf '%s\n' "$supref") <(printf '%s\n' "$allids"))
    if [ -n "$danglingsup" ]; then
      echo "integrity: decision 'supersedes' points to an id missing from the index (broken lineage): $(printf '%s' "$danglingsup" | tr '\n' ' ')"
      issues=1
    fi
  fi

  [ "$issues" -eq 0 ]
}

# CLI: usable from skills/hooks/CI as `bash integrity.sh <root>`. Guarded so sourcing is a no-op.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  command -v jq >/dev/null 2>&1 || { echo "integrity.sh: jq is required" >&2; exit 1; }
  iroha_integrity "${1:-$PWD}"
fi
