# harness_hub

**Catalog of agent harnesses — coding-agent runtimes, harness toolkits, and orchestration frameworks used across the FlexNetOS meta workspace.**

A FlexNetOS hub: `registry.json` is the single source of truth, `scripts/validate.py`
keeps it consistent (CI-enforced), and this README mirrors it. Follows the
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

The `harness` toolkit is vendored in-repo at [`harness/`](harness).

## Entry shape

See [`registry.schema.json`](registry.schema.json) for the full field reference. Key
bespoke fields: `category` (agent-runtime / harness-toolkit / skills-framework /
orchestrator), `runtime`, and `path` (for content vendored in-repo).

## Adding a harness

Add an entry to `registry.json`, create `entries/<id>.md` (and a `snippets/<id>.sh` if
useful), add a Catalog row, then run `python3 scripts/validate.py`. See the
[Hub Standard](https://github.com/FlexNetOS/template_hub/blob/master/docs/hub-standard.md).
