#!/usr/bin/env bash
# eject.sh — install the packaged `code-research` harness into a target repo's .claude/.
# SAFE: copy + scaffold only (and the harness is read-only on the target's code). Prints the
# .gitignore / CLAUDE.md snippets to apply. Usage: bash eject.sh <target-repo-dir>
set -euo pipefail
TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "usage: bash eject.sh <target-repo-dir>" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "error: target dir not found: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"  # harness/

SKILLS=(code-research code-research-map code-research-analyze code-research-verify session-relay-wrap-up session-relay-resume harness-loop-init harness-evolution)
AGENTS=(code-research-cartographer code-research-analyst code-research-verifier code-research-synthesizer \
        continuity-steward evolution-steward)

mkdir -p "$TARGET/.claude/skills" "$TARGET/.claude/agents" \
         "$TARGET/.handoff/loop/findings" "$TARGET/.handoff/loop/reports"
for s in "${SKILLS[@]}"; do cp -r "$PLUGIN/skills/$s" "$TARGET/.claude/skills/$s"; echo "  skill  -> .claude/skills/$s"; done
for a in "${AGENTS[@]}"; do cp "$PLUGIN/agents/$a.md" "$TARGET/.claude/agents/$a.md"; echo "  agent  -> .claude/agents/$a.md"; done
echo "  state  -> .handoff/loop/ scaffolded (seed loop_state.md: research_question + target_root)"

cat <<'SNIP'

── Apply to the target repo yourself (repo-specific; not edited for you) ──

# .gitignore:
.claude/*
!.claude/agents/
!.claude/skills/
.handoff/loop/*.log
.handoff/loop/ralph-run-*.log

# CLAUDE.md pointer:
## Harness: code-research (deep code research & analysis)
**Trigger:** for "analyze this codebase / what is it / is it an X / deep code research / resume the
analysis", use the `/code-research` skill. Read-only; adversarially-verified, cited findings.

Done. Invoke as: /code-research
SNIP
