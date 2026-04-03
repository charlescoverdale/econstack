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
git clone https://github.com/charlescoverdale/econstack-data.git ~/econstack-data
```

That's it. No npm install, no API keys, no configuration. Claude Code automatically discovers skills in `~/.claude/skills/`.

**Step 2: Use**

Open [Claude Code](https://claude.ai/code) and type:

```
/impact-report £10m in Manufacturing in Manchester
```

Claude reads the local authority data, runs the IO computation, applies HM Treasury additionality adjustments, and writes a full report to your working directory. Takes about 30 seconds.

**Step 3: Choose your output format (optional)**

Add `--format` for Word, PowerPoint, HTML, or PDF output:

```
/impact-report £10m in Manufacturing in Manchester --format word,pdf
```

Or skip the flag and the skill will ask you interactively which formats you need. PDF requires [Quarto](https://quarto.org) (`brew install quarto` on macOS). Word and PowerPoint are generated automatically.

### More examples

```
# Economic impact assessment
/impact-report £10m in Manufacturing in Manchester
/impact-report 500 jobs in Construction in Glasgow --type2
/impact-report £25m in Financial & Insurance in City of London --conservative
/impact-report £5m in Accommodation & Food in Brighton and Hove --format word,pptx

# Local authority economic profile
/la-profile Manchester
/la-profile Glasgow City --brief
/la-profile Leeds --compare Birmingham
/la-profile Bristol --focus housing --format pdf
```

### What you get

**Both skills are interactive.** They compute first, then ask what you need. Here's what the conversation looks like:

```
You:     /impact-report £10m in Manufacturing in Manchester

Claude:  IMPACT COMPUTED
         ===============
         Net additional output:  £5.7m   (after additionality)
         Net additional jobs:    23
         Gross output:           £10.6m  (before additionality)
         Gross jobs:             43
         GVA contribution:       £3.2m
         Estimated tax:          £420k
         Output multiplier:      1.06x
         Additionality factor:   54%

         What output do you need?
         A) Full report (8 sections, 5-10 pages)
         B) Pick sections (choose only what you need)
         C) Slide summary (5 bullet points for PowerPoint)
         D) Data only (JSON file for your own analysis)

You:     B

Claude:  Which sections?
         ☑ Executive summary
         ☑ Impact tables
         ☐ Additionality adjustment
         ☐ Sensitivity analysis
         ☐ Key risks
         ☐ Local context
         ☐ Full methodology
         ☑ Methodology summary (one paragraph)
         ☐ References

         [Generates only the 3 selected sections]
         [Saves companion JSON with all computed values]

Claude:  What file formats do you need?
         ☑ Markdown (.md)
         ☐ HTML
         ☑ Word (.docx)
         ☐ PowerPoint (.pptx)
         ☐ PDF

         [Generates markdown + Word document]
```

**The idea:** you don't need a 10-page report. You need the exec summary for an email, the tables for your spreadsheet, and a one-paragraph methodology note for a footnote. Pick the pieces and build your own deliverable.

**Output options:**

| Option | What you get | Use it for |
|--------|-------------|------------|
| Full report | All sections, 5-10 pages | Formal business cases, funding bids |
| Pick sections | Only what you select | Dropping into your own document or deck |
| Slide summary | 5 bullet points | Quick talking points |
| Elevator pitch | One paragraph (la-profile) | Meeting prep, email intros |
| Data only | `.json` file | Your own Excel model, charts, analysis |

**Output formats** (choose one or more):

| Format | File | Use it for |
|--------|------|------------|
| Markdown | `.md` | Default. Paste into any editor, convert to anything |
| HTML | `.html` | Self-contained branded page. Email or open in browser |
| Word | `.docx` | Edit in Microsoft Word, add to your own report |
| PowerPoint | `.pptx` | Client presentation with key numbers and tables |
| PDF | `.pdf` | Branded consulting-quality document (requires Quarto) |

Every output includes a **companion `.json` file** with all computed values. The skills produce building blocks, not finished deliverables. You take the 80% first draft and make it yours.

### Data path

The skills expect local authority data at this path:
```
~/econstack-data/src/data/
```

If your data is elsewhere, update the data paths in:
- `~/.claude/skills/econstack/skills/impact-report/SKILL.md`
- `~/.claude/skills/econstack/skills/la-profile/SKILL.md`

Search for `DATA_DIR=` and replace the path with your data location.

---

## How it works

econstack skills are not software. They are instructions. Each SKILL.md file tells Claude Code exactly what to do: which data files to read, what computation to run, how to structure the output, what methodology to document, and what caveats to include.

Claude is the runtime. The SKILL.md is the prompt. The data comes from econstack-data sitting on your disk.

```
You type:    /impact-report £10m in Manufacturing in Manchester
                                    |
