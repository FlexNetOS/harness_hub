# Agent Team Examples

---

## Example 1: Research Team (Agent Team Mode)

### Team Architecture: Fan-out / Fan-in
### Execution Mode: Agent Team

```
[Leader / Orchestrator]
    ├── TeamCreate(research-team)
    ├── TaskCreate(4 research tasks)
    ├── Team members self-coordinate (SendMessage)
    ├── Collect results (Read)
    └── Generate consolidated report
```

### Agent Configuration

| Member | Agent Type | Role | Output |
|--------|-----------|------|--------|
| official-researcher | general-purpose | Official docs / blogs | research_official.md |
| media-researcher | general-purpose | Media / investment | research_media.md |
| community-researcher | general-purpose | Community / social media | research_community.md |
| background-researcher | general-purpose | Background / competition / academic | research_background.md |
| (leader = orchestrator) | — | Consolidated report | consolidated-report.md |

> Research agents use the `general-purpose` built-in type, but must be defined as `.claude/agents/{name}.md` files. Each file specifies the agent's role, research scope, and team communication protocol to ensure reusability and collaboration quality.

### Orchestrator Workflow (Agent Team)

```
Phase 1: Preparation
  - Analyze user input (topic, research mode)
  - Create _workspace/

Phase 2: Team Formation
  - TeamCreate(team_name: "research-team", members: [
      { name: "official", prompt: "Investigate official channels..." },
      { name: "media", prompt: "Investigate media / investment trends..." },
      { name: "community", prompt: "Investigate community reactions..." },
      { name: "background", prompt: "Investigate background / competitive landscape..." }
    ])
  - TaskCreate(tasks: [
      { title: "Official channel research", assignee: "official" },
      { title: "Media trend research", assignee: "media" },
      { title: "Community reaction research", assignee: "community" },
      { title: "Background landscape research", assignee: "background" }
    ])

Phase 3: Research Execution
  - 4 team members work independently
  - Share interesting findings via SendMessage between members
    (e.g., media forwards investment news to background)
  - Conflicting information is debated directly between members
  - Each member saves their file and notifies the leader upon completion

Phase 4: Integration
  - Leader reads the 4 outputs
  - Generates consolidated report
  - Conflicting information is presented with sources cited

Phase 5: Cleanup
  - Request team members to stop
  - Disband team
  - Preserve _workspace/ (for post-hoc verification and audit trail)
```

### Team Communication Patterns

```
official ──SendMessage──→ background  (share relevant official announcements)
media ────SendMessage──→ background  (share investment / acquisition info)
community ─SendMessage──→ media      (community reactions relevant to media)
all members ──TaskUpdate──→ shared task list  (progress updates)
leader ←───── idle notification ──── completed member   (automatic)
```

---

## Example 2: SF Novel Writing Team (Agent Team Mode)

### Team Architecture: Pipeline + Fan-out
### Execution Mode: Agent Team

```
Phase 1 (parallel — agent team): worldbuilder + character-designer + plot-architect
  → Coordinate consistency with each other via SendMessage
Phase 2 (sequential): prose-stylist (writing)
Phase 3 (parallel — agent team): science-consultant + continuity-manager (review)
  → Share findings with each other via SendMessage
Phase 4 (sequential): prose-stylist (revise based on review)
```

### Agent Configuration

| Member | Agent Type | Role | Skill |
|--------|-----------|------|-------|
| worldbuilder | custom | World-building | world-setting |
| character-designer | custom | Character design | character-profile |
| plot-architect | custom | Plot structure | outline |
| prose-stylist | custom | Style editing + writing | write-scene, review-chapter |
| science-consultant | custom | Scientific validation | science-check |
| continuity-manager | custom | Consistency validation | consistency-check |

### Full Agent File Example: `worldbuilder.md`

