//! Rust-native validator for a FlexNetOS hub catalog.
//!
//! Part of the Hub Standard (see template_hub/docs/hub-standard.md). This is the
//! Rust-native replacement for the former dependency-on-Python `scripts/validate.py`
//! — the FlexNetOS meta workspace is Rust-native, so hub tooling is too.
//!
//! Checks: required top-level keys, required entry fields, enum membership,
//! unique kebab-case ids, referenced files exist, and the README links each entry.
//! Exits non-zero on any problem.
//!
//! Usage: `hub-validate [REPO_ROOT]` (defaults to the current working directory).

use serde_json::Value;
use std::collections::BTreeSet;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::exit;

// ─── per-hub constants ──────────────────────────────────────────────────────
const COLLECTION: &str = "harnesses"; // registry.json array key
// Hosting middle value for nested-meta children, or None if this hub hosts none.
const CHILD_TOKEN: Option<&str> = None;
const BASE_REQUIRED: &[&str] = &["id", "displayName", "status", "summary", "doc"];
const BESPOKE_REQUIRED: &[&str] = &["category"];
const FILE_REF_FIELDS: &[&str] = &["doc", "snippet"]; // repo-relative paths that must exist

fn enums(field: &str) -> Option<&'static [&'static str]> {
    match field {
        "status" => Some(&["stable", "beta", "experimental", "deprecated"]),
        "category" => Some(&["agent-runtime", "harness-toolkit", "skills-framework", "orchestrator"]),
        "runtime" => Some(&["node", "rust", "bun", "python", "multi"]),
        "hosting" => Some(&["peer", "registry-only"]),
        _ => None,
    }
}
// ──────────────────────────────────────────────────────────────────────────────

fn is_kebab(id: &str) -> bool {
    let mut chars = id.chars();
    match chars.next() {
        Some(c) if c.is_ascii_lowercase() || c.is_ascii_digit() => {}
        _ => return false,
    }
    id.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-')
}

fn main() {
    let root: PathBuf = env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| env::current_dir().expect("cwd"));

    let reg_path = root.join("registry.json");
    let reg_text = match fs::read_to_string(&reg_path) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("FATAL: cannot read {}: {e}", reg_path.display());
            exit(1);
        }
    };
    let reg: Value = match serde_json::from_str(&reg_text) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("FATAL: registry.json is not valid JSON: {e}");
            exit(1);
        }
    };

    let mut errors: Vec<String> = Vec::new();
    let mut err = |m: String| errors.push(m);

    for key in ["version", "updated", "org", "hub", COLLECTION] {
        if reg.get(key).is_none() {
            err(format!("registry.json missing top-level key: {key}"));
        }
    }

    let hub = reg.get("hub").and_then(Value::as_str).unwrap_or("?");
    let readme = fs::read_to_string(root.join("README.md")).unwrap_or_default();
    let meta_yaml = fs::read_to_string(root.join(".meta.yaml")).ok();

    let empty = Vec::new();
    let entries = reg.get(COLLECTION).and_then(Value::as_array).unwrap_or(&empty);
    let mut seen: BTreeSet<String> = BTreeSet::new();

    for (i, e) in entries.iter().enumerate() {
        let eid = e
            .get("id")
            .and_then(Value::as_str)
            .map(str::to_string)
            .unwrap_or_else(|| format!("<index {i}>"));

        for field in BASE_REQUIRED.iter().chain(BESPOKE_REQUIRED) {
            if e.get(*field).is_none() {
                err(format!("[{eid}] missing required field: {field}"));
            }
        }

        if let Some(id) = e.get("id").and_then(Value::as_str) {
            if !is_kebab(id) {
                err(format!("[{eid}] id is not kebab-case: {id:?}"));
            }
            if !seen.insert(id.to_string()) {
                err(format!("[{eid}] duplicate id"));
            }
        }

        for field in ["status", "category", "runtime", "hosting"] {
            if let Some(val) = e.get(field).and_then(Value::as_str) {
                if let Some(allowed) = enums(field) {
                    if !allowed.contains(&val) {
                        err(format!("[{eid}] {field}={val:?} not in {allowed:?}"));
                    }
                }
            }
        }

        for refk in FILE_REF_FIELDS {
            if let Some(rel) = e.get(*refk).and_then(Value::as_str) {
                if !Path::new(&root).join(rel).exists() {
                    err(format!("[{eid}] {refk} file not found: {rel}"));
                }
            }
        }

        if let Some(token) = CHILD_TOKEN {
            if e.get("hosting").and_then(Value::as_str) == Some(token) {
                match e.get("subPath").and_then(Value::as_str) {
                    None => err(format!("[{eid}] hosting={token} requires 'subPath'")),
                    Some(sub) => match &meta_yaml {
                        None => err(format!("[{eid}] hosting={token} but .meta.yaml is missing")),
                        Some(my) if !my.contains(&format!("{sub}:")) => {
                            err(format!("[{eid}] '{sub}' not listed as a project in .meta.yaml"))
                        }
                        _ => {}
                    },
                }
            }
        }

        if !readme.is_empty() {
            for refk in ["doc", "snippet"] {
                if let Some(rel) = e.get(refk).and_then(Value::as_str) {
                    if !readme.contains(rel) {
                        err(format!("[{eid}] README.md does not link {refk}: {rel}"));
                    }
                }
            }
        }
    }

    if !errors.is_empty() {
        println!("✗ {} problem(s) in the {hub} catalog:\n", errors.len());
        for e in &errors {
            println!("  - {e}");
        }
        exit(1);
    }

    println!("✓ {hub} OK — {} entries, all valid and consistent.", entries.len());
}
