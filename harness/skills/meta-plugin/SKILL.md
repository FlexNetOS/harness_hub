---
name: meta-plugin
description: >-
  Packaged repo-organization harness (invoked as /harness:meta-plugin). Runs the autonomous
  loop that organizes the FlexNetOS meta workspace and runs its combined maintenance processes
  via harness_hub, meta-plugins, meta_plugin_protocol, and meta_plugin_api — hub/registry
  consistency, cross-repo build/test/lint health, protocol↔consumer drift, catalog/inventory
  organization — over all repos in .meta.yaml. ALWAYS use for: "organize the repos", "run the
  meta-plugin harness", "sync the catalog", "check cross-repo health", "scan for protocol drift",
  "audit the workspace", AND follow-ups — "resume", "pick up the loop", "continue", "run it
  again", "re-run", "update", "redo only the <X> pass", "based on the previous result". Also
  ejectable: "install/eject this harness into <repo>" drops its agents+skills into a target repo's
  .claude/. Drives a durable, resumable, self-restarting Ralph loop: one item per cycle, commit
  per cycle, hand off at budget.
---

# meta-plugin — packaged repo-organization harness  (`/harness:meta-plugin`)

This is the leader skill of the **meta-plugin** packaged harness, shipped in the `harness` plugin.
It weaves five agents into a durable autonomous loop that organizes the meta workspace and runs the
combined maintenance processes, coordinated through the four coordination repos (harness_hub,
meta-plugins, meta_plugin_protocol, meta_plugin_api) but operating over **all** workspace repos in
`.meta.yaml`.

It is **packaged + runnable + ejectable** (Hub Standard "packaged harness"): run it in place via
`/harness:meta-plugin`, or eject it into a target repo's `.claude/` (see §Eject). It is the
executable form of the FlexNetOS autonomous-operation pattern (proven in envctl / forge-loop /
n8n-loop): **truth lives on disk**, every cycle commits, any restart resumes cold with zero loss.

> **Continuity convention (ADR-0004 / policy P7.36):** durable loop state lives in
> **`.handoff/loop/`** — `_workspace/` is the deprecated rival convention; do not use it. When the
> meta handoff kernel (`hf`) is reachable, **prefer the kernel verbs** (`hf checkpoint`, `hf handoff`,
> `hf resume`) over hand-writing `.handoff/loop/` files; the file-based form below is the fallback
> when `hf` is unavailable. The committed checkpoint (kernel packet or `.handoff/loop/HANDOFF.md`)
> is the authoritative resume signal either way.

## Agents this harness uses (in the `harness` plugin's shared `agents/` pool)

Shared infra agents (reused by other packaged harnesses): `build-health-auditor`, `integration-qa`,
`continuity-steward`. Specialists (this harness): `meta-plugin-registry-curator`,
`meta-plugin-protocol-drift-analyst`. When ejected into a target repo, the install copies these
agent files into that repo's `.claude/agents/`.

## Execution mode — Hybrid (sub-agent + file-based), and why

The loop is **single-orchestrator with specialist sub-agents**, not a live agent team. This is a
deliberate divergence from the team-default: a live team holds shared state *in memory*, which is
destroyed at the self-restart boundary — and this loop's whole premise is that state survives a
fresh process. So coordination is **file-based** under `.handoff/loop/` (durable, resumable) plus
**return-value-based** (sub-agent results to the orchestrator). Per phase:

| Phase | Mode | Shape |
|-------|------|-------|
| Discovery / audit | Sub-agent, parallel (`run_in_background`) | Fan-out 3 auditors → fan-in to backlog |
| Execution (per cycle) | Sub-agent, sequential | One item → owning specialist → integration-qa verify |
| Handoff | Sub-agent | continuity-steward writes HANDOFF.md |

All `Agent` calls use `model: "opus"`.

## Agents (team roster)

| Agent | Owns | Type |
|-------|------|------|
| `build-health-auditor` | build/test/lint green baseline (runs first) | general-purpose |
| `meta-plugin-registry-curator` | hub/registry consistency + catalog/inventory organization | general-purpose |
| `meta-plugin-protocol-drift-analyst` | protocol↔consumer contract drift | general-purpose |
| `integration-qa` | cross-boundary verification before each commit | general-purpose |
| `continuity-steward` | writes the cold-start HANDOFF.md at budget | general-purpose |

Specialists use the matching skills: `cross-repo-health`, `hub-registry-sync`,
`protocol-drift-scan`. QA and steward use cross-boundary verification and `session-relay`.

## Phase 0: Context check (initial / resume / partial re-run)

Decide the mode **first**, from `.handoff/loop/` state and the user's phrasing:

