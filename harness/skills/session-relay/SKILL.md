---
name: session-relay
description: >-
  Handoff and resume protocol for the meta-plugin. ALWAYS use at a loop cycle-budget boundary
  (HAND OFF) and at the start of a fresh/continuing session (RESUME). Triggers on "hand off",
  "checkpoint the loop", "resume the loop", "pick up where it left off", "continue in a new
  session", "resume from HANDOFF.md". The committed HANDOFF.md is the authoritative resume
  signal — weave is only an observable heartbeat.
---

# Session Relay — handoff / resume

Makes the loop a **chain of short, fresh-context sessions**, each handing a durable checkpoint to
the next. A single long session rots (context fills, quality drops) and burns tokens; the defense
is to hand off at a cycle budget and resume cold from committed state.

## Two entry points

### HAND OFF (at cycle budget)

1. Spawn the **`continuity-steward`** agent (`model: "opus"`) to write `.handoff/loop/HANDOFF.md`
   (state + pointers + verify-on-resume commands — see that agent's definition).
2. **Commit** `.handoff/loop/HANDOFF.md` together with the cycle's state. The committed file — not
   any message — is the real payload.
3. Broadcast a weave heartbeat `to:"all"` with a `relay:handoff` tag summarizing where the loop
   stopped (current item, branch, commit). This is a **cross-identity observable heartbeat**, not
   the resume payload — do not rely on your own inbox (a self-addressed message doesn't land in
   it, and a same-machine successor inherits the same identity).
4. Best-effort one-shot successor: `CronCreate {recurring:false}` whose prompt self-describes the
   resume (`/meta-plugin resume from .handoff/loop/HANDOFF.md`). Treat as best-effort only —
   `durable:true` is not honored across restarts in this runtime; the committed HANDOFF.md is what
   actually guarantees continuation (a human, the external runner, or RemoteTrigger resumes from it).
5. **Stop** — do not `ScheduleWakeup`.

### RESUME (fresh or continuing session)

1. Read the committed `.handoff/loop/HANDOFF.md` (authoritative). If absent, fall back to DISCOVER.
2. Run its **Verify-on-resume** baseline commands first (from `.handoff/loop/baseline.md`). If the
   baseline is not green, do NOT continue feature work — fix/triage the baseline first, or surface
   `NEEDS-HUMAN`.
3. Broadcast a weave `relay:resumed` heartbeat `to:"all"`.
4. Reset `cycles_this_session = 0` in `.handoff/loop/loop_state.md` (keep `cycles_total`).
5. Continue the `meta-plugin` at the backlog's current `- [ ]` item.

## Multi-system release & resume (grit + handoff + fleet + .kb)

The loop now runs over several integrated systems; a clean handoff must release/record
in **all** of them, not just write HANDOFF.md (see the handoff kernel's `session-relay`
+ `systems-conduct` skills). State precedence everywhere: **Git > ledger > cards > .kb >
prose.**

**On HAND OFF, additionally:**
- **grit** — `grit done --agent <id>` for every active agent (merges its worktree +
  releases its AST-symbol locks); `grit gc` strays; confirm `grit status` is clean. A
  held grit lock blocks the next session.
- **handoff** — `hf checkpoint <ID> "<landed/verified/next>"` → `hf handoff` (re-render
  the packet from the **real** ledger, in the repo that owns it).
- **fleet** — `hf fleet render <repo>` for any repo whose state changed; `.kb` write-back
  via `hf sync` (when envctl injection is up).

**On RESUME, additionally:**
- Check `hf fleet status` (where the fleet stands; which repos have `ready` work) and
  `grit status`/`grit worktree list` (orphaned locks/worktrees from a crashed session →
  `grit gc`).
- **Selection is hybrid, not auto-backfill:** auto-claim only tasks flagged `ready:true`
  in their capsule/card; otherwise orient and let the orchestrator pull the
  highest-value task across the fleet. Do not auto-work every repo's backlog (FLEET
  ledger swamp).

## Non-negotiables

- **Write state down every cycle** — never hold the plan only in context.
- **Commit the checkpoint** — a fresh process must resume from committed state alone.
- **Fail-closed on a red baseline** — resume verifies before it builds.
- **Release every system on handoff** — never leave a grit lock held or a worktree dirty.
- **Pull by value, don't backfill** — sessions orient; the orchestrator selects.
