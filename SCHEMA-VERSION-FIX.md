# Schema Version Fix

## Problem
`build-handoff.md` (and any existing handoff construction code) was setting
`schemaVersion: "1.0.0"` while `schema.md` defines the current version as `1.4.0`.

This causes silent schema mismatch on every pipeline run — agents write an
invalid handoff that does not match the schema contract other agents read.

## Fix
In your existing repo, find and update every occurrence of the schema version string.

### In `.agents/skills/atoms/build-handoff.md` (old path)
### In `.agents/atoms/build-handoff.md` (new path after rename)
### In `.github/skills/build-handoff/SKILL.md` (this file replaces both)

The new `build-handoff` SKILL.md in this zip already uses `"schemaVersion": "1.4.0"`.

### In any existing `handoff.json` file on feature branches
```bash
# Find any live handoff.json files with wrong version
grep -r '"schemaVersion": "1.0.0"' . --include="handoff.json"

# For each found file, update it
# (do this on the feature branch it lives on)
sed -i 's/"schemaVersion": "1.0.0"/"schemaVersion": "1.4.0"/' handoff.json
git add handoff.json
git commit -m "fix(pipeline): correct schemaVersion to 1.4.0"
```

### In `schema.md` — confirm the canonical version
The canonical version in `.agents/handoff/schema.md` should read:
```
Current version: 1.4.0
```
No change needed if it already says 1.4.0.

## Verify the fix
After applying:
```bash
grep -r "schemaVersion" . --include="*.md" --include="*.json" | grep -v node_modules
```
All results should show `1.4.0`. Any `1.0.0` remaining is a bug.

## Going forward
The `build-handoff` SKILL.md in `.github/skills/build-handoff/SKILL.md` is now
the canonical source for handoff construction. The old atom file in `.agents/`
should either be deleted or updated to redirect to the skill.
