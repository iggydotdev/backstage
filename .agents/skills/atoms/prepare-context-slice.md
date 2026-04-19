# Skill: Prepare Context Slice

**Type:** Atom
**Used by:** Pipeline Orchestrator
**Trigger:** Immediately before invoking any agent or sub-agent

---

## Purpose
Read the full source context files and produce a trimmed, role-specific
context slice for the target agent. The slice contains only what that
agent needs — nothing more.

This keeps agent context lean, reduces noise in decision-making, and
ensures agents aren't distracted by information outside their scope.

The slice is **ephemeral** — it is written to `handoff.json > contextSlice`
before each agent invocation and overwritten before the next. It is never
the source of truth — the source files always are.

---

## Inputs
```json
{
  "targetAgent": "red | green | blue | developer-orchestrator | qa | pipeline-orchestrator | architect | ba",
  "specId": "SPEC-001",
  "sources": {
    "systemMd": ".agents/context/system.md",
    "decisionsMd": ".agents/context/decisions.md",
    "stackMd": ".agents/context/stack.md",
    "domainMd": ".agents/context/domain.md",
    "handoff": "handoff.json"
  }
}
```

---

## Context profiles by agent

Each profile defines exactly what to read and how deeply.

---

### `pipeline-orchestrator`
**Reads:**
- `system.md` → `<!-- SUMMARY -->` block only
- `stack.md` → `<!-- SUMMARY -->` block only
- `handoff.json` → full (`ticket`, `branch`, `tdd.phase`, `tdd.loop`, `qaRuns`, `audit` last 5 entries)

**Slice output:**
```json
{
  "preparedFor": "pipeline-orchestrator",
  "systemSummary": "<SUMMARY block from system.md>",
  "stackSummary": "<SUMMARY block from stack.md>",
  "pipelineState": {
    "ticketId": "SPEC-001",
    "ticketStatus": "in_progress",
    "tddPhase": "green",
    "iteration": 1,
    "qaRuns": 0,
    "lastAuditEntry": { ... }
  }
}
```

---

### `architect`
**Reads:**
- `system.md` → full
- `decisions.md` → full
- `.specs/done/` → titles only (for review mode — what has been built)

**Slice output:**
```json
{
  "preparedFor": "architect",
  "systemFull": "<full system.md content>",
  "decisionsFull": "<full decisions.md content>",
  "completedSpecTitles": ["SPEC-001: Login form", "SPEC-002: Registration form"]
}
```

---

### `ba`
**Reads:**
- `system.md` → full
- `decisions.md` → active decisions only, one-liner summary per ADR
- `.specs/epics/` → all epic files (titles + status)
- `.specs/features/` → all feature files (titles + status)

**Does NOT read:** `stack.md`, `domain.md`, `handoff.json`

**Slice output:**
```json
{
  "preparedFor": "ba",
  "systemFull": "<full system.md content>",
  "activeDecisions": [
    "ADR-001: Repository pattern for all data fetching",
    "ADR-002: Optimistic UI updates for cart interactions"
  ],
  "epicsSummary": [
    { "id": "EPIC-001", "title": "User Authentication", "status": "active" }
  ],
  "featuresSummary": [
    { "id": "FEAT-001", "title": "Email/password login", "status": "active", "epic": "EPIC-001" }
  ]
}
```

---

### `developer-orchestrator`
**Reads:**
- `system.md` → `<!-- SUMMARY -->` block + domain glossary section only
- `decisions.md` → active decisions one-liners, filtered to those tagged with the current epic
- `stack.md` → `<!-- SUMMARY -->` block only
- `handoff.json` → `ticket`, `requirements`, `tdd`, `defects` (open only), `context.agentNotes`, last 10 `audit` entries

**Does NOT read:** full system vision, BA epic/feature hierarchy, figmaNodes detail

**Slice output:**
```json
{
  "preparedFor": "developer-orchestrator",
  "domainGlossary": "<domain concepts section from system.md — 200 words max>",
  "relevantDecisions": ["ADR-001: Repository pattern for all data fetching"],
  "stackSummary": "<SUMMARY block from stack.md>",
  "specOverview": {
    "id": "SPEC-001",
    "title": "Login form component",
    "brs": ["BR-1: ...", "BR-2: ..."],
    "acs": ["AC-1: ...", "AC-2: ..."],
    "tddPhase": "green",
    "iteration": 1,
    "openDefects": []
  }
}
```

---

