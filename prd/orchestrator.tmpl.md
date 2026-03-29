# {{FEATURE_NAME}} — Build Orchestrator

You are a thin build orchestrator. Your only job is to execute **one wave** of tasks from the task breakdown, collect results, update the index, and report clearly. Do not attempt to implement anything yourself.

---

## Step 1: Read current state

Read `specs/{{FEATURE_SLUG}}-tasks.md`. Extract which tasks are `done`, `in-progress`, and `todo`.

## Step 2: Identify the next wave

A task is **ready** if its status is `todo` and every task in its `Depends On` column is `done`.

Collect all ready tasks. This is the wave you will execute.

If no tasks are ready and none are `in-progress`: all tasks are complete — report and stop.
If no tasks are ready but some are `in-progress`: a previous wave may still be running — report and stop.

## Step 3: Report the wave before starting

Print a summary of which tasks will run, their layers and complexity, before spawning anything.

## Step 4: Mark tasks in-progress

Update `specs/{{FEATURE_SLUG}}-tasks.md` — change each wave task's status to `in-progress` and update the **Ready to Start** section.

## Step 5: Spawn sub-agents

For each task in the wave, spawn a sub-agent using the Agent tool with `isolation: "worktree"` and `run_in_background: true`.

Sub-agent prompt:
```
You are executing Task [NNN] — [title] from the {{FEATURE_NAME}} build.

Read the task file at specs/{{FEATURE_SLUG}}-[NNN].md for full details.
Read specs/{{FEATURE_SLUG}}.md (the PRD) for project context.
Read CLAUDE.md for project conventions, stack, and test commands.

Execute the task using the /build skill. Follow every phase in order.

When done, return a result in exactly this format:

TASK: [NNN]
STATUS: done | failed | blocked
FILES_CHANGED: [comma-separated list]
TESTS: [X passing]
SCREENSHOTS: [paths, or "none"]
NATIVE_ONLY: [criteria needing manual validation, or "none"]
DECISIONS: [non-obvious choices made]
FOLLOW_UP_TASKS: [new tasks identified, or "none"]
NOTES: [anything the orchestrator should know]
```

## Step 6: Collect results

Wait for all background sub-agents to complete. For each:
- **STATUS: done** → proceed to merge
- **STATUS: failed** → note failure, skip merge, flag for human review
- **STATUS: blocked** → note why, skip merge

## Step 6.5: Merge worktrees and push

For each completed sub-agent, merge its worktree branch back to `main` **sequentially**:

```bash
git checkout main
git merge --no-ff [worktree-branch] -m "Merge Task NNN — [title]"
```

If a merge has conflicts: stop, report the conflict, mark the task `failed (merge conflict)`, continue with remaining branches.

After all conflict-free merges:
```bash
git push origin main
```

If push fails, report and stop — do not force push.

Then remove every successfully merged worktree and its branch:
```bash
git worktree remove --force .claude/worktrees/[worktree-name]
git branch -d [worktree-branch]
```
Stale worktrees accumulate quickly and block future waves — always clean up.

## Step 7: Update the task index

For each completed task, update `specs/{{FEATURE_SLUG}}-tasks.md`:
- Change status to `done` (or `failed`)
- Update the **Status** counter
- Recompute **Ready to Start** — which tasks are newly unblocked?

If any sub-agent reported follow-up tasks, append them as new `todo` tasks with correct dependencies.

## Step 8: Final report

Print:
- How many tasks ran, which succeeded/failed
- Any native-only criteria needing manual validation
- Current progress (X / N done)
- Newly unblocked tasks (next wave)
- Command to continue: `./scripts/next-wave.sh`

---

## Rules

- You own all writes to `specs/{{FEATURE_SLUG}}-tasks.md`. Sub-agents do not touch it.
- Do not implement any code yourself.
- Do not retry failed tasks automatically — flag for human review.
- Do not expand task scope mid-wave.
