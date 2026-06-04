---
name: harness
description: "Configure and build a harness. A meta-skill that defines specialized agents and creates the skills those agents use. Invoke when: (1) the user asks to 'configure a harness', 'build a harness', or 'set up a harness'; (2) the user asks to 'design a harness' or do 'harness engineering'; (3) building a harness-based automation system for a new domain or project; (4) restructuring or extending an existing harness configuration; (5) requests to 'audit the harness', 'inspect the harness', 'harness status', or 'sync agents/skills' for an existing harness."
---

# Harness — Agent Team & Skill Architect

A meta-skill for configuring a harness suited to a domain or project — defining each agent's role and creating the skills those agents use.

**Core principles:**
1. Create agent definitions (`.claude/agents/`) and skills (`.claude/skills/`).
2. **Use agent teams as the default execution mode.**
3. **Register a harness pointer in CLAUDE.md.** — Record only the minimal pointer (trigger rules + change history) so that the orchestrator skill is triggered in new sessions.
4. **A harness is an evolving system, not a static artifact.** — Incorporate feedback after every run and continuously update agents, skills, and CLAUDE.md.

## Workflow

### Phase 0: Current-State Audit

When the harness skill is triggered, the first action is always to check the current state of any existing harness.

1. Read `project/.claude/agents/`, `project/.claude/skills/`, and `project/CLAUDE.md`.
2. Branch on what is found:
   - **New build**: No agent/skill directory exists or both are empty → run all phases from Phase 1.
   - **Extend existing**: A harness already exists and the request is to add agents/skills → run only the required phases per the Phase Selection Matrix below.
   - **Operations/maintenance**: Request is to audit, modify, or sync an existing harness → jump to the Phase 7-5 operations/maintenance workflow.

   **Phase Selection Matrix for extending an existing harness:**
   | Change type | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 | Phase 6 |
   |-------------|---------|---------|---------|---------|---------|---------|
   | Add agent | Skip (use Phase 0 findings) | Placement decision only | Required (incl. 3-0) | If dedicated skill needed (incl. 4-0) | Modify orchestrator | Required |
   | Add/modify skill | Skip | Skip | Skip | Required (incl. 4-0) | If connections change | Required |
   | Architecture change | Skip | Required | Affected agents only (incl. 3-0) | Affected skills only (incl. 4-0) | Required | Required |
3. Cross-reference the existing agent/skill list against the CLAUDE.md record and detect any drift.
4. Summarize the audit findings for the user and confirm the execution plan before proceeding.

### Phase 1: Domain Analysis
1. Identify the domain or project from the user's request.
2. Identify the core task types (generation, validation, editing, analysis, etc.).
3. Based on the Phase 0 audit, analyze conflicts and duplication with existing agents and skills.
4. Explore the project codebase — understand the tech stack, data models, and key modules.
5. **Detect user skill level** — read contextual cues in the conversation (terminology used, question sophistication) to gauge technical level and adjust communication tone accordingly. Do not use terms like "assertion" or "JSON schema" without explanation when speaking with users who have limited coding experience.

### Phase 2: Team Architecture Design

#### 2-1. Choose Execution Mode

**Agent teams are the primary default.** Whenever two or more agents collaborate, always evaluate an agent team first. Team members self-coordinate through direct communication (`SendMessage`) and a shared task list (`TaskCreate`), and the shared discovery, debated trade-offs, and gap-filling that result raise output quality.

| Mode | When to use | Characteristics |
|------|-------------|-----------------|
| **Agent team** (default) | 2+ agents collaborating, real-time coordination and feedback exchange required, intermediate outputs cross-referenced | Self-coordinated via `TeamCreate` + `SendMessage` + `TaskCreate` |
| **Sub-agent** (alternative) | Single-agent task, returning only the result to main is sufficient, team communication overhead outweighs the benefit | Direct `Agent` tool call, parallelized with `run_in_background` |
| **Hybrid** | Each phase has distinct characteristics — e.g., parallel collection (sub) → consensus-based integration (team) | Mix team/sub per phase |

