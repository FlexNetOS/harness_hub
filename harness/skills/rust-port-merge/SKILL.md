---
name: rust-port-merge
description: >-
  How to MERGE a parity-verified Rust unit (ported from source repo X) into a destination Rust repo Y
  with NO downgrade — landing decision (new module vs merge-into-existing vs map-onto-Y-substrate),
  symbol-level conflict resolution via grit locks, reuse-over-duplicate, and re-verifying parity in
  Y's context. ALWAYS use when a port has a destination repo (`dest_repo` Y), when merging ported Rust
  into another repo, or on "port X and merge into Y", "merge the rust code into <repo>", "reconcile the
  port with <repo>". The rust-port → rust-port-merge arc of ADR-0001. Behavior preserved across the move.
---

# Rust-Port Merge

Porting a unit to Rust is half the arc; **merging it into destination repo Y** is the other half
(ADR-0001's `rust-port → rust-port-merge`). A merge is not a copy-paste — it *places, reconciles,
de-duplicates, and wires* the ported unit into Y's existing crates and substrates, then re-proves the
behavior **in Y's context**. The guarantee is the same as the port: **no feature logic left behind, no
downgrade — now across the merge too.** Used by `rust-port-merge-integrator`; the gate is
`rust-port-parity-verifier` re-run in Y.

## When this runs

Only when the run has a `dest_repo` Y (in `loop_state.md`). The ITERATE cycle becomes: port unit →
parity-verify (standalone) → **merge into Y** → build-health (Y) → **re-parity-verify in Y** → commit.
A unit is `merged` only after the re-verification passes in Y — a standalone PASS is necessary, not
sufficient.

## The landing decision (record per unit in `merge-ledger.md`)

For each parity-verified unit, decide where it lands in Y — informed by the **researcher's reuse map**
(`reports/research.md`: what Y already provides) and the **cross-repo reference map**
(`reports/cross-repo-refs.md`: who references what):

| Landing | When | Rule |
|---------|------|------|
| **New module/crate in Y** | Y has nothing equivalent | place in Y's layout, wire imports/exports/Cargo, follow Y's conventions |
| **Merge into existing Y module** | Y has a partial/overlapping impl | unify — *complete* Y's version with X's behavior; a duplicate is an incomplete unification (no-downgrade directive), wire it, don't leave two |
| **Map onto a Y substrate** | the unit is a runtime construct Y delegates to a substrate | map onto `hf`/`weave`/`grit`/`icm`/provider-CLI per `rust-port/references/runtime-constructs.md` — only if it preserves every behavior |

**Reuse > duplicate, but never reuse-by-narrowing.** Mapping onto a Y symbol/substrate is legal only if
it preserves **every** behavior in the unit's contract. A near-fit that loses a behavior is *extended*
(complete the feature), or — if genuinely impossible — a `- [!]`/`- [≠]` owner-decision, never a silent
narrowing.

## Symbol-level conflict resolution (grit, parallel-safe)

- Read the **blast radius** for the symbols you touch from `reports/cross-repo-refs.md` (every Y caller
  affected). Take a **grit symbol lock** on those Y symbols so a concurrent merge can't corrupt shared
  state; release on commit. Coarser-than-symbol locking is allowed (stricter is fine); skipping it is not.
- Resolve a collision by **unifying** the two sides (complete/merge), never by dropping one. If you
  truly can't reconcile without losing behavior, keep both, flag it, and route the decision up.
- A merge that touches a **contract Y's consumers depend on** (shared protocol/API/type) is checked for
  compatibility (the protocol-drift method via the cross-repo-referencer) — a wire/type change is a
  breaking change to flag, not silently ship.

## The no-downgrade-across-the-merge gate

The move itself can introduce a downgrade — a dropped re-export, a type narrowed to fit Y, a lost error
variant, a streaming path collapsed during integration. So **re-run the differential parity gate in Y's
context**: the merged code, called through Y, must still match source X over the unit's whole contract
(happy + every error/edge + runtime behaviors). Only that re-PASS flips the unit to `- [x]` in the merge
ledger. Y must also stay green (`cargo build`/`clippy`/`test`) — a merge that reds Y rolls back to `- [~]`.

## Merge-ledger & DONE

- Ledger schema + status legend + the merge DONE-gate: `rust-port/references/merge-ledger.md`.
- When `dest_repo` is set, **DONE also requires** the merge ledger at 100% (every unit `- [x]` merged +
  re-verified, or owner-approved `- [≠]`), Y's build/clippy/test green, and a merge left-behind sweep
  (no ported unit unmerged). The port-only DONE conditions still all apply.
