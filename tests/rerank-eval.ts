// rerank-eval.ts — precision eval for the OPT-IN cross-encoder rerank gate (scripts/rerank.ts).
//
// The cheap BM25 stage (recall-eval) has high recall but limited precision on a small single-domain
// corpus: a prompt that merely shares the project's vocabulary lexically matches an unrelated
// decision and (measured) can outscore a genuinely relevant one — so a higher floor cannot separate
// them. The cross-encoder reranker IS the precision filter. This eval proves it on a labeled set:
// every hard-negative (off-topic but same-vocabulary) prompt must yield ZERO injected decisions,
// while real prompts still surface their decision.
//
// This requires the opt-in @huggingface/transformers dep + the local model (run in-process under Bun,
// no node). When that is absent it SKIPS with exit 0 — the dependency-free TS BM25 path (recall-eval)
// is the always-on guarantee; this is the extra precision layer, validated wherever the model is present.
//
// Run: bun tests/rerank-eval.ts   (PASS / SKIP / FAIL)

import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { indexRead } from "../scripts/_lib/index.ts";
import { rerankPromote } from "../scripts/rerank.ts";

const out = (s: string) => process.stdout.write(`${s}\n`);

// Frozen fixture corpus (shared with recall-eval / hybrid-eval), NOT the live repo index — a
// workspace re-save churns decision ids and used to drift this eval's TRUEQ labels. The snapshot
// keeps them stable; re-label only when the fixture is deliberately regenerated.
const ROOT = join(import.meta.dir, "fixtures", "recall-corpus");
const INDEX = join(ROOT, ".iroha", "index.ndjson");
const THRESHOLD = process.env.IROHA_RERANK_THRESHOLD ?? "0.05";
// rerankPromote reads IROHA_MODEL_DIR from the env; pin it (default per-user dir) before calling.
process.env.IROHA_MODEL_DIR =
  process.env.IROHA_MODEL_DIR ?? join(homedir(), ".iroha", "models");

if (!existsSync(INDEX)) {
  out("SKIP: no local index");
  process.exit(0);
}

// Probe: is the runtime+model actually usable? rerankPromote throws when the dep/model is missing.
try {
  await rerankPromote("ping", [{ id: "x", text: "ping pong" }], 0.0, 1);
} catch {
  out(
    "SKIP: rerank runtime/model not installed (run the rerank setup to enable this precision eval)",
  );
  process.exit(0);
}

const records = indexRead(ROOT);
// Candidate docs (id -> rerankable text), the same shape the hook passes.
const docs = records.map((r) => ({
  id: String(r.id ?? ""),
  text: [r.title, r.topic, r.text]
    .filter((x): x is string => typeof x === "string" && x !== "")
    .join(" "),
}));
const topicOf = (id: string): string => {
  const r = records.find((x) => x.id === id);
  return r ? `${String(r.topic ?? "")} ${String(r.title ?? "")}` : "";
};

async function rerank(query: string): Promise<string[]> {
  try {
    const survivors = await rerankPromote(query, docs, Number(THRESHOLD), 3);
    return survivors.map((s) => s.id).filter((id) => id !== "");
  } catch {
    return [];
  }
}

// TRUE prompts -> a substring the surfaced decision's topic/title must contain. ONE near-paraphrase
// per decision in the frozen fixture corpus (HEAVY実行 / 依存方針 / 保存). Each query is a paraphrase
// the cross-encoder ranks above the 0.05 promote threshold against that corpus. Re-label only when the
// fixture is deliberately regenerated (never as forced re-save fallout — that drift is now designed out).
const TRUEQ: [string, string][] = [
  [
    "transformers を node サブプロセスでなく Bun で in-process 実行する",
    "HEAVY実行",
  ],
  ["外部ライブラリを足さず依存ゼロを維持すべきか", "依存方針"],
  ["Notion 保存で API トークンを使わず本文を決定論で生成すべきか", "保存"],
];
// HARD-NEGATIVE prompts (off-topic but share the project's vocabulary) -> MUST inject nothing.
const NEGQ = [
  "Notionに画像をアップロードする方法を教えて",
  "bashスクリプトのテストをどう書くか",
  "jqでJSONをパースする方法",
  "gitのブランチ戦略を決めたい",
  "おすすめの映画を教えて",
];

out(`=== rerank precision eval (threshold=${THRESHOLD}) ===`);
let recallHit = 0;
for (const [q, want] of TRUEQ) {
  const ok = (await rerank(q)).some((id) => topicOf(id).includes(want));
  if (ok) {
    recallHit += 1;
    out(`  HIT      ${q}`);
  } else {
    out(`  miss     ${q} (wanted ${want})`);
  }
}
let falseInject = 0;
for (const q of NEGQ) {
  const n = (await rerank(q)).length;
  if (n === 0) {
    out(`  ABSTAIN  ${q}`);
  } else {
    falseInject += 1;
    out(`  LEAK(${n}) ${q}`);
  }
}

out("---");
out(
  `Recall@3 = ${recallHit}/${TRUEQ.length} · False-injection (hard negatives) = ${falseInject}/${NEGQ.length}`,
);
// The contract: ZERO false injections (precision win) AND every TRUE case surfaces its decision.
if (falseInject === 0 && recallHit >= TRUEQ.length) {
  out(
    `PASS: rerank gate holds (0 false injections, all ${TRUEQ.length} TRUE cases surfaced)`,
  );
  process.exit(0);
}
out(
  `FAIL: false_inject=${falseInject} (want 0), recall=${recallHit}/${TRUEQ.length} (want all)`,
);
process.exit(1);
