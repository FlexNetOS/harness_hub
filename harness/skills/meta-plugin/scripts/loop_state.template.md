# Loop state — meta-plugin
session_started: <UTC e.g. 2026-06-13T14:00:00Z>   # you supply it; the runtime can't read the clock
loop: meta-plugin
branch: <branch>
worktree: <abs path>
cycle_budget: 3            # completed cycles per session before handoff (override via arg)
cycles_this_session: 0     # reset to 0 on RESUME
cycles_total: 0            # carried across sessions
scope: <e.g. all .meta.yaml repos | the 4 coordination repos>
last_item: (none — discovery only)
status: DISCOVER complete — backlog seeded
last_update: <UTC>
