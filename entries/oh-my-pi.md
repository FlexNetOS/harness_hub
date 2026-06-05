# oh-my-pi (omp)

A standalone **coding agent with the IDE wired in** — its own agent runtime, not a Claude
Code plugin. A TypeScript/Rust/Bun monorepo (`omp-monorepo`) with a TUI, a swarm
extension, and `agent`/`ai`/`coding-agent` packages.

| | |
|---|---|
| **Repo** | [`FlexNetOS/oh-my-pi`](https://github.com/FlexNetOS/oh-my-pi) (fork of [`can1357/oh-my-pi`](https://github.com/can1357/oh-my-pi)) |
| **Category** | agent-runtime |
| **Runtime** | multi (TypeScript / Rust / Bun) |
| **Package** | `@oh-my-pi/pi-coding-agent` (npm) |
| **Homepage** | https://omp.sh |
| **License** | MIT |
| **Status** | stable |
| **Hosting** | peer (workspace member `oh-my-pi/`) |

## What it is

A self-contained coding-agent harness — an alternative agent runtime (like Claude Code or
Codex), **not** a Claude Code plugin. Its `packages/` include `coding-agent`, `agent`,
`ai`, `tui`, `swarm-extension`, `mnemopi`, `hashline`, and `natives`.

## Run

Snippet: [`snippets/oh-my-pi.sh`](../snippets/oh-my-pi.sh)

```bash
# published agent (npm)
npx @oh-my-pi/pi-coding-agent
# or build from the workspace clone (Bun)
cd oh-my-pi && bun install && bun run build
```

## Why it's in harness_hub (not plugin_hub or tool_hub)

- **Not plugin_hub** — the `marketplace.json` files in the repo are *test fixtures*; omp
  is not a Claude Code plugin.
- **Not tool_hub / no envctl connection** — omp is an *agent harness* (a coding-agent
  runtime), not a CLI dev tool, and has no relationship to envctl. (Any omp/omc packages
  that ended up under `envctl/` are unused there and are not a real dependency.)
- **harness_hub** is the right home: it catalogs agent harnesses and runtimes.
