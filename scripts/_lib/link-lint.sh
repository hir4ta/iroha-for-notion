#!/usr/bin/env bash
# link-lint.sh — deterministic guard against Notion auto-linkifying bare file/command/path tokens.
#
# Notion turns a bare `foo.sh` / `CLAUDE.md` / `.iroha/state.md` in BODY text into a bogus
# `http://foo.sh` link (it grabs the surrounding run, sometimes a whole sentence). The fix is to
# wrap every file / command / path in backticks — the save / init / project / digest skills all
# say so, but that is human diligence and it recurs every save (it bit the Session page and the
# container callout). This lints the to-be-published Markdown and FAILS if a risky token sits
# OUTSIDE a backtick span / fenced code block / explicit [text](url) link, so a leak-prone page is
# caught BEFORE it reaches Notion — the same gate role `state-lint.sh` plays for the \n/\t leak.
#
# It only flags FILE/PATH-shaped tokens (a token ending in a known code/text extension), which is
# the class Notion mis-linkifies; bare prose and real URLs are left alone to avoid false positives.
#
# Usage: link-lint.sh <file>     (or pipe Markdown on stdin)
#   exit 0 = clean   ·   exit 1 = offenders printed to stderr (wrap each in backticks, re-lint)
set -u

# iroha_link_lint  — reads Markdown on stdin, prints offending tokens (one per line), returns 1 if any.
iroha_link_lint() {
  # SC2016: the single-quoted sed/awk/grep scripts use literal `, $, etc. on purpose (no shell
  # expansion wanted) — that is the whole point, so silence the "expressions don't expand" info.
  # shellcheck disable=SC2016
  awk '
    # toggle in/out of fenced code blocks (``` ... ```, incl ```mermaid); drop fenced lines.
    /^[[:space:]]*```/ { infence = !infence; next }
    !infence { print }
  ' \
  | sed -E 's/`[^`]*`//g' \
  | sed -E 's/\[[^]]*\]\([^)]*\)//g' \
  | grep -oE '[A-Za-z0-9._/~+-]+\.(sh|md|json|jsonl|ya?ml|toml|tsx?|jsx?|mjs|cjs|py|go|rs|txt|sql|lock|env|cfg|ini|svg)\b' \
  | sort -u
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  src="${1:-/dev/stdin}"
  offenders="$(iroha_link_lint <"$src")"
  if [ -n "$offenders" ]; then
    {
      echo "link-lint: un-backticked file/path token(s) — Notion will auto-linkify these to http://… ;"
      echo "wrap each in backticks (or rephrase) and re-lint until clean:"
      printf '  %s\n' "$offenders"
    } >&2
    exit 1
  fi
  exit 0
fi
