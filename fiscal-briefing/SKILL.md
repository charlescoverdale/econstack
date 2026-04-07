---
name: fiscal-briefing
description: Public finances briefing. Supports UK, US, and Australia. Borrowing/deficit, debt, receipts, spending, fiscal rules/outlook. Interactive section selection.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
  - Skill
---

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

If learnings are found, apply them to this session. When a prior learning influences a decision (e.g., defaulting to a framework because the user always picks it, or applying a custom parameter override), note: "Prior learning applied: [key]".

**Capturing new learnings:** After completing this skill, log any new insights about the user's preferences, parameter choices, or project-specific quirks using:

```bash
~/.claude/skills/econstack/bin/econstack-learnings-log '<json>'
```

Learning types for econstack:

| Type | When to log | Example |
|------|-------------|---------|
| `framework` | User picks or confirms a framework | `{"skill":"cost-benefit","type":"framework","key":"uk-green-book","insight":"User prefers UK Green Book with 3.5% declining","confidence":9,"source":"observed"}` |
| `parameter` | User overrides a default parameter | `{"skill":"cost-benefit","type":"parameter","key":"optimism-bias-zero","insight":"User always sets optimism bias to 0% with justification for this project","confidence":8,"source":"observed"}` |
| `data-source` | User states a data preference | `{"skill":"macro-briefing","type":"data-source","key":"ons-abs-preferred","insight":"User prefers ONS ABS over HMRC for sector data","confidence":7,"source":"user-stated"}` |
| `output` | A report is generated | `{"skill":"cost-benefit","type":"output","key":"last-cba","insight":"Generated cba-hospital-uk-2026-04-07.json","confidence":10,"source":"observed"}` |
| `operational` | A tool or dependency is unavailable | `{"skill":"cost-benefit","type":"operational","key":"no-r-available","insight":"R is not installed, use deterministic sensitivity only","confidence":9,"source":"observed"}` |
| `preference` | User requests a specific format or style | `{"skill":"fiscal-briefing","type":"preference","key":"aud-millions-no-decimals","insight":"User wants all tables in AUD millions, no decimal places","confidence":8,"source":"user-stated"}` |

Confidence guide: 9-10 for directly observed or user-stated preferences. 6-8 for strong inferences. 4-5 for weak inferences. User-stated learnings never decay; observed/inferred learnings lose 1 confidence point per 30 days.

All learnings are stored locally at `~/.econstack/projects/` on the user's machine. Nothing is transmitted to any server.

# /fiscal-briefing: Public Finances Briefing

Generate a narrative briefing on public finances for the UK, US, or Australia. Covers the current deficit/surplus, debt position, receipts and spending breakdown, fiscal rules or sustainability context, and outlook.

**This skill is interactive.** It fetches the data, shows the key numbers, then asks what output you need.

## Arguments

```
/fiscal-briefing [options]
```

**Examples:**
```
/fiscal-briefing                    # UK (default)
/fiscal-briefing --country us       # US federal finances
/fiscal-briefing --country au       # Australian Commonwealth finances
/fiscal-briefing --full
```

**Options:**
- `--country <code>` : Country. `uk` (default), `us`, `au`
- `--full` : Skip menu, generate all sections
- `--dsa` : Add a debt sustainability analysis section using the `debtkit` R package (projections, stress tests, fan chart description)
- `--client "Name"` : Add "Prepared for"
- `--exec` : Generate a management consulting-style executive summary deck (6 slides with action titles). Can be combined with `--format pptx` for both decks.
- `--audit` : After generating, run `/econ-audit` on the output
- `--format <type>` : Output format(s): `markdown`, `html`, `word`, `pptx`, `pdf`, or `all`. Comma-separate for multiple. Default: markdown only

## Country Routing

| Country | Data (A) | Dashboard (B) | Narrative (C) | Focus |
|---------|----------|---------------|---------------|-------|
| `uk` | A1: obr + ons packages | B1 | C1: 5 sections | PSNB, PSND, OBR forecasts, fiscal rules |
| `us` | A2: fred package | B2 | C2: 6 sections | Federal deficit, debt, receipts/outlays, CBO context |
| `au` | A3: readabs + fred/readoecd | B3 | C3: 5 sections | Underlying cash balance, revenue/expenses by function, net debt, Budget/MYEFO context |

## Instructions

### Step 1: Identify arguments and route

Parse flags. Determine country from `--country` (default: `uk`).

**Validate the country code.** Supported values: `uk`, `us`, `au`. If the user passes an unsupported code (e.g., `--country eu`, `--country nz`), stop and tell them: "Country '[code]' is not yet supported for fiscal briefings. Supported countries: uk (default), us, au. More countries coming soon."

- `uk`: A1 -> B1 -> C1
- `us`: A2 -> B2 -> C2
- `au`: A3 -> B3 -> C3

---

## SECTION A: DATA FETCHING

### A1: UK Data Fetching

**Approach A: R packages (if available)**

```bash
Rscript -e "library(obr); cat('R_READY')" 2>/dev/null
```

If R is available:
```r
library(obr)
library(ons)
library(jsonlite)

tryCatch({
  data <- list(
    psnb = get_psnb(),
    psnd = get_psnd(),
    public_finances = ons_public_finances(),
    receipts = get_receipts(),
    expenditure = get_expenditure(),
    forecasts = get_forecasts(),
    efo_fiscal = get_efo_fiscal()
  )
  cat(toJSON(data, auto_unbox=TRUE, pretty=TRUE))
}, error = function(e) {
  cat(paste0("ERROR: ", e$message))
})
```

