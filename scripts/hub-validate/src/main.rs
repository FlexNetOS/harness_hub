//! Rust-native validator + registrar for a FlexNetOS hub catalog.
//!
//! Part of the Hub Standard (see template_hub/docs/hub-standard.md). The FlexNetOS meta workspace
//! is Rust-native, so hub tooling is too (this replaced the former `scripts/validate.py`).
//!
//! Subcommands:
//!   hub-validate [REPO_ROOT]              validate the catalog (default; REPO_ROOT defaults to cwd)
//!   hub-validate register --id <id> ...   add a harness to the catalog, then validate
//!
//! `register` appends a row to registry.json (order-preserving), scaffolds entries/<id>.md if
//! missing, inserts a README Catalog row, optionally bumps `updated`, then runs validation.

use serde_json::{Map, Value};
use std::collections::BTreeSet;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::exit;

// ─── per-hub constants ──────────────────────────────────────────────────────
const COLLECTION: &str = "harnesses";
const CHILD_TOKEN: Option<&str> = None;
const BASE_REQUIRED: &[&str] = &["id", "displayName", "status", "summary", "doc"];
const BESPOKE_REQUIRED: &[&str] = &["category"];
const FILE_REF_FIELDS: &[&str] = &["doc", "snippet"];

fn enums(field: &str) -> Option<&'static [&'static str]> {
    match field {
        "status" => Some(&["stable", "beta", "experimental", "deprecated"]),
        "category" => Some(&[
            "agent-runtime",
            "harness-toolkit",
            "skills-framework",
            "orchestrator",
        ]),
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
    id.chars()
        .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-')
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.first().map(String::as_str) == Some("register") {
        register(&args[1..]);
    } else {
        let root = args
            .first()
            .map(PathBuf::from)
            .unwrap_or_else(|| env::current_dir().expect("cwd"));
        run_validate_and_report(&root);
    }
}

// ── validate ────────────────────────────────────────────────────────────────

fn run_validate_and_report(root: &Path) {
    let (errors, count, hub) = match validate(root) {
        Ok(t) => t,
        Err(fatal) => {
            eprintln!("{fatal}");
            exit(1);
        }
    };
    if !errors.is_empty() {
        println!("✗ {} problem(s) in the {hub} catalog:\n", errors.len());
        for e in &errors {
            println!("  - {e}");
        }
        exit(1);
    }
    println!("✓ {hub} OK — {count} entries, all valid and consistent.");
}

/// Returns (errors, entry_count, hub_name) on success, or a fatal message on read/parse failure.
fn validate(root: &Path) -> Result<(Vec<String>, usize, String), String> {
    let reg_path = root.join("registry.json");
    let reg_text = fs::read_to_string(&reg_path)
        .map_err(|e| format!("FATAL: cannot read {}: {e}", reg_path.display()))?;
    let reg: Value = serde_json::from_str(&reg_text)
        .map_err(|e| format!("FATAL: registry.json is not valid JSON: {e}"))?;

    let mut errors: Vec<String> = Vec::new();
    let mut err = |m: String| errors.push(m);

    for key in ["version", "updated", "org", "hub", COLLECTION] {
        if reg.get(key).is_none() {
            err(format!("registry.json missing top-level key: {key}"));
        }
    }

    let hub = reg
        .get("hub")
        .and_then(Value::as_str)
        .unwrap_or("?")
        .to_string();
    let readme = fs::read_to_string(root.join("README.md")).unwrap_or_default();
    let meta_yaml = fs::read_to_string(root.join(".meta.yaml")).ok();

    let empty = Vec::new();
    let entries = reg
        .get(COLLECTION)
        .and_then(Value::as_array)
        .unwrap_or(&empty);
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
                if !root.join(rel).exists() {
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
                        Some(my) if !my.contains(&format!("{sub}:")) => err(format!(
                            "[{eid}] '{sub}' not listed as a project in .meta.yaml"
                        )),
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

    Ok((errors, entries.len(), hub))
}

// ── register ──────────────────────────────────────────────────────────────────

fn parse_flags(args: &[String]) -> HashMap<String, String> {
    let mut m = HashMap::new();
    let mut i = 0;
    while i < args.len() {
        if let Some(key) = args[i].strip_prefix("--") {
            let val = args.get(i + 1).cloned().unwrap_or_default();
            m.insert(key.to_string(), val);
            i += 2;
        } else {
            i += 1;
        }
    }
    m
}

fn register(args: &[String]) {
    let f = parse_flags(args);
    let get = |k: &str| f.get(k).filter(|v| !v.is_empty()).cloned();
    let req = |k: &str| match get(k) {
        Some(v) => v,
        None => {
            eprintln!("register: missing required --{k}");
            exit(2);
        }
    };

    let root = get("root")
        .map(PathBuf::from)
        .unwrap_or_else(|| env::current_dir().expect("cwd"));
    let id = req("id");
    if !is_kebab(&id) {
        eprintln!("register: --id must be kebab-case: {id:?}");
        exit(2);
    }
    let display = req("display");
    let category = req("category");
    let status = req("status");
    let summary = req("summary");
    let doc = get("doc").unwrap_or_else(|| format!("entries/{id}.md"));

    // Validate enum choices up front for a friendly error.
    for (field, val) in [("category", &category), ("status", &status)] {
        if !enums(field).unwrap().contains(&val.as_str()) {
            eprintln!(
                "register: --{field} {val:?} not in {:?}",
                enums(field).unwrap()
            );
            exit(2);
        }
    }
    for opt in ["runtime", "hosting"] {
        if let Some(v) = get(opt) {
            if !enums(opt).unwrap().contains(&v.as_str()) {
                eprintln!("register: --{opt} {v:?} not in {:?}", enums(opt).unwrap());
                exit(2);
            }
        }
    }

    // Read + parse registry.json (order-preserving via preserve_order feature).
    let reg_path = root.join("registry.json");
    let reg_text = fs::read_to_string(&reg_path).unwrap_or_else(|e| {
        eprintln!("register: cannot read {}: {e}", reg_path.display());
        exit(1);
    });
    let mut reg: Value = serde_json::from_str(&reg_text).unwrap_or_else(|e| {
        eprintln!("register: registry.json is not valid JSON: {e}");
        exit(1);
    });

    {
        let arr = reg
            .get_mut(COLLECTION)
            .and_then(Value::as_array_mut)
            .unwrap_or_else(|| {
                eprintln!("register: registry.json has no '{COLLECTION}' array");
                exit(1);
            });
        if arr
            .iter()
            .any(|e| e.get("id").and_then(Value::as_str) == Some(id.as_str()))
        {
            eprintln!("register: id '{id}' already exists in the catalog (refusing to duplicate)");
            exit(1);
        }

        // Build the entry in a stable, readable key order.
        let mut entry = Map::new();
        entry.insert("id".into(), Value::String(id.clone()));
        entry.insert("displayName".into(), Value::String(display.clone()));
        entry.insert("category".into(), Value::String(category.clone()));
        entry.insert("status".into(), Value::String(status.clone()));
        entry.insert("summary".into(), Value::String(summary.clone()));
        if let Some(tags) = get("tags") {
            let list: Vec<Value> = tags
                .split(',')
                .map(|t| t.trim())
                .filter(|t| !t.is_empty())
                .map(|t| Value::String(t.to_string()))
                .collect();
            if !list.is_empty() {
                entry.insert("tags".into(), Value::Array(list));
            }
        }
        for (k, flag) in [
            ("runtime", "runtime"),
            ("homepage", "homepage"),
            ("hosting", "hosting"),
            ("repo", "repo"),
            ("workspaceMember", "member"),
            ("path", "path"),
            ("notes", "notes"),
        ] {
            if let Some(v) = get(flag) {
                entry.insert(k.into(), Value::String(v));
            }
        }
        entry.insert("doc".into(), Value::String(doc.clone()));
        arr.push(Value::Object(entry));
    }

    // Optionally bump `updated` (the caller supplies the date; the shell wrapper reads the clock).
    if let Some(updated) = get("updated") {
        if let Some(obj) = reg.as_object_mut() {
            obj.insert("updated".into(), Value::String(updated));
        }
    }

    // Write registry.json back (pretty, trailing newline).
    let mut out = serde_json::to_string_pretty(&reg).expect("serialize");
    out.push('\n');
    fs::write(&reg_path, out).unwrap_or_else(|e| {
        eprintln!("register: cannot write {}: {e}", reg_path.display());
        exit(1);
    });
    println!("  registry.json  + {id}");

    // Scaffold the entry doc if missing.
    let doc_path = root.join(&doc);
    if doc_path.exists() {
        println!("  {doc}  (exists — left as-is)");
    } else {
        if let Some(parent) = doc_path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let runtime_bit = get("runtime")
            .map(|r| format!(" · **Runtime:** {r}"))
            .unwrap_or_default();
        let repo_bit = get("repo")
            .map(|r| format!(" · **Repo:** `{r}`"))
            .unwrap_or_default();
        let stub = format!(
            "# {display}\n\n**Category:** {category} · **Status:** {status}{runtime_bit}{repo_bit}\n\n{summary}\n\n<!-- TODO: expand — what it is, how to use, key commands/entry points. -->\n"
        );
        fs::write(&doc_path, stub).unwrap_or_else(|e| {
            eprintln!("register: cannot write {}: {e}", doc_path.display());
            exit(1);
        });
        println!("  {doc}  (scaffolded)");
    }

    // Insert a README Catalog row after the last existing table row.
    let readme_path = root.join("README.md");
    if let Ok(readme) = fs::read_to_string(&readme_path) {
        let runtime_cell = get("runtime").unwrap_or_else(|| "—".to_string());
        let row =
            format!("| [{id}]({doc}) | {category} | {runtime_cell} | {status} | [doc]({doc}) |");
        if readme.contains(&format!("[{id}]({doc})")) {
            println!("  README.md  (row already present)");
        } else {
            let mut lines: Vec<String> = readme.lines().map(String::from).collect();
            match lines
                .iter()
                .rposition(|l| l.trim_start().starts_with("| ["))
            {
                Some(idx) => {
                    lines.insert(idx + 1, row);
                    let mut joined = lines.join("\n");
                    if readme.ends_with('\n') {
                        joined.push('\n');
                    }
                    fs::write(&readme_path, joined).unwrap_or_else(|e| {
                        eprintln!("register: cannot write README.md: {e}");
                        exit(1);
                    });
                    println!("  README.md  + Catalog row");
                }
                None => println!("  README.md  (no Catalog table found — add the row manually)"),
            }
        }
    }

    // Validate the result.
    println!("  validating…");
    run_validate_and_report(&root);
}
