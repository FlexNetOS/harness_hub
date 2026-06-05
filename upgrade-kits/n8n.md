# Harness Upgrade — n8n (tailoring sheet)

Follow the generic kit: `~/Desktop/meta/HARNESS-UPGRADE-KIT.md` (or `./_GENERIC.md`).
This sheet fills in the `<…>` placeholders for **n8n**. This is the **non-Rust** case — the
pattern is language-agnostic; wire it to pnpm. n8n already has a rich harness and a `_workspace/`
— **reuse them**, don't duplicate.

| Field | Value |
|-------|-------|
| Repo / path | `FlexNetOS/n8n` · `~/Desktop/meta/n8n` |
| Language | Node / TypeScript (pnpm monorepo) |
| Existing harness (REUSE) | `spec-driven-development`, `run-n8n`, `create-pr`, `mutant-{score,diff,fix}`, `db-migrations`, … + an existing `_workspace/` |
| Durable state | **reuse the existing `_workspace/`** for `backlog.md`/`loop_state.md`/`HANDOFF.md` |
| Loop name `<loop>` | `n8n-loop` |
| Runner | `.claude/skills/n8n-loop/scripts/ralph-n8n.sh` · opt-in env `N8N_APPLY=1` |
| Resume command | `/n8n-loop resume from _workspace/HANDOFF.md` |

**Per-cycle body — drive existing skills:** `spec-driven-development` (design the slice) →
implement → `run-n8n` smoke + tests (verify) → optionally `mutant-score` for test strength.

**DISCOVER:** backlog = open issues / spec docs / the existing `_workspace/` state. One item per slice.

**VERIFY per cycle:**
```bash
pnpm build              # or the package-scoped build for the touched package
pnpm test               # scope to the affected package(s) for speed
# lint per repo convention (biome/eslint); run-n8n smoke for runtime-affecting changes
```

**DONE criteria (all pass → `_workspace/DONE` with evidence):**
- `pnpm build` clean · affected `pnpm test` green · lint clean ·
  `run-n8n` smoke healthy (e.g. `/healthz` 200) for runtime changes · backlog clear.

**Repo-specific guardrails:** scope build/test to affected packages — a full monorepo build per
cycle is too slow to loop on. The kit's "safe-by-default vs `N8N_APPLY`" maps to *whether the
unattended runner may push / open PRs* (via `create-pr`), not system mutation. Keep the existing
`_workspace/` conventions; just add the loop ledger + sentinels alongside.
