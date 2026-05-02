# Handoff Schema

Every agent reads from and writes to a shared work item object.
This is the contract between all agents in the pipeline.
It is stored as `handoff.json` in the root of each feature branch.

Schema version: `1.4.0`

---

## Changelog
- `1.4.0` — Added `agentNotesArchive` field. Formalised agentNotes tagging convention (see skills/agent-notes-convention.md).
- `1.3.0` — Added `dod` field for storing last Definition of Done check result.
- `1.2.0` — Added `contextSlice` field. Pipeline orchestrator prepares
  a role-scoped context slice before each agent invocation.
- `1.1.0` — Added `qaRuns`, expanded `defects` schema, added field
  ownership table.
- `1.0.0` — Initial schema.

---

## Schema

```json
{
  "schemaVersion": "1.4.0",

  "ticket": {
    "id": "SPEC-001",
    "title": "Short description of the spec",
    "url": ".specs/active/SPEC-001-slug.md",
    "status": "in_progress | pr_draft | pr_ready | qa | done | blocked"
  },

  "requirements": {
    "brs": [
      "BR-1: Business requirement in business language",
      "BR-2: Business requirement in business language"
    ],
    "acs": [
      "AC-1: Given [context], when [action], then [outcome]",
      "AC-2: Given [context], when [action], then [outcome]"
    ]
  },

  "design": {
    "figmaNodes": [
      {
        "url": "https://figma.com/file/...",
        "nodeId": "123:456",
        "componentName": "ButtonPrimary",
        "partial": false,
        "tokens": {
          "color-background-primary": "#0052CC"
        },
        "variants": [
          { "name": "variant", "values": ["primary", "secondary", "ghost"] }
        ],
        "states": ["default", "hover", "focus", "disabled", "loading"],
        "codeConnect": "Button",
        "screenshotUrl": "https://...",
        "spec": "Plain-English description of component intent"
      }
    ]
  },

  "branch": {
    "name": "feature/SPEC-001-slug",
    "base": "develop",
    "prUrl": null
  },

  "tdd": {
    "phase": null,
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

  "qaRuns": 0,

  "dod": {
    "lastCheckedPhase": "red | green | blue | qa",
    "lastCheckedAt": "ISO8601",
    "passed": false,
    "failedChecks": [],
    "warnChecks": [],
    "recommendedAction": "advance | return_to_red | return_to_green | return_to_blue | escalate"
  },

  "defects": [
    {
      "id": "DEF-001",
      "title": "Short description",
      "severity": "critical | high | medium | low",
      "type": "new_code | regression | design_fidelity | accessibility | missing_ac_coverage",
      "description": "What is wrong and how to reproduce it",
      "affectedFiles": ["src/components/Button.tsx"],
      "relatedAC": "AC-2",
      "origin": "current_ticket | pre_existing",
      "action": "return_to_developer | create_regression_ticket",
      "status": "open | resolved | ticket_created"
    }
  ],

  "humanReview": {
    "status": "pending | changes_requested | approved",
    "comments": [
      {
        "author": "human",
        "timestamp": "ISO8601",
        "body": "Comment text"
      }
    ]
  },

  "context": {
    "version": "1.0",
    "agentNotes": "Tagged notes — format: [WRITER → TARGET]: body — see skills/agent-notes-convention.md",
    "agentNotesArchive": "Overflow from agentNotes when entries exceed 20 lines — never filtered into slices"
  },

  "contextSlice": {
    "preparedFor": "red | green | blue | developer-orchestrator | qa | pipeline-orchestrator | architect | ba",
    "preparedAt": "ISO8601",
    "schemaVersion": "1.0",
    "domainGlossary": "Trimmed domain concepts relevant to this spec and agent",
    "relevantDecisions": [
      "ADR-001: One-line summary of decision relevant to this agent"
    ],
    "stackSummary": "Trimmed stack info relevant to this agent's task",
    "designSummary": "Trimmed Figma/design info relevant to this agent",
    "specOverview": {
      "id": "SPEC-001",
      "title": "...",
      "brs": [],
      "acs": [],
      "openDefects": []
    },
    "pipelineState": {
      "tddPhase": "red",
      "iteration": 0,
      "qaRuns": 0,

  "dod": {
    "lastCheckedPhase": "red | green | blue | qa",
    "lastCheckedAt": "ISO8601",
    "passed": false,
    "failedChecks": [],
    "warnChecks": [],
    "recommendedAction": "advance | return_to_red | return_to_green | return_to_blue | escalate"
  },
      "lastAuditEntry": {}
    },
    "agentNotes": "Filtered agentNotes relevant to this agent"
  },

  "audit": [
    {
      "timestamp": "ISO8601",
      "agent": "pipeline-orchestrator | developer-orchestrator | red | green | blue | qa",
      "action": "Description of what was done",
      "result": "success | failure | escalated | halted",
      "iteration": 0
    }
  ]
}
```

---

## Field ownership

| Field | Owner | Others |
|---|---|---|
| `ticket.status` | pipeline-orchestrator, developer-orchestrator | read |
| `ticket.id`, `title`, `url` | pipeline-orchestrator (init) | read |
| `requirements.*` | pipeline-orchestrator (init from spec) | read |
| `design.figmaNodes` | pipeline-orchestrator (init from Figma) | read |
| `branch.name`, `base` | pipeline-orchestrator (init) | read |
| `branch.prUrl` | developer-orchestrator | read |
| `tdd.phase` | developer-orchestrator, red, green, blue | read |
| `tdd.loop.iteration` | developer-orchestrator only | read |
| `tdd.testResults` | red, green, blue (own phase only) | read |
| `tdd.acCoverage` | red (init + update), green, blue (update) | read |
| `qaRuns` | qa-orchestrator only | read |
| `dod` | check-dod atom (via developer-orchestrator) | read |
| `defects` | qa-orchestrator (append) | developer reads |
| `defects[].status` | developer-orchestrator, qa-orchestrator | read |
| `humanReview.*` | pipeline-orchestrator (reads from PR state) | read |
| `context.agentNotes` | any agent — append only, tagged format [WRITER → TARGET] | append |
| `context.agentNotesArchive` | prepare-context-slice atom (auto-managed) | read |
| `contextSlice` | pipeline-orchestrator only (overwrites before each agent) | read |
| `audit` | all agents — append only | append |

---

## contextSlice rules

- Written by the pipeline orchestrator immediately before invoking any agent
- Each agent reads **only** from `contextSlice` — not directly from source files
- The slice is role-specific — fields present vary by `preparedFor` value
- Source of truth always remains the context files and spec — the slice is a
  trimmed read-only view
- If `contextSlice.preparedFor` does not match the invoking agent's role,
  the agent must stop and log a `warn` event before proceeding
- See `.agents/skills/atoms/prepare-context-slice.md` for full profile definitions

---

## General rules

- **No agent overwrites another agent's fields** outside its own scope.
- **`audit` is append-only.** Every agent appends on every meaningful action.
- **`context.agentNotes` is append-only.** Prefix with `[AGENT-NAME]:`.
- **`tdd.loop.iteration`** incremented only by the developer orchestrator.
- **`ticket.status`** updated only by orchestrators (pipeline or developer).
- **`qaRuns`** incremented by QA orchestrator at the start of each run.
- If `tdd.loop.iteration >= maxIterations` → escalate, do not loop again.
- If `qaRuns >= 3` → escalate, do not run QA again.
- `handoff.json` is committed on every meaningful state change.
- `handoff.json` is never committed to `develop` — feature branch only.
