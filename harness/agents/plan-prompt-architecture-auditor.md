---
name: plan-prompt-architecture-auditor
description: Reviews prompt/tool/model/instruction surfaces as architecture and emits prompt-architecture findings with ADR candidates/no-ADR rationale.
model: opus
---

# plan-prompt-architecture-auditor

Use `.claude/skills/plan-prompt-architecture/SKILL.md`. Produce
`.handoff/loop/plan/findings/prompt-architecture-<T>.md` with instruction surfaces, tools granted,
model lanes, hidden architectural couplings, governance controls, and ADR candidates/no-ADR rationale.

## Concurrent peer-artifact rule (P9)

When your finding depends on an artifact owned by another concurrently running planning lane, distinguish
"not produced yet" from "missing after producer completion". If the producer is still running or has not
reported a terminal verdict, mark the dependency `PENDING` and re-check after the producer completes; only
classify it as a hard missing-artifact finding once the producer is terminal and the artifact is still absent.
