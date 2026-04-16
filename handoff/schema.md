# Handoff Schema

Every agent reads from and writes to a shared work item object.
This is the contract between all agents in the pipeline.
It is stored as `handoff.json` in the root of the feature branch.

---

## Schema

```json
{
  "schemaVersion": "1.0.0",

  "ticket": {
    "id": "TICKET-123",
    "title": "Short description of the ticket",
    "url": "https://<atlassian-or-ado-url>/ticket/TICKET-123",
    "status": "in_progress | pr_draft | pr_ready | qa | done | blocked"
  },

  "requirements": {
    "brs": [
      "Business requirement 1",
      "Business requirement 2"
    ],
    "acs": [
      "Acceptance criteria 1",
      "Acceptance criteria 2"
    ]
  },

  "design": {
    "figmaNodes": [
      {
        "url": "https://figma.com/file/...",
        "nodeId": "123:456",
        "componentName": "ButtonPrimary",
        "tokens": {},
        "variants": [],
        "spec": ""
      }
    ]
  },

  "branch": {
    "name": "feature/TICKET-123-short-description",
    "base": "develop",
    "prUrl": null
  },

  "tdd": {
    "phase": "red | green | blue | complete",
    "loop": {
      "iteration": 0,
      "maxIterations": 3
    },
    "testResults": {
      "total": 0,
      "passed": 0,
      "failed": 0,
      "skipped": 0,
      "coverage": null,
      "output": ""
    },
    "acCoverage": {
      "total": 0,
      "covered": 0,
      "uncovered": []
    }
  },

  "defects": [],

  "humanReview": {
    "status": "pending | changes_requested | approved",
    "comments": []
  },

  "context": {
    "version": "1.0.0",
    "resolvedStack": "[STACK]",
    "agentNotes": ""
  },

  "audit": [
    {
      "timestamp": "ISO8601",
      "agent": "developer-orchestrator | red | green | blue | qa",
      "action": "description of what was done",
      "result": "success | failure | escalated",
      "iteraton": 0
    }
  ]
}
```

---

## Rules

- **No agent overwrites another agent's fields** outside its own scope.
- **`audit` is append-only.** Every agent appends an entry on every action.
- **`tdd.loop.iteration`** is incremented by the developer orchestrator, not sub-agents.
- **`ticket.status`** is only updated by the orchestrator.
- If `tdd.loop.iteration` reaches `tdd.loop.maxIterations`, the orchestrator escalates — it does not start another loop.
- `handoff.json` is committed to the feature branch on every meaningful state change.