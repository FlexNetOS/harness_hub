---
name: bootstrap
description: >-
  One-shot bootstrap that takes a FRESH repo (no harness, no hf) onto the hf Continuity Ledger Kernel
  AND the forge-loop / feature-forge harness, in one idempotent pass (invoked as /harness:bootstrap).
  ALWAYS use for: "set up the harness in <repo>", "bootstrap <repo>", "add hf + forge-loop to <repo>",
  "install the harness here", "stand up a new repo on the kernel", "onboard <repo> to the loop",
  "set up meta/network-manager". Installs hf if absent (builds meta/handoff + symlinks), registers the
  repo as an hf fleet member (.meta.yaml), runs handoff-loop-init (hf init + residency guard), ejects
  the feature-forge harness, wires CLAUDE.md/.gitignore/settings, seeds the backlog, and verifies.
  SAFE: dry-run by default, --apply to execute. Do NOT use to RUN the loop (that's /forge-loop) or to
  re-init an already-bootstrapped repo (idempotent, but unnecessary).
---

# bootstrap — fresh-repo → hf kernel + forge-loop, in one pass

Onboards a brand-new repo (the `meta/network-manager` archetype — may not even be a fleet member yet)
to the full continuity stack: the **hf Continuity Ledger Kernel** *and* the **forge-loop /
feature-forge construction-crew harness**. It is the composition layer over the existing primitives —
it does not reinvent them:

| It reuses | For |
|-----------|-----|
| `handoff-loop-init` (`init-handoff-kernel.sh`) | the kernel `.handoff/` (`hf init` + ledger-residency guard) |
| `feature-forge/scripts/eject.sh` | the harness (skills + agents + file-based `.handoff/loop/`) |
| `session-relay-wrap-up`/`-resume`, `forge-loop`, `harness-evolution` | the loop continuity (ejected with the harness) |

…and fills the four gaps a *fresh* repo has that those primitives don't cover on their own.

## Invocation (the simple slash command)

Type it anywhere in meta — the repo is the argument:

```
/harness:bootstrap <target-repo>            # dry-run preview (changes nothing)
/harness:bootstrap <target-repo> --apply    # execute
```

`<target-repo>` is a path or a meta member name (e.g. `network-manager`); pass-through flags
(`--apply`, `--member`, `--repo`, `--meta-root`) go straight to the script below. With no path, ask
which repo to bootstrap. This skill simply resolves the target and runs `scripts/bootstrap-repo.sh`
with the given arguments — dry-run first, then `--apply` after the owner reviews the planned mutations.

## Run

```bash
bash <harness>/skills/bootstrap/scripts/bootstrap-repo.sh <target-repo-dir> \
     [--apply] [--member NAME] [--repo GIT_URL] [--meta-root PATH]
```

**SAFE by default: dry-run.** With no `--apply` it prints every mutation it *would* make (build, file
writes, `.meta.yaml` edit) and changes nothing — review, then re-run with `--apply`. Idempotent
(safe to re-run; never clobbers existing `.handoff/`, `loop_state.md`, `backlog.md`, or CLAUDE.md
pointer). Fail-closed (a real error halts; it never fabricates kernel state).

## The six steps (and the four fresh-repo gaps they close)

0. **Ensure `hf`** — if absent, build `meta/handoff` (`cargo build --release`) and symlink the binary
   into `~/.local/bin/hf`. *(Gap 1: `handoff-loop-init` alone punts a missing `hf` to `NEEDS-HUMAN`.)*
1. **Ensure git + fleet membership** — the target must be a git repo; if its name isn't a `projects:`
   entry in `.meta.yaml`, add one (repo URL from `git remote get-url origin` or `--repo`). *(Gap 2:
   hf fleet discovery = `.meta.yaml`; a fresh repo isn't a member until it's listed.)* Backs up
   `.meta.yaml` before editing under `--apply`.
2. **Kernel init** — run `handoff-loop-init` → `hf init` builds `.handoff/{active.md,context/,packets/,
   tasks/,decisions/}` and the ledger-residency `.gitignore` guard. Does **not** `hf seed` (that's
   handoff's own backlog).
3. **Eject the harness + reconcile** — run `feature-forge/scripts/eject.sh` (skills + 4 prefixed agents
   + shared evolution/continuity + session-relay). Its file-based `.handoff/loop/` **coexists** with the
   kernel `.handoff/{tasks,packets,…}` (different subdirs — no clobber). Seeds `loop_state.md` in
   **kernel-backed pick mode**. *(Gap 3: the two state surfaces must reconcile, not collide.)*
4. **Wire CLAUDE.md / .gitignore / settings** — append the harness pointer (kernel-backed: pick via
   `hf fleet render <member>`, cycle counter in `loop_state.md`), the `.gitignore` lines, and the
   deterministic ICM session-priming hook. Leaves a **repo-invariants TODO** — the bundled invariants
   are envctl's pure-Rust set and MUST be adapted per repo. *(Gap 4.)*
5. **Seed the backlog** — `.handoff/loop/backlog.md` stub (replace with the repo's real roadmap).
5b. **Mint the backlog into hf task cards** — `hf init` leaves `.handoff/tasks/` **empty**; the loop's
   dependency-DAG / `hf fleet render` aren't real until the backlog is minted into per-member
   `handoff.task.v1` cards. The script writes a `MINT-CARDS-TODO.md` prompt; **drive the
   `feature-forge-kernel-engineer` agent** (ejected into `.claude/agents/`) to mint them via the proven
   **TASK-0044 method** — see `references/mint-cards.md` (work-order-crate `intent_lock`, per-member
   store, zero FLEET contamination; NOT `hf task mint --from-kb`). This is the "create the task cards"
   step. *(Cards are not auto-minted: it's kernel-version-specific + contamination-sensitive → agent-driven.)*
6. **Verify** — `hf status` (in the repo) + `hf fleet render <member>` (from `$META_ROOT`); report.

## Toolchain & dependency discipline (what it teaches the new repo)

A fresh repo's agent must not install toolchains/deps globally on a whim. Step 4's CLAUDE.md pointer
includes a **toolchain-location** block so the agent understands the meta model *before* installing
anything: meta-built tools resolve by **bare name on PATH** (`~/.local/bin`/`~/.cargo/bin` hold
**symlinks INTO meta**, e.g. `hf` → `$META_ROOT/handoff/target/release/hf`); workspace paths resolve
from **`$META_ROOT`** (never hardcoded); Rust deps live in the repo's `Cargo.toml` (no global
`cargo install` to satisfy a build); and **host service/process management + global toolchain installs
are out of scope** — find where a tool already lives (or build it from its meta repo + symlink, the way
`hf` is) rather than polluting global. (This is *guidance written into the repo*, not symlinks the
bootstrap creates — the harness slash-commands are already global via the plugin.)

## The loop model it sets up (kernel-backed + file cycle-counter)

A bootstrapped repo runs the **kernel-backed** forge-loop on the **per-repo-first + central-rollup**
model (ADR-0004 §3.3 rev + ADR-0052): `.handoff/` is the kernel's (built by `hf init`); the loop picks
the next dep-safe item with **`hf resume`/`hf claim`** run *in the member dir* (they read this repo's
own **per-repo `.handoff/ledger.db`** — the gitignored witnessed *source of record* — plus its cards),
and keeps `.handoff/loop/loop_state.md` for the cycle counter (the `cycle_budget`/`wrap_every`/
`last_wrapup_total`/`cycles_total` schema the batch-cadence + loop-state gate read). At every session
end the **SessionStop auto-sync hook** (`hf checkpoint --auto && hf handoff && hf sync --auto`, written
into `.claude/settings.json`) rolls this repo's new events into the central FLEET ledger. The
cross-repo board is `hf fleet render <member>` from `$META_ROOT`; the markdown sub-note path is the
fallback when hf is absent. (`HFTASK-0054`'s `--ledger`/`HANDOFF_LEDGER` override exists for rendering
against the shared/central ledger.)

## Discipline
- **Compose, don't reinvent** — drive `handoff-loop-init` and the `feature-forge` eject; never
  hand-roll a `.handoff/` (kernel-first) or re-copy what eject already copies.
- **Safe by default** — dry-run first; `--apply` only after review. Never `--force`; back up
  `.meta.yaml` before editing; never clobber existing kernel/loop state.
- **Per-repo ledger is gitignored + auto-synced** — `.handoff/ledger.db` is this repo's witnessed
  source of record: **gitignored** (only its WAL/shm/.rvf sidecars too), **never git-committed** (a
  tracked binary ledger is BANNED — `hf fleet status` flags it), and **auto-rolled** to central by the
  SessionStop `hf sync --auto` hook. `hf resume`/`hf claim` in the member dir read it directly.
- **Adapt invariants** — the ejected agent/verification invariants are envctl's; the bootstrap leaves
  a CLAUDE.md TODO so the target repo's real NON-NEGOTIABLEs get filled in before the first cycle.

## After bootstrap
`/forge-loop` to run the crew continuously over `.handoff/loop/backlog.md`; `/feature-forge` for a
single feature; `session-relay-resume`/`-wrap-up` across sessions. The repo is now a first-class
fleet member on the witnessed kernel.
