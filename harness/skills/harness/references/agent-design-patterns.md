# Agent Team Design Patterns

## Execution Modes: Agent Teams vs Sub-agents

Understand the key differences between the two execution modes and choose the appropriate one.

### Agent Teams — Default Mode

The team leader forms a team using `TeamCreate`, and team members run as independent Claude Code instances. Members communicate directly via `SendMessage` and self-coordinate through a shared task list (`TaskCreate`/`TaskUpdate`).

```
[Leader] ←→ [MemberA] ←→ [MemberB]
  ↕             ↕             ↕
  └──── Shared Task List ────┘
```

**Core tools:**
- `TeamCreate`: Create a team + spawn members
- `SendMessage({to: name})`: Message a specific member
- `SendMessage({to: "all"})`: Broadcast (high cost, use sparingly)
- `TaskCreate`/`TaskUpdate`: Manage the shared task list

**Characteristics:**
- Members can talk directly to each other, challenge each other, and verify each other's work
- Members exchange information without routing through the leader
- Self-coordination via shared task list (members can request tasks themselves)
- Leader is automatically notified when a member becomes idle
- Plan approval mode enables review before risky operations

**Constraints:**
- Only one team can be **active** per session (though a team can be dissolved between phases and a new one formed)
- No nested teams (a team member cannot create its own team)
- Leader is fixed (cannot be transferred)
- High token cost

**Team reformation pattern:**
When different specialist combinations are needed per phase, save the previous team's outputs to files → dissolve the team → create a new team. Previous team outputs are preserved in `_workspace/`, so the new team can access them via Read.

### Sub-agents — Lightweight Mode

The main agent creates sub-agents using the `Agent` tool. Sub-agents return their results only to the main agent and do not communicate with each other.

```
[Main] → [SubA] → return result
       → [SubB] → return result
       → [SubC] → return result
```

**Core tools:**
- `Agent(prompt, subagent_type, run_in_background)`: Create a sub-agent

**Characteristics:**
- Lightweight and fast
- Results are summarized and returned to the main context
- Token efficient

**Constraints:**
- No communication between sub-agents
- Main agent handles all coordination
- No real-time collaboration or challenge

### Mode Selection Decision Tree

```
Are there 2 or more agents?
├── Yes → Is inter-agent communication needed?
│         ├── Yes → Agent team (default)
│         │         Cross-validation, shared discoveries, real-time feedback improve quality.
│         │
│         └── No → Sub-agents are also viable
│                  For produce-then-verify, expert pool patterns where only result handoff is needed.
│
└── No (1 agent) → Sub-agent
                   Single agent does not need a team.
```

> **Core principle:** Agent teams are the default. When choosing sub-agents, ask yourself: "Is inter-member communication truly unnecessary?"

---

## Agent Team Architecture Types

### 1. Pipeline
Sequential task flow. The output of each agent becomes the input to the next.

```
[Analyze] → [Design] → [Implement] → [Verify]
```

**When to use:** Each stage depends strongly on the output of the previous stage
**Example:** Novel writing — world-building → characters → plot → writing → editing
**Caution:** A bottleneck delays the entire pipeline. Design each stage to be as independent as possible.
**Team mode fit:** Strong sequential dependency limits the benefit of team mode. However, team mode is useful when parallel segments exist within the pipeline.

### 2. Fan-out/Fan-in
Parallel processing followed by result integration. Independent tasks run simultaneously.

```
          ┌→ [ExpertA] ─┐
[Dispatch] → ├→ [ExpertB] ─┼→ [Integrate]
          └→ [ExpertC] ─┘
```

**When to use:** Different perspectives or domain analyses are needed for the same input
**Example:** Comprehensive research — simultaneous investigation of official sources / media / community / background → integrated report
**Caution:** The quality of the integration stage determines overall quality.
**Team mode fit:** The most natural pattern for agent teams. **Must be implemented as an agent team.** Members share discoveries and challenge each other, and one agent's findings can redirect another agent's investigation in real time — significantly improving quality compared to isolated parallel work.

### 3. Expert Pool
Select and invoke the appropriate expert based on context.

```
[Router] → { ExpertA | ExpertB | ExpertC }
```

