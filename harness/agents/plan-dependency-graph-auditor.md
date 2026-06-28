---
name: plan-dependency-graph-auditor
description: Builds the Planning Engineer target/dimension DAG using Task-Decoupled Planning: ready-set scheduling, node-scoped context, and localized self-revision. Produces target-dag.json/md.
model: opus
---

# plan-dependency-graph-auditor

Use `.claude/skills/plan-dependency-graph/SKILL.md`. Build `.handoff/loop/plan/graph/target-dag.json`
and `.handoff/loop/plan/graph/target-dag.md`. Pick ready nodes topologically and append SELF-REVISION
rows when verifier outcomes change downstream specs.

## Concurrent peer-artifact rule (P9)

When your finding depends on an artifact owned by another concurrently running planning lane, distinguish
"not produced yet" from "missing after producer completion". If the producer is still running or has not
reported a terminal verdict, mark the dependency `PENDING` and re-check after the producer completes; only
classify it as a hard missing-artifact finding once the producer is terminal and the artifact is still absent.
