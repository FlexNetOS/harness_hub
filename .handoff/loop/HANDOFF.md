# HANDOFF — rust-port KICKOFF (Archon → Rust)

> This is a **bootstrap kickoff packet**, not a mid-loop checkpoint. There is no running loop yet.
> A fresh session reads this and *starts* the full-parity Rust port of `meta/Archon` via
> `/harness:rust-port`. Staged in harness_hub deliberately (owner choice); the real `.handoff/loop/`
> for the port is created in the **port target repo** once the next session picks it (step 1).

closed_utc: 2026-06-13
staged_in: harness_hub (bootstrap only — not the port's home)
branch: develop
mode: INITIAL (DISCOVER) — no parity ledger exists yet
resume_command: /harness:rust-port   (then follow the steps below)

## Mission

Full-feature, **NO-DOWNGRADE** port of `~/Desktop/meta/Archon` (a TypeScript/Bun monorepo —
~510 `.ts` + ~122 `.tsx`, `packages/` + `auth-service/`) to idiomatic Rust. *No feature logic left
behind* — guaranteed structurally by the parity ledger + differential parity gate.

- **source_root:** `~/Desktop/meta/Archon`
- **source_toolchain:** `bun` (must be on PATH so the parity-verifier can RUN the source)
- **rust_target:** **TBD — this is the first decision (step 1).**

## Step 1 — decide the port target (consult the handoff harness)

The port needs a home, and the **handoff harness** (`meta/handoff`: the `hf` kernel + its
`systems-orchestrator` / `systems-conduct` knowledge of the meta-workspace architecture) is the best
source to decide *where*. Before DISCOVER:
1. Orient via the handoff kernel — `hf fleet status` and the systems map — to choose between:
   a **new sibling repo `meta/archon-rs`** (clean separation; needs `git init` + GitHub remote +
   `.meta.yaml` entry per the meta-repo rules) vs **in-place in `meta/Archon`** under a `rust/`
   workspace on a branch. Default lean: a new `archon-rs` workspace repo (a full port is large and
   deserves its own history), but let the handoff harness's architecture knowledge confirm.
2. Create/locate that repo, **eject the harness** into it:
   `bash <plugin>/harness/skills/rust-port/scripts/eject.sh <rust_target_repo>` — then the port runs
   there as `/rust-port`, with its own committed `.handoff/loop/` (the durable state moves out of
   harness_hub).
3. Seed `<rust_target>/.handoff/loop/loop_state.md` from the template with `source_root`,
   `source_toolchain=bun`, and the chosen `rust_target`.

## Step 2 — run /harness:rust-port DISCOVER (in the port repo, fresh worktree)

Per the owner workflow: a **fresh worktree off the port repo's default branch**. Then DISCOVER:
- `rust-port-cartographer` → exhaustive `.handoff/loop/parity-ledger.md` (every Archon unit + its
  contract: modules, exports, error paths, config/env, CLI, HTTP routes, auth, side effects, edge cases).
- `rust-port-architect` → `.handoff/loop/target-architecture.md` (crate layout + idiom map +
  dependency-equivalent table: e.g. the Archon web layer → axum, prisma/ORM → sqlx/sea-orm, zod →
  serde+validator; a missing equivalent ⇒ vendor/reimpl/FFI, never drop the feature).
- `build-health-auditor` → confirm the empty Rust skeleton builds → `.handoff/loop/baseline.md`.
Then ITERATE one unit/cycle (port fully → build/clippy → differential parity-verify → commit),
hand off at budget via `session-relay-wrap-up`, and close at 100% + left-behind sweep (Phase E retro).

## Verify-on-resume baseline (for THIS kickoff — fresh start)

A fresh session confirms before acting:
```bash
test -d ~/Desktop/meta/Archon && echo "Archon source present"
command -v bun  >/dev/null && echo "bun on PATH"       # source toolchain (parity needs it)
command -v cargo >/dev/null && echo "cargo on PATH"     # Rust target toolchain
```
If `bun` is absent, the parity-verifier can't run the source → that's a `NEEDS-HUMAN` wall to resolve
before porting (no differential parity = no no-downgrade guarantee).

## ICM / continuity pointers

- Recall first (the rust-port harness's `session-relay-resume` does this): `icm recall-context
  "rust-port Archon" --limit 5` and `icm recall "harness_hub decisions" -t decisions-harness_hub`.
- harness_hub catalog already lists `rust-port` (entry `entries/rust-port.md`) and `handoff`
  (`entries/handoff.md`) — read both for the harness contract + the kernel's role.
- Continuity convention: committed `.handoff/loop/HANDOFF.md` (or `hf` packet) is authoritative;
  weave is the heartbeat. Once ejected, the port repo owns its handoffs — this harness_hub kickoff is
  superseded the moment the port repo's first `.handoff/loop/HANDOFF.md` is committed.

## State of systems at handoff

- grit: no active agents / no held locks from this session.
- harness_hub: clean on `develop`; the harness plugin (factory + library) has `rust-port` ready to run/eject.
- This packet released nothing else (no running loop, fleet, or kernel cycle to close).
