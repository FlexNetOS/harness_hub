#!/usr/bin/env bash
# bootstrap-repo.sh — stand up a FRESH repo (no harness, no hf) on the hf Continuity Ledger Kernel
# + the forge-loop / feature-forge harness, in one idempotent pass.
#
# Composes the existing primitives and fills the fresh-repo gaps:
#   0. ensure hf            (build meta/handoff + symlink ~/.local/bin if absent)   [gap 1]
#   1. ensure git + fleet   (add the repo to .meta.yaml so hf fleet discovers it)   [gap 2]
#   2. kernel init          (handoff-loop-init: hf init + ledger-residency guard)
#   3. eject the harness    (feature-forge eject.sh), reconcile with the kernel .handoff/  [gap 3]
#   4. wire CLAUDE.md/gitignore/settings (kernel-backed forge-loop pointer)          [gap 4]
#   5. seed the backlog     (.handoff/loop/backlog.md stub)
#   6. verify               (hf status + hf fleet render <member> + report)
#
# SAFE BY DEFAULT: dry-run (prints every mutation it WOULD make). Pass --apply to execute.
# Idempotent (safe to re-run). Fail-closed (a real error stops the run; it never fabricates state).
#
# Usage:
#   bash bootstrap-repo.sh <target-repo-dir> [--apply] [--member NAME] [--repo GIT_URL] [--meta-root PATH]
set -euo pipefail

TARGET="" ; APPLY=0 ; MEMBER="" ; REPO_URL="" ; META_ROOT="${META_ROOT:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/../../.." && pwd)"   # harness/  (skills/<name>/scripts -> up 3)

usage() { sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
while [ $# -gt 0 ]; do case "$1" in
  --apply)     APPLY=1 ;;
  --member)    MEMBER="${2:-}"; shift ;;
  --repo)      REPO_URL="${2:-}"; shift ;;
  --meta-root) META_ROOT="${2:-}"; shift ;;
  -h|--help)   usage; exit 0 ;;
  -*)          echo "unknown flag: $1" >&2; exit 1 ;;
  *)           TARGET="$1" ;;
