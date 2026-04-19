# Agent Notes Convention

The canonical specification for writing to and reading from
`handoff.json > context.agentNotes`.

Referenced by all agents and by `skills/atoms/prepare-context-slice.md`.

---

## The problem this solves

`agentNotes` is a single append-only string shared across all agents
and all phases of a pipeline run. Without structure it becomes noise —
by the time QA runs, it may contain notes from six prior agents, most
irrelevant to the task at hand.

This convention makes every note self-describing: who wrote it,
who should read it, and what it means.

---

## Tag format

Every note appended to `agentNotes` must begin with a tag:

```
[WRITER → TARGET]: note body
```

### WRITER
The agent or skill that wrote the note. One of:

| Token | Agent |
|---|---|
| `PIPELINE` | Pipeline Orchestrator |
| `DEV-ORCH` | Developer Orchestrator |
| `RED` | Red Agent |
| `GREEN` | Green Agent |
| `BLUE` | Blue Agent |
| `QA` | QA Orchestrator |
| `BA` | BA Agent |
| `ARCHITECT` | Architect Agent |
| `CHECK-DOD` | check-dod atom |
| `CONTEXT-SLICE` | prepare-context-slice atom |
| `FIGMA` | fetch-figma-nodes atom |
| `RECOVER` | recover-pipeline atom |

### TARGET
The agent or role the note is intended for. Same tokens as WRITER,
plus two special values:

| Token | Meaning |
|---|---|
| `ALL` | Every agent reads this |
| `HUMAN` | Surfaces in PR description and escalation comments only |

### Note body
Plain English. One concern per note. As short as possible.
If a note requires more than two sentences, it belongs in a separate
field or a PR comment — not in `agentNotes`.

---

## Examples

```
[RED → GREEN]: ButtonPrimary test uses data-testid="btn-primary" — match this exactly, not className
[RED → GREEN]: AC-3 test mocks useAuth — import mock from __mocks__/useAuth.ts
[GREEN → BLUE]: Duplicated error handler in LoginForm and RegisterForm — candidate for extraction
[GREEN → BLUE]: Used inline styles for focus ring — replace with Tailwind ring utility
[BLUE → QA]: Deferred TS error on onClick prop — see Button.tsx:42 TODO comment
[BLUE → QA]: Minor visual diff expected on hover state — Figma token spacing-2 applied, was spacing-1
[QA → HUMAN]: A11y check skipped — axe-core not configured in this project yet
[QA → HUMAN]: Visual diff tool unavailable — manual Figma comparison required before merge
[FIGMA → ALL]: Figma MCP returned partial data for node 123:456 — tokens may be incomplete
[CHECK-DOD → DEV-ORCH]: Red DoD passed 6/6 — advancing to Green
[CHECK-DOD → DEV-ORCH]: Green DoD failed G-4 — test files modified, escalating
[PIPELINE → ALL]: context/v1.1 applied mid-run — stack.md updated with new test runner
[DEV-ORCH → ALL]: green-commit-sha=abc123def456
```

---

## Writing rules

1. **Always include the full tag** — `[WRITER → TARGET]:` — never omit either part
2. **One note per append** — do not write multiple notes in a single string
3. **Append, never overwrite** — always concatenate with a newline separator
4. **Be specific** — name the file, component, AC, or check involved
5. **No markdown** — plain text only, no headers or lists inside a note
6. **No secrets** — no API keys, tokens, or credentials ever in agentNotes

### Append pattern
```bash
# Read current notes
CURRENT=$(cat handoff.json | jq -r '.context.agentNotes // ""')

# Append new note
NEW_NOTE="[RED → GREEN]: ButtonPrimary test uses data-testid=\"btn-primary\""

# Write back
NEW_NOTES="${CURRENT}\n${NEW_NOTE}"
cat handoff.json | jq --arg notes "$NEW_NOTES" '.context.agentNotes = $notes' > tmp.json
mv tmp.json handoff.json
```

---

## Reading rules — for prepare-context-slice

When building a context slice for a target agent, filter `agentNotes`
to include only lines where:

```
TARGET == agent's role token  OR  TARGET == "ALL"
```

And additionally include `HUMAN`-tagged notes only when building the
PR description or escalation comment — not in agent slices.

### Filtering logic
```bash
TARGET_ROLE="GREEN"  # example

FILTERED=$(echo "$AGENT_NOTES" | grep -E "^\[.+ → (${TARGET_ROLE}|ALL)\]:")
```

### Max note limit
If filtered notes exceed 20 lines, include only the most recent 20.
Older notes are archived — prepend them to a `agentNotesArchive` field
(plain string, not filtered into slices) so they are never lost but
don't burden agents.

```json
"context": {
  "agentNotes": "<current — last 20 filtered lines>",
  "agentNotesArchive": "<overflow — older entries>"
}
```

---

## Targeting guide

Use this to decide which TARGET to use when writing a note:

| Situation | Target |
|---|---|
| Implementation hint needed for Green | `GREEN` |
| Refactoring candidate spotted during Green | `BLUE` |
| Deferred issue for QA to verify | `QA` |
| Issue requiring human decision before merge | `HUMAN` |
| Infrastructure issue all agents should know about | `ALL` |
| Orchestrator bookkeeping (commit SHAs, phase markers) | `ALL` |
| BA clarification needed | `BA` |
| Context or system-level observation | `ALL` |

When in doubt, use `ALL`. A note that reaches the wrong agent is
harmless. A note that reaches no agent is a silent failure.

---

## Note lifecycle

Notes are never deleted from `agentNotes` during a pipeline run.
After a successful merge, `agentNotes` is preserved in the feature
branch `handoff.json` history — it is not carried forward to the
next spec. Each spec starts with an empty `agentNotes`.

The pipeline orchestrator writes the first note when initialising
`handoff.json`:
```
[PIPELINE → ALL]: SPEC-001 pipeline started — <ISO8601>
```
