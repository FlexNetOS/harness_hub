# rust-port (full-parity Rust port loop)

**Category:** orchestrator · **Status:** beta · **Runtime:** multi · **Command:** `/harness:rust-port`

A packaged harness that performs a **full-feature, no-downgrade port of a source project to
idiomatic Rust** — *no feature logic left behind*. The guarantee is structural, not aspirational: a
**parity ledger** inventories every source unit, and the port is `DONE` only when that ledger reaches
100% and a left-behind sweep finds nothing missing.

It also does **port-and-merge**: port source repo X to Rust **and merge each verified unit into a
destination repo Y** (re-verified in Y's context — the ADR-0001 `rust-port → rust-port-merge` arc),
with research/cross-repo agents so the port maps onto what Y already provides instead of duplicating it.
Runs an **automated 3-model workflow** (opus on gates/hard design, sonnet on structured work, haiku on
mechanical) — gates are never tiered down.

Flagship use case: a full-capability **TypeScript → Rust** port of [`meta/Archon`](https://github.com/FlexNetOS/Archon),
merged into `harness-agent-rs`.

## How it guarantees no downgrade

1. **Exhaustive inventory, two grains** (`rust-port-cartographer`) — every module/unit becomes a
   *parity-ledger* row, and every source *symbol* (exported fn, type, method, field, const, enum
   variant, trait, CLI flag, HTTP route) becomes a *symbol-map* row (`.handoff/loop/symbol-map.md`),
   harvested deterministically from the AST/index (`git kb code symbols --json --limit -1`, never
   grep) so coverage is provable. Each row carries its *contract* (not just its name). A unit is
   `- [x]` only when all its symbols are — so a dropped method/field/variant/route can't hide.
2. **Idiom mapping** (`rust-port-architect`) — source→Rust conventions decided once (error model,
   async, traits, ownership, serde) + a dependency-equivalent table. A missing Rust equivalent is
   never grounds to drop a feature (vendor / reimplement / FFI instead).
3. **Full port, no stubs** (`rust-port-porter`) — one unit per cycle, every branch implemented; a
   `todo!()` or dropped error path is a downgrade and is forbidden.
4. **Differential parity proof** (`rust-port-parity-verifier`) — runs source and Rust over the same
   inputs (all branches) and diffs outputs/side-effects/errors. Only a behavioral `PASS` flips a unit
   to verified. The compile is a precondition, not the verdict.
5. **Merge into Y — bidirectional no-downgrade** (`rust-port-merge-integrator`, when a destination repo
   is set) — units are classified up-front (`port-fresh`/`extend-Y`/`reuse-Y`/`map-onto-substrate`) so
   the loop never re-ports what Y already provides; each lands in Y (new module / merge-into-existing /
   map-onto a substrate), symbol-locked via grit, in a **per-task Y worktree + feature branch**
   (atomic — commit iff it passes, else `reset --hard`). The gate is **bidirectional**: the merge must
   still match source X **and not regress Y's own behavior** (a Y-regression diff vs Y's captured
   baseline). Y-drift is reconciled on resume (rebase + re-verify drifted units); breaking contracts are
   **resolved** (shim/adapter/version), not just flagged; merge-DONE opens a **PR into Y with auto-merge**.
6. **DONE gate** — left-behind sweep clean **at both grains** (no unmapped unit AND no unmapped
   symbol; every `- [x]` unit has 100% verified symbols) + every unit and **every symbol** verified
   (or an explicit, owner-approved `- [≠]` divergence) + `cargo build`/`clippy`/`test` green **+ (when
   merging) the merge ledger 100% re-verified in Y and Y green**.

## Shape

- **Skills** (`harness/skills/`): `rust-port` (orchestrator) + `rust-port-inventory`,
  `rust-port-translate`, `rust-port-parity`, `rust-port-merge`, `cross-repo-reference` (+ shared
  `icm-memory` [persistent memory any agent recalls/stores as needed], `session-relay-wrap-up`,
  `session-relay-resume`, `cross-repo-health`, `harness-loop-init`, `harness-evolution`; research
  reuses `code-research-*` + `deep-research`).
- **Agents** (shared `harness/agents/`): `rust-port-cartographer`, `rust-port-architect`,
  `rust-port-porter`, `rust-port-parity-verifier`, `rust-port-merge-integrator`, `rust-port-researcher`,
  `rust-port-cross-repo-referencer` (7 specialists) + `build-health-auditor`, `continuity-steward`,
  `evolution-steward` (shared infra). 3-model tiered (opus gates / sonnet workers / haiku mechanical).
- **Execution mode:** hybrid — single-orchestrator Ralph loop, file-based state under `.handoff/loop/`
  (durable so the parity ledger survives the self-restart boundary).

## Run / eject

- **Run in place:** `/harness:rust-port` (and `/harness:rust-port resume` to continue).
- **Eject into the port repo:** `bash harness/skills/rust-port/scripts/eject.sh <target-repo>` (then
  `/rust-port`). The parity-verifier must be able to *run the source*, so the source toolchain
  (bun/node/python) is needed in the port environment. See `harness/skills/rust-port/references/eject.md`.
- **External runner (SAFE):** `harness/skills/rust-port/scripts/ralph-rust-port.sh`.

Built per the [packaged-harness standard](../docs/packaged-harness-standard.md).
