---
name: build-handoff
description: >
  Construct and commit handoff.json from a spec file and fetched Figma data.
  Use this at pipeline Step 5, after the branch exists and Figma nodes are fetched.
  This is the contract all downstream agents read and write — get it right here.
---

# Build Handoff

Combine spec file + Figma data into a complete, valid `handoff.json`.

## Inputs needed
- Spec file path (e.g. `.specs/active/SPEC-001-login-form-component.md`)
- Branch name (e.g. `feature/SPEC-001-login-form-component`)
- figmaNodes array (from fetch-figma-nodes skill, may be empty if Figma unavailable)

## Step 1 — Parse the spec file
Extract:
- Spec ID and title from `# SPEC-NNN: Title` heading
- BRs from `## Business requirements` section
- ACs from `## Acceptance criteria` section
- Dependencies from `## Dependencies` section → log in agentNotes
- Notes from `## Notes` section → append to agentNotes

If `requirements.brs` is empty → HALT, flag to pipeline orchestrator
If `requirements.acs` is empty → HALT, flag to pipeline orchestrator

## Step 2 — Build the handoff object

```json
{
  "schemaVersion": "1.4.0",

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
    "figmaNodes": []
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
  "dod": {
    "lastCheckedPhase": null,
    "lastCheckedAt": null,
    "passed": false,
    "failedChecks": [],
    "warnChecks": [],
    "recommendedAction": null
  },

  "defects": [],

  "humanReview": {
    "status": "pending",
    "comments": []
  },

  "context": {
    "agentNotes": "[PIPELINE → ALL]: SPEC-001 pipeline started — <ISO8601>",
    "agentNotesArchive": ""
  },

  "contextSlice": null,

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

## Step 3 — Validate before writing
- [ ] `ticket.id` matches spec filename prefix
- [ ] `requirements.brs` is non-empty
- [ ] `requirements.acs` is non-empty
- [ ] `tdd.acCoverage.total` equals `requirements.acs.length`
- [ ] `tdd.acCoverage.uncovered` lists all AC identifiers
- [ ] `branch.name` matches the created branch
- [ ] `schemaVersion` is `"1.4.0"`

If any check fails → halt, report, do not write.

## Step 4 — Write and commit
```bash
# Write handoff.json to branch root
git add handoff.json
git commit -m "chore(pipeline): SPEC-001 — initialise handoff"
git push origin feature/SPEC-001-login-form-component
```

## Output
Report: AC count, figmaNode count, branch committed, any warnings.
