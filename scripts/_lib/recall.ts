// recall.ts — the shared LOCAL recall used by the proactive hooks (recall-inject, check-inject).
//
// ONE always-on tier: a dependency-free BM25 over the keys-only index (scripts/_lib/search.ts). No
// LLM, no network, no model — instant and offline, which is exactly what a per-prompt UserPromptSubmit
// hook needs. A per-prompt LLM/agent recall was tried and removed (cost / latency / rate-competition
// with the live session / misfire on non-user turns), so this stage stays purely lexical. Deep
// SEMANTIC recall is the explicit /iroha:recall skill (Notion's own free semantic search over the
// canonical data), NOT a local embedding/reranker model tier.
//
// Output: ranked SearchHit records, best first (advisory; an empty list = honest silence).

import { indexList } from "./index.ts";
import { type SearchHit, search } from "./search.ts";

// recallLocal(root, query, topn) -> BM25-ranked records. search() reads the index and returns [] for
// an empty index/query, so this is a thin, centralizing wrapper (one place owns the score floor AND
// the cold-start corpus gate, so BOTH proactive hooks — recall-inject and check-inject — inherit them).
export function recallLocal(
  root: string,
  query: string,
  topn = 3,
): SearchHit[] {
  // Cold-start corpus gate. On a tiny index BM25's IDF is miscalibrated: a genuinely relevant match
  // can score BELOW the floor while a coincidental cross-domain match (shared project vocabulary)
  // scores high — measured on a 5-row corpus, a relevant query landed at ~0.96 (< floor 1.2, a MISS)
  // while an unrelated query hit ~5.5 (a false inject). Until the corpus is big enough for IDF to
  // separate signal from coincidence, the proactive tier stays SILENT rather than confidently wrong
  // (explicit /iroha:recall still works on any corpus size). This is a SIZE gate, NOT a floor raise
  // or a per-query coverage gate — both of which architecture.md (recall-sacrosanct) rejects because
  // they permanently trade away real single-strong-term recall. This one disables nothing once the
  // corpus is adequate; it self-lifts as memory grows (and /iroha:decide grows it faster). Default 8;
  // tune with IROHA_RECALL_MIN_CORPUS (1 = effectively off).
  const minRaw = Number(process.env.IROHA_RECALL_MIN_CORPUS ?? "8");
  const minCorpus = Number.isFinite(minRaw)
    ? Math.max(1, Math.floor(minRaw))
    : 8;
  if (indexList(root).length < minCorpus) return [];

  // A non-numeric IROHA_RECALL_MINSCORE → NaN, and `score < NaN` is always false, which silently
  // DISABLES the floor (weak partial matches then leak into proactive injection). Guard to the default.
  const raw = Number(process.env.IROHA_RECALL_MINSCORE ?? "1.2");
  const minscore = Number.isFinite(raw) ? raw : 1.2;
  return search(root, query, "", topn, minscore);
}

// CLI: `bun recall.ts <root> <query> [topn]`. One compact JSON hit per line.
if (import.meta.main) {
  const [root, query, topn] = process.argv.slice(2);
  const hits = recallLocal(root ?? "", query ?? "", topn ? Number(topn) : 3);
  for (const h of hits) process.stdout.write(`${JSON.stringify(h)}\n`);
}
