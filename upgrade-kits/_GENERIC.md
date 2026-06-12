# Harness Upgrade Kit v2 — autonomous, resumable, self-restarting operation

Hand this whole file to a session working in another repo. It tells that session how to
upgrade *its* repo's harness to the same pattern proven in `envctl`: a **Ralph loop** that
works a durable on-disk backlog one item per cycle, **hands off to a fresh session** at a
cycle budget, and can run **fully unattended** by self-restarting with a clean context every
cycle. Truth lives on disk (backlog + checkpoints + commits), so any restart resumes cold
with **zero loss**.

> **v2 (2026-06-12, ADR-0004):** durable loop state moved from `_workspace/` to
> **`.handoff/loop/`** — `_workspace/` is a deprecated rival convention (policy P7.36).
> When the meta workspace kernel is reachable, the file protocol below is the *fallback*:
> prefer **minted cards** over `backlog.md` (`hf task mint`), **witnessed checkpoints**
> over ledger prose (`hf checkpoint`), and **rendered packets** over hand-written
> `HANDOFF.md` (`hf handoff`). Existing `_workspace/` dirs keep their history — migrate
> opportunistically, never bulk-delete.

It is repo-agnostic. Replace every `<…>` placeholder with your repo's specifics.

---

## 0) Paste-this prompt (give this to the target session verbatim)

> Upgrade this repo's harness to the autonomous-operation pattern in
> `~/Desktop/meta/HARNESS-UPGRADE-KIT.md` (v2). Read that file, then, **in a fresh git
> worktree** (never on dirty `master`), create the deliverables in §3 adapted to THIS repo:
> a durable `.handoff/loop/` state dir, a loop skill, a `session-relay` skill, a
> `continuity-steward` agent, a `/<loop> resume` slash command, and the external `/new`
> runner script. If this repo lives in the meta workspace, wire backlog/checkpoint/handoff
> to the `hf` kernel verbs first and use the file protocol only as fallback. Match the
> acceptance targets in §4. Keep the harness hand-authored and git-tracked. Don't invent a
> CLI you don't have — wire the loop to whatever commands actually drive your repo. Report
> back with the file list + one happy-path and one error-path dry run.

---

## 1) The core idea (why this shape)

A single long session **rots** (context fills, quality drops) and **burns tokens**. The
defense is to run the work as a **chain of short sessions**, each handing a durable
checkpoint to the next. Two layers:

- **In-session loop** (`<loop>` skill): work one backlog item per cycle, commit, self-pace.
  At a per-session **cycle budget**, hand off.
- **External self-restart** (the `/new` upgrade): an agent *cannot type `/new`* (it's a REPL
  command, not a tool) — **but a new process is a clean context**. A bundled shell loop spawns
  a fresh `claude -p "<resume prompt>"` each iteration. Each fresh agent does one budget of
  work, writes **exactly one sentinel**, and exits; the runner respawns until a terminal
  sentinel. That is the honest, executable form of "run `/new` then continue, handed off to
  yourself."

## 2) Non-negotiable principles

1. **Write state down every cycle.** Never hold the plan only in context.
2. **Durable state on disk** under `.handoff/loop/` (backlog + ledger + checkpoint) —
   git-committed **text only**; binary state never enters git (the beads lesson). The
   witnessed event ledger stays central (`handoff/.handoff/ledger.db`), not per-repo.
3. **One item per cycle; commit per cycle** (area-prefixed subject). A fresh process must be
   able to resume from committed state alone.
4. **The committed `.handoff/loop/HANDOFF.md` is the authoritative resume signal** — *not*
   the weave inbox. (Verified gotcha: a message addressed to your own identity does **not**
   land in your own inbox, and a same-machine successor inherits the same identity. weave is
   an *observable heartbeat* via `to:"all"`, not the payload.) With kernel access, `hf
   handoff` + `hf resume` replace the file as the packet of record.