- `.handoff/loop/HANDOFF.md` exists **and** user says resume/continue/pick-up → **RESUME**: invoke
  `session-relay` RESUME (read the committed HANDOFF.md — authoritative — run its verify-on-resume
  baseline, broadcast `relay:resumed`, reset `cycles_this_session=0`), then continue at the
  backlog's current item.
- `.handoff/loop/` exists **and** user asks to redo only one pass (e.g. "redo the drift scan") →
  **PARTIAL RE-RUN**: re-invoke only that specialist; do not touch other findings.
- `.handoff/loop/` exists **and** user provides genuinely new input/scope → **NEW RUN**: move the old
  `.handoff/loop/` to `.handoff/loop_prev/`, then run DISCOVER fresh.
- `.handoff/loop/` absent → **INITIAL RUN**: DISCOVER.

## Phase 1: DISCOVER (initial run only)

Establish reality before planning — never hallucinate the backlog.

1. Seed `.handoff/loop/loop_state.md` from the template in `scripts/loop_state.template.md`
   (supply a UTC `session_started`; the runtime can't read the clock).
2. Confirm the **green baseline first**: run `build-health-auditor` to produce
   `.handoff/loop/findings/health.md` and the canonical `.handoff/loop/baseline.md`.
3. Fan out the audit (parallel, `run_in_background: true`):
   - `meta-plugin-registry-curator` → `.handoff/loop/findings/registry.md` + `.handoff/loop/reports/inventory.md`
   - `meta-plugin-protocol-drift-analyst` → `.handoff/loop/findings/drift.md`
   (build-health-auditor's matrix is already in hand from step 2.)
4. Fan-in: synthesize all findings into `.handoff/loop/backlog.md` — one ordered `- [ ]` item per
   gap, dependency-ordered (contract fixes before consumer fixes; green baseline before catalog
   changes that assert build state). See `references/backlog-seeding.md` for the routing rules.
5. Commit `.handoff/loop/backlog.md` + `loop_state.md` + findings.

## Phase 2: ITERATE (one cycle)

Repeat until a stop condition. Each cycle:

1. **Read state** — `.handoff/loop/loop_state.md` + `.handoff/loop/backlog.md`.
2. **Stop checks** (in order):
   - no `- [ ]` left → write `.handoff/loop/DONE` (with evidence, see §DONE) and stop.
   - `cycles_this_session >= cycle_budget` → go to **Phase 3 (HAND OFF)**.
   - a `.handoff/loop/STOP` file exists → stop immediately (kill switch).
3. **Pick** the top `- [ ]` item that has its dependencies satisfied.
4. **Assign** it to the owning specialist sub-agent (`model: "opus"`), passing the item text and
   the relevant findings file. The specialist does the work the idempotent/declared way —
   **dry-run first, then apply** for anything destructive; never weaken a guard to pass.
5. **Verify across the boundary** — invoke `integration-qa` on the just-changed item. It re-runs
   the real check in a fresh shell and compares both sides. Only `PASS` proceeds; `FAIL`/`INCONCLUSIVE`
   returns the item to `- [ ]` (or `- [!]` with reason) — do NOT commit an unverified item.
6. **Write state back** — mark `- [x]`/`- [!]`, bump `cycles_this_session` and `cycles_total`,
   update `last_item`/`status`/`last_update` (UTC).
7. **Commit** — one area-prefixed commit (e.g. `chore(registry): …`, `fix(protocol): …`) including
   the touched repo files + updated `.handoff/loop/` state. A fresh process must be able to resume
   from this commit alone.
8. **Self-pace** — `ScheduleWakeup` to re-enter the next cycle (long delay if blocked on a slow
   external step; otherwise short).

## Phase 3: HAND OFF (at cycle budget)

Invoke `session-relay` HAND OFF: spawn `continuity-steward` to write+commit
`.handoff/loop/HANDOFF.md`, broadcast the weave `relay:handoff` heartbeat (`to:"all"`), best-effort
one-shot cron successor, then **stop** (no further `ScheduleWakeup`).

## DONE criteria (terminal, evidence-backed)

Write `.handoff/loop/DONE` only when ALL hold, and record the evidence inside it:
- backlog has zero `- [ ]` (every item `- [x]` verified or `- [!]` blocked-with-reason);
- `bash scripts/validate.sh` exits clean;
- `build-health-auditor` reports GREEN for the in-scope repo set (or every red is an explicit
  `- [!]` with reason);
- `meta-plugin-protocol-drift-analyst` reports zero unresolved breaking findings.

## Data transfer protocol

- **File-based** (primary): `.handoff/loop/` is the shared bus. Layout:
  `backlog.md`, `loop_state.md`, `baseline.md`, `HANDOFF.md`, `findings/{health,registry,drift,qa}.md`,
  `reports/inventory.md`. Naming for any extra artifact: `{phase}_{agent}_{artifact}.{ext}`.
- **Return-value-based**: each sub-agent returns a terse summary + proposed backlog items.
- Commit `backlog.md` + `loop_state.md` + `HANDOFF.md` + touched repo files every cycle; the
  `*.log` runner files are gitignored.

## Error handling

Core principle: **retry once; if it fails again, proceed without that result and note the
omission; never discard conflicting data — record it with its source.**

| Situation | Action |
|-----------|--------|
| Specialist sub-agent errors | Retry once. Still failing → mark the item `- [!]` blocked with the error; continue with other items. |
| Validator / build red on a fix | Do not commit. Return item to backlog; route the failure to the right owner. Never weaken the check. |
| QA returns FAIL/INCONCLUSIVE | Item is not done — re-open it; record QA evidence in `findings/qa.md`. |
| Human wall (sudo / interactive auth / reboot) | Write `.handoff/loop/NEEDS-HUMAN` with the reason; stop. Don't spin or force. |
| Conflicting findings between agents | Keep both, attributed to their source; flag for QA to adjudicate. |

## Team size

5 agents for a Large (all-workspace, 20+ item) task — at the top of the recommended band, but
each owns a distinct boundary and only one specialist runs per execution cycle, so coordination
overhead stays bounded. Do not add more agents without merging or retiring one.

## Test Scenarios

**Happy path (initial → done):** No `.handoff/loop/`. DISCOVER runs: baseline GREEN, registry valid,
no drift, but inventory finds two undocumented harness-eligible repos. Backlog seeds 2 items.
Cycle 1: meta-plugin-registry-curator adds an entry + README row → integration-qa re-runs `validate.sh` (clean)
and confirms the file exists → commit `chore(registry): catalog <repo>`. Cycle 2: same for the
second repo. Backlog empty + all DONE criteria pass → write `.handoff/loop/DONE` with evidence.

**Error path (drift + human wall):** DISCOVER finds a breaking protocol change: a new required
field added to `PluginRequest` without `#[serde(default)]`, breaking 3 consumer plugins.
Backlog seeds: (1) make the field `#[serde(default)]` in meta_plugin_protocol, (2..n) consumer
updates. Cycle 1: meta-plugin-protocol-drift-analyst proposes the contract fix; applying it needs a `cargo
publish` that requires interactive credentials → orchestrator writes `.handoff/loop/NEEDS-HUMAN`
("publish meta_plugin_protocol requires interactive auth") and stops — no forced action, no false
green. On the next human-initiated resume, the published crate is present and the loop continues
at the consumer-update items.

## Eject / install into a target repo

This harness is **packaged**: it runs in place via `/harness:meta-plugin`, and it can be *ejected*
into any target repo so that repo owns a hand-authored, git-tracked copy (the autonomous-operation
pattern wants the harness committed in the repo it drives). When the user says "install/eject this
harness into `<repo>`":

1. Run `bash scripts/eject.sh <target-repo-dir>` (bundled). It copies this harness's pieces into
   `<target>/.claude/`: the orchestrator skill (`skills/meta-plugin/`), its sub-skills
   (`session-relay`, `hub-registry-sync`, `cross-repo-health`, `protocol-drift-scan`), and the
   agents it uses from the shared pool (`build-health-auditor`, `integration-qa`,
   `continuity-steward`, `meta-plugin-registry-curator`, `meta-plugin-protocol-drift-analyst`).
2. The script also seeds `<target>/.handoff/loop/` (durable state) and prints the `.gitignore` +
   CLAUDE.md-pointer snippets the target repo needs (it does not edit those files for you — review
   and apply them, since they're repo-specific).
3. After ejecting, the harness is invoked in the target repo by its skill name (`/meta-plugin`),
   no plugin namespace required there — it's now a first-party repo skill.

See `references/eject.md` for the full procedure and the snippets. The eject script is SAFE
(copy + scaffold only); it never modifies the target's tracked files.

## References

- `references/backlog-seeding.md` — how audit findings become an ordered, dependency-correct backlog.
- `references/eject.md` — full eject/install-into-target-repo procedure.
- `scripts/loop_state.template.md` — the ledger template.
- `scripts/eject.sh` — copies this packaged harness into a target repo's `.claude/`.
- `scripts/ralph-meta-plugin.sh` — the external self-restart runner (the `/new` effect).
- `session-relay` skill — handoff/resume protocol.
