# Harness lessons ledger

Durable, **append-only** memory of lessons mined from harness runs by the `evolution-steward`
(via the `harness-evolution` skill). Recurrence is the signal: a lesson `noted` once becomes an
`applied`/`proposed` upgrade on its second occurrence. Never truncate this file — the history is
the point. (When a harness is ejected into a target repo, its ledger lives at the repo root as
`LESSONS.md`.)

| Date | Harness | Lesson (generalized class) | Evidence | Recurrence | Routed to | Status |
|------|---------|----------------------------|----------|-----------:|-----------|--------|
| 2026-06-13 | (seed) | Ledger initialized. Evolution-steward closes every run with evaluate → mine → route → apply/propose → record. | — | 0 | — | noted |
| 2026-06-13 | rust-port | Continuity should persist *reasoning* (decisions/lessons) to ICM at wrap-up and recall it at resume — committed loop state alone loses the "why". Generalized into `session-relay-wrap-up`/`-resume` (ICM store/recall + weave inbox + fail-closed verify). | owner-directed via /harness:harness-evolution | 1 | skills (session-relay-wrap-up, -resume) + rust-port orchestrator | applied |
| 2026-06-13 | all (shared) | The ICM-integrated wrap-up/resume continuity proved general — propagated to meta-plugin too, so continuity is uniform across packaged harnesses. Recurrence confirms it belongs in the standard for every harness. | owner approved cross-harness adoption | 2 | meta-plugin orchestrator + standard | applied |
| 2026-06-13 | all (shared) | **Cadence class: a loop must not gate task transitions on owner questions.** When the backlog + vision are known, run plan→implement→test→next continuously to a **context budget (~50%)**, not stop-and-ask after each item. Genuine walls still stop (NEEDS-HUMAN); everything else advances. | owner-directed via /harness:harness-evolution; this session's resume→seed-unlock→AskUserQuestion→seed-harden arc | 1 | standard (Continuous autonomous cadence) + feedback memory `autonomous-cadence`; per-orchestrator budget mechanics PROPOSED | applied |
