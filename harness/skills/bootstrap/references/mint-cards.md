# Minting the backlog into hf task cards (the proven TASK-0044 method)

After `bootstrap-repo.sh` seeds `.handoff/loop/backlog.md`, the repo's kernel `.handoff/tasks/` is
still **empty** — the backlog is a human view, not yet the kernel's dependency-DAG. This step turns
the backlog into per-member `handoff.task.v1` cards so `hf fleet render <member>` and the kernel DAG
picker become real. Drive it with the **`feature-forge-kernel-engineer`** agent — it is the agent that
performed this exact mint for envctl (TASK-0044) and owns the kernel/ledger-residency invariants.

This is a **contamination-sensitive, kernel-version-specific** operation — do it the proven way, not
with a shortcut.

## The method (what worked for envctl, 53 cards, zero contamination)

1. **Generate cards with the kernel's OWN `work-order` crate.** Build a throwaway generator that links
   `meta/handoff`'s `work-order` crate and calls `WorkOrder::compute_intent_lock`, so every card's
   `intent_lock` (blake3) is **byte-identical to what `hf` verifies**. Confirm by re-deriving an
   existing card's hashes (e.g. another member's) and matching them before writing any new card.
2. **Write cards into the PER-MEMBER store**, `<repo>/.handoff/tasks/TASK-####.task.json` — NOT the
   shared `$META_ROOT/.handoff/` FLEET dir. Card-file writes touch **zero ledger** (verify the FLEET
   `ledger.db` md5 + event count are unchanged before/after).
3. **One card per backlog item.** Carry `- [x]` items as `status: done`, open items as `backlog`,
   `- [!]` as `blocked`, `- [!!]` as supervised (never auto-served). Derive `dependencies`/`blocked_by`
   from the backlog `## Order` blocks + sub-notes. Preserve the `TASK-####` ids and one-line goals.
4. **Card schema (handoff.task.v1)** — the fields envctl's cards carry:
   `schema, id, title, status, priority, objective, path_scope, acceptance_criteria, test_commands,
   dependencies, blocked_by, allows_network, allows_dependency_addition, correlation_id, role,
   intent_lock`.

## What NOT to use (and why — learned on envctl)

- **`hf task mint --from-kb <slug>`** — forces a `KBTASK-` prefix and writes into the shared FLEET dir
  → mixes envctl's work into the kernel's own `HFTASK-*`/`KBTASK-*` loop (contamination). Rejected.
- **`hf intake --bundle`** — vibe-synthesis front door; it cannot carry N pre-specified ids / deps /
  statuses faithfully. Rejected for a known, ordered backlog.
- **Hand-writing `*.task.json`** without the work-order crate — the `intent_lock` won't match what `hf`
  verifies, so the kernel rejects/ignores the cards. Always compute it via the crate.

## Verify the mint (the acceptance gate)

- `hf fleet render <member>` (from `$META_ROOT`) renders the repo's packet from its OWN cards, lists
  only `TASK-*`, **0 cross-member (`HFTASK-*`/other) leakage**.
- DAG correctness: a card whose `blocked_by` is open is **not** served as next; an unblocked one is.
- Contamination guard: other members' card counts + the FLEET `ledger.db` are **unchanged**.
- `bash` the repo's `ci/gates/p7.sh` if present (residency/schema), and `hf doctor` healthy.

## Ledger model (ADR-0004 §3.3 rev + ADR-0052)

Once minted, the cards + this repo's **per-repo `.handoff/ledger.db`** (the gitignored witnessed
source of record) drive the loop: `hf resume`/`hf claim` run **in the member dir** read them directly.
The per-repo ledger **auto-syncs** to the central FLEET ledger at session end via the SessionStop hook
(`hf checkpoint --auto && hf handoff && hf sync --auto`). Keep the ledger **gitignored** — a
*git-committed* binary ledger is BANNED (`hf fleet status` flags a tracked one). `HFTASK-0054`'s
`--ledger`/`HANDOFF_LEDGER` override (landed, PR #85) is for rendering against the shared/central
ledger — what `hf fleet render <member>` does from `$META_ROOT` for the cross-repo board.
