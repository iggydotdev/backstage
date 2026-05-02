---
name: run-e2e-tests
description: >
  Execute end-to-end tests against the feature branch using the configured e2e runner
  (Playwright or equivalent). Returns structured pass/fail results mapped to ACs.
  Use during QA phase Step 3a. Reports coverage gaps if any AC has no e2e test.
---

# Run E2E Tests

Execute the e2e test suite and return structured results mapped to acceptance criteria.

## Inputs needed
Read from `handoff.json`:
- `requirements.acs` — list of ACs to validate
- `design.figmaNodes` — visual reference
- `branch.name` — branch under test
- `contextSlice.testingCommands.e2eCommand` — the e2e command to run

## Step 1 — Confirm environment
Before running tests, verify:
- Dev server is running or can be started
- E2E config points to the correct base URL
- Test database / mock server is seeded if required

If environment setup fails → return `status: "error"`. Do not attempt to run tests.

## Step 2 — Run the e2e suite
```bash
# Run the e2e command from contextSlice
pnpm test:e2e  # or whatever is configured
```

Capture:
- Exit code
- Full stdout/stderr output
- Individual test results (pass/fail/skip per test name)
- Screenshot paths on failure (Playwright captures automatically if configured)

## Step 3 — Map results to ACs
For each AC in `requirements.acs`:
- Find e2e test(s) covering it — by test name convention: `AC-N:` prefix expected
- Record: `covered | not_covered | failing`

## Step 4 — Return structured results

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
  ]
}
```

## Rules
- Never mark an AC as "pass" if its test was skipped
- If dev server fails to start → `status: "error"` (not "fail")
- Screenshot paths must be relative to repo root
- ACs with no e2e test → mark `"no_test"` and surface as coverage gap
- If e2e runner is unavailable → report `status: "error"` with clear message; QA orchestrator will handle graceful degradation
