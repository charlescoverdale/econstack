---
name: fiscal-briefing
description: UK public finances analysis. Borrowing, debt, sustainability, Bohn test, fan charts, stress tests. Uses debtkit + obr. Interactive section selection.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# /fiscal-briefing: Public Finances and Debt Sustainability

Assess UK public finances: current borrowing position, debt trajectory, comparison to OBR forecasts, and debt sustainability analysis (Bohn test, fan charts, IMF stress tests, EC S1/S2 gaps). Follows the framework used by HM Treasury, the OBR, and the IFS Green Budget.

**This skill is interactive.** It pulls the latest data, runs sustainability tests, then asks what output you need.

## Arguments

```
/fiscal-briefing [options]
```

**Examples:**
```
/fiscal-briefing
/fiscal-briefing --full
/fiscal-briefing --focus sustainability
```

**Options:**
- `--full` : Skip menu, generate all sections
- `--focus <area>` : Emphasise one area (current, receipts, spending, sustainability, rules)
- `--client "Name"` : Add "Prepared for"
- `--format pdf` : Branded PDF

## Prerequisites

R packages: `debtkit`, `obr`, `ons`. Install with:
```r
install.packages(c("debtkit", "obr", "ons"))
```

## Instructions

### Step 1: Fetch data and run analysis

```r
library(debtkit)
library(obr)
library(ons)

# Current position
psnb <- get_psnb()
psnd <- get_psnd()
public_finances <- get_public_finances()
pf_ons <- ons_public_finances()

# Receipts and spending breakdown
receipts <- get_receipts()
expenditure <- get_expenditure()
welfare <- get_welfare_spending()

# OBR forecasts
forecasts <- get_forecasts()
efo_fiscal <- get_efo_fiscal()
efo_economy <- get_efo_economy()

# Sustainability analysis
# Prepare debt and primary balance series for debtkit
# dk_sample_data() provides example data if needed

# Bohn test
bohn <- dk_bohn_test(primary_balance, debt_ratio)

# r-g differential
rg <- dk_rg(interest_rate, growth_rate)

# Debt projection
projection <- dk_project(
  debt_ratio_initial = [latest PSND %],
  primary_balance = [latest primary balance %],
  interest_rate = [latest effective rate],
  growth_rate = [latest nominal growth],
  horizon = 10
)

# Fan chart
shocks <- dk_estimate_shocks(historical_data)
fan <- dk_fan_chart(projection, shocks)

# IMF stress tests
stress <- dk_stress_test(projection)

# EC sustainability gaps
gaps <- dk_sustainability_gap(projection)

# Debt dynamics decomposition
decomp <- dk_decompose(debt_series, primary_balance, interest, growth)
```

### Step 2: Show results and ask what the user needs

```
PUBLIC FINANCES DASHBOARD
==========================
PSNB (latest month):     £[val]bn
PSNB (YTD):              £[val]bn    (OBR forecast: £[val]bn)
PSND:                    [val]% GDP  (£[val]bn)
Debt interest (month):   £[val]bn

r - g differential:      [val]pp     ([positive = adverse / negative = favourable])
Bohn coefficient:        [val]       ([positive = stabilising / negative = unsustainable])
Headroom vs fiscal rule: £[val]bn

OBR PSNB forecast:       £[val]bn ([year])
OBR PSND forecast:       [val]% GDP ([year])
```

**If `--full` was NOT specified**, ask using AskUserQuestion:

Question: "What output do you need?"

Options:
- A) **Full fiscal analysis** : All 6 layers
- B) **Pick sections** : Choose which analyses
- C) **Summary dashboard** : Key fiscal stats only
- D) **Data only** : JSON

**If user picks B** (multiSelect: true):

Options:
- Current fiscal position (PSNB, PSND, comparison to OBR forecast)
- Receipts breakdown (tax receipts by source, year-on-year)
- Expenditure breakdown (spending by category, welfare, debt interest)
- Debt dynamics decomposition (primary deficit vs snowball effect)
- Sustainability assessment (Bohn test, r-g differential)
- Debt projection fan chart (stochastic scenarios)
- IMF stress tests (growth shock, interest rate shock, combined)
- EC sustainability gaps (S1 and S2)
- Fiscal rules and headroom
- Methodology summary (one paragraph)
- References

### Step 3: Generate the requested output

**Always include key numbers block and companion JSON.**