**When to use:** Different processing is needed depending on the type of input
**Example:** Code review — invoke only the relevant specialist among security / performance / architecture experts
**Caution:** The router's classification accuracy is critical.
**Team mode fit:** Sub-agents are more appropriate. Only the needed expert is invoked, so a standing team is unnecessary.

### 4. Producer-Reviewer
A producer agent and a reviewer agent operate as a pair.

```
[Producer] → [Reviewer] → (if issues found) → [Producer] re-runs
```

**When to use:** Output quality assurance is important and objective verification criteria exist
**Example:** Webtoon — artist produces → reviewer inspects → problematic panels re-generated
**Caution:** Set a maximum retry count (2–3) to prevent infinite loops.
**Team mode fit:** Agent team is useful. Real-time feedback exchange between producer and reviewer via SendMessage.

### 5. Supervisor
A central agent manages task state and dynamically distributes work to worker agents.

```
          ┌→ [WorkerA]
[Supervisor] ─┼→ [WorkerB]    ← Supervisor observes state and assigns dynamically
          └→ [WorkerC]
```

**When to use:** Workload is variable or task distribution must be decided at runtime
**Example:** Large-scale code migration — supervisor analyzes the file list and assigns batches to workers
**Difference from Fan-out:** Fan-out distributes tasks upfront with fixed assignments; Supervisor observes progress and adjusts dynamically
**Caution:** Set delegation units large enough so the supervisor does not become a bottleneck.
**Team mode fit:** The shared task list of an agent team maps naturally to the supervisor pattern. Register tasks via TaskCreate; team members self-request tasks.

### 6. Hierarchical Delegation
A higher-level agent recursively delegates to lower-level agents. Complex problems are decomposed step by step.

```
[Director] → [LeadA] → [WorkerA1]
                      → [WorkerA2]
           → [LeadB] → [WorkerB1]
```

**When to use:** The problem naturally decomposes in a hierarchical structure
**Example:** Full-stack app development — director → frontend lead → (UI / logic / tests) + backend lead → (API / DB / tests)
**Caution:** Depth beyond 3 levels causes significant latency and context loss. 2 levels or fewer recommended.
**Team mode fit:** Agent teams cannot be nested (a team member cannot create a team). Implement the first level as a team and the second level as sub-agents, or flatten the structure into a single team.

## Composite Patterns

In practice, composite patterns are more common than single patterns:

| Composite Pattern | Composition | Example |
|------------------|-------------|---------|
| **Fan-out + Producer-Reviewer** | Parallel production followed by individual review | Multilingual translation — 4 languages translated in parallel → each reviewed by a native reviewer |
| **Pipeline + Fan-out** | Some stages within a sequential pipeline are parallelized | Analysis (sequential) → implementation (parallel) → integration testing (sequential) |
| **Supervisor + Expert Pool** | Supervisor dynamically invokes experts | Customer inquiry handling — supervisor classifies the inquiry then assigns the appropriate expert |

### Execution Mode in Composite Patterns

**By default, use agent teams for all composite patterns.** Active communication between members is the core driver of output quality.

| Scenario | Recommended Mode | Reason |
|----------|-----------------|--------|
| **Research + Analysis** | Agent team | Investigators share discoveries, discuss conflicting information in real time |
| **Design + Implementation + Verification** | Agent team | Feedback loop among designer ↔ implementer ↔ verifier |
| **Supervisor + Worker** | Agent team | Dynamic assignment via shared task list, workers share progress with each other |
| **Producer + Reviewer** | Agent team | Real-time feedback between producer ↔ reviewer minimizes rework |

> Consider mixing in sub-agents only when a single agent performs a completely isolated, one-shot task.

## Agent Type Selection

When invoking an agent, specify the type via the `subagent_type` parameter of the Agent tool. Agent team members can also use custom agent definitions.

### Built-in Types

| Type | Tool Access | Suitable For |
|------|-------------|--------------|
| `general-purpose` | Full access (including WebSearch, WebFetch) | Web research, general-purpose tasks |
| `Explore` | Read-only (no Edit/Write) | Codebase exploration, analysis |
| `Plan` | Read-only (no Edit/Write) | Architecture design, planning |

### Custom Types

