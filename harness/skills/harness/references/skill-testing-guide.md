# Skill Testing & Iterative Improvement Guide

A methodology for validating and iteratively improving the quality of skills created by the harness. Supplementary reference for SKILL.md Phase 6.

---

## Table of Contents

1. [Testing Framework Overview](#1-testing-framework-overview)
2. [Writing Test Prompts](#2-writing-test-prompts)
3. [Execution Testing: With-skill vs Baseline](#3-execution-testing-with-skill-vs-baseline)
4. [Quantitative Evaluation: Assertion-Based Scoring](#4-quantitative-evaluation-assertion-based-scoring)
5. [Using Specialized Agents](#5-using-specialized-agents)
6. [Iterative Improvement Loop](#6-iterative-improvement-loop)
7. [Description Trigger Validation](#7-description-trigger-validation)
8. [Workspace Structure](#8-workspace-structure)

---

## 1. Testing Framework Overview

Skill quality validation is a combination of **qualitative evaluation** and **quantitative evaluation**.

| Evaluation Type | Method | Best For |
|----------------|--------|----------|
| **Qualitative** | User directly reviews output | Subjective quality: writing style, design, creative work, etc. |
| **Quantitative** | Assertion-based automated scoring | Objectively verifiable outcomes: file generation, data extraction, code generation, etc. |

Core loop: **Write → Run Tests → Evaluate → Improve → Retest**

---

## 2. Writing Test Prompts

### Principles

Test prompts should be **specific and natural sentences that a real user would actually type**. Abstract or artificial prompts have low test value.

### Bad Examples

```
"Process the PDF"
"Extract the data"
"Generate a chart"
```

### Good Examples

```
"In the file 'Q4_Sales_Final_v2.xlsx' in my Downloads folder, use column C (Revenue)
and column D (Cost) to add a profit margin (%) column. Then sort descending by profit margin."
```

```
"Extract the table on page 3 of this PDF and convert it to CSV. The table header spans
two rows — the first row is the category and the second row is the actual column name."
```

### Prompt Diversity

- Mix **formal / casual** tone
- Mix **explicit / implicit** intent (cases where the file format is stated directly vs. must be inferred from context)
- Mix **simple / complex** tasks
- Some should include abbreviations, typos, or casual phrasing

### Coverage

Start with 2–3 prompts, designed to cover:
- 1 core use case
- 1 edge case
- (Optional) 1 compound task

---

## 3. Execution Testing: With-skill vs Baseline

### 3-1. Comparative Execution Structure

For each test prompt, spawn two sub-agents **simultaneously**:

**With-skill execution:**
```
Prompt: "{test prompt}"
Skill path: {skill path}
Output path: _workspace/iteration-N/eval-{id}/with_skill/outputs/
```

**Baseline execution:**
```
Prompt: "{test prompt}"  (identical)
Skill: none
Output path: _workspace/iteration-N/eval-{id}/without_skill/outputs/
```

### 3-2. Baseline Selection

| Situation | Baseline |
|-----------|----------|
| Creating a new skill | Run the same prompt without any skill |
| Improving an existing skill | The pre-modification skill version (preserve a snapshot) |

### 3-3. Capturing Timing Data

Save `total_tokens` and `duration_ms` **immediately** from the sub-agent completion notification. This data is only accessible at notification time and cannot be recovered afterward.

```json
{
  "total_tokens": 84852,
  "duration_ms": 23332,
  "total_duration_seconds": 23.3
}
```

---

## 4. Quantitative Evaluation: Assertion-Based Scoring

### 4-1. Writing Assertions

When output is objectively verifiable, define assertions for automated scoring.

**Good assertions:**
- Can be objectively judged true or false
- Have descriptive names that make it clear what is being checked just from the name
- Validate the core value of the skill

**Bad assertions:**
- Things that always pass regardless of whether the skill is used (e.g., "output exists")
- Things that require subjective judgment (e.g., "well written")

### 4-2. Programmatic Verification

When an assertion can be verified with code, write it as a script. This is faster and more reliable than manual inspection, and is reusable across iterations.

### 4-3. Watch Out for Non-Discriminating Assertions

Assertions that pass 100% for both configurations do not measure the skill's differential value. When you find such an assertion, remove it or replace it with a more challenging one.

### 4-4. Scoring Result Schema

```json
{
  "expectations": [
    {
      "text": "Profit margin column added",
      "passed": true,
      "evidence": "Column 'profit_margin_pct' confirmed in column E"
    },
    {
      "text": "Sorted descending by profit margin",
      "passed": false,
      "evidence": "Original order preserved without sorting"
    }
  ],
  "summary": {
    "passed": 1,
    "failed": 1,
    "total": 2,
    "pass_rate": 0.50
  }
}
```

---

## 5. Using Specialized Agents

Quality improves when specialized-role agents are used during the testing and evaluation process.

### 5-1. Grader

Performs assertion-based scoring, extracts verifiable claims from the output, and cross-validates them.

**Responsibilities:**
- Pass/fail judgment per assertion with supporting evidence
- Extract factual claims from the output and verify them
- Provide feedback on the quality of the eval itself (suggest improvements when assertions are too easy or vague)

### 5-2. Comparator (Blind Comparison)

Anonymizes the two outputs as A/B and judges quality without knowing which result used the skill.

**When to use:** When you need to rigorously confirm "is the new version actually better?" Can be omitted for routine iterative improvement.

**Judgment criteria:**
- Content: accuracy, completeness
- Structure: organization, formatting, usability
- Overall score

### 5-3. Analyzer

Analyzes statistical patterns in benchmark data:
- Non-discriminating assertions (both configurations pass → no discriminating power)
- High-variance evals (results vary significantly across runs → unstable)
- Time/token trade-offs (when a skill improves quality but also raises cost)

---

## 6. Iterative Improvement Loop

### 6-1. Collecting Feedback

Show the user the outputs and gather feedback. Empty feedback is interpreted as "no issues."

### 6-2. Improvement Principles

1. **Generalize the feedback** — Narrow fixes that only address the test example are overfitting. Fix at the level of the underlying principle.
2. **Remove anything that doesn't earn its weight** — Read the transcript; if the skill is causing the agent to do unproductive work, cut that section.
3. **Explain the why** — Even when user feedback is brief, understand why it matters and encode that understanding into the skill.
4. **Bundle repetitive tasks** — If the same helper script is generated across every test run, include it in `scripts/` upfront.

### 6-3. Iteration Procedure

```
1. Modify the skill
2. Re-run all test cases in a new iteration-N+1/ directory
3. Present results to the user (compare to previous iteration)
4. Collect feedback
5. Revise again → repeat
```

**Exit conditions:**
- The user is satisfied
- All feedback is empty (no issues with any output)
- No further meaningful improvement is possible

### 6-4. Draft → Review Pattern

When revising a skill, write a draft first, then **read it again with fresh eyes** and improve it. Do not try to write it perfectly in one pass — go through a draft-review cycle.

---

## 7. Description Trigger Validation

### 7-1. Writing Trigger Eval Queries

Write 20 eval queries — 10 should-trigger + 10 should-NOT-trigger.

**Query quality criteria:**
- Specific and natural sentences that a real user would actually type
- Include concrete details such as file paths, personal context, column names, company names
- Mix of length, tone, and format
- Focus on **edge cases** rather than clear-cut examples

**Should-trigger queries (8–10):**
- Same intent expressed in varied ways (formal/casual)
- Cases where the skill or file type is not explicitly mentioned but is clearly needed
- Less common use cases
- Cases that compete with other skills but where this skill should win

**Should-NOT-trigger queries (8–10):**
- **Near-miss is the key** — queries with similar keywords where a different tool/skill is more appropriate
- Obviously unrelated queries ("write a Fibonacci function") have no test value
- Adjacent domains, ambiguous phrasing, keyword overlap but different context

### 7-2. Validating Conflicts with Existing Skills

Confirm that the new skill's description does not overlap with the trigger territory of existing skills:

1. Collect the descriptions from the existing skill list
2. Verify that the new skill's should-trigger queries do not incorrectly trigger existing skills
3. When conflicts are found, clarify the boundary conditions in the description more precisely

### 7-3. Automated Optimization (Optional Advanced Feature)

When description optimization is needed:

1. Split the 20 eval queries into Train (60%) / Test (40%)
2. Measure trigger accuracy with the current description
3. Analyze failure cases to generate an improved description
4. Select the best description based on the Test set (not the Train set — to prevent overfitting)
5. Repeat up to 5 times

> This process is performed by an automation script using `claude -p`. Token costs are high, so run this only at the final stage after the skill has stabilized sufficiently.

---

## 8. Workspace Structure

A directory structure for systematically managing test and evaluation results:

```
{skill-name}-workspace/
├── iteration-1/
│   ├── eval-descriptive-name-1/
│   │   ├── eval_metadata.json
│   │   ├── with_skill/
│   │   │   ├── outputs/
│   │   │   ├── timing.json
│   │   │   └── grading.json
│   │   └── without_skill/
│   │       ├── outputs/
│   │       ├── timing.json
│   │       └── grading.json
│   ├── eval-descriptive-name-2/
│   │   └── ...
│   └── benchmark.json
├── iteration-2/
│   └── ...
└── evals/
    └── evals.json
```

**Rules:**
- eval directories use **descriptive names**, not numbers (e.g., `eval-multi-page-table-extraction`)
- Each iteration is preserved in its own directory (do not overwrite previous iterations)
- `_workspace/` is not deleted — kept for post-hoc verification and audit trail
