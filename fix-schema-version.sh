#!/usr/bin/env bash
# fix-schema-version.sh
# Fixes the schemaVersion mismatch in legacy build-handoff atom files.
# Run from repo root.

set -euo pipefail

echo ""
echo "🔧 Fixing schemaVersion mismatch..."
echo ""

FIXED=0

# Check all likely locations for the legacy build-handoff atom
FILES=(
  ".agents/skills/atoms/build-handoff.md"
  ".agents/atoms/build-handoff.md"
  ".agents/agents/build-handoff.md"
  ".github/skills/build-handoff/SKILL.md"
)

for FILE in "${FILES[@]}"; do
  if [ -f "$FILE" ]; then
    if grep -q '"schemaVersion": "1.0.0"' "$FILE"; then
      sed -i 's/"schemaVersion": "1.0.0"/"schemaVersion": "1.4.0"/g' "$FILE"
      echo "  ✅ Fixed: $FILE"
      FIXED=$((FIXED + 1))
    elif grep -q '"schemaVersion"' "$FILE"; then
      CURRENT=$(grep '"schemaVersion"' "$FILE" | head -1)
      echo "  ℹ️  $FILE — schemaVersion found but not 1.0.0: $CURRENT"
      echo "     Verify this is correct (expected 1.4.0)"
    else
      echo "  ⚠️  $FILE — no schemaVersion field found (may need manual check)"
    fi
  fi
done

# Also do a broad search in case the file is somewhere else
echo ""
echo "  Broad search for schemaVersion 1.0.0 across .agents/..."
FOUND=$(grep -rl '"schemaVersion": "1.0.0"' .agents/ 2>/dev/null || true)

if [ -n "$FOUND" ]; then
  echo "  Found in:"
  echo "$FOUND" | while read -r F; do
    sed -i 's/"schemaVersion": "1.0.0"/"schemaVersion": "1.4.0"/g' "$F"
    echo "    ✅ Fixed: $F"
    FIXED=$((FIXED + 1))
  done
else
  echo "  None found."
fi

echo ""
if [ "$FIXED" -gt 0 ]; then
  echo "✅ Fixed $FIXED file(s). Commit the changes:"
  echo "   git add -A && git commit -m 'fix(pipeline): correct schemaVersion to 1.4.0'"
else
  echo "ℹ️  Nothing to fix — either already correct or no files found."
  echo "   Manually verify any build-handoff files contain schemaVersion 1.4.0."
fi
echo ""
