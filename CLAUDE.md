# harness_hub

Catalog of agent harnesses for the FlexNetOS meta workspace. `registry.json` is the single source
of truth; the **Rust-native** `scripts/validate.sh` (the `hub-validate` crate) enforces it
(CI-enforced). No Python tooling — the workspace is Rust-native.

## Packaged harnesses (the `harness` plugin)

The vendored `harness/` plugin is a **factory + a library of packaged harnesses**. `/harness:harness`
builds harnesses; `/harness:<name>` runs a ready-made one. Every new harness follows the
[packaged-harness standard](docs/packaged-harness-standard.md): an orchestrator skill in
`harness/skills/<name>/`, agents in the shared `harness/agents/` pool (infra shared, specialists
name-prefixed), a `registry.json` catalog row, and ejectability into a target repo's `.claude/`.

**Harness: meta-plugin (`/harness:meta-plugin`)** — the pilot packaged harness. An autonomous,
resumable, self-restarting Ralph loop that organizes the meta workspace and runs the combined
maintenance processes (hub/registry consistency, cross-repo build/test/lint health, protocol↔consumer
drift, catalog/inventory organization), coordinated via harness_hub, meta-plugins,
meta_plugin_protocol, meta_plugin_api, over all repos in `.meta.yaml`.

**Trigger:** for repo-organization, catalog-sync, cross-repo-health, protocol-drift, workspace-audit,
or "resume/continue/re-run the loop" tasks, use `/harness:meta-plugin` (or `/meta-plugin` once
ejected). Simple one-off questions may be answered directly. To add a *new* packaged harness, use
`/harness:harness` and follow the packaged-harness standard.

**Harness: rust-port (`/harness:rust-port`)** — a full-feature, **no-downgrade** Rust-port loop. A
parity ledger inventories every source unit; each is ported fully (no stubs) then differentially
parity-verified (source vs Rust) before it counts as done; `DONE` only at 100% + a left-behind sweep.
**Trigger:** "port \<project\> to Rust", "rust port", "full-parity port", "resume the port".

**Continuity:** committed `.handoff/loop/HANDOFF.md` is the authoritative cold-resume signal; weave is
only an observable heartbeat. The external runner
(`harness/skills/meta-plugin/scripts/ralph-meta-plugin.sh`) is **SAFE by default** — it does not
bypass the permission system; unattended apply is a deliberate, settings-authorized opt-in.

