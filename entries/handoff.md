# handoff (continuity kernel)

**Category:** orchestrator · **Status:** beta · **Runtime:** multi · **Repo:** `git@github.com:FlexNetOS/handoff.git`

The FlexNetOS **handoff / continuity kernel** — the `hf` binary plus a `.handoff/` **witnessed
ledger**. It is the *only sanctioned cross-session continuity path* (ADR-0004 / policy P7.36):
checkpoint and handoff packets are **rendered from the ledger, never hand-written**, so a fresh
session resumes cold from committed, witnessed state with zero loss.

## What it ships

- **`hf` kernel** (Rust) — `hf checkpoint` / `hf handoff` / `hf resume` / `hf fleet status|render` /
  `hf sync`. Packets are compiled from the ledger; residency rules keep `.handoff/` git-text only.
- **`handoff-discipline` harness** — a full `.claude/` team: orchestrator + specialist skills
  (`fleet-handoff`, `handoff-loop`, `session-relay`, `drift-reconcile`, `kernel-verify`, …) and
  agents (`continuity-navigator`, `fleet-steward`, `kernel-implementer`, `kernel-verifier`, …).
- **Fleet coordination** — multiple sessions/repos hand off and resume against the shared ledger.

## How to use

In the meta workspace, drive it through the `handoff-discipline` skill / slash commands:
`/handoff` · `/resume` · `/mint` · `/checkpoint` · `/fleet`. Queued approvals are decided by the
`handoff-steward` agent (witnessed verdicts only; scope law applies).

## Relationship to this hub

harness_hub catalogs `handoff` as a **peer** (it lives in its own repo, `FlexNetOS/handoff`, and is
a `.meta.yaml` workspace member) — it is not vendored here. The packaged `meta-plugin` harness in
this hub defers its continuity to this kernel: prefer `hf` verbs when reachable, file-based
`.handoff/loop/` fallback otherwise.
