#!/usr/bin/env bash
# oh-my-pi (omp) — a standalone coding agent. https://omp.sh
# Published as the npm package @oh-my-pi/pi-coding-agent.

# Run the published agent without installing:
npx @oh-my-pi/pi-coding-agent

# Or build from the meta workspace clone (Bun runtime):
#   cd oh-my-pi
#   bun install
#   bun run build
#   bun run packages/coding-agent   # launch the coding agent

# omp is its own agent runtime — not a Claude Code plugin and unrelated to envctl.