**Change history:**
| Date | Change | Target | Reason |
|------|--------|--------|--------|
| 2026-06-13 | Initial build: repo-org-loop harness — 5 agents, 5 skills, external SAFE runner | `.claude/` (repo-local) | Requested: loop workflow automating organization + combined processes via the 4 coordination repos |
| 2026-06-13 | Port catalog validator Python→Rust (`hub-validate` crate + `validate.sh`); rewire CI/README/schema; delete `validate.py` | `scripts/`, CI, README, schema | Owner constraint: Rust-native only, no Python |
| 2026-06-13 | Promote repo-org-loop into the `harness` plugin as packaged harness `/harness:meta-plugin`; shared agent pool; ejectable; catalog row; plugin v1.2.0→1.3.0; establish `docs/packaged-harness-standard.md` | `harness/agents/`, `harness/skills/`, `registry.json`, `entries/`, `docs/` | Owner vision: harness_hub = library of per-use-case packaged harnesses exposed as `/harness:<name>` |
| 2026-06-13 | Rust-native `register` subcommand + `scripts/register.sh` (inverse of eject); cataloged `handoff` + `weave` as peers | `scripts/`, `registry.json`, `entries/` | Repeatable one-command harness registration |
| 2026-06-13 | New packaged harness `/harness:rust-port` (full-feature no-downgrade Rust port loop) — 4 specialist agents + 3 skills + parity ledger; plugin v1.3.0→1.4.0 | `harness/agents/rust-port-*`, `harness/skills/rust-port*`, `registry.json`, `entries/` | Owner: automated full-parity Rust port harness (flagship: meta/Archon TS→Rust) |
| 2026-06-13 | Mandatory shared self-evolution: `evolution-steward` agent + `harness-evolution` skill + `LESSONS.md` ledger + a final **Phase E** wired into every harness (meta-plugin, rust-port) and the standard | `harness/agents/evolution-steward.md`, `harness/skills/harness-evolution/`, `harness/LESSONS.md`, both orchestrators + eject scripts, `docs/` | Owner: a common evaluation+upgrade agent that learns lessons each run and upgrades the harness |
| 2026-06-13 | rust-port upgrade: full wrap-up/handoff — new shared `session-relay-wrap-up` + `session-relay-resume` skills (ICM store/recall + weave inbox + verify-on-resume, ideas from weave session-relay & ICM hooks); wired into rust-port Phase 0/3 + eject | `harness/skills/session-relay-{wrap-up,resume}/`, `harness/skills/rust-port/`, `docs/` | Owner-directed via `/harness:harness-evolution`; meta-plugin may adopt (proposed, scope law) |
| 2026-06-13 | meta-plugin adopts `session-relay-wrap-up` + `session-relay-resume` (Phase 0/3 + eject + references) — continuity now uniform across both packaged harnesses | `harness/skills/meta-plugin/` | Owner approved the cross-harness proposal ("do it") |
| 2026-06-13 | New packaged harness `/harness:code-research` (deep, read-only code research & analysis — fan-out analysts → adversarial claim verification vs source → decision-grade report) — 4 specialist agents + 3 skills; plugin v1.4.0→1.5.0 | `harness/agents/code-research-*`, `harness/skills/code-research*`, `registry.json`, `entries/`, `docs/` | Owner: evidence-based analysis to settle "is Archon a harness/agent manager?" + reusable capability |
| 2026-06-13 | ADR-0001: `harness-agent-rs` — Rust harness/agent-manager runtime, ported from Archon's design + mapped onto hf/weave/grit/icm; markdown builder kept as-is; current-architecture-only (3 legacy versions excluded) | `docs/adr/0001-harness-agent-rs.md` | code-research verdict accepted; owner: "Archon is an agent harness manager — start the rust port to new repo harness-agent-rs" |
| 2026-06-13 | New shared skill `harness-loop-init` (idempotently lays down `.handoff/loop/` — a loop's first step) + init script; added to the 3 loop-harness eject lists + standard; staged the session handoff (`.handoff/loop/HANDOFF.md`: STEP1 code-research oh-my-pi → STEP2 rust-port DISCOVER) | `harness/skills/harness-loop-init/`, eject scripts, `docs/`, `.handoff/loop/HANDOFF.md` | Owner: build harness-loop-init + session handoff via /session-relay-wrap-up |
| 2026-06-13 | Kernel-backed loop flavor: `handoff-loop-init` (drives `hf init` for the FULL `.handoff` buildout + ledger-residency guard; kernel-first, fail-closed) + `handoff-loop` (witnessed `hf` loop: resume→drift→claim→checkpoint→policy→handoff); standard documents file-based vs kernel-backed; plugin v1.5.0→1.6.0 | `harness/skills/handoff-loop-init/`, `harness/skills/handoff-loop/`, `docs/` | Owner: "/handoff-loop-init build the .handoff kernel and full .handoff buildout" (was not registered) |
| 2026-06-13 | Vendored the `handoff-loop` harness from `meta/handoff` into `harness_hub/handoff-loop/` (.claude [12 skills+9 agents], .agent, .handoff [minus ledger.db], .grit, .github, docs, schemas, scripts, guide files); EXCLUDED the Rust kernel crates (hf/ledger/work-order) + build/scratch. Renamed plugin skill `handoff-loop`→`handoff-loop-run` (do-not-delete); anchored `.gitignore` `/.claude/*` so the vendor's `.claude` is fully tracked | `handoff-loop/`, `harness/skills/handoff-loop-run/`, `.gitignore`, `docs/` | Owner: "create handoff-loop folder, copy .claude + .agent from meta/handoff; change the name, don't delete" |
| 2026-06-13 | Continuous-autonomous-cadence rule (merged from master #15): a loop runs plan→implement→test→next continuously to a ~50% context budget, not stop-and-ask per item; only genuine walls halt | `docs/packaged-harness-standard.md`, `harness/LESSONS.md`, `.handoff/loop/{evaluation,proposed-upgrades}.md` | Concurrent meta-session rule reconciled into develop during the develop↔master merge |
| 2026-06-13 | rust-port `/verify` fix + scale upgrades: **(bug)** the symbol-map harvest prescribed `git kb index` but git-kb's command is **`git kb code index`** (verified by running git-kb 0.2.10: wrong form errors → empty harvest → the fail-closed rule would wall every port at DISCOVER); fixed all 6 occurrences (5 rust-port + 1 code-research-map). **(accuracy)** git-kb's `visibility` field is null (Rust) → derive the visibility filter from the `signature`'s pub/export marker. **(scale, for ports ≥ Archon)** symbol-map sharding by package (bounded per-cycle reads) + a DISCOVER **source-runnable baseline** (fail-fast NEEDS-HUMAN if the source toolchain can't run, vs every-unit INCONCLUSIVE). plugin v1.7.0→1.7.1 | `harness/skills/rust-port/references/symbol-map.md`, `harness/skills/rust-port/SKILL.md`, `harness/agents/rust-port-cartographer.md`, `harness/skills/rust-port-inventory/`, `harness/skills/rust-port/references/eject.md`, `harness/skills/code-research-map/`, `harness/.claude-plugin/{plugin,marketplace}.json`, `harness/LESSONS.md` | `/verify` ran the prescribed commands + a gap hunt for repos ≥ the flagship target; runtime-found bug + scale/runnability gaps closed (no-downgrade) |
| 2026-06-13 | rust-port harness self-upgrade (designed+adversarially-verified via `/harness:harness-evolution`, no-downgrade-only): **(1) detailed symbol mapping** — new `references/symbol-map.md` + `.handoff/loop/symbol-map.md` (one row per source symbol, deterministic `git kb code symbols --json --limit -1` harvest, visibility-filtered, **empty-harvest fail-closed**), the unit→symbol **rollup rule**, and a two-grain pre-DONE sweep (a dropped method/field/variant/route can no longer hide); **(2) agent-runtime porting** — new `references/runtime-constructs.md` (reimplement-vs-MAP-ONTO `hf`/`weave`/`grit`/`icm`/provider-CLI per ADR-0001, no behavior dropped) + a `rust-port-translate` agent-runtime idiom-map section + cartographer runtime/concurrency inventory dimension + streaming/concurrency/cancellation/backpressure differential scenarios in the verifier; **(3) agent runtime contract** — explicit per-agent execution table in the orchestrator (the spec `harness-agent-rs` consumes) + team-size 6→7 fix; **(4) gap-fill** — eject.md/entries/registry de-staled to match `eject.sh` (9 skills incl. `harness-loop-init`, 7 agents incl. `evolution-steward`), `loop_state` symbol counter, plugin v1.6.0→1.7.0 | `harness/skills/rust-port/**` (SKILL + references/{symbol-map,runtime-constructs,parity-ledger,eject} + scripts), `harness/skills/rust-port-{inventory,translate,parity}/`, `harness/agents/rust-port-*`, `entries/rust-port.md`, `registry.json`, `harness/.claude-plugin/{plugin,marketplace}.json`, `harness/LESSONS.md` | Owner-directed harness evolution: deepen the parity/DONE gate (strengthen-only) — detailed symbol mapping, agent runtime, fill all gaps, 100% Rust-native no-feature-left-behind |
