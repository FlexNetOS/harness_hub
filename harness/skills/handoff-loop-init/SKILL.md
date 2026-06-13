---
name: handoff-loop-init
description: >-
  Builds the FULL .handoff continuity-kernel buildout in a repo by DRIVING the `hf` kernel (kernel-
  first; never hand-rolls kernel artifacts). ALWAYS use on "init the handoff kernel", "build .handoff",
  "set up the continuity kernel", "handoff loop init", "hf init here", "full .handoff buildout". Runs
  `hf init` (ledger + context/capsule + packets + tasks + decisions), sets the ledger-residency
  .gitignore guard, and reports `hf status`. Idempotent; fail-closed if `hf` is absent (the kernel is
  the only way to build the kernel). The kernel-backed counterpart to the file-based `harness-loop-init`.
---

# handoff-loop-init — build the full `.handoff` kernel (via `hf`)

Stands up a repo's **Continuity Ledger Kernel** — the full `.handoff/` buildout — so the repo can run
the witnessed handoff protocol (ADR-0004 / P7.36). It does this the *only* compliant way: by
**driving the `hf` kernel binary**. It never hand-writes ledger/packet/capsule/policy files — those
are the kernel's to render from the witnessed ledger (hard rule: a hand-written packet is never
authoritative over Git/ledger/cards).

This is the **kernel-backed** init. Its file-based sibling, `harness-loop-init`, lays down only a
minimal `.handoff/loop/` for harnesses that don't use the kernel. Use *this* one when the repo should
run on the real kernel.

## What `hf init` builds (the core)

```
.handoff/
├── active.md               # current focus pointer
├── context/capsule.json    # the context capsule
├── packets/                # rendered handoff packets (hf renders these — never hand-write)
├── tasks/                  # task cards (HFTASK-*.task.json)
├── decisions/              # ADRs
└── ledger.db               # the witnessed ledger (LOCAL — gitignored per the residency rule)
```
The richer structure a mature kernel repo grows (`fleet/`, `hooks/`, `policies/`+`policy.toml`,
`skills/`) is populated by the kernel as it's used (`hf session`, `hf fleet render`, policy setup) —
not fabricated here.

## Run

```bash
bash <harness>/skills/handoff-loop-init/scripts/init-handoff-kernel.sh [TARGET_DIR]
```
The script (idempotent, fail-closed):
1. **Requires `hf` on PATH** — if absent, writes guidance and exits non-zero. You cannot build the
   kernel without the kernel; installing `hf` (from `meta/handoff`) is a human step → `NEEDS-HUMAN`.
2. Requires the target to be a git repo (the kernel is Git-anchored).
3. If `.handoff/` already exists → idempotent: reports + `hf status`, does **not** re-init or clobber.
4. Else runs **`hf init`** (core buildout).
5. Sets the **ledger-residency guard** — ensures `.gitignore` carries `.handoff/ledger.db` +
   `.handoff/*.db` (P7 rule: no per-repo `*.db` committed; the ledger is local, the FLEET ledger is
   central). Commits nothing — leaves staging to you.
6. Reports `hf status`.

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
- **Idempotent** — safe to re-run to confirm; never clobbers an existing kernel.
