# Merge ledger — the no-downgrade-across-the-merge contract

`.handoff/loop/merge-ledger.md` is the destination-side counterpart of the parity ledger: it tracks
each ported, parity-verified unit as it lands in **destination repo Y**. The port ledger proves "X's
behavior is now in Rust"; the merge ledger proves "that Rust is now **integrated into Y** with the
behavior still intact." Owned by `rust-port-merge-integrator`; status transitions gated by
`rust-port-parity-verifier` (re-run in Y) + `build-health-auditor` (Y green). Exists only when the run
has a `dest_repo` Y.

## Row format

```
- [ ] <unit-id> · <class> · <ported-rust-symbol> · <landing: new|merge-into <Y-mod>|map-onto <substrate>> · -> <Y-target-symbol> · refs: <cross-repo-ref id> · status
```

- `<unit-id>` — the same id as the parity-ledger unit (one merge row per ported unit).
- `<class>` — the up-front classification (below): `port-fresh` | `extend-Y` | `reuse-Y` | `map-onto-substrate`.
- `<landing>` — the decision from `rust-port-merge` (new module / merge-into-existing / map-onto-substrate).
- `<Y-target-symbol>` — where it lands in Y (`crate::module::item`).
- `refs:` — the `reports/cross-repo-refs.md` entry (blast radius + grit lock scope used).

## Unit classification (decided up-front, from the researcher's reuse map — drives ITERATE)

The researcher's `reports/research.md` reuse map (X-needs ⟷ Y-provides) lets the architect classify
**every** unit at DISCOVER, so the loop never re-ports what Y already has. The class is a ledger field
and decides the ITERATE path:

| Class | Meaning | ITERATE path (no wasted port) |
|-------|---------|-------------------------------|
| `port-fresh` | Y lacks it | full port (porter) → standalone parity-verify → merge as **new module** in Y |
| `extend-Y` | Y has a *partial* impl | port the missing behavior → merge by **completing** Y's module (unify, never narrow) |
| `reuse-Y?` (provisional) | Y *appears to* provide it fully (architect claim from the reuse narrative — **not yet verified**) | **skip the fresh port** — differentially verify **Y's existing symbol against source X**; if it matches, it becomes `reuse-Y` (verified) and is marked merged (verify-only); if it diverges, it's really `extend-Y`/`port-fresh` (Y was partial or absent) — reclassify and complete |
| `map-onto-substrate` | a runtime construct Y delegates to `hf`/`weave`/`grit`/`icm` | **skip the fresh port** — map onto the substrate per `runtime-constructs.md`; differentially verify the substrate-backed path against X |

`reuse-Y` and `map-onto-substrate` units do **not** run the porter — porting them then discarding the
port (because Y/substrate already has it) is the wasted work this classification removes. They still go
through the **same opus re-verification against source X** — reuse is never trust; a `reuse-Y` that
secretly diverges from X is caught and reclassified to `extend-Y`.

**`reuse-Y` is PROVISIONAL until verified (`reuse-Y?`).** At DISCOVER it is an architect *claim* from
the reuse narrative (`research.md`), not a verified state — so plan it as "differential-verify, likely a
small port," **never as a free `[x]`**. Empirically reuse-Y reclassifies often under the gate: a
2026-06-14 MiroFish→teri cycle reclassified **6 of 6** backend `reuse-Y?` units (U-006/U-008→`extend-Y`,
U-009→`extend-Y`, U-013→`port-fresh`, U-004→`- [≠]`, U-048→`extend-Y`) — the "verify-only quick-wins"
framing set a false free-win expectation; the reality was six small ports. The differential gate **caught
all 6** (reuse-is-never-trusted held — keep that strength); the only defect was the *optimistic plan*.
So budget reuse-Y cycles honestly, and spot-check a couple of `reuse-Y?` claims against the actual Y
source before asserting the class. This aligns the plan with the gate; it does not relax the gate.

## Port-in-place (`rust_target == dest_repo` — port and merge collapse)

When the port lands directly into an existing Rust app that already has the foundation (the port target
**is** the merge destination — e.g. porting a Python app into an existing Rust app), there is no separate
port crate to merge into Y; the porter lands Rust straight into the dest's modules. The merge ledger then
tracks **class + landing decision only**, and the merge condition collapses:

- **No re-port, no second-repo hop.** `port-fresh`/`extend-Y` units are produced once, in the dest;
  `reuse-Y`/`map-onto-substrate` units verify the dest's existing surface against source X. The
  merge-ledger row records the **class** and the **landing** (which dest module), not a re-implementation.
- **"Merged" = landed-in-dest + dest-not-regressed.** Because X⟷Y *is* X⟷dest, the per-unit **parity gate
  doubles as the dest-regression gate**: a unit is `- [x]` in the merge ledger when its parity gate PASSes
  **and** the dest's own behavioral baseline (`findings/y-regression.md`, captured at DISCOVER) is not
  regressed. There is no separate "re-verify in Y's context" hop — it is the same verification.