#### Section templates

**Current fiscal position:**
```markdown
## Current Fiscal Position

**Public sector net borrowing was £[val]bn in [month], bringing the year-to-date total to £[val]bn.** This is £[val]bn [above/below] the same point last year and £[val]bn [above/below] the OBR's full-year forecast of £[val]bn from the [month year] EFO.

Public sector net debt stands at [val]% of GDP (£[val]bn), [up/down] from [val]% a year ago. The current fiscal rule target is for PSNFL (public sector net financial liabilities) to fall as a share of GDP between [year] and [year].

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

| Tax | Receipts | YoY change | Share |
|-----|----------|-----------|-------|
| Income tax | £[val]bn | [val]% | [val]% |
| NICs | £[val]bn | [val]% | [val]% |
| VAT | £[val]bn | [val]% | [val]% |
| Corporation tax | £[val]bn | [val]% | [val]% |
| Fuel duty | £[val]bn | [val]% | [val]% |
| Stamp duty | £[val]bn | [val]% | [val]% |
| Other | £[val]bn | [val]% | [val]% |

[1-2 sentences: which taxes are driving growth/shortfall? Are receipts tracking above or below OBR assumptions?]
```

**Expenditure breakdown:**
```markdown
## Public Expenditure

**Total managed expenditure in [period] was £[val]bn.**

[Key spending categories with year-on-year changes.]

Debt interest payments were £[val]bn, accounting for [val]% of total spending. [Note if debt interest is elevated due to index-linked gilt inflation accruals.]

Welfare spending: £[val]bn. [Key welfare components and trends.]
```

**Debt dynamics decomposition:**
```markdown
## Debt Dynamics

**The debt-to-GDP ratio [rose/fell] by [val]pp in [period].** This decomposition shows why:

| Component | Contribution (pp) |
|-----------|-------------------|
| Primary deficit | +[val] |
| Snowball effect (r - g) | [+/-][val] |
| Stock-flow adjustment | [+/-][val] |
| **Total change** | **[+/-][val]** |

The r-g differential (effective interest rate minus nominal GDP growth) is [val]pp. [If negative: "With growth exceeding the interest rate, the snowball effect is reducing the debt ratio, partially offsetting the primary deficit."] [If positive: "The interest rate exceeding growth adds to the debt burden beyond the primary deficit itself."]

The key equation: delta(b) = primary deficit + (r - g) * b_{t-1} + stock-flow adjustment.

Reference: Blanchard (2019), "Public Debt and Low Interest Rates", AER.
```

**Sustainability assessment:**
```markdown
## Debt Sustainability

### Bohn Test

**The Bohn coefficient is [val] ([significant/insignificant] at the 5% level).** [If positive and significant: "This indicates a stabilising fiscal reaction function: the government systematically raises the primary balance when debt rises. This is a sufficient condition for fiscal sustainability (Bohn 1998)."] [If insignificant: "There is no statistically significant evidence of a stabilising fiscal reaction function in the data."]

| Parameter | Estimate | Std. Error | p-value |
|-----------|----------|------------|---------|
| Debt ratio (rho) | [val] | [val] | [val] |
| Output gap control | [val] | [val] | [val] |

Reference: Bohn (1998), "The Behavior of U.S. Public Debt and Deficits", QJE.

### r-g Differential

The r-g differential is currently [val]pp. Historically, r < g has been the norm for advanced economies (Blanchard 2019). The current [favourable/unfavourable] differential means debt dynamics are [self-correcting/adverse] even without primary surpluses.
```

**Fan chart:**
```markdown
## Debt Projection Fan Chart

Baseline projection: debt-to-GDP [rises to / falls to / stabilises at] [val]% by [year], assuming [growth, interest rate, primary balance assumptions].

The fan chart below shows the distribution of outcomes under stochastic shocks (bootstrapped from historical fiscal data):

| Percentile | Debt/GDP in 5 years | Debt/GDP in 10 years |
|-----------|--------------------|--------------------|
| 10th (optimistic) | [val]% | [val]% |
| 25th | [val]% | [val]% |
| **50th (median)** | **[val]%** | **[val]%** |
| 75th | [val]% | [val]% |
| 90th (pessimistic) | [val]% | [val]% |

[Interpretation: probability of debt exceeding X% threshold, probability of fiscal rule being met.]
```

