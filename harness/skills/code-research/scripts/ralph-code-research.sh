#!/usr/bin/env bash
# ralph-code-research.sh — external Ralph loop: self-restarts the code-research harness with a FRESH
# context each iteration until a terminal sentinel. Read-only analysis; durable findings ledger under
# .handoff/loop/, so every restart resumes cold. SAFE by default: no permission-system bypass.
set -euo pipefail
WORKTREE="${RALPH_WORKTREE:-$(pwd)}"; BUDGET="${RALPH_BUDGET:-3}"
MAX_ITERS="${RALPH_MAX_ITERS:-50}"; SLEEP_BETWEEN="${RALPH_SLEEP:-5}"; MODEL="${RALPH_MODEL:-opus}"
WS="$WORKTREE/.handoff/loop"; mkdir -p "$WS"
log(){ printf '[ralph code-research %s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
command -v claude >/dev/null || { log "FATAL: claude not on PATH"; exit 1; }
log "SAFE mode: read-only analysis; permission prompts active; no permission-system bypass."

read -r -d '' PROMPT <<EOP || true
Resume the code-research harness (external Ralph runner, fresh context): run /code-research resume
(if ejected here) or /harness:code-research resume. Worktree: $WORKTREE.
1. If .handoff/loop/HANDOFF.md exists, follow session-relay-resume (authoritative): read it, run
   verify-on-resume, continue at the research-ledger's next dimension. Else MAP: codemap + dimensions.
2. Run up to $BUDGET cycles: analyze a dimension (cited claims) -> adversarially VERIFY claims vs the
   code (refute; run where ambiguous) -> only CONFIRMED/QUALIFIED survive. Commit findings per cycle.
   Never let an unverified claim into the report.
3. Then write EXACTLY ONE sentinel under .handoff/loop/ and stop (no ScheduleWakeup):
   DONE (completeness sweep clean + report answers the question) | NEEDS-HUMAN (reason) | else HANDOFF.md.
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
