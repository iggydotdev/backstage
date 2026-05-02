# Backstage

An agentic SDLC pipeline for VS Code. Automates the full software development
lifecycle — from product vision to merged code — using structured AI agents
that coordinate via a shared contract.

---

## What this is

Backstage is a **framework** that orchestrates AI coding agents through a
rigorous TDD pipeline. It decomposes your product into specs, writes failing
tests, implements them, refactors, and submits PRs for human review — all
within VS Code using GitHub Copilot's agent mode.

```
@init → @plan → @pipeline /run → @developer (red→green→blue) → human review → @qa → merge
```

Humans stay in the loop at every critical gate: spec confirmation, PR review,
and merge. Agents never merge code — they produce it, verify it, and wait.

---

## Prerequisites

- **VS Code 1.100+** with GitHub Copilot agent mode enabled
- **GitHub Copilot Pro** or higher (agent mode requires tool use)
- A repository with a `develop` branch (Gitflow)

### Recommended VS Code settings

Add to `.vscode/settings.json`:
```json
{
  "chat.agent.enabled": true,
  "chat.subagents.enabled": true,
  "github.copilot.chat.agent.runTasks": true
}
```

### Optional MCP servers

For full pipeline functionality, add to `.vscode/mcp.json`:
```json
{
  "servers": {
    "figma": {
      "command": "npx",
      "args": ["-y", "@figma/mcp-server"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"]
    }
  }
}
```

The pipeline degrades gracefully without these — Figma nodes will be empty
and PR creation will need to be done manually.

---

## Quick start

### 1. Set up the repo

```bash
# Ensure develop branch exists
git checkout -b develop
git push -u origin develop
```

### 2. Initialise the project — `@init`

Open VS Code Copilot chat and select **@init** from the agent dropdown.

This runs two phases:
1. **Architect elicitation** — a structured conversation about your product,
   domain model, users, and technical constraints
2. **Onboarding** — scans your repo, resolves stack configuration, and
   populates all agent shortcodes

At the end, it creates `context/v1.0` and your pipeline is ready.

### 3. Plan the work — `@plan`

```
@plan
```

The BA agent decomposes your system into epics → features → specs.
Each level requires your explicit confirmation before proceeding.
Nothing moves to `.specs/active/` without you saying so.

### 4. Run the pipeline — `@pipeline`

```
@pipeline /run
```

Or for a specific spec:
```
@pipeline /run SPEC-001
```

The pipeline runs automatically: creates a feature branch, fetches Figma data,
builds the handoff, runs the TDD loop (Red → Green → Blue), and opens a
draft PR for your review.

### 5. Review and merge

Review the draft PR. When you approve it, the QA agent validates everything
end-to-end. If QA passes, the pipeline labels the PR as `ready-to-merge`.
**You** perform the final merge.

---

## Available agents

| Agent | Type | How to invoke | Purpose |
|-------|------|---------------|---------|
| `@pipeline` | Organism | `@pipeline /run` | Full lifecycle orchestrator |
| `@developer` | Organism | `@developer` | TDD loop (red→green→blue) |
| `@init` | Molecule | `@init` | First-time project setup |
| `@plan` | Molecule | `@plan` | Spec decomposition |
| `@qa` | Molecule | `@qa` | Post-approval validation |

Red, green, and blue are subagents — invoked by `@developer` only,
not directly by users.

---

## Architecture

```
.agents/          ← source of truth (full agent instructions, context, schema)
.github/agents/   ← VS Code wiring layer (references .agents/ files)
.github/skills/   ← VS Code skill definitions (auto-loaded)
.specs/           ← spec lifecycle (epics → features → active → done)
.pipeline/        ← checkpoint storage for recovery
```

For the full architecture, agent hierarchy, and observability model,
see [.agents/README.md](.agents/README.md).

For the universal agent entry point (tool-agnostic),
see [AGENTS.md](AGENTS.md).

---

## Key design decisions

- **Sub-agent claims are verified, not trusted.** When Red says "tests are ready",
  the Developer Orchestrator runs the Definition of Done checks before advancing.
- **Agents never merge.** Every merge requires human approval.
- **Context is sliced per-agent.** Each agent reads from a pre-prepared
  `contextSlice` — not raw files — keeping token usage efficient and context relevant.
- **Failures are contained.** A failed step doesn't fail the pipeline. The system
  classifies failures, retries when possible, and escalates to humans when not.
- **The pipeline improves itself.** Every 10 specs, an eval runs automatically
  and recommends context or agent updates to the Architect.

---

## Security

Agents run with scoped access. They can commit to feature branches and open
PRs, but cannot merge, force-push, or access `main`. See
[.agents/security.md](.agents/security.md) for the full security model.

---

## License

[Add your license here]
