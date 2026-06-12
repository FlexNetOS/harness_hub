> **v2 retarget (2026-06-12, ADR-0004 / policy P7.36):** `_workspace/` is deprecated for NEW
> state — durable loop state now lives in **`.handoff/loop/`**, and when the meta workspace
> kernel is reachable, backlog/checkpoints/relay use `hf` verbs (`mint` / `checkpoint` /
> `handoff`) instead of files. Existing `_workspace/` content keeps its history; migrate
> opportunistically, never bulk-delete. Full protocol: `_GENERIC.md` (v2).

# Harness Upgrade — lane (tailoring sheet)

Follow the generic kit: `~/Desktop/meta/HARNESS-UPGRADE-KIT.md` (or `./_GENERIC.md`).
This sheet fills in the `<…>` placeholders for **lane**. lane already has the *design + verify*
halves of a crew — you're adding the **loop + continuity + /new runner** on top (don't rebuild
the skills it has).

| Field | Value |
|-------|-------|
| Repo / path | `FlexNetOS/lane` · `~/Desktop/meta/lane` |
| Language | Rust (11-crate Cargo workspace) |
| CLI | `lane` |
| Existing harness (REUSE) | `intent-driven-development`, `intent-to-spec`, `lane-feature-design`, `lane-verification`, `rust-native-guard`, `rust-native-implementation` |
| Loop name `<loop>` | `lane-loop` |
| Runner | `.claude/skills/lane-loop/scripts/ralph-lane.sh` · opt-in env `LANE_APPLY=1` |
| Resume command | `/lane-loop resume from _workspace/HANDOFF.md` |

**Per-cycle body — DRIVE your existing skills (analogous to envctl's architect→implementer→guardian):**
`lane-feature-design` (or `intent-to-spec`) → `rust-native-implementation` → `lane-verification`
(+ `rust-native-guard`). The loop just sequences these per backlog item, checkpoints, and hands off.

**DISCOVER:** backlog = open intents / `docs` roadmap / issues, run through `intent-to-spec`.

**VERIFY per cycle:**
```bash
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo test                      # 37 in-module #[cfg(test)] suites
```
plus the `lane-verification` skill's checks.

**DONE criteria (all pass → `_workspace/DONE` with evidence):**
```bash
cargo build && cargo build --release    # release: opt-level=z, LTO, panic=abort, stripped
cargo test                              # green
cargo fmt --all -- --check && cargo clippy --all-targets -- -D warnings
```
Plus backlog clear; `lane-verification` green; blocked items surfaced.

**Repo-specific guardrails:** rust-native by mandate (remove foreign artifacts; `rust-native-guard`).
Heads-up: `lane doctor`'s CA-trust + port-forwarding probes currently false-negative
(FlexNetOS/lane#5) — don't let a verify cycle trust `lane doctor` for those two until #5 lands.
