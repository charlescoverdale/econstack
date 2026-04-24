---
name: fiscal-briefing
description: Public finances briefing. Supports UK, US, and Australia. Produces a single compact briefing on borrowing, debt, receipts, spending, and fiscal rules. Optional debt sustainability analysis via the debtkit R package. User-selectable sub-components and multi-format export.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - AskUserQuestion
  - Skill
---

**Only stop to ask the user when:** the country is ambiguous or a non-standard fiscal indicator is requested.
**Never stop to ask about:** data sources (use official sources), section selection, fiscal rule definitions, or output filename.

<!-- preamble: update check -->
Before starting, run this silently. If it outputs UPDATE_AVAILABLE, tell the user:
"A new version of econstack is available. Run `cd ~/.claude/skills/econstack && git pull` to update."
Then continue with the skill normally.

```bash
~/.claude/skills/econstack/bin/econstack-update-check 2>/dev/null || true
```

<!-- preamble: project learnings -->
After the update check, run this silently to load prior learnings for this project:

```bash
eval "$(~/.claude/skills/econstack/bin/econstack-slug)"
~/.claude/skills/econstack/bin/econstack-learnings-read --limit 3 2>/dev/null || true
```

If learnings are found, apply them. When a prior learning influences a decision, note: "Prior learning applied: [key]".

**Capturing new learnings:** After completing this skill, log new insights via:

```bash
~/.claude/skills/econstack/bin/econstack-learnings-log '{"skill":"...","type":"...","key":"...","insight":"...","confidence":N,"source":"observed|user-stated|inferred"}'
```

Types: `framework` (preferred appraisal framework), `parameter` (custom overrides), `data-source` (preferred data), `output` (past report references), `operational` (tool/env quirks), `preference` (formatting/style). Confidence: 9-10 observed/stated, 6-8 strong inference, 4-5 weak. User-stated never decays; observed/inferred lose 1 point per 30 days. All data stored locally. Nothing transmitted.

<!-- preamble: parameter database check -->
After the update check, verify the parameter database is available and check staleness:

```bash
PARAMS_DIR="$HOME/econstack-data/parameters"
if [ -d "$PARAMS_DIR" ]; then
  PARAM_COUNT=$(find "$PARAMS_DIR" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
  echo "PARAMS: $PARAM_COUNT files loaded from $PARAMS_DIR"

  # Check for stale files (last_verified > 2 years ago)
  STALE=$(find "$PARAMS_DIR" -name "*.json" -mtime +730 2>/dev/null | wc -l | tr -d ' ')
  if [ "$STALE" -gt 0 ]; then
    echo "PARAMS_WARNING: $STALE file(s) not updated in 2+ years. Run: cd ~/econstack-data && git pull"
  fi
else
  echo "PARAMS: not found. Using built-in defaults. For full parameter support: git clone https://github.com/charlescoverdale/econstack-data.git ~/econstack-data"
fi
```

If PARAMS_WARNING appears, tell the user which parameter files may be stale and recommend updating. Continue with the skill normally using whatever parameters are available.

<!-- preamble: safety hooks -->

**Safety rules for this skill:**

1. **Parameter database is read-only.** Never write to, modify, or delete files in `~/econstack-data/parameters/`. These are shared, versioned parameters maintained separately. If a parameter needs updating, tell the user to update the econstack-data repo.

2. **Confirm before overwriting.** Before writing an output file, check if a file with the same name already exists. If it does, ask the user: "A file named [filename] already exists. Overwrite it, or save with a new name?" Do not silently overwrite.

<!-- preamble: completion status -->
**At the end of every skill run, report one of these statuses:**

- **DONE**: Analysis complete, output generated, all sections finished.
- **DONE_WITH_CONCERNS**: Output generated but with caveats (e.g., data gaps, assumptions that need review, sections below expected depth).
- **BLOCKED**: Cannot proceed (e.g., missing critical input, parameter database unavailable, framework not supported).
- **NEEDS_CONTEXT**: Need more information from the user before continuing.

Format: `STATUS: [status] | [one-line reason]`

# /fiscal-briefing: Public Finances Briefing

Produces a compact public finances briefing for the UK, US, or Australia. Covers the current deficit or surplus, debt position, receipts by tax, spending by category, and fiscal rules or sustainability context. Every number is traceable to an official source with a vintage date.

