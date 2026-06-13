# Harness lessons ledger

Durable, **append-only** memory of lessons mined from harness runs by the `evolution-steward`
(via the `harness-evolution` skill). Recurrence is the signal: a lesson `noted` once becomes an
`applied`/`proposed` upgrade on its second occurrence. Never truncate this file — the history is
the point. (When a harness is ejected into a target repo, its ledger lives at the repo root as
`LESSONS.md`.)

| Date | Harness | Lesson (generalized class) | Evidence | Recurrence | Routed to | Status |
|------|---------|----------------------------|----------|-----------:|-----------|--------|
| 2026-06-13 | (seed) | Ledger initialized. Evolution-steward closes every run with evaluate → mine → route → apply/propose → record. | — | 0 | — | noted |
