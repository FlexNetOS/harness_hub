---
name: rust-port
description: >-
  Packaged Rust-port harness (invoked as /harness:rust-port). Runs an autonomous, resumable loop
  that performs a FULL-FEATURE, NO-DOWNGRADE port of a source project (TypeScript/Python/etc.) to
  idiomatic Rust — no feature logic left behind. ALWAYS use for: "port <project> to Rust", "rust
  port", "rewrite in Rust", "full-parity Rust port", "port meta/Archon to Rust", AND follow-ups —
  "resume", "continue the port", "run it again", "re-run", "redo only the <unit/phase>", "based on
  the previous result", "what's left to port". Also ejectable: "install/eject the rust-port harness
  into <repo>". Drives a Ralph loop over a parity ledger: one unit per cycle, differential parity
  test, commit per cycle, hand off at budget. DONE only at 100% parity (nothing left behind).
---

# rust-port — full-feature, no-downgrade Rust port harness  (`/harness:rust-port`)

Leader skill of the **rust-port** packaged harness (in the `harness` plugin). It ports a source
project to **idiomatic Rust with zero capability loss**: every module, behavior, error path, and
edge case in the source is inventoried, ported, and **differentially verified** against the source
before it counts as done. The guarantee is **no feature logic left behind** — enforced structurally
by a parity ledger that must reach 100%, not by good intentions.

It is **packaged + runnable + ejectable**: run in place via `/harness:rust-port`, or eject into the
target/port repo's `.claude/` (see §Eject). Built on the FlexNetOS autonomous-operation pattern:
**truth lives on disk**, every cycle commits, any restart resumes cold with zero loss.

## Execution mode — Hybrid (sub-agent + file-based), and why

Single-orchestrator with specialist sub-agents, coordinated **file-based** under `.handoff/loop/`
(durable) + return-values. Not a live team: team state dies at the self-restart boundary, and this
loop's premise is that state (the parity ledger) survives a fresh process. Per phase:

| Phase | Mode | Shape |
|-------|------|-------|
| Discover / inventory | Sub-agent | cartographer → ledger; architect → target design (parallel-capable) |
| Port (per cycle) | Sub-agent, sequential | one unit → porter → build-health → parity-verifier |
| Handoff | Sub-agent | continuity-steward writes HANDOFF.md |

All `Agent` calls use `model: "opus"`.

## Agents (in the plugin's shared `harness/agents/` pool)

| Agent | Owns | Shared? |
|-------|------|---------|
| `rust-port-cartographer` | exhaustive source inventory + parity ledger + left-behind sweep | specialist |
| `rust-port-architect` | Rust target layout + idiom map + dependency equivalents | specialist |
| `rust-port-porter` | full (no-stub) idiomatic port of one unit | specialist |
| `rust-port-parity-verifier` | differential parity proof (source vs Rust) | specialist |
| `build-health-auditor` | cargo build/clippy/test green gate | shared |
| `continuity-steward` | cold-start HANDOFF.md at budget | shared |
| `evolution-steward` | evaluates each run, mines lessons, upgrades the harness (runs last) | shared |

Skills: `rust-port-inventory`, `rust-port-translate`, `rust-port-parity`, `cross-repo-health`,
`session-relay-wrap-up`, `session-relay-resume`, `harness-loop-init`, `harness-evolution`.

## Agent runtime (the declarative execution contract)

The consolidated, per-agent runtime spec for this harness. It is the single source of truth for *how*
each agent is run (it subsumes the scattered facts — the `model: "opus"` rule, the phase/mode table
above, the retry/fail-closed rule, the self-pace cadence). **This table is the declarative contract
the `harness-agent-rs` runtime (ADR-0001) will consume to execute the harness**, so every cell is
meant to be precise and machine-translatable — model, phase, concurrency, precondition, timeout/retry,
I/O files, and gate-role are the fields a runtime needs to schedule, isolate, and gate each run. Keep
it in sync with the agent defs in `harness/agents/` and the per-row contracts they declare.

