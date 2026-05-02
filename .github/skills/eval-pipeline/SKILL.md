---
name: eval-pipeline
description: >
  Run a pipeline performance evaluation every 10 completed specs or when an epic
  completes. Analyses iteration counts, DoD failure rates, escalation frequency,
  and QA defect patterns. Produces a structured report and recommendations for
  improving the pipeline. Never blocks the pipeline — runs as a background task.
---

# Eval Pipeline

Evaluate pipeline performance and produce improvement recommendations.

## When to run
- Every 10th spec moved to `.specs/done/`
- When an epic is marked `complete`
- When explicitly invoked by the pipeline orchestrator after a difficult run

## Data sources

```bash
# All completed handoff.json snapshots (from done/ specs)
ls .specs/done/

# Full pipeline event log
cat pipeline.log.ndjson | jq -s '.'

# All checkpoint files
ls .pipeline/checkpoints/
```

## Metrics to compute

### Iteration health
```
For each completed spec:
  red_iterations  = count phase_started events where phase="red"
  green_iterations = count phase_started events where phase="green"
  blue_iterations = count phase_started events where phase="blue"

averages across window:
  avg_red_iterations   (target: < 1.3)
  avg_green_iterations (target: < 1.5)
  avg_blue_iterations  (target: < 1.2)
```

### DoD failure rate
```
dod_failures = count "dod_failed" events
dod_checks   = count "dod_checked" events
failure_rate = dod_failures / dod_checks

target: < 20%
by phase: identify which phase has the worst rate
```

### Escalation rate
```
escalations = count "escalation" events
specs_run   = count "pipeline_started" events
escalation_rate = escalations / specs_run

target: < 10%
```

### QA defect patterns
```
from all defects across completed specs:
  by type:   new_code | regression | design_fidelity | accessibility | missing_ac_coverage
  by origin: current_ticket | pre_existing
  by severity: critical | high | medium | low

top_defect_types = sort by frequency, take top 3
```

### Cycle time
```
For each spec:
  cycle_time = pipeline_completed.timestamp - pipeline_started.timestamp
avg_cycle_time (target: context-dependent, record trend over time)
```

## Output format

Write to `.agents/eval/eval-YYYYMMDD-HHMMSS.json`:

```json
{
  "evaluatedAt": "ISO8601",
  "window": {
    "fromSpec": "SPEC-001",
    "toSpec": "SPEC-010",
    "specsAnalysed": 10
  },
  "metrics": {
    "avgIterations": {
      "red": 1.2,
      "green": 1.4,
      "blue": 1.1
    },
    "dodFailureRate": 0.18,
    "escalationRate": 0.05,
    "avgCycleTimeMinutes": 45,
    "topDefectTypes": ["design_fidelity", "missing_ac_coverage", "accessibility"]
  },
  "flags": [
    {
      "severity": "warn | info",
      "metric": "dodFailureRate",
      "value": 0.32,
      "threshold": 0.20,
      "message": "DoD failure rate above threshold — Red agent writing false positive tests"
    }
  ],
  "recommendations": [
    {
      "priority": 1,
      "area": "red-agent",
      "finding": "32% DoD failure rate on R-3 (false positive tests)",
      "recommendation": "Add assertion specificity guidelines to Red agent instructions — tests passing without implementation are a recurring pattern",
      "evidenceSpecs": ["SPEC-003", "SPEC-007"]
    }
  ],
  "trend": {
    "dodFailureRate": "increasing",
    "cycleTime": "stable",
    "escalationRate": "decreasing"
  }
}
```

## Rules
- Never halt the pipeline — if eval fails, log the error and continue
- Never modify agent files based on eval findings — surface recommendations only
- Only a human acts on recommendations
- Archive older eval files after 30 reports — move to `.agents/eval/archive/`
- Trend is computed only if 3+ eval reports exist

## After writing the report
Append to `pipeline.log.ndjson`:
```json
{"event": "eval_completed", "severity": "info", "reportPath": ".agents/eval/eval-*.json", "flags": N, "recommendations": N}
```
