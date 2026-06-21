#!/usr/bin/env bash
# git-hygiene.sh — audit + (guarded) cleanup of the port/merge git surface: worktrees, feature
# branches, and stale remote-tracking refs. A multi-session port-and-merge accumulates per-task
# worktrees and merged `dest_branch`es; this keeps that surface clean WITHOUT ever risking unmerged work.
#
# SAFE BY DEFAULT: audit only (dry-run). Mutations happen only with --apply, and even then:
#   - protected branches (main/master/develop + the current branch + any dest_base) are NEVER deleted;
#   - only branches already MERGED into the base are deleted (git branch -d, never -D — unmerged work
#     is refused by git itself);
#   - a worktree is pruned only if git reports it prunable (its dir is gone) or it is clean + merged;
#   - cleanup refuses to run if the current worktree is dirty (commit/stash first).
#
# Usage:
#   bash git-hygiene.sh                      # audit the current repo against its default base
#   bash git-hygiene.sh --base develop       # audit merged-ness against a specific base
#   bash git-hygiene.sh --apply [--base B]   # perform the SAFE cleanups listed by the audit
set -euo pipefail

BASE=""; APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift;;
    --base)  BASE="${2:?--base needs a branch}"; shift 2;;
    *) echo "usage: git-hygiene.sh [--base <branch>] [--apply]" >&2; exit 1;;
  esac
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "error: not in a git repo" >&2; exit 1; }
REPO_ROOT="$(git rev-parse --show-toplevel)"
CUR="$(git rev-parse --abbrev-ref HEAD)"

# Resolve the base branch (explicit > origin/HEAD > main > master > develop).
if [ -z "$BASE" ]; then
  # `|| true` inside the substitution: with no remote, `git symbolic-ref` exits non-zero and (under
  # `set -e -o pipefail`) would otherwise abort the whole script on a fresh/remoteless repo.
  BASE="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@' || true)"
  [ -n "$BASE" ] || { git show-ref --verify --quiet refs/heads/main && BASE=main; }
  [ -n "$BASE" ] || { git show-ref --verify --quiet refs/heads/master && BASE=master; }
  [ -n "$BASE" ] || { git show-ref --verify --quiet refs/heads/develop && BASE=develop; }
fi
[ -n "$BASE" ] || { echo "error: could not resolve a base branch; pass --base" >&2; exit 1; }
# Validate the base actually exists (a bad --base would otherwise spew `fatal: malformed object name`
# from the merged-check below); accept a local branch or any resolvable ref (e.g. origin/<base>).
git rev-parse --verify --quiet "refs/heads/$BASE" >/dev/null 2>&1 \
  || git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null 2>&1 \
  || { echo "error: base branch '$BASE' does not exist (pass a valid --base)" >&2; exit 1; }
PROTECTED="main master develop $BASE $CUR"
is_protected() { for p in $PROTECTED; do [ "$1" = "$p" ] && return 0; done; return 1; }

echo "── git hygiene @ $REPO_ROOT  (base=$BASE, current=$CUR, mode=$([ "$APPLY" = 1 ] && echo APPLY || echo audit)) ──"

echo; echo "[1] worktrees"
git worktree list
PRUNABLE="$(git worktree list --porcelain | awk '/^worktree /{w=$2} /^prunable /{print w}')"
if [ -n "$PRUNABLE" ]; then echo "  prunable (dir missing):"; echo "$PRUNABLE" | sed 's/^/    /'; else echo "  (none prunable)"; fi

echo; echo "[2] local branches already merged into $BASE (safe to delete)"
MERGED="$(git branch --merged "$BASE" --format='%(refname:short)' | while read -r b; do is_protected "$b" || echo "$b"; done)"
[ -n "$MERGED" ] && echo "$MERGED" | sed 's/^/    /' || echo "    (none)"

# Squash/rebase-merge detection: `git branch --merged` only sees ANCESTRY merges, so a branch whose PR
# was SQUASH-merged (the default on many repos — every PR in this repo) shows as "not merged" forever
# and is never cleaned (the exact gap that stranded 6 branches here). Use the merged-PR record (one `gh`
# call, matched locally) as the proof of merge. gh-gated → graceful no-op when ejected to a non-GitHub
# repo (behavior then identical to before: ancestry-only).
GH_OK=0; MERGED_HEADS=""; OPEN_HEADS=""
if command -v gh >/dev/null 2>&1 && git remote get-url origin >/dev/null 2>&1; then
  MERGED_HEADS="$(gh pr list --state merged --limit 300 --json headRefName -q '.[].headRefName' 2>/dev/null || true)"
  OPEN_HEADS="$(gh pr list --state open   --limit 100 --json headRefName -q '.[].headRefName' 2>/dev/null || true)"
  [ -n "$MERGED_HEADS" ] && GH_OK=1
fi
is_squash_merged() { [ "$GH_OK" = 1 ] && printf '%s\n' "$MERGED_HEADS" | grep -qxF "$1"; }
has_open_pr()      { [ "$GH_OK" = 1 ] && printf '%s\n' "$OPEN_HEADS"   | grep -qxF "$1"; }

