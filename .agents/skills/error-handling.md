# Error Handling Contract

Every agent follows this contract for classifying, recovering from, and
escalating errors. Read this alongside `skills/observability.md`.

---

## Core principle

**Fail the step, not the pipeline.**

Every failure should be contained to the smallest possible scope:
- A failed MCP call should not fail the agent
- A failed agent phase should not fail the spec
- A failed spec should not affect other specs

Agents degrade gracefully. They do not propagate failures upward unless
they have genuinely exhausted all recovery options.

---

## Failure classification

Before responding to any failure, classify it:

### Class 1 — Transient
Temporary condition expected to resolve on its own.
Examples: network timeout, Figma MCP rate limit, git remote temporarily unavailable.
→ **Retry with backoff. Log as `warn`. Continue if retry succeeds.**

### Class 2 — Recoverable
Something went wrong but the pipeline can continue with reduced capability
or with a different approach.
Examples: Figma node partially unavailable, lint warnings, one AC has no test.
→ **Log as `warn`. Flag in `context.agentNotes`. Continue with degraded output.**

### Class 3 — Phase failure
The current agent phase cannot complete, but the pipeline is not broken.
The orchestrator can retry from a checkpoint.
Examples: tests still failing after implementation attempts, type errors blocking blue phase.
→ **Log as `error` with `recoverable: true`. Return to orchestrator. Orchestrator retries or escalates.**

### Class 4 — Unrecoverable
The pipeline cannot continue without human input.
Examples: `handoff.json` corrupt, git conflict, spec missing required fields, max iterations reached.
→ **Log as `error` with `recoverable: false` or `fatal`. Escalate. Halt.**

---

## Recovery decision tree

When anything fails, work through this in order:

```
1. Is this a transient external failure?
   YES → retry (per retry policy in observability.md) → if resolved: continue
   NO  → continue to 2

2. Can the pipeline continue without this data/result?
   YES → log as warn, flag in agentNotes, continue with degraded output
   NO  → continue to 3

3. Is there a checkpoint to restore from?
   YES → log as error (recoverable: true), restore checkpoint, retry phase once
   NO  → continue to 4

4. Has max iterations/retries been reached?
   YES → log as fatal, escalate to human, halt
   NO  → log as error (recoverable: true), increment iteration, retry phase
```

---

## What each agent does on failure

### Pipeline Orchestrator
- Catches failures from all sub-agents and atoms
- Classifies the failure and applies the recovery tree
- Restores from checkpoint when available
- Writes all escalations to `pipeline.log.ndjson`
- Posts escalation comment on PR or creates a draft PR if none exists

### Developer Orchestrator
- On Red failure: stays in red, increments iteration, retries
- On Green failure: returns to red, increments iteration
- On Blue failure: returns to green, increments iteration
- On max iterations: writes `loop_limit_reached` error event, returns
  control to pipeline orchestrator with `ticket.status = "blocked"`
- Never silently swallows a test failure

### Red Agent
- If tests won't fail (false positive): tightens test, re-runs — does not proceed
- If existing tests break: fixes regression before proceeding — does not proceed with broken baseline
- If AC is ambiguous: marks `uncovered`, logs in `agentNotes`, continues with remaining ACs
- Does not escalate for a single ambiguous AC — only escalates if >50% of ACs are uncovered

### Green Agent
- If tests still fail after implementation: retries implementation once (internal attempt)
- After 2 internal attempts: sets `tdd.phase = "red"`, logs blocker in `agentNotes`,
  returns control — does not escalate directly, lets orchestrator handle
- Never modifies tests to make them pass

### Blue Agent
- If a refactor breaks tests: reverts that specific change immediately, logs it,
  continues with remaining refactors
- If type errors cannot be resolved without behaviour change: leaves `// TODO:` comment,
  logs in `agentNotes`, continues — does not block on type errors alone
- If lint fails: fixes lint errors before proceeding — lint is not optional

### QA Orchestrator
- If e2e environment fails to start: logs `external_service_error`, retries once,
  then runs unit tests only — does not skip QA entirely
- If Playwright is unavailable: runs unit + AC coverage checks only, flags
  `e2e_skipped` in agentNotes, does not block merge for e2e infrastructure failure
- If a defect origin is unclear: defaults to `current_ticket` (safer — blocks
  current ticket rather than shipping a known defect)
- Increments `qaRuns` at start of every run — never bypasses the counter

---

## Degraded mode catalogue

When full operation isn't possible, agents continue in degraded mode and
flag the degradation clearly. The pipeline never silently degrades.

| Condition | Degraded behaviour | Flag in |
|---|---|---|
| Figma MCP unavailable | Continue with empty figmaNodes | `agentNotes`, `warn` event |
| Figma node partial | Use available data, mark partial | `agentNotes`, `warn` event |
| e2e runner unavailable | Unit + AC coverage only | `agentNotes`, `warn` event, PR description |
| A11y tool unavailable | Skip a11y checks, flag for human | `agentNotes`, `warn` event, PR description |
| AC ambiguous | Mark uncovered, flag for BA | `acCoverage.uncovered`, `agentNotes` |
| Lint warnings (not errors) | Continue, surface in PR | PR description |
| Coverage decreased slightly | Warn, do not block | `warn` event, PR description |
| Regression ticket creation fails | Log full defect in agentNotes + PR comment | `agentNotes`, `error` event |

---

## Escalation format

When a fatal event is written and the pipeline halts, the orchestrator
must post this comment on the PR (creating a draft PR if none exists):

```
🚨 Pipeline — Escalation Required

**Spec:** SPEC-NNN — [title]
**Pipeline run:** [pipelineRun ID]
**Halted at:** [phase] — [agent]
**Reason:** [event type] — [detail]
**Recoverable:** No — human input required

**What was attempted:**
[Summary of audit log entries for this run]

**Last known good state:**
Checkpoint: [checkpointRef] at [moment]

**Suggested next step:**
[Agent's best diagnosis of what the human needs to do]

To resume after fixing: re-trigger the pipeline orchestrator for SPEC-NNN.
It will restore from checkpoint and continue from [phase].
```

---

## `handoff.json` integrity

Before any agent reads `handoff.json`, it must validate:

```
Required fields present: ticket.id, requirements.brs, requirements.acs,
                         branch.name, tdd.phase, audit (non-empty array)
Schema version matches: schemaVersion == "1.1.0"
No field is null that should not be: ticket.status, branch.base
audit array is valid JSON array
```

If validation fails:
1. Do not proceed with the corrupted handoff
2. Look for the most recent checkpoint in `.pipeline/checkpoints/`
3. Restore from checkpoint
4. Log `handoff_invalid` error event and `checkpoint_restored` info event
5. If no checkpoint exists, log `fatal` and escalate

---

## Preventing cascading failures

### Developer ↔ QA bounce loop
If the audit log shows the pattern `[developer complete → qa fail → developer complete → qa fail]`
repeating, the pipeline orchestrator detects it and escalates rather than
continuing. Detection condition: same defect ID appears in `defects` across
two or more QA runs.

### Regression amplification
If a defect fix from the developer agent causes new test failures that weren't
in the original `defects` list, the developer orchestrator logs
`regression_detected` and returns the full failure set to the pipeline
orchestrator rather than attempting a fix. The pipeline orchestrator escalates.

### Context drift
If `context.version` in `handoff.json` doesn't match the current
`context/vX.Y` git tag, the pipeline orchestrator logs a `warn` event
and re-reads context files before proceeding. It does not abort — stale
context is recoverable, but it must be noticed.
