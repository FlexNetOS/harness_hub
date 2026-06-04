# QA Agent Design Guide

A reference guide for including QA agents in a build harness. Based on bug patterns discovered in a real project (SatangSlide) and their root cause analysis, this guide provides a verification methodology for systematically catching defects that QA tends to miss.

---

## Table of Contents

1. Defect Patterns That QA Agents Miss
2. Integration Coherence Verification
3. QA Agent Design Principles
4. Verification Checklist Template
5. QA Agent Definition Template

---

## 1. Defect Patterns That QA Agents Miss

### 1-1. Boundary Mismatch

The most frequent defect. Two components are each implemented "correctly," but the contract breaks at their connection point.

| Boundary/Interface | Mismatch Example | Why It Gets Missed |
|--------|-----------|-----------|
| API response → front-end hook | API returns `{ projects: [...] }`, hook expects `SlideProject[]` | Each side passes individual validation; no cross-comparison done |
| API response field name → type definition | API uses `thumbnailUrl` (camelCase), type uses `thumbnail_url` (snake_case) | TypeScript generic casting lets the compiler miss it |
| File path → link href | Page lives at `/dashboard/create` but link points to `/create` | File structure and href are never cross-compared |
| State transition map → actual status updates | Map defines `generating_template → template_approved`, transition missing in code | Only checks that the map exists; doesn't trace all update code |
| API endpoint → front-end hook | API exists but no corresponding hook (never called) | API list and hook list are never mapped 1:1 |
| Immediate response → async result | API immediately returns `{ status }`, front-end accesses `data.failedIndices` | Only checks types without distinguishing sync vs. async responses |

### 1-2. Why Static Code Review Misses These

- **Limits of TypeScript generics**: `fetchJson<SlideProject[]>()` — compiles fine even if the runtime response is `{ projects: [...] }`
- **`npm run build` passing ≠ correct behavior**: Type casting, `any`, and generics allow a successful build that fails at runtime
- **Existence verification vs. connection verification**: "Does the API exist?" and "Does the API's response match what the caller expects?" are entirely different checks

---

## 2. Integration Coherence Verification

**Cross-comparison verification** areas that must be included in every QA agent.

### 2-1. API Response ↔ Front-End Hook Type Cross-Verification

**Method**: Compare the object passed to `NextResponse.json()` in each API route against the type parameter of the corresponding hook's `fetchJson<T>`.

```
Verification steps:
1. Extract the shape of the object passed to NextResponse.json() in the API route
2. Identify the T type in the corresponding hook's fetchJson<T>
3. Compare whether shape and T match
4. Check for wrapping (if the API returns { data: [...] }, verify the hook unwraps .data)
```

**Patterns to watch closely:**
- Pagination APIs: `{ items: [], total, page }` vs. front-end expecting a plain array
- Mismatches across the chain: snake_case DB fields → camelCase API response → front-end type definitions
- Shape differences between immediate responses (202 Accepted) and final results

### 2-2. File Path ↔ Link/Router Path Mapping

**Method**: Extract the URL paths for page files under `src/app/`, then cross-reference against all `href`, `router.push()`, and `redirect()` values in the codebase.

```
Verification steps:
1. Extract URL patterns from page.tsx file paths under src/app/
   - (group) → removed from URL
   - [param] → dynamic segment
2. Collect all href=, router.push(, redirect( values in the codebase
3. Confirm each link matches an actually existing page path
4. Watch for URL prefixes on pages inside route groups (e.g., under dashboard/)
```

### 2-3. State Transition Completeness Tracking

**Method**: Extract all `status:` updates from the codebase and cross-reference them against the state transition map.

```
Verification steps:
1. Extract the list of allowed transitions from the state transition map (STATE_TRANSITIONS)
2. Search all API routes for the .update({ status: "..." }) pattern
3. Confirm each transition is defined in the map
4. Identify transitions defined in the map but never executed in code (dead transitions)
5. Pay special attention to: transitions from intermediate states (e.g., generating_template) to final states (template_approved) being missing
```

### 2-4. API Endpoint ↔ Front-End Hook 1:1 Mapping

**Method**: List all API routes and front-end hooks and verify they pair up correctly.

```
Verification steps:
1. Extract per-HTTP-method endpoint list from route.ts files under src/app/api/
2. Extract fetch call URL list from use*.ts files under src/hooks/
3. Identify API endpoints not called by any hook → flag as "unused"
4. Determine whether "unused" is intentional (e.g., admin API) or accidental (missing hook call)
```

---

## 3. QA Agent Design Principles

### 3-1. Use general-purpose Type, Not Explore Type

If a QA agent is typed as `Explore`, it can only read. But effective QA requires:
- Grep for pattern searching (extracting all `NextResponse.json()` calls)
- Script execution for automated cross-comparison (API shape vs. hook types)
- The ability to apply fixes when needed

