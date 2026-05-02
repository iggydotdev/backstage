---
name: prepare-context-slice
description: >
  Read full source context files and produce a trimmed, role-specific context slice
  for a target agent. Write the slice to handoff.json > contextSlice before invoking
  any agent. Each agent reads only from contextSlice — never directly from source files.
  Use before invoking any molecule or sub-agent.
---

# Prepare Context Slice

Build a role-scoped context slice and write it to `handoff.json > contextSlice`.

## Inputs needed
- `targetAgent` — one of: red | green | blue | developer-orchestrator | qa | pipeline-orchestrator | architect | ba
- Source files: `system.md`, `stack.md`, `decisions.md`, `domain.md`, `handoff.json`

## Profiles by target agent

**pipeline-orchestrator**
- system.md → SUMMARY block only
- stack.md → SUMMARY block only
- handoff.json → ticket, branch, tdd.phase, tdd.loop, qaRuns, last 5 audit entries

**developer-orchestrator**
- system.md → domain glossary section only
- decisions.md → active decisions one-liners (ADRs tagged to current epic)
- stack.md → SUMMARY block only
- handoff.json → ticket, requirements, tdd, open defects, agentNotes, last 10 audit entries

**red**
- system.md → domain glossary (concept names + one-line definitions)
- stack.md → test runner, test command, file convention, mock library ONLY
- handoff.json → requirements.acs, design.figmaNodes, tdd.acCoverage, agentNotes (filtered for RED and ALL)

**green**
- stack.md → FULL (needs project structure, component library, state management)
- system.md → domain glossary only
- handoff.json → tdd.testResults.output (failing tests), design.figmaNodes, requirements.brs, agentNotes (filtered for GREEN and ALL)

**blue**
- stack.md → coding standards, lint command, type check command, project structure
- system.md → domain glossary only
- handoff.json → tdd.testResults (passing baseline), agentNotes (filtered for BLUE and ALL)

**qa**
- system.md → SUMMARY block + key qualities section
- stack.md → e2e command, a11y command, visual diff command
- handoff.json → requirements.acs, design.figmaNodes, tdd.testResults, defects, qaRuns, agentNotes (filtered for QA and ALL)

**architect**
- system.md → FULL
- decisions.md → FULL
- .specs/done/ → titles only (for review mode)

**ba**
- system.md → FULL
- decisions.md → active decisions one-liners only
- .specs/epics/ → all epic titles + status
- .specs/features/ → all feature titles + status

## agentNotes filtering
Map targetAgent to role token: RED, GREEN, BLUE, QA, DEV-ORCH, PIPELINE, BA, ARCHITECT.

Include only lines where `TARGET == roleToken OR TARGET == "ALL"`.
Exclude `[WRITER → HUMAN]` lines (surface those in PR descriptions only).
If filtered notes exceed 20 lines → include only the most recent 20.

If raw agentNotes exceeds 50 total lines:
- Move oldest entries to `agentNotesArchive`
- Keep only last 30 in `agentNotes`

## SUMMARY block extraction
Look for `<!-- SUMMARY -->` and `<!-- END SUMMARY -->` markers.
If missing → use first 30 lines as fallback, log a `warn` event.

## Write to handoff.json
```json
"contextSlice": {
  "preparedFor": "red",
  "preparedAt": "ISO8601",
  "schemaVersion": "1.4.0",
  ... role-specific fields ...
}
```

Commit:
```bash
git add handoff.json
git commit -m "chore(pipeline): prepare context slice for [role] — SPEC-NNN"
```

## Rules
- Never read a source file not listed in the agent's profile
- contextSlice is overwritten on every invocation — it is not cumulative
- The slice is a read-only view — source files remain the truth
- If a source file is missing → omit that field, log a `warn` event, do not fail
