---
name: hub-registry-sync
description: >-
  How to keep the harness_hub catalog truthful and organize the workspace's repo inventory.
  ALWAYS use when editing registry.json, adding/updating an entry doc, syncing the README Catalog
  table, validating the hub, or classifying/routing repos across the FlexNetOS hub family. Triggers
  on "registry", "catalog", "hub entry", "validate the hub", "Hub Standard", "inventory the repos",
  "which hub does X belong in". Validation is Rust-native (scripts/validate.sh) — never reintroduce
  Python.
---

# Hub Registry Sync

`registry.json` is the **single source of truth**; the README and `entries/<id>.md` are renderings
of it. This skill is how `meta-plugin-registry-curator` keeps them consistent and organizes the repo inventory.

## The validator is Rust-native

Validate with `bash scripts/validate.sh` (the `hub-validate` crate at `scripts/hub-validate/`).
It checks: required top-level keys, required entry fields, kebab-case unique ids, enum membership
(status / category / runtime / hosting), referenced files exist (`doc`, `snippet`), and that the
README links each entry's `doc`/`snippet`. **A clean exit is the gate** — an item is not done until
the validator passes. Never reintroduce a Python validator (workspace-owner constraint); if a new
check is needed, extend `scripts/hub-validate/src/main.rs`.

## Editing flow (source → renderings → validate)

1. Edit `registry.json` first (the source). Match `registry.schema.json`: every entry needs at
   minimum `id`, `displayName`, `category`, `status`, `summary`, `doc`.
2. Create/update the entry doc at the `doc` path (`entries/<id>.md`) and the snippet if referenced.
3. Update the README **Catalog** table row so it links the same `doc`/`snippet` paths.
4. Bump `registry.json`'s `updated` date when the catalog content changes.
5. Run `bash scripts/validate.sh` — fix the smallest cause of any failure and re-run until clean.

## Scope rules (what belongs in harness_hub)

harness_hub catalogs **agent harnesses only**: agent runtimes, harness toolkits, skills
frameworks, orchestrators. Out of scope, with the correct sibling hub:

| Thing | Hub |
|-------|-----|
| Claude Code *plugin* | `plugin_hub` |
| MCP server | `mcp_hub` |
| Plain CLI tool | `tool_hub` |

Rule of thumb: *if it's an agent runtime or the toolkit that builds one, it belongs here.* When a
repo is out of scope, record the routing in `.handoff/loop/reports/inventory.md` — do not force it
into this registry.

## Inventory / organization pass

1. Enumerate workspace repos from `.meta.yaml`.
2. For each, classify: in-scope-here / belongs-in-sibling-hub / not-a-catalog-target.
3. Detect **undocumented harness-eligible** repos (in scope, missing from registry.json) and
   **orphan entries** (registry entry whose `repo`/`path`/`doc` no longer resolves).
4. Write the combined inventory to `.handoff/loop/reports/inventory.md`: repo → classification →
   target hub → action (or "none"). Seed backlog items only for in-scope gaps (per
   `meta-plugin/references/backlog-seeding.md`).

## Cross-repo operations are Rust-native

Drive multi-repo reads through the `meta` CLI (`meta project list`, `meta exec -- …`) rather than
hand-walking directories. Keep all tooling Rust-native or shell glue — no Python.