**Approach B: Direct web fetch (if R not available)**

Fetch from ONS:
- PSNB ex: CDID `J5II` from `governmentpublicsectorandtaxes/publicsectorfinance`
- PSND ex % GDP: CDID `HF6X` from `governmentpublicsectorandtaxes/publicsectorfinance`

Use the same ONS CSV endpoint pattern as `/macro-briefing`.

For OBR forecasts, use WebFetch on the OBR website tables or note "OBR forecast comparison requires the obr R package."

---

### A2: US Data Fetching

**Only run if `--country us` is specified.** Requires the `fred` R package with a FRED API key.

```bash
Rscript -e '
  library(fred); library(jsonlite)

  tryCatch({
    data <- list(
      # Monthly (Treasury Monthly Statement)
      deficit_monthly = tail(fred_series("MTSDS133FMS"), 12),
      receipts_monthly = tail(fred_series("MTSR133FMS"), 12),
      outlays_monthly = tail(fred_series("MTSO133FMS"), 12),

      # Quarterly receipts breakdown (BEA NIPA, SAAR)
      income_tax = tail(fred_series("A074RC1Q027SBEA"), 8),
      corporate_tax = tail(fred_series("B075RC1Q027SBEA"), 8),
      social_insurance = tail(fred_series("W780RC1Q027SBEA"), 8),
      excise_tax = tail(fred_series("B234RC1Q027SBEA"), 8),

      # Quarterly spending breakdown (BEA NIPA, SAAR)
      interest_payments = tail(fred_series("A091RC1Q027SBEA"), 8),
      defense = tail(fred_series("FDEFX"), 8),
      social_security = tail(fred_series("W823RC1"), 8),
      medicare = tail(fred_series("W824RC1"), 8),
      medicaid = tail(fred_series("W729RC1"), 8),

      # Debt
      gross_debt = tail(fred_series("GFDEBTN"), 8),
      debt_to_gdp = tail(fred_series("GFDEGDQ188S"), 8),
      debt_public_to_gdp = tail(fred_series("FYGFGDQ188S"), 8),

      # Annual interest trend (OMB)
      interest_annual = tail(fred_series("FYOINT"), 10),
      interest_pct_gdp = tail(fred_series("FYOIGDA188S"), 10)
    )
    cat(toJSON(data, auto_unbox=TRUE, pretty=TRUE))
  }, error = function(e) {
    cat(paste0("ERROR: ", e$message))
  })
'
```

If fred is not installed or the API key is missing, tell the user:
"The US fiscal briefing requires the fred R package with a FRED API key.
Install with: install.packages('fred')
Set key with: fred_set_key('YOUR_KEY')
Get a free key from: https://fredaccount.stlouisfed.org/apikeys"
Stop.

**Data notes:**
- Monthly deficit/receipts/outlays are from the Treasury Monthly Statement (MTS). Not seasonally adjusted.
- Quarterly receipts and spending breakdowns are from BEA National Income and Product Accounts (NIPA Table 3.2), reported as Seasonally Adjusted Annual Rates (SAAR) in billions of dollars.
- Spending by program (Social Security, Medicare, Medicaid) uses BEA "benefits to persons" series, which differ slightly from OMB budget authority figures.
- CBO baseline projections are NOT available on FRED. Reference Claude's knowledge of recent CBO reports and note: "CBO projections sourced from cbo.gov, not FRED."

---

### A3: Australia Data Fetching

**Only run if `--country au` is specified.** Uses `readabs` (primary) for quarterly ABS Government Finance Statistics, with `fred` and `readoecd` as backup for headline numbers.

**Primary approach: readabs + ABS SDMX API**

```bash
Rscript -e '
  library(jsonlite)
  data <- list()

  if (requireNamespace("readabs", quietly = TRUE)) {
    library(readabs)

    # ABS Government Finance Statistics (Cat. 5519.0)
    # The ABS SDMX API provides quarterly GFS data for all levels of government.
    # Key series: Commonwealth general government sector
    tryCatch({
      # Total revenue, expenses, net operating balance, net lending/borrowing
      gfs <- read_abs(cat_no = "5519.0")

      # Filter for Commonwealth general government
      # Key series IDs (check with browse_abs for current codes):
      # Revenue: total taxation, income tax, GST, excise, company tax
      # Expenses: total, social security & welfare, health, education, defence, interest
      # Balance: underlying cash balance, fiscal balance, net operating balance
      # Debt: net debt

      data$gfs_raw <- gfs
      data$source <- "ABS GFS Cat. 5519.0"
    }, error = function(e) {
      message("ABS GFS fetch failed: ", e$message)
    })
  }

  # Backup: FRED + readoecd for headline numbers
  if (length(data) == 0 || is.null(data$gfs_raw)) {
    if (requireNamespace("fred", quietly = TRUE)) {
      library(fred)
      tryCatch({
        data$debt_total = tail(fred_series("GGGDTAAUA188N"), 10)
        data$deficit = tail(fred_series("GGNLBAAUA188N"), 10)
        data$cash_balance = tail(fred_series("CASHBLAUA188A"), 10)
        data$source <- "FRED (IMF WEO)"
      }, error = function(e) message("FRED AU fiscal failed: ", e$message))
    }
    if (requireNamespace("readoecd", quietly = TRUE)) {
      library(readoecd)
      tryCatch({
        data$deficit_pct_gdp = get_oecd_deficit("AUS")
        data$tax_pct_gdp = get_oecd_tax("AUS")
        if (is.null(data$source)) data$source <- "OECD"
        else data$source <- paste0(data$source, " + OECD")
      }, error = function(e) NULL)
    }
  }

  if (length(data) == 0) {
    cat("ERROR: No AU fiscal data available. Install readabs (recommended), or fred/readoecd for headline numbers.")
  } else {
    cat(toJSON(data, auto_unbox=TRUE, pretty=TRUE))
  }
'
```

