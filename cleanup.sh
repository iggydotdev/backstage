#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# cleanup.sh
# Migrates the old scattered agent files into the correct .agents/ structure.
# Safe to run multiple times — checks before moving or deleting.
#
# Usage:
#   chmod +x cleanup.sh
#   ./cleanup.sh
#
# Run from the repo root.
# -----------------------------------------------------------------------------

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
AGENTS="$ROOT/.agents"

echo ""
echo "🤖 Agent pipeline — repo cleanup"
echo "Root: $ROOT"
echo ""

# -----------------------------------------------------------------------------
# 1. Ensure target directory structure exists
# -----------------------------------------------------------------------------
echo "📁 Creating .agents/ structure..."

mkdir -p "$AGENTS/handoff"
mkdir -p "$AGENTS/context"
mkdir -p "$AGENTS/agents/developer"
mkdir -p "$AGENTS/agents/qa"
mkdir -p "$AGENTS/skills/atoms"

echo "   ✓ Directories ready"
echo ""

# -----------------------------------------------------------------------------
# 2. Move files from old locations to correct locations
#    Format: move_file "<source>" "<destination>"
# -----------------------------------------------------------------------------
move_file() {
  local src="$ROOT/$1"
  local dst="$ROOT/$2"

  if [ -f "$src" ]; then
    if [ -f "$dst" ]; then
      echo "   ⚠️  Skipped (destination already exists): $2"
      echo "      → Review manually: $1 vs $2"
    else
      mv "$src" "$dst"
      echo "   ✓ Moved: $1 → $2"
    fi
  else
    echo "   –  Not found (already moved or never existed): $1"
  fi
}

echo "📦 Moving files to .agents/..."
echo ""

# Developer agents
move_file "PR/red.md"                              ".agents/agents/developer/red.md"
move_file "PR/green.md"                            ".agents/agents/developer/green.md"
move_file "PR/blue.md"                             ".agents/agents/developer/blue.md"
move_file "shortcodes/developer/orchestrator.md"   ".agents/agents/developer/orchestrator.md"

# Onboarding
move_file "onboarding-agent/agents/onboarding.md"  ".agents/agents/onboarding.md"

# Handoff schema
move_file "handoff/schema.md"                      ".agents/handoff/schema.md"

echo ""

# -----------------------------------------------------------------------------
# 3. Remove old empty directories
# -----------------------------------------------------------------------------
echo "🗑️  Removing old directories..."
echo ""

remove_dir() {
  local dir="$ROOT/$1"
  if [ -d "$dir" ]; then
    if [ -z "$(ls -A "$dir")" ]; then
      rm -rf "$dir"
      echo "   ✓ Removed empty dir: $1"
    else
      echo "   ⚠️  Not empty — leaving for manual review: $1"
      echo "      Contents:"
      ls "$dir" | sed 's/^/         /'
    fi
  else
    echo "   –  Already gone: $1"
  fi
}

remove_dir "PR"
remove_dir "shortcodes/developer"
remove_dir "shortcodes"
remove_dir "onboarding-agent/agents"
remove_dir "onboarding-agent"
remove_dir "handoff"

echo ""

# -----------------------------------------------------------------------------
# 4. Ensure AGENTS.md is at repo root
# -----------------------------------------------------------------------------
echo "📄 Checking AGENTS.md..."

if [ -f "$ROOT/AGENTS.md" ]; then
  echo "   ✓ AGENTS.md already at root"
else
  echo "   ⚠️  AGENTS.md missing from root — please generate it"
fi

echo ""

# -----------------------------------------------------------------------------
# 5. Validate final structure
# -----------------------------------------------------------------------------
echo "✅ Validating final structure..."
echo ""

check_file() {
  local path="$ROOT/$1"
  if [ -f "$path" ]; then
    echo "   ✓ $1"
  else
    echo "   ✗ MISSING: $1"
  fi
}

check_file "AGENTS.md"
check_file ".agents/README.md"
check_file ".agents/handoff/schema.md"
check_file ".agents/agents/onboarding.md"
check_file ".agents/agents/developer/orchestrator.md"
check_file ".agents/agents/developer/red.md"
check_file ".agents/agents/developer/green.md"
check_file ".agents/agents/developer/blue.md"
check_file ".agents/agents/qa/orchestrator.md"
check_file ".agents/skills/atoms/create-regression-ticket.md"
check_file ".agents/skills/atoms/run-e2e-tests.md"

echo ""

# -----------------------------------------------------------------------------
# 6. Stage changes for review
# -----------------------------------------------------------------------------
echo "📝 Staging changes for your review..."
echo ""
git -C "$ROOT" add -A
git -C "$ROOT" status --short

echo ""
echo "Review the changes above, then commit with:"
echo ""
echo "  git commit -m \"chore(agents): consolidate pipeline files into .agents/\""
echo ""
echo "Done. 🎉"
