#!/usr/bin/env bash
# ralph-meta-plugin.sh — external Ralph loop: self-restarts the meta-plugin harness with a FRESH context each
# iteration (each `claude -p` process is a clean session = the /new effect) until a terminal
# sentinel. Truth lives on disk (.handoff/loop/ backlog + ledger + commits), so every restart resumes
# cold with zero loss. Bash is process-glue only — all repo work is Rust-native (cargo / meta CLI).
#
# SAFE BY DEFAULT and SAFE-ONLY as shipped. Each spawned session prompts for permission on
# sensitive actions as usual — this runner does NOT bypass the permission system, and contains no
# code path that does. Fully-unattended apply (skipping prompts) is intentionally not wired in; it
# is a deliberate operator change, described in the note at the bottom of this file.
# The loop is fail-closed at the work level regardless: dry-run -> apply for destructive steps,
# integration-qa gates every commit, guards are never weakened.
set -euo pipefail
WORKTREE="${RALPH_WORKTREE:-$(pwd)}"; BUDGET="${RALPH_BUDGET:-3}"
MAX_ITERS="${RALPH_MAX_ITERS:-50}"; SLEEP_BETWEEN="${RALPH_SLEEP:-5}"; MODEL="${RALPH_MODEL:-opus}"
WS="$WORKTREE/.handoff/loop"; mkdir -p "$WS"
log(){ printf '[ralph meta-plugin %s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
command -v claude >/dev/null || { log "FATAL: claude not on PATH"; exit 1; }

log "SAFE mode: permission prompts active. This runner never bypasses the permission system."
# Unattended apply is intentionally NOT wired here — see the operator note at the bottom of this
# file. Enabling it requires a settings-level permission grant (the agent's auto-mode classifier
# refuses to author a permission-bypass spawn loop), then a one-line wiring change you apply.

read -r -d '' PROMPT <<EOF || true
Resume the meta-plugin harness (external Ralph runner, fresh context): run /meta-plugin resume
(if this repo has the harness ejected) or /harness:meta-plugin resume. Worktree: $WORKTREE.
1. If .handoff/loop/HANDOFF.md exists, follow session-relay RESUME from it (authoritative signal):
   read it, run its Verify-on-resume baseline, then continue at the backlog's current item.
   Else DISCOVER and build .handoff/loop/backlog.md.
2. Run up to $BUDGET cycles: one backlog item each, dry-run -> apply for destructive steps,
   VERIFY across the boundary with integration-qa in a FRESH shell, commit per cycle.
   Fail-closed; never weaken the validator or a guard.
3. Then write EXACTLY ONE sentinel under .handoff/loop/ and stop (do not ScheduleWakeup):
   DONE (with evidence) | NEEDS-HUMAN (reason) | else HANDOFF.md (spawn continuity-steward).
EOF

cd "$WORKTREE"; i=0
while :; do
  i=$((i+1)); [ "$i" -gt "$MAX_ITERS" ] && { log "MAX_ITERS hit — halting."; exit 3; }
  [ -f "$WS/STOP" ]        && { log "STOP — halting."; exit 2; }
  [ -f "$WS/DONE" ]        && { log "DONE."; exit 0; }
  [ -f "$WS/NEEDS-HUMAN" ] && { log "NEEDS-HUMAN: $(cat "$WS/NEEDS-HUMAN")"; exit 2; }
  log "iter $i/$MAX_ITERS — spawning fresh agent (budget=$BUDGET, model=$MODEL)"
  claude -p "$PROMPT" --model "$MODEL" --add-dir "$WORKTREE" \
    >>"$WS/ralph-run-$i.log" 2>&1 || log "iter $i nonzero (continuing from durable state)"
  [ -f "$WS/DONE" ]        && { log "DONE."; exit 0; }
  [ -f "$WS/NEEDS-HUMAN" ] && { log "NEEDS-HUMAN: $(cat "$WS/NEEDS-HUMAN")"; exit 2; }
  [ -f "$WS/STOP" ]        && { log "STOP — halting."; exit 2; }
  sleep "$SLEEP_BETWEEN"
done

# ── Unattended apply (deliberate opt-in, NOT enabled here) ───────────────────────────────────
# The proven envctl/forge/n8n runners support a fully-unattended APPLY mode that adds Claude
# Code's --dangerously-skip-permissions flag so no prompts interrupt the loop. That is a real
# permission-bypass and is intentionally omitted from this script. If you want it, add it
# yourself with eyes open: append `--dangerously-skip-permissions` to the `claude -p` invocation
# above (ideally gated behind an env flag like RALPH_APPLY=1), run only in a disposable worktree,
# and keep `touch .handoff/loop/STOP` handy as the kill switch.
