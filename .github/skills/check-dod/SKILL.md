---
name: check-dod
description: >
  Run binary Definition of Done checks for a TDD phase (red, green, blue, or qa).
  Use this when any sub-agent claims a phase is complete — before advancing.
  Returns pass/fail per check with recommended action. All checks are deterministic
  (git, shell, filesystem only — no LLM judgment). Never advance a phase without running this.
---

# Check Definition of Done

Run deterministic binary checks to verify a phase claim. Report every check explicitly.

## Inputs needed before running
Read `handoff.json` to get:
- `tdd.testResults` — last test run output
- `tdd.acCoverage` — covered/uncovered ACs
- `contextSlice.testingConventions.command` — test command
- `contextSlice.stack.lintCommand` — lint command
- `contextSlice.stack.typeCheckCommand` — type check command
- `requirements.acs` — list of ACs with their IDs
- For Blue phase: `GREEN_COMMIT` sha from `context.agentNotes`

---

## Red Phase Checks (R-1 through R-6)

**R-1** — Test files exist
```bash
find . -name "*.test.tsx" -o -name "*.test.ts" -o -name "*.spec.tsx" -o -name "*.spec.ts" \
  | grep -v node_modules | grep -v ".agents"
# PASS: count > 0 | FAIL: no test files found
```

**R-2** — All AC IDs referenced in tests
```bash
# For each AC-N in handoff.json > requirements.acs:
grep -r "AC-N" <test files>
# PASS: every AC ID found in at least one test | FAIL: list missing ACs
```

**R-3** — All new tests fail (not false positives)
```bash
# Run test command — exit code must be non-zero
# PASS: exit code non-zero (tests fail as expected)
# FAIL: any new test passes → FALSE POSITIVE → return_to_red, tighten assertions
# Ideal failure mode: "Cannot find module" / import errors
```

**R-4** — No existing tests broken
```bash
# Compare failing tests on feature branch vs develop
# PASS: only NEW tests appear in failure list
# FAIL: previously passing test now fails → REGRESSION → fix before proceeding
```

**R-5** — No implementation files created or modified
```bash
git diff develop --name-only | grep -v "\.test\.\|\.spec\.\|handoff\.json\|pipeline\.log"
# PASS: empty output
# FAIL: implementation files listed → RULE VIOLATION → escalate (do not retry)
```

**R-6** — acCoverage.uncovered is consistent with test files
```bash
# Each AC in tdd.acCoverage.uncovered should have NO test referencing it
# PASS: consistent | FAIL: uncovered AC has a test → tracking bug → fix coverage data
```

---

## Green Phase Checks (G-1 through G-6)

**G-1 + G-2** — All tests pass, zero failures
```bash
# Run test command — exit code 0, "failed: 0" in output
# FAIL → return_to_green
```

**G-3** — Coverage not decreased vs baseline
```bash
# Parse coverage from test output
# Current coverage >= baseline in handoff.json > tdd.testResults.coverage
# FAIL → implementation incomplete → return_to_green
```

**G-4** — No test files modified
```bash
git diff develop --name-only | grep "\.test\.\|\.spec\."
# PASS: empty output
# FAIL: test files listed → RULE VIOLATION → escalate immediately (do not retry)
```

**G-5** — All test imports resolve to existing files
```bash
# For each import in test files that references src/ or @/:
# Verify the target file exists
# FAIL: missing file → return_to_green
```

**G-6** — Lint has zero errors (warnings deferred to Blue)
```bash
# Run lint command — count error-level issues only
# PASS: zero errors (warnings allowed) | FAIL: errors found → return_to_green
```

---

## Blue Phase Checks (B-1 through B-7)

**B-1 + B-2** — Tests still pass, coverage maintained vs Green baseline
```bash
# Same as G-1/G-2/G-3 but vs GREEN_COMMIT baseline
# FAIL → revert last change, return_to_blue
```

**B-3** — Zero lint errors AND zero warnings
```bash
# Run lint — both errors and warnings must be 0
# FAIL → fix lint, do not escalate for lint alone
```

**B-4** — Zero type errors
```bash
# Run type check command
# If errors cannot be fixed without interface changes:
#   → add // TODO(blue): comment, log in agentNotes, pass with warn (B-4 deferred)
# Genuine fixable type errors: fix them, do not defer
```

**B-5** — No test files modified since Green commit
```bash
git diff <GREEN_COMMIT_SHA> --name-only | grep "\.test\.\|\.spec\."
# PASS: empty | FAIL → RULE VIOLATION → escalate
```

**B-6** — No files outside expected project structure
```bash
git diff develop --name-only --diff-filter=A
# All new files must be under src/, tests/, __tests__/ or .agents/, .specs/
# FAIL: unexpected location → flag to orchestrator
```

**B-7** — No public interfaces removed or renamed
```bash
git diff develop | grep "^-.*export "
# PASS: no removed exports | FAIL → escalate, requires human review
```

---

## QA Phase Checks (Q-1 through Q-7)

**Q-1** All unit tests pass on feature branch
**Q-2** All e2e tests pass
**Q-3** Every AC has a passing e2e test (AC-N in test name)
**Q-4** No regressions vs develop (compare full suite results)
**Q-5** Zero accessibility violations (WCAG AA)
**Q-6** Design fidelity confirmed (visual diff or Figma comparison — no critical mismatches)
**Q-7** No open current-ticket defects in `handoff.json > defects`

---

## Output format — always report this way

```
Checking DoD for phase: [red | green | blue | qa]

R-1: ✅ Found 3 test files matching *.test.tsx
R-2: ✅ All ACs referenced (AC-1, AC-2, AC-3)
R-3: ✅ Tests fail — import errors (expected behaviour)
R-4: ✅ No regressions on develop
R-5: ✅ No implementation files modified
R-6: ✅ acCoverage.uncovered is consistent

DoD result: PASS ✅
Recommended action: advance to green
```

Or on failure:
```
R-3: ❌ 2 of 5 new tests PASS without implementation — false positives detected
     Test names: "renders component", "shows default state"
     These tests pass because they assert nothing specific enough to fail.

DoD result: FAIL ❌
Recommended action: return_to_red — tighten assertions on failing tests
```

## Escalation triggers (do not retry — escalate immediately)
- R-5 fails: implementation code written during Red phase
- G-4 fails: test files modified during Green phase
- B-5 fails: test files modified during Blue phase
- B-7 fails: public interface removed without replacement

## Write to pipeline.log.ndjson
After every check run, append event:
- Pass: `{"event": "dod_checked", "severity": "info", "phase": "...", "detail": "N/N checks passed"}`
- Fail: `{"event": "dod_failed", "severity": "warn", "phase": "...", "failedChecks": [...], "detail": "..."}`