| Agent | Model | Runs-in (phase) | Concurrency | Trigger / precondition | Timeout & retry (fail-closed) | Inputs (reads) | Outputs (writes) | Gate-role |
|-------|-------|-----------------|-------------|------------------------|-------------------------------|----------------|------------------|-----------|
| `rust-port-cartographer` | opus | P1 DISCOVER (seed); DONE gate (left-behind sweep) | parallel-capable with `rust-port-architect` at DISCOVER; sequential at the sweep | initial run or new source/scope; and once more pre-DONE | retry once; on 2nd failure → `- [!]` blocked row + continue, never fake coverage; empty symbol harvest of non-empty source → `NEEDS-HUMAN` | source root; prior `parity-ledger.md`/`symbol-map.md` | `parity-ledger.md` + `symbol-map.md` (authoritative), `reports/inventory.md` | **completeness critic** — its two-grain sweep (zero unlisted units/symbols, zero `- [ ]`/`- [~]`, zero rollup violations) is a hard DONE precondition |
| `rust-port-architect` | opus | P1 DISCOVER (layout); P2 ITERATE (only when a unit needs a new structural decision) | parallel-capable with cartographer at DISCOVER; on-demand, single-flight per unit otherwise | DISCOVER, or a porter/orchestrator structural question | retry once; unresolved equivalent → record options + surface to orchestrator, never pick/drop silently | source root; `parity-ledger.md` | `target-architecture.md` (layout + idiom map + dep table + port-and-map decisions) | advisory — establishes the no-downgrade idiom/dep + reimplement-vs-map-onto mapping the porter must follow; not a pass/fail gate |
| `rust-port-porter` | opus | P2 ITERATE (the per-cycle worker) | **sequential, exactly one per cycle** (the one-specialist-per-cycle rule) | a picked unit whose `deps:` are all `- [x]` | retry once; if not finished → unit `- [~]`/`- [!]` + the specific `symbol-map.md` rows `- [ ]`/`- [!]`, never `- [x]` | unit's ledger + symbol rows; `target-architecture.md`; source file; `rust-port-translate` | Rust source + tests in the target crate; unit + symbol rows → `- [~]` | produces the artifact under test; its claim is **never self-certified** (verifier + auditor gate it) |
| `build-health-auditor` | opus | P1 DISCOVER (skeleton baseline); P2 ITERATE (post-port compile gate) | sequential, after the porter in a cycle | a freshly ported unit, or the DISCOVER baseline / verify-on-resume | retry once; environmental failure (toolchain/network) → `skip` w/ reason, never silent pass | target repo set; the porter's new code | `findings/health.md`; `baseline.md` | **green-build gate** — `cargo build` + `clippy -D warnings` (+ `test`) must pass; precondition for the parity gate |
| `rust-port-parity-verifier` | opus | P2 ITERATE (the per-cycle gate) | sequential, after build-health-auditor | a unit that compiles + passes clippy | retry once; can't run one side → `INCONCLUSIVE`, unit stays open (never pass on faith) | unit's ledger + symbol rows; source unit; Rust impl; `target-architecture.md` | `findings/parity.md` (verdict + diff); per-symbol `- [x]` in `symbol-map.md`; golden fixtures | **the no-downgrade gate** — only a `PASS` (every contract branch matches **and** all the unit's symbols `- [x]`/`- [≠]`) lets the orchestrator mark `- [x]` |
| `continuity-steward` | opus | P3 HAND OFF (at budget) | sequential, single-flight at the budget boundary | `cycles_this_session >= cycle_budget` (or STOP) | retry once; missing `baseline.md` → reconstruct verify-on-resume block + note it | `parity-ledger.md`, `symbol-map.md`, `loop_state.md`, `baseline.md`, session commit list | `HANDOFF.md` (state + pointers, the authoritative resume signal) | continuity gate — writes the cold-resume contract; no fake DONE may substitute for it |
| `evolution-steward` | opus | Phase E (runs **last** — at DONE full retro, at HAND OFF lightweight) | sequential, single-flight at the run boundary (never mid-cycle) | end of run (DONE or HAND OFF) | retry once; thin artifacts → evaluate what exists + record the gap as its own lesson | `.handoff/loop/` artifacts; CLAUDE.md change history; `LESSONS.md` | `evaluation.md`; `proposed-upgrades.md`; lessons-ledger rows; applied PR edits | **gate-strengthener only** — may evaluate and *strengthen* the parity/DONE gate, never weaken it (scope law) |

**Loop-level runtime (the schedule the runtime drives):**

- **Self-pacing** — after each committed cycle the orchestrator re-enters via `ScheduleWakeup` (P2 step 6); at HAND OFF/DONE it stops with **no** `ScheduleWakeup` and lets exactly one terminal sentinel (`DONE` / `NEEDS-HUMAN` / `HANDOFF.md`) drive the external runner.
- **Cycle budget** — `cycle_budget` (default `3`, in `loop_state.template.md`) cycles per session; `cycles_this_session` resets to `0` on RESUME. Hitting the budget routes to P3 HAND OFF, not a stop-and-ask.
- **Context budget** — a session runs cycles continuously to a ~50% context budget rather than stopping per item; only a genuine wall (`NEEDS-HUMAN`) or the cycle budget halts it.
- **Commit per cycle** — every ITERATE cycle commits one unit with its `.handoff/loop/` state (`port(<crate>): <unit> — parity verified`); truth lives on disk so any restart resumes cold with zero loss.
- **One specialist per cycle** — exactly one specialist (the porter) runs per ITERATE cycle, gated by the auditor then the verifier; the architect runs only on a structural question. This bounds coordination to a single sequential chain per cycle and is what makes the loop machine-schedulable.

## Phase 0: Context check (initial / resume / partial)

- `.handoff/loop/HANDOFF.md` exists + user says resume/continue → **RESUME** via
  `session-relay-resume` (ICM recall → weave inbox scan → read committed HANDOFF → verify-on-resume
  baseline, fail-closed → broadcast `relay:resumed` → reset `cycles_this_session=0`), continue at the
  ledger's next `- [ ]`/`- [~]` unit.
- `.handoff/loop/` exists + user asks to redo one unit/phase → **PARTIAL**: re-run only that unit.
- `.handoff/loop/` exists + new source/scope → **NEW RUN**: move old to `.handoff/loop_prev/`.
- absent → **INITIAL**.

The orchestrator must know the **source root** (the project being ported) and the **Rust target
crate/dir**. Ask once if not given; record both in `loop_state.md`.

## Phase 1: DISCOVER (initial run)

1. Seed `.handoff/loop/loop_state.md` (template in `scripts/`) with source root + Rust target + UTC start.
2. `rust-port-cartographer` → `.handoff/loop/parity-ledger.md` (every source unit, all `- [ ]`)
   **and `.handoff/loop/symbol-map.md`** (every source symbol — fn/type/method/field/const/variant/
   trait/CLI flag/route — harvested deterministically via `git kb code symbols --json --limit -1`,
   all `- [ ]`, each `unit:`-tagged). See `references/symbol-map.md`.
3. `rust-port-architect` → `.handoff/loop/target-architecture.md` (crate layout, idiom map, deps).
4. `build-health-auditor` → confirm the Rust target skeleton builds (baseline) → `.handoff/loop/baseline.md`.
5. Order the ledger by dependency (leaf modules / pure functions first; entrypoints last). See
   `references/parity-ledger.md`. Commit ledger + state + architecture.

## Phase 2: ITERATE (one unit per cycle)

1. Read `loop_state.md` + `parity-ledger.md`.
2. Stop checks: no `- [ ]`/`- [~]` left → go to **DONE gate**; `cycles_this_session >= cycle_budget`
   → **HAND OFF**; `.handoff/loop/STOP` present → stop.
3. Pick the top unported unit whose dependencies are `- [x]`.
4. **Architect** (only if the unit needs a new structural decision) → **porter** ports it FULLY
   (no stubs, every branch — see `rust-port-translate`) → **build-health-auditor** (compiles + clippy).
5. **Parity gate** — `rust-port-parity-verifier` runs the differential test (source vs Rust over the
   unit's whole contract, **exercising every symbol of the unit** in `symbol-map.md`). A unit `PASS`
   requires every contract behavior to match **and all the unit's symbols to be `- [x]`/`- [≠]`**
   (rollup rule) → mark the unit `- [x]`. Any unverified symbol or divergence → leave `- [~]`/`- [!]`
   with the exact missing behavior + symbol id; do NOT commit a fake `- [x]`. **A dropped symbol or
   downgrade never passes the gate.**
6. Write ledger back, bump counters, **commit** one unit (`port(<crate>): <unit> — parity verified`)
   with the `.handoff/loop/` state. Self-pace (`ScheduleWakeup`).

## Phase 3: HAND OFF (at budget)

Invoke **`session-relay-wrap-up`** — the full wrap-up: stop-checks → Phase E lightweight retro
(`evolution-steward`) → persist durable memory to ICM → `continuity-steward` writes+commits
`.handoff/loop/HANDOFF.md` → weave `relay:handoff` heartbeat → best-effort cron successor → stop
(prefer `hf checkpoint`/`hf handoff` when the kernel is reachable). The committed HANDOFF.md is the
resume signal; a fresh session re-enters via `session-relay-resume`.

## Phase E: Evaluate & evolve (runs last — at DONE and at HAND OFF)

Invoke `evolution-steward` (`model: "opus"`, skill `harness-evolution`): evaluate the run (friction,
**gate quality** — did the parity gate miss a downgrade or false-block?, coverage, human walls),
mine generalizable lessons into the lessons ledger, and upgrade the harness — auto-applying only
low-risk in-scope edits via the standard PR flow (with a change-history row), proposing structural
changes in `.handoff/loop/proposed-upgrades.md`. It may only ever *strengthen* the parity/DONE gate,
never weaken it, and stewards only this harness (scope law). Lightweight at HAND OFF, full at DONE.

## DONE gate (no-downgrade, evidence-backed)

Write `.handoff/loop/DONE` only when ALL hold:
- **Left-behind sweep passes at BOTH grains** — `rust-port-cartographer` re-scans the source and
  finds zero *units* missing from the ledger and zero `- [ ]`/`- [~]` unit rows; **then re-harvests
  the full source *symbol* set (`git kb code symbols --json --limit -1`, same visibility filter) and
  finds zero symbols missing from `symbol-map.md`, zero `- [ ]`/`- [~]`/`- [!]` symbol rows, and zero
  rollup violations (every `- [x]` unit has 100% `- [x]`/`- [≠]` symbols).** A zero/empty symbol
  harvest of a non-empty source is fail-closed (`NEEDS-HUMAN`), never a vacuous `0/0` pass. (The
  completeness critic, unit + symbol.)
- Every unit is `- [x]` (parity-verified) or an explicit `- [≠]` intentional-divergence with owner
  approval — **and every symbol in `symbol-map.md` is `- [x]`/`- [≠]`** (symbols X/Y = Y/Y).
- `cargo build` + `cargo clippy -D warnings` + `cargo test` all green.
- The parity trail in `.handoff/loop/findings/parity.md` shows a passing differential test per unit.
Record the evidence (unit counts, **symbol counts X/Y**, and both sweep results) inside `DONE`. After writing `DONE`, run **Phase E**
(full retro) so the completed port feeds the harness's evolution.

## Data transfer & error handling

- File bus: `.handoff/loop/{parity-ledger,symbol-map,target-architecture,baseline,loop_state,HANDOFF}.md`,
  `findings/parity.md`, `reports/inventory.md`.
- **Retry once; never fake completion.** Specialist errors → `- [!]` with reason, continue other
  units. Parity FAIL → unit stays open. Human wall (needs network creds to run source, etc.) →
  `.handoff/loop/NEEDS-HUMAN`, stop. Conflicting behavior readings → keep both, verifier adjudicates.
- **The cardinal rule:** never weaken the parity gate, stub a unit, or drop a branch to make a cycle
  pass. A red parity test is honest; a fake green defeats the harness's entire purpose.

## Team size

7 agents (Large): 4 specialists + 3 shared (`build-health-auditor`, `continuity-steward`,
`evolution-steward`). One specialist runs per cycle, so coordination stays bounded — see the
**Agent runtime** table above for the full per-agent execution contract.

## Eject

`bash scripts/eject.sh <target-repo>` copies this harness (skills + the 7 agents) into the port
repo's `.claude/` and scaffolds `.handoff/loop/`. See `references/eject.md`. Invoke as `/rust-port`
once ejected.

## Test Scenarios

**Happy path:** Port `meta/Archon` (TS/Bun) to Rust. DISCOVER inventories 600+ units into the ledger;
architect maps packages→crates, express→axum, prisma→sqlx, sets tokio+thiserror. Cycle N: porter
ports `auth-service/token.ts` fully (all 4 error branches) → builds → verifier runs source & Rust
over happy + 4 error inputs, outputs match → `- [x]`, commit. … At 100%, cartographer's sweep finds
nothing left → tests green → write `DONE`.

**Error path (attempted downgrade):** Porter ports a streaming handler as a synchronous one "for
now." Build is green, but the parity-verifier feeds a streaming input and the Rust returns all-at-once
→ `FAIL` (expected: incremental chunks; actual: single buffer). Unit stays `- [~]` with the exact
diff; the cardinal rule blocks commit. Next cycle the porter implements the streaming version.

**Error path (runtime-construct downgrade):** Porter maps Archon's `dag-executor.ts` parallel layers
onto a sequential `for` loop, and a `loop`-until-signal node onto a fixed-count loop. Build is green,
but the parity-verifier feeds a parallel workload (Rust runs layers serially → ordering/timing diff)
and a cancellation input (Rust never aborts → stuck) → `FAIL`. The runtime contract (concurrency
degree, loop-until-signal, cancellation point) is part of the ledger row per
`references/runtime-constructs.md`, so it stays `- [~]` until the executor runs layers concurrently
and honors the stop signal. Mapping onto a substrate (e.g. run-state onto `hf`) is verified the same
way — a mapped unit is differentially tested, never trusted.

**Error path (intra-unit symbol drop):** Porter ports `Config` but omits one field and one enum
variant. `cargo build` is green and the happy-path differential PASSes, but the verifier exercises
every `symbol-map.md` row for the unit: the dropped field's row stays `- [ ]` and the missing variant
`FAIL`s → by the rollup rule the unit can't reach `- [x]`. The pre-DONE symbol sweep would also catch
it as an unmapped/unverified symbol. The dropped symbol cannot hide behind the module compiling.

## References
- `references/parity-ledger.md` — unit ledger schema + dependency ordering + the no-downgrade legend.
- `references/symbol-map.md` — per-symbol map schema + deterministic harvest + the unit-rollup rule.
- `references/runtime-constructs.md` — port-and-map decision table for agent-runtime / orchestration
  subsystems (reimplement vs map-onto `hf`/`weave`/`grit`/`icm`/provider-CLI; no behavior dropped).
- `references/eject.md` — install into the port repo.
- `scripts/loop_state.template.md` · `scripts/eject.sh` · `scripts/ralph-rust-port.sh` (SAFE runner).
