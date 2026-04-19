# .agents

All agent definitions, context files, schemas, and skills for the automated
development pipeline.

---

## Structure

```
root/
├── AGENTS.md                            ← universal tool-agnostic entry point
├── pipeline.log.ndjson                  ← append-only event log (all specs)
│
├── .pipeline/
│   └── checkpoints/                     ← handoff.json snapshots per pipeline run
│
├── .specs/
│   ├── template.md                      ← spec format
│   ├── epics/template.md
│   ├── features/template.md
│   ├── active/                          ← pipeline picks from here
│   └── done/                            ← archived after merge
│
└── .agents/
    ├── README.md                        ← this file
│   ├── security.md                      ← read before running anything
    ├── handoff/
    │   └── schema.md                    ← typed JSON contract (v1.1.0)
    ├── context/                         ← git-versioned, evolves over time
    │   ├── system.md                    ← architect: product + domain model
    │   ├── decisions.md                 ← architect: ADR log
    │   ├── stack.md                     ← onboarding: stack + conventions
    │   ├── domain.md                    ← onboarding: project knowledge
    │   └── CHANGELOG.md                 ← every context change, versioned
    ├── agents/
    │   ├── pipeline-orchestrator.md     ← top-level per-spec coordinator
    │   ├── architect.md                 ← system vision, domain, decisions
    │   ├── ba.md                        ← epics → features → specs
    │   ├── onboarding.md                ← resolves [SHORTCODES], runs once
    │   ├── developer/
    │   │   ├── orchestrator.md          ← TDD lifecycle manager
    │   │   ├── red.md                   ← writes failing tests
    │   │   ├── green.md                 ← writes minimal implementation
    │   │   └── blue.md                  ← refactors implementation
    │   └── qa/
    │       └── orchestrator.md          ← validates ACs, routes defects
    └── skills/
        ├── observability.md             ← event schema, log format, checkpoints
    ├── definition-of-done.md        ← canonical DoD checklist per phase
    └── agent-notes-convention.md    ← tagging format for agentNotes field
        ├── error-handling.md            ← failure classification, retry, recovery
        └── atoms/
            ├── create-branch.md
            ├── fetch-figma-nodes.md
            ├── build-handoff.md
            ├── archive-spec.md
            ├── recover-pipeline.md      ← diagnose + restore broken runs
            ├── run-e2e-tests.md
            └── create-regression-ticket.md
```

---

## Agent hierarchy

```
Architect Agent
  → system.md, decisions.md
      ↓
BA Agent
  → epics, features, specs (human confirmed at each level)
      ↓
Onboarding Agent
  → stack.md, [SHORTCODE] resolution
      ↓
Pipeline Orchestrator  ←──── recover-pipeline (on error)
  → create-branch
  → fetch-figma-nodes
  → build-handoff → handoff.json
  → checkpoint ✓
      ↓
Developer Orchestrator
  → Red → Green → Blue (≤3 iterations)
  → checkpoint after each passing phase ✓
  → Draft PR
      ↓
⏸ Human Review
  → checkpoint on approval ✓
      ↓
QA Orchestrator (≤3 runs)
  → run-e2e-tests
  → classify + route defects
  → checkpoint on pass ✓
      ↓
merge → archive-spec → .specs/done/
```

---

## Observability

**`pipeline.log.ndjson`** at repo root — NDJSON, one event per line,
append-only, committed to `develop`. Contains every event across all
specs and all agents. Never truncated.

**`.pipeline/checkpoints/`** — `handoff.json` snapshots at key moments.
Used by `recover-pipeline` to restore known good state after a failure.

Both are governed by `.agents/skills/observability.md`.

### Useful log queries
```bash
# All errors
jq 'select(.severity == "error" or .severity == "fatal")' pipeline.log.ndjson

# Everything for a spec
jq 'select(.spec == "SPEC-001")' pipeline.log.ndjson

# All escalations
jq 'select(.event == "pipeline_escalated")' pipeline.log.ndjson

# Status of all active runs (last event per spec)
jq -s 'group_by(.spec) | map(sort_by(.timestamp) | last)' pipeline.log.ndjson
```

