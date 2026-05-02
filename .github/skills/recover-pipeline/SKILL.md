---
name: recover-pipeline
description: >
  Diagnose and recover a broken or interrupted pipeline run. Use when a pipeline
  is in an unknown, halted, or corrupt state. Reads pipeline.log.ndjson and
  handoff.json to produce a diagnosis and recovery proposal. Always presents
  findings before taking any action.
---

# Recover Pipeline

Diagnose the current state of a broken pipeline run and propose the safest recovery path.

## Inputs
Either provide:
- `specId` — e.g. "SPEC-001"
- Or nothing — diagnose the most recently active spec (last `pipeline_started` with no `pipeline_completed`)

## Step 1 — Read the log
```bash
jq 'select(.spec == "SPEC-001")' pipeline.log.ndjson | jq -s 'sort_by(.timestamp) | reverse'
```
Build a timeline: when did the run start, what was the last successful event, what failed, what is the last known state?

## Step 2 — Read handoff.json from feature branch
```bash
git fetch origin
git show origin/feature/SPEC-001-slug:handoff.json 2>/dev/null || echo "NOT FOUND"
```
Record: `tdd.phase`, `ticket.status`, `tdd.loop.iteration`, `qaRuns`, last audit entry.

## Step 3 — Find the last valid checkpoint
```bash
ls -t .pipeline/checkpoints/SPEC-001-*.json | head -5
```
For each checkpoint (newest first):
- Verify valid JSON
- Verify `handoff` snapshot is present
- Verify `commitSha` exists in git: `git cat-file -e <sha> && echo "exists"`
Use the first checkpoint that passes all checks.

## Step 4 — Produce diagnosis

```
DIAGNOSIS REPORT
─────────────────────────────────────
Spec:          SPEC-001 — [title]
Pipeline run:  SPEC-001-[timestamp]
Started:       [ISO8601]
Halted:        [ISO8601]

Last good state:
  Checkpoint: .pipeline/checkpoints/SPEC-001-[hash].json
  Moment:     [tests_passing | refactor_complete | etc.]
  Commit:     [sha] — [exists ✓ | NOT FOUND ✗]

Failure:
  Event:      [event type]
  Agent:      [agent name]
  Detail:     [human-readable description]
  Recoverable: [yes | no]

Current handoff:
  tdd.phase:     [phase]
  ticket.status: [status]
  iteration:     [N] / [maxIterations]
  Relevant agentNotes: [last 5 lines]
─────────────────────────────────────
```

## Step 5 — Recovery proposal

**Option A — Auto-resume** (transient failure, valid checkpoint)
→ Restore checkpoint and continue. Safe to execute automatically.

**Option B — Restore and retry** (invalid handoff but valid checkpoint, iteration under limit)
→ Restore checkpoint, reset phase, give agent a fresh attempt.

**Option C — Human input needed** (genuine blocker: TS error, ambiguous AC, design mismatch)
→ Describe exactly what the human needs to do, then how to resume.

**Option D — Start fresh** (no valid checkpoint, cascading failures)
→ Close PR, delete branch, move spec back to active/, re-trigger pipeline.

## Step 6 — Execute (if authorised)
- Options A and B: execute automatically if invoked by pipeline orchestrator
- Options A and B: wait for human confirmation if invoked by human
- Options C and D: ALWAYS wait for human confirmation regardless of who invoked

## Rules
- Never delete a checkpoint file during diagnosis
- Never force-push to the feature branch
- Never move a spec back to active/ without explicit human confirmation
- Always present the full diagnosis before proposing action
- If pipeline.log.ndjson is missing or corrupt → treat as Option D
