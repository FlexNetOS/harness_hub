# Harness Upgrade — weave (tailoring sheet)

Follow the generic kit: `~/Desktop/meta/HARNESS-UPGRADE-KIT.md` (or `./_GENERIC.md`).
This sheet fills in the `<…>` placeholders for **weave**. Special case: **weave IS the relay
substrate** the loop uses for handoff heartbeats — so dogfood it, but isolate it (below).

| Field | Value |
|-------|-------|
| Repo / path | `FlexNetOS/weave` · `~/Desktop/meta/weave` |
| Language | Rust (single crate) |
| CLI | `weave` (+ the `session`/`stop`/`prompt` lifecycle hooks) |
| Existing harness | `weave` skill (usage); no loop yet |
| Loop name `<loop>` | `weave-loop` |
| Runner | `.claude/skills/weave-loop/scripts/ralph-weave.sh` · opt-in env `WEAVE_APPLY=1` |
| Resume command | `/weave-loop resume from _workspace/HANDOFF.md` |

**DISCOVER:** backlog = open issues / roadmap for the mesh (transport, inbox semantics, peer
presence, hook lifecycle). One item per cohesive change.

**VERIFY per cycle:**
```bash
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo test
```

**DONE criteria (all pass → `_workspace/DONE` with evidence):**
```bash
cargo build && cargo test && cargo fmt --all -- --check && cargo clippy --all-targets -- -D warnings
```
Plus backlog clear; blocked items surfaced.

**Repo-specific guardrail — the bootstrap hazard:** the loop's `session-relay` heartbeat
(`relay:handoff`/`relay:resumed`, `to:"all"`) runs over weave itself. If a cycle changes weave's
own wire/inbox behavior, **do not depend on the live `weave` binary for the handoff** that cycle —
the **committed `_workspace/HANDOFF.md` is the authoritative resume signal anyway** (weave is only
the observable heartbeat), so a fresh session resumes correctly even if weave is mid-change. Pin a
known-good `weave` on PATH for the relay, or skip the heartbeat and rely on the committed checkpoint.
Re-verify the heartbeat works *after* the build passes, before handing off.
