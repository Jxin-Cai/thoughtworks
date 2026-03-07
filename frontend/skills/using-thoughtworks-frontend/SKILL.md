---
name: using-thoughtworks-frontend
description: Use when starting any conversation - establishes how to find and use thoughtworks frontend skills, requiring Skill tool invocation before ANY frontend DDD API-related response
---

<EXTREMELY-IMPORTANT>
If the user's request involves frontend development based on DDD API contracts, you ABSOLUTELY MUST invoke the relevant thoughtworks frontend skill.

IF A THOUGHTWORKS SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you — follow it directly. Never use the Read tool on skill files.

## Available Skills

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
| `/thoughtworks-frontend` | Frontend workflow |
| `/thoughtworks-frontend-clarify` | Frontend requirements clarification |
| `/thoughtworks-frontend-thought` | Frontend design phase only |
| `/thoughtworks-frontend-works` | Frontend coding phase only |

## Trigger Rules

| User Intent | Skill to Invoke |
|-------------|----------------|
| Frontend pages, components, UI consuming DDD API | `/thoughtworks-frontend` |
| Clarify or refine frontend requirements | `/thoughtworks-frontend-clarify` |
| Design frontend only | `/thoughtworks-frontend-thought` |
| Code from existing frontend design | `/thoughtworks-frontend-works` |

## The Rule

**Invoke relevant skills BEFORE any response or action.** When the user mentions frontend development consuming DDD APIs, invoke the appropriate skill first.

```
User message received
  → Is this frontend consuming DDD APIs? → /thoughtworks-frontend
  → None of the above → Respond normally
```

## Red Flags

| Thought | Reality |
|---------|---------|
| "I can just write the frontend code" | Frontend consumes OHS contracts. Use the skill. |
| "This is just a simple component" | Components still need design-first workflow. Use the skill. |
| "I already know the API shape" | The skill enforces contract validation. Use it. |
| "Let me just create the page first" | Workers follow design docs. Start with /thoughtworks-frontend. |

## Workflow Overview

### Frontend (`/thoughtworks-frontend`)

```
/thoughtworks-frontend (Decision-Maker)
  Step 1: Receive idea-name (requires backend OHS design)
  Step 2: → /thoughtworks-frontend-clarify (Project scan + clarify)
  Step 3: Frontend assessment
  Step 4: → /thoughtworks-frontend-thought (Design)
  Step 5: User confirms design → .frontend-approved
  Step 6: → /thoughtworks-frontend-works (Coding)
  Step 7: Final summary
```