```markdown
---
name: worldbuilder
description: "Specialist in building the world for SF novels. Designs physical laws, social structures, technological level, and history."
---

# Worldbuilder — SF World Design Specialist

You are a specialist in world design for SF novels. Grounded in scientific fact while expanding imagination, you construct the physical, social, and technological foundations of the world in which the story unfolds.

## Core Responsibilities
1. Define the world's physical laws and technological level
2. Design social structures, political systems, and economic systems
3. Establish historical context and the structure of current conflicts
4. Describe the environment and atmosphere of each location

## Working Principles
- Internal consistency is the top priority — there must be no contradictions between settings
- Use cascading "what if this technology existed?" questions to reason through the world's ripple effects
- A world that serves the story — avoid excessive world-building that obstructs the plot

## Input / Output Protocol
- Input: User's world concept, genre requirements
- Output: `_workspace/01_worldbuilder_setting.md`
- Format: Markdown, organized by section (physics / society / technology / history / locations)

## Team Communication Protocol
- To character-designer: SendMessage with social structure, class system, and occupation information
- To plot-architect: SendMessage with the world's major conflict structure and crisis elements
- From science-consultant: Receive scientific error feedback → revise settings
- Broadcast to all relevant team members when world settings change

## Error Handling
- If the concept is ambiguous, propose 3 directions and ask for a choice
- When a scientific error is found, present alternatives alongside the finding

## Collaboration
- Provide social structure information to character-designer
- Provide conflict structure information to plot-architect
- Revise settings to incorporate feedback from science-consultant
```

### Detailed Team Workflow

```
Phase 1: TeamCreate(team_name: "novel-team", members: [worldbuilder, character-designer, plot-architect])
         TaskCreate([world-building, character design, plot structure])
         → Team members self-coordinate and work in parallel
         → worldbuilder sends SendMessage to character-designer when social structure is complete
         → character-designer sends SendMessage to plot-architect when protagonist is defined

Phase 2: Disband Phase 1 team → invoke prose-stylist as a sub-agent (no team needed for solo writing)
         prose-stylist reads the 3 outputs in _workspace/ and writes
         → Saves result to _workspace/02_prose_draft.md

Phase 3: Create new team — TeamCreate(team_name: "review-team", members: [science-consultant, continuity-manager])
         (Only one team active per session, but Phase 1 team was disbanded so a new team can be created)
         → Two reviewers examine the draft and share findings with each other
         → science-consultant notifies continuity-manager when a physics error is found
         → Disband team after review is complete

Phase 4: Invoke prose-stylist as a sub-agent, incorporate review results, and produce final revision
```

---

## Example 3: Webtoon Production Team (Sub-Agent Mode)

### Team Architecture: Generate-Validate
### Execution Mode: Sub-Agent

> In the generate-validate pattern, there are only 2 agents and result handoff is more important than real-time communication, making sub-agent the right fit.

```
Phase 1: Agent(webtoon-artist) → generate panels
Phase 2: Agent(webtoon-reviewer) → quality review
Phase 3: Agent(webtoon-artist) → regenerate problem panels (max 2 iterations)
```

### Agent Configuration

| Agent | subagent_type | Role | Skill |
|-------|--------------|------|-------|
| webtoon-artist | custom | Panel image generation | generate-webtoon |
| webtoon-reviewer | custom | Quality review | review-webtoon, fix-webtoon-panel |

### Full Agent File Example: `webtoon-reviewer.md`

