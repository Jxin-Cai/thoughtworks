---
name: using-thoughtworks
description: Use when starting any conversation - establishes how to find and use thoughtworks DDD skills, requiring Skill tool invocation before ANY DDD-related response
---

<EXTREMELY-IMPORTANT>
If the user's request involves DDD, domain modeling, layered architecture design, Java code generation for a DDD project, or frontend development based on DDD API contracts, you ABSOLUTELY MUST invoke the relevant thoughtworks skill.

IF A THOUGHTWORKS SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.

**HOW to invoke: Use the `Skill` tool.** Do NOT try to follow the workflow steps manually. Do NOT explore the codebase, read requirement files, or write any code before invoking the skill. The skill contains all the logic — your only job is to invoke it.
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
| "Let me explore the codebase first" | The skill's clarify step does project scanning. Invoke the skill first. |
| "I understand the workflow, I can follow the steps myself" | Understanding the flow does NOT replace invoking the Skill tool. The skill enforces HARD-GATEs, contract validation, and state management that you cannot replicate manually. INVOKE THE SKILL. |
| "I'll just read the requirement file and start coding" | Requirements need clarification with the user first. Invoke the skill. |

## Workflow Overview

These are **high-level summaries for reference only**. Do NOT use them as execution instructions. Always invoke the skill via the `Skill` tool — the skill handles all internal steps, HARD-GATEs, and state management.

### Backend Only

Invoke: `Skill(skill: "thoughtworks-skills-backend", args: "<requirement>")`

Handles: requirement clarification → branch → layer assessment → phase loop (design → confirm → coding) → merge → engineering tasks → summary

### Frontend Only

Invoke: `Skill(skill: "thoughtworks-skills-frontend", args: "<idea-name>")`

Handles: requirement clarification (based on OHS contracts) → branch → assessment → design → confirm → coding → summary → merge

### Fullstack

Invoke: `Skill(skill: "thoughtworks-skills-all", args: "<requirement>")`

Handles: requirement classification → backend clarification → branch → backend (assessment → phase loop → approved) → frontend (clarification → assessment → design → confirm → coding) → merge → engineering tasks → summary
