# ADR-0001 — `harness-agent-rs`: a Rust harness/agent-manager runtime, ported from Archon's design

- **Status:** Accepted (2026-06-13)
- **Deciders:** owner (FlexNetOS) + code-research harness
- **Supersedes / relates to:** the packaged-harness library (`harness_hub/harness`), the rust-port
  harness (`/harness:rust-port`), and the Rust substrates `hf` (handoff), `weave`, `grit`, `icm`.

## Context

The FlexNetOS harness layer today is **markdown skills + bash glue, interpreted by Claude** — a
*specification* of orchestration, not a *program* that orchestrates. Everything load-bearing
underneath is already Rust (`hf` continuity, `weave` messaging, `grit` symbol-locks, `icm` memory,
`meta_cli`). The missing piece is a **compiled runtime that executes harnesses** — owns the loop,
spawns/coordinates agent runs, enforces gates, isolates runs — instead of re-deriving all of it from
markdown each session. Working name: **`harness-agent-rs`**.

The open question was whether `meta/Archon` is the right base. We answered it with evidence rather
than assumption by running the `/harness:code-research` harness against Archon (4 parallel analysts +
1 adversarial verifier; all six load-bearing claims confirmed against source). See
**Research & cross-references** below.

**Finding (verdict, high confidence):** Archon **is** a harness/agent manager — specifically a **DAG
workflow-run orchestrator over *external* coding-agent SDKs**. It *manages agent runs* (DAG state
machine with loop-until / human-gate / parallel layers; per-run git-worktree isolation; provider
sessions behind a uniform `IAgentProvider`; a multi-surface control plane) but **delegates every LLM
run-loop to vendor SDK subprocesses** (`grep messages.create|chat.completions` = 0). It has **no A2A
bus** (only coarse path-exclusive run locks) and **no RAG/memory** in-tree.

**Owner note (key constraint):** Archon's tree still carries **three old, uncleaned-up versions**;
agents struggle to work through the mess, and the README's "archived v1" framing is not reflected as
a clean separation in-repo (consistent with the verifier's INCONCLUSIVE on "v1 archived"). The port
must therefore target the **current intended architecture (the v0.4.x DAG-workflow-manager)** and
**not** carry the legacy cruft.

## Decision

1. **Build `harness-agent-rs` as a new repo** (`FlexNetOS/harness-agent-rs`) — the compiled Rust
   runtime that *executes* harnesses. It is named for the goal, not the source: it ports Archon's
   runtime **design** *and* maps Archon's overlapping subsystems onto the existing Rust substrates.
2. **Port (rust-port) from Archon's design — the parts FlexNetOS lacks:**
   - the **workflow/DAG schema** (`packages/workflows/src/schemas/workflow.ts`),
   - the **DAG-executor state machine** (`packages/workflows/src/dag-executor.ts`: topological
     parallel layers, `loop`-until-signal, human-approval gates, fresh/shared context),
   - the **`IAgentProvider` + `ProviderCapabilities`** abstraction (`packages/providers/src/types.ts:349-440`),
   - **per-run git-worktree isolation** (`packages/isolation/`),
   - the **multi-surface control plane** (server + Web + Slack/Telegram/GitHub adapters + real-time push).
3. **Map onto existing substrates — do NOT reimplement:** run-ledger/durable state → **`hf`**;
   multi-agent coordination → **`weave`** (messaging, which Archon lacks) + **`grit`** (symbol locks,
   finer than Archon's path lock); memory/knowledge → **`icm`**.
4. **Delegate the agent loop to provider CLIs** (`claude`/`codex`/…) — Archon's own model; the one
   capability missing everywhere, and not worth reinventing.
5. **Keep the markdown harness builder (`harness_hub/harness`) as-is** — it is the *authoring* layer;
   `harness-agent-rs` is the *execution* layer. They compose: the builder writes harnesses (and the
   evolution-steward keeps editing them as text), the runtime executes them. This preserves
   self-evolution (the runtime loads declarative harness defs; behavior is not compiled in).
6. **Port the current architecture only.** The rust-port harness's `cartographer` must first
   **disambiguate current-vs-legacy** in Archon and scope the parity ledger to the v0.4.x runtime —
   the three old versions are explicitly out of scope (the port is also a consolidation).

This is the **`rust-port` → `rust-port-merge`** arc: rust-port Archon's runtime core into
`harness-agent-rs`; the architect maps its overlapping subsystems onto the substrates (the "merge").

## Consequences

**Positive**
- A deterministic, reproducible, Rust-native runtime for harnesses — fail-closed, fast, native to
  `hf`/`weave`/`grit`/`icm`.
- Self-evolution preserved (declarative harness defs + the evolution-steward), per the runtime-not-
  rewrite fork — now evidence-backed by how Archon itself works.
- The port doubles as a cleanup: the legacy 3-version mess is left behind by construction.

**Negative / risks**
- Large, multi-session effort; the agent-loop delegation inherits Archon's auth/binary-resolution
  complexity (`claude`/`codex` subprocesses).
- **Open fork:** `oh-my-pi` (a Rust/Bun coding-agent runtime already cataloged) may already supply the
  agent-loop/IDE piece Archon delegates — *not yet analyzed*. Resolve via a `/harness:code-research`
  run on oh-my-pi before locking the loop strategy.
- **Unverified:** whether `hf`'s witnessed ledger can express Archon's run-event semantics
  (parallel-node status, paused gates) or whether a second store is forced.
- Porting from a 3-versions-deep messy source raises the cartographer's disambiguation cost.

## Research & cross-references

- **Method:** `/harness:code-research` (this hub's deep-code-research harness) against
  `/home/drdave/Desktop/meta/Archon` — MAP → 4 parallel analysts (architecture, agent/manager model,
  capabilities, harness-agent-rs fit) → adversarial verifier (all 6 load-bearing claims CONFIRMED) →
  synthesis. Read-only.
- **Key evidence:** `packages/workflows/src/dag-executor.ts` (~3,700 lines, Kahn topological layers);
  `packages/providers/src/types.ts:349-440` (`IAgentProvider`/`ProviderCapabilities`, 5 SDKs);
  `packages/providers/src/claude/provider.ts:947` (`query()` delegation); `packages/isolation/src/factory.ts`
  (worktree-only); `packages/workflows/src/schemas/loop.ts` (bounded re-prompt loop); A2A/RAG greps = 0.
- **ICM:** `decisions-harness_hub` — Archon verdict (`01KV0Z9P…`) + this ADR.
- **Catalog:** [`entries/rust-port.md`](../../entries/rust-port.md), [`entries/code-research.md`](../../entries/code-research.md),
  [`entries/handoff.md`](../../entries/handoff.md), [`entries/weave.md`](../../entries/weave.md).
- **Next:** scaffold `FlexNetOS/harness-agent-rs`, eject `/harness:rust-port`, seed the port kickoff
  (current-architecture-only directive), then DISCOVER. Open the oh-my-pi code-research before locking
  the loop strategy.
