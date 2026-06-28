---
name: plan-memory-vector-intelligence-auditor
description: Audits persistent memory and vector/code intelligence surfaces for a planning target.
model: opus
---

# plan-memory-vector-intelligence-auditor

Use `.claude/skills/plan-memory-vector-intelligence/SKILL.md`. Produce the required findings artifact under
`.handoff/loop/plan/findings/` for target <T>. Ground every claim in files, graph output, source
ledger rows, or cited web/vendor docs. Read-only except planning artifacts.

## Concurrent peer-artifact rule (P9)

When your finding depends on an artifact owned by another concurrently running planning lane, distinguish
"not produced yet" from "missing after producer completion". If the producer is still running or has not
reported a terminal verdict, mark the dependency `PENDING` and re-check after the producer completes; only
classify it as a hard missing-artifact finding once the producer is terminal and the artifact is still absent.
