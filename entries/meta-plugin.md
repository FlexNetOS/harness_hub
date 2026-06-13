# meta-plugin (repo-org harness)

**Category:** orchestrator · **Status:** beta · **Runtime:** multi · **Command:** `/harness:meta-plugin`

The first **packaged harness** shipped by the [`harness`](harness.md) plugin. An autonomous,
resumable, self-restarting **Ralph loop** that organizes the FlexNetOS meta workspace and runs its
combined maintenance processes, coordinated through the four plugin-subsystem repos — `harness_hub`,
`meta-plugins`, `meta_plugin_protocol`, `meta_plugin_api` — over **all** repos in `.meta.yaml`.

## What it automates

- **Hub/registry consistency** — keeps `registry.json` ↔ README ↔ entries in sync; validates via
  the Rust-native `scripts/validate.sh` (the `hub-validate` crate). No Python.
- **Cross-repo build/test/lint health** — `cargo check/build/clippy/test` per repo; gates every
  cycle on a green baseline.
- **Protocol↔consumer drift** — compares `meta_plugin_protocol` / `meta_plugin_api` against every
  consumer and classifies findings safe / risky / breaking.
- **Catalog/inventory organization** — classifies all workspace repos and routes out-of-scope ones
  to sibling hubs (`plugin_hub`, `mcp_hub`, `tool_hub`).

## Shape

- **Agents** (in the plugin's shared `harness/agents/` pool): `build-health-auditor`,
  `integration-qa`, `continuity-steward` (shared infra) + `meta-plugin-registry-curator`,
  `meta-plugin-protocol-drift-analyst` (specialists).
- **Skills** (`harness/skills/`): `meta-plugin` (orchestrator) + `session-relay`,
  `hub-registry-sync`, `cross-repo-health`, `protocol-drift-scan`.
- **Execution mode:** hybrid — single-orchestrator with specialist sub-agents, coordinated
  file-based under `.handoff/loop/` (durable, so state survives the self-restart boundary).

## Run / eject

- **Run in place:** `/harness:meta-plugin` (and `/harness:meta-plugin resume` to continue).
- **Eject into a repo:** `bash harness/skills/meta-plugin/scripts/eject.sh <target-repo-dir>` copies
  the skills + agents into `<target>/.claude/` for git-tracked, repo-owned operation. See
  `harness/skills/meta-plugin/references/eject.md`.
- **External runner (SAFE):** `harness/skills/meta-plugin/scripts/ralph-meta-plugin.sh` spawns
  fresh-context sessions until a terminal sentinel; never bypasses the permission system by default.

Pilot for the [packaged-harness convention](../docs/packaged-harness-standard.md).
