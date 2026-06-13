---
name: code-research-map
description: >-
  How to map an unfamiliar codebase for deep analysis and decompose a research question into
  dimensions. ALWAYS use at the start of code research, on "map this codebase", "what are the entry
  points", "what does this depend on", "decompose the question", or the pre-DONE completeness sweep.
  Uses code intelligence (AST/call-graph), not just grep. Behavior + structure over file lists.
---

# Code-Research Map

Orient before you analyze. A good map makes the deep dive fast and the completeness sweep honest.
Used by `code-research-cartographer`.

## Method

1. **Use code intelligence first.** Prefer `git-kb code` / `git kb` AST tools over grep:
   `symbols` (what's defined), `callers`/`callees` (real usage), `impact` (blast radius),
   `query hotspots` (central code), `dead` (unwired code). Grep is for strings/config/docs only.
   If the index is empty, run `git kb index <dir>` first.
2. **Find the seams that define the system:**
   - **Entry points** — mains, servers, CLIs, MCP servers, exported library APIs, workers.
   - **Dependency graph** — internal module deps + the handful of external libs that shape the design
     (web framework, ORM, agent/LLM SDK, runtime).
   - **External interface surface** — HTTP routes, CLI commands, MCP tools, events/queues, file/DB I/O.
   - **Build/run surface** — how it builds, how it starts, config + env (read `.env.example`, manifests).
3. **Read the project's own story, skeptically** — README/ARCHITECTURE/AGENTS/CHANGELOG state intent;
   capture as *claims to verify*, never facts.
4. **Decompose the question into dimensions** (catalog in `code-research/references/research-ledger.md`)
   — translate "is it an X?" into specific, answerable areas; seed one ledger row each.

## Discipline
- **No silent caps** — areas not yet mapped are explicit `- [ ]` rows; the completeness sweep diffs
  the real tree against the ledger and blocks DONE on anything unexamined.
- **Ground every entry in a path/symbol** so analysts cite real code.
- **Map behavior, not just names** — note what each subsystem does and how it connects.
