#!/usr/bin/env bash
# eject.sh — install the packaged `feature-forge` harness into a target Rust repo's .claude/.
# SAFE: copy + scaffold only. Never edits the target's tracked files; prints the .gitignore /
# CLAUDE.md snippets for you to apply.
#
# Usage: bash eject.sh <target-repo-dir>
set -euo pipefail
TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "usage: bash eject.sh <target-repo-dir>" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "error: target dir not found: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"  # harness/

SKILLS=(feature-forge forge-loop rust-feature-impl session-relay-wrap-up session-relay-resume harness-loop-init harness-evolution icm-memory)
AGENTS=(feature-forge-architect feature-forge-implementer feature-forge-guardian feature-forge-kernel-engineer \
        evolution-steward continuity-steward)

mkdir -p "$TARGET/.claude/skills" "$TARGET/.claude/agents" \
         "$TARGET/.handoff/loop/findings" "$TARGET/.handoff/loop/reports"
for s in "${SKILLS[@]}"; do cp -r "$PLUGIN/skills/$s" "$TARGET/.claude/skills/$s"; echo "  skill  -> .claude/skills/$s"; done
for a in "${AGENTS[@]}"; do cp "$PLUGIN/agents/$a.md" "$TARGET/.claude/agents/$a.md"; echo "  agent  -> .claude/agents/$a.md"; done
echo "  state  -> .handoff/loop/ scaffolded (seed loop_state.md from skills/feature-forge/scripts/loop_state.template.md; create backlog.md from your roadmap)"

cat <<'SNIP'

── Apply these to the target repo yourself (repo-specific; not edited for you) ──

# .gitignore:
.claude/*
!.claude/agents/
!.claude/skills/
.handoff/loop/*.log
.handoff/loop/ralph-run-*.log

# CLAUDE.md pointer:
## Harness: feature-forge (design→implement→verify construction crew + Ralph loop)
**Trigger:** to add/build/implement/upgrade a feature, use the `/feature-forge` skill; to run the
crew continuously over a backlog, use `/forge-loop`. The crew is architect→implementer→guardian
(Phase 3.5 runtime-verify, Unit-ledger completeness, A2 cross-repo all-green barrier), self-evolving
via Phase E (evolution-steward). Resumable via session-relay-wrap-up/-resume.
Runner: .claude/skills/feature-forge/scripts/ralph-feature-forge.sh (SAFE by default).
NOTE: adapt the invariant set in the agent defs + rust-feature-impl to THIS repo's CLAUDE.md
(the bundled invariants are envctl's pure-Rust no-C/engine-first set). The envctl-specific loops
(env-install-loop, auto-provision, handoff-sync) are NOT bundled — they remain envctl extensions.

# .claude/settings.json — DETERMINISTIC pre-session memory priming (recommended).
# Fires at every session start with NO model decision, so the agent is primed with prior context
# (decisions, resolved errors, gotchas) before its first token. The `icm-memory` skill is the
# as-needed complement (the model recalls/stores mid-task). Within the meta workspace this is
# inherited from user-global settings; OUTSIDE it, add this so the priming travels with the harness.
# Graceful no-op when ICM is absent (`command -v icm` guard + `|| true`).
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          { "type": "command",
            "command": "command -v icm >/dev/null && icm recall-context \"feature-forge resume: prior decisions, resolved errors, gate/parity gotchas for this repo\" --limit 8 2>/dev/null || true" }
        ]
      }
    ]
  }
}

Done. Invoke the ejected harness as: /feature-forge  (continuous: /forge-loop)
SNIP
