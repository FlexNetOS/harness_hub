# Ejecting the `meta-plugin` harness into a target repo

The `meta-plugin` harness is **packaged + runnable + ejectable**. Two ways to use it:

- **Run in place** — invoke `/harness:meta-plugin` from anywhere the `harness` plugin is installed.
  Good for ad-hoc workspace organization runs.
- **Eject into a target repo** — copy a hand-authored, git-tracked instance into `<repo>/.claude/`,
  so that repo owns the harness and a fresh session can cold-resume from the repo's committed state.
  This is the form the autonomous-operation pattern wants for unattended/long-running use.

## Procedure

```bash
bash <plugin>/skills/meta-plugin/scripts/eject.sh <target-repo-dir>
```

The script (SAFE — copy + scaffold only):

1. Copies the orchestrator skill (`meta-plugin/`) and its sub-skills (`session-relay`,
   `hub-registry-sync`, `cross-repo-health`, `protocol-drift-scan`) into `<target>/.claude/skills/`.
2. Copies the agents it uses into `<target>/.claude/agents/`: shared infra
   (`build-health-auditor`, `integration-qa`, `continuity-steward`) + specialists
   (`meta-plugin-registry-curator`, `meta-plugin-protocol-drift-analyst`).
3. Scaffolds `<target>/.handoff/loop/` (durable state dirs).
4. **Prints** the `.gitignore` and `CLAUDE.md`-pointer snippets the target repo needs — it does
   **not** edit those files, because they are repo-specific. Review and apply them yourself.

## After ejecting

- The harness is now a first-party repo skill: invoke it as **`/meta-plugin`** (no `harness:`
  namespace in the target repo).
- Seed `.handoff/loop/loop_state.md` from `skills/meta-plugin/scripts/loop_state.template.md` on the
  first run (the orchestrator does this in DISCOVER).
- The Rust-native validator (`scripts/validate.sh` + the `hub-validate` crate) lives in
  **harness_hub**, not in every target. If the target repo is itself a hub, give it its own
  validator; otherwise the catalog-consistency pass only applies when organizing the hub repos.

## Why eject at all (vs. always run the plugin form)?

The Ralph pattern's guarantee — *cold resume from committed state, zero loss* — requires the
harness to be **committed in the repo it drives**. A plugin lives outside the target's git history,
so an ejected, git-tracked copy is what lets a fresh process (or the external runner) resume from
the repo alone. Run-in-place is for convenience; eject is for durable, repo-owned operation.

## Keeping ejected copies in sync

An ejected copy is a fork-in-time. When the packaged harness in the plugin evolves, re-run
`eject.sh` to overwrite the target's `.claude/skills/meta-plugin` + agents (it copies over the top).
Review the diff before committing in the target — the target may have local adaptations.
