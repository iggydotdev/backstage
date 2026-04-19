# Observability Contract

Every agent in this pipeline follows this contract for logging and
checkpointing. This document is referenced by all agent files — it
is not optional.

---

## Two outputs every agent writes

### 1. Events → `pipeline.log.ndjson`
Located at repo root. Append-only. Never rewrite or truncate.
One JSON object per line. Committed to `develop` after every agent run.

### 2. Checkpoints → `.pipeline/checkpoints/`
A snapshot of `handoff.json` at key moments.
Written by the pipeline orchestrator only — not sub-agents.
Sub-agents signal that a checkpoint should be taken via a `checkpoint_requested`
event. The orchestrator acts on it.

---

## Event schema

Every event written to `pipeline.log.ndjson` must conform to this shape:

```json
{
  "timestamp": "ISO8601",
  "pipelineRun": "SPEC-001-20260418T103200",
  "spec": "SPEC-001",
  "feature": "FEAT-001",
  "epic": "EPIC-001",
  "agent": "pipeline-orchestrator | architect | ba | onboarding | developer-orchestrator | red | green | blue | qa",
  "phase": "init | red | green | blue | pr | review | qa | merge | archive",
  "event": "<event_type>",
  "severity": "info | warn | error | fatal",
  "iteration": 0,
  "detail": "Human-readable description of what happened",
  "recoverable": true,
  "checkpointRef": "abc123def456 | null",
  "durationMs": 0
}
```

### Required fields
`timestamp`, `pipelineRun`, `spec`, `agent`, `phase`, `event`, `severity`,
`recoverable`

### Optional fields
`feature`, `epic`, `iteration`, `detail`, `checkpointRef`, `durationMs`

### `pipelineRun` format
`{specId}-{ISO8601 timestamp of run start, compact}`
e.g. `SPEC-001-20260418T103200`

This uniquely identifies a run. If the same spec is retried, it gets a
new `pipelineRun` ID. The log keeps all runs — history is never erased.

---

## Event types

### Lifecycle events (severity: info)
| Event | When |
|---|---|
| `pipeline_started` | Pipeline orchestrator picks up a spec |
| `pipeline_completed` | Spec fully merged and archived |
| `phase_started` | Agent begins its phase |
| `phase_completed` | Agent completes its phase successfully |
| `dod_checked` | check-dod ran and all checks passed |
| `dod_failed` | check-dod ran and one or more checks failed |
| `checkpoint_written` | Orchestrator writes a checkpoint |
| `checkpoint_restored` | Orchestrator restores from checkpoint |
| `pr_opened` | Draft PR created |
| `pr_approved` | Human approves PR |
| `pr_changes_requested` | Human requests changes |
| `merge_completed` | Branch merged to develop |
| `spec_archived` | Spec moved to done/ |
| `pipeline_eval_complete` | eval-pipeline atom completed a run |
| `architect_review_recommended` | eval signals recommend architect review |

### Warning events (severity: warn)
| Event | When |
|---|---|
| `figma_partial` | Figma MCP returned partial data |
| `figma_unavailable` | Figma MCP entirely unreachable |
| `ac_uncovered` | An AC has no corresponding test |
| `coverage_decreased` | Test coverage dropped vs base |
| `lint_warnings` | Lint passed with warnings |
| `dependency_unmet` | Spec dependency not yet in done/ |
| `retry_attempted` | Agent retrying after transient failure |

### Error events (severity: error)
| Event | When |
|---|---|
| `phase_failed` | Agent failed its phase, will retry |
| `tests_failing` | Test run produced failures |
| `regression_detected` | Existing tests broken by new code |
| `external_service_error` | MCP or git remote call failed |
| `handoff_invalid` | handoff.json failed validation |
| `spec_invalid` | Spec file missing required fields |
| `defect_found` | QA found a defect |
| `loop_limit_reached` | Max iterations hit before completion |
| `qa_limit_reached` | Max QA runs hit before completion |

