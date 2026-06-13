# HANDOFF — harness_hub session (harness development)

> Session boundary for the harness-development work in `harness_hub`. A fresh session reads this and
> continues the agreed plan. The committed file is the authoritative resume signal; weave is the
> heartbeat. (Supersedes the earlier rust-port kickoff — that port now lives in `harness-agent-rs`.)

closed_utc: 2026-06-13
repo: harness_hub
branch: develop
resume_command: /session-relay-resume from .handoff/loop/HANDOFF.md

## Where things stand

The packaged-harness library is mature. `harness_hub` catalog = **7 entries**; the `harness` plugin is
**factory + library** (`/harness:harness` builds; `/harness:<name>` runs). Shipped this session:
`code-research` harness, the Archon code-research verdict, **ADR-0001 (harness-agent-rs)**, the new
**`FlexNetOS/harness-agent-rs`** repo (scaffold + rust-port harness ejected + port kickoff, registered
in meta `.meta.yaml`), and the continuity primitives `session-relay-wrap-up`/`-resume` +
`harness-loop-init`. Tree clean on `develop`.

**Decision of record (ADR-0001):** Archon **is** an agent-harness manager (DAG workflow-run
orchestrator over external agent SDKs; delegates the LLM loop). Build `harness-agent-rs` by porting
Archon's runtime *design* + mapping subsystems onto `hf`/`weave`/`grit`/`icm`; keep the markdown
builder as-is; **port the current v0.4.x architecture only** (Archon has 3 uncleaned legacy versions).

## NEXT — do these in order (owner-sequenced)

### ▶ STEP 1 (do FIRST): code-research `oh-my-pi`  — close ADR-0001's open fork
Run **`/harness:code-research`** against `~/Desktop/meta/oh-my-pi`, question:
*"Does oh-my-pi provide the agent run-loop / IDE layer that Archon delegates to provider SDKs — and
should harness-agent-rs reuse/merge it, or build the loop fresh?"*
- Why first: ADR-0001 delegated the agent loop to provider CLIs but flagged that oh-my-pi (a Rust/Bun
  coding-agent runtime) may already supply that loop. This is the one unverified assumption that could
  change the port's shape — settle it with evidence **before** committing port effort.
- Output: a decision-grade verdict + a recommendation (reuse oh-my-pi's loop / merge / build fresh),
  feeding a short addendum to ADR-0001.

### ▶ STEP 2 (then): `/rust-port` DISCOVER in `harness-agent-rs`
In a **fresh worktree off `harness-agent-rs` main**, run **`/rust-port`** (its kickoff is committed at
`harness-agent-rs/.handoff/loop/HANDOFF.md`):
- DISCOVER step 1 = **cartographer disambiguates current-vs-legacy** Archon (3 old versions OUT of
  scope) → parity ledger over the v0.4.x runtime.
- architect → crate layout + the substrate-mapping table (ledger→hf, coord→weave+grit, memory→icm,
  agent-loop per STEP 1's verdict).
- Then ITERATE one unit/cycle (full port → build/clippy → differential parity-verify → commit).

## Landed this session (pointers)
- harness_hub PRs: #14 (code-research harness), #16 (ADR-0001), this PR (harness-loop-init + handoff),
  plus earlier #3/#5/#7/#8/#9/#10/#11/#12/#13.
- New repo: github.com/FlexNetOS/harness-agent-rs (main, scaffold + ejected rust-port + kickoff).
- meta PR #30: registered harness-agent-rs in `.meta.yaml` + `.gitignore`.

## ICM / continuity pointers
- Recall first (session-relay-resume does this): `icm recall-context "harness-agent-rs Archon oh-my-pi" --limit 5`;
  `icm recall "Archon verdict" -t decisions-harness_hub`; `icm recall "" -t decisions-harness_hub` (ADR-0001).
- Authoritative docs: `docs/adr/0001-harness-agent-rs.md`; `entries/code-research.md`,
  `entries/rust-port.md`; `harness-agent-rs/.handoff/loop/HANDOFF.md` (the port kickoff).

## Verify-on-resume baseline
```bash
cd ~/Desktop/meta/harness_hub && bash scripts/validate.sh        # catalog green (7 entries)
cargo build --quiet --manifest-path ~/Desktop/meta/harness-agent-rs/Cargo.toml  # skeleton builds
command -v bun >/dev/null && echo "bun on PATH"  # needed by code-research (run oh-my-pi) + rust-port parity
```

## Decisions & dead-ends (don't re-litigate)
- Archon's label was contested (workflow-engine vs manager) — RESOLVED by the verifier: it's an agent
  *harness manager* that delegates the loop. Don't reopen.
- harness-agent-rs is named for the goal (not `archon-rs`): it ports Archon's design AND maps onto the
  substrates — not a 1:1 clone.
- Unattended-apply for the ralph runners stays SAFE-only unless the owner adds a settings Bash rule.
