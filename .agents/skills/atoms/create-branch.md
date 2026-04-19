# Skill: Create Branch

**Type:** Atom
**Used by:** Pipeline Orchestrator
**Trigger:** Step 3 of pipeline — before handoff.json is built

---

## Purpose
Create a correctly named gitflow feature branch from `develop` for the
current spec. Ensures consistent branch naming across all pipeline runs.

---

## Inputs
```json
{
  "specId": "SPEC-001",
  "specTitle": "Login form component",
  "base": "develop"
}
```

---

## Process

### Step 1 — Derive branch name
Slugify the spec title:
- Lowercase
- Replace spaces and special characters with hyphens
- Remove consecutive hyphens
- Truncate slug to 40 characters maximum

```
"Login form component" → "login-form-component"
Branch name → "feature/SPEC-001-login-form-component"
```

### Step 2 — Check if branch already exists
```bash
git fetch origin
git branch -a | grep "feature/SPEC-001-login-form-component"
```

If the branch already exists locally or on remote:
- Return the existing branch name
- Set `alreadyExisted: true` in output
- Do NOT reset or force-push — the pipeline orchestrator will decide how to handle it

If the branch does not exist:
```bash
git checkout develop
git pull origin develop
git checkout -b feature/SPEC-001-login-form-component
git push -u origin feature/SPEC-001-login-form-component
```

### Step 3 — Verify
Confirm the branch is checked out and tracking the remote:
```bash
git status
git branch -vv
```

---

## Output
```json
{
  "branchName": "feature/SPEC-001-login-form-component",
  "base": "develop",
  "alreadyExisted": false,
  "remote": "origin/feature/SPEC-001-login-form-component"
}
```

---

## Rules
- Always branch from `develop`, never from `main` or another feature branch
- Never force-push
- If `develop` is behind `origin/develop`, pull before branching
- Branch name must always start with `feature/SPEC-`