### Fatal events (severity: fatal)
| Event | When |
|---|---|
| `pipeline_escalated` | Human intervention required, pipeline halted |
| `context_missing` | context/v1.0 tag or required context files absent |
| `branch_conflict` | Git conflict cannot be auto-resolved |
| `checkpoint_corrupt` | Checkpoint file unreadable or invalid |

---

## Severity and recoverability matrix

| Severity | `recoverable` | Pipeline behaviour |
|---|---|---|
| `info` | `true` | Continue normally |
| `warn` | `true` | Log, continue, surface in PR description |
| `error` | `true` | Retry per retry policy, then escalate if exhausted |
| `error` | `false` | Halt this phase, restore checkpoint, escalate |
| `fatal` | `false` | Halt pipeline, notify human, do not retry |

---

## Retry policy

When an `error` event is `recoverable: true`, agents apply this policy
before declaring failure:

| Failure type | Max retries | Backoff |
|---|---|---|
| External service (Figma, git remote) | 3 | 2s, 5s, 15s |
| Test run failure | 0 (handled by TDD loop iterations) | — |
| Handoff commit failure | 2 | 3s, 10s |
| Branch creation failure | 2 | 2s, 5s |

After max retries are exhausted:
- Write `recoverable: false` error event
- Write `pipeline_escalated` fatal event
- Halt and notify human

---

## How to write an event

Every agent appends events using this pattern:

```bash
echo '{"timestamp":"...","pipelineRun":"...","spec":"...","agent":"...","phase":"...","event":"...","severity":"...","recoverable":true,"detail":"..."}' \
  >> pipeline.log.ndjson
```

After every agent run (success or failure), commit the log:
```bash
git add pipeline.log.ndjson
git commit -m "log(agent-name): SPEC-NNN — event description"
git push origin develop
```

The log is always committed to `develop`, not to the feature branch.
The `handoff.json` stays on the feature branch. They are separate concerns.

---

## Checkpoint moments

The pipeline orchestrator writes a checkpoint after each of these events:

| Checkpoint | After |
|---|---|
| `branch_created` | Branch exists, clean state |
| `handoff_initialised` | handoff.json committed, ready for developer |
| `tests_passing` | All tests green (end of green phase) |
| `refactor_complete` | Blue phase done, all checks pass |
| `pr_approved` | Human sign-off received |
| `qa_passed` | QA passed, ready to merge |

### Checkpoint format
Filename: `.pipeline/checkpoints/{specId}-{shortHash}.json`

```json
{
  "checkpointId": "abc123def456",
  "pipelineRun": "SPEC-001-20260418T103200",
  "spec": "SPEC-001",
  "timestamp": "ISO8601",
  "moment": "tests_passing",
  "handoff": { ... full handoff.json snapshot ... },
  "branch": "feature/SPEC-001-login-form-component",
  "commitSha": "abc123..."
}
```

Checkpoints are never deleted during a pipeline run.
After a successful merge they may be pruned (keep last 3 per spec).

---

## Reading the log

Useful queries (requires `jq`):

```bash
# All errors across all specs
jq 'select(.severity == "error" or .severity == "fatal")' pipeline.log.ndjson

# Full history for a specific spec
jq 'select(.spec == "SPEC-001")' pipeline.log.ndjson

# All fatal escalations
jq 'select(.event == "pipeline_escalated")' pipeline.log.ndjson

# Current status of all specs (last event per spec)
jq -s 'group_by(.spec) | map(sort_by(.timestamp) | last)' pipeline.log.ndjson

# Everything from a specific pipeline run
jq 'select(.pipelineRun == "SPEC-001-20260418T103200")' pipeline.log.ndjson

# Warn+ events in the last 24 hours
jq 'select(.severity != "info") | select(.timestamp > "2026-04-17T00:00:00Z")' \
  pipeline.log.ndjson
```