esac; shift; done
[ -n "$TARGET" ] || { usage; exit 1; }
[ -d "$TARGET" ] || { echo "error: target dir not found: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"
MEMBER="${MEMBER:-$(basename "$TARGET")}"

DRY="[dry-run]" ; [ "$APPLY" -eq 1 ] && DRY="[apply]"
step()  { printf '\n=== %s ===\n' "$1"; }
note()  { printf '  %s\n' "$*"; }
# run "<description>" <cmd...>  — echo always; execute only under --apply
run()   { local d="$1"; shift; if [ "$APPLY" -eq 1 ]; then note "$DRY $d"; "$@"; else note "$DRY would: $d"; fi; }
fail()  { echo "BOOTSTRAP FAIL — $*" >&2; exit 1; }

printf 'bootstrap %s  target=%s  member=%s\n' "$DRY" "$TARGET" "$MEMBER"

# ── 0. ensure hf ────────────────────────────────────────────────────────────────────────────────
step "0. ensure hf (the Continuity Ledger Kernel)"
if command -v hf >/dev/null 2>&1; then
  note "hf present: $(command -v hf)"
else
  # discover meta/handoff to build from
  : "${META_ROOT:=$(cd "$TARGET" && while [ "$PWD" != / ]; do [ -f .meta.yaml ] && { echo "$PWD"; break; }; cd ..; done)}"
  [ -n "$META_ROOT" ] && [ -d "$META_ROOT/handoff" ] || fail "hf absent and meta/handoff not found (set --meta-root). Cannot build the kernel."
  note "hf absent → build from $META_ROOT/handoff + symlink ~/.local/bin/hf"
  run "cargo build --release in $META_ROOT/handoff" bash -c "cd '$META_ROOT/handoff' && cargo build --release"
  run "mkdir -p ~/.local/bin" mkdir -p "$HOME/.local/bin"
  run "symlink hf -> $META_ROOT/handoff/target/release/hf" ln -sf "$META_ROOT/handoff/target/release/hf" "$HOME/.local/bin/hf"
  if [ "$APPLY" -eq 1 ]; then command -v hf >/dev/null 2>&1 || note "WARN: ~/.local/bin not on PATH — add it, then re-run"; fi
fi

# ── 1. ensure git repo + fleet membership ─────────────────────────────────────────────────────────
step "1. ensure git repo + fleet membership (.meta.yaml)"
[ -d "$TARGET/.git" ] || fail "$TARGET is not a git repo (the kernel is Git-anchored). 'git init' first."
: "${META_ROOT:=$(cd "$TARGET" && while [ "$PWD" != / ]; do [ -f .meta.yaml ] && { echo "$PWD"; break; }; cd ..; done)}"
[ -n "$META_ROOT" ] && [ -f "$META_ROOT/.meta.yaml" ] || fail "no .meta.yaml found above $TARGET (set --meta-root); fleet discovery needs it."
META="$META_ROOT/.meta.yaml"
[ -n "$REPO_URL" ] || REPO_URL="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
if grep -qE "^[[:space:]]+${MEMBER}:" "$META" 2>/dev/null; then
  note "fleet member '$MEMBER' already in .meta.yaml"
else
  [ -n "$REPO_URL" ] || note "WARN: no git remote on $TARGET — set --repo <git-url> so the .meta.yaml entry is complete"
  ENTRY="  ${MEMBER}:\n    repo: ${REPO_URL:-git@github.com:FlexNetOS/${MEMBER}.git}"
  note "add to $META under projects::"; printf '%b\n' "$ENTRY" | sed 's/^/      /'
  if [ "$APPLY" -eq 1 ]; then
    cp "$META" "$META.bak.$$" ; note "$DRY backed up .meta.yaml -> $(basename "$META").bak.$$"
    # append under the top-level 'projects:' map (best-effort; verify structure after)
    awk -v entry="$(printf '%b' "$ENTRY")" '
      /^projects:/{print; print entry; ins=1; next} {print}
      END{ if(!ins) print "projects:\n" entry }' "$META" > "$META.tmp" && mv "$META.tmp" "$META"
    note "$DRY appended '$MEMBER' to projects: (verify the YAML)"
  fi
fi

# ── 2. kernel init (handoff-loop-init) ─────────────────────────────────────────────────────────────
step "2. kernel init — hf init + ledger-residency guard (handoff-loop-init)"
INIT="$PLUGIN/skills/handoff-loop-init/scripts/init-handoff-kernel.sh"
[ -f "$INIT" ] || fail "handoff-loop-init script missing: $INIT"
if [ "$APPLY" -eq 1 ]; then bash "$INIT" "$TARGET"; else note "$DRY would: bash handoff-loop-init/scripts/init-handoff-kernel.sh $TARGET (hf init + .gitignore residency guard)"; fi

# ── 3. eject the forge-loop harness + reconcile with the kernel .handoff/ ───────────────────────────
step "3. eject the feature-forge/forge-loop harness + reconcile"
EJECT="$PLUGIN/skills/feature-forge/scripts/eject.sh"
[ -f "$EJECT" ] || fail "feature-forge eject script missing: $EJECT"
if [ "$APPLY" -eq 1 ]; then bash "$EJECT" "$TARGET"; else note "$DRY would: bash feature-forge/scripts/eject.sh $TARGET (copy skills+agents; scaffold .handoff/loop/)"; fi
# Reconcile: the eject's file-based .handoff/loop/ COEXISTS with the kernel's .handoff/{tasks,packets,..}
# (different subdirs — no clobber). Seed loop_state.md from the template in KERNEL-BACKED pick mode.
LS_TMPL="$PLUGIN/skills/feature-forge/scripts/loop_state.template.md"
LS="$TARGET/.handoff/loop/loop_state.md"
if [ -f "$LS" ]; then note "loop_state.md present — not clobbering"; else
  run "seed .handoff/loop/loop_state.md (kernel-backed pick: hf fleet render $MEMBER) from template" \
      bash -c "[ -f '$LS_TMPL' ] && sed 's/<MEMBER>/$MEMBER/g' '$LS_TMPL' > '$LS' || true"
fi

# ── 4. wire CLAUDE.md / .gitignore / settings (kernel-backed pointer) ───────────────────────────────
step "4. wire CLAUDE.md / .gitignore / settings.json"
GI="$TARGET/.gitignore"
add_ignore() { grep -qxF "$1" "$GI" 2>/dev/null || { [ "$APPLY" -eq 1 ] && printf '%s\n' "$1" >> "$GI"; note "$DRY .gitignore += $1"; }; }
[ "$APPLY" -eq 1 ] && touch "$GI"
add_ignore '.claude/*' ; add_ignore '!.claude/agents/' ; add_ignore '!.claude/skills/'
add_ignore '.handoff/loop/*.log' ; add_ignore '.handoff/loop/ralph-run-*.log'
# (ledger residency '.handoff/ledger.db' + '.handoff/*.db' already added by step 2)
CLAUDE="$TARGET/CLAUDE.md"
if grep -q "Harness: feature-forge" "$CLAUDE" 2>/dev/null; then note "CLAUDE.md harness pointer present"; else
  note "$DRY append the kernel-backed harness pointer to CLAUDE.md (adapt invariants to THIS repo):"
  if [ "$APPLY" -eq 1 ]; then cat >> "$CLAUDE" <<EOF

## Harness: feature-forge (design→implement→verify crew + kernel-backed forge-loop)
**Trigger:** to add/build/implement/upgrade a feature use \`/feature-forge\`; to run the crew
continuously over the backlog use \`/forge-loop\`. **Kernel-backed:** \`.handoff/\` is built by the
hf Continuity Ledger Kernel (\`hf init\`); the loop picks the next dep-safe item via
\`hf fleet render ${MEMBER}\` (read-only, from \$META_ROOT) and keeps \`.handoff/loop/loop_state.md\`
for the cycle counter. Resumable via session-relay-wrap-up/-resume; self-evolving via Phase E.
**TODO (repo-specific):** fill this repo's NON-NEGOTIABLE invariants + area-prefixes; the bundled
agent/verification invariants are envctl's pure-Rust no-C/engine-first set — adapt them here.

### Toolchain & dependency discipline (meta model — READ before installing anything)
This repo lives in the **meta** workspace. Toolchains/dependencies are NOT installed globally ad hoc —
the agent must first understand **how each one is installed and WHERE it lives**, then use it in place:
- **PATH (bare names)** — meta-built tools resolve by name (e.g. \`hf\`, \`rtk\`, \`grit\`); \`~/.local/bin\`
  and \`~/.cargo/bin\` hold **symlinks INTO meta** (e.g. \`~/.local/bin/hf\` → \`\$META_ROOT/handoff/target/release/hf\`).
- **\$META_ROOT** — resolve workspace paths from the \`.meta.yaml\` marker; never hardcode \`/home/...\`.
- **Rust** — workspace/cargo deps live in the repo's \`Cargo.toml\`; do not \`cargo install\` global crates to
  satisfy a build. Language toolchains are pinned per repo (\`rust-toolchain.toml\`).
- **DO NOT** install toolchains/services globally, manage host daemons, or \`cp\` binaries into
  \`~/.cargo/bin\` to "fix" a missing tool — find where it already lives (or build it from its meta repo
  + symlink, the way \`hf\` is). Host service/process management is **outside** meta scope.
EOF
  fi
fi

# ── 5. seed the backlog ─────────────────────────────────────────────────────────────────────────────
step "5. seed .handoff/loop/backlog.md"
BL="$TARGET/.handoff/loop/backlog.md"
if [ -f "$BL" ]; then note "backlog.md present — not clobbering"; else
  note "$DRY create a backlog.md stub (replace with this repo's real roadmap)"
  if [ "$APPLY" -eq 1 ]; then mkdir -p "$(dirname "$BL")"; cat > "$BL" <<EOF
# Loop backlog — ${MEMBER}

> Legend: \`- [ ]\` todo · \`- [x]\` done (MERGED) · \`- [~]\` in-flight · \`- [!]\` blocked ·
> \`- [?]\` needs-investigation · \`- [!!]\` SUPERVISED. One item per cycle; one PR per item.

- [ ] **TASK-0001:** <replace with the first real work item for ${MEMBER}>
EOF
  fi
fi

# ── 5b. prompt: mint the backlog into hf task cards (the TASK-0044 method) ───────────────────────────
step "5b. mint cards from the backlog (drives feature-forge-kernel-engineer)"
TODO="$TARGET/.handoff/loop/MINT-CARDS-TODO.md"
TASKS_N="$(find "$TARGET/.handoff/tasks" -maxdepth 1 -name '*.task.json' 2>/dev/null | wc -l)"
if [ "${TASKS_N:-0}" -gt 0 ]; then
  note "tasks/ already has $TASKS_N card(s) — minted; skipping the prompt"
elif [ -f "$TODO" ]; then
  note "MINT-CARDS-TODO present — agent already prompted"
else
  note "$DRY .handoff/tasks/ is EMPTY → prompt the agent to mint cards (NOT auto-minted: it needs the"
  note "       kernel work-order crate + per-member residency — see references/mint-cards.md)"
  if [ "$APPLY" -eq 1 ]; then mkdir -p "$(dirname "$TODO")"
    # copy the recipe INTO the target so the reference resolves (the bootstrap skill itself is run
    # from the hub and is NOT ejected into the repo).
    [ -f "$HERE/../references/mint-cards.md" ] && cp "$HERE/../references/mint-cards.md" "$TARGET/.handoff/loop/mint-cards.md" && note "$DRY recipe -> .handoff/loop/mint-cards.md"
    cat > "$TODO" <<EOF
# NEXT STEP — mint the backlog into hf task cards ($MEMBER)

\`.handoff/tasks/\` is empty. Turn \`.handoff/loop/backlog.md\` into per-member \`handoff.task.v1\`
cards so the kernel DAG picker / \`hf fleet render $MEMBER\` are real.

**Drive the \`feature-forge-kernel-engineer\` agent** (ejected into \`.claude/agents/\`) to mint them
using the proven TASK-0044 method — see \`.handoff/loop/mint-cards.md\` (copied here by the bootstrap):
- generate cards via meta/handoff's \`work-order\` crate (\`compute_intent_lock\` → byte-identical hash),
- write \`.handoff/tasks/TASK-####.task.json\` into THIS member's store (never the FLEET dir),
- one card per backlog item with deps/blocked_by from the backlog \`## Order\`,
- verify: \`hf fleet render $MEMBER\` shows only TASK-*, 0 cross-member leak, FLEET ledger unchanged.

Delete this file once cards are minted. Do NOT use \`hf task mint --from-kb\` (KBTASK prefix →
FLEET contamination) or hand-write \`intent_lock\` (kernel will reject it).
EOF
    note "$DRY wrote $TODO (the agent's prompt to create cards)"
  fi
fi

# ── 6. verify ─────────────────────────────────────────────────────────────────────────────────────
step "6. verify"
if [ "$APPLY" -eq 1 ] && command -v hf >/dev/null 2>&1; then
  ( cd "$TARGET" && hf status 2>&1 | sed 's/^/    /' || true )
  ( cd "$META_ROOT" && note "hf fleet render $MEMBER:"; hf fleet render "$MEMBER" 2>&1 | sed 's/^/    /' | head -20 || note "(member not yet rendered — commit + let the fleet discover it)" )
else
  note "$DRY verify would run: (cd $TARGET && hf status) ; (cd $META_ROOT && hf fleet render $MEMBER)"
fi

printf '\n✓ bootstrap %s complete for %s\n' "$DRY" "$MEMBER"
[ "$APPLY" -eq 1 ] || printf '  Re-run with --apply to execute. Review the planned mutations above first.\n'
