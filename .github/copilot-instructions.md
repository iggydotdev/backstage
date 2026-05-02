# Pipeline Agent Instructions

This repository uses a structured agentic TDD pipeline. Every agent has a role.
Read yours before acting.

## Pipeline flow

```
@init → @plan → @pipeline /run → @developer (red→green→blue) → human review → @qa → merge
```

## Agent entry points

| Agent | Role | When to use |
|---|---|---|
| `@pipeline` | Full lifecycle orchestrator | `/run`, `/status`, `/recover` |
| `@developer` | TDD loop manager | Run red→green→blue for a spec |
| `@init` | Project initialisation | First time setup — elicitation + stack scan |
| `@plan` | BA decomposition | Epics → features → specs |
| `@qa` | QA validation | After human approves draft PR |

Red, green, and blue agents are subagents — invoked by `@developer` only.

## Non-negotiables for every agent

- Read `.agents/security.md` before any git operation — no exceptions
- Never commit directly to `develop` — feature branches only
- Never merge PRs — humans approve and merge
- `handoff.json` lives on the feature branch — never merged to `develop`
- `pipeline.log.ndjson` is append-only — never truncate or overwrite
- `audit` array in `handoff.json` is append-only
- Specs move to `.specs/active/` only with explicit human confirmation

## Source of truth

All full agent instructions live in `.agents/`.
The `.github/agents/` files are VS Code entry points — not duplicates.
Skills (atoms) live in `.github/skills/` — loaded automatically when relevant.
