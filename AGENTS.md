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

| Role | VS Code Agent | Full Instructions | Invoked when |
|---|---|---|---|
| Pipeline | `.github/agents/pipeline.agent.md` | `.agents/organisms/pipeline.md` | Per spec — top-level coordinator |
| Init (Architect + Onboarding) | `.github/agents/init.agent.md` | `.agents/molecules/architect.md`, `.agents/molecules/onboarding.md` | Project init, first-time setup |
| Business Analyst | `.github/agents/plan.agent.md` | `.agents/molecules/ba.md` | After architect, to produce specs |
| Developer | `.github/agents/developer.agent.md` | `.agents/organisms/developer.md` | Sub-agent of pipeline |
| Red | `.github/agents/red.agent.md` | `.agents/molecules/red.md` | Sub-agent of developer |
| Green | `.github/agents/green.agent.md` | `.agents/molecules/green.md` | Sub-agent of developer |
| Blue | `.github/agents/blue.agent.md` | `.agents/molecules/blue.md` | Sub-agent of developer |
| QA | `.github/agents/qa.agent.md` | `.agents/molecules/qa.md` | Sub-agent of pipeline, post human review |

---

## Atomic skills

Skills are single-purpose tools invoked by agents. They are loaded automatically by
VS Code from `.github/skills/`. Full source definitions live in `.agents/atoms/`.

| Skill | VS Code Skill | Full Source | Used by |
|---|---|---|---|
| Create branch | `.github/skills/create-branch/SKILL.md` | `.agents/atoms/create-branch.md` | Pipeline |
| Fetch Figma nodes | `.github/skills/fetch-figma-nodes/SKILL.md` | `.agents/atoms/fetch-figma-nodes.md` | Pipeline |
| Build handoff | `.github/skills/build-handoff/SKILL.md` | `.agents/atoms/build-handoff.md` | Pipeline |
| Archive spec | `.github/skills/archive-spec/SKILL.md` | `.agents/atoms/archive-spec.md` | Pipeline |
| Check DoD | `.github/skills/check-dod/SKILL.md` | `.agents/atoms/check-dod.md` | Developer |
| Prepare context slice | `.github/skills/prepare-context-slice/SKILL.md` | `.agents/atoms/prepare-context-slice.md` | Pipeline |
| Recover pipeline | `.github/skills/recover-pipeline/SKILL.md` | `.agents/atoms/recover-pipeline.md` | Pipeline |
| Eval pipeline | `.github/skills/eval-pipeline/SKILL.md` | `.agents/atoms/eval-pipeline.md` | Pipeline |
| Run e2e tests | `.github/skills/run-e2e-tests/SKILL.md` | `.agents/atoms/run-e2e-tests.md` | QA |
| Create regression ticket | `.github/skills/create-regression-ticket/SKILL.md` | `.agents/atoms/create-regression-ticket.md` | QA |

---

## Pipeline at a glance

```
[Once]
Architect → BA → Onboarding
       produce context + specs

[Per spec — automated]
Pipeline
  ├─ create-branch
  ├─ fetch-figma-nodes
  ├─ build-handoff → handoff.json
  ├─ Developer
  │    └─ Red → Green → Blue → Draft PR
  ├─ ⏸ Human Review
  ├─ QA
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
Only the pipeline agent moves specs to `done/`.

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