**Decision order:**
1. First evaluate whether an agent team design is feasible — if 2+ agents are needed, that is the default.
2. Choose sub-agents only when team communication is structurally unnecessary (result delivery only) and the team overhead exceeds the benefit.
3. Consider hybrid when phases have clearly different characteristics — document the execution mode for each phase in the orchestrator.

> For a detailed comparison table and per-pattern decision tree, see "Execution Modes" in `references/agent-design-patterns.md`.

#### 2-2. Select Architecture Pattern

1. Decompose the work into specialized domains.
2. Decide on the agent team structure (see `references/agent-design-patterns.md` for architecture patterns):
   - **Pipeline**: Sequentially dependent tasks.
   - **Fan-out/Fan-in**: Parallel independent tasks.
   - **Expert Pool**: Situational selective invocation.
   - **Producer-Reviewer**: Generation followed by quality review.
   - **Supervisor**: Central agent manages state and dynamically distributes work.
   - **Hierarchical Delegation**: Upper agents recursively delegate to lower agents.

#### 2-3. Agent Separation Criteria

Evaluate on four axes: specialization, parallelism, context, and reusability. For the detailed criteria table, see "Agent Separation Criteria" in `references/agent-design-patterns.md`. Duplication and reuse review against existing agents is handled in Phase 3-0.

### Phase 3: Generate Agent Definitions

#### 3-0. Check for Duplicate Agents

Before creating a new agent, verify there is no overlap with existing agents in `project/.claude/agents/`. Iterative harness builds tend to accumulate agents with overlapping roles under different names.

> For duplication classification and reuse design, see "Agent Reuse Design" in `references/agent-design-patterns.md`.

**Every agent must be defined in a `project/.claude/agents/{name}.md` file.** Placing roles directly in the `Agent` tool's prompt without a definition file is not allowed. Reasons:
- Agent definitions must exist as files to be reusable in future sessions.
- Team communication protocols must be explicit to guarantee collaboration quality.
- The core value of a harness is the separation of agent (who) from skill (how).

Create agent definition files even when using built-in types (`general-purpose`, `Explore`, `Plan`). Specify the built-in type via the `subagent_type` parameter of the Agent tool, and put role, principles, and protocols in the definition file.

**Model setting:** All agents use `model: "opus"`. Always specify the `model: "opus"` parameter when calling the Agent tool. Harness quality is directly tied to the reasoning ability of its agents, and opus delivers the highest quality.

**Team restructuring:** Only one team can be active per session, but teams can be disbanded and a new one formed between phases. If a pipeline pattern requires a different expert combination per phase, save the previous team's output to file, clean up the team, then create a new one.

Define each agent in `project/.claude/agents/{name}.md`. Required sections: core role, working principles, input/output protocol, error handling, and collaboration. In agent team mode, add a `## Team Communication Protocol` section specifying which agents to send messages to and receive from, and the scope of work requests.

> For definition templates and complete example files, see "Agent Definition Structure" in `references/agent-design-patterns.md` + `references/team-examples.md`.

**When including a QA agent — mandatory items:**
- The QA agent must use the `general-purpose` type (`Explore` is read-only and cannot run validation scripts).
- The essence of QA is **"cross-boundary comparison"**, not "existence checking" — read the API response and the frontend hook simultaneously and compare shapes.
- QA should run **incrementally after each module is complete**, not once after everything is done (incremental QA).
- Detailed guide: see `references/qa-agent-guide.md`.

### Phase 4: Create Skills

Create the skills each agent will use at `project/.claude/skills/{name}/SKILL.md`. For a detailed authoring guide, see `references/skill-writing-guide.md`.

#### 4-0. Check for Duplicate Skills

Before creating a new skill, verify there is no overlap with existing skills in `project/.claude/skills/`. Iterative harness builds tend to accumulate skills with overlapping functionality under different names.

> For duplication classification and generalization patterns, see "Skill Reuse Design" in `references/skill-writing-guide.md`.

#### 4-1. Skill Structure

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description required)
│   └── Markdown body
└── Bundled Resources (optional)
    ├── scripts/    - executable code for repetitive/deterministic tasks
    ├── references/ - reference documents loaded conditionally
    └── assets/     - files used in output (templates, images, etc.)