**IMF stress tests:**
```markdown
## IMF Stress Tests

Standard scenarios applied to the baseline debt projection:

| Scenario | Debt/GDP in 5 years | Change vs baseline |
|----------|--------------------|--------------------|
| Baseline | [val]% | - |
| Real GDP growth -1pp | [val]% | +[val]pp |
| Interest rate +200bp | [val]% | +[val]pp |
| Primary balance shock | [val]% | +[val]pp |
| Combined | [val]% | +[val]pp |

[Interpretation: how resilient is the debt trajectory to adverse shocks?]

Reference: IMF (2022), Staff Guidance Note on the Sovereign Risk and Debt Sustainability Framework.
```

**EC sustainability gaps:**
```markdown
## EC Sustainability Gaps

| Gap | Value | Risk level |
|-----|-------|-----------|
| S1 (60% debt target) | [val]% GDP | [Low (<0) / Medium (0-2.5) / High (>2.5)] |
| S2 (infinite horizon) | [val]% GDP | [Low (<2) / Medium (2-6) / High (>6)] |

**S1** measures the permanent budgetary adjustment needed to bring debt to 60% of GDP by [target year]. **S2** measures the adjustment needed to satisfy the intertemporal budget constraint over an infinite horizon, including projected ageing costs.

Reference: European Commission, "Fiscal Sustainability Report", Annex methodology.
```

**Fiscal rules and headroom:**
```markdown
## Fiscal Rules

Current UK fiscal framework (October 2024):

| Rule | Target | Status |
|------|--------|--------|
| Stability rule | Current budget in balance by [year] | [On track / At risk / Breached] |
| Investment rule | PSNFL falling as % GDP by [year] | [On track / At risk] |
| Welfare cap | Social security below £[val]bn | [Within cap / Near cap / Breached] |

**Headroom against the investment rule is £[val]bn** (OBR estimate from [month year] EFO). [If < £10bn: "Headroom is thin and vulnerable to forecast revisions."]
```

**Methodology summary:**
```markdown
**Methodology:** Fiscal data from ONS Public Sector Finances (monthly) and OBR Economic and Fiscal Outlook. Debt dynamics decomposed using the standard equation: delta(d) = primary deficit + (r-g) * d_{t-1} + SFA. Bohn test following Bohn (1998) with output gap control. Fan charts via bootstrap simulation of historical shocks (OBR methodology). IMF stress tests following SRDSF (2022). EC S1/S2 gaps following Fiscal Sustainability Report methodology. Analysis via debtkit and obr R packages.
```

**References:**
```markdown
## References

- Bohn, H. (1998). "The Behavior of U.S. Public Debt and Deficits." QJE, 113(3), 949-963.
- Blanchard, O. (2019). "Public Debt and Low Interest Rates." AER, 109(4), 1197-1229.
- Ghosh, A. et al. (2013). "Fiscal Fatigue, Fiscal Space, and Debt Sustainability." Economic Journal, 123, F4-F30.
- IMF (2022). Staff Guidance Note on the Sovereign Risk and Debt Sustainability Framework.
- OBR (2026). Economic and Fiscal Outlook.
- European Commission. Fiscal Sustainability Report (annual).
- HM Treasury (2022). The Green Book.
- ONS. Public Sector Finances: Methodological Guide.
```

### Step 4: Save and present

Save as `fiscal-briefing-{date}.md`. Always save `fiscal-data-{date}.json`.

## Important Rules

- Never use em dashes.
- Never attribute econstack to any individual.
- Every section stands alone.
- PSNB ex (excluding public sector banks) is the standard headline measure. Use this unless specifically discussing banking sector interventions.
- PSNFL is the current fiscal rule target, not PSND. Report both but note which the rules target.
- The Bohn test coefficient must be interpreted with caveats: sample period sensitivity, structural breaks, and "fiscal fatigue" at high debt levels (Ghosh et al. 2013).
- Fan charts: always note the assumptions (baseline growth, interest rate, primary balance) and the bootstrap methodology.
- r-g: always note Blanchard's (2019) finding that r < g is the historical norm, not the exception.
- Headroom figures are point estimates subject to large forecast revision. Always caveat.
- Debt interest: note if elevated due to RPI-linked gilt inflation accruals (a large share of UK debt is index-linked).
- Be specific about dates, data vintages, and which OBR EFO is being referenced.
