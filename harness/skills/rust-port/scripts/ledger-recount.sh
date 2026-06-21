#!/usr/bin/env bash
# ledger-recount.sh — deterministic marker recount for the parity/symbol/merge ledgers.
#
# WHY: a session that tracks counts by hand-arithmetic drifts from a regex recount (observed across the
# MiroFish→teri loop: running "+13/+3/+1" math disagreed with the regex sweep because the two used
# different patterns). The per-symbol marker in the ledger is the source of truth; this script makes the
# COUNT a single deterministic read so the loop never reconciles two divergent tallies. Run it before
# writing counts into loop_state.md / DONE.
#
# It counts the five row markers — [ ] [~] [x] [!] [≠] — anchored at line start in the exact row format
# (`- [<m>] `), so prose that merely mentions a symbol id never inflates a count.
#
# Usage:
#   bash ledger-recount.sh [<handoff-loop-dir>]        # default: .handoff/loop
#   bash ledger-recount.sh --find <id> [<dir>]         # token-safe row lookup (never substring-matches prose)
set -euo pipefail

DIR="${1:-.handoff/loop}"
if [ "${1:-}" = "--find" ]; then
  ID="${2:?usage: ledger-recount.sh --find <symbol-or-unit-id> [dir]}"
  DIR="${3:-.handoff/loop}"
  # Anchored, token-delimited: matches `- [<m>] <ID> ·` only — never `... S-877 ...` inside prose.
  grep -rnE "^- \[.\] ${ID} ·" "$DIR" 2>/dev/null || { echo "no ledger row for '${ID}' (prose mentions are ignored by design)"; exit 1; }
  exit 0
fi

[ -d "$DIR" ] || { echo "error: not a dir: $DIR" >&2; exit 1; }

count_file() {
  # prints: a human line, then a machine line "TALLY <empty> <tilde> <x> <bang> <neq>"
  # Patterns require the ledger ROW structure `- [<m>] <id-token> ·` so a prose checkbox
  # (`- [x] did a thing`) is never miscounted as a ledger row — only true rows have the ` · ` field sep.
  local f="$1" empty tilde x bang neq total
  empty=$(grep -cE '^- \[ \] [^ ]+ ·'  "$f" 2>/dev/null || true)
  tilde=$(grep -cE '^- \[~\] [^ ]+ ·'  "$f" 2>/dev/null || true)
  x=$(grep -cE '^- \[x\] [^ ]+ ·'      "$f" 2>/dev/null || true)
  bang=$(grep -cE '^- \[!\] [^ ]+ ·'   "$f" 2>/dev/null || true)
  neq=$(grep -cE '^- \[≠\] [^ ]+ ·'    "$f" 2>/dev/null || true)
  total=$(( empty + tilde + x + bang + neq ))
  printf '%-44s  [ ]=%-5s [~]=%-4s [x]=%-5s [!]=%-4s [≠]=%-5s  total=%s\n' \
    "${f#"$DIR"/}" "$empty" "$tilde" "$x" "$bang" "$neq" "$total"
  printf 'TALLY %s %s %s %s %s\n' "$empty" "$tilde" "$x" "$bang" "$neq"
}

echo "── ledger marker recount: $DIR ──"
G_EMPTY=0; G_TILDE=0; G_X=0; G_BANG=0; G_NEQ=0
# Include the unit ledger, the symbol map (+ shards), and the merge ledger when present.
mapfile -t FILES < <(find "$DIR" -type f \( -name 'parity-ledger.md' -o -name 'merge-ledger.md' -o -name 'symbol-map.md' -o -path '*/symbol-map/*.md' \) 2>/dev/null | sort)
[ "${#FILES[@]}" -gt 0 ] || { echo "no ledger files found under $DIR"; exit 1; }
while read -r line; do
  if [ "${line%% *}" = "TALLY" ]; then
    read -r _ e t x b n <<<"$line"
    G_EMPTY=$((G_EMPTY+e)); G_TILDE=$((G_TILDE+t)); G_X=$((G_X+x)); G_BANG=$((G_BANG+b)); G_NEQ=$((G_NEQ+n))
  else
    echo "$line"   # human per-file line, passthrough
  fi
done < <(for f in "${FILES[@]}"; do count_file "$f"; done)
G_TOTAL=$(( G_EMPTY + G_TILDE + G_X + G_BANG + G_NEQ ))
G_TERMINAL=$(( G_X + G_NEQ ))
echo "──────────────────────────────────────────────────────────────────────────────"
printf '%-44s  [ ]=%-5s [~]=%-4s [x]=%-5s [!]=%-4s [≠]=%-5s  total=%s\n' \
  "TOTAL (all rows)" "$G_EMPTY" "$G_TILDE" "$G_X" "$G_BANG" "$G_NEQ" "$G_TOTAL"
echo "terminal (= [x]+[≠], count toward DONE): $G_TERMINAL / $G_TOTAL"
if [ "$G_TOTAL" -gt 0 ]; then
  PCT=$(( G_TERMINAL * 100 / G_TOTAL ))
  echo "DONE-progress: ${PCT}%   (DONE requires 100% terminal AND a clean pre-DONE left-behind sweep)"
fi
[ "$(( G_EMPTY + G_TILDE + G_BANG ))" -eq 0 ] && echo "no open rows ([ ]/[~]/[!]) — ledger is terminal (sweep still gates DONE)." || true