```

#### 4-2. Writing the Description — Drive Active Triggering

The description is the skill's only trigger mechanism. Because Claude tends to be conservative when deciding to trigger, write descriptions in an **assertive ("pushy") style**.

**Bad example:** `"A skill that processes PDF documents."`
**Good example:** `"Handles all PDF tasks: reading PDF files, extracting text/tables, merging, splitting, rotating, watermarking, encrypting, OCR, and more. ALWAYS use this skill when a .pdf file is mentioned or a PDF output is requested."`

Key: describe what the skill does AND the specific trigger situations, and distinguish from similar cases that should NOT trigger this skill.

#### 4-3. Body Authoring Principles

| Principle | Description |
|-----------|-------------|
| **Explain the why** | Instead of coercive directives like "ALWAYS/NEVER", convey the reason behind the rule. An LLM that understands the reason makes correct judgments even in edge cases. |
| **Stay lean** | The context window is a shared resource. Target a SKILL.md body under 500 lines — delete or move to `references/` anything that does not earn its weight. |
| **Generalize** | Explain principles rather than narrow rules that only fit specific examples, so the skill handles diverse inputs. Avoid overfitting. |
| **Bundle repetitive code** | When agents are found to write the same scripts across test runs, bundle that code into `scripts/` in advance. |
| **Write imperatively** | Use imperative, directive phrasing throughout. |

#### 4-4. Progressive Disclosure

Skills manage context through a three-tier loading system:

| Tier | When loaded | Size target |
|------|-------------|-------------|
| **Metadata** (name + description) | Always in context | ~100 words |
| **SKILL.md body** | When the skill is triggered | <500 lines |
| **references/** | Only when needed | Unlimited (scripts can be executed without loading) |

**Size management rules:**
- When SKILL.md approaches 500 lines, move detailed content to `references/` and leave a pointer in the body specifying when to read that file.
- Reference files over 300 lines must include a **table of contents (ToC)** at the top.
- When domain- or framework-specific variants exist, split them under `references/` by domain so only the relevant file is loaded.

```
cloud-deploy/
├── SKILL.md (workflow + selection guide)
└── references/
    ├── aws.md    ← load only when AWS is selected
    ├── gcp.md
    └── azure.md
```

#### 4-5. Skill-Agent Connection Principles

- 1 agent ↔ 1–N skills (one-to-one or one-to-many).
- A skill may be shared by multiple agents.
- Skills hold "how to do it"; agents hold "who does it".

> For detailed authoring patterns, examples, and data schema standards, see `references/skill-writing-guide.md`.

### Phase 5: Integration and Orchestration

The orchestrator is a special form of skill that weaves individual agents and skills into a single workflow and coordinates the whole team. Where the individual skills created in Phase 4 define "what each agent does and how", the orchestrator defines "who collaborates, when, and in what order". For a concrete template, see `references/orchestrator-template.md`.

**Modifying the orchestrator for an existing extension:** When extending rather than building from scratch, modify the existing orchestrator rather than creating a new one. When adding an agent, reflect the new agent in team composition, task assignment, and data flow, and add trigger keywords related to the new agent to the description.

The orchestrator pattern varies based on the execution mode chosen in Phase 2-1:

#### 5-0. Orchestrator Patterns (by mode)

**Agent team pattern (default):**
The orchestrator forms the team with `TeamCreate` and assigns tasks with `TaskCreate`. Team members communicate directly via `SendMessage` and self-coordinate. The leader (orchestrator) monitors progress and synthesizes results.

```
[Orchestrator/Leader]
    ├── TeamCreate(team_name, members)
    ├── TaskCreate(tasks with dependencies)
    ├── Team members self-coordinate (SendMessage)
    ├── Collect and synthesize results
    └── Clean up team
```

**Sub-agent pattern (alternative):**
The orchestrator invokes sub-agents directly via the `Agent` tool. Parallel execution uses `run_in_background: true`; results are returned only to the main agent. Use when team communication is unnecessary and you want to reduce overhead.

```
[Orchestrator]
    ├── Agent(agent-1, run_in_background=true)
    ├── Agent(agent-2, run_in_background=true)
    ├── Wait for and collect results
    └── Produce integrated output
