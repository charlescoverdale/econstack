# econstack

Professional economic analysis, powered by AI.

econstack is a set of [Claude Code](https://claude.ai/code) skills that handle the first 80% of economic analysis, so you can focus on the interpretation and key decisions. Type a slash command, get the key numbers in seconds, then select the outputs and formats you need to support the publication, analysis, or client deliverable you're working on.

Skills are currently built around the UK, US, EU, and Australia, with further regional support coming soon.

---

## Quick start

```bash
# Install the skills
git clone https://github.com/charlescoverdale/econstack.git ~/.claude/skills/econstack

# Get the data (391 UK local authority datasets + CBA parameter database)
git clone https://github.com/charlescoverdale/econstack-data.git ~/econstack-data
```

No npm, no API keys, no configuration. Claude Code discovers skills in `~/.claude/skills/` automatically. econstack runs entirely on your machine through Claude Code. Your data, inputs, and outputs stay local and are never uploaded or shared.

Install econstack in Claude Code and start talking to it about your analysis. Describe your project and the skill integrates with whatever you're building, whether that's a report, a model, a slide deck, or a policy brief. Generate a full analysis or just the sections you need, then export to Markdown, HTML, Word, PowerPoint, PDF, or Excel.

---

## Skills

### `/cost-benefit`

Cost-benefit analysis that meets you where you are. Come with a one-line description ("I'm building a bridge in Melbourne") or a detailed set of inputs (costing schedules, theory of change, benefit streams by beneficiary group). The skill walks you through what it needs, fills in the framework-specific parameters automatically, and asks the right questions based on your project type and location.

Whether you've finalised the exact location, scale, and beneficiary groups or you're still at the back-of-envelope stage, the skill adapts. It follows standard business case logic: establishing a baseline (what happens without the project), developing options, and ensuring all benefit calculations are marginal compared to that baseline. It helps you think through scenario development and options selection before jumping to the numbers.

It then works through costs using the latest government guidelines and market benchmarks, provides defensible estimates, and lets you override anything. The output is a structured CBA model that's 80% done: correct discounting, optimism bias, sensitivity analysis, switching values, and Monte Carlo. You edit from there.

```
/cost-benefit
/cost-benefit --framework us
/cost-benefit --from assumptions.json --full --format xlsx,pdf
```

8 frameworks (UK Green Book, US OMB A-4, EU Cohesion, Australia, World Bank, NZ CBAx, EIB, ADB). 34 audited parameter files with source citations and staleness detection.

| Parameter | UK | US | EU | AU |
|-----------|:--:|:--:|:--:|:--:|
| Discount rates | 3.5% declining | 2% (OMB A-4) + 3%/7% legacy | 3% / 5% | 7% (4%/10%) |
| Carbon values | DESNZ traded + non-traded | EPA SC-GHG | EIB shadow price | ACCU + Safeguard |
| VSL | GBP 2.35M | DOT/EPA/HHS ($12.5-13.7M) | EUR 3.6M + transfer | AUD 5.87M |
| Health (QALY) | GBP 70,000 | $190-250K | EUR 40-100K | AUD 50-70K |
| VTTS | TAG Data Book | DOT wage-% method | | ATAP formula |
| Optimism bias | 6 types x 3 stages | | | |

**Options:** `--framework`, `--from`, `--full`, `--audit`, `--format`

---

### `/macro-briefing`

Up-to-date macroeconomic reports for the UK, US, Euro area, and Australia. Pulls live data from official government databases (ONS, FRED, ECB, ABS), structures it into a professional briefing following each central bank's reporting conventions, and lets you pick the sections you need. Every number is traceable: full methodology, data sources, and vintage dates included.

```
/macro-briefing                     # UK (BoE MPR structure, 27 indicators)
/macro-briefing --country us        # US (FOMC structure, 27 indicators)
/macro-briefing --country eu        # Euro area (ECB Bulletin, 17 indicators)
/macro-briefing --country au        # Australia (RBA SoMP, 12+ indicators via readabs)
/macro-briefing --international     # Add 30-country comparison tables
```

Traffic-light macro assessment (GREEN/AMBER/RED) with quantitative thresholds. Outputs to Markdown, HTML, Word, PowerPoint, or PDF. **Options:** `--country`, `--full`, `--focus`, `--international`, `--format`

---

### `/fiscal-briefing`

Up-to-date public finances reports for the UK, US, and Australia. Pulls live data from official sources (ONS, OBR, FRED, ABS), covers borrowing, debt, receipts by tax, spending by category, and fiscal rules or sustainability context. Every number is traceable: full methodology, data sources, and vintage dates included. Optionally add a debt sustainability analysis powered by the `debtkit` R package.

```
/fiscal-briefing                    # UK: PSNB, PSND, OBR forecasts, fiscal rules
/fiscal-briefing --country us       # US: federal deficit, debt, receipts/outlays
/fiscal-briefing --country au       # Australia: UCB, net debt, revenue/expenses
/fiscal-briefing --dsa              # Add debt sustainability analysis via debtkit
```

Outputs to Markdown, HTML, Word, PowerPoint, or PDF. **Options:** `--country`, `--full`, `--dsa`, `--format`

---

### `/io-report` (UK, more countries coming soon)

Quantitative economic impact assessment for 391 UK local authorities. Input an investment amount or jobs number in a specific sector and location, and the skill builds regional input-output tables from the latest ONS economic data, computes direct and indirect (supply chain) multipliers, and estimates the net additional impact on output, employment, GVA, and tax revenue.

Allows you to choose between Type I and Type II multipliers, adjust for additionality (deadweight, displacement, leakage) with sensitivities, and benchmark your results against comparable areas. All additionality assumptions are aligned with HM Treasury Green Book guidance. Full report output includes detailed methodology and an honest discussion of the limitations of IO models.

```
/io-report £10m in Manufacturing in Manchester
/io-report 500 jobs in Construction in Glasgow --type2
```

**Options:** `--type2`, `--conservative`/`--optimistic`, `--audit`, `--format`

---

### `/la-profile` (UK)

Economic snapshot for any of the 391 UK local authorities. Covers demographics, labour market, earnings, industry structure, housing, business activity, productivity, skills, and deprivation. All indicators are benchmarked against the LA's own country average (England, Scotland, or Wales) and can be compared side-by-side with other local authorities. Pick the sections you need and export to Markdown, HTML, Word, PowerPoint, or PDF.

```
/la-profile Manchester
/la-profile Leeds --compare Birmingham
``` **Options:** `--compare`, `--focus`, `--full`, `--format`

---

### `/econ-audit`

Full methodology audit of any output from the skills above, or any economic analysis you point it at. Runs 60+ checks across 10 categories and produces a RAG (red, amber, green) rating on how your methods and assumptions compare to best practice. Agnostic to region or asset class: it draws on government guidance (Green Book, OMB A-4, EC CBA Guide) and published academic literature (Flyvbjerg, Moretti, Flegg) to assess numerical consistency, discount rates, additionality, multiplier plausibility, double counting, and framing.

When it finds issues, it gives you a structured step-by-step plan to fix them and updates the methodology accordingly. So your analysis gets better as your project collects more information or you tailor it to your own needs or your clients' needs. Designed to improve over time as the rest of the repo evolves: as the parameter database and skill coverage expand, so does the audit's ability to cross-check your work.

```
/econ-audit io-report-manchester-2026-04-03.md --strict
/econ-audit . --fix
```

Letter grade A-F, with auto-fix option. **Options:** `--strict`, `--fix`, `--format`

---

## Data

**Local authority data:** 391 UK LAs with 16 data files each (employment, earnings, IO multipliers, population, housing, GVA, deprivation, skills, commuting). At `~/econstack-data/src/data/`.

**CBA parameters:** 34 JSON files across UK (14), US (6), EU (6), AU (6), OECD (1), and common (1). Discount rates, carbon values, VSL, QALY, VTTS, optimism bias, additionality, tax parameters, and more. Source citations, staleness detection, and validation script included. At `~/econstack-data/parameters/`. See the [parameters README](https://github.com/charlescoverdale/econstack-data/blob/main/parameters/README.md) for full documentation.

---

## The ecosystem

```
R packages (data access)          econprofile (data + web)         econstack (skills)
========================          =======================         ==================
ons    -> ONS data                391 LA profiles                 /cost-benefit (UK, US, EU, AU)
boe    -> Bank of England         IO impact calculator            /macro-briefing (UK, US, EU, AU)
hmrc   -> HMRC trade              Compare regions tool            /fiscal-briefing (UK, US, AU)
obr    -> OBR fiscal              Embeddable charts               /io-report (UK)
fred   -> US FRED data            Country benchmarking            /la-profile (UK)
readecb -> ECB data                                               /econ-audit
readoecd -> OECD data

R packages (analytical)           macrowithr.com
========================          ==============
nowcast    -> Nowcasting           14-chapter textbook
debtkit    -> Debt sustainability  Applied macro with R
yieldcurves -> Yield curves        Uses all the packages above
inflationkit -> Inflation analysis
predictset  -> Conformal prediction
climatekit  -> Climate indices
```

All 16 R packages are on [CRAN](https://cran.r-project.org/).

---

## Contributing

Create `<skill-name>/SKILL.md`, follow the format of existing skills, and open a PR.

## License

MIT
