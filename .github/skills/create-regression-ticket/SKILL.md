---
name: create-regression-ticket
description: >
  Create a structured regression ticket for a pre-existing defect found during QA.
  Use when a defect has origin "pre_existing" in handoff.json. Non-blocking — does
  not stop the current ticket. Links the regression ticket back to the source ticket.
---

# Create Regression Ticket

Create a regression ticket for a pre-existing defect discovered during QA.

## Input needed
A single defect object from `handoff.json > defects` where `origin == "pre_existing"`.

Also need:
- `sourceTicketId` — current ticket ID (e.g. "TICKET-123")
- `sourceTicketUrl` — URL of the current PR or ticket
- `detectedInBranch` — e.g. "feature/SPEC-001-login-form-component"

## Ticket structure to create

**Title:** `[REGRESSION] <defect.title>`

**Type:** Bug

**Priority:** Map from severity:
- `critical` → P1 Blocker
- `high` → P2 High
- `medium` → P3 Medium
- `low` → P4 Low

**Description template:**
```
## Summary
[defect.description]

## How it was detected
Found during QA of [sourceTicketId]([sourceTicketUrl]) on branch `[detectedInBranch]`.
This defect exists in code that predates the current ticket.

## Affected files
[defect.affectedFiles — one per line]

## Steps to reproduce
[Populate from test output or e2e failure if available]

## Expected behaviour
[Derive from failing test assertion or general UX expectation]

## Actual behaviour
[What was observed]

## Acceptance criteria
- [ ] The defect described above is no longer reproducible
- [ ] Existing tests pass
- [ ] A regression test is added to prevent recurrence

## Notes
Detected by QA Agent. Source branch: `[detectedInBranch]`.
```

**Labels:** `regression`, `agent-detected`, severity label

## After creating the ticket
Write to `handoff.json > context.agentNotes`:
`[QA → HUMAN]: regression ticket [TICKET-NNN] created — [defect.title]`

Update `defects[N].status` to `"ticket_created"`.

## Rules
- Never assign the regression ticket to a specific person — leave unassigned
- Never block the current ticket because of a pre-existing regression
- Always link back to the source ticket
- If ticket creation fails (system unavailable) → log the full defect to agentNotes AND post as PR comment so it is not lost
