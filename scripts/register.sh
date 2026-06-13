#!/usr/bin/env bash
# register.sh — register a harness into the harness_hub catalog (Rust-native, via the hub-validate
# crate's `register` subcommand). Inverse of skills/meta-plugin/scripts/eject.sh.
#
# Appends a validated registry.json row, scaffolds entries/<id>.md if missing, inserts a README
# Catalog row, bumps `updated` to today, then runs validation (fail-closed). Pass-through flags go
# straight to the Rust registrar.
#
# Usage:
#   bash scripts/register.sh --id <id> --display "<name>" --category <cat> --status <s> \
#        --summary "<text>" [--runtime <r>] [--hosting peer|registry-only] [--repo <git-url>] \
#        [--member <workspace-name>] [--homepage <url>] [--tags a,b,c] [--path <p>] [--doc <p>] \
#        [--notes "<text>"]
#
# Pointer example (catalog an external/peer repo, e.g. meta/handoff):
#   bash scripts/register.sh --id handoff --display "handoff (continuity kernel)" \
#     --category orchestrator --status beta --runtime multi --hosting peer \
#     --repo git@github.com:FlexNetOS/handoff.git --member handoff \
#     --summary "FlexNetOS handoff/continuity kernel — hf + .handoff/ witnessed ledger."
#
# Packaged example (a vendored /harness:<name>): also copy the skill+agents into the plugin first
# (see docs/packaged-harness-standard.md), then register with --hosting registry-only --path harness/skills/<name>.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

# Default `updated` to today (UTC) unless the caller passed --updated; the shell reads the clock
# so the Rust core stays deterministic.
EXTRA=()
case " $* " in *" --updated "*) ;; *) EXTRA=(--updated "$(date -u +%F)") ;; esac

exec cargo run --quiet --release --manifest-path "$HERE/hub-validate/Cargo.toml" -- \
  register --root "$ROOT" "$@" "${EXTRA[@]}"