```

**Hybrid pattern:**
Mix modes across phases. Common combinations:
- **Parallel collection (sub) → consensus integration (team)**: Phase 2 sub-agents collect independent data in parallel → Phase 3 forms a team for discussion and consensus-based integration.
- **Team generation (team) → validation (sub)**: Phase 2 team produces a draft → Phase 3 a single sub-agent performs independent validation.
- **Team restructuring between phases**: `TeamDelete` before each phase, then `TeamCreate` for the next, with sub-agent calls inserted between phases.

When choosing hybrid, document the execution mode for each phase at the top of its section in the orchestrator (e.g., `**Execution mode:** Agent team`).

#### 5-1. Data Transfer Protocol

Document the data transfer strategy between agents within the orchestrator:

| Strategy | Mechanism | Applicable mode | Best for |
|----------|-----------|-----------------|----------|
| **Message-based** | Direct communication between team members via `SendMessage` | Team | Real-time coordination, feedback exchange, lightweight state transfer |
| **Task-based** | Share task state via `TaskCreate`/`TaskUpdate` | Team | Progress tracking, dependency management, work requests |
| **File-based** | Write and read files at agreed paths | Team + Sub | Large data, structured output, audit trail required |
| **Return-value-based** | Return message from the `Agent` tool | Sub | Main agent directly collecting sub-agent results |

**Recommended combination (team mode):** Task-based (coordination) + File-based (output) + Message-based (real-time communication)
**Recommended combination (sub mode):** Return-value-based (result collection) + File-based (large output)
**Hybrid:** Apply the combination that matches each phase's execution mode.

File-based transfer rules:
- Create a `_workspace/` folder under the working directory to store intermediate outputs.
- File naming convention: `{phase}_{agent}_{artifact}.{ext}` (e.g., `01_analyst_requirements.md`).
- Output only final artifacts to the user-specified path; preserve intermediate files (`_workspace/`) for post-hoc verification and audit.

#### 5-2. Error Handling

Include an error handling policy within the orchestrator. Core principle: retry once; if it fails again, proceed without that result (note the omission in the report); do not discard conflicting data — record it with its source.

> For a table of error-type strategies and implementation details, see "Error Handling" in `references/orchestrator-template.md`.

#### 5-3. Team Size Guidelines

| Task scale | Recommended team size | Tasks per member |
|------------|----------------------|------------------|
| Small (5–10 tasks) | 2–3 members | 3–5 |
| Medium (10–20 tasks) | 3–5 members | 4–6 |
| Large (20+ tasks) | 5–7 members | 4–5 |

> More team members means more coordination overhead. Three focused members outperform five distracted ones.

#### 5-4. Register the Harness Pointer in CLAUDE.md

After completing the harness, register a minimal pointer in the project's `CLAUDE.md`. Because CLAUDE.md is loaded at the start of every session, recording only the harness's existence and trigger rules is sufficient — the orchestrator skill handles the rest.

**CLAUDE.md template:**

````markdown
## Harness: {Domain Name}

**Goal:** {One-line description of the harness's core objective}

**Trigger:** For any {domain}-related task, use the `{orchestrator-skill-name}` skill. Simple questions may be answered directly.

**Change history:**
| Date | Change | Target | Reason |
|------|--------|--------|--------|
| {YYYY-MM-DD} | Initial setup | All | - |
````

**What NOT to put in CLAUDE.md:** agent lists, skill lists, directory structure, detailed execution rules. Reason: agent and skill lists are managed in the orchestrator skill and in `.claude/agents/` and `.claude/skills/`, so including them here is duplication. Directory structure can be checked directly in the filesystem. CLAUDE.md holds only the **pointer (trigger rules) + change history**.

#### 5-5. Follow-up Work Support

The orchestrator must handle follow-up requests, not just the initial run. Ensure the following three things:

**1. Include follow-up keywords in the orchestrator description:**
Initial creation keywords alone will not trigger follow-up requests. The description must include follow-up expressions such as:
- "re-run", "run again", "update", "revise", "refine"
- "redo only the {sub-task} of {domain}"
- "based on the previous result", "improve the result"

**2. Add a context check step to Phase 1 of the orchestrator:**
At the start of the workflow, check whether previous output exists and decide the execution mode:
- `_workspace/` exists + user requests partial modification → **Partial re-run** (re-invoke only the relevant agent).
- `_workspace/` exists + user provides new input → **New run** (move existing `_workspace/` to `_workspace_prev/`).
- `_workspace/` does not exist → **Initial run**.

**3. Include re-invocation guidance in agent definitions:**
Specify "behavior when previous output exists" in each agent's `.md` file:
- If a previous result file exists, read it and incorporate improvements.
- If user feedback is provided, modify only the affected portion.

> See the "Phase 0: Context Check" section of the orchestrator template: `references/orchestrator-template.md`.

### Phase 6: Validation and Testing

Validate the generated harness. For detailed testing methodology, see `references/skill-testing-guide.md`.

#### 6-1. Structure Validation

- Verify all agent files are in the correct locations.
- Validate skill frontmatter (name, description).
- Verify reference consistency between agents.
- Confirm that no commands were generated.

#### 6-2. Execution-Mode Validation

- **Agent team**: Verify communication paths between members, task dependencies, and appropriate team size.
- **Sub-agent**: Verify each agent's input/output connections, `run_in_background` settings, and return-value collection logic.
- **Hybrid**: Verify the execution mode for each phase is documented in the orchestrator and that data transfer is continuous across phase boundaries (when transitioning from team to sub, verify the team's output feeds into the sub's input).

#### 6-3. Skill Execution Testing

Perform actual execution tests for each generated skill:

1. **Write test prompts** — Write 2–3 realistic test prompts for each skill. Use specific, natural sentences that actual users would enter.

2. **With-skill vs. Without-skill comparison** — Where possible, run both in parallel to confirm the skill's added value. Spawn two agents per skill:
   - **With-skill**: Reads the skill and performs the task.
   - **Without-skill (baseline)**: Performs the same prompt without the skill.

3. **Evaluate results** — Evaluate output quality both qualitatively (user review) and quantitatively (assertion-based). Define assertions when output is objectively verifiable (file creation, data extraction, etc.); rely on user feedback for subjective output (tone, design).

4. **Iterative improvement loop** — When issues are found during testing:
   - **Generalize** the feedback and update the skill (avoid narrow fixes that only address the specific example).
   - Re-test after each modification.
   - Repeat until the user is satisfied or no further meaningful improvement is possible.

5. **Bundle repeated patterns** — When agents are found to write the same code across test runs (e.g., the same helper script in every test), bundle that code into `scripts/` in advance.

#### 6-4. Trigger Validation

Validate that each skill's description triggers correctly:

1. **Should-trigger queries** (8–10) — Diverse phrasings that should trigger the skill (formal/casual, explicit/implicit).
2. **Should-NOT-trigger queries** (8–10) — "Near-miss" queries with similar keywords where a different tool or skill is more appropriate.

**Key to writing near-misses:** Queries that are obviously unrelated (e.g., "write a Fibonacci function") have no test value. Good test cases are **boundary-ambiguous queries** such as "extract the chart from this Excel file as a PNG" (xlsx skill vs. image conversion).

Also check for trigger conflicts with existing skills at this stage.

#### 6-5. Dry-Run Test

- Review whether the orchestrator skill's phase sequence is logically sound.
- Verify there are no dead links in the data transfer paths.
- Verify each agent's input matches the output of the preceding phase.
- Verify that fallback paths for error scenarios are executable.

#### 6-6. Write Test Scenarios

- Add a `## Test Scenarios` section to the orchestrator skill.
- Document at least one happy-path scenario and one error-path scenario.

