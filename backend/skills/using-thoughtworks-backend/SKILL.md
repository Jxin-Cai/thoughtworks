---
name: using-thoughtworks-backend
description: Use when starting any conversation - establishes how to find and use thoughtworks DDD backend skills, requiring Skill tool invocation before ANY DDD-related response
---

<EXTREMELY-IMPORTANT>
If the user's request involves DDD, domain modeling, layered architecture design, or Java code generation for a DDD project, you ABSOLUTELY MUST invoke the relevant thoughtworks backend skill.

IF A THOUGHTWORKS SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you — follow it directly. Never use the Read tool on skill files.

## Available Skills

### Backend (DDD)

| Skill | Trigger | Description |
|-------|---------|-------------|
| `thoughtworks-skills-ddd` | User wants backend DDD feature | Main entry: requirements → design → implementation |
| `thoughtworks-skills-ddd-clarify` | User wants to clarify backend requirements | Project context scan + structured requirement clarification |
| `thoughtworks-skills-ddd-thought` | User wants backend design only | Orchestrates thinker subagents for layered design docs |
| `thoughtworks-skills-ddd-works` | User wants to code from backend design | Orchestrates worker subagents for Java implementation |
| `thoughtworks-skills-java-spec` | Need Java DDD coding spec | Routes to layer-specific coding constraints |

## Slash Commands

| Command | Maps to |
|---------|---------|
| `/thoughtworks-backend` | Backend DDD workflow |
| `/thoughtworks-backend-clarify` | Backend requirements clarification |
| `/thoughtworks-backend-thought` | Backend design phase only |
| `/thoughtworks-backend-works` | Backend coding phase only |

## Trigger Rules

| User Intent | Skill to Invoke |
|-------------|----------------|
| DDD, domain modeling, layered architecture, Java backend | `/thoughtworks-backend` |
| Clarify or refine backend requirements | `/thoughtworks-backend-clarify` |
| Design backend layers only | `/thoughtworks-backend-thought` |
| Code from existing backend design | `/thoughtworks-backend-works` |

## The Rule

**Invoke relevant skills BEFORE any response or action.** When the user mentions DDD, domain modeling, layered architecture, or Java backend code generation, invoke the appropriate skill first.

```
User message received
  → Is this DDD backend-related? → /thoughtworks-backend
  → None of the above → Respond normally
```

## Red Flags

| Thought | Reality |
|---------|---------|
| "I can just write the code directly" | DDD code needs design-first. Use the skill. |
| "This is a simple domain model" | Simple models still need contract validation. Use the skill. |
| "I already know DDD patterns" | The skill enforces specific contract-driven workflows. Use it. |
| "Let me just create the entity first" | Workers follow design docs. Start with /thoughtworks-backend. |

## Workflow Overview

### Backend (`/thoughtworks-backend`)

```
/thoughtworks-backend (Decision-Maker)
  Step 1: Receive requirement
  Step 2: → /thoughtworks-backend-clarify (Project scan + clarify)
  Step 3: Layer assessment → assessment.md
  Step 4: → /thoughtworks-backend-thought (Design)
  Step 5: User confirms design → .approved
  Step 6: → /thoughtworks-backend-works (Coding)
  Step 7: Final summary
```
