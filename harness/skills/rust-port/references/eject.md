# Ejecting the rust-port harness into the port repo

`/harness:rust-port` runs in place; eject it for a git-tracked, repo-owned instance in the repo that
will hold the Rust port (recommended for a long, resumable port).

```bash
bash <plugin>/skills/rust-port/scripts/eject.sh <target-repo-dir>
```

SAFE (copy + scaffold only). It copies the orchestrator skill (`rust-port/`) and sub-skills
(`rust-port-inventory`, `rust-port-translate`, `rust-port-parity`, `rust-port-merge`,
`cross-repo-reference`, `icm-memory`, `session-relay-wrap-up`, `session-relay-resume`,
`cross-repo-health`, `harness-loop-init`, `harness-evolution`) into `<target>/.claude/skills/`,
the 10 agents (7 specialists + `build-health-auditor`, `continuity-steward`, `evolution-steward`) into
`<target>/.claude/agents/`, scaffolds `<target>/.handoff/loop/`, and prints the
`.gitignore` / `CLAUDE.md` / **`SessionStart` recall-hook** snippets to apply.

## Pre-session memory priming (the most important memory layer)

Eject prints a `.claude/settings.json` **`SessionStart` hook** that runs `icm recall-context` at every
session start — **deterministic priming, no model decision**, so the agent starts informed by prior
decisions/errors/gotchas (a missed recall makes the *whole* session run blind, which is why this
outranks an end-of-session store). The bundled **`icm-memory` skill** is the as-needed complement (the
model recalls/stores mid-task). Within the meta workspace this hook is inherited from the user-global
settings; **outside it, apply the printed snippet** so the priming travels with the harness. It is a
graceful no-op where ICM is absent (so it never blocks session start).

## Durability — the harness's truth must be committed (read before applying `.gitignore`)

The ejected `.claude/agents/`+`.claude/skills/` AND the `.handoff/loop/*.md` ledgers (`loop_state`,
`parity-ledger`, `symbol-map`, `findings/*`) are the **continuity contract**: a fresh session resumes
*only* from what was **committed**. So the `.gitignore` must keep them tracked — the eject prints the
**contents-form** snippet (`.claude/*` + `!.claude/agents/` + `!.claude/skills/`; ignore only
`.handoff/loop/*.log`, **never** `.handoff/` or `.handoff/loop/` as a directory).

**The dir-form trap.** A pre-existing **dir-form** ignore — `.claude/` or `.handoff/` (a directory, no
`/*`) — silently **swallows** the agents/skills and the ledgers, and you **cannot** rescue it with
`!`-exceptions: git refuses to re-include a path whose *parent directory* is excluded. The eject now
**detects** a dir-form ignore in the target's `.gitignore` and **warns** (and runs `git check-ignore`
on representative agent/ledger paths). Fix it by changing `.claude/` → `.claude/*`, or force-track
(`git add -f <path>`). (Observed: a repo with a bare `.claude/` would lose its whole ejected harness;
a `.handoff/`-ignoring convention would kill cold-resume.)

> **Note vs the `hf` kernel's `.handoff/`.** The `hf`/`meta-handoff` kernel gitignores *regenerable*
> `.handoff/**/*.db`/`packets/` — that is **not** the rust-port loop's `.handoff/loop/*.md`, which is
> durable source-of-truth and **must** be committed. Don't let a kernel-style `.handoff/**` ignore
> reach the loop ledgers.

After ejecting, invoke as **`/rust-port`** in the target repo. Seed `loop_state.md` with the **source
root** (project being ported) and the **Rust target** crate/dir on first run. DISCOVER's cartographer
then seeds both `.handoff/loop/parity-ledger.md` (units) and `.handoff/loop/symbol-map.md` (one row
per source symbol, harvested via `git kb code symbols --json --limit -1`); the source must be
indexable (`git kb code index <source_root>`) so symbol coverage is provable, not grep-guessed.

## Source vs target layout

The source project and the Rust target may be the same repo (port-in-place under a new crate) or two
repos. Record both paths in `loop_state.md`; the parity-verifier needs to *run the source*, so the
source's toolchain (bun/node/python) must be available in the port environment.
