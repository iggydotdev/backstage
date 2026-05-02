#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# Backstage Pipeline — Bootstrap
#
# Copy this script into your repo and run it. It will:
#   1. Clone the backstage repo into a temp directory
#   2. Copy all pipeline files into your current repo
#   3. Create .vscode/ config templates
#   4. Create develop branch if needed
#   5. Make an initial commit
#   6. Clean up
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/iggydotdev/backstage/main/setup.sh | bash
#   # or
#   cp setup.sh /path/to/your/repo/ && cd /path/to/your/repo && ./setup.sh
# ──────────────────────────────────────────────────────────────────────

REPO_URL="https://github.com/iggydotdev/backstage.git"
BRANCH="main"

# ── Colours ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1" >&2; }
step() { echo -e "\n${CYAN}${BOLD}→ $1${NC}"; }

# ── Validate ─────────────────────────────────────────────────────────
TARGET="$(pwd)"

# Must be in a git repo (or offer to init)
if [[ ! -d "$TARGET/.git" ]]; then
  warn "Current directory is not a git repository."
  read -rp "   Initialise git here? [y/N] " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    git init
    log "Initialised git repository"
  else
    err "Aborted — run this from inside a git repository."
    exit 1
  fi
fi

# Check for existing .agents/
if [[ -d "$TARGET/.agents" ]]; then
  warn "This repo already has .agents/ directory."
  read -rp "   Overwrite existing pipeline files? [y/N] " yn
  if [[ ! "$yn" =~ ^[Yy]$ ]]; then
    err "Aborted — will not overwrite existing pipeline."
    exit 1
  fi
fi

# ── Fetch backstage ─────────────────────────────────────────────────
step "Fetching backstage pipeline"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMPDIR/backstage" 2>&1 | tail -1
log "Cloned backstage repo"

SRC="$TMPDIR/backstage"

# ── Copy pipeline files ─────────────────────────────────────────────
step "Installing pipeline files"

# Core agent framework
cp -r "$SRC/.agents" "$TARGET/"
log ".agents/ — agents, context, handoff schema, security, skills"

# VS Code wiring
mkdir -p "$TARGET/.github"
cp -r "$SRC/.github/agents" "$TARGET/.github/"
cp -r "$SRC/.github/skills" "$TARGET/.github/"
cp "$SRC/.github/copilot-instructions.md" "$TARGET/.github/"
log ".github/ — VS Code agent wiring + skills"

# Spec templates
cp -r "$SRC/.specs" "$TARGET/"
log ".specs/ — epic, feature, and spec templates"

# Pipeline infrastructure
cp -r "$SRC/.pipeline" "$TARGET/"
log ".pipeline/ — checkpoint storage"

# Root files
cp "$SRC/AGENTS.md" "$TARGET/"
log "AGENTS.md — universal agent entry point"

# Empty log file
if [[ ! -f "$TARGET/pipeline.log.ndjson" ]]; then
  touch "$TARGET/pipeline.log.ndjson"
  log "pipeline.log.ndjson — empty event log"
else
  warn "pipeline.log.ndjson already exists — skipping"
fi

# ── VS Code configuration ───────────────────────────────────────────
step "Creating VS Code configuration"

mkdir -p "$TARGET/.vscode"

if [[ ! -f "$TARGET/.vscode/settings.json" ]]; then
  cat > "$TARGET/.vscode/settings.json" << 'EOF'
{
  "chat.agent.enabled": true,
  "chat.subagents.enabled": true,
  "github.copilot.chat.agent.runTasks": true
}
EOF
  log ".vscode/settings.json — agent mode enabled"
else
  warn ".vscode/settings.json already exists — skipping"
fi

if [[ ! -f "$TARGET/.vscode/mcp.json" ]]; then
  cat > "$TARGET/.vscode/mcp.json" << 'EOF'
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
EOF
  log ".vscode/mcp.json — Figma + GitHub MCP servers"
else
  warn ".vscode/mcp.json already exists — skipping"
fi

# ── Git setup ────────────────────────────────────────────────────────
step "Setting up git"

# Create develop branch if it doesn't exist
if git rev-parse --verify develop >/dev/null 2>&1; then
  warn "develop branch already exists"
elif git rev-parse HEAD >/dev/null 2>&1; then
  git branch develop
  log "Created develop branch from current HEAD"
else
  warn "No commits yet — develop branch will be created after initial commit"
fi

# Stage pipeline files
git add \
  .agents/ \
  .github/agents/ \
  .github/skills/ \
  .github/copilot-instructions.md \
  .specs/ \
  .pipeline/ \
  .vscode/ \
  AGENTS.md \
  pipeline.log.ndjson

# Commit
if git diff --cached --quiet; then
  warn "Nothing to commit — pipeline files already tracked"
else
  git commit -m "chore: bootstrap backstage agentic SDLC pipeline

Adds:
- .agents/ — agent definitions, context templates, handoff schema, security, skills
- .github/agents/ — VS Code Copilot agent wiring
- .github/skills/ — VS Code skill definitions
- .specs/ — spec lifecycle templates (epics, features, active, done)
- .pipeline/ — checkpoint storage for recovery
- .vscode/ — VS Code settings + MCP server configuration
- AGENTS.md — universal agent entry point
- pipeline.log.ndjson — append-only event log"
  log "Committed pipeline files"
fi

# Create develop if this was the first commit
if ! git rev-parse --verify develop >/dev/null 2>&1; then
  git branch develop
  log "Created develop branch"
fi

# ── Clean up self ────────────────────────────────────────────────────
# Remove this setup script from the target repo — it's not needed after install
if [[ -f "$TARGET/setup.sh" ]]; then
  rm "$TARGET/setup.sh"
  git add -u setup.sh 2>/dev/null || true
  git commit -m "chore: remove setup.sh after pipeline bootstrap" 2>/dev/null || true
  log "Removed setup.sh — no longer needed"
fi

# ── Done ─────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✓ Backstage pipeline installed${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo ""
echo -e "  1. Open this repo in VS Code"
echo -e "  2. Open Copilot chat → select ${CYAN}@init${NC} from the agent dropdown"
echo -e "  3. Answer the product questions — creates system.md + stack.md"
echo -e "  4. Switch to ${CYAN}@plan${NC} — decompose into specs"
echo -e "  5. Type ${CYAN}@pipeline /run${NC} and watch it go"
echo ""
echo -e "  Docs: ${BOLD}AGENTS.md${NC} · ${BOLD}.agents/README.md${NC}"
echo ""
