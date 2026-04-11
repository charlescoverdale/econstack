# econstack

![Version](https://img.shields.io/badge/version-0.12.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Skills](https://img.shields.io/badge/skills-14-orange)
![Frameworks](https://img.shields.io/badge/frameworks-5-red)

Economic analysis skills for Claude Code.

econstack is a set of [Claude Code](https://claude.ai/code) skills for professional economic analysis: cost-benefit analysis, business cases, evaluations, regulatory impact assessments, multi-criteria analysis, and macro briefings. You describe your project; the skill does the structuring, computation, and formatting. You review and edit from there.

Built on 16 R packages on CRAN and a local parameter database covering the UK, EU, World Bank, ADB, and Victorian Treasury frameworks. Everything runs locally through Claude Code. No API keys. No uploads. Your inputs and outputs stay on your machine.

## Quick start

```bash
git clone https://github.com/charlescoverdale/econstack.git ~/.claude/skills/econstack
git clone https://github.com/charlescoverdale/econstack-data.git ~/econstack-data
```

Claude Code discovers the skills automatically. Install and start typing: `/longlist "New secondary school in Leeds"` or `/cost-benefit` or `/macro-briefing --country uk`.

If you already have a report, model, or output format you like, point the skill at it and it will adapt to match your structure and style. Your previous work becomes the template for future analyses.

---

## Frameworks

Every appraisal skill supports the same five frameworks. You pick via `--framework` or the skill auto-detects from your project description.

| Flag | Framework | Use when |
|---|---|---|
| `uk-gb` | UK HM Treasury Green Book (2022, with Wellbeing supplementary 2021) | Default. UK public investment, programmes, infrastructure, place-based interventions. |
| `eu-brg` | EU Better Regulation Guidelines (2021, SWD(2021) 305) | EU regulations, directives, EU-level interventions. SME test, fundamental rights, REFIT. |
| `wb` | World Bank Economic Analysis of Investment Operations (OP 10.04, 2023 guidance) | World Bank-financed projects. Economic rate of return, distributional incidence, poverty impact. |
| `adb` | Asian Development Bank Guidelines for the Economic Analysis of Projects (2017) | ADB-financed projects. 9% EIRR hurdle (6% for climate, health, education), poverty and gender disaggregation. |
| `au-vic` | Victorian Treasury High Value High Risk (HVHR) | Victorian Government projects above the HVHR threshold. Investment Logic Map, Benefit Management Plan, six-gate assurance. |

Framework defaults are applied automatically: the right discount rate, the right unit values (VSL, QALY, shadow wages, carbon prices), the right additionality conventions, and the right optimism bias uplift for the jurisdiction.

**Note**: `/reg-impact` supports only `uk-gb`, `eu-brg`, and `au-vic` (regulatory impact statement version, not HVHR). World Bank and ADB do not produce regulatory impact assessments.

---

## Output formats

Every skill generates markdown by default, and can also export to Excel, Word, PowerPoint, or PDF via `--format`.

| Format | Flag | Use |
|---|---|---|
| Markdown | default | Always generated. Plain text you can paste into any editor, issue tracker, or wiki. |
| Excel | `--format xlsx` | Spreadsheet workbook with blue input cells, linked formulas, conditional formatting on ratings, and scenario toggles. Re-run scenarios without re-invoking the skill. |
| Word | `--format word` | Formatted document for editing in Microsoft Word. Hyperlinked references. |
| PowerPoint | `--format pptx` | Slide deck with action titles (sentences stating the insight) and 3-4 evidence bullets per slide. The kind of deck you'd take to a board, minister, or investment committee. |
| PDF | `--format pdf` | Consulting-quality PDF rendered through Quarto. |
| All | `--format all` | All of the above. |

Combine formats with commas: `--format xlsx,word,pptx`.

---

## Section selection

The default output for each skill is one clean deliverable: all the sections a first-time user needs, nothing they don't. Power users can select just the sub-components they want via `--section`.

For example:
```
/mca ... --section matrix       # just the scoring table, not the full MCA
/cost-benefit ... --section verdict,sensitivity   # headline and sensitivity only
/vfm-eval ... --section scorecard      # just the 4 E's scorecard
```

Every skill lists its supported sub-components in its own `--help` or SKILL.md. Combinable with commas.

---

## The skills

The skills fall into four groups: **brainstorming and appraisal**, **wrapping and evaluation**, **briefings and market analysis**, and **audit**.

### Brainstorming and appraisal

**`/longlist` — the messy-whiteboard phase before any appraisal.** Describe your project and it brainstorms every benefit and cost you should consider, classifies each by materiality (High / Medium / Low), suggests how to quantify and monetise each, and tags each item as `Cash in`, `Cash out`, or `Non-cash` from the sponsor's perspective (so the downstream CBA can distinguish economic welfare from financial viability). Output is two clean tables you can hand straight to `/cost-benefit`.

```
/longlist "Climate adaptation via parks and green corridors in Milan"
/longlist "Rural water supply project, Indonesia" --framework adb
```

**`/cost-benefit` — develops NPV models at both economic and financial level.** Takes a longlist (or a rough project description) and produces two parallel answers. The **economic case** is a Green Book-style NPV with BCR, optimism bias, additionality adjustments, and sensitivity analysis. The **financial case** uses only the cash items (cash in minus cash out, at the sponsor's cost of capital) to compute Financial NPV, payback period, total funding requirement, and DSCR if the project takes on debt. The headline verdict tells you in one line whether the project is socially worthwhile **and** financially self-sustaining. A public park has a positive economic NPV but a negative financial NPV: the skill spells out exactly why, and tells you how much public subsidy the project needs.

```
/cost-benefit                                    # interactive walkthrough
/cost-benefit --from longlist-schools-2026-04-10.md
/cost-benefit --framework wb --format xlsx,pptx
```

**`/mca` — multi-criteria analysis when you can't (or shouldn't) monetise everything.** You describe your decision problem, the skill either takes your own criteria and scores or helps you brainstorm criteria with descriptors specific to your context. It then scores each option, applies weights, and outputs one ranked scoring matrix with a one-line verdict and a sensitivity paragraph. Good for early-stage option sifting, site selection, technology choice, or anything where the main trade-offs are environmental, social, or strategic. Use `--rigorous` for Green Book MCDA compliance (0-100 scale, swing weighting).

```
/mca "Choose between 3 sites for a new hospital in Leeds"
/mca "5 renewable energy technologies for a rural council" --format xlsx
/mca "Compare 4 regulatory options for online safety" --rigorous
```

**`/business-case` — guides you through a full Five Case Model business case.** Walks you through the structured thinking: options vs counterfactual, preferred option selection, consistency across the five cases. The **Strategic Case** frames the problem and options. The **Economic Case** delegates to `/cost-benefit` for the numbers. The **Commercial Case** covers deliverability and procurement. The **Financial Case** covers affordability. The **Management Case** covers the plan to deliver. Cross-case consistency checks flag any mismatches between the financial and economic costs, the benefits register and realisation plan, and the risk register and economic case risk costs. Scales by stage (Strategic OC, Outline BC, Full BC) and proportionality (under GBP 1m to over GBP 100m).

```
/business-case "New hospital wing in Greater Manchester" --stage obc
/business-case --framework au-vic --stage fbc
/business-case --from longlist-schools-2026-04-10.md
```

**`/reg-impact` — regulatory impact assessment for proposed legislation.** Applies the Standard Cost Model for compliance costs, runs the framework-specific tests (EANDCB and Small and Micro Business Impact for UK, SME test and Fundamental Rights for EU, Regulatory Change Measurement for Victoria), and produces a compact RIA with a single recommendation. The output covers problem definition, options (including Do Nothing), cost-benefit summary per option, framework tests, sensitivity, post-implementation review plan, and a one-line verdict. Not supported under `wb` or `adb` (they do project appraisal, not regulatory impact).

```
/reg-impact "Mandatory climate risk disclosure for listed companies"
/reg-impact "Ban on single-use plastics" --framework eu-brg
```

### Wrapping and evaluation

**`/vfm-eval` — ex-post value for money evaluation.** Where `/cost-benefit` asks "should we do this?" (ex-ante), `/vfm-eval` asks "did it work? was it worth the money?" (ex-post). Produces a 4 E's scorecard (Economy, Efficiency, Effectiveness, Equity) with a headline VfM rating, one paragraph per dimension, a sensitivity paragraph, and a recommendation. Can import a `/cost-benefit` output via `--with-cba` to inherit the BCR.

```
/vfm-eval "DESNZ Industrial Energy Transformation Fund, GBP 500m"
/vfm-eval --with-cba cba-ietf-2026-04-10.md
/vfm-eval --section narrative          # Spending Review style narrative
```

**`/evaluate` — design a programme evaluation before, during, or after the programme runs.** Covers evaluation plan (pre-programme), mid-term (formative), final (summative), and post-implementation review. Includes a counterfactual method decision tree (RCT, DiD, RDD, PSM, synthetic control, ITS, plus theory-based methods like Contribution Analysis and Realist Evaluation) and Theory of Change testing with assumption-by-assumption evidence assessment.

```
/evaluate "National Apprenticeship Programme" --type final
/evaluate --type plan "New early years pilot"
```

### Briefings and market analysis

**`/macro-briefing` — structured macroeconomic briefing.** Pulls live data for UK, US, Euro area, or Australia from official sources (ONS, FRED, ECB, ABS), follows each central bank's reporting structure (BoE MPR, FOMC, ECB Bulletin, RBA SoMP), and produces a one-page briefing with a traffic-light assessment. Good before a ministerial meeting, investment committee, or exam.

```
/macro-briefing                          # UK by default
/macro-briefing --country us
/macro-briefing --international          # add cross-country comparison
```

**`/fiscal-briefing` — structured public finances briefing.** Borrowing, debt, receipts by tax, spending by category, fiscal rules, outlook. Supports UK, US, and Australia. Optional debt sustainability analysis via the `debtkit` R package.

```
/fiscal-briefing                         # UK
/fiscal-briefing --country au --dsa
```

**`/market-research` — industry and market analysis with source citations.** Market sizing, segmentation, key players, HHI and CR4 concentration, Porter's Five Forces, PESTLE macro-environment, regulatory environment, trade flows, and outlook with scenario analysis. Supports UK, US, EU, Australia, and global scope. Multi-geography comparisons (e.g. `--geo uk,us`) are supported.

```
/market-research "UK grocery retail"
/market-research "semiconductors" --geo global
/market-research "residential mortgages" --geo uk,us
```

**`/io-report` — regional economic impact assessment.** Input an investment amount or jobs number in a specific sector and location; the skill builds regional input-output tables and computes direct and indirect multipliers via FLQ regionalization, applies additionality adjustments (deadweight, displacement, leakage), and estimates net economic impact on output, employment, and GVA. Supports 391 UK local authorities and 88 Australian SA4 regions.

```
/io-report "GBP 10m in Manufacturing in Manchester"
/io-report "500 jobs in Construction in Glasgow"
```

**`/la-profile` — UK local authority economic snapshot.** Demographics, labour market, earnings, industry structure, housing, business activity, productivity, skills, and deprivation. Benchmarked against the LA's country average, with optional side-by-side comparison against another LA. Good for funding bid context or place-based policy work.

```
/la-profile "Manchester"
/la-profile "Leeds" --compare "Birmingham"
```

**`/briefing-note` — two-page policy briefing note.** Problem, analysis, options, recommendation. Four templates covering minister submissions, board papers, committee briefings, and internal memos. This is the skill to use when you need to put something in front of a decision-maker quickly.

```
/briefing-note "Public transport fare cap policy"
```

### Audit

**`/econ-audit` — a senior partner and an economics professor reviewing your work.** Runs methodology checks across any econstack output or any economic analysis you point it at. Checks include the common Green Book / Aqua Book errors (double counting, missing counterfactual, transfers as benefits, unit costs not benchmarked), Flyvbjerg-style optimism indicators (cost-benefit asymmetry, scope near thresholds, low contingencies), and distributional gaps. Returns a RAG rating with issues ranked by severity and an optional auto-fix mode.

```
/econ-audit cba-schools-2026-04-10.md
/econ-audit . --strict --fix
```

---

## How the skills fit together

```
Pre-appraisal    →   Appraisal          →    Wrapping          →    Evaluation
/longlist            /cost-benefit            /business-case         /vfm-eval
                     /mca                                            /evaluate
                     /reg-impact

Context and background:          Audit at any point:
/macro-briefing                  /econ-audit
/fiscal-briefing
/market-research
/io-report
/la-profile
/briefing-note
```

A typical workflow:

1. **`/longlist`** — brainstorm benefits and costs for the project, with cash flow tags.
2. **`/cost-benefit`** — monetise and compute economic + financial NPV.
3. **`/business-case`** — wrap in the Five Case Model for a spending bid.
4. **`/vfm-eval`** — (later, after delivery) evaluate whether it actually worked.
5. **`/econ-audit`** — run at any point to check the analysis for common errors.

---

## Data

**CBA and evaluation parameters**: audited JSON files with source citations and staleness detection. Discount rates, carbon values, VSL, QALY, shadow wages, optimism bias tables, additionality conventions, and more. Covers UK, EU, World Bank, ADB, and Victorian Treasury. Lives at `~/econstack-data/parameters/`.

**Local authority data**: 391 UK local authorities with 16 data files each (employment, earnings, IO multipliers, population, housing, GVA, deprivation, skills, commuting). Lives at `~/econstack-data/src/data/`.

See the [parameters README](https://github.com/charlescoverdale/econstack-data/blob/main/parameters/README.md) for full documentation.

---

## Structure

```
econstack/
├── longlist/           /longlist       Benefits and costs brainstorm
├── cost-benefit/       /cost-benefit   CBA with economic + financial NPV
├── business-case/      /business-case  Five Case Model
├── mca/                /mca            Multi-criteria analysis
├── reg-impact/         /reg-impact     Regulatory Impact Assessment
├── vfm-eval/           /vfm-eval       4 E's value for money evaluation
├── evaluate/           /evaluate       Programme evaluation
├── macro-briefing/     /macro-briefing Macro monitor (UK, US, EU, AU)
├── fiscal-briefing/    /fiscal-briefing Public finances (UK, US, AU)
├── market-research/    /market-research Industry and market analysis
├── io-report/          /io-report      Regional IO impact
├── la-profile/         /la-profile     UK local authority profile
├── briefing-note/      /briefing-note  Policy briefing note
├── econ-audit/         /econ-audit     Methodology audit
├── templates/blocks/                   Shared template blocks
├── scripts/gen-skill-docs.sh           Generate SKILL.md from SKILL.tmpl
└── README.md
```

## Contributing

Edit the relevant `<skill>/SKILL.tmpl` and run `scripts/gen-skill-docs.sh <skill>` to regenerate the SKILL.md. Follow the format of existing skills. Open a PR.

## License

MIT
