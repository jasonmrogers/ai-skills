---
name: scaffold
description: Set up the build infrastructure for a new project — orchestrator, run script, CLAUDE.md, and project-level agent definitions. Run once when starting a new project. Skips files that already exist. Use this after /plan has produced a task breakdown.
---

# Scaffold — Project Build Infrastructure

You are setting up the build infrastructure for a project. Your job is to generate the files that make the build system work: the orchestrator prompt, the run script, the agent guide, and the project-level agent definitions.

**Check what already exists before writing anything.** Skip files that are already in place — this skill is safe to re-run on existing projects, and will only fill gaps.

Work through these steps in order.

---

## Step 1: Gather project context

Before generating any files, collect:

1. **Feature name** (human-readable, e.g. "SuperStretchy")
2. **Feature slug** (kebab-case, e.g. "superstretchy") — matches the `specs/<slug>.md` filename
3. **Repo structure** — run `find . -maxdepth 3 -type d | head -60` to see what exists
4. **Run commands** — how to start dev servers (check `package.json`, `Makefile`, `README`)
5. **Test commands** — unit, integration, E2E (check `package.json` scripts, CI config)
6. **Env vars** — scan `.env.example`, `.env.local.example`, or ask the user
7. **Key conventions** — read any existing `CLAUDE.md` or `README` for project-specific rules

If you don't have enough context to fill these out accurately, ask the user before writing. A wrong CLAUDE.md is worse than no CLAUDE.md.

---

## Step 2: Generate CLAUDE.md (skip if exists)

Check for `CLAUDE.md` at the project root. If it exists, skip this step.

If it doesn't exist, create it using the template at `templates/CLAUDE.tmpl.md`. Fill in every `{{PLACEHOLDER}}`:

- `{{FEATURE_NAME}}` → human-readable project name
- `{{FEATURE_SLUG}}` → kebab-case slug
- `{{ONE_PARAGRAPH_SUMMARY}}` → what the project is, from the PRD Overview
- `{{REPO_STRUCTURE}}` → actual directory layout
- `{{RUN_COMMANDS}}` → how to start dev servers, per component
- `{{TEST_COMMANDS}}` → unit, integration, and E2E commands
- `{{ENV_VARS_BY_COMPONENT}}` → env vars grouped by component, values blank
- `{{KEY_CONVENTIONS}}` → 4–8 non-obvious rules agents must follow (auth patterns, error handling, premium gating, data ownership, etc.)

---

## Step 3: Generate specs/orchestrator.md (skip if exists)

Check for `specs/orchestrator.md`. If it exists, skip this step.

If it doesn't exist, create `specs/` if needed, then create `specs/orchestrator.md` using `templates/orchestrator.tmpl.md`. Substitute:
- `{{FEATURE_NAME}}` → project name
- `{{FEATURE_SLUG}}` → kebab-case slug

---

## Step 4: Generate scripts/next-wave.sh (skip if exists)

Check for `scripts/next-wave.sh`. If it exists, skip this step.

If it doesn't exist, create `scripts/` if needed, then copy `templates/next-wave.tmpl.sh` verbatim to `scripts/next-wave.sh`. Make it executable:

```bash
chmod +x scripts/next-wave.sh
```

---

## Step 5: Create .claude/agents/ definitions (skip individual files that exist)

Check for `.claude/agents/code-reviewer.md` and `.claude/agents/qe-engineer.md`.

Create `.claude/` and `.claude/agents/` directories if they don't exist. For each agent file that doesn't exist, create it using the templates below.

These agent definitions are project-portable — they live in the repo, get committed to git, and work in any environment that clones the project. They reference `CLAUDE.md` for project-specific context rather than hardcoding it.

### .claude/agents/code-reviewer.md

Copy the contents of `agents/code-reviewer.md` (in this skill's directory) verbatim.

### .claude/agents/qe-engineer.md

Copy the contents of `agents/qe-engineer.md` (in this skill's directory) verbatim.

---

## Step 6: Report what was created

```
Scaffold complete:

✅ Created   CLAUDE.md
✅ Created   specs/orchestrator.md
✅ Created   scripts/next-wave.sh
✅ Created   .claude/agents/code-reviewer.md
✅ Created   .claude/agents/qe-engineer.md
⏭️  Skipped  [file] — already exists

These agent definitions are committed with the project and work in any environment.
Run `./scripts/next-wave.sh` to start the first build wave.
```