**If readabs is available:** Parse the GFS data to extract Commonwealth general government sector aggregates. The ABS GFS covers:
- **Revenue:** Total taxation revenue, income tax (individuals + companies separately), goods and services tax (GST), excise, superannuation taxes, other
- **Expenses:** Total expenses, social security and welfare, health, education, defence, public order and safety, interest, other
- **Balances:** Net operating balance, fiscal balance, underlying cash balance
- **Debt:** Net debt, gross debt

**If readabs is NOT available:** Fall back to FRED (annual IMF WEO data: gross debt, net lending/borrowing, cash balance) and readoecd (annual deficit % GDP, tax % GDP). Note: "Detailed quarterly fiscal data requires the readabs package. Install with: install.packages('readabs'). Currently showing annual headline numbers only."

**Data notes:**
- ABS GFS is quarterly, with approximately 3-month lag.
- The underlying cash balance (UCB) is the headline measure in Australian budget reporting, analogous to the UK PSNB.
- Australian fiscal year runs July to June, not calendar year.
- GST revenue is collected by the Commonwealth but distributed to states. The fiscal briefing should note this.

---

## SECTION B: DASHBOARDS

### Step 2: Show the dashboard and ask what the user needs

### B1: UK Dashboard

```
PUBLIC FINANCES
================
PSNB (latest month):     £[val]bn
PSNB (YTD):              £[val]bn     (OBR forecast: £[val]bn full year)
PSND:                    [val]% GDP   (£[val]bn)
Debt interest (month):   £[val]bn
Headroom vs fiscal rule: £[val]bn (OBR estimate)
```

### B2: US Dashboard

```
US FEDERAL FINANCES
====================
Deficit (latest month):    $[val]bn
Deficit (FYTD):            $[val]bn
Receipts (latest month):   $[val]bn
Outlays (latest month):    $[val]bn
Gross federal debt:        $[val]tn    ([val]% of GDP)
Debt held by public:       [val]% of GDP
Interest payments (SAAR):  $[val]bn/yr ([val]% of GDP)

Data as of: [latest date]. US fiscal year runs Oct-Sep.
```

### B3: Australia Dashboard

**If readabs data available (quarterly GFS):**
```
AUSTRALIAN COMMONWEALTH FINANCES
=================================
Underlying cash balance (quarter):  A$[val]bn
UCB (FYTD):                         A$[val]bn     (Budget forecast: A$[val]bn full year)
Net debt:                            [val]% GDP   (A$[val]bn)
Total revenue (quarter):            A$[val]bn
Total expenses (quarter):           A$[val]bn
Interest payments (quarter):        A$[val]bn

Data as of: [quarter]. Australian fiscal year runs Jul-Jun.
```

**If backup data only (annual FRED/OECD):**
```
AUSTRALIAN GOVERNMENT FINANCES (ANNUAL)
========================================
Net lending/borrowing:    [val]% of GDP
Gross debt:               A$[val]bn
Tax revenue:              [val]% of GDP

Data as of: [year]. Annual data only. Install readabs for quarterly detail.
```

### Interactive Menu

**If `--full` was NOT specified**, ask using AskUserQuestion:

Question: "What output do you need?"

Options:
- A) **Full briefing** : All sections
- B) **Pick sections** : Choose which sections
- C) **Summary** : Just the dashboard table and one-paragraph narrative
- D) **Data only** : JSON

**If user picks B** (multiSelect: true):

**UK sections:**
- Current fiscal position (PSNB, PSND, comparison to OBR forecast)
- Receipts breakdown (tax receipts by source)
- Expenditure breakdown (spending by category, debt interest)
- Fiscal rules and headroom (current targets, how much room)
- Outlook (OBR forecasts, key risks)
- Methodology note (one paragraph)

**US sections:**
- Current fiscal position (deficit monthly and FYTD, debt level)
- Federal receipts (income tax, corporate, payroll, excise)
- Federal outlays (Social Security, Medicare, Medicaid, defense, interest)
- Interest on the debt (trend, % of GDP, comparison to defense)
- Debt dynamics (gross vs held by public, debt-to-GDP trajectory)
- Outlook and risks (CBO context, entitlements, debt ceiling)

**Australia sections:**
- Current fiscal position (underlying cash balance, net debt)
- Revenue (income tax, company tax, GST, excise, superannuation tax)
- Expenses by function (social security, health, education, defence, interest)
- Net debt dynamics (net debt trajectory, gross vs net)
- Outlook and risks (Budget/MYEFO context, terms of trade, commodity exposure)

---

## SECTION C: NARRATIVE TEMPLATES

