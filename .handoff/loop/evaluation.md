# Run evaluation — 2026-06-13 · rust-port harness self-upgrade (via `/harness:harness-evolution`)

Run = `/harness:rust-port [upgrade harness | detailed symbol mapping, agent run time, fill all gaps |
no feature left behind, 100% rust-native | /harness:harness-evolution]`. This was a **proactive
harness self-upgrade** (not a port run), so the four axes are scored against the harness's design vs
the owner's directive + the no-downgrade invariant, reconstructed from the harness files + the
design/adversarial-verify workflow (`wf_fcc045e2-9de`, 6 agents, ~520k tok).

## Method
Hybrid: inline scout (read every rust-port file) → a dynamic workflow (4 parallel design analysts —
symbol-map, runtime-constructs, agent-runtime-contract, gap-audit — barrier → 2 adversarial verifiers:
gate-integrity + wiring/consistency) → reconcile per the verifiers' must-fix list → apply inline →
validate → PR/auto-merge.

## Four axes
- **Friction:** low. The workflow surfaced all edit collisions (same file/line touched by ≥2 dims:
  `loop_state:12`, `SKILL:131/135/153`, the verifier list, `entries` Shape) so they were reconciled
  *before* applying — no thrashing. One latent overfit (Dim4's `runtime_coverage` counter with no
  producer/consumer) was caught and dropped rather than shipped as dead state.
- **Gate quality (primary):** the adversarial pass earned its keep. It refuted "strengthen-only" in
  one place: the new AST-harvested symbol denominator is `0` for an un-indexable source → a vacuous
  `0/0` sweep would pass DONE with nothing mapped (a hole the unit-only gate didn't have). Fixed
  fail-closed (`NEEDS-HUMAN` on empty harvest of a non-empty source) + a shared visibility filter so
  the sweep stays sound *and* achievable. Net: every applied change strengthens the parity/DONE gate;
  nothing weakened (verified APPLY-WITH-FIXES on both lenses, BLOCK on neither).
- **Coverage:** all three owner asks delivered — (1) detailed symbol mapping (new artifact + rollup +
  two-grain sweep), (2) agent runtime (porting-side idiom map + port-and-map refs; harness-side
  declarative per-agent contract), (3) fill-all-gaps (eject/entries/registry/version/template/count
  drift). No silent caps. The one structural item left **proposed** (not applied) is the standing
  P1/P2 context-budget loop guard — untouched, still owner-pending.
- **Human walls:** none. Owner-directed scope = apply authority; all changes additive/strengthening,
  landed via the standard feature-branch → PR → auto-merge flow.

## Lessons mined → `harness/LESSONS.md` (4 new rows)
gate-completeness (symbol+runtime), empty-denominator-fail-closed (from the verifier), runtime-contract
(declarative per-agent table), catalog-drift (recurrence 2 → standard checklist proposed). See the
ledger + the CLAUDE.md change-history row.
