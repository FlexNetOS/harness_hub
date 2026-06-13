# handoff-loop (vendored)

A **vendored snapshot** of the `handoff-loop` harness from **`FlexNetOS/handoff`** (`meta/handoff`),
the Continuity Ledger Kernel. Brought into harness_hub so the hub carries the kernel-backed loop
harness alongside its other harnesses (like `harness/` vendors the harness toolkit).

## Provenance
- Source: `meta/handoff` (the `hf` kernel repo). The canonical, maintained version lives there.
- Snapshot date: 2026-06-13.

## What's vendored
`.claude/` (12 skills + 9 agents), `.agent/`, `.handoff/` (kernel structure: context, decisions,
fleet, hooks, packets, policies, skills, tasks — **minus the binary `ledger.db`**), `.grit/`,
`.github/`, `docs/`, `schemas/`, `scripts/`, and the guide files (`AGENTS.md`, `CLAUDE.md`,
`FLEET_GUIDE.md`, `NEEDS-HUMAN.md`).

## What's intentionally NOT vendored (left in meta/handoff)
- **The Rust kernel source** — `hf/`, `ledger/`, `work-order/`, `Cargo.toml`, `Cargo.lock`. The `hf`
  binary is built and owned by `meta/handoff`; install it from there.
- Build/scratch/IDE/repo: `target/`, `_workspace/`, `_workspace_prev/`, `.idea/`, nested `.git/`.
- `.handoff/ledger.db` — the live binary ledger (P7 residency rule: never vendor a `*.db`).

## Note
This is a reference/library snapshot, not a live kernel. To run the kernel-backed loop, use the
`hf` binary (from meta/handoff) + the `/harness:handoff-loop-init` (build `.handoff/`) and
`/harness:handoff-loop-run` plugin skills. Re-sync this snapshot from `meta/handoff` when it evolves.