### Step 3: Generate the requested output

**Always include key numbers block and companion JSON.**

### C1: UK Narrative Templates

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

**UK slide summary:**
```markdown
**UK Public Finances, [Month Year]**

- PSNB **£[val]bn YTD**, [above/below] OBR's £[val]bn full-year forecast
- PSND at **[val]% of GDP** (£[val]bn)
- Debt interest **£[val]bn/month**, [elevated / manageable]
- Headroom against fiscal rules: **£[val]bn** ([thin / comfortable])
- OBR projects borrowing [falling/rising] to £[val]bn by [year]

*Data from ONS and OBR. Powered by econstack.*
```

---

### C2: US Narrative Templates

**US key numbers block:**
```markdown
<!-- KEY NUMBERS
type: fiscal
date: [YYYY-MM-DD]
framework: us
deficit_monthly_bn: [val]
deficit_fytd_bn: [val]
receipts_monthly_bn: [val]
outlays_monthly_bn: [val]
gross_debt_tn: [val]
debt_to_gdp_pct: [val]
debt_public_to_gdp_pct: [val]
interest_saar_bn: [val]
interest_pct_gdp: [val]
-->
```

**Current fiscal position:**
```markdown
## Current Fiscal Position

**The federal government ran a deficit of $[val]bn in [month], bringing the fiscal year-to-date deficit to $[val]bn.** This compares to a FYTD deficit of $[val]bn at the same point last year, a [increase/decrease] of $[val]bn ([val]%).

Total receipts in [month] were $[val]bn. Total outlays were $[val]bn. [Note any distortions from payment timing shifts, which are common in the MTS data.]

| Metric | [Month] | FYTD | Prior year FYTD |
|--------|---------|------|-----------------|
| Receipts | $[val]bn | $[val]bn | $[val]bn |
| Outlays | $[val]bn | $[val]bn | $[val]bn |
| Deficit (-) | -$[val]bn | -$[val]bn | -$[val]bn |

*Note: The US federal fiscal year runs October to September, not calendar year. FYTD figures accumulate from October 1.*
```

**Federal receipts:**
```markdown
## Federal Receipts

**Federal receipts totalled $[val]bn (SAAR) in [quarter], [up/down] [val]% from a year earlier.**

| Revenue source | SAAR ($bn) | YoY change | Share |
|---------------|-----------|-----------|-------|
| Individual income tax | $[val] | [val]% | [val]% |
| Social insurance (payroll) | $[val] | [val]% | [val]% |
| Corporate income tax | $[val] | [val]% | [val]% |
| Excise taxes | $[val] | [val]% | [val]% |

Individual income tax and social insurance contributions together account for roughly 80% of federal revenue. Corporate tax receipts are volatile and sensitive to the business cycle. [1-2 sentences on what is driving the revenue trend.]

*Note: Quarterly figures are from BEA NIPA (seasonally adjusted annual rate). Monthly MTS figures are not seasonally adjusted and show significant month-to-month variation due to payment timing.*
```

**Federal outlays:**
```markdown
## Federal Outlays

**Federal spending totalled $[val]bn (SAAR) in [quarter].**

| Category | SAAR ($bn) | Share of total |
|----------|-----------|---------------|
| Social Security | $[val] | [val]% |
| Medicare | $[val] | [val]% |
| Medicaid | $[val] | [val]% |
| **Entitlements subtotal** | **$[val]** | **[val]%** |
| National defense | $[val] | [val]% |
| Interest on the debt | $[val] | [val]% |

The three major entitlement programs (Social Security, Medicare, Medicaid) account for approximately [val]% of federal spending and are growing as the population ages. [1-2 sentences on spending dynamics.]

*Note: Spending figures use BEA "benefits to persons" series, which measure cash and in-kind transfers. These differ slightly from OMB budget authority/outlay figures but capture the same underlying trends.*
```

**Interest on the debt:**
```markdown
## Interest on the Debt

**Federal interest payments are running at $[val]bn annually (SAAR), or [val]% of GDP.** This is [up/down] from [val]% of GDP a year ago and [val]% a decade ago.

Net interest now [exceeds / is approaching] national defense spending ($[val]bn), a threshold last crossed in the late 1990s. [If interest > defense: "Interest on the debt is now the [Nth] largest category of federal spending."]

| Year | Interest ($bn) | % of GDP |
|------|---------------|----------|
| [Year-5] | $[val] | [val]% |
| [Year-3] | $[val] | [val]% |
| [Year-1] | $[val] | [val]% |
| [Latest] | $[val] | [val]% |

**Rate sensitivity:** Every 100bp increase in average borrowing costs adds approximately $[estimated]bn to annual interest expense, given the current debt stock. The weighted average maturity of outstanding Treasury securities is approximately 6 years, meaning rate increases feed through gradually, not immediately.
```

**Debt dynamics:**
```markdown
## Debt Dynamics

**Gross federal debt stands at $[val]tn, or [val]% of GDP.** Debt held by the public (the measure most economists focus on) is [val]% of GDP.

| Measure | Level | % of GDP | Year ago |
|---------|-------|----------|----------|
| Gross federal debt | $[val]tn | [val]% | [val]% |
| Debt held by public | $[val]tn | [val]% | [val]% |

The difference between gross debt and debt held by the public ([val]% of GDP) represents intragovernmental holdings, primarily the Social Security and Medicare trust funds. As these trust funds draw down (Social Security OASI trust fund projected to be depleted by [year per latest Trustees report]), intragovernmental holdings shrink and are replaced by publicly held debt.

[1-2 sentences on the debt trajectory: is debt-to-GDP rising, stable, or falling? What is driving the trajectory?]

*Note: Gross debt includes the statutory debt limit. Debt held by the public excludes intragovernmental holdings and is the standard measure for fiscal sustainability analysis.*
```

