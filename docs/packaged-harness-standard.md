# Packaged-Harness Standard

How every harness in this hub is organized, named, and shipped. This is the convention the
`/harness:harness` factory mints into and the rule the loop enforces. A "packaged harness" is a
ready-made, **runnable + ejectable** harness exposed as a `/harness:<name>` command.

## The three layers (don't conflate them)

| Layer | What it is | Where |
|-------|-----------|-------|
| **Factory** | `/harness:harness` — the meta-skill that *builds* harnesses | `harness/skills/harness/` |
| **Packaged harnesses** | ready-made harnesses, one per use case, `/harness:<name>` | `harness/skills/<name>/` + `harness/agents/` |
| **Catalog** | the human-facing index (one row per harness) | `registry.json` + `entries/<id>.md` + README |

The factory produces packaged harnesses; the catalog indexes them. A new harness touches **all
three**: a plugin skill, its agents, and a catalog row.

## Naming

- Command = `/harness:<name>` — the `harness:` namespace already says "harness", so **do not**
  repeat it (`/harness:rust-port`, not `/harness:harness-rust-port`).
- Orchestrator skill directory = `harness/skills/<name>/`; its frontmatter `name:` = `<name>`.
- `<name>` is kebab-case, stable, and unique across the plugin and the catalog `id`.

## Anatomy of a packaged harness

```
harness/
├── LESSONS.md                              # durable, append-only cross-run lessons ledger
├── agents/                                  # SHARED plugin agent pool
│   ├── integration-qa.md                    #   shared infra (reused by every harness)
│   ├── continuity-steward.md                #   shared infra
│   ├── build-health-auditor.md              #   shared infra
│   ├── evolution-steward.md                 #   shared infra — MANDATORY in every harness
│   └── <name>-<specialist>.md               #   per-harness specialists, name-prefixed
└── skills/
    └── <name>/                              # the orchestrator (= the /harness:<name> command)
        ├── SKILL.md                         #   leader: phases, roster, data flow, eject, tests, Phase E
        ├── references/
        │   ├── backlog-seeding.md           #   findings → ordered backlog (loop harnesses)
        │   └── eject.md                     #   install-into-target-repo procedure
        └── scripts/
            ├── eject.sh                     #   copy this harness into <target>/.claude/
            ├── loop_state.template.md        #   ledger template (loop harnesses)
            └── ralph-<name>.sh               #   external SAFE self-restart runner (loop harnesses)
    ├── harness-loop-init/                   # shared — lays down .handoff/loop/ (loop's FIRST step)
    ├── session-relay-wrap-up/ + -resume/    # shared — full ICM-integrated handoff/resume
    ├── harness-evolution/                   # shared — the evolution-steward's method (MANDATORY)
    └── <name>-specific sub-skills/          # the "how" skills this harness's agents use
```

**Agent scope (shared pool model):** reusable infra agents (`integration-qa`,
`continuity-steward`, `build-health-auditor`, `evolution-steward`) are **shared, unprefixed** —
every harness reuses them. Use-case specialists are **per-harness, name-prefixed**
(`meta-plugin-registry-curator`, `rust-port-porter`) so they never collide in the shared `agents/`.

**Mandatory in every harness — self-evolution:** every harness includes the shared
`evolution-steward` agent + `harness-evolution` skill and a final **Phase E (Evaluate & evolve)**
that runs last (at DONE and HAND OFF). It evaluates the run, mines generalizable lessons into
`LESSONS.md`, and upgrades the harness — auto-applying only low-risk in-scope edits (via the standard
PR flow + a change-history row), proposing structural changes for owner approval, and **never
weakening a gate**. This is how a harness improves itself run over run (automates Phase 7).

**Durable state (loop start) — two flavors:**
- **File-based** (default for portable harnesses): `harness-loop-init` idempotently lays down
  `.handoff/loop/` (findings/, reports/, seeded `loop_state.md`, the state-contract README) before
  DISCOVER. State is committed markdown; continuity via `session-relay-wrap-up`/`-resume`.
