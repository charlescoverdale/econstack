# EconStack

Claude Code skills for professional economic analysis.

## Skills

Each skill has its own directory with a `SKILL.md` defining the workflow.

- `impact-report/SKILL.md` : Economic impact assessment (IO model)
- `la-profile/SKILL.md` : Local authority economic profile report
- `macro-briefing/SKILL.md` : UK macroeconomic monitor (GDP, CPI, employment, rates)
- `fiscal-briefing/SKILL.md` : Public finances briefing (borrowing, debt, receipts, spending)
- `cost-benefit/SKILL.md` : Green Book cost-benefit analysis (NPV, BCR, optimism bias, sensitivity)

## Important Rules

- Never include "Co-Authored-By: Claude" in commit messages
- Never use em dashes in prose. Use colons, periods, commas, or parentheses.
- Never connect econstack to any individual person. Present as a brand/product.
- Reports must always include methodology sections and caveats. Credibility comes from transparency.
- Type I multipliers are the default (conservative). Only use Type II when explicitly requested.
- Tax estimates always get the strongest caveats (30-50% margin of error).

## Data Dependencies

The impact-report and la-profile skills read multiplier and LA data from a local data directory. The path is configured in each SKILL.md file. Update it if your data is in a different location.
