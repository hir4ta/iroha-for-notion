# save-session — design rationale

The procedure lives in `SKILL.md`; this file holds the *why* behind a few of its steps so the skill
itself stays a scannable checklist. Read this when you want the reasoning — not when you are
executing a save (every imperative step, every bash block, and every inline pitfall warning stays in
`SKILL.md`).

## Why the local index is keys + a derived snippet, not the content

`SKILL.md` §6 writes a `≤160`-char rationale condensation into the index, never the full decision
body. That is deliberate:

- **Notion stays the single source of truth.** The snippet is regenerated on every save (like an
  embedding would be), so it cannot drift into a second truth; recall always fetches the full
  `Rationale` / `Alternatives` from Notion via `notion-fetch`.
- **It exists for two jobs the content could not do better:** (a) dedup / supersede / audit can
  enumerate the *complete* decision set that the free-plan `notion-search` cannot list, and (b) the
  local BM25 recall (`search.ts`, the always-on first stage in the `UserPromptSubmit` hook) can match
  a prompt against the *reason* a decision was made — not just its title. Matching the title alone
  misses "do we need an API token?" → "Notion: MCP only", whose reason is the token, not the title.

## Why State is single-source (the mirror and Notion are one artifact)

`SKILL.md` §8 composes the State body once and writes the *identical* text to both the repo mirror
(`.iroha/state.md`) and the Notion State page. Authoring it twice is what lets them drift: a past
save composed them separately and the Notion page degraded to a summary-only callout with literal
`\n` / `\t` escapes leaking in as `nt…n`, while the mirror stayed fine. Single-source makes that
failure impossible — and because the mirror is lint-gated (`state-lint` / `link-lint`), a clean
mirror *is* a clean Notion page.
