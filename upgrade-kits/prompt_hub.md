# Harness Upgrade — prompt_hub (tailoring sheet)

Follow the generic kit: `~/Desktop/meta/HARNESS-UPGRADE-KIT.md` (or `./_GENERIC.md`).
This sheet fills in the `<…>` placeholders for **prompt_hub**. No loop harness exists yet —
build all 6 deliverables from scratch.

| Field | Value |
|-------|-------|
| Repo / path | `FlexNetOS/prompt_hub` · `~/Desktop/meta/prompt_hub` |
| Language | Rust (16-crate Cargo workspace), `just`-driven |
| CLI | `prompthub` (`just cli <args>` = `cargo run --bin prompthub -- <args>`) |
| Existing harness | **none** — this is a greenfield harness build |
| Loop name `<loop>` | `prompt-loop` |
| Runner | `.claude/skills/prompt-loop/scripts/ralph-prompt.sh` · opt-in env `PROMPT_APPLY=1` |
| Resume command | `/prompt-loop resume from _workspace/HANDOFF.md` |

**DISCOVER (build the backlog from real state):** read `docs/`/ROADMAP + open issues + `just`
targets; enumerate the per-crate work / prompt-library gaps. One backlog item = one cohesive
unit of work (a crate feature, a prompt set, a fix).

**VERIFY per cycle (cross-boundary, not existence-only):**
```bash
just test          # cargo test --workspace --all-features
just lint          # cargo clippy --workspace --all-features -- -D warnings
```

**DONE criteria (all pass → write `_workspace/DONE` with evidence):**
```bash
cargo build --workspace --all-features
just test          # green
just lint          # zero warnings (clippy -D warnings)
just fmt           # cargo fmt --all  (then: git diff --quiet)
```
Plus: backlog has no `- [ ]`; blocked items surfaced with reasons.

**Repo-specific guardrails:** prompt_hub is **rust-native by mandate** — treat any non-Cargo
build/test presented as canonical, foreign-language code, or `async_trait`/`unsafe`/panic-as-error
drift as a defect to fix, not accept (see its CLAUDE.md "Detect drift"). Feature-gated code needs
`--all-features` to compile/test. For a code loop, "apply" = commit/PR (no system mutation), so the
safe-vs-`PROMPT_APPLY` distinction maps to *whether the unattended runner may push/open PRs*.