### `red`
**Reads:**
- `system.md` → domain glossary only (concept names + one-line definitions)
- `stack.md` → test runner, test command, test file convention, mock library only
- `handoff.json` → `requirements.acs` (full), `design.figmaNodes` (full),
  `tdd.acCoverage`, `context.agentNotes`

**Does NOT read:** BRs, system vision, coding standards, BA hierarchy, prior audit

**Slice output:**
```json
{
  "preparedFor": "red",
  "domainGlossary": "Product: a sellable item with SKU and price. Order: ...",
  "testingConventions": {
    "runner": "Vitest",
    "command": "pnpm test",
    "fileConvention": "*.test.tsx next to source",
    "mockLibrary": "vi + msw for API mocking"
  },
  "acs": ["AC-1: Given...", "AC-2: Given..."],
  "figmaNodes": [ ... ],
  "uncoveredACs": [],
  "agentNotes": "..."
}
```

---

### `green`
**Reads:**
- `stack.md` → full (needs project structure, component library, state management)
- `system.md` → domain glossary only
- `handoff.json` → `tdd.testResults.output` (failing tests), `design.figmaNodes` (full),
  `context.agentNotes`, `requirements.brs` (for intent, not re-scoping)

**Does NOT read:** ACs directly (tests already encode them), system vision, decisions, BA hierarchy

**Slice output:**
```json
{
  "preparedFor": "green",
  "domainGlossary": "...",
  "stack": {
    "stack": "React 18 + TypeScript + Vite",
    "projectStructure": "feature-based under src/features/",
    "componentLibrary": "shadcn/ui",
    "stateManagement": "Zustand",
    "lintCommand": "pnpm lint"
  },
  "failingTests": "<tdd.testResults.output>",
  "figmaNodes": [ ... ],
  "brs": ["BR-1: ...", "BR-2: ..."],
  "agentNotes": "..."
}
```

---

### `blue`
**Reads:**
- `stack.md` → coding standards, lint command, type check command, project structure
- `system.md` → domain glossary only
- `handoff.json` → `tdd.testResults` (passing baseline), `context.agentNotes`

**Does NOT read:** ACs, figmaNodes (design already implemented), BRs, BA hierarchy, decisions

**Slice output:**
```json
{
  "preparedFor": "blue",
  "domainGlossary": "...",
  "refactoringConventions": {
    "codingStandards": "Airbnb ESLint config + project-specific rules at .eslintrc",
    "lintCommand": "pnpm lint",
    "typeCheckCommand": "pnpm tsc --noEmit",
    "projectStructure": "feature-based under src/features/"
  },
  "passingTestBaseline": {
    "total": 12,
    "passed": 12,
    "coverage": "87%"
  },
  "agentNotes": "..."
}
```

---

### `qa`
**Reads:**
- `system.md` → `<!-- SUMMARY -->` block + key qualities section (for priority ordering)
- `stack.md` → e2e command, a11y command, visual diff command
- `handoff.json` → `requirements.acs` (full), `design.figmaNodes` (full),
  `tdd.testResults`, `defects` (all), `qaRuns`, `context.agentNotes`

**Does NOT read:** full system vision, coding standards, BA hierarchy, decisions

**Slice output:**
```json
{
  "preparedFor": "qa",
  "systemSummary": "<SUMMARY block>",
  "qualityPriorities": ["1. Accessibility — WCAG AA", "2. Performance", "3. Simplicity"],
  "testingCommands": {
    "e2eCommand": "pnpm test:e2e",
    "a11yCommand": "pnpm test:a11y",
    "visualDiffCommand": "pnpm test:visual"
  },
  "acs": ["AC-1: ...", "AC-2: ..."],
  "figmaNodes": [ ... ],
  "qaRuns": 0,
  "openDefects": [],
  "agentNotes": "..."
}
```

---

## Process

### Step 1 — Identify the profile
Match `targetAgent` to the profile above. If no profile exists for the
target agent, log a `warn` event and return the `<!-- SUMMARY -->` blocks
from all context files plus the full `handoff.json`.

### Step 2 — Read only what the profile requires
Do not read files not listed in the profile.
For `<!-- SUMMARY -->` blocks, extract only the content between
`<!-- SUMMARY -->` and `<!-- END SUMMARY -->` markers.

### Step 3 — Filter and trim
Apply profile-specific filters:
- "active decisions only" → skip ADRs with status `superseded`
- "last N audit entries" → slice array from end
- "open defects only" → filter `defects` where `status == "open"`
- "domain glossary only" → extract the `## Domain model > ### Concepts` section