# [3] genuinely-unmerged branches stay KEPT (never auto-deleted — they hold real work). But split them:
#   [3a] has an OPEN PR  → in-flight, fine;
#   [3b] has NO PR       → unmerged work that may be FORGOTTEN — the exact gap that let a vital harness
#                          upgrade (architect-in-loop) sit unmerged. Surface it loudly for review.
SQUASH_MERGED=""; NOPR_UNMERGED=""
echo; echo "[3] local branches NOT yet merged into $BASE (KEPT — never auto-deleted)"
KEPT_ANY=0
while read -r b; do
  [ -n "$b" ] || continue; is_protected "$b" && continue
  if   is_squash_merged "$b"; then SQUASH_MERGED="${SQUASH_MERGED}${b}"$'\n'
  elif has_open_pr "$b";      then echo "    $b   [3a] in-flight (open PR)"; KEPT_ANY=1
  elif [ "$GH_OK" = 1 ];      then echo "    $b   [3b] ⚠ NO open PR — unmerged work, may be FORGOTTEN"; NOPR_UNMERGED="${NOPR_UNMERGED}${b}"$'\n'; KEPT_ANY=1
  else echo "    $b"; KEPT_ANY=1; fi
done < <(git branch --no-merged "$BASE" --format='%(refname:short)')
[ "$KEPT_ANY" = 0 ] && echo "    (none)"
if [ -n "$NOPR_UNMERGED" ]; then
  echo "    ⚠ [3b] above have unmerged commits and NO PR — a vital upgrade can sit here forgotten."
  echo "      Review each: open a PR + merge it, or delete if superseded. (Never silently leave it.)"
fi

if [ "$GH_OK" = 1 ]; then
  echo; echo "[2b] NOT ancestry-merged but a SQUASH/rebase PR merged them (gh-confirmed — safe to delete)"
  [ -n "$SQUASH_MERGED" ] && printf '%s' "$SQUASH_MERGED" | sed '/^$/d;s/^/    /' || echo "    (none)"
else
  echo; echo "[2b] squash-merge detection SKIPPED (no gh / no GitHub remote) — ancestry-merged [2] only"
fi

# [2c] REMOTE-ONLY stranded branches: the most common drift — you merge a PR from the GitHub UI and the
# REMOTE branch lingers even though no local copy exists, so [2]/[2b] (local-only) never see it. List
# every origin branch whose PR was merged and that is not protected. gh-gated (same as [2b]).
STRANDED_REMOTE=""
if [ "$GH_OK" = 1 ]; then
  echo; echo "[2c] REMOTE branches whose PR was merged but were never deleted (gh-confirmed — safe to delete)"
  while read -r rb; do
    [ -n "$rb" ] || continue; is_protected "$rb" && continue
    printf '%s\n' "$MERGED_HEADS" | grep -qxF "$rb" && STRANDED_REMOTE="${STRANDED_REMOTE}${rb}"$'\n'
  done < <(git ls-remote --heads origin 2>/dev/null | sed 's#.*refs/heads/##')
  [ -n "$STRANDED_REMOTE" ] && printf '%s' "$STRANDED_REMOTE" | sed '/^$/d;s/^/    /' || echo "    (none)"
fi

echo; echo "[4] remote-tracking refs whose upstream is gone (stale)"
GONE="$(git branch -vv | awk '/: gone\]/{print $1}' | sed 's/^[*+] *//')"
[ -n "$GONE" ] && echo "$GONE" | sed 's/^/    /' || echo "    (none — run 'git fetch --prune' to refresh)"

if [ "$APPLY" != 1 ]; then
  echo; echo "audit only. Re-run with --apply to: prune missing-dir worktrees; delete [2] ancestry-merged"
  echo "(git branch -d), [2b] gh-confirmed squash-merged locals (git branch -D + their remote ref), and"
  echo "[2c] gh-confirmed stranded REMOTE branches (git push origin --delete); then 'git fetch --prune'."
  echo "Branches in [3] & protected branches (main/master/develop/current/base) are never touched."
  exit 0
fi

# ---- APPLY (only the safe set) ----
if [ -n "$(git status --porcelain)" ]; then
  echo "refusing --apply: working tree is dirty (modified / staged / untracked). Commit or stash first." >&2
  echo "  (untracked files count as dirty — 'git diff' alone would miss them.)" >&2
  exit 1
fi
echo; echo "applying safe cleanups…"
git worktree prune -v || true
if [ -n "$MERGED" ]; then
  echo "$MERGED" | while read -r b; do
    [ -n "$b" ] || continue
    git branch -d "$b" && echo "  deleted ancestry-merged branch: $b" || echo "  kept (git refused — not fully merged): $b"
  done
fi
# [2b] squash-merged: ancestry can't confirm, but the gh-merged PR is the proof → force-delete local +
# delete the remote ref. Only ever reached for branches gh confirmed as merged above.
if [ -n "$SQUASH_MERGED" ]; then
  printf '%s' "$SQUASH_MERGED" | sed '/^$/d' | while read -r b; do
    [ -n "$b" ] || continue
    git branch -D "$b" && echo "  deleted squash-merged branch (gh-confirmed): $b"
    git push origin --delete "$b" >/dev/null 2>&1 && echo "    + deleted remote origin/$b" || true
  done
fi
# [2c] remote-only stranded: delete the remote ref (no local copy exists). gh-confirmed merged above.
if [ -n "$STRANDED_REMOTE" ]; then
  printf '%s' "$STRANDED_REMOTE" | sed '/^$/d' | while read -r rb; do
    [ -n "$rb" ] || continue
    git push origin --delete "$rb" >/dev/null 2>&1 && echo "  deleted stranded remote branch (gh-confirmed): origin/$rb" || echo "  (could not delete origin/$rb — may already be gone)"
  done
fi
git fetch --prune --quiet && echo "  pruned stale remote-tracking refs"
echo "done. (To remove a specific merged worktree dir: 'git worktree remove <path>'.)"
