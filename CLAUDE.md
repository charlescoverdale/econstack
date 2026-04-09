# EconStack

Claude Code skills for professional economic analysis.

## Skills

Each skill has its own directory with a `SKILL.md` defining the workflow.

- `cost-benefit/SKILL.md` : Cost-benefit analysis (8 international frameworks)
- `business-case/SKILL.md` : Five Case Model business case (UK, AU, NZ, EU, World Bank, US). Framework-native headings. Interactive section picker.
- `vfm-eval/SKILL.md` : Value for Money evaluation (3Es/4Es, unit cost benchmarks, fiscal return, evidence grading). AU framework support is structural only (ANAO 4Es headings); cost benchmarks use UK GMCA as proxy.
- `mca/SKILL.md` : Multi-criteria analysis and MCDA (tailored criteria, swing/AHP weighting, sensitivity)
- `io-report/SKILL.md` : Input-output economic impact assessment (UK: 391 LAs, Australia: 88 SA4 regions)
- `macro-briefing/SKILL.md` : Macroeconomic monitor (UK, US, Euro area, Australia; --international for 30-country comparison)
- `fiscal-briefing/SKILL.md` : Public finances briefing (UK, US, Australia)
- `market-research/SKILL.md` : Industry and market analysis (sizing, structure, competition, M&A, multi-geo)
- `la-profile/SKILL.md` : Local authority economic profile (UK, 391 areas)
- `briefing-note/SKILL.md` : Policy briefing note (1-2 pages, UK GES / AU Treasury / consulting / think-tank formats)
- `reg-impact/SKILL.md` : Regulatory Impact Assessment (UK Better Regulation, AU OIA RIS, EU, US OMB). Compliance costs, CBA per option, EANDCB, SaMBA, competition filter.
- `evaluate/SKILL.md` : Full programme evaluation (Magenta Book, AU Commonwealth/state, OECD DAC). Plans, mid-term, final, PIR. Process + impact + economic evaluation.
- `longlist/SKILL.md` : Pre-appraisal longlist builder. Brainstorms benefits and costs across 6 benefit lenses (stakeholder, market failure, ToC, framework taxonomy, sector library, Flyvbjerg-informed commonly-missed checklist) and 5 cost lenses (direct, indirect/induced, compliance/SCM, other parties, risk). Classifies each item as Strong/Moderate/Weak CBA contender. Framework-aware. Hands off a structured JSON shortlist to `/cost-benefit`, `/business-case`, `/vfm-eval`, or `/reg-impact`.
- `econ-audit/SKILL.md` : Methodology audit (124 checks across 17 categories, RED/AMBER/GREEN grading, includes AU framework checks)

**Preamble tiers:** All 14 skills get update check, learnings, safety hooks, and completion status. 10 skills (cost-benefit, business-case, vfm-eval, evaluate, reg-impact, io-report, mca, econ-audit, briefing-note, longlist) additionally get the parameter database check because they read from `~/econstack-data/parameters/`. The other 4 (macro-briefing, fiscal-briefing, la-profile, market-research) pull live data or LA-specific data and do not use the parameter database.

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
- Evaluation, "did it work", Magenta Book, evaluation plan, mid-term evaluation, PIR, process evaluation, impact evaluation → invoke evaluate
- Briefing note, policy brief, ministerial brief, "write me a 2-pager", decision brief → invoke briefing-note
- Regulatory impact, RIA, RIS, impact assessment, compliance cost, EANDCB, "new regulation" → invoke reg-impact
- Brainstorm benefits, longlist, what costs should I include, beneficiary mapping, "what am I missing", benefit streams, benefits register, pre-CBA scoping, pre-appraisal scoping → invoke longlist
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

**AU IO data:** The io-report skill reads Australian SA4 multipliers from `~/econstack-data/src/data/au/sa4/` and national IO data from `~/econstack-data/src/data/au/national-io.json`.

**CBA parameters:** The cost-benefit, business-case, io-report, mca, vfm-eval, evaluate, and econ-audit skills read structured parameter files from `~/econstack-data/parameters/`. 57 JSON files covering UK, US, EU, AU, World Bank, ADB, and common parameters: discount rates, carbon values, VSL, QALY, VTTS, optimism bias, additionality, tax parameters, distributional weights, construction benchmarks, unit costs for outcome monetisation, IO metadata, and 8 reference case templates for common asset types. Skills fall back to built-in defaults if parameter files are not found.

**Reference cases:** 8 asset-type templates in `~/econstack-data/parameters/reference-cases/` (schools, hospitals, roads, rail, housing, employment programmes, digital, AU transport). Each includes cost benchmarks, benefit categories, default parameters, published BCR ranges from real business cases, and typical risks. Used by `/cost-benefit` and `/business-case` to pre-populate inputs for common project types.

**Trade data:** The market-research, io-report, and macro-briefing skills optionally use the `comtrade` R package for UN Comtrade trade flow data. Install from GitHub: `devtools::install_github("charlescoverdale/comtrade")`. Works without an API key for basic queries (500 records). For full access, register for a free key at <https://comtradedeveloper.un.org/>. If comtrade is not installed, skills fall back to WebSearch for trade data.
