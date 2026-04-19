# .pipeline/checkpoints/

Pipeline orchestrator writes handoff.json snapshots here at key moments.
Used by the recover-pipeline skill to restore a known good state.

## Format
Filename: `{specId}-{shortHash}.json`
e.g. `SPEC-001-abc123def.json`

## Contents
Each file is a full checkpoint object — see `skills/observability.md`
for the checkpoint schema.

## Retention
- Kept during active pipeline runs
- After successful merge: keep last 3 checkpoints per spec, prune the rest
- After a spec is archived to done/: may be pruned entirely

## Rules
- Never manually edit checkpoint files
- Never delete checkpoints during an active pipeline run
- This directory is committed to `develop`
