# EconStack

Claude Code skills for professional economic analysis.

## Skills

Each skill has its own directory with a `SKILL.md` defining the workflow.

- `io-report/SKILL.md` : Input-output economic impact assessment (UK)
- `la-profile/SKILL.md` : Local authority economic profile (UK)
- `fiscal-briefing/SKILL.md` : Public finances briefing (UK, US, Australia)
- `macro-briefing/SKILL.md` : Macroeconomic monitor (UK, US, Euro area, Australia; --international for 30-country comparison)
- `cost-benefit/SKILL.md` : Cost-benefit analysis (8 international frameworks)
- `vfm-eval/SKILL.md` : Value for Money evaluation (3Es/4Es, unit cost benchmarks, fiscal return, evidence grading)
- `business-case/SKILL.md` : Five Case Model business case (UK Green Book, Australian Commonwealth/Victoria HVHR/NSW/Queensland, NZ, EU, World Bank, US). Framework-native headings and terminology (e.g. VIC DTF 10-chapter structure, NSW component model, QLD 20-chapter BCDF). Interactive section picker.
- `econ-audit/SKILL.md` : Methodology audit (80+ checks, RED/AMBER/GREEN grading)

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

**Proactive detection:** If the user describes a task without naming a skill, match their intent to the routing table below. You do not need to wait for an explicit `/command`. For example, "I need to appraise three options for a new school" should auto-route to `/cost-benefit` or `/business-case` depending on context. "What's happening with UK inflation?" should route to `/macro-briefing`.

**Econstack routing rules:**
- CBA, appraisal, "is this worth it", discount rate, NPV, BCR, options appraisal → invoke cost-benefit
- Business case, Five Case Model, SOC, OBC, FBC, HVHR, strategic case, commercial case → invoke business-case
- VfM evaluation, "did it work", programme assessment, Magenta Book, 3Es, effectiveness → invoke vfm-eval
- Compare options, criteria, scoring, weighting, MCDA, AHP → invoke mca
- GDP, inflation, unemployment, wages, interest rates, macro, "what's happening with the economy" → invoke macro-briefing
- Borrowing, debt, deficit, budget, fiscal rules, public finances → invoke fiscal-briefing
- Market size, industry, competition, M&A, Porter's Five Forces, HHI → invoke market-research
- Economic impact, multiplier, jobs created, GVA, input-output → invoke io-report
- Local authority, council area, area profile, LA data → invoke la-profile
- Audit, check methodology, review my numbers, "is this analysis right" → invoke econ-audit


## Versioning

Econstack uses semver-lite. The current version is in `VERSION`.

- **MAJOR** (X.0.0): Breaking change to the parameter database schema, JSON `--from` schema, or skill invocation syntax. Anything that would break existing `--from` JSON files or require users to change how they call a skill.
- **MINOR** (0.X.0): New skill added, new framework added to an existing skill, or significant new capability (e.g. Monte Carlo, new output format, new jurisdiction).
- **PATCH** (0.0.X): Bug fixes, audit fixes, parameter updates, wording improvements, template tweaks, heading corrections.

Always bump VERSION in the same commit as the change. Include the new version in the commit message (e.g. "v0.5.0: Add /business-case skill").

## Learned State

Econstack remembers per-project preferences across sessions. Learnings are stored locally at `~/.econstack/projects/{slug}/learnings.jsonl`. No data is transmitted to any server.

**How it works:**
- Every skill's preamble runs `econstack-learnings-read` to load prior learnings (framework choices, parameter overrides, data preferences, past outputs, operational quirks)
- After a skill completes, new insights are logged via `econstack-learnings-log`
- Dedup by key+type (latest wins). Observed/inferred learnings decay 1 confidence point per 30 days. User-stated learnings never decay.
- Top 3 learnings are surfaced at the start of each skill run

**Bin scripts:**
- `bin/econstack-slug` : Derive project slug from git remote or cwd
- `bin/econstack-learnings-log` : Append a learning (validates JSON, auto-timestamps)
- `bin/econstack-learnings-read` : Read, dedup, decay, sort, and format learnings

**Learning types:** framework, parameter, data-source, output, operational, preference.

## Data Dependencies

**LA data:** The io-report and la-profile skills read multiplier and LA data from `~/econstack-data/src/data/`.

**CBA parameters:** The cost-benefit, io-report, and econ-audit skills read structured parameter files from `~/econstack-data/parameters/`. 14 JSON files covering UK, EU, and AU: discount rates, carbon values, VSL, QALY, VTTS, optimism bias, additionality, tax parameters, distributional weights, and construction benchmarks. Skills fall back to built-in defaults if parameter files are not found.