```markdown
---
name: webtoon-reviewer
description: "Specialist in reviewing the quality of webtoon panels. Evaluates composition, character consistency, text readability, and direction."
---

# Webtoon Reviewer — Webtoon Quality Review Specialist

You are a specialist in reviewing the quality of webtoon panels. You evaluate panels against criteria of visual completeness, story delivery, and character consistency.

## Core Responsibilities
1. Evaluate the composition and visual completeness of each panel
2. Verify character appearance consistency across panels
3. Evaluate the readability and placement of speech bubble text
4. Review the directorial flow and pacing of the overall episode

## Working Principles
- Render a clear verdict using three tiers: PASS / FIX / REDO
- FIX applies when partial correction is sufficient; REDO applies when full regeneration is required
- Judge by objective criteria (consistency, readability, composition), not subjective preference

## Input / Output Protocol
- Input: Panel images in the `_workspace/panels/` directory
- Output: `_workspace/review_report.md`
- Format:
  ```
  ## Panel {N}
  - Verdict: PASS | FIX | REDO
  - Reason: [specific reason]
  - Revision instruction: [specific correction direction if FIX / REDO]
  ```

## Error Handling
- If an image fails to load, mark that panel as REDO
- After 2 regeneration attempts, force PASS with a warning for any remaining REDO panels

## Collaboration
- Deliver revision instructions to webtoon-artist (via output file)
- Re-review regenerated panels (max 2-iteration loop)
```

### Error Handling

```
Retry policy:
- REDO verdict panel → request regeneration from artist (with specific revision instructions)
- Force PASS after maximum 2 iterations
- If 50% or more of all panels are REDO, suggest prompt revision to the user
```

---

## Example 4: Code Review Team (Agent Team Mode)

### Team Architecture: Fan-out / Fan-in + Discussion
### Execution Mode: Agent Team

> Code review is a prime example where agent teams shine. Reviewers from different perspectives share findings and challenge each other, enabling deeper review.

```
[Leader] → TeamCreate(review-team)
    ├── security-reviewer: check security vulnerabilities
    ├── performance-reviewer: analyze performance impact
    └── test-reviewer: verify test coverage
    → Reviewers share findings with each other (SendMessage)
    → Leader consolidates results
```

### Team Communication Patterns

```
security ──SendMessage──→ performance  ("This SQL query is injectable — please also check from a performance angle")
performance ──SendMessage──→ test      ("Found N+1 query — please check whether related tests exist")
test ────SendMessage──→ security      ("No tests for auth module — what's the priority from a security perspective?")
```

Key point: Reviewers communicate **directly without going through the leader**, enabling rapid detection of cross-domain issues.

---

## Example 5: Supervisor Pattern — Code Migration Team (Agent Team Mode)

### Team Architecture: Supervisor
### Execution Mode: Agent Team

```
[supervisor / leader] → analyze file list → assign batches
    ├→ [migrator-1] (batch A)
    ├→ [migrator-2] (batch B)
    └→ [migrator-3] (batch C)
    ← Receive TaskUpdate → assign additional batches or reassign
```

### Agent Configuration

| Member | Role |
|--------|------|
| (leader = migration-supervisor) | File analysis, batch distribution, progress management |
| migrator-1~3 | Migrate the assigned file batch |

### Supervisor's Dynamic Distribution Logic (Using Agent Team)

```
1. Collect the full list of target files
2. Estimate complexity (file size, number of imports, dependencies)
3. Register file batches as tasks via TaskCreate (including dependencies)
4. Team members self-claim tasks
5. When a member reports completion via TaskUpdate:
   - Success → automatically claim the next task
   - Failure → leader confirms the cause via SendMessage → reassign or hand off to another member
6. All tasks complete → leader runs integration tests
```

Difference from fan-out: Tasks are not fixed in advance — they are **dynamically assigned at runtime**. The self-claim feature of the shared task list maps naturally to the supervisor pattern.

---

## Output Pattern Summary

### Agent Definition Files
Location: `project/.claude/agents/{agent-name}.md`
Required sections: Core responsibilities, working principles, input/output protocol, error handling, collaboration
Additional section for team mode: **Team communication protocol** (messages sent/received, task claim scope)

### Skill File Structure
Location: `project/.claude/skills/{skill-name}/SKILL.md` (project level)
Or: `~/.claude/skills/{skill-name}/SKILL.md` (global level)

### Integration Skill (Orchestrator)
A top-level skill that coordinates the entire team. Defines agent configuration and workflow for each scenario.
Template: see `references/orchestrator-template.md`.
**Always specify the execution mode** — agent team (default) or sub-agent.
