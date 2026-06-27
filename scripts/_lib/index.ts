// index.ts — local enumeration index for iroha memory (the completeness layer search lacks).
//
// On the Notion FREE plan, `query-data-sources` is paid, so the Decisions / Sessions DBs
// cannot be enumerated — only `notion-search` (semantic top-N) and `notion-fetch` (one page)
// work. That makes reliable dedup, supersede checks, and honest abstention impossible:
// you cannot reason about a set you cannot list. This keeps a tiny NDJSON index of KEYS ONLY
// (no content — Notion remains the single source of truth for content) so those operations
// see the COMPLETE set, not just search's top-N.
//
// Lives in the repo at <root>/.iroha/index.ndjson (committed, shared with the team like the
// State mirror). One JSON object per line:
//   {type, id, topic, status, date, title, project, text, supersedes}.
//   type    "decision" | "session"
//   id      the Notion page id (the upsert key)
//   topic   for decisions, the "<topic>" prefix of "<topic>: <choice>" (the dedup key)
//   status  "Active" | "Superseded" (decisions) / "Complete" | "WIP" | "Interrupted" (sessions)
//   supersedes  for decisions, the bare id of the immediate predecessor this decision REPLACED
//           (empty -> the key is omitted). This makes the supersede LINEAGE walkable offline:
//           /iroha:history starts at the current Active decision and follows `supersedes` back.
//   text    a short SEARCH SNIPPET (decision rationale / session summary, ~160 chars) — the
//           lexical-recall key for search.ts. DERIVED (regenerated each save), NOT canonical.

import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

export interface IndexRecord {
  type: string;
  id: string;
  topic: string;
  status: string;
  date: string;
  title: string;
  project: string;
  text: string;
  supersedes?: string;
}

export function indexPath(root: string): string {
  return join(root, ".iroha", "index.ndjson");
}

// Read + parse the index, skipping malformed lines (tolerant, like jq with 2>/dev/null — but it
// keeps lines AFTER a broken one too, where a streaming jq parse would stop).
export function indexRead(root: string): Record<string, unknown>[] {
  const f = indexPath(root);
  if (!existsSync(f)) return [];
  const out: Record<string, unknown>[] = [];
  for (const line of readFileSync(f, "utf8").split("\n")) {
    if (line.trim() === "") continue;
    try {
      out.push(JSON.parse(line) as Record<string, unknown>);
    } catch {
      // skip a truncated / malformed line rather than failing the whole read.
    }
  }
  return out;
}

function writeLines(root: string, lines: string[]): void {
  const f = indexPath(root);
  mkdirSync(dirname(f), { recursive: true });
  const tmp = join(tmpdir(), `iroha-idx.${process.pid}.${Date.now()}`);
  writeFileSync(tmp, lines.length ? `${lines.join("\n")}\n` : "");
  renameSync(tmp, f);
}

// Upsert by id: drop any existing line with the same id, then append the new one (so a status
// change — e.g. Active -> Superseded — replaces in place rather than duplicating).
export function indexUpsert(
  root: string,
  type: string,
  id: string,
  topic: string,
  status: string,
  date: string,
  title = "",
  project = "",
  text = "",
  supersedes = "",
): void {
  const rec: IndexRecord = {
    type,
    id,
    topic,
    status,
    date,
    title,
    project,
    text,
  };
  if (supersedes !== "") rec.supersedes = supersedes;
  const kept = indexRead(root)
    .filter((r) => r.id !== id)
    .map((r) => JSON.stringify(r));
  kept.push(JSON.stringify(rec));
  writeLines(root, kept);
}

// ASCII-only downcase (matches jq's ascii_downcase — non-ASCII, e.g. Japanese, is left as-is).
function asciiDowncase(s: string): string {
  return s.replace(/[A-Z]/g, (c) => c.toLowerCase());
}

// Matching decision lines for a topic (any status). The dedup/supersede key is the topic;
// case-insensitive on ASCII.
export function indexFindTopic(
  root: string,
  topic: string,
): Record<string, unknown>[] {
  const t = asciiDowncase(topic);
  return indexRead(root).filter(
    (r) => r.type === "decision" && asciiDowncase(String(r.topic ?? "")) === t,
  );
}

// The supersede LINEAGE starting at <id>, newest first: <id>, then the predecessor it replaced
// (via .supersedes), and so on. Bounded (a malformed cycle / long chain cannot loop forever).
export function indexChain(
  root: string,
  id: string,
): Record<string, unknown>[] {
  const recs = indexRead(root);
  const out: Record<string, unknown>[] = [];
  let cur = id;
  let n = 0;
  while (cur !== "" && n < 50) {
    const rec = recs.find((r) => r.type === "decision" && r.id === cur);
    if (!rec) break;
    out.push(rec);
    cur = typeof rec.supersedes === "string" ? rec.supersedes : "";
    n += 1;
  }
  return out;
}

// All lines, optionally filtered by type. The completeness primitive audit uses to enumerate the
// full set (then reconcile each id against Notion), instead of trusting search's partial recall.
export function indexList(root: string, type = ""): Record<string, unknown>[] {
  const recs = indexRead(root);
  return type === "" ? recs : recs.filter((r) => r.type === type);
}

// CLI: usable from skills as `bun index.ts <cmd> ...`. Each case returns the process exit code.
function runCli(): number {
  const [cmd, ...rest] = process.argv.slice(2);
  const emit = (recs: Record<string, unknown>[]) => {
    for (const r of recs) process.stdout.write(`${JSON.stringify(r)}\n`);
  };
  switch (cmd) {
    case "path":
      process.stdout.write(indexPath(rest[0] ?? ""));
      return 0;
    case "upsert":
      indexUpsert(
        rest[0] ?? "",
        rest[1] ?? "",
        rest[2] ?? "",
        rest[3] ?? "",
        rest[4] ?? "",
        rest[5] ?? "",
        rest[6] ?? "",
        rest[7] ?? "",
        rest[8] ?? "",
        rest[9] ?? "",
      );
      return 0;
    case "find-topic":
      emit(indexFindTopic(rest[0] ?? "", rest[1] ?? ""));
      return 0;
    case "chain":
      emit(indexChain(rest[0] ?? "", rest[1] ?? ""));
      return 0;
    case "list":
      emit(indexList(rest[0] ?? "", rest[1] ?? ""));
      return 0;
    default:
      process.stderr.write(
        "usage: index.ts <path|upsert|find-topic|chain|list> ...\n",
      );
      return 2;
  }
}

if (import.meta.main) process.exit(runCli());