### Phase 7: Harness Evolution

A harness is not a static artifact built once and left unchanged. It is a system that continuously evolves based on user feedback.

#### 7-1. Collect Feedback After Each Run

After every harness run, ask the user for feedback:
- "Are there any parts of the result you'd like to improve?"
- "Is there anything you'd like to change about the agent team structure or workflow?"

Skip this if no feedback is offered. Do not press, but always provide the opportunity.

#### 7-2. Feedback Routing

The target for revision depends on the type of feedback:

| Feedback type | Target | Example |
|---------------|--------|---------|
| Output quality | Skill for the relevant agent | "Analysis is too superficial" → Add depth criteria to the skill |
| Agent role | Agent definition `.md` | "We need a security review too" → Add a new agent |
| Workflow order | Orchestrator skill | "Validation should come first" → Reorder phases |
| Team composition | Orchestrator + agents | "These two could be merged" → Merge agents |
| Missing trigger | Skill description | "This phrasing doesn't work" → Expand description |

#### 7-3. Change History

Record every change in the **change history** table in CLAUDE.md (the same table as in the Phase 5-4 template):

```markdown
**Change history:**
| Date | Change | Target | Reason |
|------|--------|--------|--------|
| 2026-04-05 | Initial setup | All | - |
| 2026-04-07 | Add QA agent | agents/qa.md | Feedback: insufficient output quality validation |
| 2026-04-10 | Add tone guide | skills/content-creator | Feedback: "too stiff" |
```

