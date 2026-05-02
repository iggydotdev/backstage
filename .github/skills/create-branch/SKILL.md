---
name: create-branch
description: >
  Create a correctly named gitflow feature branch from develop for the current spec.
  Use this at pipeline Step 3, before handoff.json is built. Ensures consistent branch
  naming across all pipeline runs. Returns branch name and whether it already existed.
---

# Create Branch

Create a feature branch from `develop` for the current spec.

## Inputs needed
- `specId` — e.g. "SPEC-001"
- `specTitle` — e.g. "Login form component"

## Step 1 — Derive branch name
Slugify the spec title:
- Lowercase
- Replace spaces and special characters with hyphens
- Remove consecutive hyphens
- Truncate slug to 40 characters

```
"Login form component" → "login-form-component"
Branch name → "feature/SPEC-001-login-form-component"
```

## Step 2 — Check if branch already exists
```bash
git fetch origin
git branch -a | grep "feature/SPEC-001-login-form-component"
```

If branch EXISTS:
- Return the branch name with `alreadyExisted: true`
- Do NOT reset or force-push
- Check if `handoff.json` exists on that branch — if yes, pipeline orchestrator resumes from current state

If branch does NOT exist:
```bash
git checkout develop
git pull origin develop
git checkout -b feature/SPEC-001-login-form-component
git push -u origin feature/SPEC-001-login-form-component
```

## Step 3 — Verify
```bash
git status
git branch -vv
```
Confirm branch is checked out and tracking the remote.

## Output
Report:
- Branch name created/found
- Whether it already existed
- Remote tracking confirmed

## Rules
- Always branch from `develop` — never from `main` or another feature branch
- Never force-push
- Pull `develop` before branching to ensure it is up to date
- Branch name must always start with `feature/SPEC-`
