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

# Resolve the base branch (explicit > origin/HEAD > master > develop).
if [ -z "$BASE" ]; then
  BASE="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@')"
  [ -n "$BASE" ] || { git show-ref --verify --quiet refs/heads/master && BASE=master; }
  [ -n "$BASE" ] || { git show-ref --verify --quiet refs/heads/develop && BASE=develop; }
fi
[ -n "$BASE" ] || { echo "error: could not resolve a base branch; pass --base" >&2; exit 1; }
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

echo; echo "[3] local branches NOT yet merged into $BASE (KEPT — never auto-deleted)"
git branch --no-merged "$BASE" --format='%(refname:short)' | while read -r b; do is_protected "$b" || echo "    $b"; done

echo; echo "[4] remote-tracking refs whose upstream is gone (stale)"
GONE="$(git branch -vv | awk '/: gone\]/{print $1}' | sed 's/^[*+] *//')"
[ -n "$GONE" ] && echo "$GONE" | sed 's/^/    /' || echo "    (none — run 'git fetch --prune' to refresh)"

if [ "$APPLY" != 1 ]; then
  echo; echo "audit only. Re-run with --apply to: prune missing-dir worktrees, delete the [2] merged"
  echo "branches (git branch -d), and 'git fetch --prune'. Unmerged branches & protected branches are"
  echo "never touched. (Open the PR and let it merge BEFORE expecting a dest_branch to appear in [2].)"
  exit 0
fi

# ---- APPLY (only the safe set) ----
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "refusing --apply: current worktree is dirty. Commit or stash first." >&2; exit 1
fi
echo; echo "applying safe cleanups…"
git worktree prune -v || true
if [ -n "$MERGED" ]; then
  echo "$MERGED" | while read -r b; do
    [ -n "$b" ] || continue
    git branch -d "$b" && echo "  deleted merged branch: $b" || echo "  kept (git refused — not fully merged): $b"
  done
fi
git fetch --prune --quiet && echo "  pruned stale remote-tracking refs"
echo "done. (To remove a specific merged worktree dir: 'git worktree remove <path>'.)"
