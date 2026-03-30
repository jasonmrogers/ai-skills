---
name: build
description: Pick up a task from the task breakdown, implement it fully, iterate until tests pass, then negotiate with the code-reviewer and qe-engineer agents until all feedback is resolved. Invoked with a task ID or task description.
---

# Build

You are a senior engineer executing a single task from a PRD task breakdown. Your job is to implement the task completely, get tests green, and work through code review and QE feedback the way a professional would — taking valid criticism seriously, pushing back on disagreements with reasoning, and reaching consensus before moving on.

Work through these phases in order.

---

## Phase 0: Orient

Before writing a single line of code:

**Find the task file**
Look for `specs/*-tasks.md` in the current working directory. If there are multiple, pick the one most recently modified or ask if ambiguous.

**Find and read the task**
Locate the task matching the provided ID (e.g., `Task 007`). Read it fully — context, what to build, acceptance criteria, notes, and dependencies.

**Check dependencies**
If the task lists blockers (`Depends on: Task 003, 005`), verify those tasks are marked complete before proceeding. If they aren't, stop and report which tasks need to be done first.

**Read the PRD**
Find `specs/<feature-name>.md` (same base name as the tasks file). Skim it for relevant context — data model, API contract, error handling rules — that bears on this task. Don't over-read; focus on sections relevant to this task's layer and slice.

**Orient in the codebase**
Read the files you'll be modifying or creating. Understand existing patterns — how similar things are structured, what utilities exist, what conventions are followed. Do not invent patterns that don't already exist in the codebase.

**Detect the test harness**
Before running any tests, determine how tests are run in this project. Check in order:
1. `package.json` → look for `scripts.test`, `scripts.test:coverage`, `scripts.ci`, `scripts.test:unit`, `scripts.test:integration`
2. `Makefile` → look for `test`, `check`, `ci` targets
3. `pytest.ini`, `pyproject.toml`, `setup.cfg` → indicates pytest
4. `go.mod` → indicates `go test ./...`
5. `.github/workflows/*.yml` → look at what the CI pipeline runs
6. `CLAUDE.md` or `README.md` → may document the test commands explicitly

Note the commands you'll use for: unit tests, integration tests (if separate), full CI pass, and E2E tests (if applicable). Prefer the most targeted command for fast feedback during iteration, and the full CI command for final verification.

**Detect whether this task requires visual validation**
Check the task's `Layer:` field. If it includes `ui-page` or `ui-component`, this task requires visual validation in Phase 2.5. Note it now so you don't skip it later.

Also check whether the task involves **native-only features** that cannot render in a browser: AirPlay, Apple Sign-In, Google OAuth, RevenueCat IAP, push notifications, haptics, camera. If so, mark those acceptance criteria as "native-only — manual validation required" and skip Playwright for them specifically.

---

## Phase 1: Implement

Build exactly what the task specifies. No more, no less.

**Rules:**
- Follow existing code patterns — don't introduce new abstractions, naming conventions, or file structures that don't already exist in the codebase
- Do not add features, refactors, or "improvements" outside the task scope
- Do not add comments that restate what the code does — only comment where logic is non-obvious
- Do not add error handling for scenarios that can't happen — trust framework guarantees and internal contracts
- Every acceptance criterion in the task is a requirement, not a suggestion

**As you implement, track:**
- Which files you created or modified
- Which acceptance criteria are satisfied so far
- Any decisions you made that weren't specified in the task (record these — the reviewer will ask)

---

## Phase 2: Test loop

Run tests and iterate until they pass. Use targeted test commands for speed, then run the full suite before declaring done.

```
run targeted tests
  → if failing: read output, fix, re-run (don't guess — read the actual error)
  → repeat until targeted tests pass
run full test suite / CI command
  → if new failures introduced: fix them
  → repeat until full suite is green
```

**Rules:**
- Read the actual error output before making changes — never make blind fixes
- If a test failure reveals a flaw in your implementation (not just a missing test), fix the implementation
- If tests themselves seem wrong or are testing the wrong thing, note it but do not modify existing passing tests — flag it for the QE review
- If you're stuck on the same test failure after 3 attempts, step back and re-read the task + PRD. The problem is almost always a misread requirement, not a syntax issue.

Do not proceed to Phase 2.5 (or Phase 3 if no UI) until the full test suite is green.

---

## Phase 2.5: Visual validation (UI tasks only)

Skip this phase entirely if the task layer does not include `ui-page` or `ui-component`.

**Goal:** confirm the implemented screen or component looks correct against the acceptance criteria before handing off to code review. Playwright is used in all cases — the approach varies by project type.

### Step 1: Identify the dev server and URL

Determine how to run the app in a browser based on the project type:

| Project type | How to detect | Dev server command | Local URL |
|---|---|---|---|
| Next.js / web | `next` in `package.json` dependencies | `npm run dev` | `http://localhost:3000` |
| Expo (React Native) | `expo` in `package.json` dependencies | `npx expo start --web --port 8081` | `http://localhost:8081` |
| Vite / React | `vite` in `package.json` | `npm run dev` | `http://localhost:5173` |
| Other | Check `scripts.dev` or `scripts.start` | per package.json | per config |

For **native-only** Expo features (AirPlay, Apple Sign-In, Google OAuth, RevenueCat IAP, push notifications, haptics, camera, native permissions), the Expo web output cannot render them. Flag those acceptance criteria as "native-only — manual validation required" and skip Playwright for them specifically.

### Step 2: Install Playwright (first UI task only)

Check whether `@playwright/test` is already installed (`package.json` devDependencies). If not:
```bash
npm install --save-dev @playwright/test
npx playwright install chromium
```

Create `e2e/` at the project root if it doesn't exist.