Define an agent in `.claude/agents/{name}.md` and invoke it with `subagent_type: "{name}"`. Custom agents have full tool access.

### Selection Criteria

| Situation | Recommended | Reason |
|-----------|-------------|--------|
| Complex role reused across multiple sessions | **Custom type** (`.claude/agents/`) | Manage persona and task principles as a file |
| Simple research/collection, prompt alone is sufficient | **`general-purpose`** + detailed prompt | No agent file needed; include instructions in the prompt |
| Read-only code access needed (analysis/review) | **`Explore`** | Prevents accidental file modification |
| Design/planning only | **`Plan`** | Focus on analysis, prevent code changes |
| Implementation work requiring file edits | **Custom type** | Full tool access + specialized instructions |

**Principle:** Every agent must be defined as a `.claude/agents/{name}.md` file. Even for built-in types, create an agent definition file to specify the role, principles, and protocol. The file must exist for reuse in future sessions, and the team communication protocol must be specified to guarantee collaboration quality.

**Model:** All agents use `model: "opus"`. When calling the Agent tool, always specify the `model: "opus"` parameter.

## Agent Definition Structure

```markdown
---
name: agent-name
description: "1-2 sentence role description. List trigger keywords."
---

# Agent Name — One-line role summary

You are a [role] expert in [domain].

## Core Responsibilities
1. Responsibility 1
2. Responsibility 2

## Working Principles
- Principle 1
- Principle 2

## Input/Output Protocol
- Input: [what is received and from where]
- Output: [what is written and where]
- Format: [file format, structure]

## Team Communication Protocol (Agent Team Mode)
- Receiving messages: [from whom and what kind of messages]
- Sending messages: [to whom and what kind of messages]
- Task requests: [what types of tasks to request from the shared task list]

## Error Handling
- [Action on failure]
- [Action on timeout]

## Collaboration
- Relationships with other agents
```

## Agent Separation Criteria

| Criterion | Separate | Merge |
|-----------|----------|-------|
| Expertise | Different domains → separate | Overlapping domains → merge |
| Parallelism | Can run independently → separate | Sequentially dependent → consider merging |
| Context | Heavy context load → separate | Lightweight and fast → merge |
| Reusability | Used by other teams → separate | Used only by this team → consider merging |

## Designing for Agent Reusability

Before creating a new agent, check for overlap with existing agents. Repeated harness construction tends to accumulate agents with overlapping roles under different names.

| Situation | Action |
|-----------|--------|
| Existing agent fully covers the new role | Do not create — reuse the existing agent |
| Existing agent partially covers and can be generalized | Generalize the existing agent to extend it |
| Partial overlap is intentionally domain-specific | Create new — keep as a separate agent |
| Role scope is entirely different | Create new |

**Principle:** The more an agent focuses on a single role, the higher its reusability and the lower the duplication. If a role has two or more responsibilities, first consider whether it can be split.

**When generalizing an existing agent:** The behavior of orchestrators and team configurations that depend on that agent may change. Verify dependencies before extending, and confirm that existing behavior is preserved via a dry run after generalization.

## Skill vs Agent Distinction

| Distinction | Skill | Agent |
|-------------|-------|-------|
| Definition | Procedural knowledge + tool bundle | Expert persona + behavioral principles |
| Location | `.claude/skills/` | `.claude/agents/` |
| Trigger | User request keyword matching | Explicit invocation via Agent tool |
| Size | Small to large (workflows) | Small (role definition) |
| Purpose | "How to do it" | "Who does it" |

A skill is a **procedural guide** that an agent references when performing a task.
An agent is an **expert role definition** that leverages skills.

## Skill ↔ Agent Connection Methods

Three ways an agent can leverage a skill:

| Method | Implementation | When to Use |
|--------|----------------|-------------|
| **Skill tool invocation** | Specify `call /skill-name via the Skill tool` in the agent prompt | When the skill is an independent workflow and can be invoked by the user |
| **Inline in prompt** | Include the skill content directly inside the agent definition | When the skill is short (50 lines or fewer) and exclusive to this agent |
| **Reference load** | Load the skill's `references/` file on demand via `Read` | When the skill content is large and only conditionally needed |

Recommendation: Use the Skill tool for high reusability, inline for exclusive use, reference load for large content.
