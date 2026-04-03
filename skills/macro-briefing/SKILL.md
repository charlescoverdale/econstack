---
name: macro-briefing
description: Generate a UK macroeconomic briefing. Pulls GDP, inflation, employment, wages, rates, trade, housing, and fiscal data. Interactive section selection.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# /macro-briefing: UK Macroeconomic Monitor

Generate a professional UK macro briefing covering output, labour market, prices, monetary conditions, fiscal position, trade, and housing. Follows the Bank of England Monetary Policy Report narrative structure.

**This skill is interactive.** It pulls the latest data, shows you a dashboard, then asks what output you need.

## Arguments

```
/macro-briefing [options]
```

**Examples:**
```
/macro-briefing
/macro-briefing --full
/macro-briefing --focus prices
/macro-briefing --international
```

**Options:**
- `--full` : Skip the interactive menu, generate all sections
- `--focus <area>` : Emphasise a specific area (output, labour, prices, monetary, fiscal, trade, housing)
- `--international` : Include US and Euro area comparison
- `--client "Name"` : Add "Prepared for" on outputs
- `--format pdf` : Also render branded PDF

## Instructions

### Step 1: Fetch the data

Fetch the latest values directly from ONS and Bank of England. Two approaches, in order of preference:

**Approach A: R packages (if R is available)**

Check if R and the `ons` package are installed:
```bash
Rscript -e "library(ons); cat('R_READY')" 2>/dev/null
```

If R is available, use it (faster, cleaner):
```r
library(ons)
library(boe)
gdp_q <- ons_gdp(frequency = "quarterly")
gdp_m <- ons_monthly_gdp()
unemployment <- ons_unemployment()
employment <- ons_employment()
wages <- ons_wages()
cpi <- ons_cpi()
cpi_core <- ons_cpi(measure = "core")
trade <- ons_trade()
public_finances <- ons_public_finances()
house_prices <- ons_house_prices()
retail <- ons_retail_sales()
bank_rate <- boe_bank_rate()
```

**Approach B: Direct web fetch (if R is not available)**

Fetch each series directly from the ONS CSV endpoint using WebFetch or curl. Each ONS time series has a four-character CDID code and a URL pattern:

```
https://www.ons.gov.uk/generator?format=csv&uri=/economy/grossdomesticproductgdp/timeseries/{CDID}/pn2
```

Key CDID codes:
| Indicator | CDID | Topic path |
|-----------|------|------------|
| GDP q/q growth | IHYQ | grossdomesticproductgdp |
| Monthly GDP | ECVM | grossdomesticproductgdp |
| Unemployment rate | MGSX | employmentandlabourmarket/peoplenotinwork/unemployment |
| Employment rate | LF24 | employmentandlabourmarket/peopleinwork/employmentandemployeetypes |
| AWE total pay y/y | KAB9 | employmentandlabourmarket/peopleinwork/earningsandworkinghours |
| AWE regular pay y/y | KAI7 | employmentandlabourmarket/peopleinwork/earningsandworkinghours |
| CPI annual rate | D7G7 | inflationandpriceindices |
| Core CPI | DKO8 | inflationandpriceindices |
| Retail sales volume | J5EK | retailindustry |
| Trade balance | BOKI | tradeinthenationalaccounts |
| PSNB ex | J5II | governmentpublicsectorandtaxes/publicsectorfinance |
| House price index | HPI | economy/inflationandpriceindices |

For each series, fetch the CSV, skip the metadata rows (lines starting with non-numeric characters), parse the latest value.

For Bank of England data, use the BoE Statistical Interactive Database:
```
https://www.bankofengland.co.uk/boeapps/database/fromshowcolumns.asp?SeriesCodes={CODE}&DateFrom=01/Jan/2024&DateTo=01/Jan/2027&csv=true
```

Key BoE codes:
| Indicator | Code |
|-----------|------|
| Bank Rate | IUDBEDR |
| GBP/USD | XUDLUSS |

For each indicator, extract: latest value, previous period value, year-ago value, and period-on-period change.

If `--international` is specified and R is available, also fetch US data via `fred_series()`. If R is not available, use the FRED API directly (requires an API key, which the user may not have; skip and note "US comparison requires R with the fred package or a FRED API key").

