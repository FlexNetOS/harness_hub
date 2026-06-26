# harness_hub

**Catalog of agent harnesses — coding-agent runtimes, harness toolkits, and orchestration frameworks used across the FlexNetOS meta workspace.**

A FlexNetOS hub: `registry.json` is the single source of truth, the Rust-native
`scripts/validate.sh` (the `hub-validate` crate) keeps it consistent (CI-enforced),
and this README mirrors it. Follows the
[Hub Standard](https://github.com/FlexNetOS/template_hub/blob/master/docs/hub-standard.md).

## Scope

In scope: **agent harnesses** — self-contained coding-agent runtimes (e.g. oh-my-pi),
harness toolkits/skill frameworks, and orchestration systems for agents.

Out of scope: Claude Code *plugins* → [`plugin_hub`](https://github.com/FlexNetOS/plugin_hub);
MCP servers → [`mcp_hub`](https://github.com/FlexNetOS/mcp_hub); plain CLI tools →
[`tool_hub`](https://github.com/FlexNetOS/tool_hub). Rule of thumb: *if it's an agent
runtime or the toolkit that builds one, it belongs here.*

## Catalog

| Harness | Category | Runtime | Status | Doc |
|---------|----------|---------|--------|-----|
| [oh-my-pi](entries/oh-my-pi.md) | agent-runtime | multi | stable | [doc](entries/oh-my-pi.md) · [run](snippets/oh-my-pi.sh) |
| [harness](entries/harness.md) | harness-toolkit | node | beta | [doc](entries/harness.md) |
| [meta-plugin](entries/meta-plugin.md) | orchestrator | multi | beta | [doc](entries/meta-plugin.md) |
| [handoff](entries/handoff.md) | orchestrator | multi | beta | [doc](entries/handoff.md) |
| [weave](entries/weave.md) | orchestrator | rust | beta | [doc](entries/weave.md) |
| [rust-port](entries/rust-port.md) | orchestrator | multi | beta | [doc](entries/rust-port.md) |
| [code-research](entries/code-research.md) | orchestrator | multi | beta | [doc](entries/code-research.md) |
| [feature-forge](entries/feature-forge.md) | orchestrator | multi | beta | [doc](entries/feature-forge.md) |
| [bootstrap](entries/bootstrap.md) | orchestrator | multi | beta | [doc](entries/bootstrap.md) |
| [planning-engineer](entries/planning-engineer.md) | orchestrator | multi | beta | [doc](entries/planning-engineer.md) |

The `harness` toolkit is vendored in-repo at [`harness/`](harness); it now also ships **packaged
harnesses** (ready-made, runnable, ejectable) as `/harness:<name>` commands — see the
[packaged-harness standard](docs/packaged-harness-standard.md). `meta-plugin` is the first.

## Entry shape

See [`registry.schema.json`](registry.schema.json) for the full field reference. Key
bespoke fields: `category` (agent-runtime / harness-toolkit / skills-framework /
orchestrator), `runtime`, and `path` (for content vendored in-repo).

## Adding a harness

Add an entry to `registry.json`, create `entries/<id>.md` (and a `snippets/<id>.sh` if
useful), add a Catalog row, then run `bash scripts/validate.sh`. See the
[Hub Standard](https://github.com/FlexNetOS/template_hub/blob/master/docs/hub-standard.md).
