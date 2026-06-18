# harness-bootstrap (fresh-repo → hf kernel + forge-loop)

**Category:** orchestrator · **Status:** beta · **Runtime:** multi

One-shot, idempotent bootstrap that takes a FRESH repo (no harness, no hf) onto the hf Continuity Ledger Kernel AND the forge-loop/feature-forge construction-crew harness. Installs hf if absent (builds meta/handoff + symlinks), registers the repo as an hf fleet member (.meta.yaml), runs handoff-loop-init (hf init + ledger-residency guard), ejects the feature-forge harness and reconciles its file-based .handoff/loop/ with the kernel .handoff/, wires CLAUDE.md/.gitignore/settings, seeds the backlog, and verifies (hf status + hf fleet render). Safe by default (dry-run; --apply to execute), fail-closed. The kernel-backed loop picks via hf fleet render <member> (HFTASK-0054-aware) with a file-based cycle counter.

## Use

```bash
# preview (dry-run; changes nothing) then execute
bash harness/skills/harness-bootstrap/scripts/bootstrap-repo.sh <target-repo> [--member NAME] [--repo GIT_URL]
bash harness/skills/harness-bootstrap/scripts/bootstrap-repo.sh <target-repo> --apply
```
Or invoke `/harness:harness-bootstrap` and point it at the repo.

## The six steps (and the four fresh-repo gaps they close)

| # | Step | Gap closed |
|---|------|-----------|
| 0 | Ensure `hf` — build `meta/handoff` + symlink `~/.local/bin/hf` if absent | `handoff-loop-init` alone punts a missing hf to NEEDS-HUMAN |
| 1 | Ensure git repo + add the repo to `.meta.yaml` (fleet membership) | hf fleet discovery = `.meta.yaml`; a fresh repo isn't a member yet |
| 2 | Kernel init via `handoff-loop-init` (`hf init` + ledger-residency `.gitignore` guard) | — |
| 3 | Eject `feature-forge` (skills+agents) + reconcile its file-based `.handoff/loop/` with the kernel `.handoff/{tasks,packets,…}` | the two state surfaces must coexist, not collide |
| 4 | Wire CLAUDE.md / `.gitignore` / settings (kernel-backed pointer + ICM priming) | a fresh repo has no CLAUDE.md; invariants need per-repo adaptation |
| 5 | Seed `.handoff/loop/backlog.md` | — |
| 6 | Verify (`hf status` + `hf fleet render <member>`) | — |

## Composes (does not reinvent)

- **`handoff-loop-init`** → the kernel `.handoff/` (`hf init`, never hand-rolled).
- **`feature-forge` eject.sh** → the construction-crew harness (architect→implementer→guardian, forge-loop, session-relay).
- **`session-relay-wrap-up`/`-resume`** → cross-session continuity (ejected with the harness).

## Loop model it sets up

**Kernel-backed + file cycle-counter.** `.handoff/` is the kernel's; the forge-loop picks the next
dep-safe item via `hf fleet render <member>` (read-only, from `$META_ROOT` — the safe authority path
while the shipped `hf` is CWD-relative with no `--ledger`/`--member` override, kernel item
**HFTASK-0054**) and keeps `loop_state.md` for the cycle counter. Reverts to `hf claim --next` once
HFTASK-0054 lands.

## Safety

Dry-run by default (prints every planned mutation), `--apply` to execute, idempotent, fail-closed.
Backs up `.meta.yaml` before editing; never clobbers existing kernel/loop state; never `--force`.
Verified: a real `--apply` run leaves the central fleet ledger byte-identical (no contamination).

> **Provenance:** distilled from the envctl Feature Forge rollout — the composition of
> `handoff-loop-init` + the `feature-forge` package + fleet onboarding into a single fresh-repo pass.