Claude reads: ~/.claude/skills/econstack/skills/impact-report/SKILL.md
                                    |
Claude loads: ~/econstack-data/src/data/manchester/multipliers.json
              ~/econstack-data/src/data/manchester/summary.json
              ~/econstack-data/src/data/national-benchmarks.json
                                    |
Claude runs:  IO computation (Leontief inverse, FLQ regionalization)
              Additionality adjustment (HM Treasury defaults)
              Sensitivity analysis (+/- 15% multiplier variation)
                                    |
Claude writes: impact-report-manchester-2026-04-02.md
```

No API keys. No build step. No dependencies beyond Claude Code and the data files.

For additional output formats, add `--format` to any command. You can request Word, PowerPoint, HTML, or PDF (or combine them):

```
/impact-report £10m in Manufacturing in Manchester --format word,pdf
```

Or skip the flag entirely and the skill will ask you interactively which formats you need.

---

## Output formats

Every skill generates **Markdown + JSON** by default. You can also get HTML, Word, PowerPoint, or PDF, either via the `--format` flag or by answering the interactive format question.

```
/impact-report £10m in Manufacturing in Manchester --format word,pptx
```

### Markdown (.md)
Always generated. Plain text with tables, ready to paste into any editor or convert to other formats.

### HTML (.html)
Self-contained single-page report with inline CSS. GOV.UK-style navy branding, KPI cards, professional tables. No external dependencies. Open in a browser, attach to an email, or host on an intranet.

### Word (.docx)
Formatted Word document with navy headings, styled tables, and title page. Ready to edit, add your own branding, or drop sections into a client deliverable.

### PowerPoint (.pptx)
Slide deck with title slide, key numbers, impact tables, sensitivity analysis, and methodology note. Navy accent colour. Ready for client presentations.

### PDF
Branded consulting-quality PDF rendered via Quarto and Typst. Cover page, headers/footers, navy heading hierarchy, professional tables with alternating stripes, callout boxes, section numbering.

**Requirements:** [Quarto](https://quarto.org) >= 1.5.0 (includes Typst). On macOS: `brew install quarto`. The render script auto-detects Quarto at `/Applications/quarto/bin/quarto` or on your PATH.

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
| `--format <type>` | Output format(s): `markdown`, `html`, `word`, `pptx`, `pdf`, or `all`. Comma-separate for multiple (e.g. `--format word,pdf`) |

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
| `--format <type>` | Output format(s): `markdown`, `html`, `word`, `pptx`, `pdf`, or `all` |

---

### `/macro-briefing`

UK macroeconomic monitor. GDP, inflation, employment, wages, monetary conditions, fiscal position, trade, housing.

```
/macro-briefing
/macro-briefing --full
/macro-briefing --focus prices
/macro-briefing --international
```

Follows the Bank of England Monetary Policy Report narrative structure: output, labour market, prices, monetary conditions, fiscal, trade, housing, outlook. Uses `ons` (16 functions) + `boe` (11 functions) + `obr` (15 functions).

### `/fiscal-briefing`

UK public finances briefing: borrowing, debt, receipts, spending, fiscal rules.

```
/fiscal-briefing
/fiscal-briefing --full
```

Covers: current PSNB/PSND vs OBR forecast, tax receipts breakdown, expenditure and debt interest, fiscal rules headroom (PSNFL target), and outlook. Uses `obr` (15 functions) + `ons`, or falls back to direct ONS web fetch if R is not available.

### `/cost-benefit`

Green Book cost-benefit analysis. Discounting, NPV, BCR, optimism bias, sensitivity, switching values.

```
/cost-benefit
/cost-benefit --framework eu
```

Interactive options appraisal: define your options (do nothing, do minimum, preferred), enter costs and benefits (summary figures, year-by-year, or plain English descriptions), and the skill handles the computation. Correct declining discount rate schedule (3.5% years 0-30, 3.0% years 31-75, 2.5% years 76+), optimism bias by project type, additionality adjustments, sensitivity analysis (+/-20%), and switching values. Output matches the Five Case Model economic case structure. No R required.

### Coming soon

| Skill | What it does |
|-------|-------------|
| `/sector-analysis` | Industry deep dive: BRES employment, IO multipliers, shift-share, LQ analysis. |
| `/benchmarking` | Cross-area or cross-country comparison across standardised indicators. |

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