- **Kernel-backed** (when the repo runs the `hf` Continuity Ledger Kernel): `handoff-loop-init`
  **drives `hf init`** to build the full `.handoff/` (ledger + context/capsule + packets + tasks +
  decisions) and sets the ledger-residency `.gitignore` guard — never hand-rolling kernel artifacts;
  fail-closed if `hf` is absent. The `handoff-loop` skill then runs the witnessed loop (one task/
  cycle: `hf resume` → drift → claim → work-in-scope → checkpoint → policy gate → handoff). The
  committed ledger/packet is authoritative; packets are *rendered by `hf`*, never hand-written.

Pick file-based for a portable harness; kernel-backed when the repo is on the kernel (ADR-0004/P7.36).

**Continuity (session boundaries):** a loop harness uses the shared `session-relay-wrap-up` and
`session-relay-resume` skills (the full, ICM-integrated form) — or the lighter `session-relay` — for
HAND OFF / RESUME. Wrap-up = stop-checks → Phase E retro → **ICM store** → `continuity-steward`
writes+commits `HANDOFF.md` → weave heartbeat → cron → stop. Resume = **ICM recall** → weave inbox
scan → read committed `HANDOFF.md` → verify-on-resume (fail-closed) → `relay:resumed` → reset → loop.
The committed `HANDOFF.md` (or `hf` packet) is always authoritative; weave is only the heartbeat.

## The seven steps to add a harness (the factory follows these)

1. **Triage scope.** Is it a harness (agent runtime / toolkit / skills-framework / orchestrator)?
   If not, route to the right sibling hub (`plugin_hub` / `mcp_hub` / `tool_hub`) — don't force it.
2. **Pick `<name>`** (kebab, no `harness-` prefix) and the team. Always include the shared infra
   agents — `integration-qa` (or a per-harness verifier), `continuity-steward`, **`evolution-steward`** —
   and add prefixed specialists only for genuinely new roles (Phase 3-0/4-0 duplication check first).
3. **Create the orchestrator skill** `harness/skills/<name>/SKILL.md` (assertive description with
   trigger + follow-up keywords; documents execution mode, data flow, error handling, tests, and a
   final **Phase E (Evaluate & evolve)** that runs `evolution-steward`/`harness-evolution` last).
4. **Create/​reuse agents** in `harness/agents/` and sub-skills in `harness/skills/` (reuse the shared
   `evolution-steward` + `harness-evolution` — do not re-create them).
5. **Make it ejectable** — bundle `scripts/eject.sh` (include `evolution-steward` + `harness-evolution`
   in its copy lists) + `references/eject.md` so it drops into a target repo's `.claude/`.
6. **Catalog it** — run `bash scripts/register.sh --id <name> --display "..." --category <cat>
   --status <s> --summary "..." [--runtime <r>] [--hosting registry-only --path harness/skills/<name>]`.
   The Rust-native registrar (the `hub-validate register` subcommand) appends the `registry.json`
   row, scaffolds `entries/<name>.md`, inserts the README row, bumps `updated`, and validates — one
   fail-closed step (never Python). For an external/peer repo (not vendored) use
   `--hosting peer --repo <git-url> --member <workspace-name>` instead of `--path`. `register.sh` is
   the inverse of `eject.sh`.
7. **Bump the plugin** — `plugin.json` + `marketplace.json` version, and reinstall/sync the plugin
   so `/harness:<name>` appears. Note divergence from upstream `revfactory/harness` if pushing.

## Loop vs non-loop harnesses

Not every harness is a Ralph loop. A loop harness (like `meta-plugin`) adds the durable
`.handoff/loop/` ledger, `session-relay`, `continuity-steward`, and the external runner. A one-shot
harness (e.g. a generate-then-review pipeline) may skip those and just ship an orchestrator +
agents + sub-skills. The eject + catalog + naming rules apply either way.

## Reference implementation

`meta-plugin` (`/harness:meta-plugin`) is the pilot that established this standard — see
`harness/skills/meta-plugin/` and `entries/meta-plugin.md`.
