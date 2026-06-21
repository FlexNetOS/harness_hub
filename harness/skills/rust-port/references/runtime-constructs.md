# Runtime & orchestration constructs — port-and-map decision discipline

Reference for `rust-port-architect` (and the porter/verifier who consume the decision). Some source
subsystems are not leaf logic to transliterate — they are **runtime/orchestration constructs** (a DAG
executor, a run-loop, a provider abstraction over external agent CLIs, a worktree-isolation manager, a
run-ledger, an event bus). For these, FlexNetOS already ships Rust **substrates** (`hf`, `weave`,
`grit`, `icm`, provider CLIs). The architect's job is the **port-and-map** decision — the
`rust-port` -> `rust-port-merge` arc of ADR-0001: port the construct's *behavior*, but MAP it onto a
substrate instead of reimplementing, **without losing a single behavior**.

> Scope note: the substrate column below is the **FlexNetOS default** (it targets ADR-0001 /
> `harness-agent-rs`). For a non-Archon port with different runtime idioms, treat the substrate column
> as a default to confirm, not a universal law — the REIMPLEMENT/DELEGATE rows and the cardinal
> no-drop rule remain general.

## The cardinal rule (no-downgrade, restated for mapping)

Mapping onto a substrate is only legal if the substrate preserves **every** behavior in the
construct's parity-ledger contract (state transitions, ordering, concurrency, cancellation,
durability, event semantics). If the substrate **cannot express a behavior**, that is a `- [!]`
blocked row or a `- [≠]` owner-decision — **never a silent drop**. "It mostly maps" is a downgrade.
A mapped unit is still differentially parity-verified against the source (the verifier doesn't care
whether the impl is hand-rolled or substrate-backed — only that behavior matches).

**`- [≠]` here means genuinely-inexpressible, not "the destination won't use it."** A MAP-ONTO/REIMPLEMENT
decision may `- [≠]` a source behavior ONLY when the substrate *truly cannot represent it* (inexpressible),
the behavior is *non-contractual/unobservable*, or the dest is a *strict superset* (see `parity-ledger.md`
§"The `[≠]` bar"). It is **never** legal to `- [≠]` a portable behavior — one that produces a distinct
observable output (a serialization/export shape, a file sink, a CLI flag, a recorded activity) — by
rationalizing "the native engine's design won't use it" or "the dest consumes the value directly." That is a
disguised feature-skip, and the no-downgrade rule is **when in doubt, port/map it** (preserve capability),
not skip it. A `- [≠]` "Substrate gaps" line must name a *real* inability of the substrate, not a design
preference of the destination.

## Decision table — reimplement vs map-onto (source subsystem -> substrate)

