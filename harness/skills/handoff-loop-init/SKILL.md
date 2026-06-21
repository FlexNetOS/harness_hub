---
name: handoff-loop-init
description: >-
  All-in-one initializer that upgrades, syncs, and deploys the FULL .handoff continuity-kernel into
  ANY repo (or the whole fleet) from one command, by DRIVING the portable `hf` kernel (kernel-first;
  never hand-rolls kernel artifacts). ALWAYS use on "init the handoff kernel", "build .handoff", "set
  up the continuity kernel", "handoff loop init", "hf init here", "onboard a repo to the kernel",
  "upgrade .handoff", "full .handoff buildout". The all-in-one driver (`handoff-loop-init.sh`):
  ensures the redb (no-C) `hf`, runs portable `hf init`-or-upgrade (repo self-identifies, handoff
  PR #81), installs the `.gitignore` residency + redb-migration-artifact guards, runs a FAIL-CLOSED
  legacy-SQLite→redb `hf migrate` on provably-quiescent repos only (out-of-tree backup, handoff
  PR #114), deploys the SessionStart/SessionEnd auto-loop hooks, and verifies `hf resume`+`hf drift`.
  Per-repo + `--fleet`, idempotent, `--dry-run`. A minimal init-only path (`init-handoff-kernel.sh`)
  remains for just `hf init` + guard + status. Fail-closed if `hf` is absent (the kernel is the only
  way to build the kernel). The kernel-backed counterpart to the file-based `harness-loop-init`.
---

# handoff-loop-init — one command, fully-deployed `.handoff` continuity

This is the **all-in-one initializer** for the Continuity Ledger Kernel: where `handoff-loop-run`
*advances* a repo that already has `.handoff`, this **gets a repo to that state** and keeps it
current — idempotent, fail-closed, and from a single invocation. It wraps the kernel primitives
(`hf init`, `hf migrate`, the residency guards, the auto-loop hooks) so the user never chains them.

## Run — the all-in-one driver (recommended)

```bash
# current repo (default)
bash <harness>/skills/handoff-loop-init/scripts/handoff-loop-init.sh

# a specific repo, staging the git-text
bash <harness>/skills/handoff-loop-init/scripts/handoff-loop-init.sh /path/to/repo --commit

# the whole fleet (additive steps everywhere; the migrate step self-defers on any busy repo)
bash <harness>/skills/handoff-loop-init/scripts/handoff-loop-init.sh --fleet --dry-run
```

What it does, idempotent and in order: (1) ensure the redb no-C `hf` (rebuild+install from the
handoff kernel ONLY if PATH `hf` is missing or links `libsqlite`; if no kernel source is reachable
when ejected, it fails closed with a NEEDS-HUMAN install hint rather than guessing); (2) portable
`hf init`-or-upgrade (repo self-identifies; existing capsule/cards preserved); (3) `.gitignore`
residency guards **plus** the redb-cutover migration-artifact guards (`*.sqlite.bak`/`*.redb.tmp`);
(4) **fail-closed** legacy-SQLite→redb `hf migrate` — only on a provably-quiescent repo (no running
`hf`/`cargo`/`grit`, no active grit worktree, no held lease lock, ledger not written in the last
120 s), else DEFERRED and reported; the backup is written **out-of-tree** (handoff PR #114), never
inside the tracked `.handoff/` tree; (5) deploy the SessionStart/SessionEnd auto-loop hooks (merged
into `.claude/settings.json`, existing keys preserved); (6) verify `hf resume` + `hf drift`. Flags:
`--commit`/`--push`, `--no-migrate`, `--no-hooks`, `--build-hf`, `--dry-run` (always offer `--dry-run`
first for a `--fleet` run).

The driver sources `handoff-lib.sh` (the canonical residency-guard + quiescence helpers) — both are
vendored beside this skill so `/harness:handoff-loop-init` is self-contained when ejected.

# handoff-loop-init — build the full `.handoff` kernel (via portable `hf init`)

Stands up a repo's **Continuity Ledger Kernel** — the full `.handoff/` buildout — so the repo can run
the witnessed handoff protocol (ADR-0004 / P7.36). It does this the *only* compliant way: by
**driving the `hf` kernel binary**. It never hand-writes ledger/packet/capsule/policy files — those
are the kernel's to render from the witnessed ledger (hard rule: a hand-written packet is never
authoritative over Git/ledger/cards).

**`hf init` is portable (handoff PR #81).** Run it in *any* repo and it does the right thing on its
own: the capsule identifies the repo **as itself** (`project_name` from the git toplevel; a neutral
`(seed me)` northstar — never the handoff kernel's identity or doctrine), it writes the Tier-A
`README.md` and the `.handoff/**/ledger.db` `.gitignore` residency guard so the repo passes
`hf fleet status` immediately, and it is **idempotent + non-destructive** (an existing/curated capsule
is preserved). Only in the handoff kernel home itself — detected by the keystone ADR
(`docs/adr-0001-flexnetos-autopilot-keystone.md`), which is worktree-safe — does it write the full
kernel doctrine. So this skill is now a thin wrapper: drive `hf init`, verify the guard, report status.

This is the **kernel-backed** init. Its file-based sibling, `harness-loop-init`, lays down only a
minimal `.handoff/loop/` for harnesses that don't use the kernel. Use *this* one when the repo should
run on the real kernel.

## What `hf init` builds (the core)

```
.handoff/
├── active.md               # current focus pointer
├── README.md               # the Tier-A one-screen contract (members only)
├── context/capsule.json    # the context capsule — identifies THIS repo (name/role/plane/northstar)
├── packets/                # rendered handoff packets (hf renders these — never hand-write)
├── tasks/                  # task cards (HFTASK-*.task.json)
├── decisions/              # ADRs
└── ledger.db               # the witnessed ledger (LOCAL — gitignored by the guard hf init writes)
```
The richer structure a mature kernel repo grows (`fleet/`, `hooks/`, `policies/`+`policy.toml`,
`skills/`) is populated by the kernel as it's used (`hf session`, `hf fleet render`, policy setup) —
not fabricated here.

## Run

The simplest path is just `hf init` in your repo — the script below adds the fail-closed checks,
the residency-guard verification, and `hf status` reporting around it:

```bash
# zero-config — the repo identifies as itself:
bash <harness>/skills/handoff-loop-init/scripts/init-handoff-kernel.sh

# another repo, or describe it in one go (flags forwarded to `hf init`):
bash <harness>/skills/handoff-loop-init/scripts/init-handoff-kernel.sh /path/to/repo
bash <harness>/skills/handoff-loop-init/scripts/init-handoff-kernel.sh . \
     --name "weave (A2A bus)" --role tool --plane execution \
     --northstar "the repo's guiding goal"
```

The first non-flag argument is the TARGET dir (default: cwd); everything else (or anything after a
literal `--`) is forwarded verbatim to `hf init`. The script (idempotent, fail-closed):
1. **Requires `hf` on PATH** — if absent, writes guidance and exits non-zero. You cannot build the
   kernel without the kernel; installing `hf` (from `meta/handoff`) is a human step → `NEEDS-HUMAN`.
2. Requires the target to be a git repo (the kernel is Git-anchored).
3. Runs **portable `hf init`** (forwarding any flags). This is safe whether or not `.handoff/` exists —
   `hf init` is idempotent and preserves a curated capsule ("capsule preserved").
4. **Verifies the ledger-residency guard** that `hf init` writes (`git check-ignore .handoff/ledger.db`).
   If an *older* `hf` (pre-PR #81) didn't write it, the script adds the canonical
   `.handoff/**/ledger.db` (+ wal/shm) block as a fallback so the repo is P7-conformant regardless.
   Commits nothing — leaves staging to you.
5. Reports `hf status`.

**Does NOT run `hf seed`** — seed injects the *handoff repo's own* HFTASK backlog; in any other repo
that's wrong. Seed a repo's real work with `hf task mint --from-kb <slug>` or the repo's own intake.

## After init — the kernel protocol (don't bypass it)

`hf resume` (first command each session) → navigate `active.md` → `context/capsule.json` →
`packets/latest.md` → `tasks/`/`decisions/`. Claim before editing (`hf claim`), stay in scope,
`hf checkpoint` + `hf drift` + `hf policy check-handoff` + `hf handoff` before stopping. The
`handoff-loop-run` skill (or the canonical `handoff-loop` in `meta/handoff`, also vendored at
`harness_hub/handoff-loop/`) drives this loop; `session-relay-resume`/`-wrap-up` integrate it with ICM + weave.

## Discipline
- **Kernel-first, never hand-rolled.** Build via `hf`; if it's not installed, stop (`NEEDS-HUMAN`) —
  do not fabricate a fake `.handoff/`.
- **Ledger residency** — `.handoff/ledger.db` is local + gitignored; the witnessed/fleet state is the
  kernel's, not a committed per-repo db.
- **Idempotent + non-destructive** — safe to re-run to confirm; `hf init` preserves an existing
  capsule/README and never clobbers an existing kernel.
- **Own identity, never the kernel's** — a member's capsule describes *that* repo with a neutral
  `(seed me)` northstar. Edit `context/capsule.json` (or pass `--northstar`/`--role`/`--plane`) to
  seed the real goal; never copy handoff's doctrine into a member.
