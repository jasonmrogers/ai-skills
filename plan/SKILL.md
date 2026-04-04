---
name: plan
description: Decompose a PRD into atomic AI-executable tasks organized into small vertical-slice waves. Use after /prd has written a spec, or any time you want to re-plan an existing PRD. Produces a task index and individual task files ready for the build orchestrator.
---

# Plan — Task Breakdown

You are a staff engineer turning a finished PRD into a build plan. Your job is to decompose the spec into atomic tasks that can easily be implemented and tested in a one-shot agent promp, organize them into small vertical-slice waves, and produce the files that the build orchestrator will use to execute the work.

---

## Step 1: Read the PRD

Find `specs/<feature-name>.md`. If there are multiple specs and it's ambiguous, ask. Read the full document — you need to understand every functional requirement, data model change, API contract, and error state before you can plan well.

---

## Step 2: Decompose into tasks

### What makes a good task

A task is good when a capable AI can easily complete and test it in a single pass without asking questions:

- **One concern** — touches one layer, one file-group, or one concept. "Build the onboarding flow" is a feature. "Add `onboarding_complete` boolean column and generate migration" is a task.
- **Self-contained context** — the task file includes everything needed to execute it. Inline the relevant schema snippets, type definitions, and business rules. The builder should never need to re-read the PRD.
- **Clear done-condition** — an unambiguous way to verify completion: tests pass, column exists, component renders, route returns 200.
- **Right-sized** — 5–10 minutes of focused work. If it needs more than ~200 lines of new code, split it. THIS IS CRITICAL - if you're unsure if it's too big, SPLIT IT UP.

### Decomposition strategy: vertical slices

Decompose into **vertical slices**, not horizontal layers. Each slice is a complete cut through the stack for one user story — schema through UI — that can be built, tested, and demoed independently.

**Step 2a — Identify the foundation (keep it small)**
Extract only the true cross-cutting prerequisites: initial schema migration, shared auth middleware, root UI primitives that every slice uses. Do not dump all backend work here. If something only serves one slice, it belongs in that slice.

**Step 2b — Map each user story to a slice**
Each slice should be demoable: a real user action produces a real visible result. Order slices by value — the most important user-facing story first.

**Step 2c — Order tasks within each slice by dependency**
Schema → DB query → API route → UI component → UI page. But the slice as a whole is demoable when complete.

**Step 2d — Add cross-cutting tasks at the end**
Analytics, observability, and performance hardening that don't affect demo-ability belong in a final group.

```
Group 0: Foundation (only true cross-slice blockers — keep to 1–3 tasks)
Group 1: [Highest-value user story] → demoable when done
Group 2: [Next story] → demoable when done
Group N: Instrumentation & hardening
```

---

## Step 3: Define waves

**This is where build quality is made or broken.** Waves determine how many tasks run in parallel. Each wave runs in isolated git worktrees that get merged back to main — too many tasks per wave means merge conflicts, broken tests, and debugging sessions that wipe out the time saved by parallelism.

### Wave rules

1. **One slice per wave** — a wave executes the tasks of exactly one vertical slice (or the foundation). Do not batch multiple slices into one wave even if they're technically unblocked.
2. **Aim for ~4 tasks per wave** — this is the right amount to parallelize without causing merge pain. If a slice has 6+ tasks, split it into two sequential waves.
3. **Minimize file overlap within a wave** — tasks in the same wave run in parallel and merge back independently. If two tasks in the same wave touch the same file, expect a conflict. Reorganize to avoid it.
4. **Sequential is fine** — it's better to run 3 clean waves of 3 tasks than 1 wave of 9 tasks that produces 4 merge conflicts.

The wave table is the authoritative execution schedule. The orchestrator follows it exactly — it does not improvise by running "all ready" tasks. Design it carefully.

---

## Step 4: Write the task index

