# Skill: Eval Pipeline

**Type:** Atom
**Used by:** Pipeline Orchestrator (auto), Human (manual trigger)
**Trigger:**
- Auto: every 10 completed specs (pipeline orchestrator checks after `archive-spec`)
- Auto: on every epic completion
- Manual: human explicitly requests an eval run

---

## Purpose
Read `pipeline.log.ndjson` and all completed `handoff.json` histories,
compute performance metrics per agent and per phase, identify recurring
failure patterns, and produce two outputs:

1. `.agents/context/eval-report.md` — human-readable health report
2. `eval-signals.json` — structured signals for the Architect Agent's
   review mode to act on

This closes the improvement loop: the pipeline learns from its own
history and feeds that learning back into context updates.

---

## Inputs
```json
{
  "trigger": "auto | manual",
  "specRange": {
    "from": "SPEC-001",
    "to": "SPEC-010"
  },
  "logFile": "pipeline.log.ndjson",
  "checkpointDir": ".pipeline/checkpoints/",
  "doneDir": ".specs/done/"
}
```

If `specRange` is omitted, evaluate all specs in `.specs/done/`.

---

## Process

### Step 1 — Load the log

```bash
# Read all events, parse as NDJSON
ALL_EVENTS=$(cat pipeline.log.ndjson | grep -v "^{\"_comment")

# Filter to spec range if provided
if [ -n "$SPEC_FROM" ]; then
  SPEC_IDS=$(ls .specs/done/ | grep -oP 'SPEC-\d+' | sort)
  # Build list of spec IDs in range
fi
```

### Step 2 — Compute per-spec metrics

For each completed spec, extract from the log:

```bash
for SPEC in $SPEC_IDS; do
  # Pipeline duration
  START=$(echo "$ALL_EVENTS" | jq "select(.spec == \"$SPEC\" and .event == \"pipeline_started\") | .timestamp" | head -1)
  END=$(echo "$ALL_EVENTS" | jq "select(.spec == \"$SPEC\" and .event == \"pipeline_completed\") | .timestamp" | head -1)

  # Developer iterations used
  ITERATIONS=$(echo "$ALL_EVENTS" | jq "select(.spec == \"$SPEC\" and .agent == \"developer-orchestrator\" and .event == \"phase_started\") | .iteration" | sort -n | tail -1)

  # QA runs
  QA_RUNS=$(echo "$ALL_EVENTS" | jq "select(.spec == \"$SPEC\" and .agent == \"qa\" and .event == \"phase_started\") | .iteration" | wc -l)

  # DoD failures per phase
  RED_DOD_FAILS=$(echo "$ALL_EVENTS" | jq "select(.spec == \"$SPEC\" and .event == \"dod_failed\" and .phase == \"red\") | .detail" | wc -l)
  GREEN_DOD_FAILS=$(echo "$ALL_EVENTS" | jq "select(.spec == \"$SPEC\" and .event == \"dod_failed\" and .phase == \"green\") | .detail" | wc -l)
  BLUE_DOD_FAILS=$(echo "$ALL_EVENTS" | jq "select(.spec == \"$SPEC\" and .event == \"dod_failed\" and .phase == \"blue\") | .detail" | wc -l)

  # Escalations
  ESCALATED=$(echo "$ALL_EVENTS" | jq "select(.spec == \"$SPEC\" and .event == \"pipeline_escalated\") | .spec" | wc -l)

  # Defects found by QA
  DEFECTS=$(echo "$ALL_EVENTS" | jq "select(.spec == \"$SPEC\" and .event == \"defect_found\") | .detail" | wc -l)
  REGRESSIONS=$(echo "$ALL_EVENTS" | jq "select(.spec == \"$SPEC\" and .event == \"defect_found\" and .detail | contains(\"pre_existing\")) | .spec" | wc -l)

  # AC coverage gaps (uncovered ACs at Red completion)
  UNCOVERED=$(echo "$ALL_EVENTS" | jq "select(.spec == \"$SPEC\" and .event == \"phase_completed\" and .phase == \"red\") | .detail" | grep -oP 'uncovered:\K\d+' || echo 0)
done
```

### Step 3 — Compute aggregate metrics

```bash
# Across all specs in range:

# 1. First-pass rates (phase completed on iteration 0)
RED_FIRST_PASS_RATE   = specs where red completed with 0 DoD failures / total specs
GREEN_FIRST_PASS_RATE = specs where green completed on first attempt / total specs
BLUE_FIRST_PASS_RATE  = specs where blue completed on first attempt / total specs
QA_FIRST_PASS_RATE    = specs where QA passed on first run / total specs

# 2. Average iterations to green
AVG_ITERATIONS = sum(iterations per spec) / total specs

# 3. Escalation rate
ESCALATION_RATE = escalated specs / total specs

# 4. Most common DoD failure checks
# Tally all failedChecks arrays across all dod_failed events
DOD_FAILURE_FREQUENCY = {
  "R-3": 4,   # false positive tests — most common
  "G-4": 2,   # test files modified
  "B-3": 3,   # lint warnings
  ...
}

# 5. AC coverage gap rate
ACS_UNCOVERED_RATE = specs with any uncovered ACs / total specs

# 6. Regression rate
REGRESSION_RATE = specs that triggered a regression ticket / total specs

# 7. Average pipeline duration (minutes)
AVG_DURATION = sum(end - start per spec) / total specs
```

### Step 4 — Identify patterns

Patterns are the actionable insights. Look for:

