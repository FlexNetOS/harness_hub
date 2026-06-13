---
name: handoff-loop
description: >-
  Runs a repo's autonomous loop on the `hf` Continuity Ledger Kernel — the kernel-backed alternative
  to the file-based meta-plugin/rust-port loops. ALWAYS use to run/resume/continue a kernel loop in a
  repo whose .handoff/ was built by handoff-loop-init: "run the handoff loop", "resume the kernel
  loop", "continue", "do the next HFTASK", "pick up where it left off", "re-run". One witnessed task
  per cycle: resume → drift-reconcile → claim → work-in-scope → checkpoint → policy gate → handoff.
  Defers to the kernel's hard rules; never hand-writes a packet or bypasses a gate.
---

# handoff-loop — kernel-backed autonomous loop (drives `hf`)

The continuity-kernel loop for a repo set up by `handoff-loop-init`. Where the file-based loops
(`meta-plugin`, `rust-port`, `code-research`) keep state in `.handoff/loop/` markdown, this loop runs
on the **witnessed ledger**: state is the kernel's, packets are *rendered* by `hf` (never
hand-written), and every claim/edit/handoff passes the kernel's policy gates. The repo is the source
of truth; chat history and a stale packet are not.

> This is the *generic, kernel-USE* loop any repo can run. It is distinct from `meta/handoff`'s own
> repo-specific `handoff-loop` (which develops the kernel itself). Both ride the same `hf` protocol.

## Prerequisite
`.handoff/` built by `handoff-loop-init` (i.e. `hf init` has run) and `hf` on PATH. If not →
run `handoff-loop-init` first (or `NEEDS-HUMAN` if `hf` is absent).

## One cycle (one witnessed task)

1. **Resume** — `hf resume` (first command). Read the kernel's navigation order: `.handoff/active.md`
   → `context/capsule.json` → `packets/latest.md` → `tasks/` + `decisions/`. The committed ledger/
   packet is authoritative — not your inbox, not memory.
2. **Reconcile drift** — `hf drift` (and `hf policy check-claim`). A failing gate is a wall; fix or
   surface it, don't paper over it.
3. **Pick the next safe task** — the top `ready` HFTASK whose scope doesn't overlap an active claim;
   `hf claim <ID>`. **Claim before editing**; stay strictly in the claimed path scope.
4. **Work** — implement the task; tests/verification required (no "done" without tests or an explicit
   waiver). Architecture changes need an ADR (`.handoff/decisions/`).
5. **Checkpoint** — `hf checkpoint <ID> [note]` (witness progress to the ledger).
6. **Policy gate + handoff** — `hf policy check-edit`/`check-handoff`, `hf drift`, then `hf done <ID>
   [--pr N]` / `hf ship` as appropriate, and `hf handoff` to render the packet. Never stop without
   `hf checkpoint` + `hf handoff`.
7. **Self-pace / hand off at budget** — integrate with `session-relay-wrap-up` (which calls
   `hf checkpoint`/`hf handoff` when the kernel is present) + `session-relay-resume` (`hf resume`
   first), and close the session with the Phase-E `harness-evolution` retro.

## Hard rules (from the kernel — do not violate)
- No edit without a task claim; no writing outside claimed scope; no parallel write session on
  overlapping paths.
- No task marked complete without tests or an explicit waiver; no architecture change without an ADR.
- `.handoff/packets/latest.md` is **not** more authoritative than Git, the ledger, or task cards.
- Always `hf checkpoint` + `hf handoff` before stopping; run `hf drift` before any handoff.

## Fleet (multi-repo)
`hf fleet status` shows where the fleet stands; `hf fleet render <member>` updates a member's view.
Selection is **pull-by-value, not auto-backfill** — auto-claim only `ready` tasks; otherwise orient
and let the highest-value task be pulled. Don't drain every repo's backlog.
