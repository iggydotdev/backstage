# Skill: Check Definition of Done

**Type:** Atom
**Used by:** Developer Orchestrator, Pipeline Orchestrator
**Trigger:** After any sub-agent sets `tdd.phase` — before the orchestrator acts on it

---

## Purpose
Run the binary Definition of Done checks for the claimed phase.
Return a structured result. Never advance a phase on agent self-certification alone.

All checks are deterministic — git, shell, file system.
This skill does not use LLM judgment for any check.

---

## Inputs
```json
{
  "phase": "red | green | blue | qa",
  "branch": "feature/SPEC-001-slug",
  "handoffPath": "handoff.json",
  "baseBranch": "develop",
  "greenCommitSha": "abc123"
}
```

`greenCommitSha` is only required when `phase = "blue"` — it identifies
the commit after the Green phase completed, used as the baseline for
detecting test file modifications during refactoring.

---

## Process

### Step 0 — Setup
```bash
# Ensure we are on the correct branch
git checkout feature/SPEC-001-slug
git fetch origin develop

# Read handoff for context
HANDOFF=$(cat handoff.json)
TEST_COMMAND=$(echo $HANDOFF | jq -r '.contextSlice.testingConventions.command')
LINT_COMMAND=$(echo $HANDOFF | jq -r '.contextSlice.stack.lintCommand')
TYPE_CHECK=$(echo $HANDOFF | jq -r '.contextSlice.stack.typeCheckCommand')
E2E_COMMAND=$(echo $HANDOFF | jq -r '.contextSlice.testingCommands.e2eCommand')
A11Y_COMMAND=$(echo $HANDOFF | jq -r '.contextSlice.testingCommands.a11yCommand')
FILE_CONVENTION=$(echo $HANDOFF | jq -r '.contextSlice.testingConventions.fileConvention')
ACS=$(echo $HANDOFF | jq -r '.requirements.acs[]')
```

---

### Red phase checks

#### R-1: Test files exist
```bash
TEST_FILES=$(find . -name "*.test.tsx" -o -name "*.test.ts" -o -name "*.spec.tsx" \
  | grep -v node_modules | grep -v ".agents")
COUNT=$(echo "$TEST_FILES" | grep -c .)

if [ "$COUNT" -gt 0 ]; then
  pass R-1 "Found $COUNT test files"
else
  fail R-1 "No test files found matching convention: $FILE_CONVENTION"
fi
```

#### R-2: All AC IDs referenced in tests
```bash
# Extract AC identifiers from handoff
AC_IDS=$(cat handoff.json | jq -r '.requirements.acs[]' | grep -oP 'AC-\d+')

MISSING=""
for AC in $AC_IDS; do
  if ! grep -r "$AC" $TEST_FILES --quiet; then
    MISSING="$MISSING $AC"
  fi
done

if [ -z "$MISSING" ]; then
  pass R-2 "All ACs referenced in tests"
else
  fail R-2 "No test references found for:$MISSING"
fi
```

#### R-3: New tests fail (and only because implementation is missing)
```bash
$TEST_COMMAND 2>&1; EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  # Check that failures are import/module errors, not logic errors
  OUTPUT=$($TEST_COMMAND 2>&1)
  if echo "$OUTPUT" | grep -qiE "cannot find module|does not exist|not found"; then
    pass R-3 "Tests fail correctly — implementation not yet present"
  else
    warn R-3 "Tests fail but not due to missing implementation — review test logic"
  fi
else
  fail R-3 "Tests pass without implementation — false positives detected"
fi
```

#### R-4: No existing tests broken
```bash
# Run tests on base branch and compare
git stash
git checkout develop
$TEST_COMMAND 2>&1 > /tmp/base_results.txt
git checkout feature/SPEC-001-slug
git stash pop

$TEST_COMMAND 2>&1 > /tmp/branch_results.txt

# Check if any previously passing test now fails
BASE_PASSING=$(grep -c "✓\|PASS\|passed" /tmp/base_results.txt || echo 0)
BRANCH_PASSING=$(grep -c "✓\|PASS\|passed" /tmp/branch_results.txt || echo 0)

if [ "$BRANCH_PASSING" -ge "$BASE_PASSING" ]; then
  pass R-4 "No regressions — base had $BASE_PASSING passing, branch has $BRANCH_PASSING"
else
  fail R-4 "Regression detected — base had $BASE_PASSING passing tests, branch has $BRANCH_PASSING"
fi
```

