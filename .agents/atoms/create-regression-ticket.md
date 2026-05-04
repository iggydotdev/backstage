# Skill: Create Regression Ticket

**Type:** Atom  
**Used by:** QA Orchestrator  
**Trigger:** A defect with `origin: "pre_existing"` is found during QA

---

## Purpose
Create a well-structured regression ticket in [TICKET_SYSTEM] for a defect
found in code that was not part of the current ticket's scope.

This skill does not fix anything. It documents and creates. That is its only job.

---

## Inputs
A single defect object from `handoff.json > defects`:

```json
{
  "id": "DEF-002",
  "title": "Dropdown loses focus on keyboard navigation",
  "severity": "medium",
  "type": "regression",
  "description": "When navigating the dropdown with arrow keys, focus is lost after the third item. Reproducible on all pages where DropdownMenu is used.",
  "affectedFiles": ["src/components/DropdownMenu.tsx"],
  "relatedAC": null,
  "origin": "pre_existing",
  "action": "create_regression_ticket"
}
```

And the source ticket context:
```json
{
  "sourceTicketId": "TICKET-123",
  "sourceTicketUrl": "https://...",
  "detectedInBranch": "feature/TICKET-123-button-component",
  "detectedByAgent": "qa",
  "detectedAt": "ISO8601"
}
```

---

## Ticket structure to create

**Title:**  
`[REGRESSION] <defect title>`  
e.g. `[REGRESSION] Dropdown loses focus on keyboard navigation`

**Type:** Bug

**Priority:** Map from severity:
| Defect severity | Ticket priority |
|---|---|
| critical | P1 — Blocker |
| high | P2 — High |
| medium | P3 — Medium |
| low | P4 — Low |

**Description (use this template):**

```
## Summary
<defect.description>

## How it was detected
Found during QA of [TICKET-123](<sourceTicketUrl>) on branch `<detectedInBranch>`.
This defect exists in code that predates the current ticket.

## Affected files
<affectedFiles — one per line>

## Steps to reproduce
[QA agent should populate this from the test output or e2e failure if available]

## Expected behaviour
[Derive from the failing test assertion or general UX expectation]

## Actual behaviour
[What was observed]

## Acceptance criteria
- [ ] The defect described above is no longer reproducible
- [ ] Existing tests pass
- [ ] A regression test is added to prevent recurrence

## Notes
Detected by QA Agent on <detectedAt>.
Source branch: `<detectedInBranch>`.
```

**Labels/Tags:** `regression`, `agent-detected`, severity label

---

## Process

1. Construct the ticket payload from the defect object and source context
2. Create the ticket via [TICKET_SYSTEM] MCP
3. Return the new ticket ID and URL
4. The QA Orchestrator stores these in `handoff.json > context.agentNotes`

---

## Output

```json
{
  "regressionTicketId": "TICKET-456",
  "regressionTicketUrl": "https://...",
  "linkedToSourceTicket": "TICKET-123"
}
```

---

## Rules
- Never assign the regression ticket to a specific person — leave unassigned
- Never block the current ticket because of a pre-existing regression
- Always link the regression ticket back to the source ticket that discovered it
- If ticket creation fails (MCP unavailable), log the full defect to `handoff.json > context.agentNotes` and post it as a PR comment so it is not lost
