# Harness Upgrade Kits

Bring any repo to **autonomous, resumable, self-restarting** harness operation — the pattern
proven in `envctl` (durable backlog → one item per cycle → hand off to a fresh session at a cycle
budget → optional unattended self-restart with a clean context per cycle, the "/new" effect).
Truth lives on disk (backlog + checkpoints + commits), so any restart resumes cold with zero loss.

## Files

| File | What |
|------|------|
| `_GENERIC.md` | The full, repo-agnostic kit (principles, 6 deliverables, templates, the `/new` runner skeleton). Same as `~/Desktop/meta/HARNESS-UPGRADE-KIT.md`. |
| `prompt_hub.md` | Tailored sheet — greenfield Rust loop (`just`, CLI `prompthub`). |
| `lane.md` | Tailored sheet — Rust; wraps lane's existing IDD design/verify skills. |
| `weave.md` | Tailored sheet — Rust; dogfoods weave (the relay substrate) with a bootstrap-hazard guardrail. |
| `n8n.md` | Tailored sheet — Node/pnpm; reuses n8n's existing harness + `_workspace/`. |
| `idd-merge-idd.md` | Tailored sheet — Rust merge/port loop (`idd scan/plan/validate`, `rtk`). |

## How to use

1. Open the tailored sheet for the target repo; read `_GENERIC.md` for the full pattern + templates.
2. In a **fresh git worktree** of that repo (never dirty `master`), create the 6 deliverables:
   `_workspace/` state · the loop skill · `session-relay` · `continuity-steward` · the
   `/<loop> resume` slash command · the external `ralph-<x>.sh` runner.
3. Match the sheet's DONE/verify commands; keep the harness hand-authored + git-tracked.

Each target repo's `CLAUDE.md` points here (section "Harness: autonomous / resumable operation").

*Source pattern: `envctl` — skills `forge-loop`/`env-install-loop`/`session-relay`/`auto-provision`,
agent `continuity-steward`, runner `auto-provision/scripts/ralph-provision.sh`.*
