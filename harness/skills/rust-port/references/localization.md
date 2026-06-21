# Localization parity — translate user-facing text without downgrading behavior

A faithful port preserves the source's strings. But when the source's **user-facing** text is written
in a natural language the destination product does not ship in (e.g. MiroFish's Chinese error/UI
strings ported into an English-shipping Rust app), byte-identical preservation *ships the foreign text
into the product* — a real product gap. The owner's directive "ensure Chinese→English proper
translations" asks to close that gap. This reference is how to do it as a **no-downgrade upgrade**:
translate the human-readable **text** while preserving the message's **contract** (its trigger
condition, its interpolation slots, its control-flow role), and verify the translation at **semantic**
grain — not byte grain.

> **Activation (opt-in, recorded).** Localization runs only when the run's directive sets a target —
> record `localize: <src-lang>-><dst-lang>` in `loop_state.md` (e.g. `localize: zh->en`); default
> `localize: none`. With `localize: none` the default stays **byte-identical preservation** (pure
> parity) and this reference is dormant. Translating without a directive would itself be an
> unrequested behavior change — so it is gated on the directive, never automatic.

## The cardinal rule (localization is an upgrade ONLY if it loses no behavior)

Translating a string is legal **only** when every one of these holds; otherwise the string is
**preserved byte-identical** (translating it would be a *downgrade*, exactly the thing this harness
forbids):

1. **Same trigger condition.** The translated string fires under *exactly* the same predicate/branch
   as the source string. Translation never moves, adds, or drops a control-flow edge.
2. **Same interpolation.** Same number, order, and type of interpolated values (`{agent_id}`, counts,
   IDs) and the same surrounding format. A translation that reorders or drops a slot is a defect.
3. **Semantic equivalence.** The English conveys the same meaning a competent bilingual reader would
   agree on — same severity, same actionable content. "Close enough but vaguer" is a downgrade.
4. **Source recorded.** The original source string is kept as the contract reference — in a
   doc-comment next to the English literal, or as the value/comment in an i18n table — so parity is
   auditable and reversible.
5. **Not a contract string.** The string is confirmed to be in the TRANSLATE class below, i.e. **no
   consumer parses it.** If any code (the source's or a downstream consumer's) does an equality /
   `contains` / regex / hash / DB-key match on the string, it is **contract**, not prose → PRESERVE.

## String-class taxonomy (decides translate vs preserve)

### PRESERVE byte-identical — these are CONTRACT; translating them BREAKS behavior
- Protocol / wire strings, JSON keys, `serde` tags, enum discriminants, API field names.
- Log **event-type / stage keys** and metric names that tooling parses (vs the human message *value*).
- Any string compared by an equality / `contains` / regex / `match` predicate (a control-flow token),
  a DB column/key, a cache key, a hash input.
- File paths, env-var names, CLI flag names and flag *values*, error **codes** (vs error *messages*).
- A string the differential gate compares for byte-identity because a consumer round-trips it.

> Litmus: *if a machine reads it, preserve it; if only a human reads it, it may be translated.* When a
> single string serves both (a human-readable message that is **also** matched by a consumer), it is
> contract — PRESERVE, and surface a proposal to split the machine token from the human text upstream.

### TRANSLATE to English — user-facing human-readable text; preserving it foreign is the gap
- Error / status **messages** shown to an end user, UI labels, human-readable descriptions.
- Comments and docs (the Rust port writes these in English regardless).

### TRANSLATE-WITH-BEHAVIORAL-REVERIFY — LLM prompt text (special, highest-risk)
A prompt string sent to a model is **semantically load-bearing**: changing its language can change the
model's output, which is a behavioral change, not a cosmetic one. So a prompt is translated **only**
with a downstream re-verification that the *output contract still holds* (the parity gate's existing
differential test, re-run after translation, must still PASS — same structured output, same tool-call
shape, same parse success). If the output contract can't be re-proven, **preserve the prompt
byte-identical** and record it as a `localize: deferred` row (an honest gap, not a silent skip). Never
translate a prompt and assume the model behaves the same.

## Verifier mode — localization parity (semantic, not byte)

For a string the architect classified TRANSLATE, the `rust-port-parity-verifier` flips its symbol
`- [x]` on **localization parity**: checks (1)–(5) above hold — same trigger, same interpolation,
semantic equivalence, source recorded, not-a-contract-string — and records the `source ↔ English`
mapping in `findings/parity.md`. This is a *different* PASS criterion than byte-identity, and it is
**not weaker**: it adds checks (trigger + interpolation + not-contract) on top of meaning-equivalence,
so a translation that shifts behavior FAILs exactly as a narrowing would. A TRANSLATE string whose
consumer turns out to parse it → FAIL (reclassify PRESERVE). A prompt translated without the output
re-verification → FAIL.

PRESERVE-class strings keep the ordinary **byte-identity** parity check unchanged.

## i18n architecture (the maintainable landing — architect decides per project)

Prefer centralizing translated user-facing strings in one **i18n table/module** (key → English, with
the source-language original recorded alongside) rather than scattering literals. Benefits: the
`source ↔ English` map lives in one auditable place, future locales are additive, and the verifier
checks the table once. Where the destination already has an i18n layer (e.g. teri's report i18n
fallback), land translations there. For a one-off string with no table, an English literal + a
`// src: "<original>"` doc-comment satisfies check (4). The architect records the choice in
`target-architecture.md`.

## Retroactive sweep (when `localize` is added mid-port)

Foreign strings already marked `- [x]` under a prior `localize: none` directive were **correct** then
(byte-identity parity). Adding a `localize: zh->en` directive does **not** retro-invalidate them as
defects — it opens a **localization backlog**: each *user-facing* foreign string is re-adjudicated
(translate per (1)–(5), or confirm PRESERVE) as its own tracked sub-row, and the symbol flips from
"byte-parity `- [x]`" to "localization-parity `- [x]`" once translated+verified. This is an **additive
pass** (a new gate condition), never a regression of the existing parity marks. The cartographer adds
the backlog rows; DONE (under a non-`none` localize directive) requires every TRANSLATE-class
user-facing string to be localization-verified or an explicit `localize: deferred` row with reason.

## How the architect records it (in `target-architecture.md`)

```
### Localization — <unit/string-id>
- Class: PRESERVE | TRANSLATE | TRANSLATE-WITH-BEHAVIORAL-REVERIFY
- Source string: "<original>"  (e.g. "环境即将关闭")
- English: "<translation>"     (e.g. "Environment is closing")  | n/a for PRESERVE
- Why this class: <consumer-parses-it=PRESERVE | user-facing=TRANSLATE | prompt=reverify>
- Interpolation slots: <none | {agent_id}, {count} — same order as source>
- Parity note: verifier checks semantic-equivalence + same-trigger + same-slots (TRANSLATE) /
  byte-identity (PRESERVE) / output-contract re-PASS (prompt)
```
