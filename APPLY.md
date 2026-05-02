# Pipeline Update — VS Code Native Agent Wiring

## What's in this zip

```
.github/
├── copilot-instructions.md        ← always-on Copilot baseline (new)
├── agents/
│   ├── pipeline.agent.md          ← @pipeline organism (new)
│   ├── developer.agent.md         ← @developer organism (new)
│   ├── init.agent.md              ← @init molecule — elicitation + stack scan (new)
│   ├── plan.agent.md              ← @plan molecule — BA decomposition (new)
│   ├── red.agent.md               ← red subagent (new, hidden)
│   ├── green.agent.md             ← green subagent (new, hidden)
│   ├── blue.agent.md              ← blue subagent (new, hidden)
│   └── qa.agent.md                ← @qa molecule (new)
└── skills/
    ├── check-dod/SKILL.md         ← DoD verification atom (new)
    ├── create-branch/SKILL.md     ← branch creation atom (new)
    ├── fetch-figma-nodes/SKILL.md ← Figma data atom (new)
    ├── build-handoff/SKILL.md     ← handoff construction atom — FIX: uses 1.4.0 (new)
    ├── archive-spec/SKILL.md      ← spec archiving atom (new)
    ├── recover-pipeline/SKILL.md  ← recovery atom (new)
    ├── run-e2e-tests/SKILL.md     ← e2e test runner atom (new)
    ├── create-regression-ticket/SKILL.md  ← regression ticket atom (new)
    ├── prepare-context-slice/SKILL.md     ← context slice atom (new)
    └── eval-pipeline/SKILL.md     ← pipeline eval atom (new)

SCHEMA-VERSION-FIX.md             ← fix instructions for existing repo
APPLY.md                           ← this file
```

## How to apply

### Step 1 — Copy the .github/ folder
Copy everything in `.github/` from this zip into your existing repo's `.github/` folder.
```bash
cp -r .github/ /path/to/your/repo/.github/
```

### Step 2 — Apply the schema fix
Follow instructions in `SCHEMA-VERSION-FIX.md`.
```bash
grep -r '"schemaVersion"' /path/to/your/repo --include="*.md" --include="*.json"
# Fix any "1.0.0" to "1.4.0"
```

### Step 3 — Rename .agents/ folders to atomic design structure
```bash
cd /path/to/your/repo

# Create new folder structure
mkdir -p .agents/atoms
mkdir -p .agents/molecules
mkdir -p .agents/organisms

# Move atoms (skills)
cp -r .agents/skills/atoms/. .agents/atoms/

# Move molecules (individual agents)
cp .agents/agents/developer/red.md    .agents/molecules/red.md
cp .agents/agents/developer/green.md  .agents/molecules/green.md
cp .agents/agents/developer/blue.md   .agents/molecules/blue.md
cp .agents/agents/qa/orchestrator.md  .agents/molecules/qa.md
cp .agents/agents/architect.md        .agents/molecules/architect.md
cp .agents/agents/ba.md               .agents/molecules/ba.md
cp .agents/agents/onboarding.md       .agents/molecules/onboarding.md

# Move organisms (orchestrators)
cp .agents/agents/pipeline-orchestrator.md       .agents/organisms/pipeline.md
# If developer orchestrator exists separately:
# cp .agents/agents/developer/orchestrator.md    .agents/organisms/developer.md
```

### Step 4 — Verify VS Code picks up the agents
In VS Code:
1. Open Copilot chat
2. Click the agent picker dropdown
3. You should see: **pipeline**, **developer**, **init**, **plan**, **qa**
4. You should NOT see: red, green, blue (they are `user-invocable: false`)

Type `/agents` in chat to open the Configure Custom Agents menu if the dropdown is empty.

### Step 5 — First run: @init
```
@init
```
This starts the architect elicitation. It will ask you questions about your product,
then scan your repo to resolve the stack. At the end it creates `context/v1.0` tag.

### Step 6 — Plan: @plan
```
@plan
```
Decomposes your system into epics → features → specs.
Nothing moves to `.specs/active/` without you confirming each spec ID.

### Step 7 — Run the pipeline
```
@pipeline /run
```
Or for a specific spec:
```
@pipeline /run SPEC-001
```

---

## VS Code requirements
- GitHub Copilot extension with agent mode enabled
- VS Code 1.100+ (custom agents / `.agent.md` support)
- Copilot Pro or higher (agent mode requires tool use)

## MCP servers (optional but recommended)
For full Figma integration, add to `.vscode/mcp.json`:
```json
{
  "servers": {
    "figma": {
      "type": "http",
      "url": "https://mcp.figma.com/v1"
    }
  }
}
```

## Notes
- `runCommands` and `editFiles` are current valid tool names (verified against live docs)
- `user-invocable: false` hides red/green/blue from the agent picker — they only appear as subagents
- Skills are loaded automatically by Copilot when relevant based on their `description`
- All agent files reference `.agents/` source files — the `.github/` files are the VS Code wiring layer only
