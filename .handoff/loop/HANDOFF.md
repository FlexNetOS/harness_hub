# HANDOFF — harness_hub (rust-port harness development)

> Session boundary for harness-development work in `harness_hub`. A fresh session reads this and
> continues. The committed file is the authoritative resume signal; weave is the heartbeat.
> (Supersedes the prior code-research-oh-my-pi → rust-port-DISCOVER kickoff — the rust-port harness is
> now built and released; the work has moved to *using* it.)

closed_utc: 2026-06-13        branch: develop (released to master)     worktree: ~/Desktop/meta/harness_hub
orchestrator_phase: harness-development (not a parity loop — cycle/gate fields n/a)
last_item: release #28 (develop → master)   next_item: USE the harness (envctl kasetto-verify; Archon port)
gate_status: n/a   pr_url: https://github.com/FlexNetOS/harness_hub/pull/28 (merged)

## Where things stand

The **rust-port packaged harness is mature and RELEASED to `master` at plugin v1.10.1.** It is now a
full-feature, no-downgrade **port-and-merge** harness: 10 agents, 12 skills, 3-model tiered
(opus gates / sonnet workers / haiku mechanical), two-layer ICM memory, ejectable. Tree clean.

landed_this_session (all auto-merged to develop, then promoted via release #28 → master):
  - #21 detailed **symbol mapping** (per-symbol map + rollup + two-grain sweep) + agent-runtime porting + per-agent runtime contract table  (v1.6.0→1.7.0)
  - #22 `/verify` bug fix **`git kb index` → `git kb code index`** (would wall every port at DISCOVER) + symbol-map sharding + Y-runnable baseline  (→1.7.1)
  - #24 **port-and-MERGE arc** (ADR-0001 `rust-port→rust-port-merge`) + research/cross-repo agents + automated **3-model workflow**  (→1.8.0)
  - #25 **merge hardening** — 9 gaps incl. **bidirectional no-downgrade** (don't regress Y), Y worktree/branch/PR, atomic rollback, up-front reuse-classification, Y-drift  (→1.9.0)
  - #26 shared **`icm-memory` skill** (recall/store as needed — runtime-delegated, NOT hard-wired hooks)  (→1.10.0)
  - #27 eject prints a **`SessionStart` recall-hook** (deterministic pre-session priming)  (→1.10.1)

## NEXT — the work has moved to USING the harness (owner is driving)

### ▶ envctl — kasetto→envctl merge AUDIT (owner is doing this now: "i got it from here")
Use the harness in **verify mode** to confirm the existing kasetto rust merge in envctl was done right.
- Eject: `bash ~/Desktop/meta/harness_hub/harness/skills/rust-port/scripts/eject.sh ~/Desktop/meta/envctl`
- Seed `envctl/.handoff/loop/loop_state.md`: `source_root=~/Desktop/meta/kasetto` (Rust, `source_toolchain=cargo`),
  `rust_target`/`dest_repo`=envctl (kasetto referenced in `crates/engine/src/{runtime,lock}.rs` + `cli/main.rs`).
- Mode: every unit classifies **`reuse-Y`** (already in envctl) → skip porting → **differentially verify
  envctl-against-kasetto** + two-grain left-behind sweep + the dual gate (kasetto preserved AND envctl not regressed).
- Run: `/rust-port` (DISCOVER → audit) or the SAFE runner `ralph-rust-port.sh`.

### ▶ harness-agent-rs — Archon → Rust port (PENDING)
- harness-agent-rs has a **STALE ejected harness** (8 skills, pre-merge) + a committed kickoff
  (`harness-agent-rs/.handoff/loop/HANDOFF.md`). **Re-eject v1.10.1 first** (gains merge/cross-repo/
  3-model/icm-memory) before running.
- source=`~/Desktop/meta/Archon` (TS/Bun, **current v0.4.x only**, exclude 3 legacy versions), rust_target=harness-agent-rs.
- **Prereq (ADR-0001):** a `/harness:code-research` pass on `~/Desktop/meta/oh-my-pi` to settle whether it
  supplies the agent run-loop Archon delegates — resolve before locking the loop strategy.

decisions_and_dead_ends:
  - Capability = a runtime-delegated **skill**, never forced per-agent hooks (owner: hooks reduce agent ability; lead delegates at runtime).
  - **Pre-session recall hooks > stop hooks** (a missed recall blinds the whole session; a missed store loses one recoverable fact).
  - Don't over-ask scoping / don't over-engineer (owner corrected twice) — make the harness flexible, let runtime delegation drive.
  - 3-model tiering is safe because every no-downgrade **gate stays opus** (a tiered worker's downgrade is caught by the opus parity gate).

icm_stored: `decisions-harness_hub`, `preferences` (capability-as-skill), `errors-resolved` (git kb code index), `context-harness_hub` (this wrap)
findings: none in `.handoff/loop/findings/` (harness-dev session; per-PR evidence is in the merged PRs + `harness/LESSONS.md`)
verify_on_resume:
```bash
cd ~/Desktop/meta/harness_hub && bash scripts/validate.sh          # expect: ✓ 7 entries valid
git show origin/master:harness/.claude-plugin/plugin.json | grep version   # expect: 1.10.1
```
resume_command: /session-relay-resume from .handoff/loop/HANDOFF.md
