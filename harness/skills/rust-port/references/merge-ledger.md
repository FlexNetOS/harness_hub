# Merge ledger — the no-downgrade-across-the-merge contract

`.handoff/loop/merge-ledger.md` is the destination-side counterpart of the parity ledger: it tracks
each ported, parity-verified unit as it lands in **destination repo Y**. The port ledger proves "X's
behavior is now in Rust"; the merge ledger proves "that Rust is now **integrated into Y** with the
behavior still intact." Owned by `rust-port-merge-integrator`; status transitions gated by
`rust-port-parity-verifier` (re-run in Y) + `build-health-auditor` (Y green). Exists only when the run
has a `dest_repo` Y.

## Row format

```
- [ ] <unit-id> · <ported-rust-symbol> · <landing: new|merge-into <Y-mod>|map-onto <substrate>> · -> <Y-target-symbol> · refs: <cross-repo-ref id> · status
```

- `<unit-id>` — the same id as the parity-ledger unit (one merge row per ported unit).
- `<landing>` — the decision from `rust-port-merge` (new module / merge-into-existing / map-onto-substrate).
- `<Y-target-symbol>` — where it lands in Y (`crate::module::item`).
- `refs:` — the `reports/cross-repo-refs.md` entry (blast radius + grit lock scope used).

## Status legend (same discipline as the parity ledger)

| Mark | Meaning | Who sets it |
|------|---------|-------------|
| `- [ ]` | ported+verified but not yet merged into Y | merge-integrator (seed from parity ledger `- [x]`) |
| `- [~]` | merged into Y, **re-verification unproven** (or Y not yet green) | merge-integrator |
| `- [x]` | merged **and** re-parity-verified in Y's context + Y green | orchestrator, only on verifier re-PASS |
| `- [!] blocked: <reason>` | unresolved conflict / substrate can't express a behavior / Y won't build | any |
| `- [≠] intentional-divergence: <reason+approval>` | deliberate reconciliation change | only with owner approval |

**Only `- [x]` and `- [≠]` count toward merge-DONE.** A merge is real only when behavior is re-proven in
Y — a standalone port PASS does not close a merge row.

## Ordering (merge follows the port)

- A unit can be merged only when its parity-ledger row is `- [x]` (ported + standalone-verified). Merge
  is the appended step of the ITERATE cycle when `dest_repo` is set: port → verify → **merge → re-verify
  in Y** → commit one unit.
- Merge **leaf-first too** — a unit whose Y dependencies aren't merged yet waits, so Y stays buildable
  every cycle (no half-merged Y across a commit boundary).

## Completeness discipline (anti-"left behind", merge grain)

- **Reuse > duplicate, never reuse-by-narrowing.** Mapping onto an existing Y symbol/substrate is legal
  only if it preserves every behavior; a near-fit is extended (complete it), never silently accepted.
  A duplicate left in Y is an *incomplete unification*, not done — wire it (no-downgrade directive).
- **Re-verify in Y, don't trust the move.** The differential gate runs again in Y's context — a dropped
  re-export, a narrowed type, a collapsed streaming path introduced *during* the merge is a downgrade
  the re-verification must catch. A green Y build is necessary, not sufficient.
- **Merge left-behind sweep (pre-DONE).** Every parity-ledger `- [x]` unit must have a merge-ledger
  `- [x]`/`- [≠]`; any ported-but-unmerged unit, any `- [ ]`/`- [~]`/`- [!]` merge row, or any Y
  contract broken for its consumers blocks merge-DONE. Assume a unit was left unmerged and prove it wasn't.
- **Y never red across a boundary.** A merge that breaks Y's build/clippy/test rolls back to `- [~]`
  with the breakage — never committed.
