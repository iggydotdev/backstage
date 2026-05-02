#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# Backstage Pipeline — Setup Script
#
# Bootstraps the agentic SDLC pipeline into a target repository.
#
# Usage:
#   ./setup.sh /path/to/target/repo
#
# What it does:
#   1. Copies .agents/, .github/, .specs/, .pipeline/, AGENTS.md
#   2. Creates pipeline.log.ndjson (empty)
#   3. Creates .vscode/settings.json and .vscode/mcp.json templates
#   4. Creates develop branch if it doesn't exist
#   5. Makes an initial commit with all pipeline files
# ──────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"

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
if [[ -z "$TARGET" ]]; then
  echo -e "${BOLD}Backstage Pipeline — Setup${NC}"
  echo ""
  echo "Usage: $0 /path/to/target/repo"
  echo ""
  echo "Bootstraps the agentic SDLC pipeline into an existing git repository."
  echo "The target directory must already be a git repo (or empty for git init)."
  exit 1
fi

# Resolve to absolute path
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || {
  err "Target directory does not exist: $1"
  exit 1
}

# Check it's a git repo (or offer to init)
if [[ ! -d "$TARGET/.git" ]]; then
  warn "Target is not a git repository."
  read -rp "   Initialise git in $TARGET? [y/N] " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    git -C "$TARGET" init
    log "Initialised git repository"
  else
    err "Aborted — target must be a git repository."
    exit 1
  fi
fi

# Check for existing .agents/ (don't clobber)
if [[ -d "$TARGET/.agents" ]]; then
  warn "Target already has .agents/ directory."
  read -rp "   Overwrite existing pipeline files? [y/N] " yn
  if [[ ! "$yn" =~ ^[Yy]$ ]]; then
    err "Aborted — will not overwrite existing pipeline."
    exit 1
  fi
fi

# ── Copy pipeline files ─────────────────────────────────────────────
step "Copying pipeline files"

# Core agent framework
cp -r "$SCRIPT_DIR/.agents" "$TARGET/"
log ".agents/ — agents, context, handoff schema, security, skills"

# VS Code wiring
mkdir -p "$TARGET/.github"
cp -r "$SCRIPT_DIR/.github/agents" "$TARGET/.github/"
cp -r "$SCRIPT_DIR/.github/skills" "$TARGET/.github/"
cp "$SCRIPT_DIR/.github/copilot-instructions.md" "$TARGET/.github/"
log ".github/ — VS Code agent wiring + skills"

# Spec templates
cp -r "$SCRIPT_DIR/.specs" "$TARGET/"
log ".specs/ — epic, feature, and spec templates"

# Pipeline infrastructure
cp -r "$SCRIPT_DIR/.pipeline" "$TARGET/"
log ".pipeline/ — checkpoint storage"

# Root files
cp "$SCRIPT_DIR/AGENTS.md" "$TARGET/"
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

cd "$TARGET"

# Create develop branch if it doesn't exist
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

if git rev-parse --verify develop >/dev/null 2>&1; then
  warn "develop branch already exists"
elif git rev-parse HEAD >/dev/null 2>&1; then
  # Repo has at least one commit — create develop from current HEAD
  git branch develop
  log "Created develop branch from current HEAD"
else
  warn "No commits yet — develop branch will be created after initial commit"
fi

# Stage everything
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

# Create develop if repo just got its first commit
if ! git rev-parse --verify develop >/dev/null 2>&1; then
  git branch develop
  log "Created develop branch"
fi

# ── Done ─────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✓ Backstage pipeline installed successfully${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo ""
echo -e "  1. Open the repo in VS Code"
echo -e "  2. Open Copilot chat → select ${CYAN}@init${NC} from agent dropdown"
echo -e "  3. Answer the product questions — creates system.md + stack.md"
echo -e "  4. Switch to ${CYAN}@plan${NC} — decompose into specs"
echo -e "  5. Type ${CYAN}@pipeline /run${NC} — watch the magic happen"
echo ""
echo -e "  Full docs: ${BOLD}AGENTS.md${NC} and ${BOLD}.agents/README.md${NC}"
echo ""
