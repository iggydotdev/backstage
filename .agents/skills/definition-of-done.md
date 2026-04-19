# Definition of Done

The canonical, binary checklist the developer orchestrator verifies
before accepting any phase transition. Every check must pass. There
are no partial passes — a phase is done or it is not.

Checks are run by the `skills/atoms/check-dod.md` atom.
They are deterministic — git, shell, and file system operations only.
No LLM judgment. No self-certification.

---

## How this works

When a sub-agent sets `tdd.phase = "X"` in `handoff.json`, it is
making a **claim** that it is done. The developer orchestrator treats
this as a request, not a fact. It invokes `check-dod` with the claimed
phase, receives a structured result, and only advances if all checks
pass.

```
Sub-agent sets tdd.phase = "green"
       ↓
Developer Orchestrator invokes check-dod(phase: "green")
       ↓
check-dod runs binary checks
       ↓
All pass → advance to Green Agent
Any fail → stay in Red, log failure, increment iteration
```

---

## Phase: Red

**Claim being verified:** "I have written failing tests that cover all ACs."

| # | Check | Method |
|---|---|---|
| R-1 | Test files exist at expected paths | `find` by `[TEST_FILE_CONVENTION]` — count > 0 |
| R-2 | Every AC has at least one test referencing it | `grep -r "AC-[0-9]" <test files>` — all AC IDs present |
| R-3 | All new tests fail | Run `[TEST_COMMAND]` — exit code non-zero, new tests in failure output |
| R-4 | No existing tests were broken | Compare failing tests against base branch — only new tests fail |
| R-5 | No implementation files were created or modified | `git diff develop -- src/` excludes test files — diff is empty |
| R-6 | `tdd.acCoverage.uncovered` matches `tdd.testResults` | Cross-check: uncovered ACs have no matching test name |

**On failure:**
- Log which check(s) failed with specifics
- If R-3 fails (tests pass without implementation): false positive — return to Red, tighten tests
- If R-4 fails (regression introduced): fix regression before any other action
- If R-5 fails (implementation code written): flag as rule violation, escalate

---

## Phase: Green

**Claim being verified:** "All tests pass. Implementation is minimal and correct."

| # | Check | Method |
|---|---|---|
| G-1 | All tests pass | Run `[TEST_COMMAND]` — exit code zero |
| G-2 | Zero test failures | Parse output — `failed: 0` |
| G-3 | Coverage has not decreased vs base branch | Compare coverage report — current >= base |
| G-4 | No test files were modified | `git diff develop -- <test paths>` — diff is empty |
| G-5 | Implementation files exist for every test import | `grep` imports from test files — each resolves to an existing file |
| G-6 | Lint passes (errors only — warnings deferred to Blue) | Run `[LINT_COMMAND]` — zero errors (warnings allowed) |

**On failure:**
- If G-1/G-2: tests still failing — return to Green, increment internal attempt counter
- If G-4: test files were modified — flag as rule violation, escalate immediately
- If G-3: coverage dropped — implementation is incomplete, return to Green
- If G-5: missing implementation file — implementation is incomplete, return to Green

---

## Phase: Blue

**Claim being verified:** "Refactoring is complete. Behaviour unchanged. Code is clean."

| # | Check | Method |
|---|---|---|
| B-1 | All tests still pass | Run `[TEST_COMMAND]` — exit code zero |
| B-2 | Coverage has not decreased vs Green baseline | Compare coverage — current >= Green phase result |
| B-3 | Zero lint errors AND zero lint warnings | Run `[LINT_COMMAND]` — clean output |
| B-4 | Zero type errors | Run `[TYPE_CHECK_COMMAND]` — exit code zero |
| B-5 | No test files were modified | `git diff <green-phase-commit> -- <test paths>` — diff is empty |
| B-6 | No new files introduced outside existing structure | `git diff develop --name-only` — all new files match `[PROJECT_STRUCTURE]` |
| B-7 | No public interfaces removed or renamed without replacement | `git diff develop` — no exported function/component signatures deleted |

