# harness (toolkit)

The harness toolkit — vendored in this repo at [`harness/`](../harness). It backs the
`harness` meta-skill (configure/build a harness: define specialized agents and the skills
they use) and carries the project's skills, docs, and landing site.

| | |
|---|---|
| **Category** | harness-toolkit |
| **Runtime** | node |
| **Upstream** | [`FlexNetOS/harness`](https://github.com/FlexNetOS/harness) |
| **Hosting** | registry-only (vendored in-repo at `harness/`) |
| **Status** | beta |

## What it is

The `harness/` tree includes a `.claude-plugin/`, `skills/`, `docs/`, `_workspace/`, and a
static site. It is the source of the `harness` skill used elsewhere in the workspace to
design agent teams and the skills those agents use.

## Notes

Vendored into harness_hub (the nested `.git` was stripped) — it lives directly in this
repo's tree, not as a nested-meta child or a separate peer. If it later needs independent
history, promote it to its own repo and switch this entry to `hosting: peer`.