This history enables tracking the direction the harness has evolved and prevents regression.

#### 7-4. Evolution Triggers

Propose evolution not only when the user explicitly says "update the harness", but also in these situations:
- The same type of feedback recurs two or more times.
- A repeated failure pattern is observed in an agent.
- The user is observed bypassing the orchestrator and working manually.

#### 7-5. Operations/Maintenance Workflow

Perform systematic inspection, modification, and synchronization of an existing harness. Follow this workflow when the Phase 0 audit branches to "operations/maintenance".

**Step 1: Current-state audit**
- Compare the file list in `.claude/agents/` against the agent configuration in the orchestrator skill → produce a list of discrepancies.
- Compare the directory list in `.claude/skills/` against the skill configuration in the orchestrator skill → produce a list of discrepancies.
- Report the audit findings to the user.

**Step 2: Incremental additions/modifications**
- Per the user's request, add/modify/delete agents and add/modify/delete skills.
- Make one change at a time; run Step 3 (sync) immediately after each change.

**Step 3: Update CLAUDE.md change history**
- Record the date, change description, target, and reason in the change history table.

**Step 4: Validate changes**
- Validate the structure of modified agents/skills (per Phase 6-1 criteria).
- If the scope of changes affects triggers, run trigger validation (per Phase 6-4 criteria).
- For large-scale changes (architecture changes, 3+ agents added/removed), also perform Phase 6-3 (execution test) and 6-5 (dry-run).
- Final check that CLAUDE.md and actual files are consistent.

## Output Checklist

Verify after generation is complete:

- [ ] `project/.claude/agents/` — **Agent definition files must be created** (even for built-in types, files are required)
- [ ] `project/.claude/skills/` — Skill files (SKILL.md + references/)
- [ ] One orchestrator skill (with data flow + error handling + test scenarios)
- [ ] Execution mode documented (Agent team / Sub-agent / Hybrid; if Hybrid, mode listed per phase)
- [ ] All Agent calls include the `model: "opus"` parameter
- [ ] Duplicate agent check completed before creating new agents (Phase 3-0)
- [ ] Duplicate skill check completed before creating new skills (Phase 4-0)
- [ ] `.claude/commands/` — nothing created
- [ ] No conflicts with existing agents or skills
- [ ] Skill descriptions written assertively ("pushy") — **follow-up keywords included**
- [ ] SKILL.md body under 500 lines; if over, split into references/
- [ ] Execution validated with 2–3 test prompts
- [ ] Trigger validation completed (should-trigger + should-NOT-trigger)
- [ ] **Harness pointer registered in CLAUDE.md** (trigger rules + change history)
- [ ] **CLAUDE.md change history records all agent/skill additions, deletions, and modifications**
- [ ] **Context check step in orchestrator Phase 1** (distinguishes initial / follow-up / partial re-run)

## References

- Harness patterns: `references/agent-design-patterns.md`
- Existing harness examples (including complete files): `references/team-examples.md`
- Orchestrator template: `references/orchestrator-template.md`
- **Skill writing guide**: `references/skill-writing-guide.md` — authoring patterns, examples, and data schema standards
- **Skill testing guide**: `references/skill-testing-guide.md` — testing, evaluation, and iterative improvement methodology
- **QA agent guide**: `references/qa-agent-guide.md` — consult when including a QA agent in a build harness. Covers integration consistency validation methodology, boundary-bug patterns, and a QA agent definition template. Based on 7 real-project bug cases.
