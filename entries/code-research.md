# code-research (deep code analysis loop)

**Category:** orchestrator · **Status:** beta · **Runtime:** multi · **Command:** `/harness:code-research`

A packaged, **read-only** harness that answers a research question about a codebase with **cited,
adversarially-verified** evidence — not a confident guess. Its defining property: every conclusion is
*earned by evidence that survived an attempt to refute it against the source*, so the report is safe
to make architecture decisions on.

Flagship use case: settle **"is `meta/Archon` a harness/agent manager?"** with evidence — the input
to the `harness-agent-rs` decision.

## How it earns its conclusions

1. **Map** (`code-research-cartographer`) — code-intelligence map (entry points, deps, interfaces,
   build/run) + decompose the question into dimensions (architecture, agent-loop model, capabilities,
   extension model, comparison-to-X).
2. **Analyze, fan-out** (`code-research-analyst`, one per dimension, parallel) — deep per-dimension
   analysis producing **falsifiable claims, each citing `file:line`** (reasoned from source, not docs).
3. **Verify, adversarial** (`code-research-verifier`) — tries to **REFUTE** each material claim against
   the code (counter-example hunt; run it where ambiguous). Only `CONFIRMED`/`QUALIFIED` survive;
   doc-vs-code overclaims get caught (e.g. "manages a fleet" with no fleet code → REFUTED).
4. **Synthesize** (`code-research-synthesizer`) — verdict-first, cited, confidence-rated report, with a
   concept map for "is it an X?" and a flagged recommendation when it feeds a decision.
5. **DONE gate** — every dimension verified + a cartographer **completeness sweep** (no major
   module/dimension unexamined) + the question answered from confirmed evidence with named gaps.

## Shape

- **Skills** (`harness/skills/`): `code-research` (orchestrator) + `code-research-map`/`-analyze`/
  `-verify` (+ shared `session-relay-wrap-up`/`-resume`, `harness-evolution`).
- **Agents** (shared `harness/agents/`): `code-research-cartographer`/`-analyst`/`-verifier`/
  `-synthesizer` (specialists) + `continuity-steward`, `evolution-steward` (shared).
- **Execution mode:** hybrid — single-orchestrator, parallel fan-out analysts + verifiers, durable
  findings ledger under `.handoff/loop/` (resumable on large codebases). Read-only on the target.

## Run / eject

- **Run in place:** `/harness:code-research` (give it a research question + target repo).
- **Eject:** `bash harness/skills/code-research/scripts/eject.sh <target-repo>` → `/code-research`.
- **External runner (SAFE, read-only):** `harness/skills/code-research/scripts/ralph-code-research.sh`.

Built per the [packaged-harness standard](../docs/packaged-harness-standard.md).
