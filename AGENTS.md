# AGENTS.md

Universal entry point for all AI coding agents working in this repository.
Compatible with GitHub Copilot, Claude Code, Cursor, Windsurf, and any tool
that follows the AGENTS.md convention.

---

## If you are an AI agent, read this first

**Step 0 — Read security requirements:**
Read `.agents/security.md` before doing anything else.
Understand what git access you have and what you must never do.

**Step 1 — Read context (in this order):**
1. `.agents/context/system.md` — what this system is, who it serves, domain model
2. `.agents/context/decisions.md` — architectural decisions that must be respected
3. `.agents/context/stack.md` — resolved stack, tooling, conventions

**Step 2 — Identify your role** from the table below and navigate to your agent file.

**Step 3 — Follow your agent file exactly.** Do not skip phases or improvise.

**Step 4 — Never write directly to `.agents/context/`.**
All context updates are proposed via PR only.

---

## Agent roles

| Role | File | Invoked when |
|---|---|---|
| Pipeline Orchestrator | `.agents/agents/pipeline-orchestrator.md` | Per spec — top-level coordinator |
| Architect | `.agents/agents/architect.md` | Project init, or periodic review |
| Business Analyst | `.agents/agents/ba.md` | After architect, to produce specs |
| Onboarding | `.agents/agents/onboarding.md` | Once, to resolve [SHORTCODES] |
| Developer Orchestrator | `.agents/agents/developer/orchestrator.md` | Sub-agent of pipeline |
| Red | `.agents/agents/developer/red.md` | Sub-agent of developer orchestrator |
| Green | `.agents/agents/developer/green.md` | Sub-agent of developer orchestrator |
| Blue | `.agents/agents/developer/blue.md` | Sub-agent of developer orchestrator |
| QA Orchestrator | `.agents/agents/qa/orchestrator.md` | Sub-agent of pipeline, post human review |

---

## Atomic skills

Skills are single-purpose tools invoked by agents. They are not invoked directly.

| Skill | File | Used by |
|---|---|---|
| Create branch | `.agents/skills/atoms/create-branch.md` | Pipeline Orchestrator |
| Fetch Figma nodes | `.agents/skills/atoms/fetch-figma-nodes.md` | Pipeline Orchestrator |
| Build handoff | `.agents/skills/atoms/build-handoff.md` | Pipeline Orchestrator |
| Archive spec | `.agents/skills/atoms/archive-spec.md` | Pipeline Orchestrator |
| Run e2e tests | `.agents/skills/atoms/run-e2e-tests.md` | QA Orchestrator |
| Create regression ticket | `.agents/skills/atoms/create-regression-ticket.md` | QA Orchestrator |

---

## Pipeline at a glance

```
[Once]
Architect → BA → Onboarding
       produce context + specs

[Per spec — automated]
Pipeline Orchestrator
  ├─ create-branch
  ├─ fetch-figma-nodes
  ├─ build-handoff → handoff.json
  ├─ Developer Orchestrator
  │    └─ Red → Green → Blue → Draft PR
  ├─ ⏸ Human Review
  ├─ QA Orchestrator
  │    └─ e2e + AC validation + defect routing
  ├─ Merge → develop
  └─ archive-spec → .specs/done/

[Periodically]
Architect (review mode) → context updates via PR
```

---

## Specs

Specs are the pipeline's input. They live in `.specs/`.

```
.specs/
├── template.md        ← format all specs must follow
├── epics/             ← EPIC-NNN-slug.md (BA produces)
├── features/          ← FEAT-NNN-slug.md (BA produces)
├── active/            ← pipeline picks from here
└── done/              ← archived after successful merge
```

Flow: `draft → confirmed by human → active/ → pipeline → done/`

Only the BA agent (with human sign-off) moves specs to `active/`.
Only the pipeline orchestrator moves specs to `done/`.

---

## Shared contract

All agents communicate via `handoff.json` on the feature branch.
Full schema: `.agents/handoff/schema.md`

Key rules:
- `audit` is append-only
- `context.agentNotes` is append-only — prefix with `[AGENT-NAME]:`
- `ticket.status` updated only by orchestrators
- No agent overwrites another agent's fields
- `handoff.json` committed on every meaningful state change
- `handoff.json` is never merged to `develop` — feature branch only

---

## Branching

Gitflow:
- `main` → production (manual only)
- `develop` → integration target for all agent PRs
- `feature/SPEC-NNN-slug` → one per spec, created by pipeline
- All PRs target `develop`. Never `main`.

---

## Context versioning

```
context/v1.0  →  Architect + onboarding init
context/v1.N  →  Incremental update
context/v2.0  →  Major architecture or domain change
```

Full history: `.agents/context/CHANGELOG.md`
