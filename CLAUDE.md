# EconStack

Claude Code skills for professional economic analysis.

## Skills

Each skill has its own directory with a `SKILL.md` defining the workflow.

- `io-report/SKILL.md` : Input-output economic impact assessment (UK)
- `la-profile/SKILL.md` : Local authority economic profile (UK)
- `fiscal-briefing/SKILL.md` : Public finances briefing (UK, US, Australia)
- `macro-briefing/SKILL.md` : Macroeconomic monitor (UK, US, Euro area, Australia; --international for 30-country comparison)
- `cost-benefit/SKILL.md` : Cost-benefit analysis (8 international frameworks)
- `econ-audit/SKILL.md` : Methodology audit (60+ checks, RED/AMBER/GREEN grading)

## Important Rules

- Never include "Co-Authored-By: Claude" in commit messages
- Never use em dashes in prose. Use colons, periods, commas, or parentheses.
- Never connect econstack to any individual person. Present as a brand/product.
- Reports must always include methodology sections and caveats. Credibility comes from transparency.
- Type I multipliers are the default (conservative). Only use Type II when explicitly requested.
- Tax estimates always get the strongest caveats (30-50% margin of error).

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health

## Data Dependencies

**LA data:** The io-report and la-profile skills read multiplier and LA data from `~/econstack-data/src/data/`.

**CBA parameters:** The cost-benefit, io-report, and econ-audit skills read structured parameter files from `~/econstack-data/parameters/`. 14 JSON files covering UK, EU, and AU: discount rates, carbon values, VSL, QALY, VTTS, optimism bias, additionality, tax parameters, distributional weights, and construction benchmarks. Skills fall back to built-in defaults if parameter files are not found.
