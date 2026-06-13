---
name: code-research-analyze
description: >-
  How to analyze one dimension of a codebase deeply and produce cited, falsifiable claims —
  architecture, capabilities, agent/loop model, extension model, data model, or comparison-to-X.
  ALWAYS use when investigating a code dimension, answering "how does X work / what can it do / is it
  an X", or producing findings for verification. Evidence per claim (file:line / call-path / test) —
  reasoning from source, never vibes.
---

# Code-Research Analyze

Answer one dimension in **claims backed by code**. The verifier will try to refute each one, so only
make claims you can defend by pointing at the source. Used by `code-research-analyst`.

## How to analyze a dimension

1. **Locate the relevant code** via the codemap + `git-kb code` (symbols/callers/callees). Read the
   actual implementation, follow the call paths — don't infer from names or docs.
2. **State falsifiable claims with evidence.** Each material statement →
   `CLAIM | evidence: path:line / symbol / call-path / test | confidence`. (Schema in
   `code-research/references/research-ledger.md`.)
3. **Separate is / says / could-be** — what the code *does now* vs what docs claim vs what the
   architecture *allows*. Flag doc-vs-code mismatches; they're high-value findings.
4. **For "is it an X?" dimensions**, build the concept map: for each capability X has, mark the target
   *has / partially has / lacks* it — with evidence (or evidence of absence: "no code wires this up").

## Dimension hints
- **agent-loop model:** find the loop, the planner/executor split, tool-calling, memory, multi-agent
  coordination, any manager/control-plane. Name exact types/functions — or their absence.
- **capabilities:** enumerate from entry points/routes/CLI/tools; trace each to working code (not a stub).
- **extension model:** plugins/hooks/MCP/config — how it's extended without forking.

## Discipline
- **Evidence or it's not a claim** — uncited statements are guesses the verifier will drop.
- **Surface the surprising** — hidden couplings, implied-but-missing capabilities, unwired abstractions.
- **Mark low confidence honestly** and hand the verifier a concrete thing to run to settle it.
