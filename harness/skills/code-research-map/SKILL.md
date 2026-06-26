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

0. **Build + verify the code index FIRST (step 0, not an afterthought).** Before relying on any
   AST/call-graph tool, build and *confirm* the index — `git kb code index <root>`, then prove it is
   populated (e.g. `git kb code symbols <a-known-file>` returns rows, and record the symbol/callsite
   counts in the codemap). A code index is a derived artifact: do **not** assume it exists. An empty
   index makes `callers`/`callees` silently return nothing — which reads like "no usage" and corrupts
   the whole map. Only after the index is verified non-empty do steps 1–4 apply.
1. **Use code intelligence first.** Prefer `git-kb code` / `git kb` AST tools over grep:
   `symbols` (what's defined), `callers`/`callees` (real usage), `impact` (blast radius),
   `query hotspots` (central code), `dead` (unwired code). Grep is for strings/config/docs only.
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
- **Call-graph EDGES are claims-to-verify, not facts.** The index resolves call sites by name and can
  mis-bind a caller→callee edge — most often when two distinct symbols share a name (a trait method vs
  an inherent method, an overload, two functions named `search`/`get`). Treat every `callers`/`callees`
  edge the map emits as a claim the analyst/verifier must confirm by reading the actual call site
  (which symbol is really invoked there), exactly like a README claim. Never promote a raw edge to a
  report fact. (Run evidence: git-kb reported `search@hub.rs:1117 called@995`, but the call site
  actually invokes `self.search_engine.search` — a different `search` symbol; the edge was a
  symbol-resolution artifact the verify gate had to refute.)
