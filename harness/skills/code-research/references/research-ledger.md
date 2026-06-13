# Research ledger — the dimensions + claim/verdict contract

`.handoff/loop/research-ledger.md` tracks the investigation; the report is only as complete as this
ledger. Owned by `code-research-cartographer`; dimension status gated by `code-research-verifier`.

## Dimension row format

```
- [ ] <id> · <area> · <the specific question this dimension answers> · deps: <ids|none>
```
Status: `- [ ]` not analyzed · `- [~]` analyzed, claims unverified · `- [x]` verified · `- [!] blocked: <reason>`.

## Dimension catalog (pick what the question needs)

- **architecture** — components, boundaries, layering, data/control flow.
- **agent-loop model** — agent loop? planner/executor? tool-calling? memory? multi-agent / a
  manager/control-plane? (central for "is it an agent manager?")
- **capabilities** — what it actually does (features/commands/tools/integrations), each traced to code.
- **extension model** — plugins, hooks, MCP, config — extensibility without forking.
- **data model / persistence** — what it stores and how.
- **external interfaces** — HTTP/CLI/MCP/events surface.
- **comparison-to-<X>** — concept map vs a reference system (has / partial / lacks), for "is it an X?".

## Claim format (analyst → `findings/<dimension>.md`)

```
- CLAIM: <falsifiable statement> | evidence: <path:line / symbol / call-path / test> | confidence: high|medium|low
```

## Verdict format (verifier → `findings/verdicts.md`)

```
- <claim-ref> -> CONFIRMED | REFUTED (<counter-evidence>) | QUALIFIED (<condition>) | INCONCLUSIVE (<why>)
```
Only `CONFIRMED`/`QUALIFIED` reach the report. Notable `REFUTED` overclaims are reported as findings.

## Discipline
- **Completeness sweep before DONE** — cartographer re-checks the map: any major module/interface/
  dimension unexamined blocks DONE. No silent caps; deferred areas are explicit `- [ ]` rows.
- **No unverified facts** — a claim is a report fact only after surviving adversarial verification.
- **Cite everything** — every claim and verdict points at real code, so any line is checkable.
