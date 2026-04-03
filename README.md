# econstack

Professional economic analysis, powered by AI.

econstack is a set of [Claude Code](https://claude.ai/code) skills that generate professional economic analysis. Type a slash command, get the key numbers in seconds, then pick the output you need: a full report, specific sections for your own document, slide-ready bullets, an elevator pitch, or just the raw data as JSON.

```
/impact-report £10m in Manufacturing in Manchester
```

The skill computes the impact, shows you the key numbers, then asks what you need. Full report? Just the sensitivity table for your Excel model? Slide bullets for a client presentation? The methodology appendix for a business case? You pick the pieces and build your own deliverable.

Every output includes a companion `.json` file with all computed values, so you can plug the numbers into your own tools.

---

## Why this exists

Professional business economists spend 60-70% of their time on data wrangling, not analysis. They pull data from ONS, BoE, OECD, and a dozen other sources. They clean it, align frequencies, merge datasets, make charts, write reports, and do it all again next week.

The tools are either free and fragmented (individual R packages, CSV downloads, manual Excel) or expensive and institutional (Bloomberg at GBP 25k/yr, Haver Analytics at GBP 15k+, Macrobond at GBP 5k+). There is nothing in between.

econstack fills that gap. It takes the data from [econprofile](https://econprofile.com) (391 UK local authority profiles with input-output multipliers, employment, earnings, housing, deprivation, and more) and wraps it in analytical workflows that produce real deliverables.

The skills encode how a professional economist thinks about these problems: which data to use, what methodology is appropriate, what caveats to include, which academic references to cite. You provide the question. econstack provides the analysis.

---

## Quick start

**Step 1: Install (30 seconds)**

Open your terminal and run these two commands:

```bash
# Install the skills
git clone https://github.com/charlescoverdale/econstack.git ~/.claude/skills/econstack

# Get the data (391 UK local authority datasets)
git clone https://github.com/charlescoverdale/econprofile.git ~/econprofile
```

That's it. No npm install, no API keys, no configuration. Claude Code automatically discovers skills in `~/.claude/skills/`.

**Step 2: Use**

Open [Claude Code](https://claude.ai/code) and type:

```
/impact-report £10m in Manufacturing in Manchester
```

Claude reads the local authority data, runs the IO computation, applies HM Treasury additionality adjustments, and writes a full report to your working directory. Takes about 30 seconds.

**Step 3: Get a PDF (optional)**

Add `--format pdf` for a branded, consulting-quality PDF:

```
/impact-report £10m in Manufacturing in Manchester --format pdf --client "Manchester City Council"
```

Requires [Quarto](https://quarto.org) for PDF rendering (`brew install quarto` on macOS).

### More examples

```
# Economic impact assessment
/impact-report £10m in Manufacturing in Manchester
/impact-report 500 jobs in Construction in Glasgow --type2
/impact-report £25m in Financial & Insurance in City of London --conservative
/impact-report £5m in Accommodation & Food in Brighton and Hove --format pdf

# Local authority economic profile
/la-profile Manchester
/la-profile Glasgow City --brief
/la-profile Leeds --compare Birmingham
/la-profile Bristol --focus housing --format pdf
```

### What you get

**Both skills are interactive.** They compute the numbers, show you the headline stats, then ask what output format you need:

- **Full report** : every section, 5-10 pages
- **Pick sections** : choose only what you need (exec summary, tables, methodology, risks, etc.)
- **Slide summary** : 5 bullet points for PowerPoint
- **Elevator pitch** (la-profile) : one paragraph characterizing the economy
- **Data only** : just the `.json` file for your own analysis

Every output includes a **companion JSON file** with all computed values, so you can feed the numbers into Excel, build your own charts, or cross-check against other sources. The skills produce building blocks, not finished deliverables. You take the 80% first draft and make it yours.

### Data path

The skills expect econprofile data at this path:
```
~/econprofile/src/data/
```

If you cloned econprofile elsewhere, update the data paths in:
- `~/.claude/skills/econstack/skills/impact-report/SKILL.md`
- `~/.claude/skills/econstack/skills/la-profile/SKILL.md`

Search for `/Users/charlescoverdale/` and replace with your path.

---

## How it works

econstack skills are not software. They are instructions. Each SKILL.md file tells Claude Code exactly what to do: which data files to read, what computation to run, how to structure the output, what methodology to document, and what caveats to include.

Claude is the runtime. The SKILL.md is the prompt. The data comes from econprofile sitting on your disk.

```
You type:    /impact-report £10m in Manufacturing in Manchester
                                    |
Claude reads: ~/.claude/skills/econstack/skills/impact-report/SKILL.md
                                    |
Claude loads: ~/econprofile/src/data/manchester/multipliers.json
              ~/econprofile/src/data/manchester/summary.json
              ~/econprofile/src/data/national-benchmarks.json
                                    |
Claude runs:  IO computation (Leontief inverse, FLQ regionalization)
              Additionality adjustment (HM Treasury defaults)
              Sensitivity analysis (+/- 15% multiplier variation)
                                    |
Claude writes: impact-report-manchester-2026-04-02.md
```

No API keys. No build step. No dependencies beyond Claude Code and the data files.

For branded PDF output, add `--format pdf` to any command. This renders through a custom Typst template via Quarto, producing a consulting-quality PDF with cover page, headers, footers, navy branding, and professional table styling.

```
/impact-report £10m in Manufacturing in Manchester --format pdf
```

---

## PDF output

Add `--format pdf` to any skill command to generate a branded PDF alongside the markdown report.

The PDF template is designed to consulting standards (BCG, Frontier Economics):
- **Cover page** with title, subtitle, date, navy accent bar
- **Headers/footers** with EconStack wordmark, report title, page numbers
- **Navy heading hierarchy** (#003078) with thin rules under H1
- **Professional tables**: navy header row, alternating gray stripes, no vertical borders
- **Callout boxes**: light blue background with navy left border
- **Two-level section numbering** (1.1, 1.2)

**Requirements:** [Quarto](https://quarto.org) >= 1.5.0 (includes Typst for PDF rendering). On macOS: `brew install quarto`. The render script auto-detects Quarto at `/Applications/quarto/bin/quarto` or on your PATH.

You can also render any existing markdown report manually:

```bash
~/.claude/skills/econstack/scripts/render-report.sh my-report.md --title "Custom Title"
```

---

## Skills

### `/impact-report`

Generate an economic impact assessment for an investment or job creation in any UK local authority.

```
/impact-report £10m in Manufacturing in Manchester
/impact-report 500 jobs in Construction in Glasgow
/impact-report £25m in Financial & Insurance in City of London --type2
/impact-report £5m in Accommodation & Food in Brighton and Hove --conservative
```

**What you get:** A 9-section report covering:

| Section | Contents |
|---------|----------|
| Executive summary | 2-3 paragraphs for a non-technical reader |
| Investment parameters | Input table: amount, sector, LA, multiplier type |
| Gross impact | Direct / indirect / induced output and jobs, GVA, tax estimates |
| Additionality adjustment | Deadweight, displacement, leakage per HM Treasury guidance |
| Sensitivity analysis | +/- 15% multiplier variation table |
| Multiplier explanation | Why this area has this specific multiplier (lambda, FLQ) |
| Local context | Key stats for the LA (employment, earnings, claimant rate) |
| Methodology | Full IO model documentation (2 pages) |
| References | 10 academic and government citations |

**Options:**

| Flag | Effect |
|------|--------|
| `--type2` | Include household spending (induced) effects |
| `--conservative` | 35% deadweight, 40% displacement, 20% leakage |
| `--optimistic` | 10% deadweight, 10% displacement, 5% leakage |
| `--no-additionality` | Gross figures only |
| `--brief` | Executive summary only (1 page) |
| `--format pdf` | Branded PDF output via Quarto/Typst |

**Methodology:** Regional input-output model using FLQ regionalization (Flegg et al. 1995) of ONS Input-Output Analytical Tables 2023 (Blue Book 2025). 104 industries aggregated to 19 SIC sections. Type I multipliers by default (conservative). Additionality from HM Treasury Additionality Guide (4th edition, 2014) and MHCLG Appraisal Guide (3rd edition, 2025).

---

### `/la-profile`

Generate a full local authority economic profile.

```
/la-profile Manchester
/la-profile Glasgow City --brief
/la-profile Leeds --compare Birmingham
/la-profile Bristol --focus housing
```

**What you get:** A 10-section report covering:

| Section | Contents |
|---------|----------|
| At a glance | Summary table: population, jobs, earnings, claimant rate, GVA, house price |
| Summary | 3-4 paragraph narrative (what kind of economy is this?) |
| Demographics | Population, working-age %, growth trend |
| Labour market | Employment by sector, specialisation (LQ), shift-share analysis |
| Earnings | Percentile distribution (p10-p90), gender pay gap |
| Housing | Prices, affordability, tenure breakdown |
| Business activity | Enterprise counts, size bands, birth/death rates |
| Productivity | GVA per job, rank, sector breakdown |
| Deprivation | IMD rank, domain-level scores |
| Benchmarking | Comparison to England/Scotland/Wales and GB averages |

All data is benchmarked against the LA's own country (not just England). A Scottish LA gets Scottish averages. A Welsh LA gets Welsh averages.

**Options:**

| Flag | Effect |
|------|--------|
| `--brief` | Executive summary only (1-2 pages) |
| `--compare <LA>` | Side-by-side comparison with another LA |
| `--focus labour` | Emphasise labour market and skills |
| `--focus housing` | Emphasise housing and affordability |
| `--focus business` | Emphasise business activity and industry structure |
| `--format pdf` | Branded PDF output via Quarto/Typst |

---

### Coming soon

| Skill | What it does |
|-------|-------------|
| `/macro-briefing` | UK macro dashboard: GDP, inflation, employment, rates. Uses the [ons](https://cran.r-project.org/package=ons) and [boe](https://cran.r-project.org/package=boe) R packages. |
| `/sector-analysis` | Industry deep dive: BRES employment, IO multipliers, shift-share, LQ analysis for a specific sector across regions. |
| `/fiscal-monitor` | Public finances report: OBR data, debt sustainability (via [debtkit](https://cran.r-project.org/package=debtkit)), spending breakdown. |
| `/yield-report` | Yield curve analysis: Nelson-Siegel fitting, carry/rolldown, PCA (via [yieldcurves](https://cran.r-project.org/package=yieldcurves)). |
| `/inflation-briefing` | Inflation analysis: CPI decomposition, core measures, persistence, Phillips curve (via [inflationkit](https://cran.r-project.org/package=inflationkit)). |
| `/nowcast` | GDP nowcast: bridge equations, mixed-frequency alignment, backtesting (via [nowcast](https://cran.r-project.org/package=nowcast)). |

---

## Data coverage

econstack currently covers **391 local authorities** across England, Wales, and Scotland. The underlying data comes from official government open sources, pre-fetched and processed by the [econprofile](https://econprofile.com) data pipeline.

### Per local authority (16 data files each)

| Dataset | Source | Refresh |
|---------|--------|---------|
| Employment by sector (19 SIC sections) | BRES via Nomis | Annual |
| Earnings (percentiles p10-p90, gender gap) | ASHE via Nomis | Annual |
| IO multipliers (output + employment, Type I + II) | ONS IOAT 2023 + FLQ | On SUT update |
| Population (mid-year estimates, age profile, trend) | ONS | Annual |
| Housing (prices, affordability, tenure) | DLUHC / HM Land Registry | Annual |
| GVA by industry | ONS (estimated from BRES + national ratios) | Annual |
| Business counts (size bands) | ONS UK Business Counts | Annual |
| Business demography (births, deaths, survival) | ONS | Annual |
| Deprivation (IMD, 7 domains) | MHCLG (England only) | Periodic |
| Skills (occupations, qualifications) | Census 2021 via Nomis | Decennial |
| Commuting (modes, WFH %) | Census 2021 via Nomis | Decennial |
| Industry shift-share analysis | Derived from BRES | Annual |
| Location quotients | Derived from BRES | Annual |
| National benchmarks (England, Scotland, Wales, GB) | Aggregated from above | On data update |

### National IO model

| Parameter | Value |
|-----------|-------|
| Source | ONS Input-Output Analytical Tables, 2023 (Blue Book 2025) |
| Industries | 104 (aggregated to 19 SIC sections A-S) |
| Aggregation method | Output-weighted averaging |
| Regionalization | Flegg Location Quotient (FLQ), delta = 0.3 |
| Multiplier types | Type I (default) + Type II (optional) |
| Additionality | HM Treasury (2014) + MHCLG (2025) guidance |

---

## The ecosystem

econstack is part of a broader suite of economic data tools. The R packages provide programmatic data access. econprofile provides the pre-built data and web interface. macrowithr teaches the methods. econstack ties them together into workflows.

```
R packages (data access)          econprofile (data + web)         econstack (skills)
========================          =======================         ==================
ons    -> ONS data                391 LA profiles                 /impact-report
boe    -> Bank of England         IO impact calculator            /la-profile
hmrc   -> HMRC trade              Compare regions tool            /macro-briefing (soon)
obr    -> OBR fiscal              Embeddable charts               /sector-analysis (soon)
fred   -> US FRED data            Country benchmarking            /fiscal-monitor (soon)
readecb -> ECB data                                               /nowcast (soon)
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
├── CLAUDE.md                              # Claude Code project context
├── scripts/
│   └── render-report.sh                   # Markdown to branded PDF converter
├── templates/
│   └── econstack-report/
│       └── _extensions/econstack/
│           ├── _extension.yml             # Quarto extension config
│           └── typst-template.typ         # Typst template (cover, headers, tables)
└── skills/
    ├── impact-report/
    │   └── SKILL.md                       # Economic impact assessment skill
    └── la-profile/
        └── SKILL.md                       # Local authority profile skill
```

Each skill is a single SKILL.md file. No code, no dependencies, no build step. The SKILL.md contains:

1. **YAML frontmatter**: name, description, allowed tools
2. **Instructions**: step-by-step workflow Claude follows
3. **Report template**: the exact structure of the output document
4. **Methodology**: the economic model, parameters, and references
5. **Rules**: formatting, caveats, and quality standards

---

## Contributing

The most useful contributions are new skills. If you have a workflow you repeat regularly (sector analysis, trade briefing, fiscal projection), it can probably be encoded as a skill.

A good skill has:
- A clear trigger ("when someone asks for X")
- Specific data requirements (which JSON files, which R packages)
- A structured output template (sections, tables, charts)
- Methodology documentation (what model, what assumptions)
- Honest caveats (what can go wrong, what the limitations are)

To add a skill: create `skills/<skill-name>/SKILL.md`, follow the format of existing skills, and open a PR.

---

## License

MIT
