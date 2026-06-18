# Ejecting the feature-forge harness into a target Rust repo

`/harness:feature-forge` runs in place; eject it for a git-tracked, repo-owned instance in the repo
that will hold the feature work (recommended for a long, resumable backlog loop).

```bash
bash <plugin>/skills/feature-forge/scripts/eject.sh <target-repo-dir>
```

SAFE (copy + scaffold only). It copies the orchestrator skill (`feature-forge/`), the sub-skills
(`forge-loop`, `rust-feature-impl`) and the shared skills (`session-relay-wrap-up`,
`session-relay-resume`, `harness-loop-init`, `harness-evolution`, `icm-memory`) into
`<target>/.claude/skills/`, the 6 agents (4 specialists — `feature-forge-architect`, `-implementer`,
`-guardian`, `-kernel-engineer` — plus the shared `evolution-steward` + `continuity-steward`) into
`<target>/.claude/agents/`, scaffolds `<target>/.handoff/loop/`, and prints the `.gitignore` /
`CLAUDE.md` / **`SessionStart` recall-hook** snippets to apply.

## Adapt the invariant set to the target repo

The bundled agents + `rust-feature-impl` encode **envctl's** invariant set (no-C trust boundary,
engine-first non-printing library, fail-closed dry-run guards, the 3 CI gates `no-c`/`shape`/`enable`).
That is the source pattern, not a universal contract. After ejecting into a **different** Rust repo:

- Replace the invariant table in `rust-feature-impl/SKILL.md` and the agent defs with **that repo's**
  CLAUDE.md invariants, and point the guardian at that repo's actual CI gate scripts.
- Keep the **discipline** intact: engine-first (logic in the shared lib, not the front-ends),
  front-end parity, fail-closed mutation, no banned native deps, locks/manifest honest, the
  Phase-3.5 runtime observation, and the Unit-ledger completeness gate. Those generalize directly.

## What is NOT ejected (deliberate scope)

The envctl-domain-specific loops are **not** bundled and not portable:
- `env-install-loop` / `auto-provision` — workstation provisioning via `doctor`/`install`/`auto-fix`.
- `handoff-sync` — building the `hf` continuity kernel + seeding the Tier-A `.handoff`.

The generic continuity path here is `session-relay-wrap-up`/`-resume` (+ `harness-loop-init` to lay
down `.handoff/loop/`); generic kernel work routes to `feature-forge-kernel-engineer`
(which falls back to the standard `handoff-loop-init`/`-run` skills outside envctl).

## Pre-session memory priming (the most important memory layer)

Eject prints a `.claude/settings.json` **`SessionStart` hook** that runs `icm recall-context` at every
session start — **deterministic priming, no model decision**, so the agent starts informed by prior
decisions/errors/gotchas (a missed recall makes the *whole* session run blind, which is why this
outranks an end-of-session store). The bundled **`icm-memory` skill** is the as-needed complement (the
model recalls/stores mid-task). Within the meta workspace this hook is inherited from the user-global
settings; **outside it, apply the printed snippet** so the priming travels with the harness. It is a
graceful no-op where ICM is absent (so it never blocks session start).

After ejecting, invoke as **`/feature-forge`** (single feature) or **`/forge-loop`** (continuous over a
backlog) in the target repo. Seed `.handoff/loop/loop_state.md` from
`skills/feature-forge/scripts/loop_state.template.md` and create `.handoff/loop/backlog.md` from your
roadmap on first run.

## External SAFE runner

For truly-unattended set-and-forget operation (fresh context per cycle), use the bundled
`skills/feature-forge/scripts/ralph-feature-forge.sh` — it spawns a fresh `claude -p` per iteration
(each a clean session resuming from durable `.handoff/loop/` state). SAFE by default: each spawned
session prompts for permission as usual; the runner contains no permission-system bypass.
