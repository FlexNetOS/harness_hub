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
├── agents/                                  # SHARED plugin agent pool
│   ├── integration-qa.md                    #   shared infra (reused by every harness)
│   ├── continuity-steward.md                #   shared infra
│   ├── build-health-auditor.md              #   shared infra
│   └── <name>-<specialist>.md               #   per-harness specialists, name-prefixed
└── skills/
    └── <name>/                              # the orchestrator (= the /harness:<name> command)
        ├── SKILL.md                         #   leader: phases, roster, data flow, eject, tests
        ├── references/
        │   ├── backlog-seeding.md           #   findings → ordered backlog (loop harnesses)
        │   └── eject.md                     #   install-into-target-repo procedure
        └── scripts/
            ├── eject.sh                     #   copy this harness into <target>/.claude/
            ├── loop_state.template.md        #   ledger template (loop harnesses)
            └── ralph-<name>.sh               #   external SAFE self-restart runner (loop harnesses)
    ├── session-relay/                       # shared sub-skills (handoff/resume, etc.)
    └── <name>-specific sub-skills/          # the "how" skills this harness's agents use
```

**Agent scope (shared pool model):** reusable infra agents (`integration-qa`,
`continuity-steward`, `build-health-auditor`) are **shared, unprefixed** — every harness reuses
them. Use-case specialists are **per-harness, name-prefixed** (`meta-plugin-registry-curator`,
`rust-port-porter`) so they never collide in the shared `agents/` directory.

## The seven steps to add a harness (the factory follows these)

1. **Triage scope.** Is it a harness (agent runtime / toolkit / skills-framework / orchestrator)?
   If not, route to the right sibling hub (`plugin_hub` / `mcp_hub` / `tool_hub`) — don't force it.
2. **Pick `<name>`** (kebab, no `harness-` prefix) and the team (reuse shared agents; add prefixed
   specialists only for genuinely new roles — Phase 3-0/4-0 duplication check first).
3. **Create the orchestrator skill** `harness/skills/<name>/SKILL.md` (assertive description with
   trigger + follow-up keywords; documents execution mode, data flow, error handling, tests).
4. **Create/​reuse agents** in `harness/agents/` and sub-skills in `harness/skills/`.
5. **Make it ejectable** — bundle `scripts/eject.sh` + `references/eject.md` so it can be dropped
   into a target repo's `.claude/` for git-tracked, repo-owned operation.
6. **Catalog it** — add a `registry.json` row (`category`, `status`, `runtime`, `hosting`,
   `path: harness/skills/<name>`, `doc: entries/<name>.md`), the entry doc, and the README row;
   then `bash scripts/validate.sh` must pass (Rust-native; never Python).
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