### Step 2: Show the dashboard and ask what the user needs

Present the headline numbers:

```
UK MACRO DASHBOARD
==================
GDP (quarterly):      [val]% q/q   (prev: [val]%)
Monthly GDP:          [val]% m/m
Unemployment:         [val]%        (prev: [val]%)
Employment rate:      [val]%
AWE (total pay):      [val]% y/y   (prev: [val]%)
CPI (annual):         [val]%        (prev: [val]%)
Core CPI:             [val]%
Bank rate:            [val]%
GBP/USD:              [val]
House prices:         [val]% y/y
PSNB (YTD):           £[val]bn
Trade balance:        £[val]m

Data as of: [latest date from each series]
```

**If `--full` was NOT specified**, ask using AskUserQuestion:

Question: "What output do you need?"

Options:
- A) **Full briefing** : All 10 sections
- B) **Pick sections** : Choose which sections
- C) **Dashboard only** : Just the summary table above
- D) **Data only** : JSON file with all values

**If user picks B**, ask a follow-up (multiSelect: true):

Options:
- Output and activity (GDP quarterly + monthly, production, services, retail)
- Labour market (unemployment, employment, inactivity, claimant count, vacancies)
- Wages and earnings (AWE total, regular, real wages)
- Prices and inflation (CPI headline, core, services, goods, RPI)
- Monetary and financial conditions (Bank rate, gilt yields, money supply, credit, FX)
- Fiscal position (PSNB, PSND, debt interest)
- Trade and external (trade balance, current account)
- Housing market (house prices, mortgage approvals, affordability)
- Productivity (output per hour, output per worker)
- Outlook and risks (OBR/BoE forecasts, key risks)

### Step 3: Generate the requested output

**Always include a key numbers block at the top:**

```markdown
<!-- KEY NUMBERS
gdp_qq: [val]
gdp_yy: [val]
unemployment: [val]
cpi: [val]
core_cpi: [val]
bank_rate: [val]
wages_yy: [val]
house_prices_yy: [val]
psnb_ytd: [val]
trade_balance: [val]
date: [date]
-->
```

**Always save a companion JSON file** as `macro-data-{date}.json`.

#### Section templates

Each section follows the ECB Economic Bulletin pattern: **bold lead sentence stating the finding**, then 2-3 sentences of supporting detail with specific numbers. Every section stands alone.

**Output and activity:**
```markdown
## Output and Activity

**GDP [grew/contracted] by [val]% in [period], [above/below/in line with] the previous quarter's [val]%.** On a year-on-year basis, output is [val]% [higher/lower] than a year ago. Monthly GDP [rose/fell] [val]% in [month], suggesting [momentum assessment] entering [next quarter].

The services sector [expanded/contracted] by [val]%, while production output [rose/fell] [val]%. Construction output was [val]%.

Retail sales volumes [rose/fell] [val]% in [month], [interpretation of consumer spending].
```

**Labour market:**
```markdown
## Labour Market

**The unemployment rate [rose/fell] to [val]% in the three months to [month], [up/down] from [val]%.** The employment rate is [val]%. Economic inactivity stands at [val]%, [above/below] pre-pandemic levels.

The claimant count [rose/fell] by [val] in [month] to [total]. [Interpretation of whether the labour market is tightening or loosening.]
```

**Wages and earnings:**
```markdown
## Wages and Earnings

**Average weekly earnings (total pay) grew [val]% year-on-year in the three months to [month].** Regular pay (excluding bonuses) grew [val]%. In real terms (adjusted for CPI), [total/regular] pay [grew/fell] [val]%.

[Interpretation: wage growth [above/below] the BoE's assessment of target-consistent growth (~3-3.5%, i.e., 2% inflation target + ~1-1.5% productivity growth).]
```

**Prices and inflation:**
```markdown
## Prices and Inflation

**CPI inflation [rose/fell] to [val]% in [month], [above/below] the Bank of England's 2% target.** Core CPI (excluding food, energy, alcohol, and tobacco) was [val]%. Services CPI, closely watched by the MPC, was [val]%.

[If CPI > 3%: "Inflation remains significantly above target."]
[If CPI 2-3%: "Inflation is above target but within the range the MPC would consider manageable."]
[If CPI < 2%: "Inflation is below target."]

Goods price inflation was [val]%, [interpretation of goods vs services split].
```