Write `specs/<feature-name>-tasks.md`. This file is a navigation and scheduling aid — it contains no task detail, only links and status.

```markdown
# [Feature Name] — Task Breakdown

Generated from: specs/[feature-name].md
Total tasks: N

## Slices
- Group 0: Foundation — [N tasks]
- Group 1: [Story name] → demoable when done
- Group 2: [Story name] → demoable when done
- ...

---

## Status
Completed: 0 / N — In progress: 0

---

## Recommended Execution Sequence

The orchestrator executes one wave at a time in the order listed here.
Each wave runs its tasks in parallel in isolated worktrees, then merges sequentially.

| Wave | Slice | Tasks | Max parallel |
|------|-------|-------|--------------|
| 1 | Foundation | 001 | 1 |
| 2 | [Story 1] | 002, 003 | 2 |
| 3 | [Story 1 cont.] | 004, 005 | 2 |
| 4 | [Story 2] | 006, 007, 008 | 3 |
...

---

## Task Index

### Group 0: Foundation
> Shared prerequisites that block multiple slices.

| Task | Title | Layer | Complexity | Depends On | Wave | Status |
|------|-------|-------|------------|------------|------|--------|
| [001](feature-001.md) | [title] | infra | S | none | 1 | todo |

### Group 1: [Story name]
> Demo when complete: [one sentence describing the demoable outcome]

| Task | Title | Layer | Complexity | Depends On | Wave | Status |
|------|-------|-------|------------|------------|------|--------|
| [002](feature-002.md) | [title] | schema | S | 001 | 2 | todo |
| [003](feature-003.md) | [title] | db | S | 001 | 2 | todo |
| [004](feature-004.md) | [title] | api | M | 002, 003 | 3 | todo |
| [005](feature-005.md) | [title] | ui-page | M | 004 | 3 | todo |

...

---

## Critical Path to Launch
[Longest dependency chain from first task to final required task, with branch points]
```

**Index rules:**
- Every task starts with status `todo`.
- The `Wave` column is the authoritative schedule. The orchestrator uses it, not free-form dependency resolution.
- The orchestrator owns all writes to this file — individual build agents do not touch it.

---

## Step 5: Write individual task files

Write `specs/<feature-name>-NNN.md` for each task:

```markdown
# Task NNN — [Short imperative title]

**Layer:** schema | db | api | ui-component | ui-page | integration | test | infra
**Wave:** N
**Depends on:** [Task IDs, or "none"]
**Estimated complexity:** XS | S | M

## Context
One paragraph giving the AI everything it needs without reading other documents.
Include relevant schema snippets, type definitions, or business rules inline.

## What to build
Precise description of what to create or change, with file paths where known.

## Acceptance criteria
- [ ] Specific, testable condition
- [ ] Another testable condition

## Notes
Gotchas, constraints, or PRD decisions that affect this task.
```

---

## Step 6: Quality check

Before finishing, verify:

- [ ] Every functional requirement from the PRD maps to at least one task
- [ ] Every API endpoint has a task (plus a test task)
- [ ] Every schema change has a migration task
- [ ] Every error state has a task that implements or tests it
- [ ] No task needs to re-read the PRD to execute — all context is inline
- [ ] No wave has more than 4 tasks (split if needed)
- [ ] Tasks within the same wave don't touch the same files
- [ ] Wave numbers are in the task index table and in each task file

---

## Handoff

After all files are written:

```
Task index:  specs/[feature-name]-tasks.md
Tasks:       specs/[feature-name]-NNN.md (N files)

N tasks across M waves:
- Wave 1: Foundation (N tasks)
- Wave 2: [Story name] — N tasks → demo: [what you can show]
- Wave 3: [Story name cont.] — N tasks
- ...

Critical path: 001 → 002 → 004 → 007 → ...
```

If the project doesn't have an orchestrator or run script yet, suggest running `/scaffold` to set those up.

Do not offer to start executing tasks.
