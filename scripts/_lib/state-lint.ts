// state-lint.ts — validate a State body BEFORE it is published to Notion / committed.
//
// Under save-session §8's single-source rule, the repo mirror <root>/.iroha/state.md is written
// ONCE and the byte-identical text is published to the Notion State page — so linting the mirror
// also validates what Notion will render. This catches the State-corruption class found while
// dogfooding (a save left the Notion State as a summary-only callout with literal \n / \t escapes
// leaking in), turning the most defect-prone write surface from "detect after the fact (audit)"
// into "prevent before write": run it in save-session before publishing, in audit as the
// deterministic escape/section check, and in selftest against the real committed mirror so a
// corrupt State can never reach CI green.
//
// Checks are LANGUAGE-INDEPENDENT (structure only — no dependence on translated heading text):
//   1. non-empty file.
//   2. no literal "\n" / "\t" two-character escape sequence OUTSIDE code — body must contain REAL
//      newlines/tabs (the leak that degraded a past State). Fenced/inline `code` is excluded first
//      (like link-lint / session-lint) so a legitimate \n / \t written inside `code` is not flagged.
//   3. the REQUIRED named "## " sections are present: Recent sessions / Unfinished / Decisions. (A
//      bare count missed a State that degraded to a summary AND a State whose section was renamed —
//      and integrity's State->index guard keys on the literal "## Recent sessions" heading, so the
//      name must be enforced here or that guard silently no-ops on a localized/renamed heading.)
//   4. a summary line before the first "## " heading (the "**Latest (...)**" one-liner).

import { existsSync, readFileSync, statSync } from "node:fs";

// The "## " sections save-session §8 writes every save — English canonical (the body lines localize,
// the headings do not), matched by name so the structure can't silently drift.
const REQUIRED_SECTIONS = ["Recent sessions", "Unfinished", "Decisions"];

// Drop fenced code blocks and strip inline `code` spans before the \n / \t leak check (link-lint's
// exclusion), so a real \n / \t inside `code` is not a false positive.
function stripCode(md: string): string {
  let inFence = false;
  const out: string[] = [];
  for (const raw of md.split("\n")) {
    if (/^[ \t]*```/.test(raw)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    out.push(raw.replace(/`[^`]*`/g, ""));
  }
  return out.join("\n");
}

// stateLint(file) -> issue strings (empty list = clean).
export function stateLint(file: string): string[] {
  const issues: string[] = [];
  if (!existsSync(file) || statSync(file).size === 0) {
    return [`state-lint: missing or empty file: ${file}`];
  }
  const body = readFileSync(file, "utf8");
  // Literal backslash-n / backslash-t (the two-character escape leak), not real newlines/tabs.
  const prose = stripCode(body);
  if (prose.includes("\\n") || prose.includes("\\t")) {
    issues.push(
      "state-lint: literal \\n or \\t escape sequence found — State must contain real newlines/tabs",
    );
  }
  const lines = body.split("\n");
  const missing = REQUIRED_SECTIONS.filter(
    (name) => !lines.some((l) => new RegExp(`^##\\s+${name}\\b`).test(l)),
  );
  if (missing.length > 0) {
    issues.push(
      `state-lint: missing required '## ' section(s): ${missing.join(", ")} — State must keep Recent sessions / Unfinished / Decisions`,
    );
  }
  // Is there a non-blank line before the first '## ' heading (the "**Latest (...)**" summary)?
  let summaryFound = false;
  for (const l of lines) {
    if (/^## /.test(l)) break;
    if (/\S/.test(l)) summaryFound = true;
  }
  if (!summaryFound) {
    issues.push("state-lint: no summary line before the first '## ' heading");
  }
  return issues;
}

// CLI: usable from skills as `bun state-lint.ts <state.md>`. Guarded so importing is a no-op.
if (import.meta.main) {
  const issues = stateLint(process.argv[2] ?? "");
  for (const line of issues) console.log(line);
  process.exit(issues.length === 0 ? 0 : 1);
}