**Monetary and financial conditions:**
```markdown
## Monetary and Financial Conditions

**Bank Rate stands at [val]%, [unchanged since/following the [month] decision to cut/raise by [X]bp].** Markets are pricing [X] further [cuts/hikes] by year-end.

The 10-year gilt yield is [val]%, [up/down] from [val]% a month ago. The 2s10s spread is [val]bp, [interpretation]. Sterling is trading at [val] against the dollar and [val] against the euro, [up/down] [val]% over the past month.

M4 money supply [grew/contracted] [val]% year-on-year. Mortgage approvals were [val] in [month], [above/below] the pre-pandemic average.
```

**Fiscal position:**
```markdown
## Fiscal Position

**Public sector net borrowing was £[val]bn in [month], bringing the year-to-date total to £[val]bn.** This is £[val]bn [above/below] the same point last year.

Public sector net debt stands at [val]% of GDP (£[val]bn). Debt interest payments were £[val]bn in [month].
```

**Trade and external:**
```markdown
## Trade and External

**The UK trade deficit was £[val]m in [month].** The goods deficit was £[val]m, partially offset by a services surplus of £[val]m.

[1-2 sentences on whether the trade position is improving or deteriorating.]
```

**Housing market:**
```markdown
## Housing Market

**UK average house prices [rose/fell] [val]% year-on-year to £[val] in [month].** Mortgage approvals (a leading indicator of transactions) were [val] in [month], [above/below] the pre-pandemic average.

[1-2 sentences on affordability: prices relative to earnings, mortgage rates.]
```

**Productivity:**
```markdown
## Productivity

**Output per hour [rose/fell] [val]% in [period].** Output per worker [rose/fell] [val]%. UK productivity remains approximately [val]% below the pre-2008 trend.
```

**Outlook and risks:**
```markdown
## Outlook and Risks

The OBR's latest forecast (EFO [month year]) projects GDP growth of [val]% in [year] and [val]% in [year+1]. CPI inflation is forecast to average [val]% in [year]. The BoE's latest projection (MPR [month year]) shows CPI returning to [the 2% target / above target] by [date].

**Key upside risks:**
- [1-2 specific risks, e.g., faster-than-expected disinflation, global trade recovery]

**Key downside risks:**
- [1-2 specific risks, e.g., energy price spike, trade policy uncertainty, labour market weakening]
```

**Slide summary:**
```markdown
**UK Macro Snapshot — [Month Year]**

- GDP **[val]% q/q** in [quarter], monthly GDP **[val]%** in [month]
- Unemployment **[val]%**, wages growing **[val]%** y/y ([real wages interpretation])
- CPI **[val]%** ([above/below] 2% target), core **[val]%**, services **[val]%**
- Bank Rate **[val]%**, markets pricing [X] [cuts/hikes] by year-end
- House prices **[up/down] [val]%** y/y, mortgage approvals [above/below] average

*Data from ONS and Bank of England. Powered by econstack.*
```

### Step 4: Save and present

Save as `macro-briefing-{date}.md`. Always save `macro-data-{date}.json`.

If `--format pdf`, render through the template:
```bash
ECONSTACK_DIR="${CLAUDE_SKILL_DIR}/../.."
"$ECONSTACK_DIR/scripts/render-report.sh" macro-briefing-{date}.md \
  --title "UK Macroeconomic Briefing" \
  --subtitle "[Month Year]"
```

## Important Rules

- Never use em dashes. Use colons, periods, commas, or parentheses.
- Never attribute econstack to any individual.
- Every section stands alone. No cross-references.
- Bold lead sentence in every section (ECB style): state the finding, not just the topic.
- All comparisons need context: vs previous period, vs year ago, vs target/forecast where applicable.
- Target-consistent wage growth is approximately 3-3.5% (2% inflation target + 1-1.5% productivity growth). Flag if wages are above or below this.
- CPI services is the indicator the MPC watches most closely. Always mention it.
- Real wages = nominal AWE growth minus CPI. Always compute and report.
- Be specific about dates. "Q4 2025" not "last quarter". "February 2026" not "last month".
- The companion JSON must include every data point used in the briefing, with dates and sources.
