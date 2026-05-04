# Skill: Run E2E Tests

**Type:** Atom  
**Used by:** QA Orchestrator  
**Trigger:** Step 3a of QA process — functional AC validation

---

## Purpose
Execute end-to-end tests against the feature branch using Playwright (or
the configured e2e runner), capture structured results, and return a
pass/fail summary with actionable failure details.

---

## Inputs
- List of ACs to validate (from `handoff.json > requirements.acs`)
- Figma node specs for visual reference (from `handoff.json > design.figmaNodes`)
- Branch under test (from `handoff.json > branch.name`)

---

## Process

### Step 1 — Confirm environment
Before running tests, verify:
- [ ] Dev server is running or can be started: `[DEV_SERVER_COMMAND]`
- [ ] E2E config points to the correct base URL: `[E2E_BASE_URL]`
- [ ] Test database / mock server is seeded if required: `[SEED_COMMAND]`

If environment setup fails, return a structured error — do not attempt to run tests.

### Step 2 — Run e2e suite
```bash
[E2E_COMMAND]
```

Capture:
- Exit code
- Full stdout/stderr output
- Individual test results (pass/fail/skip per test name)
- Screenshots on failure (Playwright captures these automatically if configured)
- Video recordings if enabled

### Step 3 — Map results to ACs
For each AC in the inputs:
- Find the e2e test(s) that cover it (by test name convention: `AC-N:` prefix)
- Record: covered / not covered / failing

### Step 4 — Return structured results

```json
{
  "status": "pass | fail | error",
  "summary": {
    "total": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0
  },
  "acCoverage": [
    {
      "ac": "AC-1: User sees error on empty submit",
      "status": "pass | fail | no_test",
      "testName": "AC-1: shows error message when input is empty on submit",
      "failureReason": null
    }
  ],
  "failures": [
    {
      "testName": "...",
      "error": "...",
      "screenshotPath": "...",
      "affectedFiles": []
    }
  ],
  "rawOutput": "..."
}
```

---

## Rules
- Never mark an AC as "pass" if its test was skipped
- If the dev server fails to start, return `status: "error"` — not `"fail"`
- Screenshot paths must be relative to the repo root so they can be attached to PR comments
- If no e2e tests exist for a given AC, that is a coverage gap — mark it `"no_test"` and surface it to the QA Orchestrator
