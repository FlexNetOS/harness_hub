# Parity ledger — the no-feature-left-behind contract

`.handoff/loop/parity-ledger.md` is the single source of truth for the port. The port is DONE only
when this ledger is 100% — that is the structural guarantee behind "no downgrades, no feature logic
left behind." Owned by `rust-port-cartographer`; status transitions gated by `rust-port-parity-verifier`.

## Row format

```
- [ ] <id> · <source-path>:<symbol> · <contract> · -> <rust-target> · deps: <ids|none>
```

- `<contract>` = the observable behavior: inputs, outputs, side effects, **error paths**, edge cases.
  A row whose contract is just a name is incomplete — name what it *does*, so a stub can't satisfy it.
- `<rust-target>` = the crate::module::item the porter will produce.

## Per-symbol granularity (the symbol map sits under each unit)

A unit row is **not** the finest grain. Each unit decomposes into a set of source symbols
(exported/public fn, type, method, field, const, enum variant, trait, CLI flag, HTTP route) tracked
one-row-each in `.handoff/loop/symbol-map.md` (schema + deterministic harvest: `references/symbol-map.md`).
This closes the hole where a dropped method/field/variant/route *inside* a ported unit hides behind a
unit-level `- [x]`.

**Rollup rule (load-bearing):** a unit may be marked `- [x]` **only when every one of its symbols is
`- [x]` or `- [≠]`** in the symbol map. A unit with any `- [ ]`/`- [~]`/`- [!]` symbol stays `- [~]`.
"Unit verified" therefore means "every symbol of the unit verified" — not "the module compiles."

## Status legend

| Mark | Meaning | Who sets it |
|------|---------|-------------|
| `- [ ]` | not ported | cartographer (seed) |
| `- [~]` | ported, parity **unproven** (or partially) | porter |
| `- [x]` | ported **and** differentially parity-verified | orchestrator, only on verifier PASS |
| `- [!] blocked: <reason>` | can't proceed (missing dep equivalent, unparseable source, env wall) | any |
| `- [≠] intentional-divergence: <reason+approval>` | deliberate behavior change | only with owner approval |

**Only `- [x]` and `- [≠]` count toward DONE.** A `- [~]` is an unproven claim and never closes a unit.

### The `[≠]` bar — when intentional-divergence is legal (and when it is a disguised skip)

`- [≠]` is **not** a convenience escape for "porting this is extra work" — it is a deliberate,
owner-visible *capability* decision, and the no-downgrade contract treats a wrongly-`[≠]`'d portable
feature as a **defect**, not a row. `[≠]` is permitted **ONLY** when the source behavior is:

- **(a) genuinely INEXPRESSIBLE in the destination** — a substrate truly cannot represent it (this is
  really a `- [!]` owner-decision: a Zep-SaaS call with no in-process equivalent, an OASIS subprocess
  primitive the native engine has no analogue for); **or**
- **(b) NON-CONTRACTUAL / unobservable** — it perturbs nothing a consumer, a test, a log/episode/wire
  shape, or a downstream unit can observe (retry *jitter* = stochastic sleep latency; a Python-GIL /
  Windows-console artifact with no behavioral contract; a source action that is filtered out before it
  is ever recorded — e.g. an op in `FILTERED_ACTIONS` that never becomes an activity); **or**
- **(c) a strict SUPERSET** — the destination already does this and MORE, losing nothing (the dest's
  accepted-format set is a superset of the source's; the dest's type carries every source field plus
  extras).

`[≠]` is **NEVER** legal as: "the destination's architecture won't use it", "probably unused", "not
needed for <dest>'s design", "consumes the value directly so the export isn't needed", or
"`serde::Serialize` covers it" — **for a feature that produces a distinct observable output**: a
serialization SHAPE (a `to_reddit_format`/`to_dict` producing specific keys), an export format, a file
sink (rotating-file logging), a CLI flag, a distinct render path. Those are **portable features**, and
the rule is **a portable feature is ported, not `[≠]`-skipped**. A near-fit `[≠]` that erases an
observable output is the same class as a *narrowing* — a downgrade a later unit may depend on.

**When in doubt, PORT IT (preserve capability)** — the cost of porting a cheap serializer or an opt-in
sink is far less than the silent capability loss of skipping it. (Evidence: MiroFish→teri ITERATE
cycles 8–9 — U-018's `to_reddit_format`/`to_twitter_format`/`to_dict` were `[≠]`'d as "teri consumes
`SocialProfile` directly, OASIS export not needed" and U-004's rotating-file logging as
"console-by-design"; both were portable features producing real observable output, both were corrected
to PORTED, and the U-018 skip had *also* hidden a second downgrade — bio+persona collapsed into one
field — that the serializers exposed.)

## Dependency ordering (top = port first)

1. **Leaf units first** — pure functions, value types, utilities with no project-internal deps.
2. **Then their consumers** — each unit's `deps:` must be `- [x]` before it's picked.
3. **Entrypoints/wiring last** — CLI, HTTP routers, main — they compose verified pieces.
4. **Cross-cutting first-class** — the error model, config loader, and async runtime are units too,
   ported early (the architect designs them in `target-architecture.md`); everything depends on them.

## Completeness discipline (the anti-"left behind" rules)

- **No silent caps.** If inventory deferred part of the source, that's an explicit `- [ ]` sweep row,
  never an omission. Partial coverage must never read as complete.
- **Edge cases are rows.** Each error branch, empty/null case, ordering/concurrency guarantee,
  cancellation/timeout point, backpressure bound, run-isolation boundary, pause/approval-gate state,
  and platform quirk is its own line — these are what naive ports drop. For runtime/orchestration
  units, the concurrency/cancellation/streaming contract is part of the row, not optional metadata.
- **Pre-DONE sweep is mandatory, at two grains.** The cartographer re-scans the source and diffs
  against the ledger; any source *unit* not represented blocks DONE. It then re-harvests the full
  source *symbol* set and diffs against `symbol-map.md`; any *symbol* not represented (or any
  `- [ ]`/`- [~]`/`- [!]` symbol, or any `- [x]` unit whose symbols aren't all `- [x]`/`- [≠]`) also
  blocks DONE. Assume something was missed — at both grains — and prove it wasn't.
- **Downgrades are visible or forbidden.** A capability cut is only legal as a `- [≠]` row with
  recorded owner approval. Anything else (stub, dropped branch, "simpler version") is a defect, not a row.