#### R-5: No implementation files created or modified
```bash
IMPL_DIFF=$(git diff develop --name-only | grep -v "\.test\.\|\.spec\.\|handoff\.json\|pipeline\.log")

if [ -z "$IMPL_DIFF" ]; then
  pass R-5 "No implementation files modified"
else
  fail R-5 "Implementation files modified during Red phase: $IMPL_DIFF" "escalate"
fi
```

#### R-6: acCoverage.uncovered matches test output
```bash
UNCOVERED=$(cat handoff.json | jq -r '.tdd.acCoverage.uncovered[]' 2>/dev/null)

for AC in $UNCOVERED; do
  if grep -r "$AC" $TEST_FILES --quiet; then
    fail R-6 "$AC is listed as uncovered but a test referencing it exists — coverage tracking is wrong"
  fi
done

pass R-6 "acCoverage.uncovered is consistent with test files"
```

---

### Green phase checks

#### G-1 + G-2: All tests pass
```bash
OUTPUT=$($TEST_COMMAND 2>&1)
EXIT_CODE=$?

FAILED=$(echo "$OUTPUT" | grep -oP 'failed: \K\d+' || echo "0")

if [ $EXIT_CODE -eq 0 ] && [ "$FAILED" -eq 0 ]; then
  PASSED=$(echo "$OUTPUT" | grep -oP 'passed: \K\d+' || echo "0")
  pass G-1 "All tests pass"
  pass G-2 "$PASSED tests passing, 0 failing"
else
  fail G-1 "Tests still failing — exit code $EXIT_CODE"
  fail G-2 "$FAILED tests failing"
fi
```

#### G-3: Coverage not decreased
```bash
# Read base coverage from handoff checkpoint or run on develop
BASE_COVERAGE=$(cat handoff.json | jq -r '.tdd.testResults.coverage // "0"' | tr -d '%')
CURRENT_COVERAGE=$(echo "$OUTPUT" | grep -oP '\d+(?=%)' | tail -1 || echo "0")

if [ "$CURRENT_COVERAGE" -ge "$BASE_COVERAGE" ]; then
  pass G-3 "Coverage: $CURRENT_COVERAGE% (base: $BASE_COVERAGE%)"
else
  fail G-3 "Coverage dropped: $CURRENT_COVERAGE% vs base $BASE_COVERAGE%"
fi
```

#### G-4: No test files modified
```bash
TEST_DIFF=$(git diff develop --name-only | grep "\.test\.\|\.spec\.")

if [ -z "$TEST_DIFF" ]; then
  pass G-4 "No test files modified"
else
  fail G-4 "Test files were modified during Green phase: $TEST_DIFF" "escalate"
fi
```

#### G-5: All test imports resolve
```bash
MISSING_IMPORTS=""
for TEST_FILE in $TEST_FILES; do
  IMPORTS=$(grep -oP "from ['\"](\./|@/)[^'\"]+['\"]" "$TEST_FILE" | grep -v "\.test\|\.spec\|\.mock")
  for IMPORT in $IMPORTS; do
    # Resolve path and check existence
    RESOLVED=$(node -e "console.log(require.resolve('$IMPORT'))" 2>/dev/null)
    if [ -z "$RESOLVED" ]; then
      MISSING_IMPORTS="$MISSING_IMPORTS\n  $IMPORT (in $TEST_FILE)"
    fi
  done
done

if [ -z "$MISSING_IMPORTS" ]; then
  pass G-5 "All test imports resolve to existing files"
else
  fail G-5 "Unresolved imports:$MISSING_IMPORTS"
fi
```

