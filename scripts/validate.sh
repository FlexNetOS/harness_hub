#!/usr/bin/env bash
# Rust-native catalog validator — replaces the former scripts/validate.py.
# Builds (if needed) and runs the hub-validate crate against the repo root.
# The FlexNetOS meta workspace is Rust-native; hub tooling is too.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
exec cargo run --quiet --release --manifest-path "$HERE/hub-validate/Cargo.toml" -- "$ROOT"
