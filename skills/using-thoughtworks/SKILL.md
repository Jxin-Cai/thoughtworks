---
name: using-thoughtworks
description: Use when starting any conversation - establishes how to find and use thoughtworks DDD skills, requiring Skill tool invocation before ANY DDD-related response
---

<EXTREMELY-IMPORTANT>
If the user's request involves DDD, domain modeling, layered architecture design, Java code generation for a DDD project, or frontend development based on DDD API contracts, you ABSOLUTELY MUST invoke the relevant thoughtworks skill.

IF A THOUGHTWORKS SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you — follow it directly. Never use the Read tool on skill files.

## Available Skills

### Root Level (Fullstack)

| Skill | Trigger | Description |
|-------|---------|-------------|
| `thoughtworks-skills-all` | User wants fullstack end-to-end | Orchestrates backend DDD + frontend in sequence |
| `thoughtworks-skills-branch` | Manage feature branch for an idea | Creates feature/<idea-name> from main/master, called by orchestrators |
| `thoughtworks-skills-merge` | Merge feature branch back to main | Squash merges feature/<idea-name> to main/master, called by orchestrators |

### Backend (DDD)

| Skill | Trigger | Description |
|-------|---------|-------------|
| `thoughtworks-skills-backend` | User wants backend DDD feature | Main entry: requirements → design → implementation |
| `thoughtworks-skills-backend-clarify` | User wants to clarify backend requirements | Project context scan + structured requirement clarification |
| `thoughtworks-skills-backend-thought` | User wants backend design only | Orchestrates thinker subagents for layered design docs |
| `thoughtworks-skills-backend-works` | User wants to code from backend design | Orchestrates worker subagents for Java implementation |
| `thoughtworks-skills-java-spec` | Need Java DDD coding spec | Routes to layer-specific coding constraints |

### Frontend

| Skill | Trigger | Description |
|-------|---------|-------------|
| `thoughtworks-skills-frontend` | User wants frontend development | Main entry: requirements → design → implementation |
| `thoughtworks-skills-frontend-clarify` | User wants to clarify frontend requirements | Project context scan + structured frontend requirement clarification |
| `thoughtworks-skills-frontend-thought` | User wants frontend design only | Orchestrates frontend thinker for design docs |
| `thoughtworks-skills-frontend-works` | User wants to code from frontend design | Orchestrates frontend worker for implementation |
| `thoughtworks-skills-frontend-spec` | Need frontend coding spec | Routes to tech-stack-specific frontend coding constraints |

## Slash Commands

| Command | Maps to |
|---------|---------|
| `/thoughtworks-skills-all` | Fullstack: backend DDD + frontend end-to-end |
| `/thoughtworks-skills-backend` | Backend DDD workflow |
| `/thoughtworks-skills-backend-clarify` | Backend requirements clarification |
| `/thoughtworks-skills-backend-thought` | Backend design phase only |
| `/thoughtworks-skills-backend-works` | Backend coding phase only |
| `/thoughtworks-skills-frontend` | Frontend workflow |
| `/thoughtworks-skills-frontend-clarify` | Frontend requirements clarification |
| `/thoughtworks-skills-frontend-thought` | Frontend design phase only |
| `/thoughtworks-skills-frontend-works` | Frontend coding phase only |
| `/thoughtworks-branch` | Feature branch management for an idea |
| `/thoughtworks-skills-merge` | Feature branch squash merge back to main |

## Trigger Rules

| User Intent | Skill to Invoke |
|-------------|----------------|
| DDD, domain modeling, layered architecture, Java backend | Backend skills (`/thoughtworks-skills-backend`) |
| Frontend pages, components, UI consuming API | Frontend skills (`/thoughtworks-skills-frontend`) |
| Fullstack, end-to-end, both backend and frontend | Fullstack skill (`/thoughtworks-skills-all`) |

## The Rule

**Invoke relevant skills BEFORE any response or action.** When the user mentions DDD, domain modeling, layered architecture, frontend consuming DDD APIs, or fullstack development, invoke the appropriate skill first.

```
User message received
  → Is this DDD backend-related? → /thoughtworks-skills-backend
  → Is this frontend consuming DDD APIs? → /thoughtworks-skills-frontend
  → Is this fullstack? → /thoughtworks-skills-all
  → None of the above → Respond normally
```

## Red Flags

| Thought | Reality |
|---------|---------|
| "I can just write the code directly" | DDD code needs design-first. Use the skill. |
| "This is a simple domain model" | Simple models still need contract validation. Use the skill. |
| "I already know DDD patterns" | The skill enforces specific contract-driven workflows. Use it. |
| "Let me just create the entity first" | Workers follow design docs. Start with /thoughtworks-skills-backend. |
| "Frontend doesn't need the DDD skill" | Frontend consumes OHS contracts. Use /thoughtworks-skills-frontend. |
| "I'll do backend and frontend together" | Use /thoughtworks-skills-all for proper sequencing. |

## Workflow Overview

### Backend Only (`/thoughtworks-skills-backend`)

```
/thoughtworks-skills-backend (Decision-Maker)
  Step 1: Receive requirement
  Step 2: → /thoughtworks-skills-backend-clarify (Project scan + clarify)
  Step 2.5: → /thoughtworks-branch (Feature branch management)
  Step 3: Layer assessment → assessment.md
  Step 4: Phase loop (for each phase):
    4.1 → /thoughtworks-skills-backend-thought --layers <phase layers> (Design)
    4.2 User confirms phase design (HARD-GATE)
    4.3 → /thoughtworks-skills-backend-works --layers <phase layers> (Coding)
  Step 5: Mark .approved
  Step 6: Engineering support tasks
  Step 7: → /thoughtworks-skills-merge (Squash merge feature branch)
  Step 8: Final summary
```

### Frontend Only (`/thoughtworks-skills-frontend`)

```
/thoughtworks-skills-frontend (Decision-Maker)
  Step 1: Receive idea-name (requires backend OHS design)
  Step 2: → /thoughtworks-skills-frontend-clarify (Project scan + clarify)
  Step 2.5: → /thoughtworks-branch (Feature branch management)
  Step 3: Frontend assessment
  Step 4: → /thoughtworks-skills-frontend-thought (Design)
  Step 5: User confirms design → .frontend-approved
  Step 6: → /thoughtworks-skills-frontend-works (Coding)
  Step 7: Final summary
  Step 8: → /thoughtworks-skills-merge (Squash merge feature branch)
```

### Fullstack (`/thoughtworks-skills-all`)

```
/thoughtworks-skills-all (Orchestrator — directly orchestrates sub-skills)
  Step 1: Receive requirement
  Step 2: → /thoughtworks-skills-backend-clarify (Backend clarify)
  Step 3: → /thoughtworks-skills-frontend-clarify (Frontend clarify)
  Step 3.5: → /thoughtworks-branch (Feature branch management)
  Step 4: Backend layer assessment → assessment.md
  Step 5: Backend phase loop (for each phase):
    5.1 → /thoughtworks-skills-backend-thought --layers <phase layers> (Design)
    5.2 User confirms phase design
    5.3 → /thoughtworks-skills-backend-works --layers <phase layers> (Coding)
  Step 6: Mark .approved
  Step 7: Frontend assessment → frontend-assessment.md
  Step 8: → /thoughtworks-skills-frontend-thought (Frontend design)
  Step 9: User confirms frontend design → .frontend-approved
  Step 10: → /thoughtworks-skills-frontend-works (Frontend coding)
  Step 11: → /thoughtworks-skills-merge (Squash merge context branch)
  Step 12: Fullstack summary
```
