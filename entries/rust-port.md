# rust-port (full-parity Rust port loop)

**Category:** orchestrator · **Status:** beta · **Runtime:** multi · **Command:** `/harness:rust-port`

A packaged harness that performs a **full-feature, no-downgrade port of a source project to
idiomatic Rust** — *no feature logic left behind*. The guarantee is structural, not aspirational: a
**parity ledger** inventories every source unit, and the port is `DONE` only when that ledger reaches
100% and a left-behind sweep finds nothing missing.

Flagship use case: a full-capability **TypeScript → Rust** port of [`meta/Archon`](https://github.com/FlexNetOS/Archon).

## How it guarantees no downgrade

1. **Exhaustive inventory** (`rust-port-cartographer`) — every module, export, behavior, error path,
   config key, CLI flag, route, side effect, and edge case becomes a parity-ledger row with its
   *contract* (not just its name).
2. **Idiom mapping** (`rust-port-architect`) — source→Rust conventions decided once (error model,
   async, traits, ownership, serde) + a dependency-equivalent table. A missing Rust equivalent is
   never grounds to drop a feature (vendor / reimplement / FFI instead).
3. **Full port, no stubs** (`rust-port-porter`) — one unit per cycle, every branch implemented; a
   `todo!()` or dropped error path is a downgrade and is forbidden.
4. **Differential parity proof** (`rust-port-parity-verifier`) — runs source and Rust over the same
   inputs (all branches) and diffs outputs/side-effects/errors. Only a behavioral `PASS` flips a unit
   to verified. The compile is a precondition, not the verdict.
5. **DONE gate** — left-behind sweep clean + every unit verified (or an explicit, owner-approved
   `- [≠]` divergence) + `cargo build`/`clippy`/`test` green.

## Shape

- **Skills** (`harness/skills/`): `rust-port` (orchestrator) + `rust-port-inventory`,
  `rust-port-translate`, `rust-port-parity` (+ shared `session-relay`, `cross-repo-health`).
- **Agents** (shared `harness/agents/`): `rust-port-cartographer`, `rust-port-architect`,
  `rust-port-porter`, `rust-port-parity-verifier` (specialists) + `build-health-auditor`,
  `continuity-steward` (shared infra).
- **Execution mode:** hybrid — single-orchestrator Ralph loop, file-based state under `.handoff/loop/`
  (durable so the parity ledger survives the self-restart boundary).

## Run / eject

- **Run in place:** `/harness:rust-port` (and `/harness:rust-port resume` to continue).
- **Eject into the port repo:** `bash harness/skills/rust-port/scripts/eject.sh <target-repo>` (then
  `/rust-port`). The parity-verifier must be able to *run the source*, so the source toolchain
  (bun/node/python) is needed in the port environment. See `harness/skills/rust-port/references/eject.md`.
- **External runner (SAFE):** `harness/skills/rust-port/scripts/ralph-rust-port.sh`.

Built per the [packaged-harness standard](../docs/packaged-harness-standard.md).