Optionally adds a full Debt Sustainability Analysis (DSA) via the [debtkit](https://github.com/charlescoverdale/debtkit) R package with `--dsa`.

## Arguments

```
/fiscal-briefing [country or topic] [options]
```

**Example:**
```
/fiscal-briefing --country uk --format pdf
```

**Options:**
- `--country <code>` : `uk` (default), `us`, or `au`. Auto-detected if not set.
- `--focus <topic>` : Narrow to a theme. Options: `deficit`, `debt`, `receipts`, `spending`, `rules`, `outlook`.
- `--dsa` : Add a Debt Sustainability Analysis section (Bohn test, fan charts, stress tests) via the `debtkit` R package.
- `--section <name>` : Emit only one sub-component. Options: `full` (default), `headline`, `deficit`, `debt`, `receipts`, `spending`, `rules`, `outlook`, `dsa`. Combinable with commas.
- `--format <type>` : Output format(s). `markdown` (default, always generated), `xlsx`, `word`, `pptx`, `pdf`, or `all`.
- `--client "Name"` : Add "Prepared for" metadata.

## Supported countries

| Code | Country | Fiscal agency | Forecast body | Primary data sources |
|------|---------|--------------|---------------|--------------------|
| `uk` | United Kingdom (default) | HMT | Office for Budget Responsibility (OBR) | ONS, HMRC, HMT, OBR |
| `us` | United States | Treasury | Congressional Budget Office (CBO) | BEA, BLS, FRED, Treasury, OMB, CBO |
| `au` | Australia | Treasury | Parliamentary Budget Office (PBO) | ABS, Treasury, RBA, PBO |

**Auto-detection rules:**
- "UK", "Britain", "HMT", "OBR", "PSNB", "gilt" → `uk`
- "US", "Federal", "CBO", "Treasury yield", "deficit" (no qualifier) → `us`
- "Australia", "AUD", "UCB", "PBO", "Treasury Budget" → `au`
- Default → `uk`

## Instructions

### Step 1: Detect country and focus

If `--country` is not set, detect from context. Default to `uk`. If `--focus` is set, narrow the briefing to the relevant sections only.

### Step 2: Fetch data (silent)

Pull the core fiscal indicators from official sources for the detected country. Note any staleness in the Data sources footer.

**UK** (ONS, HMRC, HMT, OBR):
- Public Sector Net Borrowing (PSNB) latest month and YTD (ONS J5II)
- Public Sector Net Debt (PSND) % of GDP (ONS HF6X)
- Public Sector Current Budget (PSCB)
- Receipts by tax: income tax, NICs, VAT, corporation tax, fuel duty (HMRC)
- Spending by category: DEL vs AME, by department (HMT Public Sector Finances)
- OBR Economic and Fiscal Outlook: latest forecast, fiscal rules assessment
- Fiscal rules: debt rule, current budget rule, welfare cap

**US** (BEA, Treasury, OMB, CBO):
- Federal deficit level and % GDP (Treasury Monthly Treasury Statement, CBO)
- Federal debt held by the public and gross federal debt
- Receipts by source: individual income tax, payroll tax, corporate, excise
- Outlays by function: Social Security, Medicare, defence, net interest
- CBO Baseline Budget Outlook: latest projections
- Statutory debt ceiling status if relevant

**Australia** (ABS, Treasury, PBO):
- Underlying Cash Balance (UCB) and % GDP (Treasury Budget Papers)
- Australian Government general government net debt and gross debt
- Tax receipts by type: individual income, company, GST, excise, PRRT
- Payments by function: social security, health, education, defence
- Intergenerational Report projections (latest)
- Medium-term fiscal strategy

Silent fetching. Cite sources in a References footer at the end of the briefing.

### Step 3: Build the briefing (silent)

Structure by country using the standard fiscal reporting order:

1. **Headline and current position**: this year's deficit, debt level, % of GDP, vs prior year and vs forecast.
2. **Tax receipts**: breakdown by main tax, YoY change, surprises vs forecast.
3. **Public expenditure**: breakdown by category or function, YoY change, notable pressures.
4. **Fiscal rules**: which rules are binding, status (met / breached / at risk), headroom.
5. **Outlook**: the latest forecast body projections (OBR, CBO, PBO) for the medium term.
6. **Risks**: three bullet points: upside, downside, key fiscal events to watch.

### Step 4: Debt sustainability analysis (optional, if `--dsa`)

If `--dsa` is set, invoke the `debtkit` R package to produce:
- Debt-to-GDP projection fan chart over 10 years
- Bohn fiscal reaction test (is the primary balance responding to debt?)
- IMF-style stress tests (growth shock, rate shock, exchange rate shock, combined)
- European Commission S1 and S2 sustainability gap indicators

Note if `debtkit` is not installed: "Install debtkit from GitHub to enable DSA: `devtools::install_github('charlescoverdale/debtkit')`."

### Step 5: Write the output

Save `fiscal-[country]-[YYYY-MM-DD].md` with this structure.

```markdown
<!-- KEY NUMBERS
type: fiscal-briefing
country: [uk|us|au]
vintage: [latest data date]
deficit_pct_gdp: [value]
debt_pct_gdp: [value]
fiscal_rule_status: [met|at risk|breached]
dsa_run: [true|false]
date: [YYYY-MM-DD]
-->

# Fiscal Briefing: [Country]

**Date**: [YYYY-MM-DD] · **Data vintage**: [latest release]
**Headline**: [One-line summary: e.g. "UK deficit running above forecast, debt rule at risk of being breached in FY26-27."]

## Headline position

| Indicator | Latest | Prior | % of GDP | Vs forecast |
|-----------|-------:|------:|---------:|:------:|
| Deficit / surplus | [val] | [val] | [val]% | [above/below forecast] |
| Gross debt | [val] | [val] | [val]% | [above/below forecast] |
| Net debt | [val] | [val] | [val]% | [above/below forecast] |
| Debt interest | [val] | [val] | [val]% | [above/below forecast] |
| Primary balance | [val] | [val] | [val]% | [above/below forecast] |

## Tax receipts

[Two paragraphs: main tax contributions, YoY change, surprises vs forecast. Include one small table.]

| Tax | Latest (YTD) | Prior year | Change | Notes |
|-----|-------------:|-----------:|:------:|-------|
| [Main tax 1] | [val] | [val] | [↑/↓] | [brief] |
| [Main tax 2] | [val] | [val] | [↑/↓] | [brief] |
| [Main tax 3] | [val] | [val] | [↑/↓] | [brief] |
| **Total receipts** | **[val]** | **[val]** | [↑/↓] | |

## Public expenditure

[Two paragraphs: main spending lines, YoY change, budgetary pressures. Include one small table.]

| Category | Latest (YTD) | Prior year | Change | Notes |
|----------|-------------:|-----------:|:------:|-------|
| [Category 1] | [val] | [val] | [↑/↓] | [brief] |
| [Category 2] | [val] | [val] | [↑/↓] | [brief] |
| [Category 3] | [val] | [val] | [↑/↓] | [brief] |
| **Total spending** | **[val]** | **[val]** | [↑/↓] | |

## Fiscal rules

| Rule | Threshold | Current | Status | Headroom |
|------|-----------|--------:|:------:|---------:|
| [Rule 1] | [threshold] | [val] | [Met / At risk / Breached] | [val] |
| [Rule 2] | [threshold] | [val] | [Met / At risk / Breached] | [val] |

[One paragraph: which rule is binding, the political consequences of breach, whether the government has signalled policy changes.]

## Outlook

[Two paragraphs: latest forecast body projections for deficit and debt over the medium term. Cite the forecast body directly (OBR, CBO, PBO).]

## Risks

- **Upside**: [one bullet on potential improvements]
- **Downside**: [one bullet on potential deteriorations]
- **Key events**: [next fiscal event to watch: Budget, Autumn Statement, MYEFO, CBO update, etc.]

## Debt sustainability analysis (if --dsa)

[Bohn test result, IMF stress test outcomes, debt fan chart interpretation. One paragraph each. Refer the reader to the full debtkit output file for details.]

## Data sources

[One-line references with vintages.]
```

**Sub-component selection** (via `--section`): emit only the requested parts. Always include the header block and Headline position table.

- `full` (default): the whole structure above.
- `headline`: headline position table only.
- `deficit` / `debt` / `receipts` / `spending` / `rules` / `outlook` / `dsa`: that single section only.
- Combinable: `--section headline,rules,outlook`.

**Format exports** (via `--format`):
- **Markdown (.md)**: always generated. `fiscal-[country]-[date].md`.
- **Excel (.xlsx)**: workbook with sheets per dimension (Headline, Receipts, Spending, Rules, Outlook, optional DSA). Historical context back 10 years.
- **Word (.docx)**: one document, full briefing, cover page, TOC.
- **PowerPoint (.pptx)**: 5 slides: (1) Headline, (2) Receipts, (3) Spending, (4) Rules and outlook, (5) Risks.
- **PDF**: render markdown through econstack Quarto template.
- **`all`**: expand to all formats.

Tell the user (listing only files produced):
```
Fiscal briefing complete. [Country]. Deficit [val]% of GDP, debt [val]% of GDP. Fiscal rule: [status].

Saved:
  fiscal-[country]-[date].md
  [other formats if requested]
```

## Important rules

- **Official sources only.** ONS / HMRC / HMT / OBR for UK, BEA / Treasury / CBO / OMB for US, ABS / Treasury / PBO for AU. No third-party aggregators unless official data is unavailable.
- **Every number has a vintage.** Report the latest data release date in the Data sources footer.
- **Forecasts come from the official forecast body** (OBR, CBO, PBO). Do not generate new forecasts here.
- **One headline summary at the top**, backed by the Headline position table.
- **Fiscal rule status is explicit** (Met, At risk, Breached) with headroom.
- **DSA is optional** and requires `debtkit`. Note the install command if it is missing.
- **Em dashes**: never use em dashes. Use commas, colons, parentheses, or "and".

## Integration with other skills

- `/macro-briefing` is the broader macro companion. `/fiscal-briefing` is the deep-dive on public finances specifically.
- `/econ-audit` can audit this skill's output for source vintages and consistency.