**Recommendation**: Set the type to `general-purpose`, and explicitly specify a "verify → report → request fix" protocol in the agent definition.

### 3-2. Prioritize "Cross-Comparison" Over "Existence Checks" in Checklists

| Weak Checklist | Strong Checklist |
|---------------|---------------|
| Does the API endpoint exist? | Does the API endpoint's response shape match the corresponding hook's type? |
| Is the state transition map defined? | Do all status update code paths match the map's transitions? |
| Does the page file exist? | Do all links in the code point to actually existing pages? |
| Is TypeScript strict mode enabled? | Is there any type safety bypassed via generic casting? |

### 3-3. The "Read Both Sides Simultaneously" Principle

To catch boundary/interface bugs, QA must never read only one side. It must always:
- Read the API route **and** the corresponding hook **together**
- Read the state transition map **and** the actual update code **together**
- Read the file structure **and** the link paths **together**

State this principle explicitly in the agent definition.

### 3-4. Run QA Immediately After Each Module Completes, Not After the Full Build

If the orchestrator places QA only in "Phase 4: After Everything Is Done":
- Bugs accumulate and become more costly to fix
- Early boundary/interface mismatches propagate into downstream modules

**Recommended pattern**: Perform cross-verification of each API + its corresponding hook immediately after each backend API is completed (incremental QA).

---

## 4. Verification Checklist Template

An integration coherence checklist for web applications to include in QA agent definitions.

```markdown
### Integration Coherence Verification (Web App)

#### API ↔ Front-End Connection
- [ ] Response shape of every API route matches the generic type of the corresponding hook
- [ ] Wrapped responses ({ items: [...] }) are unwrapped by the hook
- [ ] snake_case ↔ camelCase conversion is applied consistently
- [ ] Front-end distinguishes between immediate responses (202) and final result shapes
- [ ] Every API endpoint has a corresponding front-end hook that is actually called

#### Routing Coherence
- [ ] All href/router.push values in code match actual page file paths
- [ ] Path validation accounts for route groups ((group)) being removed from URLs
- [ ] Dynamic segments ([id]) are populated with the correct parameters

#### State Machine Coherence
- [ ] All defined state transitions are executed in code (no dead transitions)
- [ ] All status updates in code are defined in the transition map (no unauthorized transitions)
- [ ] No missing transitions from intermediate states to final states
- [ ] Status-based branches in the front-end (if status === "X") use values that are actually reachable

#### Data Flow Coherence
- [ ] Mapping between DB schema field names and API response field names is consistent
- [ ] Front-end type definitions match API response field names
- [ ] null/undefined handling for optional fields is consistent on both sides
```

---

## 5. QA Agent Definition Template

Core sections to include in a QA agent in a build harness.

```markdown
---
name: qa-inspector
description: "QA verification specialist. Validates spec compliance, integration coherence, and design quality."
---

# QA Inspector

## Core Role
Verifies implementation quality against the spec and **integration coherence between modules**.

## Verification Priorities

1. **Integration coherence** (highest) — boundary/interface mismatches are the leading cause of runtime errors
2. **Functional spec compliance** — API / state machine / data model
3. **Design quality** — colors / typography / responsiveness
4. **Code quality** — unused code, naming conventions

## Verification Method: "Read Both Sides Simultaneously"

Boundary/interface verification always requires **opening both sides of the code at the same time** for comparison:

| Verification Target | Left (Producer) | Right (Consumer) |
|----------|-------------|---------------|
| API response shape | NextResponse.json() in route.ts | fetchJson<T> in hooks/ |
| Routing | page file paths under src/app/ | href, router.push values |
| State transitions | STATE_TRANSITIONS map | .update({ status }) code |
| DB → API → UI | table column names | API response fields → type definitions |

## Team Communication Protocol

- Upon discovery, send a specific fix request to the responsible agent (file:line + how to fix)
- For boundary/interface issues, notify **both** agents on each side
- To the leader: verification report (distinguish pass / fail / unverified items)
```

---

## Real-World Cases: Bugs Found in SatangSlide

All content in this guide is derived from lessons learned from the following real bugs:

| Bug | Boundary/Interface | Cause |
|------|--------|------|
| `projects?.filter is not a function` | API→hook | API returns `{projects:[]}`, hook expects array |
| All dashboard links 404 | file path→href | Missing `/dashboard/` prefix |
| Theme image not displayed | API→component | `thumbnailUrl` vs `thumbnail_url` |
| Theme selection not saved | API→hook | select-theme API exists, hook missing |
| Create page waits forever | state transition→code | `template_approved` transition code missing |
| `data.failedIndices` crash | immediate response→front-end | Background result accessed from immediate response |
| View slide after completion 404 | file path→href | `/projects/` → `/dashboard/projects/` |
