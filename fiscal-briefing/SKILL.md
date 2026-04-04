---
name: fiscal-briefing
description: Public finances briefing (UK). Borrowing, debt, receipts, spending, and fiscal context. Interactive section selection.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

<!-- preamble: update check -->
Before starting, run this silently. If it outputs UPDATE_AVAILABLE, tell the user:
"A new version of econstack is available. Run `cd ~/.claude/skills/econstack && git pull` to update."
Then continue with the skill normally.

```bash
~/.claude/skills/econstack/bin/econstack-update-check 2>/dev/null || true
```

# /fiscal-briefing: Public Finances Briefing (UK)

Generate a narrative briefing on UK public finances: current borrowing vs OBR forecast, debt position, receipts and spending breakdown, fiscal rules headroom, and outlook. Designed for economic consultants and advisors who need the headline numbers and context, not a full debt sustainability model.

**This skill is interactive.** It fetches the data, shows the key numbers, then asks what output you need.

## Arguments

```
/fiscal-briefing [options]
```

**Examples:**
```
/fiscal-briefing
/fiscal-briefing --full
```

**Options:**
- `--full` : Skip menu, generate all sections
- `--client "Name"` : Add "Prepared for"
- `--format pdf` : Branded PDF

## Instructions

### Step 1: Fetch the data

**Approach A: R packages (if available)**

```bash
Rscript -e "library(obr); cat('R_READY')" 2>/dev/null
```

If R is available:
```r
library(obr)
library(ons)
psnb <- get_psnb()
psnd <- get_psnd()
public_finances <- ons_public_finances()
receipts <- get_receipts()
expenditure <- get_expenditure()
forecasts <- get_forecasts()
efo_fiscal <- get_efo_fiscal()
```

**Approach B: Direct web fetch (if R not available)**

Fetch from ONS:
- PSNB ex: CDID `J5II` from `governmentpublicsectorandtaxes/publicsectorfinance`
- PSND ex % GDP: CDID `HF6X` from `governmentpublicsectorandtaxes/publicsectorfinance`

Use the same ONS CSV endpoint pattern as `/macro-briefing`.

For OBR forecasts, use WebFetch on the OBR website tables or note "OBR forecast comparison requires the obr R package."

### Step 2: Show the dashboard and ask what the user needs

```
PUBLIC FINANCES
================
PSNB (latest month):     £[val]bn
PSNB (YTD):              £[val]bn     (OBR forecast: £[val]bn full year)
PSND:                    [val]% GDP   (£[val]bn)
Debt interest (month):   £[val]bn
Headroom vs fiscal rule: £[val]bn (OBR estimate)
```

**If `--full` was NOT specified**, ask using AskUserQuestion:

Question: "What output do you need?"

Options:
- A) **Full briefing** : All sections
- B) **Pick sections** : Choose which sections
- C) **Summary** : Just the dashboard table and one-paragraph narrative
- D) **Data only** : JSON

**If user picks B** (multiSelect: true):

Options:
- Current fiscal position (PSNB, PSND, comparison to OBR forecast)
- Receipts breakdown (tax receipts by source)
- Expenditure breakdown (spending by category, debt interest)
- Fiscal rules and headroom (current targets, how much room)
- Outlook (OBR forecasts, key risks)
- Methodology note (one paragraph)

### Step 3: Generate the requested output

**Always include key numbers block and companion JSON.**

#### Section templates

**Current fiscal position:**
```markdown
## Current Fiscal Position

**Public sector net borrowing was £[val]bn in [month], bringing the year-to-date total to £[val]bn.** This is £[val]bn [above/below] the same point last year and [above/below] the OBR's full-year forecast of £[val]bn from the [month year] EFO.

Public sector net debt stands at [val]% of GDP (£[val]bn), [up/down] from [val]% a year ago.

| Metric | Latest | Year ago | OBR forecast |
|--------|--------|----------|-------------|
| PSNB (monthly) | £[val]bn | £[val]bn | - |
| PSNB (YTD) | £[val]bn | £[val]bn | £[val]bn (full year) |
| PSND (% GDP) | [val]% | [val]% | [val]% |
| Debt interest | £[val]bn | £[val]bn | - |
```

