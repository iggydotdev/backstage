# Skill: Recover Pipeline

**Type:** Atom
**Used by:** Human-triggered, or Pipeline Orchestrator on resume
**Trigger:** A pipeline run is in an unknown, halted, or corrupt state

---

## Purpose
Diagnose the current state of a broken or interrupted pipeline run,
restore to the last known good checkpoint, and propose the safest
path to resume — or explain clearly why human intervention is needed.

---

## Inputs
Either:
- `specId` — the spec to diagnose (e.g. `"SPEC-001"`)
- `pipelineRun` — a specific run ID to diagnose (e.g. `"SPEC-001-20260418T103200"`)

If neither is provided, diagnose the most recently active spec
(last `pipeline_started` event in the log with no corresponding `pipeline_completed`).

---

## Process

### Step 1 — Read the log
```bash
# Get all events for this spec, newest first
jq 'select(.spec == "SPEC-001")' pipeline.log.ndjson \
  | jq -s 'sort_by(.timestamp) | reverse'
```

Build a timeline:
- When did the run start?
- What was the last successful event?
- What was the first error or fatal event?
- What is the last known state?

### Step 2 — Read the current handoff.json
Checkout or read the feature branch:
```bash
git fetch origin
git show origin/feature/SPEC-001-slug:handoff.json 2>/dev/null || echo "NOT FOUND"
```

Validate `handoff.json` per the validation rules in `skills/error-handling.md`.

Record:
- `tdd.phase`
- `ticket.status`
- `tdd.loop.iteration`
- `qaRuns`
- Last `audit` entry

### Step 3 — Find the last valid checkpoint
```bash
ls -t .pipeline/checkpoints/SPEC-001-*.json | head -5
```

For each checkpoint (newest first):
- Parse the file
- Verify it is valid JSON
- Verify `handoff.snapshot` is present and passes validation
- Verify the `commitSha` still exists in git history:
  ```bash
  git cat-file -e <commitSha> && echo "exists"
  ```
- Use the first checkpoint that passes all checks

### Step 4 — Diagnose the failure
Classify the failure using the event log:

```
DIAGNOSIS REPORT
─────────────────────────────────────────
Spec:          SPEC-001 — Login form component
Pipeline run:  SPEC-001-20260418T103200
Started:       2026-04-18T10:32:00Z
Halted:        2026-04-18T11:14:22Z (42 min into run)

Last good state:
  Event:     tests_passing (green phase complete)
  Checkpoint: .pipeline/checkpoints/SPEC-001-abc123.json
  Commit:    abc123def (exists ✓)
  handoff:   valid ✓

Failure:
  Event:     loop_limit_reached
  Agent:     developer-orchestrator
  Phase:     blue
  Detail:    "TypeScript error in Button.tsx cannot be resolved
              without changing component interface"
  Recoverable: false

Current handoff state:
  tdd.phase:      blue
  ticket.status:  blocked
  iteration:      3 / 3
  agentNotes:     [blue]: TS error: Property 'onClick' is missing
                  in type ... See Button.tsx:42

Branch:        feature/SPEC-001-login-form-component (exists ✓)
PR:            https://github.com/.../pull/12 (draft, needs-human-review label)
─────────────────────────────────────────
```

### Step 5 — Propose recovery action

Based on the diagnosis, output one of these recovery proposals:

#### Option A — Safe to auto-resume
Condition: last event was transient (network, timeout) and checkpoint is valid.

```
RECOVERY PROPOSAL: Auto-resume
─────────────────────────────────────────
The failure was transient. The pipeline can resume safely.

Action: Restore from checkpoint SPEC-001-abc123 and re-run from
        the blue phase.

To proceed:
  Re-trigger the pipeline orchestrator for SPEC-001.
  It will restore the checkpoint automatically and continue.
─────────────────────────────────────────
```

#### Option B — Resume from checkpoint with reset
Condition: current `handoff.json` is invalid but checkpoint is valid.
Phase iteration count is under the limit.

```
RECOVERY PROPOSAL: Restore checkpoint and retry
─────────────────────────────────────────
The current handoff.json is invalid. The last valid checkpoint
was at: tests_passing (green phase complete).

Action: Restore SPEC-001-abc123.json as handoff.json,
        reset tdd.phase to "blue", reset iteration to 0,
        and re-invoke the developer orchestrator.

This restores the passing test state and gives the blue agent
a fresh attempt at refactoring.

To proceed:
  Re-trigger the pipeline orchestrator for SPEC-001.
  Confirm you want to restore from checkpoint abc123.
─────────────────────────────────────────
```

#### Option C — Human input required, then resume
Condition: failure is a genuine blocker (TS error, ambiguous AC, design mismatch)
that the agent cannot resolve alone.

```
RECOVERY PROPOSAL: Human fix needed, then resume
─────────────────────────────────────────
The pipeline halted because: [specific reason from agentNotes]

What you need to do:
  [Specific human action — e.g. "Clarify whether onClick is a required
   prop on ButtonPrimary — see Figma variant 'interactive'.
   Update the spec AC-3 if the behaviour should change."]

After fixing:
  Option 1 — If the spec changed: update SPEC-001.md, then
             re-trigger the pipeline orchestrator. It will restart
             from the handoff_initialised checkpoint.

  Option 2 — If only the code needs a fix: push your fix to
             feature/SPEC-001-login-form-component, then
             re-trigger the pipeline orchestrator. It will
             resume from the pr_approved checkpoint.
─────────────────────────────────────────
```

#### Option D — Unrecoverable, start fresh
Condition: no valid checkpoint, branch in unknown state, or multiple
cascading failures with no clear root cause.

```
RECOVERY PROPOSAL: Abandon run and restart
─────────────────────────────────────────
No valid checkpoint was found and the current run state is
inconsistent. Attempting to resume risks propagating bad state.

Recommended action:
  1. Close PR #12 (do not merge)
  2. Delete branch: git push origin --delete feature/SPEC-001-login-form-component
  3. Move SPEC-001 back to .specs/active/ if it was modified
  4. Re-trigger the pipeline orchestrator for a fresh run

Root cause to investigate before restarting:
  [Summary of what went wrong based on the log]
─────────────────────────────────────────
```

### Step 6 — Execute if authorised
If this skill was invoked by the pipeline orchestrator (automated recovery),
execute Option A or B without waiting for human confirmation.

If this skill was invoked by a human, present the proposal and wait for
explicit confirmation before taking any action.

For Option C and D — always wait for human confirmation regardless of
who invoked the skill.

---

## Output
```json
{
  "spec": "SPEC-001",
  "pipelineRun": "SPEC-001-20260418T103200",
  "diagnosedAt": "ISO8601",
  "lastGoodCheckpoint": "SPEC-001-abc123",
  "lastGoodMoment": "tests_passing",
  "failureClass": "1 | 2 | 3 | 4",
  "failureEvent": "loop_limit_reached",
  "recoveryOption": "A | B | C | D",
  "humanInputRequired": false,
  "proposedAction": "...",
  "executed": false
}
```

---

## Rules
- Never delete a checkpoint file during diagnosis
- Never force-push to the feature branch
- Never move a spec back to `active/` without explicit human confirmation
- If the log file itself is corrupt or missing, treat it as Option D
- Always present the full diagnosis before proposing action —
  never silently mutate state during diagnosis
