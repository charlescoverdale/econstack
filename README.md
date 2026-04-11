# econstack

![Version](https://img.shields.io/badge/version-0.12.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Skills](https://img.shields.io/badge/skills-11-orange)

Professional economic analysis, powered by AI.

econstack is a set of [Claude Code](https://claude.ai/code) skills that handle the first 80% of economic analysis, so you can focus on the interpretation and key decisions. It knows the standard frameworks (HM Treasury Green Book, EU Better Regulation, World Bank, Asian Development Bank, and Australian Treasury (Victoria)), the right parameters for each jurisdiction, and the business case logic that underpins professional appraisal. You provide the project context; econstack does the computation, structuring, and formatting.

Built on 16 R packages on CRAN and a parameter database covering the UK, EU, Australia, World Bank, and Asian Development Bank.

### Who this is for

- A government economist writing a Green Book CBA or Magenta Book evaluation
- A consultant preparing an IO impact assessment or regulatory impact assessment
- An analyst pulling a macro briefing before a ministerial meeting
- A policy officer drafting a 2-page briefing note for a minister or board
- A programme manager commissioning an evaluation and needing an evaluation plan
- A local authority officer building an economic profile for a funding bid
- A trade analyst assessing bilateral trade flows and comparative advantage

If you spend time wrangling discount rates, writing up RIAs, formatting CBA spreadsheets, or structuring evaluation frameworks, econstack automates the mechanical parts so you can focus on the judgment calls.

If you already have a report, model, or output format that you like, upload it or link to it and the skills will adapt to match your structure and style. Your previous work becomes the template for future analyses.

---

## Quick start

Copy and paste this chunk into Claude Code:

```bash
# Install the skills
git clone https://github.com/charlescoverdale/econstack.git ~/.claude/skills/econstack

# Get the data (391 UK local authority datasets + CBA parameter database)
git clone https://github.com/charlescoverdale/econstack-data.git ~/econstack-data
```

Everything installs locally: the skills, the parameter database, and the 391 UK local authority datasets are cloned to your own machine. There is no central econstack server, no database, no telemetry. The skills read files from your local drive through Claude Code's normal file access, so your project notes, costings, and client materials stay on your device. Nothing is sent anywhere until you ask Claude a question, and even then it is the same privacy posture as using Claude Code for anything else: there is no extra layer, no phone-home, no third-party service.

You can come to econstack with zero project documents and start from a one-line description, or you can point it to wherever your existing materials live: costings, design briefs, brainstorming notes, prior business cases, stakeholder correspondence. The skill reads them automatically and factors the bespoke context into the analysis, so you do not need to retype anything you have already captured elsewhere.

---

## Frameworks and output formats

### Frameworks

| Flag | Framework |
|------|-----------|
| `uk-gb` | [UK HM Treasury Green Book (November 2025)](https://www.gov.uk/government/publications/the-green-book-appraisal-and-evaluation-in-central-government) |
| `eu-brg` | [EU Better Regulation Guidelines (2021, SWD(2021) 305)](https://commission.europa.eu/law/law-making-process/planning-and-proposing-law/better-regulation/better-regulation-guidelines-and-toolbox_en) |
| `wb` | [World Bank Economic Analysis of Investment Operations (OP 10.04)](https://www.worldbank.org/en/projects-operations/products-and-services/brief/economic-analysis) |
| `adb` | [Asian Development Bank Guidelines for the Economic Analysis of Projects (2017)](https://www.adb.org/documents/guidelines-economic-analysis-projects) |
| `au-vic` | [Victorian Treasury High Value High Risk (HVHR) framework](https://www.dtf.vic.gov.au/infrastructure-investment/high-value-high-risk-framework) |

Framework defaults are applied automatically: the right discount rate, the right unit values (VSL, QALY, shadow wages, carbon prices), the right additionality conventions, and the right optimism bias uplift for the jurisdiction.

### Output formats

Every skill generates markdown by default, and can also export to Excel, Word, PowerPoint, or PDF via `--format`.

| Format | Flag | When to use |
|--------|------|-------------|
| Markdown | default, always generated | Plain text you can paste into any editor, issue tracker, wiki, or chat. Source of truth that other formats are rendered from. |
| Excel | `--format xlsx` | Full investment banking style spreadsheet workbooks with blue input cells and linked formulas. |
| Word | `--format word` | Formatted document for editing in Microsoft Word. Hyperlinked references, cover page, table of contents. |
| PowerPoint | `--format pptx` | Slide deck with action titles (sentences stating the insight) and 3-4 evidence bullets per slide. The kind of deck you'd take to a board, minister, or investment committee. |
| PDF | `--format pdf` | Consulting-quality PDF rendered through Quarto. |
| All | `--format all` | All of the above in one invocation. |

Combine formats with commas: `--format markdown,xlsx,pptx`.

---

## Skills

### `/cost-benefit`

Come with a one-line description ("I'm building a bridge in Melbourne") or a detailed set of inputs (costing schedules, theory of change, benefit streams by beneficiary group). The skill walks you through what it needs, fills in the framework-specific parameters automatically, and asks the right questions based on your project type and location.

If you have a similar CBA or business case for a comparable asset that you like, upload it and tell econstack to use it as a reference. It will adopt that framing when building your new analysis.

Every analysis starts by establishing who the decision-maker represents (the referent group) and what perspective to take. This follows the Campbell & Brown multiple account framework: costs and benefits are tagged to stakeholder groups, disaggregated into referent and non-referent flows, and verified with the identity check (Referent Group NPV + Non-Referent NPV = Efficiency NPV). You can see exactly whose costs are being weighed against whose benefits.

```
/cost-benefit "New secondary school in Leeds" --framework uk-gb --format xlsx,word
```

---

### `/longlist`

The messy-whiteboard-phase skill. Before you run a CBA, a business case, or an RIA, you need to know what benefits to measure and what costs to include. `/longlist` is a structured brainstorm that helps you think through both, systematically, using multiple lenses (stakeholder mapping, Theory of Change, framework taxonomy, sector template, commonly-missed checklist). It runs the brainstorm internally and shows you the result: two clean tables of benefits and costs that you can hand straight to `/cost-benefit`.

The headline output is a seven-column table of benefits and costs: number, name, plain-English description, materiality rating (H/M/L), cash flow tag (Cash in / Cash out / Non-cash), how to quantify, and how to monetise.

**The cash flow tag is the bridge to the financial case.** Every item is tagged from the sponsor's perspective: cash in (real money onto the sponsor's books), cash out (real money off the sponsor's books), or non-cash (social value with no money attached, like heat deaths avoided, WELLBYs, biodiversity). This drives `/cost-benefit`'s financial case: only cash in and cash out items count for the Financial NPV, while the full set counts for the Economic NPV. That's how the skill tells you whether a project is socially worthwhile AND financially self-sustaining in one go.

**How to quantify / monetise: the bridge to the NPV.** Every item gets a suggested estimation method, either a published unit value from a named data source, an analytical approach, or "qualitative only" if no defensible monetisation exists. The downstream CBA starts with a clear method per line, not a blank cell.

Recognises the three classic double-counting traps and flags them automatically: construction employment + capital cost, journey time savings + land value uplift, and gross earnings + tax revenue. Excludes sunk costs by default. Splits carbon into embodied (construction) and operational (in-use). Does not adjust carbon benefits for additionality (per Green Book / DESNZ guidance).

Framework-aware: align to UK Green Book benefit categories, EU Better Regulation impacts, World Bank OP 10.04 lens, Asian Development Bank poverty and gender disaggregation, or Australian Treasury (Victoria) Investment Logic Map. Hands off a markdown longlist that `/cost-benefit`, `/business-case`, and `/reg-impact` can read directly via `--from`, so the suggested method and cash flow tags flow straight through without retyping.

```
/longlist "New secondary school in Leeds" --framework uk-gb --format xlsx,word
```

---

### `/business-case`

Draft a complete business case in the Five Case Model structure (Strategic, Economic, Commercial, Financial, Management). Delegates the CBA computation to `/cost-benefit` and adjusts depth by stage (SOC/OBC/FBC) and proportionality (under GBP 1m to over GBP 100m).

Guides you through the structured thinking: options vs counterfactual, preferred option selection, consistency across the five cases. The **Strategic Case** frames the problem, the options considered, and the Critical Success Factors. The **Economic Case** delegates to `/cost-benefit` for the NPV/BCR numbers. The **Commercial Case** covers procurement strategy, risk allocation, and contractual terms. The **Financial Case** covers funding sources and the year-by-year affordability profile. The **Management Case** covers governance, programme plan, risk register, and benefits realisation plan.

Cross-case consistency checks flag mismatches between financial and economic costs, benefits register and realisation plan, risk register and economic case contingency, and the preferred option across all five cases. Cash flow tags from the longlist flow through unchanged to keep the economic and financial cases internally consistent. Supports `--with-cba` to import an existing CBA output and `--from` to import a longlist.

```
/business-case "New hospital wing in Greater Manchester" --framework uk-gb --stage fbc --format docx,pdf
```

---

### `/macro-briefing`

Up-to-date macroeconomic reports for the UK, US, Euro area, and Australia. Tell it what you care about most (CPI, GDP growth, labour market, yield curves) or let it pick for you. Pulls live data from official government databases (ONS, FRED, ECB, ABS), structures it into a professional briefing following each central bank's reporting conventions, and lets you tailor the output to the indicators that matter for your work. Every number is traceable: full methodology, data sources, and vintage dates included.

Traffic-light macro assessment (GREEN/AMBER/RED) with quantitative thresholds. Good before a ministerial meeting, investment committee, or board paper.

```
/macro-briefing --country uk --format pdf
```

---

### `/fiscal-briefing`

Up-to-date public finances reports for the UK, US, and Australia. Pulls live data from official sources (ONS, OBR, FRED, ABS), covers borrowing, debt, receipts by tax, spending by category, and fiscal rules or sustainability context. Every number is traceable: full methodology, data sources, and vintage dates included. Optionally add a debt sustainability analysis powered by the `debtkit` R package.

```
/fiscal-briefing --country uk --format pdf
```

---

### `/market-research`

Industry and market analysis for any sector or product. Combines official statistics (ONS, BLS, Eurostat), regulatory data (CMA, FTC, EC), company filings, trade data (HMRC, UN Comtrade, Comext), and trade sources into a structured, source-cited research report. Covers market sizing, market segmentation, key players, M&A activity, pricing trends, market structure (HHI, CR4, contestability), Porter's Five Forces, PESTLE macro-environment, regulatory environment, supply chains, trade flows, demand drivers, industry history, and outlook with scenario analysis.

Supports UK, US, EU, Australia, and global scope. Multiple geographies can be combined for cross-market comparison (e.g. `--geo uk,us`). Adapts writing style to the client and audience (GOV.UK, European Commission, academic, board, public). Lets you specify preferred data sources or bring your own data. All data points are source-cited with full references.

```
/market-research "UK grocery retail"
/market-research "semiconductors" --geo global
/market-research "residential mortgages" --geo uk,us
/market-research "UK childcare" --focus regulation --depth quick
```

---

### `/io-report` (UK and Australia)

Quantitative economic impact assessment for 391 UK local authorities and 88 Australian SA4 regions. Input an investment amount or jobs number in a specific sector and location, and the skill builds regional input-output tables from the latest national IO data (ONS Blue Book 2025 for UK, ABS IO Tables 2023-24 for AU), computes direct and indirect (supply chain) multipliers via FLQ regionalization, and estimates the net additional impact on output, employment, and GVA. Auto-detects country from location name and currency.

Allows you to choose between Type I and Type II multipliers, adjust for additionality (deadweight, displacement, leakage) with sensitivities, and benchmark your results against comparable areas. All additionality assumptions are aligned with HM Treasury Green Book guidance. Full report output includes detailed methodology and an honest discussion of the limitations of IO models.

```
/io-report "GBP 10m in Manufacturing in Manchester"
/io-report "500 jobs in Construction in Glasgow" --type2
```

---

### `/la-profile` (UK)

Economic snapshot for any of the 391 UK local authorities. Covers demographics, labour market, earnings, industry structure, housing, business activity, productivity, skills, and deprivation. All indicators are benchmarked against the LA's own country average (England, Scotland, or Wales) and can be compared side-by-side with other local authorities. Pick the sections you need and export to Markdown, Word, PowerPoint, or PDF.

```
/la-profile "Manchester"
/la-profile "Leeds" --compare "Birmingham"
```

---

### `/reg-impact`

Regulatory Impact Assessment for proposed legislation, policy, or regulatory change. Applies the Standard Cost Model for compliance costs, runs the framework-specific tests (EANDCB and Small and Micro Business Impact for UK, SME test and Fundamental Rights screening for EU, Regulatory Change Measurement for Victoria), and produces a compact RIA with a single recommendation.

The output covers problem definition, market failure, options compared (including Do Nothing), cost-benefit summary per option, framework tests, sensitivity, post-implementation review plan, and a one-line verdict.

```
/reg-impact "Mandatory climate risk disclosure for listed companies"
/reg-impact "Ban on single-use plastics in food packaging" --framework uk-gb
/reg-impact "New data protection requirements for AI systems" --framework eu-brg
/reg-impact "Short-term rental regulation" --framework au-vic
```

---

### `/briefing-note`

Two-page policy briefing note for ministers, boards, committees, and internal decision-makers. Problem, analysis, options, recommendation. Four templates covering minister submissions, board papers, committee briefings, and internal memos. This is the skill to use when you need to put something in front of a decision-maker quickly, with the right level of formality for the audience.

```
/briefing-note "Public transport fare cap policy"
/briefing-note "Response to consultation on XYZ"
```

---

### `/econ-audit`

Think of it as a senior partner and an economics professor going through your work and poking holes in it. Full methodology audit of any output from the skills above, or any economic analysis you point it at. Runs 124 checks across 17 categories and produces a RAG (red, amber, green) rating on how your methods and assumptions compare to best practice. Agnostic to region or asset class: it draws on government guidance (Green Book 2026, Aqua Book, EU Better Regulation Toolbox, World Bank Guidance Note) and published academic literature (Flyvbjerg, Moretti, Flegg) to assess numerical consistency, discount rates, additionality, multiplier plausibility, double counting, framing, Five Case Model completeness, distributional analysis, Aqua Book RIGOUR compliance, and strategic misrepresentation patterns.

When it finds issues, it gives you a structured step-by-step plan to fix them and updates the methodology accordingly. Designed to improve over time as the rest of the repo evolves: as the parameter database and skill coverage expand, so does the audit's ability to cross-check your work.

```
/econ-audit io-report-manchester-2026-04-03.md --strict
/econ-audit . --fix
```

Letter grade A-F, with auto-fix option.

---

## Data

econstack comes preloaded with the data you need for most economic analysis work: discount rates, carbon values, VSL, QALYs, shadow wages, optimism bias tables, additionality conventions, tax parameters, and more. It also carries 391 UK local authority datasets covering employment, earnings, IO multipliers, population, housing, GVA, deprivation, skills, and commuting. All of this lives in the second repo you clone during install (`~/econstack-data/`) and is versioned, source-cited, and checked for staleness so you can trust the numbers without chasing them down yourself.

You can always override any parameter or bring your own data. If you have in-house unit costs, bespoke discount assumptions, or project-specific inputs, point the skill at them and it will use yours instead of the defaults. For the full list of parameters, source citations, and vintage dates, see the [parameters README](https://github.com/charlescoverdale/econstack-data/blob/main/parameters/README.md).

---

## Structure

```
econstack/
├── cost-benefit/        /cost-benefit   CBA with economic + financial NPV (5 frameworks)
├── macro-briefing/      /macro-briefing Macroeconomic monitor (UK, US, EU, AU)
├── fiscal-briefing/     /fiscal-briefing Public finances (UK, US, AU)
├── market-research/     /market-research Industry and market analysis (multi-geo)
├── io-report/           /io-report      Input-output impact (391 UK LAs)
├── la-profile/          /la-profile     Local authority profiles (391 UK LAs)
├── business-case/       /business-case  Five Case Model business case (5 frameworks)
├── briefing-note/       /briefing-note  Policy briefing note (4 templates)
├── reg-impact/          /reg-impact     Regulatory Impact Assessment (3 frameworks)
├── longlist/            /longlist       Pre-appraisal benefits and costs longlist (5 frameworks)
├── econ-audit/          /econ-audit     Methodology audit (124 checks)
├── templates/
│   └── blocks/          Shared template blocks (preamble, formatting, rules)
├── scripts/
│   ├── gen-skill-docs.sh  Generate SKILL.md from SKILL.tmpl + blocks
│   └── render-report.sh   PDF rendering via Quarto
├── bin/
│   └── econstack-update-check
└── README.md
```

Backed by 16 R packages on [CRAN](https://cran.r-project.org/) and a [57-file parameter database](https://github.com/charlescoverdale/econstack-data) and 8 reference case templates.

---

## Contributing

Edit the relevant `<skill>/SKILL.tmpl` and run `scripts/gen-skill-docs.sh <skill>` to regenerate the SKILL.md. Follow the format of existing skills, and open a PR.

## License

MIT