5. **Fail-closed.** Destructive/irreversible ops are **dry-run first + opt-in**; never weaken
   a guard to make a step pass.
6. **Human walls STOP the loop** (sudo / interactive auth / reboot / hardware you can't drive)
   — mark `NEEDS-HUMAN` with the reason and halt; don't spin or force.
7. **Safe by default.** Unattended *apply* is a deliberate opt-in flag, never the default.
8. **Bounded.** A max-iterations backstop + an always-checked `STOP` kill switch.

## 3) Deliverables (create these in YOUR repo)

**A. Durable state — `.handoff/loop/`**
- `backlog.md` — the single source of truth *when the kernel is unreachable*. Ordered
  checklist, one item per gap. Legend: `- [ ]` todo · `- [x]` done+verified ·
  `- [!] blocked: <reason>`. **Kernel available → backlog = minted cards**
  (`hf task mint --from-kb <slug>`; status via `hf status`).
- `loop_state.md` — the cycle ledger (schema in §5).
- At runtime: `HANDOFF.md` and the sentinels (§6). `.gitignore` the per-run `*.log` files;
  **commit** `backlog.md` + `loop_state.md` + `HANDOFF.md` every cycle.
- Your repo's `.handoff/context/capsule.json` (seeded by the P7 rollout) should keep its
  `next_command` pointing at the loop's resume entry point.

**B. Loop skill — `.claude/skills/<loop>/SKILL.md`**
The in-session body:
1. **DISCOVER** real state (don't hallucinate) → write `backlog.md`, seed `loop_state.md`.
2. **One iteration:** read state → stop-checks (no `- [ ]` left → DONE; `cycles_this_session
   >= cycle_budget` → HAND OFF) → pick top item (respect dependency order) → do it the
   declared/idempotent way (dry-run → apply for anything destructive) → **VERIFY across the
   boundary** (not existence-only: confirm it actually works in a fresh shell / re-run your
   real check) → write state back (`- [x]`/`- [!]`, bump counters) → **commit** → self-pace
   (`ScheduleWakeup` to re-enter; long delay if waiting on a slow external step).
3. At budget → invoke `session-relay` HAND OFF, then stop (no further wakeup).

**C. `session-relay` skill — `.claude/skills/session-relay/SKILL.md`**
Two entry points (full protocol in §7):
- **HAND OFF:** spawn `continuity-steward` → write+**commit** `.handoff/loop/HANDOFF.md`
  (kernel available: `hf checkpoint <ID> "<note>"` + `hf handoff` instead) → weave heartbeat
  `to:"all"` (`relay:handoff`) → best-effort one-shot cron successor whose prompt self-describes
  the resume → stop.
- **RESUME:** read the committed `HANDOFF.md` / `hf resume` packet (authoritative) → run its
  verify-on-resume baseline → broadcast `relay:resumed` → reset `cycles_this_session=0` →
  continue at the backlog's current item.

**D. `continuity-steward` agent — `.claude/agents/continuity-steward.md`**
A general-purpose agent that writes the cold-start `HANDOFF.md` (state + pointers, not
narrative): resume command, worktree+branch, backlog status, in-flight cycle, landed-this-
session commits, open findings, decisions/dead-ends, and **Verify-on-resume** commands.
Offloading this keeps the orchestrator's context lean.

**E. Resume slash command** (so a new session picks up where the last left off)
Wire `/<loop> resume from .handoff/loop/HANDOFF.md` to enter the loop in RESUME mode. The
skill's description must trigger on "resume", "pick up the loop", "continue in a new session".

**F. The `/new` upgrade — external runner `.claude/skills/<loop>/scripts/ralph-<x>.sh`**
A bounded `while` loop that each iteration: checks sentinels → spawns one fresh
`claude -p "<resume prompt>"` (clean context) → reads the one sentinel it wrote → respawns or
exits. Safe by default; `*_APPLY=1` opts into `--dangerously-skip-permissions`; `MAX_ITERS`
backstop; `touch .handoff/loop/STOP` kills it. Skeleton in §8.

## 4) Acceptance targets (prove these)

- **Backlog is the only source of truth**; every cycle commits; nothing lives only in context.
- **Cold resume works:** a fresh session given *only* the committed
  `.handoff/loop/HANDOFF.md` (or `hf resume` packet) resumes and continues at the correct
  item (verify-on-resume baseline passes first).
- **Self-restart works:** the external runner spawns fresh-context agents and terminates
  **exactly** on `DONE` / `NEEDS-HUMAN` / `STOP` (never spins past `MAX_ITERS`).
- **Fail-closed:** destructive ops dry-run first, need explicit opt-in, guards never weakened;
  a human wall yields `NEEDS-HUMAN`, not a forced action or a false "green".
- **DONE only with evidence:** terminal `DONE` is written only when `<your full verify suite>`
  all pass, and the evidence is recorded in `.handoff/loop/DONE`.
- **Honest reporting:** blocked items surfaced with reasons; no claiming green you can't prove.

## 5) Template — `.handoff/loop/loop_state.md`

```markdown
# Loop state — <loop>
session_started: <UTC e.g. 2026-06-05T02:52:37Z>   # you supply it; scripts can't read the clock
loop: <loop>
branch: <branch>
worktree: <abs path>
cycle_budget: 3            # completed cycles per session before handoff (override via arg)
cycles_this_session: 0     # reset to 0 on RESUME
cycles_total: 0            # carried across sessions
last_item: (none — discovery only)
status: DISCOVER complete — backlog seeded
last_update: <UTC>
```

## 6) Sentinel contract (the runner reads exactly one per process)

| Sentinel (`.handoff/loop/…`) | Meaning | Runner action |
|------------------------------|---------|---------------|
| `HANDOFF.md` | more work remains | spawn the next fresh process |
| `DONE`       | finished + verified (evidence inside) | exit 0 |
| `NEEDS-HUMAN`| sudo / reboot / interactive / hardware wall (reason inside) | halt for human |
| `STOP`       | kill switch (human `touch`es it) | halt |

## 7) `session-relay` protocol (the durable bits, verified)

- **Checkpoint** `.handoff/loop/HANDOFF.md` (by `continuity-steward`) is the real payload;
  commit it. Kernel reachable → `hf checkpoint` + `hf handoff` are the witnessed equivalents
  and take precedence (state order: Git > ledger > cards > prose).
- **weave** is the **cross-identity** heartbeat: broadcast `to:"all"` (`relay:handoff` /
  `relay:resumed`). Do **not** rely on your own inbox for a same-identity handoff — a
  self-addressed message isn't there.
- **cron** (`CronCreate {recurring:false}`) is **best-effort** (`durable:true` is *not* honored
  in this runtime — session-only). The prompt itself must self-describe the resume. For
  survives-restart continuation, the committed `HANDOFF.md` is the signal (a human, the
  external runner, or `RemoteTrigger` resumes from it).
- **RESUME** takes its signal from the prompt/checkpoint, verifies baseline, resets the
  per-session counter, continues.

## 8) Template — external `/new` runner (generalize this)

```bash
#!/usr/bin/env bash
# ralph-<x>.sh — external Ralph loop: self-restarts <loop> with a FRESH context each iteration
# (each `claude -p` process is a clean session = the /new effect) until a terminal sentinel.
set -euo pipefail
WORKTREE="${RALPH_WORKTREE:-$(pwd)}"; BUDGET="${RALPH_BUDGET:-3}"
MAX_ITERS="${RALPH_MAX_ITERS:-50}"; SLEEP_BETWEEN="${RALPH_SLEEP:-5}"; MODEL="${RALPH_MODEL:-opus}"
WS="$WORKTREE/.handoff/loop"; mkdir -p "$WS"
log(){ printf '[ralph %s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
command -v claude >/dev/null || { log "FATAL: claude not on PATH"; exit 1; }

APPLY_ARGS=()
if [ "${RALPH_APPLY:-0}" = "1" ]; then APPLY_ARGS=(--dangerously-skip-permissions)
  log "APPLY MODE — will modify the live system unattended."
else log "SAFE mode (default): destructive applies refused. Set RALPH_APPLY=1 to act."; fi

read -r -d '' PROMPT <<EOF || true
/<loop> resume (external Ralph runner, fresh context). Worktree: $WORKTREE.
1. If .handoff/loop/HANDOFF.md exists, follow session-relay RESUME from it (authoritative
   signal); else DISCOVER and build .handoff/loop/backlog.md (or mint cards via hf when the
   kernel is reachable).
2. Run up to $BUDGET cycles: one item each, dry-run -> apply for destructive steps, VERIFY across
   the boundary in a FRESH shell, commit per cycle. Fail-closed; never weaken a guard.
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
  claude -p "$PROMPT" --model "$MODEL" --add-dir "$WORKTREE" "${APPLY_ARGS[@]}" \
    >>"$WS/ralph-run-$i.log" 2>&1 || log "iter $i nonzero (continuing from durable state)"
  [ -f "$WS/DONE" ]        && { log "DONE."; exit 0; }
  [ -f "$WS/NEEDS-HUMAN" ] && { log "NEEDS-HUMAN: $(cat "$WS/NEEDS-HUMAN")"; exit 2; }
  [ -f "$WS/STOP" ]        && { log "STOP — halting."; exit 2; }
  sleep "$SLEEP_BETWEEN"
done
```

Launch:
```bash
bash .claude/skills/<loop>/scripts/ralph-<x>.sh                 # SAFE: dry/plan, commits non-destructive progress
RALPH_APPLY=1 bash .claude/skills/<loop>/scripts/ralph-<x>.sh   # UNATTENDED APPLY: opt in deliberately
touch .handoff/loop/STOP                                        # kill switch, any time
```

## 9) Placement & adaptation notes

- Keep the harness **hand-authored and git-tracked** (agents in `.claude/agents/*.md`, skills in
  `.claude/skills/*`). If your repo generates `.claude/` from a provisioning tool (kasetto-style),
  carve out the harness as a deliberate, documented exception so it isn't overwritten.
- **Kernel-first when you have it:** repos inside the meta workspace reach the handoff kernel
  at `handoff/target/{release,debug}/hf`. Backlog → minted cards; per-cycle checkpoint →
  `hf checkpoint <ID> "<note>"` (witnessed); relay packet → `hf handoff`. The file protocol in
  §§5–8 is the *standalone/offline* fallback and the bridge for repos cloned outside meta.
- **Wire the loop to your repo's real commands** — don't invent a CLI. The envctl version drives
  `doctor`/`auto-detect`/`install`/`lock`/CI gates; yours drives whatever proves your work
  (tests, build, lint, deploy check, migration verify…). The *shape* transfers; the verbs don't.
- Make `<your DONE criteria>` concrete and evidence-backed — that's what lets the runner exit 0
  honestly instead of looping or lying.
- Record a short **change history** table in your repo's CLAUDE.md (date | change | target | reason)
  as you evolve the harness — the envctl one does this and it pays off.
- Migrating from v1: leave existing `_workspace/` content in place (history); point the capsule
  at the new `.handoff/loop/` and start writing new state there. Per-repo kits in
  `harness_hub/upgrade-kits/` carry the same retarget note.

---

*Source pattern: `envctl` harness — skills `forge-loop` / `env-install-loop` / `session-relay` /
`auto-provision`, agent `continuity-steward`, runner `auto-provision/scripts/ralph-provision.sh`.
v2 retarget: ADR-0004 / policy P7.36 (2026-06-12).*
