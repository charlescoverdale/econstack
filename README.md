# econstack

Professional economic analysis, powered by AI.

econstack is a set of [Claude Code](https://claude.ai/code) skills that generate professional economic analysis. Type a slash command, get the key numbers in seconds, then pick the output you need.

```
/io-report £10m in Manufacturing in Manchester
/cost-benefit --framework us
```

---

## Quick start

```bash
# Install the skills
git clone https://github.com/charlescoverdale/econstack.git ~/.claude/skills/econstack

# Get the data (391 UK local authority datasets + CBA parameter database)
git clone https://github.com/charlescoverdale/econstack-data.git ~/econstack-data
```

No npm, no API keys, no configuration. Claude Code discovers skills in `~/.claude/skills/` automatically.

Then open Claude Code and type:

```
/io-report £10m in Manufacturing in Manchester
```

The skill computes the impact, shows you the key numbers, then asks what you need: full report, specific sections, slide bullets, or raw JSON. Every output includes a companion `.json` with all computed values.

```
/io-report £10m in Manufacturing in Manchester --format word,pdf
```

Add `--format` for Word, PowerPoint, HTML, Excel, or PDF. Or skip the flag and the skill asks you interactively.

---

## How it works

econstack skills are instructions, not software. Each SKILL.md tells Claude Code what to do: which data to read, what to compute, how to structure the output, and what caveats to include. Claude is the runtime.

```
You type:    /io-report £10m in Manufacturing in Manchester
                                    |
Claude reads: ~/.claude/skills/econstack/io-report/SKILL.md
Claude loads: ~/econstack-data/src/data/manchester/multipliers.json
Claude runs:  IO computation, additionality, sensitivity
Claude writes: io-report-manchester-2026-04-02.md + .json
```

### Output formats

All skills generate Markdown + JSON by default. Additional formats available via `--format`:

| Format | Use it for |
|--------|------------|
| Markdown (.md) | Default. Paste anywhere, convert to anything |
| Excel (.xlsx) | IB-style model with blue inputs and linked formulas (CBA only) |
| HTML (.html) | Self-contained branded page for email or browser |
| Word (.docx) | Edit in Word, drop sections into your own report |
| PowerPoint (.pptx) | Client presentation with key numbers and tables |
| PDF (.pdf) | Branded consulting-quality document (requires [Quarto](https://quarto.org)) |

### Interactive output selection

Every skill computes first, then asks what you need:

```
You:     /io-report £10m in Manufacturing in Manchester

Claude:  IMPACT COMPUTED
         ===============
         Net additional output:  £5.7m   (after additionality)
         Net additional jobs:    23
         GVA contribution:       £3.2m
         Output multiplier:      1.06x

         What output do you need?
         A) Full report
         B) Pick sections
         C) Slide summary
         D) Data only (JSON)
```

---

## Skills

### `/io-report` (UK)

Input-output economic impact assessment for an investment or job creation in any UK local authority.

```
/io-report £10m in Manufacturing in Manchester
/io-report 500 jobs in Construction in Glasgow --type2
/io-report £25m in Financial & Insurance in City of London --conservative
```

Regional IO model using FLQ regionalization (Flegg et al. 1995) of ONS Input-Output Analytical Tables 2023. 391 local authorities, 19 SIC sections, Type I multipliers by default. Includes tax revenue estimates, multi-year temporal profiles (construction vs operational phases), and multiplier benchmarking against comparable areas.

**Options:** `--type2` (induced effects), `--conservative` / `--optimistic` (additionality), `--audit` (auto-run quality checks), `--format`

---

### `/cost-benefit`

Cost-benefit analysis with full parameter database support for 4 jurisdictions.

```
/cost-benefit
/cost-benefit --framework us
/cost-benefit --framework eu
/cost-benefit --from assumptions.json --full --format xlsx,pdf
```

Interactive options appraisal, or skip the questions with `--from file.json`.

**8 frameworks:** UK Green Book, EU Cohesion Policy, US OMB A-4, World Bank, Australian Government, NZ Treasury CBAx, EIB, ADB. Auto-detected from your project description.

**Parameter database:** The skill loads jurisdiction-specific parameters (discount rates, carbon values, VSL, QALY, VTTS, distributional weights) from `~/econstack-data/parameters/`. UK, US, EU, and AU have full parameter coverage. Other frameworks use built-in defaults. Parameters include source citations and staleness detection.

**What it computes:** declining discount rates, optimism bias by project stage (SOC/OBC/FBC), S-curve capital phasing, benefit ramp-up, whole-life costing, additionality, carbon valuation, switching values, sensitivity (+/-20%), Monte Carlo (10k iterations), incremental analysis, distributional welfare weights, TAG/DOT transport values, QALY/DALY health values.

**Output formats:** Markdown, Excel (IB-style blue inputs, linked formulas, heat-map sensitivity), Word, PowerPoint, PDF. Chain with `--audit` to auto-run `/econ-audit`.

---

### `/econ-audit`

Audit any economic analysis output against methodology standards and academic literature.

```
/econ-audit cba-london-bridge-2026-04-03.md
/econ-audit io-report-manchester-2026-04-03.md --strict
/econ-audit . --fix
```

60+ checks across 10 categories: numerical consistency, discount rates, optimism bias, additionality, double counting, multiplier plausibility, framing, sector-specific (TAG, QALY, carbon), academic benchmarks (Flyvbjerg cost overruns, Moretti multipliers), and data quality. Validates against the same parameter database used by `/cost-benefit`.

Each issue is RED (must fix), AMBER (should address), or GREEN (pass). Every RED issue includes a concrete fix and a reference. Letter grade A through F, with RED issues capping the grade. Option to auto-fix and recompute.

---

### `/macro-briefing`

Macroeconomic monitor for UK, US, Euro area, and Australia. Each country follows its central bank's reporting structure.

```
/macro-briefing                     # UK (default, BoE MPR structure)
/macro-briefing --country us        # US (FOMC / Beige Book structure)
/macro-briefing --country eu        # Euro area (ECB Economic Bulletin structure)
/macro-briefing --country au        # Australia (RBA SoMP structure)
/macro-briefing --international     # Add 30-country comparison tables
```

**UK:** 22 indicators via `ons` and `boe` packages. GDP, unemployment, wages, CPI/CPIH/core, Bank Rate, gilts, SONIA, housing, fiscal, trade, productivity.

**US:** 21 indicators via `fred` package. GDP (annualized), payrolls, CPI/PCE (headline + core), Fed funds, Treasury yields (2y/10y), yield curve spread, housing starts, Case-Shiller, 30yr mortgage, consumer sentiment.

**Euro area:** 17 indicators via `readecb` package (no API key needed). GDP, HICP decomposition (headline/core/services/food/NEIG), ECB rates, ESTR, EURIBOR, AAA yields, M3, lending rates, mortgages, government debt.

**Australia:** 4 core indicators via `fred`/`readoecd`. GDP, CPI, unemployment, RBA cash rate. Thinner coverage, acknowledged honestly.

**All countries** include a traffic-light macro assessment (GREEN/AMBER/RED for growth, inflation, labour, financial conditions, external) and global context (Brent crude, VIX).

**Options:** `--country` (uk/us/eu/au), `--full`, `--focus`, `--international`, `--format pdf`

---

### `/la-profile` (UK)

Local authority economic profile.

```
/la-profile Manchester
/la-profile Leeds --compare Birmingham
/la-profile Bristol --focus housing --format pdf
```

10-section report: demographics, labour market, earnings, housing, business activity, productivity, deprivation, benchmarking. All data benchmarked against the LA's own country (Scottish LAs get Scottish averages).

---

### `/fiscal-briefing`

Public finances briefing for the UK or US.

```
/fiscal-briefing                    # UK (default): PSNB, PSND, OBR forecasts, fiscal rules
/fiscal-briefing --country us       # US: federal deficit, debt, receipts/outlays, CBO context
/fiscal-briefing --full
```

**UK:** PSNB, PSND, receipts by tax (income tax, NICs, VAT, corporation tax), expenditure, debt interest, fiscal rules headroom, OBR forecast comparison. Via `obr` and `ons` packages.

**US:** Federal deficit (monthly MTS + FYTD), receipts breakdown (income tax, corporate, payroll, excise), outlays (Social Security, Medicare, Medicaid, defense, interest), gross debt vs debt held by public, interest-to-GDP trend, CBO projection context. Via `fred` package.

---

## Data

### Local authority data

**391 local authorities** across England, Wales, and Scotland. 16 data files per LA, from official government open sources.

| Dataset | Source | Refresh |
|---------|--------|---------|
| Employment by sector (19 SIC sections) | BRES via Nomis | Annual |
| Earnings (p10-p90, gender gap) | ASHE via Nomis | Annual |
| IO multipliers (Type I + II) | ONS IOAT 2023 + FLQ | On SUT update |
| Population, housing, GVA, business counts | ONS / DLUHC | Annual |
| Deprivation (IMD, 7 domains) | MHCLG (England only) | Periodic |
| Skills, commuting | Census 2021 via Nomis | Decennial |

**IO model:** ONS Input-Output Analytical Tables 2023 (Blue Book 2025). 104 industries aggregated to 19 SIC sections. FLQ regionalization (delta = 0.3). Type I default, Type II optional.

### CBA parameter database

33 JSON parameter files at `~/econstack-data/parameters/` covering 4 jurisdictions plus OECD cross-country transfer. Each file includes the value, source citation, methodology note, caveats, and staleness metadata.

| Category | UK | US | EU | AU |
|----------|:--:|:--:|:--:|:--:|
| Discount rates | Green Book declining (3.5% to 1.0%) | OMB A-4 revised (2%) + legacy 3%/7% | 3% / 5% (cohesion) | 7% (4%/10%) |
| Carbon values | DESNZ traded + non-traded | EPA SC-GHG (3 discount rates, CO2/CH4/N2O) | EIB shadow price (to EUR 800/t by 2050) | ACCU + Safeguard Mechanism |
| VSL / VPF | TAG GBP 2.35M | DOT $13.7M / EPA $12.5M / HHS $13.6M | EUR 3.6M + member state transfer | OIA AUD 5.87M |
| Health (QALY) | GBP 70,000 | $190-250K + FDA $100-150K | EUR 40-100K (varies by MS) | AUD 50-70K (PBAC implicit) |
| VTTS | TAG Data Book (fixed values/hr) | DOT wage-% method (50/70/100%) | | ATAP formula (% of AWE) |
| Distributional weights | e = 1.3, median GBP 35K | e = 1.4, median $80K (A-4 revised) | e = 1.0-1.5, median EUR 18K | |
| Optimism bias | 6 project types x 3 stages | N/A | N/A | N/A |
| Additionality | HMT 3 scenarios | N/A | N/A | N/A |
| Tax parameters | Income tax, NICs, VAT (2024/25) | N/A | Conversion factors, shadow wages | N/A |
| Accident costs | TAG A4.1 (fatal/serious/slight) | DOT MAIS severity fractions | | ATAP/BITRE (national + state) |
| Transport externalities | TAG A5.4 (congestion, noise, air, GHG) | | | |
| Fleet/emissions | TAG fleet composition + CO2/km | | | |
| S-curve profiles | 2/3/5/7/10-year capex phasing | | | |
| Construction benchmarks | Flyvbjerg overruns, asset lives, BCR bands | | | |

Plus **OECD cross-country VSL transfer** (income-elasticity method for 25+ countries, based on the 2025 OECD meta-analysis of 277 studies).

**Staleness detection:** Each parameter file includes `expected_next_update`. The `/cost-benefit` skill warns when parameters are past their expected update date.

**Validation:** Run `python3 scripts/validate-parameters.py` in econstack-data to check schema, ranges, consistency (e.g. S-curve weights sum to 1.0, additionality factors match components), and staleness.

**Sources:** All values sourced from official government publications. UK: Green Book 2026, TAG Data Book v2.02, DESNZ 2024. US: OMB A-4 2023, EPA SC-GHG 2023, DOT/HHS 2024-2025. EU: EC DG Regio CBA Guide 2014, EIB 2023. AU: ATAP, OIA 2025. OECD: Mortality Risk Valuation 2025.

**Data path:** `~/econstack-data/parameters/`. Skills fall back to built-in defaults if parameter files are not found.

---

## The ecosystem

```
R packages (data access)          econprofile (data + web)         econstack (skills)
========================          =======================         ==================
ons    -> ONS data                391 LA profiles                 /io-report (UK)
boe    -> Bank of England         IO impact calculator            /la-profile (UK)
hmrc   -> HMRC trade              Compare regions tool            /cost-benefit (4 jurisdictions)
obr    -> OBR fiscal              Embeddable charts               /econ-audit
fred   -> US FRED data            Country benchmarking            /macro-briefing
readecb -> ECB data                                               /fiscal-briefing (UK, US)
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

### R packages on CRAN

| Package | Exports | What it does |
|---------|---------|-------------|
| [ons](https://cran.r-project.org/package=ons) | 16 | GDP, CPI, unemployment, wages, trade from ONS |
| [boe](https://cran.r-project.org/package=boe) | 11 | Base rate, yield curves, money supply from Bank of England |
| [hmrc](https://cran.r-project.org/package=hmrc) | 12 | UK trade data from HMRC |
| [obr](https://cran.r-project.org/package=obr) | 15 | Fiscal forecasts from the OBR |
| [fred](https://cran.r-project.org/package=fred) | 19 | 800,000+ US economic series from FRED |
| [readoecd](https://cran.r-project.org/package=readoecd) | 13 | Cross-country data from the OECD |
| [readecb](https://cran.r-project.org/package=readecb) | 16 | Euro area data from the ECB |
| [inflateR](https://cran.r-project.org/package=inflateR) | 2 | Historical inflation adjustment |
| [nowcast](https://cran.r-project.org/package=nowcast) | 10 | Economic nowcasting (bridge equations, backtesting) |
| [debtkit](https://cran.r-project.org/package=debtkit) | 12 | Debt sustainability analysis |
| [yieldcurves](https://cran.r-project.org/package=yieldcurves) | 16 | Yield curve fitting (Nelson-Siegel, Svensson, PCA) |
| [inflationkit](https://cran.r-project.org/package=inflationkit) | 11 | Inflation decomposition, persistence, Phillips curve |
| [predictset](https://cran.r-project.org/package=predictset) | 20 | Conformal prediction and uncertainty quantification |
| [climatekit](https://cran.r-project.org/package=climatekit) | 35 | Climate indices (temperature, precipitation, drought) |
| [readnoaa](https://cran.r-project.org/package=readnoaa) | 6 | US weather data from NOAA |
| [readaec](https://cran.r-project.org/package=readaec) | 3 | Australian election data |

---

## Project structure

```
econstack/
├── README.md
├── CLAUDE.md
├── VERSION
├── .gitignore
├── bin/
│   └── econstack-update-check
├── scripts/
│   └── render-report.sh
├── templates/
│   └── econstack-report/
│       └── _extensions/econstack/
├── io-report/SKILL.md          (UK)
├── la-profile/SKILL.md         (UK)
├── cost-benefit/SKILL.md       (UK, US, EU, AU + 4 more)
├── econ-audit/SKILL.md
├── macro-briefing/SKILL.md
└── fiscal-briefing/SKILL.md    (UK)

econstack-data/
├── src/data/                   (391 UK LA datasets)
├── parameters/                 (33 CBA parameter files)
│   ├── uk/    (14 files)
│   ├── us/    (6 files)
│   ├── eu/    (6 files)
│   ├── au/    (6 files)
│   └── oecd/  (1 file)
└── scripts/                    (extraction + validation)
```

---

## Contributing

Create `<skill-name>/SKILL.md`, follow the format of existing skills, and open a PR.

## License

MIT