**Receipts breakdown:**
```markdown
## Tax Receipts

**Total receipts in [period] were £[val]bn, [up/down] [val]% year-on-year.**

| Tax | Receipts | YoY change |
|-----|----------|-----------|
| Income tax | £[val]bn | [val]% |
| NICs | £[val]bn | [val]% |
| VAT | £[val]bn | [val]% |
| Corporation tax | £[val]bn | [val]% |
| Other | £[val]bn | [val]% |

[1-2 sentences: which taxes are outperforming or underperforming OBR assumptions?]
```

**Expenditure breakdown:**
```markdown
## Public Expenditure

**Total managed expenditure in [period] was £[val]bn.**

Debt interest payments were £[val]bn, accounting for [val]% of total spending. [Note if elevated due to RPI-linked gilt inflation accruals: a significant portion of UK government debt is index-linked, meaning debt interest costs are sensitive to RPI inflation.]

[1-2 sentences on spending trends.]
```

**Fiscal rules and headroom:**
```markdown
## Fiscal Rules

Current UK fiscal framework (October 2024):

| Rule | Target | Status |
|------|--------|--------|
| Stability rule | Current budget in balance by [year] | [On track / At risk] |
| Investment rule | PSNFL falling as % GDP by [year] | [On track / At risk] |

**Headroom against the investment rule is £[val]bn** (OBR estimate from [month year] EFO). [If < £10bn: "This is thin. Previous Chancellors have had headroom of £10-30bn. Small forecast revisions could eliminate it."]

Note: PSNFL (public sector net financial liabilities) is the current fiscal rule target, replacing the previous PSND target. PSNFL is broader than PSND, including items like student loans and funded pension liabilities.
```

**Outlook:**
```markdown
## Outlook

The OBR's latest forecast (EFO [month year]) projects:

| Metric | [Year] | [Year+1] | [Year+2] |
|--------|--------|----------|----------|
| PSNB (£bn) | [val] | [val] | [val] |
| PSND (% GDP) | [val] | [val] | [val] |
| GDP growth | [val]% | [val]% | [val]% |
| CPI inflation | [val]% | [val]% | [val]% |

**Key risks:**
- [1-2 upside risks: e.g., stronger growth, lower borrowing costs]
- [1-2 downside risks: e.g., weaker growth, higher interest rates, spending pressures]

[1-2 sentences on whether the current fiscal position is sustainable or under pressure.]
```

**Methodology note:**
```markdown
**Data sources:** Public sector finances from ONS (monthly). OBR forecasts from the Economic and Fiscal Outlook. Receipts and expenditure breakdowns from OBR. PSNB ex and PSND ex exclude public sector banks. Fiscal rules target PSNFL (broader than PSND). Data via obr and ons R packages.
```

**Slide summary:**
```markdown
**UK Public Finances — [Month Year]**

- PSNB **£[val]bn YTD**, [above/below] OBR's £[val]bn full-year forecast
- PSND at **[val]% of GDP** (£[val]bn)
- Debt interest **£[val]bn/month**, [elevated / manageable]
- Headroom against fiscal rules: **£[val]bn** ([thin / comfortable])
- OBR projects borrowing [falling/rising] to £[val]bn by [year]

*Data from ONS and OBR. Powered by econstack.*
```

### Step 4: Save and present

Save as `fiscal-briefing-{date}.md`. Always save `fiscal-data-{date}.json`.

## Important Rules

- Never use em dashes.
- Never attribute econstack to any individual.
- Every section stands alone.
- PSNB ex (excluding public sector banks) is the standard headline measure.
- PSNFL is the current fiscal rule target, not PSND. Note the difference.
- Debt interest: always note if elevated due to RPI-linked gilt inflation accruals.
- Headroom is a point estimate subject to large forecast revision. Always caveat.
- Be specific about which OBR EFO is being referenced (month and year).
- The companion JSON must include all fiscal data points.
