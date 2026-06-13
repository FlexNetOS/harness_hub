#!/usr/bin/env bash
# eject.sh — install the packaged `meta-plugin` harness into a target repo's .claude/.
# SAFE: copy + scaffold only. Never edits the target's tracked files; prints the .gitignore /
# CLAUDE.md snippets for you to review and apply yourself (they are repo-specific).
#
# Usage: bash eject.sh <target-repo-dir>
set -euo pipefail

TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "usage: bash eject.sh <target-repo-dir>" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "error: target dir not found: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

# PLUGIN root = harness/ (three levels up from this script: skills/meta-plugin/scripts/)
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

SKILLS=(meta-plugin session-relay-wrap-up session-relay-resume hub-registry-sync cross-repo-health protocol-drift-scan harness-evolution)
AGENTS=(build-health-auditor integration-qa continuity-steward evolution-steward \
        meta-plugin-registry-curator meta-plugin-protocol-drift-analyst)

mkdir -p "$TARGET/.claude/skills" "$TARGET/.claude/agents" \
         "$TARGET/.handoff/loop/findings" "$TARGET/.handoff/loop/reports"

for s in "${SKILLS[@]}"; do
  cp -r "$PLUGIN/skills/$s" "$TARGET/.claude/skills/$s"
  echo "  skill  -> .claude/skills/$s"
done
for a in "${AGENTS[@]}"; do
  cp "$PLUGIN/agents/$a.md" "$TARGET/.claude/agents/$a.md"
  echo "  agent  -> .claude/agents/$a.md"
done
[ -f "$PLUGIN/skills/meta-plugin/scripts/loop_state.template.md" ] && \
  echo "  state  -> .handoff/loop/ scaffolded (seed loop_state.md from skills/meta-plugin/scripts/loop_state.template.md)"

cat <<'SNIP'

── Apply these to the target repo yourself (repo-specific; not edited for you) ──

# .gitignore — track the hand-authored harness, ignore local settings/logs:
.claude/*
!.claude/agents/
!.claude/skills/
.handoff/loop/*.log
.handoff/loop/ralph-run-*.log

# CLAUDE.md — add a harness pointer so the loop triggers in new sessions:
## Harness: meta-plugin (repo-organization loop)
**Trigger:** for repo-organization / catalog-sync / cross-repo-health / protocol-drift / "resume
the loop" tasks, use the `/meta-plugin` skill. Continuity: committed `.handoff/loop/HANDOFF.md` is the
authoritative cold-resume signal. Runner: `.claude/skills/meta-plugin/scripts/ralph-meta-plugin.sh`
(SAFE by default).

Done. Invoke the ejected harness in the target repo as: /meta-plugin
SNIP
