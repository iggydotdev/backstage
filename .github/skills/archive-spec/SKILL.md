---
name: archive-spec
description: >
  Move a completed spec from .specs/active/ to .specs/done/ after a successful merge.
  Updates the spec status, checks whether the parent feature and epic should be marked
  complete, and triggers eval-pipeline if thresholds are met.
  Only run when ticket.status is "done" in handoff.json.
---

# Archive Spec

Move a completed spec to done/ and check parent feature/epic completion.

## Pre-check
Read `handoff.json`. Verify `ticket.status == "done"`. If not → HALT, do not archive.

## Inputs needed
- `specId` — e.g. "SPEC-001"
- `specFile` — e.g. `.specs/active/SPEC-001-login-form-component.md`
- `mergedAt` — ISO8601 timestamp
- `branchName` — e.g. `feature/SPEC-001-login-form-component`
- `prUrl` — GitHub PR URL

## Step 1 — Update spec file (before moving)
Append completion block to the spec file:

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

Update the `Status:` field in the spec header from `active` to `done`.

## Step 2 — Move to done
```bash
mv .specs/active/SPEC-001-login-form-component.md \
   .specs/done/SPEC-001-login-form-component.md
```

## Step 3 — Check feature completion
Read the parent feature file (`.specs/features/FEAT-NNN-*.md`):
- Update this spec's status to `done` in the feature's spec table
- If ALL specs in the feature table are `done` → update feature status to `complete`

## Step 4 — Check epic completion
Read the parent epic file (`.specs/epics/EPIC-NNN-*.md`):
- Update the feature's status in the epic's feature table
- If ALL features are `complete` → update epic status to `complete`

## Step 5 — Commit
```bash
git add .specs/
git commit -m "chore(pipeline): SPEC-001 archived to done"
git push origin develop
```

## Step 6 — Trigger eval if threshold met
```bash
DONE_COUNT=$(ls .specs/done/ | grep -c "SPEC-")
# Trigger eval if: every 10th spec, or epic just completed
```

If threshold met → run `/eval-pipeline` skill.

## Output
Report: archived path, feature complete (yes/no), epic complete (yes/no), eval triggered (yes/no).

## Rules
- Never archive unless `ticket.status == "done"`
- Never delete specs — always move, never remove
- The completion block is append-only — do not modify original spec content
- If parent feature/epic file cannot be found → log warning but do not fail the archive