If a source file is missing:
- Log `warn` event: `context_source_missing`
- Omit that field from the slice — do not fail

### Step 4 — Write to handoff
```json
"contextSlice": {
  "preparedFor": "red",
  "preparedAt": "ISO8601",
  "schemaVersion": "1.0",
  ...role-specific fields...
}
```

Commit:
```bash
git add handoff.json
git commit -m "chore(pipeline): prepare context slice for red — SPEC-001"
```

---

## Output
```json
{
  "preparedFor": "red",
  "tokenEstimate": 2400,
  "sourcesRead": ["system.md (glossary only)", "stack.md (testing section)", "handoff.json (acs + figmaNodes)"],
  "sourcesSkipped": [],
  "warnings": []
}
```

---

## Rules
- Never read a source not listed in the agent's profile
- Never include the full `system.md` for agents whose profile says "summary only"
- `contextSlice` is overwritten on every invocation — it is not cumulative
- If the `<!-- SUMMARY -->` block is missing from a context file, read the
  first 30 lines of that file as the fallback summary and log a `warn`
- Token estimate is informational only — do not block on it

---

## Agent notes filtering

This skill is responsible for filtering `agentNotes` before including
it in any context slice. Follow the tagging convention defined in
`skills/agent-notes-convention.md`.

### Step — Filter agentNotes for target agent

Map `targetAgent` to its role token:

| targetAgent | Role token |
|---|---|
| `pipeline-orchestrator` | `PIPELINE` |
| `developer-orchestrator` | `DEV-ORCH` |
| `red` | `RED` |
| `green` | `GREEN` |
| `blue` | `BLUE` |
| `qa` | `QA` |
| `ba` | `BA` |
| `architect` | `ARCHITECT` |

```bash
ROLE_TOKEN="GREEN"  # example for green agent

# Read raw agentNotes
RAW_NOTES=$(cat handoff.json | jq -r '.context.agentNotes // ""')

# Filter to lines targeting this role or ALL
FILTERED=$(echo "$RAW_NOTES" | grep -E "^\[.+ → (${ROLE_TOKEN}|ALL)\]:")

# Count filtered lines
LINE_COUNT=$(echo "$FILTERED" | grep -c . || echo 0)

# If over 20 lines, take only the most recent 20
if [ "$LINE_COUNT" -gt 20 ]; then
  FILTERED=$(echo "$FILTERED" | tail -20)
fi

echo "$FILTERED"
```

### Overflow handling

If the raw `agentNotes` field exceeds 50 total lines:
1. Move all but the last 30 lines to `context.agentNotesArchive`
2. Keep only the most recent 30 lines in `context.agentNotes`
3. Log a `warn` event: `agent_notes_archived — N lines moved to archive`

```bash
TOTAL_LINES=$(echo "$RAW_NOTES" | wc -l)

if [ "$TOTAL_LINES" -gt 50 ]; then
  ARCHIVE=$(echo "$RAW_NOTES" | head -n $((TOTAL_LINES - 30)))
  CURRENT=$(echo "$RAW_NOTES" | tail -30)

  # Append to existing archive
  EXISTING_ARCHIVE=$(cat handoff.json | jq -r '.context.agentNotesArchive // ""')
  NEW_ARCHIVE="${EXISTING_ARCHIVE}\n${ARCHIVE}"

  cat handoff.json \
    | jq --arg notes "$CURRENT" '.context.agentNotes = $notes' \
    | jq --arg archive "$NEW_ARCHIVE" '.context.agentNotesArchive = $archive' \
    > tmp.json && mv tmp.json handoff.json
fi
```

### HUMAN-tagged notes

Notes tagged `[WRITER → HUMAN]` are never included in agent slices.
They are collected separately and surfaced only when:
- Opening or updating a draft PR description
- Posting an escalation comment

```bash
HUMAN_NOTES=$(echo "$RAW_NOTES" | grep -E "^\[.+ → HUMAN\]:")
```

The pipeline orchestrator reads `HUMAN_NOTES` when composing PR
descriptions and escalation comments.

### Notes for the PR description template

When the developer orchestrator opens a draft PR, it should include:

```markdown
## Agent notes for reviewers

[List of all HUMAN-tagged notes from agentNotes, most recent first]

[If none: "No issues flagged for human review."]
```
