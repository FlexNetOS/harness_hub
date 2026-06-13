# Ejecting the code-research harness into a target repo

`/harness:code-research` runs in place; eject for a git-tracked instance inside the repo under study
(handy for a long, resumable analysis or to keep the report with the code).

```bash
bash <plugin>/skills/code-research/scripts/eject.sh <target-repo-dir>
```

SAFE (copy + scaffold only; the harness is read-only on the target's code regardless). Copies the
orchestrator (`code-research/`) + sub-skills (`code-research-map`, `code-research-analyze`,
`code-research-verify`, `session-relay-wrap-up`, `session-relay-resume`, `harness-evolution`) into
`<target>/.claude/skills/`, the 6 agents into `<target>/.claude/agents/`, scaffolds
`<target>/.handoff/loop/`, and prints the `.gitignore` / `CLAUDE.md` snippets. Invoke as
`/code-research`. The verifier may *run* the target to test behavioral claims, so the target's
toolchain should be available.
