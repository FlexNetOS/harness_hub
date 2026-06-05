#!/usr/bin/env python3
"""Validate a FlexNetOS hub catalog.

Part of the Hub Standard (see template_hub/docs/hub-standard.md). This file is COPIED
into each hub; only the per-hub constants block below changes. Dependency-free (stdlib).
Checks: required fields, enum membership, unique kebab-case ids, referenced files exist
(and parse as JSON where required), README links each entry, and — for hubs that host
nested-meta children — that `subPath` appears in .meta.yaml. Exits non-zero on any problem.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# ─── per-hub constants ────────────────────────────────────────────────────────
COLLECTION = "harnesses"                    # registry.json array key
CHILD_TOKEN = None                          # hosting middle value, or None if this hub hosts nothing
BASE_REQUIRED = ["id", "displayName", "status", "summary", "doc"]
BESPOKE_REQUIRED = ["category"]
ENUMS = {
    "status": {"stable", "beta", "experimental", "deprecated"},
    "category": {"agent-runtime", "harness-toolkit", "skills-framework", "orchestrator"},
    "runtime": {"node", "rust", "bun", "python", "multi"},
    "hosting": {"peer", "registry-only"},
}
FILE_REF_FIELDS = ["doc", "snippet"]        # values are repo-relative paths that must exist
JSON_REF_FIELDS = []                        # file-ref fields that must additionally parse as JSON
# ──────────────────────────────────────────────────────────────────────────────

ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
errors = []


def err(msg):
    errors.append(msg)


def main():
    try:
        reg = json.loads((ROOT / "registry.json").read_text())
    except (OSError, json.JSONDecodeError) as e:
        print(f"FATAL: cannot read registry.json: {e}")
        return 1

    for key in ("version", "updated", "org", "hub", COLLECTION):
        if key not in reg:
            err(f"registry.json missing top-level key: {key}")

    entries = reg.get(COLLECTION, [])
    readme = (ROOT / "README.md").read_text() if (ROOT / "README.md").exists() else ""
    seen = set()

    for i, e in enumerate(entries):
        eid = e.get("id", f"<index {i}>")
        for field in BASE_REQUIRED + BESPOKE_REQUIRED:
            if field not in e:
                err(f"[{eid}] missing required field: {field}")

        if "id" in e:
            if not ID_RE.match(e["id"]):
                err(f"[{eid}] id is not kebab-case: {e['id']!r}")
            if e["id"] in seen:
                err(f"[{eid}] duplicate id")
            seen.add(e["id"])

        for field, allowed in ENUMS.items():
            if field in e and e[field] not in allowed:
                err(f"[{eid}] {field}={e[field]!r} not in {sorted(allowed)}")

        for ref in FILE_REF_FIELDS:
            if ref in e:
                p = ROOT / e[ref]
                if not p.exists():
                    err(f"[{eid}] {ref} file not found: {e[ref]}")
                elif ref in JSON_REF_FIELDS:
                    try:
                        json.loads(p.read_text())
                    except json.JSONDecodeError as je:
                        err(f"[{eid}] {ref} is not valid JSON: {je}")

        if CHILD_TOKEN and e.get("hosting") == CHILD_TOKEN:
            sub = e.get("subPath")
            if not sub:
                err(f"[{eid}] hosting={CHILD_TOKEN} requires 'subPath'")
            elif not (ROOT / ".meta.yaml").exists():
                err(f"[{eid}] hosting={CHILD_TOKEN} but .meta.yaml is missing")
            elif f"{sub}:" not in (ROOT / ".meta.yaml").read_text():
                err(f"[{eid}] '{sub}' not listed as a project in .meta.yaml")

        if readme:
            for ref in ("doc", "snippet"):
                if ref in e and e[ref] not in readme:
                    err(f"[{eid}] README.md does not link {ref}: {e[ref]}")

    if errors:
        print(f"✗ {len(errors)} problem(s) in the {reg.get('hub', '?')} catalog:\n")
        for e in errors:
            print(f"  - {e}")
        return 1

    print(f"✓ {reg.get('hub', '?')} OK — {len(entries)} entries, all valid and consistent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