| Source subsystem (Archon idiom) | Default decision | Substrate | What MUST be preserved (verify, don't assume) |
|---------------------------------|------------------|-----------|-----------------------------------------------|
| Durable run-ledger / run state / pause-resume | **MAP-ONTO** | `hf` (witnessed continuity ledger) | parallel-node status, paused/approval-gate state, resume-after-restart, event ordering. **Open per ADR-0001:** confirm `hf` can express parallel-node + paused-gate semantics; if not → `- [!]` (second store is an owner-decision). |
| Agent-to-agent messaging / real-time event push | **MAP-ONTO** | `weave` (messaging) | event types, delivery ordering, fan-out, streaming/push timing, backpressure. Archon has **no A2A bus** (ADR-0001) — this is a *capability add*, but the mapped behavior must still match Archon's event-push contract for the surfaces it has. |
| Parallel-write / worktree symbol locks / run isolation | **MAP-ONTO** | `grit` (symbol locks, finer than Archon's path lock) + per-run worktree | mutual-exclusion guarantees, isolation boundary, no two runs corrupting shared state. `grit` is *finer* than Archon's coarse path lock — finer is allowed (stricter), coarser is a downgrade. |
| Memory / knowledge / RAG | **MAP-ONTO** | `icm` | recall/store semantics. Archon has **no RAG/memory in-tree** (ADR-0001) — capability add; don't invent a parity row the source lacks. |
| Agent LLM run-loop (the actual model turn) | **DELEGATE** | provider CLIs (`claude`/`codex`/…) | Archon's own model — delegate to subprocess; preserve auth env, binary resolution, streaming stdout, turn/loop-until-signal semantics. |
| DAG-executor state machine itself (topological layers, loop-until, gates, fresh/shared ctx) | **REIMPLEMENT** (Rust) | — (it IS the runtime core being built) | port fully per the idiom map (see `rust-port-translate` §Agent-runtime); this is the part FlexNetOS lacks. |
| Provider abstraction (`IAgentProvider`/`ProviderCapabilities`) | **REIMPLEMENT** (Rust trait + enum dispatch) | — | every capability flag, every provider variant, subprocess mgmt (stdin/stdout/streaming, binary resolution, auth). Dropping a provider variant or a capability flag is a downgrade. |
| Intrinsically-**dynamic** construct: a template/expression engine (jinja2-style), runtime-defined tool/plugin dispatch, a config/user-supplied rules DSL, hot-reloadable behavior | **EMBED-LUA** (mlua) — *only when Rust-native is genuinely awkward/lossy* | embedded sandboxed Lua | the full dynamic contract (every template directive, every runtime-dispatched branch, every rule). A Lua-backed path is **still differentially parity-verified** and is never a stub. See §EMBED-LUA below. |

## EMBED-LUA — embedded scripting for genuinely-dynamic constructs (an upgrade, not a crutch)

A fourth decision verb, alongside REIMPLEMENT / MAP-ONTO / DELEGATE: **EMBED-LUA** maps a source
construct onto an embedded, sandboxed **Lua** interpreter (`mlua`). It exists because some source
constructs are *intrinsically dynamic* — a template/expression engine, runtime-defined tool/plugin
dispatch, a small rules-DSL evaluated at runtime, hot-reloadable behavior — and forcing them into
static Rust (a hand-rolled mini-interpreter, or a sprawling `match` over runtime-shaped data) is
*more* lossy and *less* maintainable than preserving the dynamism in a scripting layer. There Lua is a
genuine **upgrade**: it re-expresses the dynamic behavior faithfully and idiomatically.

**Use EMBED-LUA only when ALL hold** (else it is a downgrade — Rust is the default):
- the source construct is **runtime-evaluated / dynamic** in a way static Rust expresses awkwardly or
  lossily (template/expression eval, runtime dispatch table, plugin/rules DSL, hot reload); **and**
- embedding it as Lua preserves that behavior **more** faithfully + maintainably than the Rust
  alternative; **and**
- the architect records the dependency (`mlua`) in the dependency-equivalent table (feature-gate it if
  the source construct is itself optional).

**Do NOT use EMBED-LUA when:**
- the logic is leaf/static and perfectly expressible in Rust (a parser, a data transform) — Rust there
  is safer/faster/clearer; Lua would be a downgrade (lost type-safety, perf, single-language clarity);
- it would be a way to *avoid* a hard Rust port ("too hard, just script it") — that is a stub-by-Lua,
  and the no-stub rule forbids it as much as `todo!()`;
- the source had **no** dynamic/scripting semantics — adding a Lua VM invents complexity the source
  never had (itself a kind of divergence).

**No-downgrade constraints on every Lua-backed path (upgrades only):**
- **Still differentially parity-verified.** The `rust-port-parity-verifier` treats EMBED-LUA exactly
  like REIMPLEMENT — same inputs → same outputs, side-effects, and error behavior over the unit's whole
  contract. Lua is never "simplified for now" and never drops a branch.
- **Sandboxed + deterministic.** No `os`/`io`/`package`/network access unless the *source path had
  exactly that capability*; no wall-clock/RNG unless the source used it (then seed it). The sandbox is
  the default `mlua` std-lib subset minus ambient authority.
- **First-class artifact.** The Lua source is committed, reviewed, and lives in the repo — never a
  fetched or `loadstring`'d blob from outside the build.
- **Errors map to the Rust error enum.** A Lua runtime error becomes a typed `Result::Err`, never a
  panic, never a silent empty — same error contract the source exposes.
- A behavior the Lua path **cannot** fully express is a `- [!]`/`- [≠]` owner-decision (same as any
  other mapping), never a silent partial.

## How the architect records it (in `target-architecture.md`)

For every runtime/orchestration unit, add a **Port-and-map decision** block, so the porter and verifier
inherit it (decide once, apply everywhere):

```
### <unit id> — <source subsystem>
- Decision: MAP-ONTO <substrate> | REIMPLEMENT | DELEGATE | EMBED-LUA
- Behaviors preserved: <list the contract behaviors the substrate/impl covers>
- Substrate gaps: <none | behavior X not expressible -> ledger - [!]/- [≠] <ref>>
- Parity note: differential test still runs source-vs-Rust over <streaming/concurrency/cancel/...>
```

A MAP-ONTO with a non-empty "Substrate gaps" line **must** carry a matching `- [!]`/`- [≠]` ledger row
(owner-decision) — the gap cannot live only in prose.

## Current-architecture-only (Archon, per ADR-0001)

Archon's tree carries three uncleaned legacy versions. The architect scopes the runtime mapping to the
**v0.4.x DAG-workflow-manager** only; legacy runtime variants are **out of scope**, recorded as an
explicit cartographer coverage note (not a silent omission). The port is also a consolidation.

## Collaboration

- Consumes the **cartographer**'s runtime/concurrency inventory rows (concurrency, cancellation,
  ordering, backpressure, run-isolation, signals — see that agent's inventory dimension).
- Hands the per-unit MAP-ONTO/REIMPLEMENT/DELEGATE decision to the **porter** (who applies the
  `rust-port-translate` §Agent-runtime idiom rows) and the **parity-verifier** (who runs the
  streaming/concurrency/cancellation differential — a mapped unit is verified, not trusted).
