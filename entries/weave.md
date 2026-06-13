# weave (agent session mesh)

**Category:** orchestrator · **Status:** beta · **Runtime:** rust · **Repo:** `git@github.com:FlexNetOS/weave.git`

A **Rust-native agent-to-agent session mesh** with a native terminal injector. It lets concurrent
coding-agent sessions (Claude Code, etc.) **message each other** and **push into a running
session's pane** (tmux *or* zellij) so a peer is flagged the moment a message arrives — degrading
to hook-delivery-on-next-turn when no multiplexer is present. One static binary; no Python, no
daemon.

## What it ships

- **`weave` binary** + crates `weave-core`, `weave-mcp`, `weave-inject`.
- **MCP server** — `weave_send` / `weave_ask` / `weave_inbox` / `weave_broadcast_*` / `weave_thread`
  / `weave_job_*` / `weave_lease_*` and more (the tools that carry this workspace's fleet traffic).
- Native **tmux/zellij injection** + a poll/hook fallback.

## Role in the workspace

weave is the **real-time messaging substrate** — the *space* axis of coordination. It is the
complement to the [handoff](handoff.md) continuity kernel (the *time* axis): handoff persists
witnessed state across sessions, weave moves signals between concurrent sessions. The
`relay:handoff` / `relay:cycle-done` heartbeats that fleet loops broadcast travel over weave;
handoff's committed packet remains the authoritative resume payload, weave the observable heartbeat.

## Harness

weave carries its own autonomous dev harness (`.claude/`: `weave-loop` / `weave-orchestrator` /
`weave-invariants` / `weave-drift-guard` / `weave-test-discipline` + planner/implementer/verifier/
guardian agents) descended from the same envctl autonomous-operation pattern — used to build the
binary itself.
