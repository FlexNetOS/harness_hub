# Orchestrator Skill Template

The orchestrator is the top-level skill that coordinates the entire team. Three templates are provided, one for each execution mode:

- **Template A: Agent Team Mode (default)** — First choice whenever two or more agents collaborate
- **Template B: Sub-Agent Mode (alternative)** — Use when team communication is unnecessary
- **Template C: Hybrid Mode** — Mix modes across Phases

---

## Template A: Agent Team Mode (Default · First Choice)

**The default mode to consider first** whenever two or more agents collaborate. Assemble the team with `TeamCreate`, coordinate via a shared task list and `SendMessage`.

```markdown
---
name: {domain}-orchestrator
description: "Orchestrator that coordinates the {domain} agent team. {initial trigger keywords}. Also use this skill for follow-up work: modifying {domain} output, partial re-runs, updates, refinements, re-execution, or requests to improve previous results."
---

# {Domain} Orchestrator

An integrated skill that coordinates the {domain} agent team to produce {final deliverable}.

## Execution Mode: Agent Team

## Agent Composition

| Member | Agent Type | Role | Skill | Output |
|--------|-----------|------|-------|--------|
| {teammate-1} | {custom or built-in} | {role} | {skill} | {output-file} |
| {teammate-2} | {custom or built-in} | {role} | {skill} | {output-file} |
| ... | | | | |

## Workflow

### Phase 0: Context Check (Follow-up Support)

Check for existing artifacts to determine execution mode:

1. Check whether the `_workspace/` directory exists
2. Determine execution mode:
   - **`_workspace/` absent** → Initial run. Proceed to Phase 1
   - **`_workspace/` present + user requests partial modification** → Partial re-run. Re-invoke only the relevant agents and overwrite only the targeted artifacts
   - **`_workspace/` present + new input provided** → Fresh run. Move the existing `_workspace/` to `_workspace_{YYYYMMDD_HHMMSS}/`, then proceed to Phase 1
3. On partial re-run: include the previous artifact paths in the agent prompt so the agent reads the existing results and incorporates the feedback

### Phase 1: Preparation
1. Analyze user input — {what to identify}
2. Create `_workspace/` in the working directory
   - **Initial run**: create a new `_workspace/`
   - **Fresh run**: move the existing `_workspace/` to `_workspace_{YYYYMMDD_HHMMSS}/`, then recreate `_workspace/`
3. Save input data to `_workspace/00_input/`

### Phase 2: Team Assembly

1. Create the team:
   ```
   TeamCreate(
     team_name: "{domain}-team",
     members: [
       { name: "{teammate-1}", agent_type: "{type}", model: "opus", prompt: "{role description and task instructions}" },
       { name: "{teammate-2}", agent_type: "{type}", model: "opus", prompt: "{role description and task instructions}" },
       ...
     ]
   )
   ```

2. Register tasks:
   ```
   TaskCreate(tasks: [
     { title: "{task-1}", description: "{details}", assignee: "{teammate-1}" },
     { title: "{task-2}", description: "{details}", assignee: "{teammate-2}" },
     { title: "{task-3}", description: "{details}", depends_on: ["{task-1}"] },
     ...
   ])
   ```

   > 5–6 tasks per member is a good target. Express dependencies via `depends_on`.

### Phase 3: {Primary Work — e.g., Research / Generation / Analysis}

**Execution:** Members self-coordinate

Members claim tasks from the shared task list and work independently.
The leader monitors progress and intervenes when needed.

**Inter-member communication rules:**
- {teammate-1} sends {what information} to {teammate-2} via SendMessage
- {teammate-2} saves results to a file on completion and notifies the leader
- If a member needs another member's output, they request it via SendMessage

**Artifact storage:**

| Member | Output path |
|--------|------------|
| {teammate-1} | `_workspace/{phase}_{teammate-1}_{artifact}.md` |
| {teammate-2} | `_workspace/{phase}_{teammate-2}_{artifact}.md` |

**Leader monitoring:**
- Automatically notified when a member goes idle
- Sends instructions via SendMessage or reassigns tasks when a member is blocked
- Checks overall progress with TaskGet

### Phase 4: {Follow-up Work — e.g., Validation / Integration}
1. Wait for all members to finish (check status with TaskGet)
2. Collect each member's artifacts with Read
3. {Integration / validation logic}
4. Produce final artifact: `{output-path}/{filename}`

### Phase 5: Cleanup
1. Request team members to shut down (SendMessage)
2. Dissolve the team (TeamDelete)
3. Preserve the `_workspace/` directory (do not delete intermediate artifacts — needed for post-hoc verification and audit trails)
4. Report a result summary to the user

> **When team reassembly is needed:** If a different specialist combination is required for the next Phase, dissolve the current team with TeamDelete and assemble the next Phase's team with a new TeamCreate. Artifacts from the previous team are preserved in `_workspace/` and can be accessed by the new team via Read.

## Data Flow

```
[Leader] → TeamCreate → [teammate-1] ←SendMessage→ [teammate-2]
                            │                           │
                            ↓                           ↓
                      artifact-1.md              artifact-2.md
                            │                           │
                            └───────── Read ────────────┘
                                       ↓
                                [Leader: Integration]
                                       ↓
                                Final deliverable
