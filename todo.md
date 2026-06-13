# harness_hub — session TODO (markdown fallback)

> No `hf` / `.handoff/` kernel in this repo yet, so remaining work is tracked here instead of a
> witnessed handoff packet. When the handoff kernel lands (see TASK-2), migrate this into
> `.handoff/loop/` per ADR-0004 / policy P7.36.

Updated: 2026-06-13

## Open

- [ ] **TASK-1 — Wire unattended apply into the meta-plugin runner (OPERATOR-MANUAL).**
  Blocked for the agent: Claude Code's auto-mode classifier refuses to author an unattended
  `--dangerously-skip-permissions` spawn loop, and states chat authorization cannot override it.
  The owner must make these two changes by hand:
  1. Create `harness_hub/.claude/settings.json` (gitignored, local-only authorization):
     ```json
     { "permissions": { "allow": [
       "Bash(bash harness/skills/meta-plugin/scripts/ralph-meta-plugin.sh*)"
     ] } }
     ```
  2. In `harness/skills/meta-plugin/scripts/ralph-meta-plugin.sh`, replace the SAFE-only `log`
     line after the `command -v claude` check with an env-gated apply block, and add
     `"${APPLY_ARGS[@]}"` to the `claude -p` spawn line:
     ```bash
     APPLY_ARGS=()
     if [ "${RALPH_APPLY:-0}" = "1" ]; then
       APPLY_ARGS=(--dangerously-skip-permissions)
       log "APPLY MODE — unattended; prompts bypassed. kill switch: touch $WS/STOP"
     else
       log "SAFE mode (default): prompts active. Set RALPH_APPLY=1 for unattended apply."
     fi
     # ...
     claude -p "$PROMPT" --model "$MODEL" --add-dir "$WORKTREE" "${APPLY_ARGS[@]}" \
       >>"$WS/ralph-run-$i.log" 2>&1 || log "iter $i nonzero (continuing from durable state)"
     ```
  Launch: `RALPH_APPLY=1 bash harness/skills/meta-plugin/scripts/ralph-meta-plugin.sh`
  (disposable worktree only; `touch .handoff/loop/STOP` is the kill switch).
  Work-level safeguards remain: integration-qa gates every commit, dry-run→apply, guards never weakened.

- [ ] **TASK-2 — Deepen `hf` kernel integration (when `hf` is on PATH / `.handoff/` exists).**
  The meta-plugin orchestrator + session-relay already say "prefer `hf` verbs (checkpoint/handoff/
  resume) when reachable, file-based fallback." Once the kernel is present, replace the file-based
  HANDOFF/checkpoint steps with `hf` verbs and migrate `todo.md` → `.handoff/loop/`.

- [ ] **TASK-3 (optional) — Commit a ready-to-paste `docs/unattended-apply.md`** so the manual
  enable steps travel with the harness in git (the agent can write the *doc*, just not wire the
  live flag).

## Done this session (shipped in PR #3 → develop, CI green)

- [x] Built the meta-plugin packaged harness (5 agents, 5 skills, orchestrator, SAFE runner, eject).
- [x] Packaged-harness library model + `docs/packaged-harness-standard.md`; plugin 1.2.0→1.3.0.
- [x] Rust-native validator (`hub-validate` crate + `scripts/validate.sh`); deleted `validate.py`; CI rewired.
- [x] Migrated harness durable state `_workspace/` → `.handoff/loop/` per ADR-0004 / P7.36.
- [x] Catalog row + `entries/meta-plugin.md`; README + schema updated; `validate.sh` green (CI SUCCESS).
