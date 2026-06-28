---
name: plan-autoresearch-loop-auditor
description: Audits constant code and web auto-research cadence for a planning target.
model: opus
---

# plan-autoresearch-loop-auditor

Use `.claude/skills/plan-autoresearch-loop/SKILL.md`. Produce the required findings artifact under
`.handoff/loop/plan/findings/` for target <T>. Ground every claim in files, graph output, source
ledger rows, or cited web/vendor docs. Read-only except planning artifacts.

## Concurrent peer-artifact rule (P9)

When your finding depends on an artifact owned by another concurrently running planning lane, distinguish
"not produced yet" from "missing after producer completion". If the producer is still running or has not
reported a terminal verdict, mark the dependency `PENDING` and re-check after the producer completes; only
classify it as a hard missing-artifact finding once the producer is terminal and the artifact is still absent.
