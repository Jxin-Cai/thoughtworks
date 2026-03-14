---
name: using-thoughtworks-backend
description: Use when starting any conversation - establishes how to find and use thoughtworks DDD backend skills, requiring Skill tool invocation before ANY DDD-related response
---

<EXTREMELY-IMPORTANT>
If the user's request involves DDD, domain modeling, layered architecture design, or Java code generation for a DDD project, you ABSOLUTELY MUST invoke the relevant thoughtworks backend skill.

IF A THOUGHTWORKS SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.

**HOW to invoke: Use the `Skill` tool.** Do NOT try to follow the workflow steps manually. Do NOT explore the codebase, read requirement files, or write any code before invoking the skill. The skill contains all the logic — your only job is to invoke it.
</EXTREMELY-IMPORTANT>

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you — follow it directly. Never use the Read tool on skill files.

## Available Skills

### Backend (DDD)

| Skill | Trigger | Description |
|-------|---------|-------------|
| `thoughtworks-skills-backend` | User wants backend DDD feature | Main entry: requirements → design → implementation |
| `thoughtworks-skills-backend-clarify` | User wants to clarify backend requirements | Project context scan + structured requirement clarification |
| `thoughtworks-skills-backend-thought` | User wants backend design only | Orchestrates thinker subagents for layered design docs |
| `thoughtworks-skills-backend-works` | User wants to code from backend design | Orchestrates worker subagents for Java implementation |
| `thoughtworks-skills-java-spec` | Need Java DDD coding spec | Routes to layer-specific coding constraints |
| `thoughtworks-skills-merge` | Merge feature branch back to main | Squash merges feature/<idea-name> to main/master, called by orchestrator |

## Slash Commands

| Command | Maps to |
|---------|---------|
| `/thoughtworks-skills-backend` | Backend DDD workflow |
| `/thoughtworks-skills-backend-clarify` | Backend requirements clarification |
| `/thoughtworks-skills-backend-thought` | Backend design phase only |
| `/thoughtworks-skills-backend-works` | Backend coding phase only |
| `/thoughtworks-skills-merge` | Feature branch squash merge back to main |

## Trigger Rules

| User Intent | Skill to Invoke |
|-------------|----------------|
| DDD, domain modeling, layered architecture, Java backend | `/thoughtworks-skills-backend` |
| Clarify or refine backend requirements | `/thoughtworks-skills-backend-clarify` |
| Design backend layers only | `/thoughtworks-skills-backend-thought` |
| Code from existing backend design | `/thoughtworks-skills-backend-works` |

## The Rule

**Invoke relevant skills BEFORE any response or action.** When the user mentions DDD, domain modeling, layered architecture, or Java backend code generation, invoke the appropriate skill first.

```
User message received
  → Is this DDD backend-related? → /thoughtworks-skills-backend
  → None of the above → Respond normally
```

## Red Flags

| Thought | Reality |
|---------|---------|
| "I can just write the code directly" | DDD code needs design-first. Use the skill. |
| "This is a simple domain model" | Simple models still need contract validation. Use the skill. |
| "I already know DDD patterns" | The skill enforces specific contract-driven workflows. Use it. |
| "Let me just create the entity first" | Workers follow design docs. Start with /thoughtworks-skills-backend. |
| "Let me explore the codebase first" | The skill's clarify step does project scanning. Invoke the skill first. |
| "I understand the workflow, I can follow the steps myself" | Understanding the flow does NOT replace invoking the Skill tool. The skill enforces HARD-GATEs, contract validation, and state management that you cannot replicate manually. INVOKE THE SKILL. |
| "I'll just read the requirement file and start coding" | Requirements need clarification with the user first. Invoke the skill. |

## Workflow Overview

This is a **high-level summary for reference only**. Do NOT use it as execution instructions. Always invoke the skill via the `Skill` tool.

### Backend

Invoke: `Skill(skill: "thoughtworks-skills-backend", args: "<requirement>")`

Handles: requirement clarification → branch → layer assessment → phase loop (design → confirm → coding) → merge → engineering tasks → summary
