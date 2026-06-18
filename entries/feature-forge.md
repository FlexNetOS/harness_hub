# feature-forge (design→implement→verify construction crew + Ralph loop)

**Category:** orchestrator · **Status:** beta · **Runtime:** multi · **Command:** `/harness:feature-forge`

A packaged harness that turns a feature / upgrade / design request into **invariant-verified working
Rust** by driving a three-specialist **construction crew** through a `design → implement → verify`
pipeline. The orchestrator is the integrator — it sequences the crew, routes findings, gates each
phase, and synthesizes the result; the crew *builds* the feature.

**Provenance:** hand-authored in **envctl** (a pure-Rust, 8-crate Cargo workspace) on **2026-06-04**.
It is the **source pattern** the hub later abstracted — the `rust-port` harness reused its
construction-crew shape. The bundled invariant set (engine-first, no-C trust boundary, fail-closed
guards, the 3 CI gates) is envctl's; when ejected into another Rust repo, adapt that table to the
target's CLAUDE.md while keeping the engine-first / front-end-parity / fail-closed discipline.

## Roster

- **Specialists** (`harness/agents/`, name-prefixed):
  - `feature-forge-architect` (`Plan`, read-only) — invariant-aware plan: placement, Engine API
    delta, per-invariant check, safety guards, lock/manifest sync, `## Target repos`, `## Unit ledger`
    (completeness contract), `## Runtime surface`. Returns **VERDICT: GO / NEEDS-DECISION**.
  - `feature-forge-implementer` (`general-purpose`, mutates) — builds engine-first, wires CLI+GUI to
    parity, adds tests; supports grit-coordinated parallel waves (claim→work→release, never `grit done`).
  - `feature-forge-guardian` (`general-purpose`) — cross-boundary verification: the CI gates +
    fmt/clippy/test, engine purity, front-end parity, fail-closed defaults, the Unit-ledger
    present+wired check, and the Phase-3.5 runtime observation.
  - `feature-forge-kernel-engineer` (`general-purpose`) — the Epic-A continuity-kernel hand (builds
    `hf` / seeds Tier-A `.handoff`; single-shared-ledger + packets-rendered + p7 invariants). Engaged
    only for hf-kernel / handoff-sync items.
- **Shared infra** (unprefixed, reused across the hub): `continuity-steward` (cold-start HANDOFF),
  `evolution-steward` (Phase E retro + harness self-improvement, MANDATORY), `build-health-auditor`,
  `integration-qa`.

## Skills

- **Orchestrator:** `feature-forge` (`/harness:feature-forge`).
- **Sub-skills:** `forge-loop` (the Ralph loop body — tick-on-merged, batch wrap-up cadence,
  worktree hygiene, A2 cycle shape) and `rust-feature-impl` (the engine-first delivery recipe +
  `references/verification.md` + `references/kasetto-absorption.md`).
- **Shared:** `session-relay-wrap-up` / `session-relay-resume` (ICM-integrated handoff/resume),
  `harness-loop-init` (lay down `.handoff/loop/`), `harness-evolution` (the steward's method),
  `icm-memory` (as-needed persistent memory; graceful no-op without ICM).

## Phases

`0` pre-flight (worktree + context-check + verify-the-claim + frozen-contract pick-time check) →
`1` design → `1.5` path selection (scale auto-trigger: ≤3 modules sequential / >3 independent
pipeline / >1 repo A2) → `2` build (or `2-A2` cross-repo fan-out with the **all-green barrier**) →
`3` verify → `3.5` runtime-verify (run the app, don't just gate it) → `4` synthesize & commit →
**`E` evaluate & evolve** (`evolution-steward` mines lessons into `harness/LESSONS.md`, auto-applies
low-risk in-scope edits, proposes structural ones, never weakens a gate).

## Run / eject

- **Single feature:** `/harness:feature-forge` (follow-ups: "re-run", "fix the guardian's findings",
  "revise the design").
- **Continuous over a backlog:** `/forge-loop` (the Ralph loop — one item per cycle, one PR per cycle,
  hand off at the cycle budget via `session-relay-wrap-up`, resume via `session-relay-resume`).
- **Eject into a target Rust repo:** `bash harness/skills/feature-forge/scripts/eject.sh <target-repo>`
  (then `/feature-forge`). See `harness/skills/feature-forge/references/eject.md` — and adapt the
  invariant set to the target repo's CLAUDE.md.
- **External SAFE runner:** `harness/skills/feature-forge/scripts/ralph-feature-forge.sh` (fresh
  context per cycle; SAFE by default, no permission bypass).

## Scope note (deliberate omissions)

This package is the **generic construction-crew core** only. The envctl-domain-specific loops —
`env-install-loop` (workstation provisioning), `auto-provision` (the external fresh-context provision
runner), and `handoff-sync` (build the `hf` kernel) — are **not** generically reusable and are **not**
ported here; they remain **envctl-specific extensions**. The generic continuity path is
`session-relay-*` + `harness-loop-init`; generic kernel work routes to `feature-forge-kernel-engineer`.

Built per the [packaged-harness standard](../docs/packaged-harness-standard.md).