#### G-6: Lint passes (errors only)
```bash
LINT_OUTPUT=$($LINT_COMMAND 2>&1)
LINT_EXIT=$?
ERROR_COUNT=$(echo "$LINT_OUTPUT" | grep -c "error" || echo "0")

if [ "$ERROR_COUNT" -eq 0 ]; then
  WARN_COUNT=$(echo "$LINT_OUTPUT" | grep -c "warning" || echo "0")
  pass G-6 "Zero lint errors ($WARN_COUNT warnings — deferred to Blue)"
else
  fail G-6 "$ERROR_COUNT lint errors found"
fi
```

---

### Blue phase checks

#### B-1 + B-2: Tests still pass, coverage maintained
```bash
# Re-use G-1, G-2, G-3 logic but compare against Green baseline
GREEN_COVERAGE=$(cat handoff.json | jq -r '.tdd.testResults.coverage // "0"' | tr -d '%')
# (same test run and coverage extraction as Green)
```

#### B-3: Zero lint errors AND zero warnings
```bash
LINT_OUTPUT=$($LINT_COMMAND 2>&1)
ERROR_COUNT=$(echo "$LINT_OUTPUT" | grep -c "error" || echo "0")
WARN_COUNT=$(echo "$LINT_OUTPUT" | grep -c "warning" || echo "0")

if [ "$ERROR_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
  pass B-3 "Zero lint errors, zero warnings"
else
  fail B-3 "$ERROR_COUNT errors, $WARN_COUNT warnings"
fi
```

#### B-4: Zero type errors
```bash
TYPE_OUTPUT=$($TYPE_CHECK 2>&1)
TYPE_EXIT=$?
ERROR_COUNT=$(echo "$TYPE_OUTPUT" | grep -c "error TS" || echo "0")

if [ $TYPE_EXIT -eq 0 ]; then
  pass B-4 "Zero type errors"
elif [ "$ERROR_COUNT" -gt 0 ]; then
  # Check if errors are about public interface changes
  INTERFACE_ERRORS=$(echo "$TYPE_OUTPUT" | grep -c "Property.*missing\|is not assignable" || echo "0")
  if [ "$INTERFACE_ERRORS" -gt 0 ]; then
    warn B-4 "$ERROR_COUNT type errors — $INTERFACE_ERRORS may require interface changes. Deferring with TODO comments." "deferred"
  else
    fail B-4 "$ERROR_COUNT type errors"
  fi
fi
```

#### B-5: No test files modified since Green commit
```bash
if [ -z "$GREEN_COMMIT_SHA" ]; then
  warn B-5 "No Green commit SHA provided — skipping test modification check"
else
  TEST_DIFF=$(git diff $GREEN_COMMIT_SHA --name-only | grep "\.test\.\|\.spec\.")
  if [ -z "$TEST_DIFF" ]; then
    pass B-5 "No test files modified since Green phase"
  else
    fail B-5 "Test files modified during Blue phase: $TEST_DIFF" "escalate"
  fi
fi
```

#### B-6: No files outside project structure
```bash
NEW_FILES=$(git diff develop --name-only --diff-filter=A)
UNEXPECTED=""
for FILE in $NEW_FILES; do
  if ! echo "$FILE" | grep -qE "^src/|^tests?/|^__tests?__/|\.agents/|\.specs/"; then
    UNEXPECTED="$UNEXPECTED\n  $FILE"
  fi
done

if [ -z "$UNEXPECTED" ]; then
  pass B-6 "All new files within expected structure"
else
  fail B-6 "Files created outside project structure:$UNEXPECTED"
fi
```

#### B-7: No public interfaces removed
```bash
DELETED_EXPORTS=$(git diff develop | grep "^-.*export " | grep -v "^---")

if [ -z "$DELETED_EXPORTS" ]; then
  pass B-7 "No exported interfaces removed"
else
  fail B-7 "Exported interfaces removed — human review required: $DELETED_EXPORTS" "escalate"
fi
```

---

### QA phase checks

