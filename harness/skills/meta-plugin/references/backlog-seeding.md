# Backlog seeding — turning audit findings into an ordered backlog

How the orchestrator's fan-in step converts the three findings files into one
dependency-correct `.handoff/loop/backlog.md`. Read this during DISCOVER (Phase 1, step 4).

## Inputs

- `.handoff/loop/findings/health.md` — per-repo build/test/lint/validate matrix (from build-health-auditor).
- `.handoff/loop/findings/registry.md` + `.handoff/loop/reports/inventory.md` — catalog gaps + repo classification (from meta-plugin-registry-curator).
- `.handoff/loop/findings/drift.md` — protocol↔consumer contract findings, classified safe/breaking/risky (from meta-plugin-protocol-drift-analyst).

## Backlog item format

```
- [ ] <area>: <imperative, single-cycle action> (owner: <agent>; deps: <item refs or none>)
```

Legend: `- [ ]` todo · `- [x]` done+verified · `- [!] blocked: <reason>`. One item = one cycle =
one commit. If an item can't be done and verified in a single cycle, split it.

## Dependency ordering rules (top = do first)

1. **Green baseline before everything.** Any repo that is RED in the health matrix and blocks
   other work gets a fix item first. A catalog item that *asserts* build state must depend on its
   repo being green.
2. **Contract before consumers.** A breaking drift finding becomes: the protocol/api fix item
   first, then one consumer-update item per affected repo (each `deps:` the contract item), then a
   final "build-health-auditor confirms all affected repos green" item.
3. **Source before rendering.** A registry.json correction precedes the README/entries items that
   render it.
4. **Safe drift = no item.** Findings classified `safe` (new optional fields) are recorded in the
   report but do not seed work. Only `breaking`/`risky` seed items.
5. **Out-of-scope routing is a report, not a work item** unless the user asked to act on it.
   "Repo X belongs in plugin_hub" is recorded in `reports/inventory.md`; only create a backlog
   item if the scope includes moving it.

## Routing table (finding → owner)

| Finding kind | Owner agent | Skill |
|--------------|-------------|-------|
| registry.json ↔ README ↔ entries mismatch; undocumented harness; orphan entry | meta-plugin-registry-curator | hub-registry-sync |
| repo RED (build/test/clippy/validate) | build-health-auditor (or the owner of the root cause) | cross-repo-health |
| breaking/risky protocol or api contract change | meta-plugin-protocol-drift-analyst | protocol-drift-scan |
| any landed change | integration-qa verifies (not an owner) | — |

## Discipline

- **No silent caps.** If discovery only swept a subset of repos (time/scope), record which repos
  were deferred as an explicit `- [ ]` "sweep remaining repos" item — never let partial coverage
  read as complete.
- **Attribute conflicts.** If two agents disagree (e.g. curator says an entry is fine, QA says the
  doc is missing), seed a single adjudication item and keep both sources cited.
