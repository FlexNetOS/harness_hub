> **v2 retarget (2026-06-12, ADR-0004 / policy P7.36):** `_workspace/` is deprecated for NEW
> state — durable loop state now lives in **`.handoff/loop/`**, and when the meta workspace
> kernel is reachable, backlog/checkpoints/relay use `hf` verbs (`mint` / `checkpoint` /
> `handoff`) instead of files. Existing `_workspace/` content keeps its history; migrate
> opportunistically, never bulk-delete. Full protocol: `_GENERIC.md` (v2).

# Harness Upgrade — idd-merge-idd (tailoring sheet)

Follow the generic kit: `~/Desktop/meta/HARNESS-UPGRADE-KIT.md` (or `./_GENERIC.md`).
This sheet fills in the `<…>` placeholders for **idd-merge-idd**. This is a **merge/port loop**:
each cycle = one vertical slice / one repo merge. It already has the design+verify+evidence skills
— add the loop + continuity + /new runner around them.

| Field | Value |
|-------|-------|
| Repo / path | `drdave-flexnetos/idd-merge-idd` · `~/Desktop/idd-merge-idd` (note: NOT under `meta/`) |
| Language | Rust (`rtk`-wrapped cargo); CLI `idd` |
| Existing harness (REUSE) | `repo-inventory`, `vertical-slice-planning`, `merge-orchestrator`, `rust-native-implementation`, `merge-verification`, `pr-evidence-bundle`, `lifecycle-porting` |
| Loop name `<loop>` | `idd-merge-loop` |
| Runner | `.claude/skills/idd-merge-loop/scripts/ralph-idd.sh` · opt-in env `IDD_APPLY=1` |
| Resume command | `/idd-merge-loop resume from _workspace/HANDOFF.md` |

**Per-cycle body — drive existing skills:** `vertical-slice-planning` (pick the slice) →
`rust-native-implementation` → `merge-verification` → `pr-evidence-bundle`. The loop sequences
these per slice, checkpoints, hands off.

**DISCOVER (the backlog writes itself here):**
```bash
idd scan         # walk repos -> RepoInventory (model.rs)
idd plan         # render inventories + merge plan + tasks
```
Backlog = the generated merge tasks / vertical slices, in dependency order.

**VERIFY per cycle (note `rtk` wrapping + `idd validate` is fail-closed):**
```bash
idd validate                                   # CRITICAL findings exit non-zero — gate the cycle
rtk cargo fmt --all -- --check
rtk cargo clippy --workspace --all-targets --all-features -- -D warnings
rtk cargo test --workspace --locked            # CI mode: fails on Cargo.lock drift
```

**DONE criteria (all pass → `_workspace/DONE` with evidence):**
- `idd validate` clean (no critical) · `rtk cargo build --workspace` · `test --workspace --locked`
  green · fmt `--check` + clippy `-D warnings` clean · `pr-evidence-bundle` produced · backlog clear.

**Repo-specific guardrails:** all writes go through `fs_utils::write_string_preserving_existing`
(**backup-on-overwrite**) — respect it; don't clobber existing files. `idd validate` is the
fail-closed gate — never tick a slice whose validation has critical findings. rust-native by mandate.
