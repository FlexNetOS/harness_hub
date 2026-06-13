#!/usr/bin/env bash
# init-handoff-kernel.sh — build the FULL .handoff continuity kernel in a repo by DRIVING `hf`.
# Kernel-first (never hand-rolls kernel artifacts), idempotent, fail-closed. Usage:
#   bash init-handoff-kernel.sh [TARGET_DIR]
set -euo pipefail
TARGET="${1:-$(pwd)}"
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
if [ -d .handoff ]; then
  echo "  .handoff/ already exists — not re-initializing (idempotent)."
else
  echo "  hf init …"
  hf init
fi

# Ledger-residency guard (P7: no per-repo *.db committed; the ledger is local).
GI="$TARGET/.gitignore"
add_ignore() { grep -qxF "$1" "$GI" 2>/dev/null || { printf '%s\n' "$1" >> "$GI"; echo "  .gitignore += $1"; }; }
touch "$GI"
grep -q '^# .handoff ledger residency' "$GI" 2>/dev/null || printf '\n# .handoff ledger residency (P7: ledger is local; fleet/witnessed state is the kernel'\''s)\n' >> "$GI"
add_ignore '.handoff/ledger.db'
add_ignore '.handoff/*.db'

echo "  --- hf status ---"
hf status 2>&1 | sed 's/^/    /' || echo "    (hf status unavailable)"
echo "  ✓ .handoff kernel ready at $TARGET (do NOT run 'hf seed' here — it injects handoff's own backlog)."
