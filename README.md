# econstack

Professional economic analysis, powered by AI.

econstack is a set of [Claude Code](https://claude.ai/code) skills that handle the first 80% of economic analysis, so you can focus on the interpretation and key decisions. Type a slash command, get the key numbers in seconds, then select the outputs and formats you need to support whatever publication, analysis, or client deliverable you're working on.

Skills are currently built around the UK, US, EU, and Australia, with further regional support coming soon.

---

## Quick start

```bash
# Install the skills
git clone https://github.com/charlescoverdale/econstack.git ~/.claude/skills/econstack

# Get the data (391 UK local authority datasets + CBA parameter database)
git clone https://github.com/charlescoverdale/econstack-data.git ~/econstack-data
```

No npm, no API keys, no configuration. Claude Code discovers skills in `~/.claude/skills/` automatically.

All skills generate Markdown + JSON by default. Add `--format` for Word, PowerPoint, HTML, Excel, or PDF.

---

## Skills

### `/io-report` (UK)

Input-output economic impact assessment for 391 UK local authorities.

```
/io-report £10m in Manufacturing in Manchester
/io-report 500 jobs in Construction in Glasgow --type2
```

Regional IO model (FLQ regionalization, ONS 2023). Tax revenue estimates, additionality, sensitivity analysis, multiplier benchmarking. **Options:** `--type2`, `--conservative`/`--optimistic`, `--audit`, `--format`

---

### `/cost-benefit`

Cost-benefit analysis with parameter database support for UK, US, EU, and Australia.

```
/cost-benefit
/cost-benefit --framework us
/cost-benefit --from assumptions.json --full --format xlsx,pdf
```

8 frameworks (UK Green Book, US OMB A-4, EU Cohesion, Australia, World Bank, NZ CBAx, EIB, ADB). Declining discount rates, optimism bias, S-curve phasing, carbon valuation, Monte Carlo, switching values, distributional weights. 33 audited parameter files with source citations and staleness detection.

---

### `/econ-audit`

Audit any economic analysis against methodology standards and academic literature.

```
/econ-audit io-report-manchester-2026-04-03.md --strict
/econ-audit . --fix
```

60+ checks across 10 categories. RED/AMBER/GREEN grading, letter grade A-F, auto-fix option.

---

### `/macro-briefing`

Macroeconomic monitor for UK, US, Euro area, and Australia.

```
/macro-briefing                     # UK (BoE MPR structure, 27 indicators)
/macro-briefing --country us        # US (FOMC structure, 27 indicators)
/macro-briefing --country eu        # Euro area (ECB Bulletin, 17 indicators)
/macro-briefing --country au        # Australia (RBA SoMP, 12+ indicators via readabs)
/macro-briefing --international     # Add 30-country comparison tables
```

Each country follows its central bank's reporting structure. Traffic-light macro assessment (GREEN/AMBER/RED) with quantitative thresholds. **Options:** `--country`, `--full`, `--focus`, `--international`, `--format pdf`

---

### `/la-profile` (UK)

Local authority economic profile for 391 UK areas.

```
/la-profile Manchester
/la-profile Leeds --compare Birmingham
```

10-section report: demographics, labour market, earnings, housing, business activity, productivity, deprivation, benchmarking.

---

### `/fiscal-briefing`

Public finances briefing for UK, US, or Australia.

```
/fiscal-briefing                    # UK: PSNB, PSND, OBR forecasts, fiscal rules
/fiscal-briefing --country us       # US: federal deficit, debt, receipts/outlays
/fiscal-briefing --country au       # Australia: UCB, net debt, revenue/expenses
/fiscal-briefing --dsa              # Add debt sustainability analysis via debtkit
```

---

## Data

**Local authority data:** 391 UK LAs with 16 data files each (employment, earnings, IO multipliers, population, housing, GVA, deprivation, skills, commuting). At `~/econstack-data/src/data/`.

**CBA parameters:** 34 JSON files across UK (14), US (6), EU (6), AU (6), OECD (1), and common (1). Discount rates, carbon values, VSL, QALY, VTTS, optimism bias, additionality, tax parameters, and more. Source citations, staleness detection, and validation script included. At `~/econstack-data/parameters/`. See the [parameters README](https://github.com/charlescoverdale/econstack-data/blob/main/parameters/README.md) for full documentation.

---

## The ecosystem

```
R packages (data access)          econprofile (data + web)         econstack (skills)
========================          =======================         ==================
ons    -> ONS data                391 LA profiles                 /io-report (UK)
boe    -> Bank of England         IO impact calculator            /la-profile (UK)
hmrc   -> HMRC trade              Compare regions tool            /cost-benefit (4 jurisdictions)
obr    -> OBR fiscal              Embeddable charts               /econ-audit
fred   -> US FRED data            Country benchmarking            /macro-briefing (4 countries)
readecb -> ECB data                                               /fiscal-briefing (UK, US, AU)
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
