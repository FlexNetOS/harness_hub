# Loop state — <MEMBER>
session_started: <SESSION_STARTED>   # filled by bootstrap (date -u); the agentic loop never reads the clock
loop: feature-forge (<MEMBER>)
branch: <BRANCH>
worktree: <WORKTREE>
repo: <MEMBER>
cycle_budget: 3            # completed cycles per session before HAND OFF (session-relay-wrap-up)
wrap_every: 5              # in-session batch boundary cadence (reaper + wrap-up reconcile + retro)
last_wrapup_total: 0       # cycles_total at the last batch boundary (boundary due when cycles_total - this >= wrap_every)
cycles_this_session: 0     # reset to 0 on RESUME
cycles_total: 0
last_item: (none — backlog not started)
status: INITIAL            # INITIAL | ITERATE in-progress | HAND OFF | DONE | NEEDS-HUMAN
# Per-cycle PR tracking (tick-on-merged gate):
#   when a cycle's guardian PASSes and auto-merge is armed but the PR is not yet MERGED,
#   record it here and leave the backlog item `- [~]` (in-flight). The next session's FIRST
#   action re-polls `gh pr view <N>` and promotes `- [~]`->`- [x]` once MERGED.
in_flight_pr: none         # <N> state=<mergeStateStatus>, or `none`
last_update: <SESSION_STARTED>