```

## Error Handling

| Situation | Strategy |
|-----------|----------|
| One member fails / stops | Leader detects → checks status via SendMessage → restarts or creates a replacement member |
| Majority of members fail | Notify the user and confirm whether to continue |
| Timeout | Use partial results collected so far; shut down incomplete members |
| Data conflict between members | Cite both sources and keep both; do not delete either |
| Task status stalls | Leader checks with TaskGet, then manually issues TaskUpdate |

## Test Scenarios

### Happy Path
1. User provides {input}
2. Phase 1 produces {analysis result}
3. Phase 2 assembles the team ({N} members + {M} tasks)
4. Phase 3: members self-coordinate and complete their tasks
5. Phase 4: artifacts are integrated to produce the final result
6. Phase 5: team is cleaned up
7. Expected output: `{output-path}/{filename}` created

### Error Path
1. {teammate-2} stops with an error during Phase 3
2. Leader receives idle notification
3. Checks status via SendMessage → attempts restart
4. If restart fails, reassign {teammate-2}'s tasks to {teammate-1}
5. Proceed to Phase 4 with remaining results
6. Note "{teammate-2} section partially missing" in the final report
```

---

## Template B: Sub-Agent Mode (Alternative)

Use when team communication overhead is unnecessary. Call agents directly with the `Agent` tool and collect results via return values.

```markdown
---
name: {domain}-orchestrator
description: "Orchestrator that coordinates {domain} agents. {initial trigger keywords}. Includes follow-up trigger keywords."
---

## Execution Mode: Sub-Agent

## Agent Composition

| Agent | subagent_type | Role | Skill | Output |
|-------|--------------|------|-------|--------|
| {agent-1} | {built-in or custom} | {role} | {skill} | {output-file} |
| {agent-2} | ... | ... | ... | ... |

## Workflow

### Phase 0: Context Check
(Same as Template A — branch on `_workspace/` existence)

### Phase 1: Preparation
1. Analyze input
2. Create `_workspace/` (on initial run, or immediately after archiving the existing `_workspace/` on a fresh run)

### Phase 2: Parallel Execution
Invoke N Agent tools simultaneously in a single message:

| Agent | Input | Output | model | run_in_background |
|-------|-------|--------|-------|-------------------|
| {agent-1} | {source} | `_workspace/{phase}_{agent}_{artifact}.md` | opus | true |
| {agent-2} | {source} | `_workspace/{phase}_{agent}_{artifact}.md` | opus | true |

### Phase 3: Integration
1. Collect each agent's return value
2. Collect file-based artifacts with Read
3. Apply integration logic → final deliverable

### Phase 4: Cleanup
1. Preserve `_workspace/`
2. Report result summary

## Error Handling
- One agent fails: retry once. If it fails again, note the gap and continue
- Majority fail: notify the user and confirm whether to continue
- Timeout: use partial results collected so far
```

---

## Template C: Hybrid Mode

Use a different execution mode for each Phase. Declare `**Execution Mode:** {Team | Sub-Agent}` at the top of each Phase.

```markdown
---
name: {domain}-orchestrator
description: "{domain} orchestrator (hybrid). {keywords}. Includes follow-up trigger keywords."
---

## Execution Mode: Hybrid

| Phase | Mode | Reason |
|-------|------|--------|
| Phase 2 (parallel collection) | Sub-Agent | Independent data collection; team communication unnecessary |
| Phase 3 (consensus integration) | Agent Team | Conflicting data requires discussion and consensus |
| Phase 4 (independent validation) | Sub-Agent | A single QA agent performs objective verification |

## Workflow

### Phase 2: Parallel Data Collection
**Execution Mode:** Sub-Agent

Invoke N agents in parallel with the Agent tool in a single message (`run_in_background: true`).
Each result is saved to `_workspace/02_{agent}_raw.md`.

### Phase 3: Consensus-Based Integration
**Execution Mode:** Agent Team

1. Assemble an integration team with `TeamCreate` (editor + fact-checker + synthesizer)
2. Distribute work with `TaskCreate` — all members Read from Phase 2's `_workspace/02_*` files
3. Members discuss conflicting data via `SendMessage` and reach consensus via file-based output
4. Produce final integrated document `_workspace/03_integrated.md`
5. Dissolve the team with `TeamDelete`

### Phase 4: Independent Validation
**Execution Mode:** Sub-Agent

A single QA sub-agent receives `_workspace/03_integrated.md` as input and produces a validation report.
```

**Hybrid transition rules:**
- Team → Sub-Agent: always dissolve the team with `TeamDelete` before calling the Agent tool
- Sub-Agent → Team: pass sub-agent file artifacts to team members as Read paths
- Team → Team: dissolve the previous team before issuing a new `TeamCreate` (only one active team per session)

---

## Authoring Principles

1. **State the execution mode first** — declare "Agent Team" / "Sub-Agent" / "Hybrid" at the top of the orchestrator. If hybrid, include a per-Phase mode table
2. **Be specific about TeamCreate / SendMessage / TaskCreate usage in team mode** — team composition, task registration, and communication rules
3. **Fully specify Agent tool parameters in sub-agent mode** — name, subagent_type, prompt, run_in_background, model
4. **Always use absolute file paths** — no relative paths; use clear paths rooted at `_workspace/`
5. **Declare inter-Phase dependencies** — state which Phase depends on which Phase's output. For hybrid mode, emphasize mode-transition points in particular
6. **Keep error handling realistic** — do not assume everything succeeds
7. **Test scenarios are mandatory** — at least one happy path and one error path

## Follow-up Trigger Keywords for `description`

An orchestrator description that only lists initial trigger keywords is insufficient. Always include follow-up phrasing such as:

- re-run / run again / update / modify / refine
- "just redo the {part} of {domain}"
- "based on previous results", "improve results"
- Domain-specific everyday requests (e.g., for a launch strategy harness: "launch", "promotion", "trending", etc.)

Without follow-up keywords, the harness effectively becomes dead code after its first run.

## Real Orchestrator Reference

The basic structure of a fan-out / fan-in orchestrator:
Preparation → Phase 0 (context check) → TeamCreate + TaskCreate → N members run in parallel → Read + integration → cleanup.
See the research team example in `references/team-examples.md`.
