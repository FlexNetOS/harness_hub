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