---

## Error recovery

All agents follow `.agents/skills/error-handling.md`:

| Failure class | Behaviour |
|---|---|
| Transient (network, timeout) | Retry with backoff, continue |
| Recoverable (partial data, warnings) | Degrade gracefully, flag in agentNotes |
| Phase failure | Restore checkpoint, retry phase |
| Unrecoverable | Escalate to human, halt |

**Principle: fail the step, not the pipeline.**

To recover a broken run:
```
→ Invoke skills/atoms/recover-pipeline.md with the spec ID
→ Follow the recovery proposal
```

---

## Full pipeline flow

```
[Once — project init]
Architect Agent → system.md + decisions.md → tag context/v1.0
Onboarding Agent → stack.md + resolve [SHORTCODES]

[Ongoing — per milestone]
BA Agent
  → epics → features → specs (human confirmed at each level)
  → confirmed specs to .specs/active/

[Per spec — automated]
Pipeline Orchestrator
  1.  Validate preconditions
  2.  Pick next eligible spec
  3.  create-branch
  4.  fetch-figma-nodes (degrades gracefully if unavailable)
  5.  build-handoff → commit handoff.json
  6.  checkpoint: handoff_initialised ✓
  7.  Developer Orchestrator (≤3 iterations)
      → Red → Green (checkpoint: tests_passing ✓) → Blue
      → checkpoint: refactor_complete ✓
      → Draft PR
  8.  ⏸ Human review
      → changes: re-invoke Developer Orchestrator
      → approved: checkpoint: pr_approved ✓
  9.  QA Orchestrator (≤3 runs)
      → pass: checkpoint: qa_passed ✓
      → fail (new code): re-invoke Developer → back to step 8
      → fail (pre-existing): create-regression-ticket (non-blocking)
      → escalate if qaRuns ≥ 3
  10. Merge → develop
  11. archive-spec → .specs/done/
  12. Update feature + epic status
  13. Recommend architect review if threshold met

[On any failure]
→ Classify failure (observability + error-handling contracts)
→ Restore from checkpoint if available
→ Retry or escalate
→ All events written to pipeline.log.ndjson

[Periodically]
Architect Agent (review mode)
  → reads done specs, proposes context updates via PR
  → bumps context version tag
```

---

## Context versioning

| Tag | Meaning |
|---|---|
| `context/v1.0` | Architect + onboarding init |
| `context/v1.N` | Incremental update |
| `context/v2.0` | Major change |

All updates via PR. Never direct commits to `develop`.
History in `.agents/context/CHANGELOG.md`.

---

## Context loading model

Agents never read context files directly. The pipeline orchestrator
prepares a **role-scoped context slice** before each agent invocation
and writes it to `handoff.json > contextSlice`. Agents read only from
their slice.

```
Source files (system.md, stack.md, decisions.md)
        ↓
prepare-context-slice (atom)
        ↓
contextSlice in handoff.json   ← agents read this only
        ↓
Agent runs with exactly the right information
```

### What each agent sees

| Agent | Gets |
|---|---|
| pipeline-orchestrator | System summary + pipeline state |
| architect | Full system.md + decisions.md |
| ba | Full system.md + active decisions one-liners + epic/feature status |
| developer-orchestrator | Domain glossary + relevant decisions + spec overview |
| red | Domain glossary + test conventions + ACs + figmaNodes |
| green | Domain glossary + full stack + failing tests + figmaNodes |
| blue | Domain glossary + refactoring conventions + passing test baseline |
| qa | System summary + quality priorities + test commands + ACs + figmaNodes |

### The SUMMARY block convention

Every context file has a machine-readable summary block at the top:

```markdown
<!-- SUMMARY -->
Key: value
Key: value
<!-- END SUMMARY -->
```

`prepare-context-slice` extracts this block for agents that need only
a high-level view. Agents that need full content get the full file.
If the SUMMARY block is missing, the first 30 lines are used as fallback.
