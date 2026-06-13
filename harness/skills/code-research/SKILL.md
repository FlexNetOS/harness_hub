---
name: code-research
description: >-
  Packaged deep-code-research harness (invoked as /harness:code-research). Runs an autonomous,
  resumable loop that deeply RESEARCHES and ANALYZES a codebase to answer a question with cited,
  adversarially-verified evidence — architecture, capabilities, agent/loop model, design intent,
  "is it an X?". ALWAYS use for: "analyze <repo>", "deep code research", "what is <project> really",
  "is <project> a <X>", "research the architecture/capabilities of <repo>", "map this codebase", AND
  follow-ups — "resume", "continue the analysis", "re-run", "redo only the <dimension>", "dig deeper
  on <X>". Read-only. Fan-out analysts → adversarial verify (refute claims vs code) → synthesize a
  decision-grade report. DONE only when the question is answered from confirmed evidence + a
  completeness sweep. Ejectable into a target repo.
---

# code-research — deep code research & analysis harness  (`/harness:code-research`)

Leader skill of the **code-research** packaged harness (in the `harness` plugin). It answers a
research question about a codebase with **cited, adversarially-verified** evidence — not a confident
guess. Map the code → analyze each dimension in parallel → **try to refute every material claim
against the source** → synthesize a decision-grade report. The defining property: conclusions are
*earned by evidence that survived refutation*, so the report is safe to make decisions on.

**Read-only** (it never mutates the target). **Packaged + ejectable**: run via `/harness:code-research`
or eject into a target repo. Built on the autonomous-operation pattern: durable findings ledger under
`.handoff/loop/`, every step recorded, any restart resumes cold.

## Execution mode — Hybrid (fan-out sub-agents + file-based), and why

Single-orchestrator with specialist sub-agents over a durable ledger (not a live team — team state
dies at the self-restart boundary; the findings ledger must survive). Per phase:

| Phase | Mode | Shape |
|-------|------|-------|
| Map | Sub-agent | cartographer → codemap + dimensions |
| Analyze | Sub-agent, **parallel** (`run_in_background`) | one analyst per dimension → claims |
| Verify | Sub-agent, **parallel** | one verifier per dimension → refute claims vs code |
| Synthesize | Sub-agent | synthesizer → decision-grade report |

All `Agent` calls use `model: "opus"`.

## Agents (in the plugin's shared `harness/agents/` pool)

| Agent | Owns | Shared? |
|-------|------|---------|
| `code-research-cartographer` | map the codebase + decompose the question into dimensions + completeness sweep | specialist |
| `code-research-analyst` | deep per-dimension analysis → cited claims | specialist |
| `code-research-verifier` | adversarially refute claims vs the actual code (the gate) | specialist |
| `code-research-synthesizer` | integrate confirmed claims → decision-grade report | specialist |
| `continuity-steward` | cold-start HANDOFF.md at budget | shared |
| `evolution-steward` | Phase E retro + harness upgrades | shared |

Skills: `code-research-map`, `code-research-analyze`, `code-research-verify`,
`session-relay-wrap-up`, `session-relay-resume`, `harness-evolution`.

## Phase 0: Context check + inputs

Decide mode (initial / resume via `session-relay-resume` / partial-redo-one-dimension / new). The
orchestrator needs the **research question** and the **target codebase root** — ask once if not given;
record both in `loop_state.md`. (A read-only target: no build/run required to start, but the verifier
may run it, so note the target toolchain.)

## Phase 1: MAP

`code-research-cartographer` → `.handoff/loop/reports/codemap.md` (modules, entry points, deps,
external interfaces, build/run) + seeds `.handoff/loop/research-ledger.md` with the **dimensions** the
question decomposes into (architecture, capabilities, agent/loop model, extension model, comparison-
to-X, …). Commit the ledger + codemap.

## Phase 2: ANALYZE (fan-out, parallel)

