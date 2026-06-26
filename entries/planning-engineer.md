# planning-engineer (deep planning & architecture loop)

**Category:** orchestrator · **Status:** beta · **Runtime:** multi · **Command:** `/harness:planning-engineer` (single cycle) · `/harness:plan-loop` (continuous)

A packaged, **read-only** harness that turns a planning target (a crate / subsystem / feature-area)
into a **decision-grade plan** — combining deep web research, a persistent code graph, and
adversarial verification. Its defining property (inherited from `code-research`): every gap and every
recommended upgrade is *earned by evidence that survived an attempt to refute it against the source*,
so the plan is safe to act on. The continuous form (`plan-loop`) plans a whole repo
subsystem-by-subsystem until done.

## How it earns its conclusions

1. **Map + Research, fan-out** (`plan-cartographer` ‖ `plan-trend-researcher`, parallel) — a CODE
   GRAPH built **only from `git-kb code` JSON** (symbols + call edges + entry points + data-flows),
   diffed against the previous snapshot, with derived **graph intelligence** (centrality/hotspots,
   blast-radius, dead code, cycles, layering violations, public-API); in parallel, deep web research
   over a **rolling 90-day window** (best-practices + latest trends, every finding cited + dated).
2. **Analyze, fan-out** (`plan-analyst`, one per dimension) — named gaps + **upgrade options each
   tagged quality / speed / accuracy**, every claim citing `file:line`, scoped by graph blast-radius.
3. **Verify, adversarial** (`plan-verifier`) — tries to **refute** each claim and **feasibility-gates**
   each upgrade against the source + the repo invariants. Only `CONFIRMED`/`QUALIFIED` + feasible
   items reach the plan (an upgrade that would breach the no-C-in-trust-boundary invariant → REFUTED).
4. **Synthesize** (`plan-architect`) — a verdict-first plan with **ASCII architecture diagrams**, a
   sequenced **quality/speed/accuracy** upgrade roadmap, a **tool-evaluation** section, named gaps and
   stated confidence; promoted to a `docs/ROADMAP.md` row (+ a draft ADR for a genuine arch decision).
5. **Self-eval, every cycle** (`evolution-steward`) — score the cycle, mine lessons, queue harness
   upgrades; apply low-risk at the batch boundary via PR (never mid-cycle, never weaken a gate).
6. **DONE gate** — every target + dimension verified + a cartographer **completeness sweep** + the
   plan answered from confirmed evidence with named gaps.

## Shape

- **Skills** (`harness/skills/`): `planning-engineer` (single-cycle orchestrator) + `plan-loop`
  (continuous Ralph loop) + `plan-cartography` / `plan-trend-research` / `plan-test-strategy` /
  `plan-synthesis` (methods), reusing `code-research-verify` + shared `session-relay-wrap-up`/`-resume`,
  `harness-loop-init`, `harness-evolution`, `icm-memory`. (The 90-day research applies the deep-research
  *method* inline in `plan-trend-research` — not a separate skill to load.)
- **Agents** (shared `harness/agents/`): `plan-cartographer` / `plan-trend-researcher` /
  `plan-analyst` / `plan-test-strategist` / `plan-verifier` / `plan-architect` (specialists) +
  `continuity-steward`, `evolution-steward` (shared).
- **Testing pillar:** an always-on `test-coverage` dimension (`plan-test-strategist` maps existing tests
  by call-graph reachability, finds coverage gaps, and designs the suite) → a *Test Strategy & Coverage*
  plan section + a **Feature-Forge test-build handoff** (the loop plans tests; Feature Forge builds +
  runs them — read-only is preserved). The harness also ships hermetic self-tests
  (`scripts/tests/test-plan-{eject,loop-state,contract}.sh`), wired into envctl CI.
- **Execution mode:** hybrid — single-orchestrator, background-parallel fan-out (map+research,
  analyze, verify), sequential synthesize + self-eval; durable ledger under `.handoff/loop/plan/`
  (resumable). **Read-only** on the target's production code (writes plans/graph + docs only). All
  agents `model: opus`.

## Run / eject

- **Single cycle:** `/harness:planning-engineer` (give it a target + target_root, or let the
  cartographer auto-derive `targets.md`).
- **Continuous loop:** `/harness:plan-loop` (plans the auto-derived backlog of crates/subsystems).
- **Eject:** `bash harness/skills/planning-engineer/scripts/eject.sh <target-repo>` → `/planning-engineer`.
- **External runner (SAFE, read-only):** `harness/skills/planning-engineer/scripts/ralph-plan.sh`.

Built per the [packaged-harness standard](../docs/packaged-harness-standard.md).
