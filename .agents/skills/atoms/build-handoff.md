# Skill: Build Handoff

**Type:** Atom
**Used by:** Pipeline Orchestrator
**Trigger:** Step 5 of pipeline — after Figma nodes are fetched

---

## Purpose
Combine the spec file and fetched Figma data into a complete, valid
`handoff.json` file. This is the contract all downstream agents will
read and write. Get it right here.

---

## Inputs
```json
{
  "specFile": ".specs/active/SPEC-001-login-form-component.md",
  "branchName": "feature/SPEC-001-login-form-component",
  "figmaNodes": [ ... ],
  "contextVersion": "1.0"
}
```

---

## Process

### Step 1 — Parse the spec file
Extract all structured fields from the spec markdown:

| Spec section | handoff.json field |
|---|---|
| `# SPEC-NNN: Title` | `ticket.id`, `ticket.title` |
| `## Business requirements` | `requirements.brs[]` |
| `## Acceptance criteria` | `requirements.acs[]` |
| `## Figma` URLs | Used to cross-reference fetched figmaNodes |
| `## Dependencies` | Logged in `context.agentNotes` |
| `## Notes` | Appended to `context.agentNotes` |

Parse BRs and ACs as ordered arrays. Preserve the original numbering
(BR-1, BR-2, AC-1, AC-2, etc.) as the list index.

If any required section is missing or empty:
- `requirements.brs` empty → halt, flag to pipeline orchestrator
- `requirements.acs` empty → halt, flag to pipeline orchestrator
- Figma section missing for a visual spec → log warning, do not halt

### Step 2 — Build the handoff object
Construct the full object per the schema in `.agents/handoff/schema.md`:

```json
{
  "schemaVersion": "1.0.0",

  "ticket": {
    "id": "SPEC-001",
    "title": "Login form component",
    "url": ".specs/active/SPEC-001-login-form-component.md",
    "status": "in_progress"
  },

  "requirements": {
    "brs": ["BR-1: ...", "BR-2: ..."],
    "acs": ["AC-1: Given...", "AC-2: Given..."]
  },

  "design": {
    "figmaNodes": [ ... ]
  },

  "branch": {
    "name": "feature/SPEC-001-login-form-component",
    "base": "develop",
    "prUrl": null
  },

  "tdd": {
    "phase": null,
    "loop": { "iteration": 0, "maxIterations": 3 },
    "testResults": {
      "total": 0, "passed": 0, "failed": 0,
      "skipped": 0, "coverage": null, "output": ""
    },
    "acCoverage": {
      "total": 3,
      "covered": 0,
      "uncovered": ["AC-1", "AC-2", "AC-3"]
    }
  },

  "qaRuns": 0,

  "defects": [],

  "humanReview": {
    "status": "pending",
    "comments": []
  },

  "context": {
    "version": "1.0",
    "resolvedStack": "<contents of stack.md — first 500 chars>",
    "agentNotes": "<spec notes + any dependency flags>"
  },

  "audit": [
    {
      "timestamp": "<ISO8601>",
      "agent": "pipeline-orchestrator",
      "action": "handoff.json initialised from SPEC-001",
      "result": "success",
      "iteration": 0
    }
  ]
}
```

Note: `tdd.acCoverage.total` is pre-populated with the count of ACs from
the spec. `uncovered` is pre-populated with all AC identifiers — the Red
Agent will update these as tests are written.

### Step 3 — Validate the object
Before writing the file, verify:
- [ ] `ticket.id` matches the spec filename prefix
- [ ] `requirements.brs` is non-empty
- [ ] `requirements.acs` is non-empty
- [ ] `tdd.acCoverage.total` equals `requirements.acs.length`
- [ ] `branch.name` matches the created branch
- [ ] Schema version matches `.agents/handoff/schema.md`

If any check fails, halt and report — do not write an invalid handoff.

### Step 4 — Write and commit
```bash
echo '<json>' > handoff.json
git add handoff.json
git commit -m "chore(pipeline): SPEC-001 — initialise handoff"
git push origin feature/SPEC-001-login-form-component
```

---

## Output
```json
{
  "path": "handoff.json",
  "branch": "feature/SPEC-001-login-form-component",
  "acCount": 3,
  "figmaNodeCount": 1,
  "committed": true
}
```

---

## Rules
- Never write a handoff.json with empty BRs or ACs
- `audit` must have at least one entry (the init entry from this skill)
- `context.resolvedStack` must be populated — agents rely on it
- Do not include raw Figma API responses — use the structured figmaNodes format only