For each `- [ ]` dimension, spawn `code-research-analyst` (parallel) → `.handoff/loop/findings/
<dimension>.md` with claims, each citing `file:line` + a confidence. Mark dimensions `- [~]`
(analyzed, unverified).

## Phase 3: VERIFY (adversarial, parallel) — the gate

For each analyzed dimension, spawn `code-research-verifier` → it tries to **refute** each material
claim against the code (read the cited source; run it where ambiguous). Verdicts to
`.handoff/loop/findings/verdicts.md`. Only `CONFIRMED`/`QUALIFIED` claims survive; `REFUTED`/
`INCONCLUSIVE` do not become report facts (notable refuted overclaims are still reported). Mark
verified dimensions `- [x]`. **Never let an unverified claim into the report** — that's the whole point.

## Phase 4: SYNTHESIZE

`code-research-synthesizer` → the report (user path or `.handoff/loop/reports/<slug>.md`): **verdict
first**, then evidence (cited), comparison/concept-map (for "is it an X?"), confidence, gaps, and a
flagged recommendation when the research feeds a decision. Commit.

## DONE gate (evidence-backed)

Write `.handoff/loop/DONE` only when: every dimension is `- [x]` (verified) or an explicit `- [!]`;
the **cartographer's completeness sweep** finds no major module/interface/dimension unexamined; and
the report answers the question from CONFIRMED evidence with a stated confidence + named gaps. Record
the sweep result inside `DONE`.

## Phase E: Evaluate & evolve (runs last — at DONE and HAND OFF)

`evolution-steward` (skill `harness-evolution`): evaluate the run (friction, **gate quality** — did a
wrong claim slip past verification? did verify false-refute a true claim?, coverage, walls), mine
lessons into `LESSONS.md`, upgrade the harness fail-closed (auto-apply low-risk in-scope via PR,
propose structural, never weaken the verify gate, scope law).

## Continuity & error handling

- **HAND OFF** at budget via `session-relay-wrap-up` (Phase E retro → ICM store → continuity-steward
  HANDOFF + commit → heartbeat → stop). **RESUME** via `session-relay-resume` (ICM recall → weave
  inbox → committed HANDOFF → verify-on-resume → continue at the next dimension).
- **Retry once; never fabricate evidence.** Analyst errors → `- [!]` dimension, continue others.
  A claim that can't be verified stays unconfirmed (out of the report). Human wall (can't run target
  for a behavioral claim) → note it, mark the claim INCONCLUSIVE, surface in gaps — don't assert.

## Eject

`bash scripts/eject.sh <target-repo>` copies the harness (skills + agents) into the target's
`.claude/` and scaffolds `.handoff/loop/`. See `references/eject.md`. Invoke as `/code-research`.

## Test Scenarios

**Happy path (the Archon question):** Question = "Is meta/Archon a harness/agent manager?" MAP finds
entry points + an agent/MCP subsystem; dimensions = {architecture, agent-loop model, capabilities,
extension model, comparison-to-harness-agent-manager}. Analysts produce cited claims; the README
claims "command center for AI agents." VERIFY refutes the overclaims (e.g. "manages a fleet" → no
fleet-coordination code wired → REFUTED) and confirms the rest. SYNTHESIZE: "Archon is an agent
*knowledge/task/MCP* layer, not a fleet manager — has X/Y, lacks Z" + a reuse recommendation for
harness-agent-rs, confidence stated, gaps named.

**Error path (unverifiable behavioral claim):** Analyst claims "hot-reloads plugins at runtime" but
it can't be confirmed statically and the target won't run in this env → verifier returns
INCONCLUSIVE → the claim is excluded from the verdict and listed under gaps ("plugin hot-reload
unverified — needs a running instance"), never stated as fact.

## References
- `references/research-ledger.md` — ledger + claim/verdict schema + dimension catalog.
- `references/eject.md` — install into a target repo.
- `scripts/loop_state.template.md` · `scripts/eject.sh` · `scripts/ralph-code-research.sh` (SAFE, read-only).
