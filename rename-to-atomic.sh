#!/usr/bin/env bash
# rename-to-atomic.sh
# Renames .agents/ subfolders to match atomic design language.
# Safe to run multiple times — uses cp not mv, originals untouched until you confirm.
# Run from repo root.

set -euo pipefail

echo ""
echo "🔬 Aligning .agents/ to atomic design structure..."
echo ""

# Create target dirs
mkdir -p .agents/atoms .agents/molecules .agents/organisms

ERRORS=0

copy_if_exists() {
  local SRC="$1"
  local DST="$2"
  if [ -f "$SRC" ]; then
    cp "$SRC" "$DST"
    echo "  ✅ $SRC → $DST"
  else
    echo "  ⚠️  NOT FOUND: $SRC (skipped)"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "  — Atoms (from .agents/skills/atoms/ or .agents/atoms/)"

# Try old location first, then new
for ATOM in \
  "build-handoff" \
  "check-dod" \
  "create-branch" \
  "fetch-figma-nodes" \
  "archive-spec" \
  "recover-pipeline" \
  "run-e2e-tests" \
  "create-regression-ticket" \
  "prepare-context-slice" \
  "eval-pipeline"
do
  if [ -f ".agents/skills/atoms/${ATOM}.md" ]; then
    cp ".agents/skills/atoms/${ATOM}.md" ".agents/atoms/${ATOM}.md"
    echo "  ✅ .agents/skills/atoms/${ATOM}.md → .agents/atoms/${ATOM}.md"
  elif [ -f ".agents/atoms/${ATOM}.md" ]; then
    echo "  ℹ️  .agents/atoms/${ATOM}.md — already in place"
  else
    echo "  ⚠️  Atom not found: ${ATOM} (check .agents/skills/atoms/)"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""
echo "  — Molecules (from .agents/agents/)"

copy_if_exists ".agents/agents/developer/red.md"      ".agents/molecules/red.md"
copy_if_exists ".agents/agents/developer/green.md"    ".agents/molecules/green.md"
copy_if_exists ".agents/agents/developer/blue.md"     ".agents/molecules/blue.md"
copy_if_exists ".agents/agents/qa/orchestrator.md"    ".agents/molecules/qa.md"
copy_if_exists ".agents/agents/architect.md"          ".agents/molecules/architect.md"
copy_if_exists ".agents/agents/ba.md"                 ".agents/molecules/ba.md"
copy_if_exists ".agents/agents/onboarding.md"         ".agents/molecules/onboarding.md"

echo ""
echo "  — Organisms (from .agents/agents/)"

copy_if_exists ".agents/agents/pipeline-orchestrator.md"    ".agents/organisms/pipeline.md"

# Developer orchestrator may be in different locations
if [ -f ".agents/agents/developer/orchestrator.md" ]; then
  cp ".agents/agents/developer/orchestrator.md" ".agents/organisms/developer.md"
  echo "  ✅ .agents/agents/developer/orchestrator.md → .agents/organisms/developer.md"
elif [ -f ".agents/agents/developer-orchestrator.md" ]; then
  cp ".agents/agents/developer-orchestrator.md" ".agents/organisms/developer.md"
  echo "  ✅ .agents/agents/developer-orchestrator.md → .agents/organisms/developer.md"
else
  echo "  ⚠️  Developer orchestrator not found — check your agents folder structure"
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "  — Context files (verify these exist)"
for CTX in system.md stack.md decisions.md domain.md; do
  if [ -f ".agents/context/$CTX" ]; then
    echo "  ✅ .agents/context/$CTX"
  else
    echo "  ⚠️  .agents/context/$CTX — NOT FOUND (needs filling in)"
  fi
done

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "✅ All files copied successfully."
else
  echo "⚠️  $ERRORS file(s) not found — check paths above."
  echo "   Some atoms/molecules may have different names in your repo."
fi

echo ""
echo "Next steps:"
echo "  1. Verify the copies look correct"
echo "  2. Update any references in .agents/organisms/*.md that point to old paths"
echo "  3. Once happy, remove old folders:"
echo "     # rm -rf .agents/agents/ .agents/skills/atoms/"
echo "  4. git add .agents/ && git commit -m 'refactor(agents): align to atomic design structure'"
echo ""