**Outlook and risks:**
```markdown
## Outlook and Risks

CBO baseline projections are published separately at cbo.gov/data/budget-economic-data. As of the latest CBO report, CBO projects [use Claude's knowledge of the most recent CBO baseline: deficit trajectory, debt-to-GDP path, key assumptions].

**Key structural pressures:**
- Entitlement spending (Social Security + Medicare) is projected to grow from ~[val]% to ~[val]% of GDP over the next decade as the population ages
- Net interest costs are projected to remain elevated, [val]% of GDP by [year]
- Revenue as a share of GDP is projected to [rise/remain stable] at ~[val]%

**Key risks:**
- Higher-than-expected interest rates would accelerate debt accumulation
- Economic downturn would reduce tax revenues and trigger automatic stabilizers
- Entitlement reform remains politically difficult. Social Security OASI trust fund depletion would trigger automatic [~20%] benefit cuts under current law
- Debt ceiling dynamics create periodic fiscal cliff risks

[1-2 sentences on overall fiscal sustainability assessment.]

*Note: CBO projections assume current law. Actual outcomes depend on future legislation. CBO does not factor in likely policy changes (e.g., extension of expiring tax provisions).*
```

**US methodology note:**
```markdown
**Data sources:** Monthly Treasury Statement via FRED (deficit, receipts, outlays). BEA NIPA Table 3.2 via FRED (quarterly receipts and spending breakdown, SAAR). OMB historical tables via FRED (annual interest, debt). Debt from Treasury Fiscal Service via FRED. CBO baseline projections from cbo.gov. All FRED data fetched via the fred R package.
```

**US slide summary:**
```markdown
**US Federal Finances, [Month Year]**

- Federal deficit **$[val]bn FYTD** (fiscal year runs Oct-Sep)
- Gross debt **$[val]tn** (**[val]% of GDP**), debt held by public **[val]%**
- Interest payments **$[val]bn/yr** (**[val]% of GDP**), [exceeding / approaching] defense
- Receipts driven by [income tax / payroll], outlays by [entitlements]
- Entitlements (SS + Medicare + Medicaid) = **[val]%** of spending

*Data from FRED (Treasury Monthly Statement, BEA NIPA, OMB). Powered by econstack.*
```

---

### C3: Australia Narrative Templates

**Australia key numbers block:**
```markdown
<!-- KEY NUMBERS
type: fiscal
date: [YYYY-MM-DD]
framework: au
ucb_quarter_bn: [val]
ucb_fytd_bn: [val]
net_debt_bn: [val]
net_debt_pct_gdp: [val]
revenue_quarter_bn: [val]
expenses_quarter_bn: [val]
interest_quarter_bn: [val]
-->
```

**Current fiscal position:**
```markdown
## Current Fiscal Position

**The Commonwealth underlying cash balance was [surplus/deficit] A$[val]bn in the [month] quarter [year], bringing the fiscal year-to-date balance to [surplus/deficit] A$[val]bn.** This compares to the Budget estimate of A$[val]bn for the full year [year]-[year+1].

Net debt stands at A$[val]bn, or [val]% of GDP. [Up/down] from [val]% a year ago.

| Metric | Latest quarter | FYTD | Budget forecast (full year) |
|--------|---------------|------|---------------------------|
| Underlying cash balance | A$[val]bn | A$[val]bn | A$[val]bn |
| Net debt (% GDP) | [val]% | - | [val]% |
| Total revenue | A$[val]bn | A$[val]bn | - |
| Total expenses | A$[val]bn | A$[val]bn | - |

*Note: The Australian fiscal year runs July to June. The underlying cash balance (UCB) is the headline fiscal measure, analogous to the UK PSNB.*
```

**Revenue:**
```markdown
## Commonwealth Revenue

**Total Commonwealth revenue was A$[val]bn in [quarter], [up/down] [val]% year-on-year.**

| Revenue source | A$bn | Share | YoY change |
|---------------|------|-------|-----------|
| Individuals income tax | [val] | [val]% | [val]% |
| Company tax | [val] | [val]% | [val]% |
| GST | [val] | [val]% | [val]% |
| Excise and customs | [val] | [val]% | [val]% |
| Superannuation taxes | [val] | [val]% | [val]% |
| Other | [val] | [val]% | [val]% |

Individual income tax and company tax together account for roughly 70% of Commonwealth revenue. [1-2 sentences on what is driving the revenue trend.]

*Note: GST is collected by the Commonwealth but distributed to state and territory governments. It is included in Commonwealth revenue but offset by payments to states. The net Commonwealth revenue position is lower than the headline figure.*
```

