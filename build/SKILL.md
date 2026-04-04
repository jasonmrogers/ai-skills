---
name: build
description: Implement a single task from a PRD task breakdown — orient, implement, get tests green, validate visually (Playwright + Maestro), commit, and report. The orchestrator owns code review and QE after the commit. Invoked with a task ID or task description.
---

# Build

You are a senior engineer executing a single task from a PRD task breakdown. Your job is to implement the task completely, get tests green, validate visually, and commit clean work. Code review and QE are handled by the orchestrator after your commit — your job ends at Phase 4.

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

Also check whether the task involves features that can't render in a standard web browser (native device APIs, platform-specific SDKs, hardware sensors, etc.). These need a different testing tier — simulator/emulator or structured manual testing — not a skip. The QE engineer in Phase 4 owns writing those tests.

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

Do not proceed to Phase 3 (or Phase 4 if no UI) until the full test suite is green.

**→ Phase 2 is complete when: the full test suite is green. Immediately proceed to Phase 3 (if UI task) or Phase 4 (if not).**

---

## Phase 3: Visual validation (UI tasks only)

Skip this phase entirely if the task layer does not include `ui-page` or `ui-component`.

**Goal:** confirm the implemented screen or component looks correct and behaves correctly against the acceptance criteria before handing off to code review. Use Playwright for anything that can run in a browser. Features that require a native runtime or hardware get covered by the QE engineer — they are not skipped.

### Step 1: Identify the dev server and URL

Check `CLAUDE.md` for the dev server command and port. Common patterns:

| Project type | How to detect | Dev server command | Local URL |
|---|---|---|---|
| Next.js / web | `next` in `package.json` | `npm run dev` | `http://localhost:3000` |
| Expo (React Native) | `expo` in `package.json` | `npx expo start --web --port 8081` | `http://localhost:8081` |
| Vite / React | `vite` in `package.json` | `npm run dev` | `http://localhost:5173` |
| Other | Check `scripts.dev` or `scripts.start` | per package.json | per config |

If the task's UI cannot render in a browser at all (e.g., it is entirely hardware-dependent), skip Phase 2.5 and note it — but Phase 4 QE must still cover it.

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

### Step 4: Write Playwright interaction tests

Create `e2e/task-NNN.spec.ts`. These tests must exercise real user behavior — not just load a page and screenshot it. Each test should navigate, interact, and assert on outcomes.

```ts
import { test, expect } from '@playwright/test';

test('task-NNN: [flow description] — happy path', async ({ page }) => {
  await page.goto('http://localhost:[PORT]/[route]');
  await page.waitForSelector('[data-testid="[key-element]"]');

  // Interact with the UI
  await page.tap('[data-testid="some-button"]');
  await page.fill('[data-testid="some-input"]', 'test value');
  await page.tap('[data-testid="submit-button"]');

  // Assert on the outcome
  await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
  await expect(page).toHaveURL(/expected-route/);
});

test('task-NNN: [flow description] — error state', async ({ page }) => {
  await page.goto('http://localhost:[PORT]/[route]');
  await page.waitForSelector('[data-testid="[key-element]"]');

  // Trigger the error condition
  await page.tap('[data-testid="submit-button"]');  // submit without filling required fields

  // Assert the error is shown
  await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
});
```

**What to test:**
- The primary happy path: user completes the flow successfully
- Navigation: tapping tabs, back buttons, and links actually changes the route
- Key error states from the task's acceptance criteria
- Any distinct UI states (empty, loaded, error) that are in scope

**Expo/React Native note:** `testID` props render as `data-testid` in the browser. Use those selectors. Use `page.tap()` for touch targets.

**Screenshots as secondary artifacts:** After each meaningful assertion, optionally take a screenshot for debugging — but the test must pass or fail based on assertions, not screenshots.

```ts
await page.screenshot({ path: 'specs/screenshots/task-NNN-[state].png', fullPage: true });
```

### Step 5: Run and verify

```bash
npx playwright test e2e/task-NNN.spec.ts
kill $DEV_PID
```

If a test fails because an element isn't interactive (click does nothing, navigation doesn't happen), fix the implementation — that is a real bug.

### Step 6: Run Maestro simulator flows (iOS projects only)

**Determine if this step applies:** Check `package.json` for `"expo"` or `"react-native"` as a dependency, or look for an `app.config.ts` / `app.json` in the project root. If neither is present, skip this step entirely — Maestro is only for iOS/React Native projects, not web or backend projects.

For iOS / React Native / Expo projects, **every acceptance criterion must be validated** — either via Playwright (web) or Maestro (iOS simulator). "It only works on native" is never an acceptable outcome. Write and run Maestro flows for anything Playwright cannot cover.

**Check if Maestro is set up:**
```bash
maestro --version
ls .maestro/
```

If Maestro is not installed or `.maestro/` does not exist, set STATUS to `blocked` and report what's missing — do not proceed.

**Write a Maestro flow for this task:**

Create `.maestro/task-NNN.yaml`. All flows that require an authenticated user must start with the shared login flow:
```yaml
appId: com.your.app
---
- runFlow: .maestro/flows/_login.yaml   # if auth is required
- [your task-specific steps]
```

Each flow must cover every acceptance criterion from the task file that Playwright did not already cover. Assert on visible elements, navigation outcomes, and state changes — not just that the screen renders.

**Run the flow:**
```bash
maestro test .maestro/task-NNN.yaml
```

If a flow fails because an element is missing or a tap does nothing, fix the implementation — that is a real bug.

### Step 7: Save artifacts

E2E specs go in `e2e/`. Screenshots go in `specs/screenshots/`. Check `CLAUDE.md` or `.gitignore` for commit guidance — if none exists, gitignore screenshots but commit the spec files.

---

## Phase 4: Mark complete and report

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

**Playwright tests:** [list of interaction tests written, what each verifies]
**Maestro flows:** [flow files written and run, what each verifies — or "n/a: not an iOS project"]

**Decisions made:**
- [Decision 1 and why]
- [Decision 2 and why]

**Follow-up tasks identified:** [any noted during implementation, or "none"]

**Demo:** [What can now be tested or shown as a result of this task]
```
