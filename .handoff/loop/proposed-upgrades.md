# Proposed upgrades (owner approval — structural, scope law)

From the 2026-06-13 cadence lesson. The *rule* is applied in the standard; the per-orchestrator
**budget mechanics** are structural (they change loop control flow), so they are proposed, not
auto-applied.

## P1 — Context-budget loop guard (replace fixed cycle-count) in meta-plugin & rust-port orchestrators
Today the loops hand off at a fixed **cycle budget**. Proposal: make the budget **~50% of the
context window** (the owner's stated threshold), so the loop keeps shipping items until ~50% is
consumed, then runs `session-relay-wrap-up`. Concretely:
- Add a `context_budget_pct` (default 50) to each orchestrator's loop-state schema, alongside the
  existing cycle counter (keep the cycle counter as a secondary safety cap).
- Per cycle: estimate context consumed; when ≥ budget → wrap-up + HAND OFF (do **not** run to
  exhaustion — leave headroom to checkpoint).
- The external Ralph runner (`ralph-meta-plugin.sh`) already restarts with fresh context per cycle;
  the in-session guard is what changes.

## P2 — "Next-item auto-select, no question-gate" in both orchestrators' loop step
Make explicit in each orchestrator SKILL that after an item completes (DONE/verified), the loop
**auto-selects the next item** and continues — `AskUserQuestion`/owner-stop only at a genuine wall.
The standard now states this; the orchestrator bodies should mirror it in their loop-step prose.

## Notes
- Neither proposal weakens a gate or a wall; both preserve NEEDS-HUMAN, worktree isolation, and the
  PR/auto-merge flow.
- Cross-harness: applies to every loop harness (meta-plugin, rust-port) — apply uniformly on approval.