**Expenses by function:**
```markdown
## Commonwealth Expenses

**Total Commonwealth expenses were A$[val]bn in [quarter].**

| Function | A$bn | Share of total |
|----------|------|---------------|
| Social security and welfare | [val] | [val]% |
| Health | [val] | [val]% |
| Education | [val] | [val]% |
| Defence | [val] | [val]% |
| Interest (public debt) | [val] | [val]% |
| Other (general public services, transport, housing, etc.) | [val] | [val]% |

Social security and welfare is the largest spending category (predominantly Age Pension, JobSeeker, NDIS, and Family Tax Benefit). Health spending includes Medicare, the Pharmaceutical Benefits Scheme, and hospital funding. [1-2 sentences on spending dynamics.]

*Note: Expenses are classified by Government Purpose Classification (GPC), the Australian equivalent of the UK's functional spending classification. The NDIS (National Disability Insurance Scheme) is the fastest-growing spending category.*
```

**Net debt dynamics:**
```markdown
## Net Debt

**Commonwealth net debt stands at A$[val]bn, or [val]% of GDP.** This is [up/down] from [val]% a year ago.

| Measure | Level (A$bn) | % of GDP | Year ago |
|---------|-------------|----------|----------|
| Net debt | [val] | [val]% | [val]% |
| Gross debt | [val] | [val]% | [val]% |

Net debt is the headline measure in Australian fiscal reporting (analogous to UK PSND). It equals the sum of interest-bearing liabilities minus financial assets (deposits, investments, loans). Gross debt is higher because it does not net off financial assets.

[1-2 sentences on the debt trajectory: is net debt rising, stable, or falling as a share of GDP?]

*By international standards, Australian net debt is low relative to GDP compared to the UK (~100%), US (~100%), and Japan (~160%). However, it has risen significantly since the GFC and COVID-19.*
```

**Outlook and risks:**
```markdown
## Outlook and Risks

The latest Budget ([month year]) / MYEFO ([month year]) projects:

| Metric | [Year] | [Year+1] | [Year+2] | [Year+3] |
|--------|--------|----------|----------|----------|
| UCB (A$bn) | [val] | [val] | [val] | [val] |
| Net debt (% GDP) | [val] | [val] | [val] | [val] |
| GDP growth | [val]% | [val]% | [val]% | [val]% |

[If readabs not available: "Budget/MYEFO projections are published as Excel tables on budget.gov.au and data.gov.au. The figures above are from Claude's knowledge of the most recent Budget. Verify against the latest release."]

**Key risks:**
- Terms of trade: Australia's fiscal position is sensitive to iron ore and coal prices. A sustained fall in commodity prices would reduce company tax receipts materially.
- NDIS growth: the National Disability Insurance Scheme is growing at [~8-10%] per year, faster than GDP. Cost containment is a key fiscal challenge.
- Interest rates: higher-than-expected rates increase debt servicing costs, though Australian net interest payments are relatively low by international standards.
- Population aging: Age Pension and health spending will grow as the dependency ratio rises, though less sharply than in the UK or continental Europe due to compulsory superannuation.

[1-2 sentences on overall fiscal sustainability assessment.]
```

**Australia methodology note:**
```markdown
**Data sources:** ABS Government Finance Statistics (Cat. 5519.0, quarterly) via readabs R package. Budget and MYEFO estimates from budget.gov.au. Headline numbers from FRED (IMF WEO) and OECD where quarterly ABS data not available. Underlying cash balance is the headline fiscal measure. Net debt excludes Future Fund assets from the denominator. Fiscal year runs July to June.
```

**Australia slide summary:**
```markdown
**Australian Commonwealth Finances, [Month Year]**

- Underlying cash balance **A$[val]bn FYTD** (fiscal year Jul-Jun)
- Net debt at **[val]% of GDP** (A$[val]bn), [low by international standards]
- Revenue driven by [income tax / company tax / commodity prices]
- Social security + health + NDIS = **[val]%** of spending
- Budget projects [surplus/deficit] of A$[val]bn in [year]-[year+1]

*Data from ABS GFS (via readabs) and Budget papers. Powered by econstack.*
```

---

### DSA Section (only if `--dsa` is specified)

**If `--dsa` is specified**, run a debt sustainability analysis using the `debtkit` R package and append the results as an additional section after the narrative.

```bash
Rscript -e '
  library(debtkit); library(jsonlite)

  # Set up the projection based on the country
  # UK: use PSND data, ~100% debt/GDP, primary balance from PSNB minus interest
  # US: use debt held by public, ~100% debt/GDP
  # AU: use net debt, ~25-30% debt/GDP

  # IMPORTANT: Replace ALL placeholders below with numeric values from the
  # fiscal data already fetched BEFORE running this Rscript. These are NOT
  # valid R syntax as written. Example: debt_gdp = 98.5, not debt_gdp = [98.5].

  tryCatch({
    # Base case projection (10 years)
    proj <- dk_project(
      debt_gdp = DEBT_TO_GDP_VALUE,
      primary_balance_gdp = PRIMARY_BALANCE_VALUE,
      interest_rate = EFFECTIVE_INTEREST_RATE_VALUE,
      growth_rate = GDP_GROWTH_VALUE,
      years = 10
    )

    # Stress tests (IMF-style)
    stress <- dk_stress_test(
      debt_gdp = DEBT_TO_GDP_VALUE,
      primary_balance_gdp = PRIMARY_BALANCE_VALUE,
      interest_rate = EFFECTIVE_INTEREST_RATE_VALUE,
      growth_rate = GDP_GROWTH_VALUE
    )

    cat(toJSON(list(projection = proj, stress = stress), auto_unbox=TRUE, pretty=TRUE))
  }, error = function(e) {
    cat(paste0("DSA ERROR: ", e$message))
  })
'
```

