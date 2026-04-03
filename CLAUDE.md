# EconStack

Claude Code skills for professional economic analysis.

## Skills

Skills are in `skills/`. Each has a `SKILL.md` defining the workflow.

- `skills/impact-report/SKILL.md` : Economic impact assessment (IO model)
- `skills/la-profile/SKILL.md` : Local authority economic profile report
- `skills/macro-briefing/SKILL.md` : UK macroeconomic monitor (GDP, CPI, employment, rates)
- `skills/fiscal-briefing/SKILL.md` : Public finances briefing (borrowing, debt, receipts, spending)

## Important Rules

- Never include "Co-Authored-By: Claude" in commit messages
- Never use em dashes in prose. Use colons, periods, commas, or parentheses.
- Never connect econprofile.com or econstack to any individual person. Present as brands/products.
- Reports must always include methodology sections and caveats. Credibility comes from transparency.
- Type I multipliers are the default (conservative). Only use Type II when explicitly requested.
- Tax estimates always get the strongest caveats (30-50% margin of error).

## Data Dependencies

The impact-report skill reads multiplier and LA data from:
`/Users/charlescoverdale/Documents/2026/Claude/Sandbox/econprofile/src/data/`

This path is hardcoded in the skill. If the econprofile repo moves, update the paths in the SKILL.md files.
