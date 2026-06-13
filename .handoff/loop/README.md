# `.handoff/loop/` — durable loop state (the source of truth)

The `repo-org-loop` harness keeps **all** its state here, on disk, committed every cycle, so any
fresh process resumes cold with zero loss. Nothing the loop needs lives only in agent context.

| File | Role |
|------|------|
| `backlog.md` | The single source of truth: ordered checklist, one item per gap. `- [ ]` todo · `- [x]` done+verified · `- [!] blocked: <reason>`. |
| `loop_state.md` | The ledger (counters, budget, current item). Seeded from `.claude/skills/repo-org-loop/scripts/loop_state.template.md`. |
| `baseline.md` | The verify-on-resume command block — what a successor runs FIRST to confirm green. |
| `HANDOFF.md` | Written by `continuity-steward` at a cycle budget. The **authoritative** cold-resume signal. |
| `findings/health.md` | Per-repo build/test/lint/validate matrix (build-health-auditor). |
| `findings/registry.md` | Catalog consistency findings (registry-curator). |
| `findings/drift.md` | Protocol↔consumer contract findings (protocol-drift-analyst). |
| `findings/qa.md` | Cross-boundary verification verdicts (integration-qa). |
| `reports/inventory.md` | Combined cross-repo classification / routing report. |
| `DONE` / `NEEDS-HUMAN` / `STOP` | Terminal sentinels read by the external runner (see the loop SKILL). |

**Committed every cycle:** `backlog.md`, `loop_state.md`, `baseline.md`, `HANDOFF.md`, and the
`findings/` + `reports/` content, alongside the touched repo files.
**Gitignored:** the per-run `*.log` files (`.handoff/loop/*.log`, `ralph-run-*.log`).
