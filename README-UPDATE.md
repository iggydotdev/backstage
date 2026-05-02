# Pipeline Update Package

This package contains the VS Code agent wiring for your pipeline.
Drop the contents into your repo root and push.

---

## What's in this package

```
.github/
├── copilot-instructions.md          ← always-on Copilot baseline (NEW)
├── agents/
│   ├── pipeline.agent.md            ← @pipeline organism (NEW)
│   ├── developer.agent.md           ← @developer organism (NEW)
│   ├── init.agent.md                ← @init molecule — elicitation (NEW)
│   ├── plan.agent.md                ← @plan molecule — BA decomposition (NEW)
│   ├── red.agent.md                 ← red subagent — hidden (NEW)
│   ├── green.agent.md               ← green subagent — hidden (NEW)
│   ├── blue.agent.md                ← blue subagent — hidden (NEW)
│   └── qa.agent.md                  ← @qa molecule (NEW)
└── skills/
    ├── check-dod/SKILL.md           ← DoD verification atom (NEW)
    ├── create-branch/SKILL.md       ← Branch creation atom (NEW)
    ├── build-handoff/SKILL.md       ← Handoff construction atom (NEW)
    ├── fetch-figma-nodes/SKILL.md   ← Figma data atom (NEW)
    ├── archive-spec/SKILL.md        ← Spec archival atom (NEW)
    ├── recover-pipeline/SKILL.md    ← Recovery atom (NEW)
    ├── run-e2e-tests/SKILL.md       ← E2E test runner atom (NEW)
    ├── create-regression-ticket/SKILL.md  ← Regression ticket atom (NEW)
    ├── prepare-context-slice/SKILL.md     ← Context slice atom (NEW)
    └── eval-pipeline/SKILL.md       ← Eval atom (NEW)
```

---

## Critical fix required in your existing codebase

### Schema version mismatch — FIX BEFORE FIRST RUN

Your existing `.agents/skills/atoms/build-handoff.md` (or wherever it lives)
writes `schemaVersion: "1.0.0"` but the current schema is `"1.4.0"`.

Find and replace in that file:
```
"schemaVersion": "1.0.0"
→
"schemaVersion": "1.4.0"
```

The new `.github/skills/build-handoff/SKILL.md` in this package already has
the correct version — but your legacy `.agents/` atom file also needs fixing
if you still reference it anywhere.

---

## Folder structure alignment

Your existing `.agents/` folder needs renaming to match atomic design language.
Run from your repo root:

```bash
# Rename layers to atomic design terminology
mkdir -p .agents/atoms .agents/molecules .agents/organisms

# Atoms — rename from old location
cp -r .agents/skills/atoms/* .agents/atoms/ 2>/dev/null || true

# Molecules — flatten from nested structure
cp .agents/agents/developer/red.md    .agents/molecules/red.md    2>/dev/null || true
cp .agents/agents/developer/green.md  .agents/molecules/green.md  2>/dev/null || true
cp .agents/agents/developer/blue.md   .agents/molecules/blue.md   2>/dev/null || true
cp .agents/agents/qa/orchestrator.md  .agents/molecules/qa.md     2>/dev/null || true
cp .agents/agents/architect.md        .agents/molecules/architect.md 2>/dev/null || true
cp .agents/agents/ba.md               .agents/molecules/ba.md     2>/dev/null || true
cp .agents/agents/onboarding.md       .agents/molecules/onboarding.md 2>/dev/null || true

# Organisms — pull out from agents
cp .agents/agents/pipeline-orchestrator.md  .agents/organisms/pipeline.md   2>/dev/null || true
cp .agents/agents/developer/orchestrator.md .agents/organisms/developer.md  2>/dev/null || true

echo "Done. Verify the copies, then delete the old nested folders when happy."
```

> Run this, verify the copies look right, then manually remove the old
> `.agents/agents/` and `.agents/skills/atoms/` folders once confirmed.

---

## How to use (once uploaded to repo)

### First time on a new project
```
1. Open VS Code with GitHub Copilot
2. Open Copilot chat, select @init from agent dropdown
3. Answer the product questions — system.md and stack.md get created
4. Switch to @plan — decompose into specs
5. Confirm spec IDs to move to .specs/active/
6. Switch to @pipeline — type /run
7. Pipeline runs Red → Green → Blue → draft PR
8. Review and approve the PR
9. Switch to @qa — validate
10. Merge
```

### Resuming an existing project
```
1. If context/v1.0 tag exists → skip @init, go straight to @plan or @pipeline
2. @pipeline /status → check current state
3. @pipeline /run SPEC-NNN → run a specific spec
4. @pipeline /recover → if something is broken
```

### Agent quick reference

| Type | Agent | When |
|---|---|---|
| Organism | `@pipeline` | Master control — use this most |
| Organism | `@developer` | TDD loop directly |
| Molecule | `@init` | First-time setup |
| Molecule | `@plan` | Create/manage specs |
| Molecule | `@qa` | After PR approval |
| Subagent | `@red` | Invoked by @developer only |
| Subagent | `@green` | Invoked by @developer only |
| Subagent | `@blue` | Invoked by @developer only |

---

## VS Code settings recommended

Add to your `.vscode/settings.json`:

```json
{
  "chat.agent.enabled": true,
  "chat.subagents.enabled": true,
  "github.copilot.chat.agent.runTasks": true
}
```

---

## MCP servers (wire these up separately)

For full pipeline functionality you need:
- **Figma MCP** — for fetch-figma-nodes skill
- **GitHub MCP** — for PR creation, regression tickets

Add to your `.vscode/mcp.json` (create if it doesn't exist):
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

Pipeline will degrade gracefully if these are absent — but Figma nodes
will be empty and PR creation will need to be done manually.

---

## What to do next (priority order)

1. **Upload this package to your repo** — merge to develop
2. **Fix schema version** in your legacy build-handoff.md atom
3. **Run the folder rename script** above
4. **Fill in system.md** — open @init and answer the questions
5. **Fill in stack.md** — @init will scan and ask about gaps  
6. **Write one real spec** into .specs/active/
7. **Type @pipeline /run** and watch what actually breaks
