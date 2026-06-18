#!/usr/bin/env bash
# ralph-feature-forge.sh — external Ralph loop: self-restarts the feature-forge harness with a FRESH
# context each iteration (each `claude -p` = a clean session) until a terminal sentinel. Truth lives on
# disk (.handoff/loop/ backlog + loop_state + commits), so every restart resumes cold with zero loss.
#
# This is the generic feature-forge analog of envctl's scripts/ralph-provision.sh — it drives the
# /forge-loop Ralph loop instead of envctl's provisioning loop.
#
# SAFE BY DEFAULT and SAFE-ONLY as shipped: each spawned session prompts for permission as usual;
# this runner contains no permission-system bypass. Unattended apply is a deliberate operator change
# authorized at the settings layer (the agent's `.claude/settings.json`), never by this script.
set -euo pipefail
WORKTREE="${RALPH_WORKTREE:-$(pwd)}"; BUDGET="${RALPH_BUDGET:-3}"
MAX_ITERS="${RALPH_MAX_ITERS:-100}"; SLEEP_BETWEEN="${RALPH_SLEEP:-5}"; MODEL="${RALPH_MODEL:-opus}"
WS="$WORKTREE/.handoff/loop"; mkdir -p "$WS"
log(){ printf '[ralph feature-forge %s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
command -v claude >/dev/null || { log "FATAL: claude not on PATH"; exit 1; }
log "SAFE mode: permission prompts active. This runner never bypasses the permission system."

read -r -d '' PROMPT <<EOP || true
Resume the feature-forge harness (external Ralph runner, fresh context): run /forge-loop resume
(if ejected here) or /harness:feature-forge resume. Worktree: $WORKTREE. Cycle budget: $BUDGET.
1. If .handoff/loop/HANDOFF.md exists, follow session-relay-resume (authoritative): read it, run the
   verify-on-resume baseline, re-poll any in_flight_pr (promote -[~]->-[x] once MERGED), then continue
   the loop at the next undone backlog item. Else read .handoff/loop/backlog.md and start the loop.
2. Run up to $BUDGET cycles: one backlog item each via architect -> implementer -> guardian (Phase 3.5
   runtime-verify included). Commit + one PR per cycle. TICK-ON-MERGED only — never tick -[x] before
   the PR is MERGED. NEVER weaken a gate to force a pass; a downgrade never passes the guardian.
3. At the cycle budget run session-relay-wrap-up (Phase-E retro + checkpoint), then write EXACTLY ONE
   sentinel under .handoff/loop/ and stop (no ScheduleWakeup):
   DONE (completion confirmed + left-behind sweep clean) | NEEDS-HUMAN (reason) | else HANDOFF.md.
EOP

cd "$WORKTREE"; i=0
while :; do
  i=$((i+1)); [ "$i" -gt "$MAX_ITERS" ] && { log "MAX_ITERS hit — halting."; exit 3; }
  for s in STOP DONE NEEDS-HUMAN; do [ -f "$WS/$s" ] && { log "$s — halting."; [ "$s" = DONE ] && exit 0 || exit 2; }; done
  log "iter $i/$MAX_ITERS — spawning fresh agent (budget=$BUDGET, model=$MODEL)"
  claude -p "$PROMPT" --model "$MODEL" --add-dir "$WORKTREE" \
    >>"$WS/ralph-run-$i.log" 2>&1 || log "iter $i nonzero (continuing from durable state)"
  for s in DONE NEEDS-HUMAN STOP; do [ -f "$WS/$s" ] && { log "$s."; [ "$s" = DONE ] && exit 0 || exit 2; }; done
  sleep "$SLEEP_BETWEEN"
done
