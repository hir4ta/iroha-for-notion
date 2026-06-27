// recall.ts — the shared LOCAL recall orchestration: BM25 (always) ∪ dense (opt-in), reranker as a
// PROMOTER (opt-in). One code path, used by BOTH the UserPromptSubmit hook (hooks/recall-inject)
// AND the quality oracle (tests/hybrid-eval), so the eval measures exactly what production does.
//
//   FREE tier  (default, no deps):   BM25 over the keys-only index (scripts/_lib/search.ts).
//   HEAVY tier (opt-in, armed):      BM25 hits ∪ DENSE candidates (scripts/embed.mjs); the
//                                    cross-encoder reranker (scripts/rerank.mjs) PROMOTES the strong
//                                    (dense-discovered) matches above the BM25 advisory list.
//
// Why the reranker promotes but never vetoes. Measured on this corpus the cross-encoder is bimodal:
// a near-paraphrase scores >0.4, but a terse, real, lexically-strong match scores ~0.003 —
// indistinguishable from an off-topic pair. So using the reranker as a VETO drops genuine BM25 hits
// (a measured recall regression). The fix: BM25 lexical hits are sacrosanct (recall is the north
// star); the reranker only LIFTS high-confidence semantic matches the dense lane surfaced above
// them. Result: hybrid recall >= BM25 recall, monotonically.
//
// Abstention is preserved: a true cross-domain prompt yields no BM25 lexical hit AND no dense
// candidate clears the reranker's "strong" threshold -> empty -> honest silence.
//
// Output: one compact JSON object per line, best first: {score,type,id,topic,status,date,title}.

import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { configGet } from "./config.ts";
import { indexRead } from "./index.ts";
import { type SearchHit, search } from "./search.ts";

const SCRIPTS = join(import.meta.dir, "..");

function modelDir(): string {
  return (
    process.env.IROHA_MODEL_DIR ||
    join(process.env.HOME ?? "", ".iroha", "models")
  );
}

// Run a model script (embed.mjs / rerank.mjs) via node, feeding `payload` on stdin. Returns the
// parsed JSON array, or null on any failure (missing model -> exit 3, parse error, node absent).
function runModel(scriptBasename: string, payload: unknown): unknown[] | null {
  const res = spawnSync("node", [join(SCRIPTS, scriptBasename)], {
    input: JSON.stringify(payload),
    encoding: "utf8",
    env: { ...process.env, IROHA_MODEL_DIR: modelDir() },
  });
  if (res.status !== 0 || !res.stdout) return null;
  try {
    const v = JSON.parse(res.stdout);
    return Array.isArray(v) ? v : null;
  } catch {
    return null;
  }
}

function docText(r: Record<string, unknown>): string {
  return [r.title, r.topic, r.text]
    .filter((x): x is string => typeof x === "string" && x !== "")
    .join(" ");
}

function uniq(ids: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const id of ids) {
    if (id === "" || seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  return out;
}

// recallLocal(root, query, topn) -> ranked records (BM25 advisory, optionally heavy-promoted).
export function recallLocal(
  root: string,
  query: string,
  topn = 3,
): SearchHit[] {
  if (indexRead(root).length === 0) return [];

  // Heavy tier on only when node is present AND (armed in config OR forced for eval).
  const heavy =
    process.env.IROHA_RERANK_DISABLE !== "1" &&
    Bun.which("node") !== null &&
    (configGet("rerank_enabled") === "true" ||
      process.env.IROHA_RECALL_FORCE_HEAVY === "1");

  const minscore = Number(process.env.IROHA_RECALL_MINSCORE ?? "1.2");
  // A wide net when the heavy tier will fuse/rerank; exactly topn otherwise.
  const candN = heavy
    ? Number(process.env.IROHA_RERANK_CANDIDATES ?? "8")
    : topn;
  const bmHits = search(root, query, "", candN, minscore);

  if (!heavy) return bmHits.slice(0, topn);

  const bmIds = bmHits.map((h) => h.id);
  const docs = indexRead(root).map((r) => ({
    id: String(r.id ?? ""),
    text: docText(r),
  }));

  // 2. Dense candidates (opt-in). embed.mjs ranks the WHOLE index by cosine; null -> BM25 only.
  const dense = docs.length
    ? runModel("embed.mjs", {
        query,
        docs,
        topk: Number(process.env.IROHA_DENSE_CANDIDATES ?? "8"),
      })
    : null;
  const denseIds = (dense ?? [])
    .map((d) => (d as { id?: string }).id ?? "")
    .filter((id) => id !== "");

  // 3. Candidate union (for the reranker to judge): BM25 ids first, then any new dense id.
  const unionIds = uniq([...bmIds, ...denseIds]);
  if (unionIds.length === 0) return [];

  // 4. Reranker as PROMOTER. Score the union; keep only the "strong" (>= threshold) survivors.
  const candDocs = docs.filter((d) => unionIds.includes(d.id));
  const survivors = runModel("rerank.mjs", {
    query,
    docs: candDocs,
    threshold: Number(process.env.IROHA_RERANK_THRESHOLD ?? "0.05"),
    topn: 50,
  });
  const strongIds = (survivors ?? [])
    .map((s) => (s as { id?: string }).id ?? "")
    .filter((id) => id !== "");

  // 5. Final ranking: strong semantic matches first, then the remaining BM25 hits. BM25 hits are
  //    never dropped -> recall is monotonic vs the free tier. Abstain only when BOTH are empty.
  const finalIds = uniq([...strongIds, ...bmIds]).slice(0, topn);
  if (finalIds.length === 0) return [];

  // Emit full records in final order; carry the rerank score when strong, else the BM25 score.
  const byId = new Map(indexRead(root).map((r) => [String(r.id ?? ""), r]));
  const scoreById = new Map<string, number>();
  for (const h of bmHits) scoreById.set(h.id, h.score);
  for (const s of survivors ?? []) {
    const o = s as { id?: string; score?: number };
    if (o.id) scoreById.set(o.id, o.score ?? 0);
  }
  const out: SearchHit[] = [];
  for (const id of finalIds) {
    const r = byId.get(id);
    if (!r) continue;
    out.push({
      score: scoreById.get(id) ?? 0,
      type: String(r.type ?? ""),
      id: String(r.id ?? ""),
      topic: String(r.topic ?? ""),
      status: String(r.status ?? ""),
      date: String(r.date ?? ""),
      title: String(r.title ?? ""),
    });
  }
  return out;
}

// CLI: `bun recall.ts <root> <query> [topn]`. One compact JSON hit per line.
if (import.meta.main) {
  const [root, query, topn] = process.argv.slice(2);
  const hits = recallLocal(root ?? "", query ?? "", topn ? Number(topn) : 3);
  for (const h of hits) process.stdout.write(`${JSON.stringify(h)}\n`);
}
