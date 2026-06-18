# Run evaluation — rust-port-merge (MiroFish → teri), U-024 cycle

Supersedes the prior per-cycle scratch (the LESSONS ledger is the durable memory). Scope: the
architect-in-loop step on U-024, the highest-leverage observation of this segment. Owner-directed retro:
"upgrade the harness to include an architect (design, reasoning, and decision) and leverage harness-evolution."

## Scorecard

### Friction — the avoidable gap
- The `rust-port-architect` agent EXISTED, but ITERATE (Phase 2 step 4) routed to it only
  **"if a unit looks structural"** — an optional, per-unit operator-judgment trigger. So a large
  `extend-Y` unit could go straight to the porter, which would then **guess** the decomposition,
  treat a stub as a hard blocker, or risk a reuse-by-narrowing downgrade. Capability present, not routed.
- U-024 = a 2573-line Python `ReportAgent` `extend-Y`, blocked on a **stubbed**
  `ZepToolsService` ↔ `KnowledgeGraph` wiring — exactly the class of unit that most needs design-first,
  yet the loop had no rule forcing it.

### What the architect-in-loop step bought us (evidence)
Invoking `rust-port-architect` BEFORE porting U-024 produced (`findings/u024-architecture.md`):
- a recorded **reuse-vs-narrowing decision** (extend-Y CONFIRMED; both report families coexist);
- **de-risking of the perceived blocker** — the architect measured `ZepToolsService` as a LEAF with
  zero production callers → wiring blast radius ~0 (the stub was not a hard wall);
- an **ordered 9-sub-cycle decomposition (a→i)** with explicit deps, each independently portable +
  parity-verifiable in one loop cycle;
- the **substrate-mapping decision** (`ReportTools<'g>{graph:&KnowledgeGraph}` borrow-facade per
  DECISION-9, NOT `Arc`) and pre-identified `[≠]`/`[!]` risk flags for the no-downgrade gate.
- Result: sub-cycle (a) ported + **byte-level parity-PASSed** + committed cleanly. Without the architect
  step the porter would have guessed the decomposition, treated the stub as a blocker, or narrowed reuse.

### Gate quality
- No defect slipped the parity gate this segment; the gate stayed strict (byte-level PASS on (a)).
- The gap was UPSTREAM of the gate — a *missing design-decision routing*, not a leaky gate. Fixing it
  STRENGTHENS the design-decision step (a recorded design now precedes the port for the at-risk class)
  and weakens no parity/DONE/build-health check.

### Coverage
- The 9-sub-cycle decomposition turns one un-cyclable 2573-line unit into 9 cycle-sized, individually
  verifiable units — improving coverage granularity and resumability; nothing capped or deferred silently.

### Human walls
- None hit. The would-be wall (stub → "blocked") was dissolved by the architect's blast-radius measure —
  an avoidable wall the harness now closes by routing the decision through the architect by rule.

## Lesson mined (→ LESSONS.md, recurrence 1, applied)
**Architect-routing class:** a design/decision agent that exists but is invoked by optional judgment gets
skipped on the units that most need it. Route the class of unit that needs it BY RULE, with a recorded
decision artifact (`findings/<unit>-architecture.md` = reuse call + facade/substrate decision + blocker
blast-radius de-risk + risk flags + sub-cycle decomposition); porter executes one sub-cycle per cycle.

## Upgrade applied (low-risk, in-scope, additive → standard PR flow)
- `harness/skills/rust-port/SKILL.md` — Phase 2 step 4: architect route MANDATORY for
  `extend-Y`/structural/`[!]`-blocked/above-threshold units (record design + sub-cycle decomposition;
  porter runs one sub-cycle/cycle); agent-runtime table row synced.
- `harness/agents/rust-port-architect.md` — role 4b (owns per-unit decomposition, not just DISCOVER
  layout) + I/O protocol writes `findings/<unit>-architecture.md`.
- `harness/LESSONS.md` + CLAUDE.md change-history row.

## Guards deliberately NOT weakened
- Parity gate, DONE/merge-DONE conditions, build-health green gate, the dual no-downgrade, the `[≠]` bar
  — all untouched. The architect's output is **advisory design** the porter must follow; it is NOT a
  pass/fail gate and cannot mark a unit `- [x]`. The threshold offers an **optional-skip only below it**
  (a trivial leaf port-fresh) — it never lets an above-threshold/`extend-Y`/blocked unit skip the architect.