```bash
# Pattern 1: Recurring DoD check failures
# If any single check fails in >30% of specs → surface as signal
for CHECK in R-1 R-2 R-3 R-4 R-5 R-6 G-1 G-2 G-3 G-4 G-5 G-6 B-1 B-2 B-3 B-4 B-5 B-6 B-7; do
  FAIL_RATE = failures_of_check / total_specs
  if [ "$FAIL_RATE" -gt 30 ]; then
    add_signal "recurring_dod_failure" "$CHECK" "$FAIL_RATE"
  fi
done

# Pattern 2: ACs consistently uncovered
# If same AC phrasing pattern appears in uncovered lists across specs
# → BA agent is writing untestable ACs
UNTESTABLE_AC_PATTERN=$(grep across uncovered lists for common patterns)

# Pattern 3: Escalation clustering
# If escalations cluster in one epic or one phase
# → That epic's specs may need BA clarification

# Pattern 4: Green agent repeatedly failing G-4 (test modification)
# → Green agent instructions need strengthening

# Pattern 5: QA consistently finding design fidelity issues
# → Figma nodes may be incomplete or fetch-figma-nodes is losing data

# Pattern 6: High regression rate in a specific epic
# → That epic's code may be touching shared code without awareness
```

### Step 5 — Write eval-signals.json

```json
{
  "generatedAt": "ISO8601",
  "trigger": "auto | manual",
  "specRange": { "from": "SPEC-001", "to": "SPEC-010" },
  "totalSpecs": 10,

  "summary": {
    "redFirstPassRate": 0.7,
    "greenFirstPassRate": 0.8,
    "blueFirstPassRate": 0.9,
    "qaFirstPassRate": 0.6,
    "avgIterationsToGreen": 1.4,
    "escalationRate": 0.1,
    "avgDurationMinutes": 28,
    "acUncoveredRate": 0.2,
    "regressionRate": 0.1
  },

  "dodFailureFrequency": [
    { "check": "R-3", "failures": 4, "rate": 0.4, "description": "False positive tests" },
    { "check": "B-3", "failures": 3, "rate": 0.3, "description": "Lint warnings not cleared" },
    { "check": "G-4", "failures": 2, "rate": 0.2, "description": "Test files modified during Green" }
  ],

  "patterns": [
    {
      "id": "PAT-001",
      "type": "recurring_dod_failure",
      "severity": "high",
      "check": "R-3",
      "rate": 0.4,
      "description": "Red agent produces false positive tests in 40% of specs",
      "suggestedAction": "Strengthen Red agent instructions on assertion specificity. Consider adding examples of tight vs loose assertions to context.",
      "targetAgent": "red",
      "targetFile": ".agents/agents/developer/red.md"
    },
    {
      "id": "PAT-002",
      "type": "untestable_acs",
      "severity": "medium",
      "rate": 0.2,
      "description": "20% of specs have at least one uncovered AC after Red phase",
      "suggestedAction": "BA agent AC format may need tightening. Review uncovered ACs for Given/When/Then compliance.",
      "targetAgent": "ba",
      "targetFile": ".agents/agents/ba.md"
    },
    {
      "id": "PAT-003",
      "type": "qa_design_fidelity",
      "severity": "low",
      "rate": 0.3,
      "description": "QA finds minor design fidelity issues in 30% of specs",
      "suggestedAction": "Verify fetch-figma-nodes is returning complete token data. Check if Figma MCP partial flag is being set silently.",
      "targetAgent": "pipeline-orchestrator",
      "targetFile": ".agents/skills/atoms/fetch-figma-nodes.md"
    }
  ],

  "archiveTrigger": {
    "architectReviewRecommended": true,
    "reason": "escalationRate > 0.1 and redFirstPassRate < 0.8",
    "priority": "high | medium | low"
  }
}
```

### Step 6 — Write eval-report.md

Write to `.agents/context/eval-report.md`.
This file is overwritten on every eval run — it always reflects the
most recent evaluation window.

See the eval-report.md template for the exact format.

### Step 7 — Commit both outputs

```bash
git checkout develop
git add .agents/context/eval-report.md
git add .agents/context/eval-signals.json  # if storing signals in repo
git commit -m "chore(eval): pipeline eval — SPEC-001 through SPEC-010"
git push origin develop
```

Log a `pipeline_eval_complete` info event to `pipeline.log.ndjson`.

### Step 8 — Notify architect if review recommended

If `archiveTrigger.architectReviewRecommended == true`:
- Append to `.agents/context/CHANGELOG.md`:
  ```
  ## [DATE] — Eval recommends architect review
  Trigger: [reason]
  Priority: [high | medium | low]
  See: eval-report.md for full details
  ```
- If auto-triggered: log `warn` event suggesting human trigger architect review
- If manual: surface recommendation directly in response

---

## Output

```json
{
  "evalComplete": true,
  "specCount": 10,
  "reportPath": ".agents/context/eval-report.md",
  "signalsPath": ".agents/context/eval-signals.json",
  "architectReviewRecommended": true,
  "topPattern": "PAT-001 — Red agent false positives (40% rate)",
  "logEvent": "pipeline_eval_complete"
}
```

---

## Rules
- Never modify `pipeline.log.ndjson` — read only
- Never modify spec files in `.specs/done/` — read only
- Always overwrite `eval-report.md` — do not append
- If fewer than 3 specs are in the range, produce the report but
  note that sample size is too small for reliable patterns
- Rates below 10% are noise — do not surface as patterns
- Rates above 30% are signals — always surface
- Rates 10–30% are observations — surface in the report but do not
  recommend architect action unless they cluster in one phase or epic