**Fill the bracketed values from the fiscal data already fetched:**
- `current_debt_to_gdp`: From the dashboard data (PSND for UK, GFDEGDQ188S for US, ABS net debt for AU)
- `current_primary_balance_to_gdp`: Deficit minus interest payments, divided by GDP
- `current_effective_interest_rate`: Interest payments divided by debt stock
- `assumed_gdp_growth`: Latest GDP growth from the macro briefing or OBR/CBO/Budget forecasts

**If debtkit is not installed**, tell the user: "DSA requires the debtkit R package. Install with: install.packages('debtkit')" and skip.

**DSA narrative template:**
```markdown
## Debt Sustainability Analysis

**Under baseline assumptions, [country] debt-to-GDP is projected to [rise to / stabilise at / fall to] [val]% by [year+10].**

### Baseline Projection

| Year | Debt/GDP | Primary balance | Interest/GDP | Growth |
|------|----------|----------------|-------------|--------|
| [Year] | [val]% | [val]% | [val]% | [val]% |
| [Year+3] | [val]% | [val]% | [val]% | [val]% |
| [Year+5] | [val]% | [val]% | [val]% | [val]% |
| [Year+10] | [val]% | [val]% | [val]% | [val]% |

### Stress Tests

| Scenario | Debt/GDP at year 5 | Debt/GDP at year 10 |
|----------|-------------------|---------------------|
| Baseline | [val]% | [val]% |
| Interest rate +200bp | [val]% | [val]% |
| Growth -1pp | [val]% | [val]% |
| Primary balance worsens 1% GDP | [val]% | [val]% |
| Combined shock | [val]% | [val]% |

[2-3 sentences interpreting: Is the debt path sustainable? What shock would push it onto an unsustainable trajectory? How much fiscal consolidation would be needed to stabilise debt/GDP?]

*Analysis computed using the debtkit R package (dk_project, dk_stress_test). Assumptions: [list key assumptions]. This is a mechanical projection, not a forecast.*
```

---

## SECTION D: OUTPUT

### Step 3b: Output formats

**If `--format` was NOT specified on the command line**, ask using AskUserQuestion:

Question: "What file formats do you need?"

Options (multiSelect: true):
- Markdown (.md) : Default, always included
- HTML : Self-contained branded page for email or browser
- Word (.docx) : Formatted document for editing
- PowerPoint (.pptx) : Slide deck with dashboard and key charts
- PDF : Branded consulting-quality PDF via Quarto

Markdown is always generated regardless of selection.

### Step 4: Save and present

Save as `fiscal-briefing-{country}-{date}.md`. Always save `fiscal-data-{country}-{date}.json`.

**Then generate each additional format the user selected:**

