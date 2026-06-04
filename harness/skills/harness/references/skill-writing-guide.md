# Skill Writing Guide

A detailed guide for improving the quality of skills created in the harness. Supplementary reference for SKILL.md Phase 4.

---

## Table of Contents

1. [Description Writing Patterns](#1-description-writing-patterns)
2. [Body Writing Style](#2-body-writing-style)
3. [Output Format Definition Patterns](#3-output-format-definition-patterns)
4. [Example Writing Patterns](#4-example-writing-patterns)
5. [Progressive Disclosure Patterns](#5-progressive-disclosure-patterns)
6. [Script Bundling Decision Criteria](#6-script-bundling-decision-criteria)
7. [Data Schema Standards](#7-data-schema-standards)
8. [What Not to Include in a Skill](#8-what-not-to-include-in-a-skill)

---

## 1. Description Writing Patterns

The description is the skill's sole trigger mechanism. Claude sees only the name + description from the `available_skills` list when deciding whether to invoke a skill.

### Understanding the Trigger Mechanism

Claude tends not to invoke skills for simple tasks it can handle easily with its built-in tools. A plain request like "read this PDF for me" may not trigger a skill even if the description is perfect. The more complex, multi-step, and specialized the task, the higher the probability of a skill being triggered.

### Writing Principles

1. Describe **what the skill does** + **the specific situations that should trigger it**
2. Explicitly state boundary conditions that distinguish similar-but-should-not-trigger cases
3. Be slightly "pushy" — compensate for Claude's tendency to trigger conservatively

### Good Examples

```yaml
description: "Handles all PDF tasks including reading PDF files, extracting text/tables,
  merging, splitting, rotating, watermarking, encrypting/decrypting, and OCR.
  When the user mentions a .pdf file or requests a PDF artifact, always use
  this skill. Especially useful when conversion, editing, or analysis is needed
  — not merely a request to 'read' a PDF."
```

```yaml
description: "Handles all spreadsheet tasks including adding columns, calculating
  formulas, formatting, charts, and data cleaning for Excel/CSV/TSV files.
  When the user mentions a spreadsheet file — even casually ('the xlsx in
  my Downloads folder') — use this skill."
```

### Bad Examples

- `"A skill that processes data"` — too vague, unclear what files/tasks are involved
- `"PDF-related tasks"` — no specific actions listed, trigger situations not described

---

## 2. Body Writing Style

### Why-First Principle

When an LLM understands the reason, it makes correct decisions even in edge cases. Conveying context is more effective than imposing rigid rules.

**Bad example:**
```markdown
ALWAYS use pdfplumber for table extraction. NEVER use PyPDF2 for tables.
```

**Good example:**
```markdown
Use pdfplumber for table extraction. PyPDF2 is specialized for text extraction
and cannot preserve the row/column structure of tables. pdfplumber recognizes
cell boundaries and returns structured data.
```

### Generalization Principle

When a problem is found in feedback or test results, instead of a narrow fix tailored to that specific example, **generalize at the level of principle**.

**Overfitted fix:**
```markdown
If there is a column named "Q4 Revenue", convert that column to a number.
```

**Generalized fix:**
```markdown
If a column name contains keywords implying numeric values — such as "revenue",
"amount", or "quantity" — convert that column to a numeric type.
Retain the original value if conversion fails.
```

### Imperative Tone

Use direct imperative forms ("use", "do", "return") rather than hedged forms ("you can", "it is possible to"). A skill is a set of instructions.

### Context Economy

The context window is a shared resource. Ask whether every sentence justifies its token cost:
- "Does Claude already know this?" → Delete it
- "Would Claude make mistakes without this explanation?" → Keep it
- "Is one concrete example more effective than a long description?" → Replace with an example

---

## 3. Output Format Definition Patterns

Use this in skills where the format of the output matters:

```markdown
## Report Structure
Follow this template exactly:

# [Title]
## Summary
## Key Findings
## Recommendations
```

Keep format definitions concise; including a real example makes them even more effective.

---

## 4. Example Writing Patterns

Examples are more effective than long descriptions:

```markdown
## Commit Message Format

**Example 1:**
Input: Add JWT token-based user authentication
Output: feat(auth): implement JWT-based authentication

**Example 2:**
Input: Fix bug where the show-password button on the login page does not work
Output: fix(login): repair password visibility toggle button behavior
```

---

## 5. Progressive Disclosure Patterns

### Pattern 1: Domain-Based Separation

```
bigquery-skill/
├── SKILL.md (overview + domain selection guide)
└── references/
    ├── finance.md (revenue, billing metrics)
    ├── sales.md (opportunities, pipeline)
    └── product.md (API usage, features)
```

When the user asks about revenue, load only finance.md.

### Pattern 2: Conditional Detail

```markdown
# DOCX Processing

## Document Creation
Create a new document with docx-js. → See [DOCX-JS.md](references/docx-js.md).

## Document Editing
For simple edits, modify the XML directly.
**If tracked changes are needed**: See [REDLINING.md](references/redlining.md)
```

### Pattern 3: Large Reference File Structure

Reference files longer than 300 lines should include a table of contents at the top:

```markdown
# API Reference

## Table of Contents
1. [Authentication](#authentication)
2. [Endpoint List](#endpoint-list)
3. [Error Codes](#error-codes)
4. [Rate Limits](#rate-limits)

---

## Authentication
...
```

---

## 6. Script Bundling Decision Criteria

Observe agent transcripts during test runs. The following patterns indicate a bundling candidate:

| Signal | Action |
|--------|--------|
| Same helper script created in 3 out of 3 tests | Bundle into `scripts/` |
| Same pip install/npm install executed every time | Document the dependency installation step in the skill |
| Same multi-step approach repeated every time | Describe it as the standard procedure in the skill body |
| Similar error followed by the same workaround each time | Document the known issue and fix in the skill |

Bundled scripts must pass an execution test before being included.

---

## 7. Data Schema Standards

Use standard schemas for consistency in data exchange between skills. These can be used for testing and evaluating skills created in the harness.

### eval_metadata.json

Metadata for each test case:

```json
{
  "eval_id": 0,
  "eval_name": "descriptive-name-here",
  "prompt": "The user's task prompt",
  "assertions": [
    "The output contains X",
    "A file was created in format Y"
  ]
}
```

### grading.json

Assertion-based grading results:

```json
{
  "expectations": [
    {
      "text": "The output contains 'Seoul'",
      "passed": true,
      "evidence": "Confirmed 'Extract Seoul regional data' at step 3"
    }
  ],
  "summary": {
    "passed": 2,
    "failed": 1,
    "total": 3,
    "pass_rate": 0.67
  }
}
```

**Field name note:** Use `text`, `passed`, and `evidence` exactly — do not use variants such as `name`/`met`/`details`.

### timing.json

Execution time and token measurements:

```json
{
  "total_tokens": 84852,
  "duration_ms": 23332,
  "total_duration_seconds": 23.3
}
```

Save `total_tokens` and `duration_ms` immediately from the sub-agent completion notification. This data is only accessible at the moment of notification and cannot be recovered afterward.

---

## 8. What Not to Include in a Skill

- Supplementary documents such as README.md, CHANGELOG.md, INSTALLATION_GUIDE.md
- Meta-information from the skill creation process (test results, iteration history)
- User-facing documentation (a skill is a set of instructions for an AI agent, not a person)
- General knowledge that Claude already knows

---

## 9. Skill Reuse Design

Before creating a new skill, check for overlap with existing skills. When building harnesses iteratively, it is easy for skills with overlapping functionality to accumulate under different names.

| Situation | Action |
|-----------|--------|
| Existing skill fully covers the new functionality | Do not create a new one — connect the existing skill to the agent |
| Existing skill partially covers it and can be generalized | Generalize and extend the existing skill |
| Partial overlap is an intentional domain specialization | Proceed with creation — keep it as a separate skill |
| Functionality scope is completely different | Proceed with creation |

**Principle:** The more a single skill focuses on a single role, the higher its reusability and the less duplication accumulates. If a skill has two or more roles, first consider whether it can be split.

### How Far to Generalize

Generalization can go on indefinitely, so stop at the **intended scope of responsibility**. Preserve intentional domain specialization; remove only accidental dependencies.

Example: "Fintech risk assessment PDF" skill

| Step | Result |
|------|--------|
| Remove fintech dependency | "Assessment result PDF" — if the scope is assessment reports, stop here |
| Remove assessment dependency | "PDF formatting" — if this already exists, reuse it rather than creating a new skill |

If the scope is intentionally specialized as "fintech risk assessment," do not generalize — keep it as a separate skill.

Note that the behavior of agents that depend on the skill may change. Verify dependencies before extending, and update the description to reflect the expanded scope of use.
