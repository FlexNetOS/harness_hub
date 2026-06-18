#!/usr/bin/env bash
# init-handoff-kernel.sh — build the FULL .handoff continuity kernel in a repo by DRIVING `hf`.
# Kernel-first (never hand-rolls kernel artifacts), idempotent, fail-closed.
#
# Usage:
#   bash init-handoff-kernel.sh [TARGET_DIR] [-- hf-init-flags...]
#   bash init-handoff-kernel.sh                          # init the cwd as itself
#   bash init-handoff-kernel.sh /path/to/repo            # init another repo
#   bash init-handoff-kernel.sh . --name "weave (A2A bus)" --role tool --plane execution \
#                                 --northstar "the repo's guiding goal"
#
# Portable `hf init` (handoff PR #81) does the heavy lifting itself: it identifies the repo as
# ITSELF (name from the git toplevel; neutral "(seed me)" northstar — never the kernel's
# identity), writes the Tier-A README + the .handoff/**/ledger.db .gitignore residency guard,
# and is idempotent + non-destructive (an existing capsule is preserved). In the handoff kernel
# home (detected by the keystone ADR) it writes the full kernel doctrine instead. So this script
# is now a thin, fail-closed wrapper that drives `hf init`, verifies the residency guard landed,
# and reports status.
set -euo pipefail

# First positional that does NOT start with '-' is the TARGET; everything else (incl. anything
# after a literal `--`) is forwarded verbatim to `hf init` (--name/--northstar/--role/--plane).
TARGET="$(pwd)"
if [ "${1:-}" = "--" ]; then
  shift
elif [ -n "${1:-}" ] && [ "${1#-}" = "${1}" ]; then
  TARGET="$1"; shift
  [ "${1:-}" = "--" ] && shift
fi
HF_INIT_ARGS=("$@")

[ -d "$TARGET" ] || { echo "error: target dir not found: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

if ! command -v hf >/dev/null 2>&1; then
  cat >&2 <<MSG
NEEDS-HUMAN: hf (the Continuity Ledger Kernel) is not on PATH.
The kernel is the only way to build .handoff/ — it is never hand-rolled.
Install it from meta/handoff (cargo build/install the hf binary), then re-run this script.
MSG
  exit 2
fi
[ -d "$TARGET/.git" ] || { echo "error: $TARGET is not a git repo (the kernel is Git-anchored)." >&2; exit 1; }

cd "$TARGET"
# `hf init` is idempotent + non-destructive — safe to run whether or not .handoff/ exists
# (it preserves a curated capsule and reports "capsule preserved").
echo "  hf init ${HF_INIT_ARGS[*]:-}…"
hf init "${HF_INIT_ARGS[@]}" 2>&1 | sed 's/^/    /'

# Defense-in-depth: confirm portable `hf init` left the ledger-residency guard in place
# (P7 / ADR-0004 §6 — `hf fleet status` requires it). If an OLDER hf predating PR #81 didn't
# write it, add the canonical guard as a fallback so the repo is conformant regardless.
if git check-ignore -q .handoff/ledger.db 2>/dev/null; then
  echo "  ✓ ledger-residency guard present (.handoff/ledger.db is gitignored)."
else
  echo "  ! hf did not set the ledger guard (old hf?) — adding the canonical block as a fallback."
  {
    echo ""
    echo "# handoff continuity: local ledger is gitignored (ADR-0004 §3.3/§6 rev, HFTASK-0035)"
    echo ".handoff/**/ledger.db"
    echo ".handoff/**/*.db-wal"
    echo ".handoff/**/*.db-shm"
  } >> "$TARGET/.gitignore"
  echo "  .gitignore += .handoff/**/ledger.db (+ wal/shm)"
fi

echo "  --- hf status ---"
hf status 2>&1 | sed 's/^/    /' || echo "    (hf status unavailable)"
echo "  ✓ .handoff kernel ready at $TARGET (do NOT run 'hf seed' here — it injects handoff's own backlog)."