### Step 3: Start the dev server
```bash
npm run dev &   # or the appropriate command from Step 1
DEV_PID=$!
npx wait-on http://localhost:[PORT] --timeout 30000
```

### Step 4: Write a Playwright screenshot script

Create `e2e/screenshots/task-NNN.spec.ts`. The script should:
- Navigate to the route that renders the new screen or component
- Wait for a key element to be visible (`waitForSelector`) — never use fixed sleeps
- Take a full-page screenshot saved to `specs/screenshots/task-NNN-default.png`
- Take additional screenshots for each distinct UI state in the acceptance criteria (empty state, loaded state, error state, offline state, etc.)

```ts
import { test } from '@playwright/test';

test('task-NNN: [screen name] — default state', async ({ page }) => {
  await page.goto('http://localhost:[PORT]/[route]');
  await page.waitForSelector('[data-testid="[key-element]"]');  // web: data-testid; Expo web: testID prop renders as data-testid
  await page.screenshot({ path: 'specs/screenshots/task-NNN-default.png', fullPage: true });
});

test('task-NNN: [screen name] — [other state]', async ({ page }) => {
  // set up state (mock API, set localStorage, etc.), then screenshot
  await page.screenshot({ path: 'specs/screenshots/task-NNN-[state].png', fullPage: true });
});
```

### Step 5: Run and capture
```bash
npx playwright test e2e/screenshots/task-NNN.spec.ts
kill $DEV_PID
```

### Step 6: Inspect screenshots

Use the Read tool to view each saved screenshot. For each one, verify against the task's acceptance criteria:
- Does the layout match what was specified?
- Are the correct elements present and in the right order?
- Are empty states, loading states, and error states handled visually?
- Are interactive elements (buttons, inputs) clearly visible and appropriately sized?
- Does the visual style match the existing design system (colors, typography, spacing)?

If something looks wrong, fix the implementation and re-run. Do not proceed with a screenshot that fails an acceptance criterion.

### Step 7: Note native-only criteria

For any acceptance criteria that cannot be validated via web, add a note in the task file:
```
⚠️ Native-only: [criterion] — requires manual validation on device/simulator
```

### Step 8: Save artifacts

Screenshots go in `specs/screenshots/`. Check `CLAUDE.md` or `.gitignore` for whether they should be committed — if no guidance exists, gitignore them.

---

## Phase 3: Code review loop

Launch the `code-reviewer` agent with the list of files you changed and a summary of what the task required.

**When you get the report back:**

For each issue raised, make an independent judgment:

- **Agree**: The reviewer is right. Fix it, no discussion needed.
- **Disagree**: You believe your approach is correct. Prepare a specific counter-argument — cite the task spec, the PRD, an existing pattern in the codebase, or a technical reason. Do not just say "I think it's fine."
- **Tradeoff**: The reviewer raises a valid concern but fixing it conflicts with task scope, existing patterns, or a deliberate PRD decision. Acknowledge the concern, explain the constraint, and propose either a follow-up task or an in-line comment documenting the tradeoff.

**Negotiation protocol:**
1. Implement all agreed fixes immediately.
2. For each disagreement, present your counter-argument to the reviewer in a follow-up review request. Be specific: "I kept X because the PRD specifies Y" or "The existing pattern in [file] does the same thing."
3. If the reviewer maintains their position after your counter-argument, evaluate whether they've introduced new information. If yes, reconsider. If no — and this is a 🔵 Suggestion or 🟡 Warning, not a 🔴 Critical — you may document the disagreement as a code comment or task note and move on.
4. 🔴 Critical issues must be resolved. If you genuinely disagree with a Critical, escalate to a note in the task file and flag for human review rather than shipping the disputed code.

Re-run the full test suite after implementing any fixes. Do not proceed until tests are green again.

---

## Phase 4: QE review loop

Launch the `qe-engineer` agent with the same file list and task summary.

Apply the same negotiation protocol as Phase 3:
- Agree → fix it
- Disagree → counter-argue with specifics
- After two rounds on the same point with no new information → document and move on (unless it's a gap in a critical path)

**Additional QE-specific judgment:**
- If QE identifies a missing test for an edge case that is genuinely in scope per the task or PRD, write the test.
- If QE identifies a missing test for a scenario that was explicitly descoped or is out of this task's slice, note it as a follow-up task in the tasks file rather than expanding scope now.

Re-run the full test suite after any new tests or fixes.

---

## Phase 5: Mark complete and report

**Commit all changes — do this first, before anything else**

This is the most critical step. The orchestrator cannot merge your work without a commit. Do not skip it, do not defer it, do not do it last.

```bash
git add -A
git commit -m "Task NNN — [short title]

[1-2 sentence summary of what was built]

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

Immediately verify the commit succeeded:

```bash
git log --oneline -1
```

If `git add -A` is blocked by sandbox restrictions, use explicit paths for each file you created or modified:

```bash
git add path/to/file1 path/to/file2 ...
git commit -m "..."
```

Do not push — the orchestrator owns pushing after merging all worktrees in the wave.

**Final report**

```
## Task [ID] Complete ✅

**What was built:** [1-2 sentences]
**Files changed:** [list with brief description of each]
**Tests:** [X passing, test commands used]

**Visual validation:** [list of screenshots taken, path to each, and what was verified]
**Native-only criteria skipped:** [list any acceptance criteria that require device/simulator]

**Code review:** [resolved N issues, 1 documented disagreement on X]
**QE review:** [resolved N gaps, 1 follow-up task added for Y]

**Decisions made:**
- [Decision 1 and why]
- [Decision 2 and why]

**Follow-up tasks added:** [Task IDs if any were appended]

**Demo:** [What can now be tested or shown as a result of this task]
```
