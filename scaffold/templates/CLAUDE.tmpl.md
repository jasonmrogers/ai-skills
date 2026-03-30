# {{FEATURE_NAME}} — Agent Guide

## What this project is

{{ONE_PARAGRAPH_SUMMARY}}

Full spec: `specs/{{FEATURE_SLUG}}.md`

---

## Repository structure

```
{{REPO_STRUCTURE}}
```

---

## How to run

{{RUN_COMMANDS}}

---

## How to test

```bash
{{TEST_COMMANDS}}
```

---

## Environment variables

{{ENV_VARS_BY_COMPONENT}}

---

## Key conventions

{{KEY_CONVENTIONS}}

---

## Build system

```bash
# Run the next wave of tasks (review output before continuing)
./scripts/next-wave.sh

# Run all waves unattended until complete or failure
./scripts/next-wave.sh --loop
```

See `specs/{{FEATURE_SLUG}}-tasks.md` for current task status and what's ready to run.