**On failure:**
- If B-1/B-2: refactor broke something — revert last change, re-run, return to Blue
- If B-3: lint still failing — fix before proceeding, do not escalate for lint
- If B-4: type errors — attempt fix; if unfixable without behaviour change, log TODO and pass with note
- If B-5: test files modified — flag as rule violation, escalate immediately
- If B-7: public interface removed — escalate; this requires human review

**Special rule for B-4:**
Type errors that cannot be fixed without changing component interfaces are
the one exception to the hard pass requirement. If B-4 fails for this reason:
- Write a `// TODO(blue): type error — [description]` comment in the file
- Log `[BLUE]: type error deferred — <description>` in `context.agentNotes`
- Set `tdd.phase = "complete"` with a `warn` event, not an `error`
- Surface clearly in the PR description

---

## Phase: QA

**Claim being verified:** "All ACs pass end-to-end. No defects introduced."

| # | Check | Method |
|---|---|---|
| Q-1 | All unit tests pass on feature branch | Run `[TEST_COMMAND]` — exit code zero |
| Q-2 | All e2e tests pass | Run `[E2E_COMMAND]` — exit code zero |
| Q-3 | Every AC has a passing e2e test | Cross-reference AC IDs in e2e test names — all covered |
| Q-4 | No regressions vs develop | Run test suite on develop, compare — no new failures |
| Q-5 | Zero accessibility violations | Run `[A11Y_COMMAND]` — zero WCAG AA violations |
| Q-6 | Design fidelity confirmed | Visual diff or manual Figma comparison — zero critical mismatches |
| Q-7 | `defects` array is empty OR all open defects are `pre_existing` | Check `handoff.json > defects` — no `origin: "current_ticket"` defects open |

**On failure:**
- If Q-1: unit regression — return to Developer Orchestrator with defect
- If Q-2/Q-3: e2e failure — classify defect origin (git blame), route accordingly
- If Q-4: regression detected — create regression ticket if pre-existing, return to dev if current
- If Q-5: a11y violation — treat as defect, classify by origin
- If Q-6: design mismatch — severity determines routing (critical → dev, minor → PR comment)
- If Q-7: open current-ticket defects — must be resolved before done

---

## DoD result schema

The `check-dod` atom returns this structure for every check run:

```json
{
  "phase": "red | green | blue | qa",
  "passed": false,
  "checks": [
    {
      "id": "R-1",
      "description": "Test files exist at expected paths",
      "passed": true,
      "detail": "Found 3 test files matching *.test.tsx"
    },
    {
      "id": "R-3",
      "description": "All new tests fail",
      "passed": false,
      "detail": "2 of 5 new tests passed without implementation — false positives detected",
      "action": "return_to_red"
    }
  ],
  "failedChecks": ["R-3"],
  "recommendedAction": "return_to_red | return_to_green | escalate | advance",
  "escalate": false,
  "notes": "Human-readable summary of what failed and why"
}
```

### `recommendedAction` logic

| Condition | Action |
|---|---|
| All checks pass | `advance` |
| Recoverable failure (G-1, G-3, B-1, B-2, B-3) | `return_to_[phase]` |
| Rule violation (R-5, G-4, B-5) | `escalate` |
| Interface removal (B-7) | `escalate` |
| Max iterations reached | `escalate` |
| False positive tests (R-3 partial) | `return_to_red` |

---

## Iteration accounting

Every DoD failure that results in `return_to_*` increments
`tdd.loop.iteration` in the developer orchestrator.

The developer orchestrator checks this **before** invoking `check-dod` —
if `iteration >= maxIterations`, escalate without running checks.

DoD failures are logged to `pipeline.log.ndjson` with:
- `event: "dod_failed"`
- `severity: "warn"` for recoverable, `"error"` for violations
- The full `failedChecks` array in `detail`