**HTML** (if selected):
Generate a self-contained HTML file with inline CSS. Navy branding (#003078), dashboard KPI cards, professional tables. Save as `fiscal-briefing-{country}-{date}.html`.

**Word (.docx)** (if selected):
Invoke the `/docx` skill. Navy headings, formatted tables, title page. Save as `fiscal-briefing-{country}-{date}.docx`.

**PowerPoint (.pptx)** (if selected):
Invoke the `/pptx` skill. Slides: (1) Title, (2) Dashboard, (3) Receipts table, (4) Expenditure table, (5) Debt/outlook, (6) Methodology. Save as `fiscal-briefing-{country}-{date}.pptx`.

**Executive summary deck** (if `--exec` specified):

Invoke the `/pptx` skill to create a management consulting-style executive summary deck. Every slide follows the **action title + evidence** pattern: a 2-line strapline stating the conclusion (a complete sentence, NOT a topic label), then 3-4 dot points proving it.

Formatting: Action title 24-28pt bold navy (#003078). Body 14-16pt, one key number bolded per bullet. Footer 10pt light grey with data source + vintage date. Clean white background, no decorative elements. Slide numbers bottom-right.

**Slide 1: Title**
- "[Country] Public Finances Briefing" (large, navy)
- [Month Year], "Prepared for: [client]" if specified

**Slide 2: Headline**
- Action title: "Public finances are [improving/deteriorating/stable], with borrowing at [currency][X]bn ([X]% of GDP)"
- Evidence:
  - [Deficit measure]: **[currency][X]bn** ([X]% of GDP)
  - [Debt measure]: **[currency][X]bn** ([X]% of GDP)
  - Trend: [improving/deteriorating] vs [previous year / forecast]
  - [Key driver: e.g. "Higher-than-expected tax receipts offset spending pressures"]

**Slide 3: Receipts**
- Action title: "Tax receipts are [above/below/in line with] forecast, driven by [top category]"
- Evidence:
  - Total receipts: **[currency][X]bn** ([X]% of GDP)
  - Income tax: **[currency][X]bn** ([+/-X]% YoY)
  - [Second largest]: **[currency][X]bn**
  - [Key trend or surprise]
- Optional: horizontal bar chart of receipts by category

**Slide 4: Spending**
- Action title: "Spending is [rising/falling/stable] at [currency][X]bn, with [department/category] driving [growth/pressure]"
- Evidence:
  - Total spending: **[currency][X]bn** ([X]% of GDP)
  - [Largest category]: **[currency][X]bn**
  - Debt interest: **[currency][X]bn** ([key context])
  - [Key trend or pressure point]

**Slide 5: Debt and sustainability**
- Action title: "Debt is [X]% of GDP and [rising/falling/stable], [on/off track] against fiscal rules"
- Evidence:
  - Debt: **[currency][X]bn** (**[X]%** of GDP)
  - Trajectory: [rising/falling] over the forecast period
  - [If DSA available]: Debt projected to [peak/stabilise] at [X]% by [year]
  - Fiscal rule status: [met/at risk/breached]

**Slide 6: Fiscal rules and outlook**
- Action title: "[Fiscal rule] headroom is [currency][X]bn, [leaving room / creating pressure] for [policy context]"
- Evidence:
  - [Rule 1]: [status, headroom]
  - [Rule 2]: [status]
  - Key risks: [2-3 bullets on downside scenarios]
- Footer: "Full briefing: fiscal-briefing-{country}-{date}.md"

Save as `fiscal-exec-{country}-{date}.pptx`.

**PDF** (if selected):
```bash
ECONSTACK_DIR="$HOME/.claude/skills/econstack"
"$ECONSTACK_DIR/scripts/render-report.sh" fiscal-briefing-{country}-{date}.md \
  --title "[Country] Public Finances Briefing" \
  --subtitle "[Month Year]"
```

Tell the user what was generated:
```
Files saved:
  fiscal-briefing-{country}-{date}.md      (report)
  fiscal-data-{country}-{date}.json        (structured data)
  fiscal-briefing-{country}-{date}.html    (if HTML selected)
  fiscal-briefing-{country}-{date}.docx    (if Word selected)
  fiscal-briefing-{country}-{date}.pptx    (if PowerPoint selected)
  fiscal-briefing-{country}-{date}.pdf     (if PDF selected)
```

Country-specific data source footer:
- UK: *Data from ONS and OBR. Powered by econstack.*
- US: *Data from FRED (Treasury Monthly Statement, BEA NIPA, OMB). Powered by econstack.*
- AU: *Data from ABS GFS (via readabs) and Budget papers. Powered by econstack.*

## Important Rules

- Never use em dashes.
- Never attribute econstack to any individual.
- Every section stands alone.
- **Table and figure formatting (universal across all econstack outputs):**
  - **Numbering**: Every table is "Table 1: [short description]", every figure/chart is "Figure 1: [short description]". Numbering restarts at 1 for each report. The caption goes above the table/figure.
  - **Source note**: Below every table and figure: "Source: [Author/Publisher] ([year])." If multiple sources: "Sources: [Source 1]; [Source 2]."
  - **Notes line**: Below the source, if needed: "Notes: [caveats, e.g. 'real 2026 prices', '2024-25 data', 'estimated from available figures']."
  - **Minimal formatting (low ink-to-data ratio)**: No heavy borders or gridlines. Thin rule under the header row only. No shading on data cells (light grey alternating rows permitted in Excel/HTML only). Right-align all numbers. Left-align all text. Bold totals rows only. No decorative elements.
  - **Number formatting**: Currency with comma separators and 1 decimal place for millions (e.g. "GBP 45.2m"), whole numbers for counts (e.g. "1,250 jobs"), percentages to 1 decimal place (e.g. "3.5%").
  - **Consistency**: The same metric must use the same unit and precision throughout the report. Do not switch between "GBP m" and "GBP bn" for the same order of magnitude.
- Be specific about dates. "[Month Year]" not "last month".
- The companion JSON must include all fiscal data points.

**UK-specific:**
- PSNB ex (excluding public sector banks) is the standard headline measure.
- PSNFL is the current fiscal rule target, not PSND. Note the difference.
- Debt interest: always note if elevated due to RPI-linked gilt inflation accruals.
- Headroom is a point estimate subject to large forecast revision. Always caveat.
- Be specific about which OBR EFO is being referenced (month and year).

**US-specific:**
- The US fiscal year runs October to September. Always state this.
- Distinguish gross federal debt from debt held by the public. Economists use the latter; politicians cite the former. Both matter.
- Monthly MTS figures are not seasonally adjusted. Quarterly BEA NIPA figures are SAAR. Note the difference when mixing frequencies.
- CBO projections assume current law, which means expiring tax provisions expire. This is often unrealistic. Always caveat.
- Interest payments are the fastest-growing spending category. Always contextualize vs defense spending.
- Entitlement spending (Social Security, Medicare, Medicaid) is mandatory and grows on autopilot. Distinguish from discretionary spending when relevant.

**Australia-specific:**
- The Australian fiscal year runs July to June. Always state this.
- The underlying cash balance (UCB) is the headline fiscal measure. It is analogous to the UK PSNB.
- Net debt is the standard debt measure (financial liabilities minus financial assets). Gross debt is higher. Always specify which.
- GST is collected by the Commonwealth but distributed to states and territories. Note this when discussing revenue.
- The NDIS (National Disability Insurance Scheme) is the fastest-growing spending program. Always mention when discussing spending pressures.
- Australian net debt is low by international standards (vs UK ~100%, US ~100%, Japan ~160%). Provide this context.
- Commodity prices (iron ore, coal, LNG) drive company tax receipts. Terms of trade sensitivity is a key fiscal risk. Always mention.
- Be specific about which Budget or MYEFO is being referenced (month and year).
