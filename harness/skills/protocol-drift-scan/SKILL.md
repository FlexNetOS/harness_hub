---
name: protocol-drift-scan
description: >-
  How to detect drift between the shared meta_plugin_protocol / meta_plugin_api contract and every
  consumer that depends on it. ALWAYS use when checking plugin protocol/API compatibility, hunting
  breaking changes, comparing host↔plugin contracts, or assessing the blast radius of a protocol
  edit. Triggers on "protocol drift", "breaking change", "plugin API compatibility", "does this
  break the plugins", "contract mismatch", "version skew". Compares across the boundary — not
  existence-checking.
---

# Protocol Drift Scan

The plugin subsystem works only because every plugin speaks the **exact** protocol the host
expects. This skill is how `meta-plugin-protocol-drift-analyst` catches the moment that stops being true.

## The canonical contract

- `meta_plugin_protocol/src/lib.rs` — `PluginInfo`, `PluginHelp`, `PluginRequest`,
  `PluginRequestOptions`, `ExecutionPlan`, `PlannedCommand`, `PlanResponse`, `CommandResult`, and
  the `run_plugin()` harness. The wire protocol: host discovers via `--meta-plugin-info`
  (plugin emits `PluginInfo` JSON), invokes via `--meta-plugin-exec` (host sends `PluginRequest`
  JSON on stdin), plugin replies with a `PlanResponse` JSON or direct output.
- `meta_plugin_api/src/lib.rs` — the shared plugin API surface.

Treat these as the source of truth; consumers must conform to them.

## Finding the consumers

Enumerate from `.meta.yaml`: every project with `depends_on: [plugin-protocol]` or
`[plugin-api]` (e.g. `meta_cli`, `meta_git_cli`, `meta_project_cli`, `meta_rust_cli`,
`meta_dashboard_cli`), plus the `meta-plugins/plugins/*` registry entries (each names a plugin
repo that must implement the protocol).

## Compare across the boundary (not existence-checking)

For each consumer, read the canonical type AND the consumer's use of it **together**, and reason
about **wire compatibility**:

- Field names / shapes match? serde attributes preserved (`#[serde(default)]`,
  `skip_serializing_if`)? A field the host now requires but a consumer omits = break.
- Enum variants align (e.g. `CommandResult` arms)?
- The discovery/exec flag contract honored (`--meta-plugin-info`, `--meta-plugin-exec`)?
- Cargo dependency version vs. the crate's actual `version` — version skew?

Prefer `git-kb code` (`callers`, `callees`, `impact`, `symbols` — `--json`) over grep for this:
it understands the call graph and gives stable symbol IDs. Use grep only for string/config matches.

## Classify every finding

| Class | Meaning | Seeds a backlog item? |
|-------|---------|-----------------------|
| `safe` | backward-compatible (new optional field, additive enum used non-exhaustively) | No — record only |
| `risky` | compatible *if* assumptions hold; needs confirmation | Yes |
| `breaking` | would fail to build / mis-deserialize against the prior contract | Yes |

Each finding cites the canonical location and the consumer location (`file:line`) and states the
concrete consequence.

## Output and ordering

Write `.handoff/loop/findings/drift.md`: a table of contract → consumer → class → consequence →
suggested fix. Order remediation so the **contract fix lands first**, then one consumer-update item
per affected repo (each depending on the contract item), then a final
`build-health-auditor confirms all affected repos green` item.

## Evidence, not assertion

Never call a change "safe" you can't justify from the types. If a consumer's version is
unresolvable or the repo is absent, classify `unverifiable` — never `safe` by default.
