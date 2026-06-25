---
name: audit
description: Health-check this project's iroha memory and report (then optionally fix) the things that rot a living memory — duplicate or conflicting Active decisions, decisions that should be Superseded, State drift (stale summary / stale unfinished items carried many sessions), orphaned decisions whose Session link is broken, and Sessions missing the fixed structure. Triggers on "/iroha:audit", "audit the memory", "check memory health". Not for saving a session (use /iroha:save-session) or recalling a past decision (use /iroha:recall).
argument-hint: "[--fix]"
---

# iroha: audit

A *growing* memory only stays useful if it stays clean. audit is the guardian: it scans
the canonical Notion DBs for the failure modes that quietly degrade recall, reports them
by severity, and — only with the user's go-ahead — applies the safe fixes. All reads go
through `notion-search` (free plan); the canonical data is never duplicated locally.
Report in the **user's conversation language**.

## 1. Preconditions

```bash
L="${CLAUDE_PLUGIN_ROOT}/scripts/_lib/config.sh"; IDX="${CLAUDE_PLUGIN_ROOT}/scripts/_lib/index.sh"
bash "$L" get decisions_ds_id    # empty -> tell the user to run /iroha:init, then stop
bash "$L" get session_ds_id
bash "$L" get-state "$PWD"        # the State page id (may be empty on a fresh project)
bash "$IDX" list "$PWD" decision  # COMPLETE list of decision keys — the enumeration search lacks
bash "$IDX" list "$PWD" session   # COMPLETE list of session keys
```

## 2. Run the checks (read-only)

**Enumerate from the local index** (`index.sh list` above) — it is the *complete* set of
decision/session keys, which free-plan `notion-search` cannot reproduce. `notion-fetch` each
id that needs its content inspected, and collect findings. (If the index is empty or stale —
an older workspace created before the index existed — fall back to `notion-search` and **say
so**: results are then best-effort, not complete. Offer to backfill: fetch the known rows and
`index.sh upsert` each into the index so future audits are exhaustive.)

- **A. Duplicate Active decisions** — two `Status = Active` rows sharing the same `<topic>`
  are a conflict (one should be `Superseded`). Now **exhaustive** via the index — every
  conflicted topic, not just what search surfaced. Use **pure jq** (not `sort | uniq -d`,
  which mis-groups multibyte/Japanese topics under some locales — a real false-positive
  found while dogfooding):
  `bash "$IDX" list "$PWD" decision | jq -s 'map(select(.status=="Active"))|group_by(.topic)|map(select(length>1))|map(.[0].topic)|.[]'`
  (severity: high — the defect that most rots recall.)
- **B. Should-be-superseded** — an `Active` decision whose `Rationale` is contradicted by
  a newer `Active` decision on the same topic, or which a later Session's decisions
  reversed. Flag the older one. (high)
- **C. Orphaned decisions** — a decision whose `Session` URL is empty or does not resolve
  (`notion-fetch` 404). The "why" loses its anchor. (medium)
- **D. State drift** — `notion-fetch` the State page and compare:
  - its header summary vs the newest Session's `Summary` (stale if it names an older
    state, e.g. "2 DB" when the newest session is "3 DB"); (medium)
  - its **Recent sessions** links vs the actual newest Sessions (missing/wrong); (medium)
  - **stale unfinished** — any `- [ ]` item carried for **3+ sessions** (look for the
    `[carried Nx]` marker save-session writes, or infer from dates). (low — but nag-worthy.)
- **E. Structure drift** — a Session missing a required section (`## Metrics`,
  `## Decisions`, `## Progress`, `## Highlights`, `## Details`) or whose Highlights look
  invented (a "You" line with no matching real prompt is impossible to verify — flag
  Sessions whose Highlights read as narration rather than real exchanges). (low)
- **F. Granularity smell** — `Active` decisions that are display/naming/wording tweaks
  rather than architecture/dependency/process (they belong in a Session's decision table,
  not the Decisions DB). (low — recall signal-to-noise.)

## 3. Report (always)

Print a findings report grouped by severity, each finding with: what, where (page link),
why it hurts recall, and the suggested fix. End with a one-line health verdict
(`healthy` / `N issues` / `needs attention`). If nothing is wrong, say so plainly — a
clean audit is a real result.

## 4. Fix (only with `--fix` or explicit confirmation)

Never mutate on a bare audit. When the user passes `--fix` (or confirms after the
report), apply **only the safe, reversible** fixes and re-report each:

- **A / B** — set the older/duplicate decision's `Status = Superseded` with
  `notion-update-page` (never delete — the change of mind is itself memory). Leave the
  current one `Active`.
- **D (summary / recent)** — refresh the State page via `notion-update-page`
  `replace_content` to match the newest Session, and re-mirror to `<repo>/.iroha/state.md`
  (`bash "$L" state-md-path "$PWD"`); remind the user to commit it.
- **D (stale unfinished)** — propose dropping or re-confirming each stale `- [ ]`; apply
  the user's call.
- **C / E / F** — these need human judgment (delete? rewrite? demote?). Report them with a
  recommended action but **do not** auto-apply; ask.

## Notes

- With the local index, decision/session **enumeration is now complete** (not just search's
  top-N), so the duplicate-Active (A) and orphan (C) checks are exhaustive rather than
  heuristic. The *content* checks (B contradiction, F granularity) still need judgment via
  `notion-fetch`. Reconcile drift: if `index.sh list` and Notion disagree (an id 404s, or a
  status differs), fix the index with `index.sh upsert`. Better a flagged false positive than
  silent rot.
- Re-run after big sessions, before onboarding a teammate, or when recall starts
  returning conflicting answers.