#### Q-1: Unit tests pass
```bash
# Same as G-1 — run full test suite
```

#### Q-2 + Q-3: E2E tests pass and cover all ACs
```bash
E2E_OUTPUT=$($E2E_COMMAND 2>&1)
E2E_EXIT=$?

if [ $E2E_EXIT -eq 0 ]; then
  pass Q-2 "All e2e tests pass"
else
  fail Q-2 "E2E tests failing — see output"
fi

# Check AC coverage in e2e test names
for AC in $AC_IDS; do
  if ! echo "$E2E_OUTPUT" | grep -q "$AC"; then
    fail Q-3 "No e2e test found for $AC"
  fi
done
pass Q-3 "All ACs covered by e2e tests"
```

#### Q-4: No regressions vs develop
```bash
# Same as R-4 — compare test results on develop vs branch
```

#### Q-5: Zero accessibility violations
```bash
A11Y_OUTPUT=$($A11Y_COMMAND 2>&1)
A11Y_EXIT=$?
VIOLATIONS=$(echo "$A11Y_OUTPUT" | grep -c "violation" || echo "0")

if [ "$VIOLATIONS" -eq 0 ]; then
  pass Q-5 "Zero accessibility violations"
else
  fail Q-5 "$VIOLATIONS accessibility violations found"
fi
```

#### Q-6: Design fidelity
```bash
# If visual diff command configured, run it
if [ -n "$VISUAL_DIFF_COMMAND" ]; then
  VISUAL_OUTPUT=$($VISUAL_DIFF_COMMAND 2>&1)
  CRITICAL=$(echo "$VISUAL_OUTPUT" | grep -c "critical" || echo "0")
  if [ "$CRITICAL" -eq 0 ]; then
    pass Q-6 "No critical design fidelity mismatches"
  else
    fail Q-6 "$CRITICAL critical visual mismatches"
  fi
else
  warn Q-6 "No visual diff tool configured — manual Figma comparison required"
fi
```

#### Q-7: No open current-ticket defects
```bash
OPEN_DEFECTS=$(cat handoff.json | jq '[.defects[] | select(.origin == "current_ticket" and .status == "open")] | length')

if [ "$OPEN_DEFECTS" -eq 0 ]; then
  pass Q-7 "No open current-ticket defects"
else
  fail Q-7 "$OPEN_DEFECTS open defects on current ticket code"
fi
```

---

## Output

```json
{
  "phase": "red",
  "passed": false,
  "timestamp": "ISO8601",
  "branch": "feature/SPEC-001-slug",
  "checks": [
    {
      "id": "R-1",
      "description": "Test files exist at expected paths",
      "passed": true,
      "detail": "Found 3 test files"
    },
    {
      "id": "R-3",
      "description": "All new tests fail",
      "passed": false,
      "detail": "2 of 5 new tests pass without implementation",
      "action": "return_to_red"
    }
  ],
  "failedChecks": ["R-3"],
  "warnChecks": [],
  "recommendedAction": "return_to_red",
  "escalate": false,
  "notes": "False positive tests detected — Red Agent must tighten assertions"
}
```

---

## Rules
- Never skip a check — a missing tool or unavailable command is a `warn`,
  not a silent pass
- If `[TEST_COMMAND]` is unavailable, fail the whole DoD — do not advance
- If `[LINT_COMMAND]` is unavailable during Blue, fail B-3
- If `[TYPE_CHECK_COMMAND]` is `n/a`, skip B-4 and log as skipped
- If `[E2E_COMMAND]` is unavailable during QA, fail Q-2 with `warn` severity
  and surface in PR description — do not block merge for e2e infrastructure failure
- Write the full DoD result to `pipeline.log.ndjson` as a `dod_checked` info
  event (pass) or `dod_failed` warn/error event (fail)
- Append a one-line summary to `handoff.json > context.agentNotes`:
  `[CHECK-DOD]: Red DoD passed — 6/6 checks` or
  `[CHECK-DOD]: Green DoD failed — G-4 test files modified (escalated)`
