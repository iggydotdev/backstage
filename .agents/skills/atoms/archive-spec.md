# Skill: Archive Spec

**Type:** Atom
**Used by:** Pipeline Orchestrator
**Trigger:** Step 10 of pipeline — after successful merge

---

## Purpose
Move a completed spec from `.specs/active/` to `.specs/done/`, update its
status, and check whether the parent feature and epic should also be
marked complete.

---

## Inputs
```json
{
  "specId": "SPEC-001",
  "specFile": ".specs/active/SPEC-001-login-form-component.md",
  "mergedAt": "ISO8601",
  "branchName": "feature/SPEC-001-login-form-component",
  "prUrl": "https://github.com/.../pull/42"
}
```

---

## Process

### Step 1 — Update spec file
Before moving, append a completion block to the spec file:

```markdown
---

## Completed

| Field | Value |
|---|---|
| Status | done |
| Merged | [mergedAt] |
| Branch | [branchName] |
| PR | [prUrl] |
```

Update the status field in the spec header from `active` to `done`.

### Step 2 — Move to done
```bash
mv .specs/active/SPEC-001-login-form-component.md \
   .specs/done/SPEC-001-login-form-component.md
```

### Step 3 — Check feature completion
Read the parent feature file (`.specs/features/FEAT-NNN-*.md`):
- Find the spec in its spec table
- Update the spec's status to `done`
- If ALL specs in the feature table are `done`:
  - Update the feature status to `complete`
  - Log: "FEAT-NNN marked complete"

### Step 4 — Check epic completion
Read the parent epic file (`.specs/epics/EPIC-NNN-*.md`):
- Find the feature in its feature table
- Update the feature's status to `complete` if applicable
- If ALL features in the epic table are `complete`:
  - Update the epic status to `complete`
  - Log: "EPIC-NNN marked complete — recommend architect review"

### Step 5 — Commit
```bash
git add .specs/
git commit -m "chore(pipeline): SPEC-001 archived — [feature/epic completion notes]"
git push origin develop
```

---

## Output
```json
{
  "archivedTo": ".specs/done/SPEC-001-login-form-component.md",
  "featureComplete": false,
  "epicComplete": false,
  "recommendArchitectReview": false
}
```

`recommendArchitectReview` is `true` when an epic completes or when the
cumulative count of completed specs reaches the review threshold (10).

---

## Rules
- Never archive a spec unless `ticket.status = "done"` in handoff.json
- Never delete specs — always move, never remove
- The completion block is append-only — never modify the original spec content
- If the parent feature or epic file cannot be found, log a warning but
  do not fail the archive — the spec move is the critical operation
