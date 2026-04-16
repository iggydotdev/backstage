# .agents

This folder contains all agent definitions, context files, and shared schemas
for the automated development pipeline.

---

## Structure

```
.agents/
├── README.md                        ← you are here
│
├── handoff/
│   └── schema.md                    ← typed contract between all agents
│
├── context/
│   ├── global.md                    ← principles and guidance (stable, rarely changes)
│   ├── stack.md                     ← resolved after onboarding (replaces [STACK] etc.)
│   ├── domain.md                    ← project-specific domain knowledge (evolves)
│   ├── CHANGELOG.md                 ← versioned log of all context changes
│   └── onboarding.log.json          ← written once by the onboarding agent
│
├── agents/
│   ├── onboarding.md                ← runs once, resolves shortcodes
│   │
│   ├── developer/
│   │   ├── orchestrator.md          ← manages TDD lifecycle, opens PR
│   │   ├── red.md                   ← writes failing tests
│   │   ├── green.md                 ← writes minimal implementation
│   │   └── blue.md                  ← refactors implementation
│   │
│   └── qa/
│       └── orchestrator.md          ← validates ACs, classifies + routes defects
│
└── skills/
    └── atoms/
        ├── create-regression-ticket.md  ← creates ticket for pre-existing defects
        └── run-e2e-tests.md             ← runs Playwright, maps results to ACs
```

---

## Pipeline flow (high level)

```
[First run only]
Onboarding Agent → resolves shortcodes → tags context/v1.0

[Per ticket]
Pipeline Orchestrator
  → creates feature branch
  → builds handoff.json from ticket + Figma
  → invokes Developer Orchestrator

Developer Orchestrator
  → Red Agent   (write failing tests)
  → Green Agent (make tests pass)
  → Blue Agent  (refactor)
  → opens Draft PR

⏸ Human Review
  → changes requested  → Developer Orchestrator (new loop)
  → approved           → QA Orchestrator

QA Orchestrator
  → run-e2e-tests (atom)
  → classify defects by origin
  → pass                          → merge + ticket done
  → fail: new code defects        → Developer Orchestrator (with defects as input)
  → fail: pre-existing defects    → create-regression-ticket (atom) → new ticket
  → both                          → handle in parallel
  → 3+ QA runs                    → escalate to human
```

---

## Defect routing logic

| Defect origin | Action | Blocks current ticket? |
|---|---|---|
| Current ticket's code | Return to Developer Orchestrator | ✅ Yes |
| Pre-existing code | Create regression ticket | ❌ No |
| Both | Both paths run in parallel | ✅ Yes (for new-code defects) |

---

## Context versioning

Context files are version-controlled. Tags follow the pattern `context/vX.Y`.

- **Major version** (`v2.0`): significant change to stack or architecture
- **Minor version** (`v1.1`): incremental improvement, new domain knowledge

Agents may propose context updates via PR. The orchestrator applies them.
Direct commits to `.agents/context/` by agents are not permitted.

---

## Shortcodes

Before onboarding, agent files contain placeholders like `[STACK]`.
After onboarding runs, these are replaced with real values.

See `agents/onboarding.md` for the full list of shortcodes and resolution process.