- **One git context.** `dest_branch`/`dest_worktree` are the port's own branch/worktree; a cycle makes
  **one** commit, not two (the two-commit rule is for a genuinely separate Y repo).
- **Gates unchanged.** This collapses *duplicate bookkeeping* (a merge row that would otherwise restate
  the parity row), never a check — every no-downgrade condition still holds, now via the dest-regression
  baseline. The dual no-downgrade below still applies: don't regress the dest's own pre-existing behavior.

When `rust_target != dest_repo` (a separate destination repo Y), everything below applies as written
(real second repo: worktree/branch/PR, two commits per cycle, re-verify in Y's context).

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

**The `[≠]` bar applies on the merge side too** (see `parity-ledger.md` §"The `[≠]` bar" for the
precise definition): a merge `- [≠]` is legal only when the behavior is genuinely **inexpressible** in
Y's substrate (really a `- [!]`), **non-contractual/unobservable**, or a **strict superset** Y already
provides. It is **never** legal as "Y's architecture won't use it" / "Y consumes the value directly so
the export isn't needed" / "`serde` covers it" for a portable feature that produces a distinct
observable output (a serialization shape, an export format, a file sink, a CLI flag). A portable
feature is **merged, not `[≠]`-skipped** — when in doubt, land it (preserve capability).

## Ordering (by Y's dependency graph, not just X's)

- A unit can be merged only when its parity-ledger row is `- [x]` (ported/verified) — *or* it is a
  `reuse-Y`/`map-onto-substrate` class that verified Y/substrate against X directly. Merge is the
  appended step of the ITERATE cycle when `dest_repo` is set: port-or-verify → **merge → re-verify in
  Y** → commit.
- **Order by Y's dependency graph, not just X's.** The landing targets live in **Y**, whose dependency
  structure differs from X's. A unit that is a leaf in X may land on a Y module that depends on a
  not-yet-merged unit — so X's leaf-first order does **not** guarantee "Y stays buildable every cycle".
  Use the **callees in Y** from `reports/cross-repo-refs.md` to topologically order the *landings* by
  Y's graph, reconciled with the port order (a unit must be ported before it merges). Tie-break: Y-leaf
  first. The invariant is stated in **Y's** terms — every committed cycle leaves Y buildable+green.

## Y is mutable — Y-drift invalidation

Destination Y is a live repo; its base advances during a multi-session merge. On resume (and per cycle):
fetch Y, **rebase the `dest_branch` worktree onto `dest_base`**, re-index Y, and re-run the
cross-repo-referencer over the **merged** set. **Any `- [x]` merged unit whose Y blast-radius changed
under it drops to `- [~]` for re-verification** — a merge verified against an old Y is not proven
against the new Y. A merged row is only durable while the Y code it landed on is unchanged.

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
- **Dual no-downgrade — don't regress Y either.** Re-verifying X⟷Y proves the merged unit still matches
  source X; it does **not** prove Y's *own* pre-existing behavior survived (a green Y build with passing
  Y tests can still change a Y-consumer-visible semantic on an untested path). So capture **Y's own
  behavioral baseline** at DISCOVER (Y's existing test suite + golden fixtures for the symbols in each
  unit's Y blast-radius from `cross-repo-refs.md`), and after each merge **re-run it and diff**. A merge
  that changes a Y-consumer-visible behavior without owner approval is a **downgrade-of-Y** → `- [!]`/
  `- [≠]`, symmetric with the X-side rule. Trail: `.handoff/loop/findings/y-regression.md`.
- **Atomic — committed iff it passes; otherwise the tree is restored.** Do the merge in the **Y
  per-task worktree** (`dest_worktree`). The unit's Y changes are committed (to `dest_branch`) **only
  when** re-verify-against-X **and** Y-green **and** Y-not-regressed all pass. On any failure:
  `git -C <dest_worktree> reset --hard && git checkout <dest_branch>` (restore to last-green HEAD) and
  **release the grit symbol locks** (release on commit **or** rollback — never leak a lock), then mark
  `- [~]` with the breakage. "Never committed" is not enough — the broken half-merge must also be
  removed from Y's tree so the next cycle/resume starts clean.
- **Symbol grain via the re-verify (made explicit).** Unlike the port side, the merge ledger is
  unit-grain; it relies **wholly on the per-unit re-verification** to catch a symbol dropped during
  reconciliation (a lost re-export/variant — the integrator's named downgrade risks). The verifier
  therefore re-exercises **every symbol of the unit in Y** (the same `symbol-map.md` rows), so the
  rollup rule holds across the merge too — a merged unit with any unverified symbol stays `- [~]`.
