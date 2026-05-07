#!/usr/bin/env bash
#
# gen-skill-docs.sh - Generate SKILL.md from SKILL.tmpl + shared template blocks
#
# Usage:
#   ./scripts/gen-skill-docs.sh              # Generate all SKILL.md files
#   ./scripts/gen-skill-docs.sh --dry-run    # Show what would change, don't write
#   ./scripts/gen-skill-docs.sh --check      # Exit non-zero if any SKILL.md is stale
#   ./scripts/gen-skill-docs.sh longlist     # Generate one skill only
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BLOCKS_DIR="$ROOT_DIR/templates/blocks"

DRY_RUN=false
CHECK_ONLY=false
TARGET_SKILL=""

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --check)   CHECK_ONLY=true ;;
    -*)        echo "Unknown flag: $arg" >&2; exit 1 ;;
    *)         TARGET_SKILL="$arg" ;;
  esac
done

# Load template blocks into variables
load_block() {
  local file="$BLOCKS_DIR/$1"
  if [ ! -f "$file" ]; then
    echo "ERROR: Template block not found: $file" >&2
    exit 1
  fi
  cat "$file"
}

PREAMBLE="$(load_block preamble.md)"
LEARNINGS="$(load_block learnings.md)"
PARAMETER_CHECK="$(load_block parameter-check.md)"
SAFETY_HOOKS="$(load_block safety-hooks.md)"
COMPLETION_STATUS="$(load_block completion-status.md)"
FORMATTING_RULES="$(load_block formatting-rules.md)"
IMPORTANT_RULES_BASE="$(load_block important-rules-base.md)"
FORMAT_DISPATCHER="$(load_block format-dispatcher.md)"
# exec-format-spec.md exists as reference but is not used as a placeholder.
# Skills that need exec formatting have it inline (tailored per skill).

# Find all skills with .tmpl files
SKILLS=()
if [ -n "$TARGET_SKILL" ]; then
  if [ ! -f "$ROOT_DIR/$TARGET_SKILL/SKILL.tmpl" ]; then
    echo "ERROR: No SKILL.tmpl found for skill: $TARGET_SKILL" >&2
    exit 1
  fi
  SKILLS=("$TARGET_SKILL")
else
  for tmpl in "$ROOT_DIR"/*/SKILL.tmpl; do
    skill_name="$(basename "$(dirname "$tmpl")")"
    SKILLS+=("$skill_name")
  done
fi

if [ ${#SKILLS[@]} -eq 0 ]; then
  echo "No SKILL.tmpl files found. Nothing to generate." >&2
  exit 0
fi

STALE_COUNT=0
GENERATED_COUNT=0

for skill in "${SKILLS[@]}"; do
  tmpl_file="$ROOT_DIR/$skill/SKILL.tmpl"
  output_file="$ROOT_DIR/$skill/SKILL.md"

  # Read template into a temp file and do replacements
  tmp_file="$(mktemp)"
  cp "$tmpl_file" "$tmp_file"

  # Replace each placeholder with its block content using python for reliable multiline handling
  python3 -c "
import sys
with open('$tmp_file', 'r') as f:
    content = f.read()
blocks = {
    '{{PREAMBLE}}': open('$BLOCKS_DIR/preamble.md').read(),
    '{{LEARNINGS}}': open('$BLOCKS_DIR/learnings.md').read(),
    '{{PARAMETER_CHECK}}': open('$BLOCKS_DIR/parameter-check.md').read(),
    '{{SAFETY_HOOKS}}': open('$BLOCKS_DIR/safety-hooks.md').read(),
    '{{COMPLETION_STATUS}}': open('$BLOCKS_DIR/completion-status.md').read(),
    '{{FORMATTING_RULES}}': open('$BLOCKS_DIR/formatting-rules.md').read(),
    '{{IMPORTANT_RULES_BASE}}': open('$BLOCKS_DIR/important-rules-base.md').read(),
    '{{FORMAT_DISPATCHER}}': open('$BLOCKS_DIR/format-dispatcher.md').read(),
}
for placeholder, block in blocks.items():
    content = content.replace(placeholder, block)
with open('$tmp_file', 'w') as f:
    f.write(content)
"
  content="$(cat "$tmp_file")"
  rm -f "$tmp_file"

  if $CHECK_ONLY; then
    # Compare with existing SKILL.md
    if [ -f "$output_file" ]; then
      existing="$(cat "$output_file")"
      if [ "$content" != "$existing" ]; then
        echo "STALE: $skill/SKILL.md (run gen-skill-docs.sh to regenerate)" >&2
        STALE_COUNT=$((STALE_COUNT + 1))
      fi
    else
      echo "MISSING: $skill/SKILL.md (run gen-skill-docs.sh to generate)" >&2
      STALE_COUNT=$((STALE_COUNT + 1))
    fi
  elif $DRY_RUN; then
    if [ -f "$output_file" ]; then
      existing="$(cat "$output_file")"
      if [ "$content" != "$existing" ]; then
        echo "WOULD UPDATE: $skill/SKILL.md"
        diff <(echo "$existing") <(echo "$content") || true
        echo "---"
      else
        echo "UP TO DATE: $skill/SKILL.md"
      fi
    else
      echo "WOULD CREATE: $skill/SKILL.md"
    fi
  else
    # Write the generated file
    echo "$content" > "$output_file"
    GENERATED_COUNT=$((GENERATED_COUNT + 1))
    echo "Generated: $skill/SKILL.md"
  fi
done

if $CHECK_ONLY; then
  if [ $STALE_COUNT -gt 0 ]; then
    echo "$STALE_COUNT skill(s) are stale. Run: scripts/gen-skill-docs.sh" >&2
    exit 1
  else
    echo "All skill docs are up to date."
    exit 0
  fi
elif ! $DRY_RUN; then
  echo "Done. Generated $GENERATED_COUNT skill doc(s)."
fi
