#!/bin/bash
# render-report.sh: Convert an econstack markdown report to a branded PDF
#
# Usage: ./scripts/render-report.sh <report.md> [--title "Custom Title"] [--subtitle "Custom Subtitle"]
#
# Takes a markdown file, wraps it in the econstack Quarto template, and renders
# a branded PDF using Typst. Output goes to the same directory as the input file.
#
# Prerequisites: Quarto >= 1.5.0 (with Typst bundled)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ECONSTACK_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$ECONSTACK_DIR/templates/econstack-report"
QUARTO="${QUARTO_PATH:-/Applications/quarto/bin/quarto}"

# Check Quarto
if [ ! -x "$QUARTO" ]; then
  QUARTO="$(which quarto 2>/dev/null || true)"
  if [ -z "$QUARTO" ]; then
    echo "ERROR: Quarto not found. Install from https://quarto.org/docs/get-started/" >&2
    echo "Or set QUARTO_PATH=/path/to/quarto" >&2
    exit 1
  fi
fi

# Parse arguments
INPUT_FILE=""
TITLE=""
SUBTITLE=""
DATE="$(date +%Y-%m-%d)"
CONFIDENTIAL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --subtitle) SUBTITLE="$2"; shift 2 ;;
    --date) DATE="$2"; shift 2 ;;
    --confidential) CONFIDENTIAL="true"; shift ;;
    --help|-h)
      echo "Usage: render-report.sh <report.md> [--title \"Title\"] [--subtitle \"Sub\"] [--date YYYY-MM-DD] [--confidential]"
      exit 0
      ;;
    *)
      if [ -z "$INPUT_FILE" ]; then
        INPUT_FILE="$1"
      else
        echo "ERROR: Unexpected argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$INPUT_FILE" ]; then
  echo "ERROR: No input file specified." >&2
  echo "Usage: render-report.sh <report.md>" >&2
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "ERROR: File not found: $INPUT_FILE" >&2
  exit 1
fi

# Derive output paths
INPUT_DIR="$(cd "$(dirname "$INPUT_FILE")" && pwd)"
INPUT_BASENAME="$(basename "$INPUT_FILE" .md)"
QMD_FILE="$INPUT_DIR/${INPUT_BASENAME}.qmd"
PDF_FILE="$INPUT_DIR/${INPUT_BASENAME}.pdf"

# Auto-detect title from first H1 if not specified
if [ -z "$TITLE" ]; then
  TITLE="$(grep -m1 '^# ' "$INPUT_FILE" | sed 's/^# //' || echo 'EconStack Report')"
fi

# Auto-detect subtitle from first line after title that starts with **
if [ -z "$SUBTITLE" ]; then
  SUBTITLE="$(grep -m1 '^\*\*Prepared by\|^\*\*Local authority\|^\*\*Date' "$INPUT_FILE" | sed 's/\*\*//g' || true)"
fi

# Build YAML frontmatter
YAML="---
title: \"$TITLE\"
subtitle: \"$SUBTITLE\"
date: \"$DATE\"
format:
  econstack-typst:
    keep-typ: false
---"

# Combine frontmatter with report body (stripping any existing YAML and the first H1)
{
  echo "$YAML"
  echo ""
  # Skip existing YAML frontmatter if present
  if head -1 "$INPUT_FILE" | grep -q '^---$'; then
    sed '1,/^---$/d' "$INPUT_FILE" | sed '1,/^---$/d'
  else
    # Skip the first H1 line (it becomes the title)
    awk 'NR==1 && /^# /{next} {print}' "$INPUT_FILE"
  fi
} > "$QMD_FILE"

# Copy the extension into the working directory (Quarto requires extensions local to the .qmd)
mkdir -p "$INPUT_DIR/_extensions"
cp -r "$TEMPLATE_DIR/_extensions/econstack" "$INPUT_DIR/_extensions/"

# Render
echo "Rendering: $QMD_FILE -> $PDF_FILE"
"$QUARTO" render "$QMD_FILE" --quiet 2>&1

# Clean up
rm -f "$QMD_FILE"
rm -rf "$INPUT_DIR/_extensions"

if [ -f "$PDF_FILE" ]; then
  echo "PDF saved: $PDF_FILE ($(du -h "$PDF_FILE" | cut -f1))"
else
  echo "ERROR: PDF not generated" >&2
  exit 1
fi
