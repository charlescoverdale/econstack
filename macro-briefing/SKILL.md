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

<!-- preamble: update check -->
Before starting, run this silently. If it outputs UPDATE_AVAILABLE, tell the user:
"A new version of econstack is available. Run `cd ~/.claude/skills/econstack && git pull` to update."
Then continue with the skill normally.

```bash
~/.claude/skills/econstack/bin/econstack-update-check 2>/dev/null || true
```

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
- `--international` : Include major economies (US, Euro area, Japan, China, Canada, Australia, G7/OECD aggregates)
- `--client "Name"` : Add "Prepared for" on outputs
- `--format pdf` : Also render branded PDF

## CDID Reference Table

Key CDID codes for ONS time series:
| Indicator | CDID | Topic path |
|-----------|------|------------|
| GDP q/q growth | IHYQ | grossdomesticproductgdp |
| Monthly GDP | ECY2 | grossdomesticproductgdp |
| Unemployment rate | MGSX | employmentandlabourmarket/peoplenotinwork/unemployment |
| Employment rate | LF24 | employmentandlabourmarket/peopleinwork/employmentandemployeetypes |
| AWE total pay y/y | KAB9 | employmentandlabourmarket/peopleinwork/earningsandworkinghours |
| AWE regular pay y/y | KAI7 | employmentandlabourmarket/peopleinwork/earningsandworkinghours |
| CPI annual rate | D7G7 | inflationandpriceindices |
| Core CPI | DKO8 | inflationandpriceindices |
| Retail sales volume | J5EK | retailindustry |
| Trade balance | IKBJ | tradeinthenationalaccounts |
| PSNB ex | DZLS | governmentpublicsectorandtaxes/publicsectorfinance |
| House price index | HPI | Not a standard CDID. Fetched via `ons_house_prices()` which uses HM Land Registry/ONS UK House Price Index data. |

When using R packages, the package functions handle CDID lookup and URL construction internally. These codes are for reference and fallback only. The package function names are authoritative.

Key BoE codes:
| Indicator | Code |
|-----------|------|
| Bank Rate | IUDBEDR |
| GBP/USD | XUDLUSS |

## Instructions

### Step 1: Identify arguments

Parse any flags from the user's command.

### Step 2: Fetch data

Use the ons and boe R packages. These handle ONS API changes, CSV parsing, caching, and retry logic.

Run a single Rscript to fetch all indicators:

```bash
Rscript -e '
  library(ons); library(boe); library(jsonlite)

  tryCatch({
    data <- list(
      gdp_q = tail(ons_gdp(frequency="quarterly"), 8),
      gdp_m = tail(ons_monthly_gdp(), 12),
      unemployment = tail(ons_unemployment(), 12),
      employment = tail(ons_employment(), 12),
      inactivity = tail(ons_inactivity(), 12),
      wages_total = tail(ons_wages(), 12),
      cpi = tail(ons_cpi(), 12),
      cpi_core = tail(ons_get("DKO8"), 12),
      cpih = tail(ons_cpi(measure="cpih"), 12),
      retail = tail(ons_retail_sales(), 12),
      trade = tail(ons_trade(), 12),
      public_finances = tail(ons_public_finances(), 12),
      productivity = tail(ons_productivity(), 8),
      house_prices = tail(ons_house_prices(), 12),
      vacancies = tail(ons_get("AP2Y"), 12),
      business_investment = tail(ons_get("NPEL"), 8),
      bank_rate = tail(boe_bank_rate(), 12),
      gbp_usd = tail(boe_exchange_rate("USD"), 30),
      gbp_eur = tail(boe_exchange_rate("EUR"), 30),
      gilt_10y = tail(boe_yield_curve(maturity="10", type="nominal_par"), 30),
      sonia = tail(boe_sonia(), 30),
      mortgage_approvals = tail(boe_mortgage_approvals(), 12)
    )
    cat(toJSON(data, auto_unbox=TRUE, pretty=TRUE))
  }, error = function(e) {
    cat(paste0("ERROR: ", e$message))
  })
'
```

If the Rscript fails or R is not available:
  Tell the user: "The macro-briefing skill requires R with the ons and boe packages installed.
  Install with: install.packages(c('ons', 'boe'))

  If you don't have R installed, you can install it from https://cran.r-project.org/"
  Stop. Do NOT fall back to web CSV fetching. The R packages handle ONS URL
  changes, CSV parsing quirks, and caching. A manual CSV fallback would be
  fragile and will break when ONS changes their URL structure.

Parse the JSON output. Each indicator is an array of {date, value} objects (or {date, cdid, value}).

If any individual indicator fails (returns null or error), note it and continue with remaining data. Do not abort the entire briefing because one series is unavailable.

**Data freshness validation:**

After parsing the JSON output, check the freshness of each indicator:

For each indicator in the data:
  latest_date = the most recent date value in the series
  staleness_days = current_date - latest_date

  If staleness_days > 90:
    Mark as STALE. In the output, add a note: "[Indicator] data is [X] days
    old (latest: [date]). This may not reflect the most recent position.
    Check for a new ONS/BoE release."

  If staleness_days > 180:
    Exclude from the dashboard. Note: "[Indicator] data is severely outdated
    ([X] days old). Excluded from this briefing."

  If an indicator returned no data (null/empty):
    Note: "[Indicator] could not be retrieved. Skipping."
    Continue with remaining indicators.

Add a "Data freshness" footer to EVERY output (markdown, HTML, PDF, etc.):

---
*Data sources: ONS (via ons R package), Bank of England (via boe R package).*
*Latest data points: GDP [date], CPI [date], unemployment [date], wages [date], Bank Rate [date].*
*[If any stale]: Note: [indicator] data is [X] days old and may not reflect the latest release.*
---

**If `--international` is specified:**

Fetch international data from three sources in priority order:
1. **FRED** (US Federal Reserve): best for US data and some international series. Requires API key.
2. **ECB** (via readecb): best for Euro area data. No API key required.
3. **OECD** (via readoecd): best for cross-country comparisons and countries not covered by FRED/ECB. No API key required. Use as backup when FRED is unavailable.

```bash
Rscript -e '
  library(jsonlite)
  intl <- list()

  # --- US data via FRED (primary source for US) ---
  if (requireNamespace("fred", quietly = TRUE)) {
    tryCatch({
      library(fred)
      intl$us <- list(
        gdp       = tail(fred_series("A191RL1Q225SBEA"), 8),   # Real GDP growth (quarterly, annualized)
        cpi       = tail(fred_series("CPIAUCSL"), 12),          # CPI-U (monthly, index)
        pce       = tail(fred_series("PCEPI"), 12),             # PCE price index (monthly)
        unemployment = tail(fred_series("UNRATE"), 12),         # Unemployment rate
        fed_rate  = tail(fred_series("FEDFUNDS"), 12),          # Fed Funds effective rate
        treasury_10y = tail(fred_series("GS10"), 12)            # 10-year Treasury yield
      )
    }, error = function(e) message("FRED fetch failed: ", e$message))
  }

  # --- Japan via FRED ---
  if (requireNamespace("fred", quietly = TRUE) && !is.null(intl$us)) {
    tryCatch({
      intl$japan <- list(
        gdp       = tail(fred_series("JPNRGDPEXP"), 8),        # Japan real GDP (quarterly)
        cpi       = tail(fred_series("JPNCPIALLMINMEI"), 12),   # Japan CPI
        unemployment = tail(fred_series("LRUNTTTTJPM156S"), 12),# Japan unemployment
        policy_rate = tail(fred_series("IRSTCB01JPM156N"), 12)  # BOJ policy rate
      )
    }, error = function(e) message("Japan FRED fetch failed: ", e$message))
  }

  # --- China via FRED ---
  if (requireNamespace("fred", quietly = TRUE) && !is.null(intl$us)) {
    tryCatch({
      intl$china <- list(
        gdp       = tail(fred_series("CHNRGDPEXP"), 8),        # China real GDP (quarterly)
        cpi       = tail(fred_series("CHNCPIALLMINMEI"), 12),   # China CPI
        unemployment = tail(fred_series("LRUN64TTCNM156S"), 12) # China urban unemployment
      )
    }, error = function(e) message("China FRED fetch failed: ", e$message))
  }

  # --- Canada via FRED ---
  if (requireNamespace("fred", quietly = TRUE) && !is.null(intl$us)) {
    tryCatch({
      intl$canada <- list(
        gdp       = tail(fred_series("NAEXKP01CAQ189S"), 8),   # Canada real GDP (quarterly)
        cpi       = tail(fred_series("CPALTT01CAM661N"), 12),   # Canada CPI
        unemployment = tail(fred_series("LRUNTTTTCAM156S"), 12),# Canada unemployment
        policy_rate = tail(fred_series("IRSTCB01CAM156N"), 12)  # BOC policy rate
      )
    }, error = function(e) message("Canada FRED fetch failed: ", e$message))
  }

  # --- Australia via FRED ---
  if (requireNamespace("fred", quietly = TRUE) && !is.null(intl$us)) {
    tryCatch({
      intl$australia <- list(
        gdp       = tail(fred_series("NAEXKP01AUQ189S"), 8),   # Australia real GDP (quarterly)
        cpi       = tail(fred_series("CPALTT01AUM661N"), 12),   # Australia CPI
        unemployment = tail(fred_series("LRUNTTTTAUM156S"), 12),# Australia unemployment
        policy_rate = tail(fred_series("IRSTCB01AUM156N"), 12)  # RBA cash rate
      )
    }, error = function(e) message("Australia FRED fetch failed: ", e$message))
  }

  # --- Euro area via ECB (primary source for EA) ---
  if (requireNamespace("readecb", quietly = TRUE)) {
    tryCatch({
      library(readecb)
      intl$euro_area <- list(
        gdp       = tail(ecb_get("MNA.Q.Y.I8.W2.S1.S1.B.B1GQ._Z._Z._Z.EUR.LR.GY"), 8),
        hicp      = tail(ecb_get("ICP.M.U2.N.000000.4.ANR"), 12),
        unemployment = tail(ecb_get("STS.M.I8.S.UNEH.RTT000.4.000"), 12),
        ecb_rate  = tail(ecb_get("FM.D.U2.EUR.4F.KR.MRR_FR.LEV"), 30)
      )
    }, error = function(e) message("ECB fetch failed: ", e$message))
  }

  # --- OECD aggregates and backup (for G7, OECD totals, and any country FRED missed) ---
  if (requireNamespace("readoecd", quietly = TRUE)) {
    tryCatch({
      library(readoecd)
      # G7 and OECD aggregate GDP growth
      intl$oecd <- list(
        gdp_g7    = tail(get_oecd_gdp("G-7"), 8),
        gdp_oecd  = tail(get_oecd_gdp("OECD"), 8),
        cpi_g7    = tail(get_oecd_cpi("G-7"), 12),
        cpi_oecd  = tail(get_oecd_cpi("OECD"), 12),
        unemp_g7  = tail(get_oecd_unemployment("G-7"), 12),
        unemp_oecd = tail(get_oecd_unemployment("OECD"), 12)
      )

      # Fill gaps: if any country was missed by FRED, try OECD
      if (is.null(intl$japan)) {
        intl$japan <- list(
          gdp = tail(get_oecd_gdp("JPN"), 8),
          cpi = tail(get_oecd_cpi("JPN"), 12),
          unemployment = tail(get_oecd_unemployment("JPN"), 12)
        )
      }
      if (is.null(intl$canada)) {
        intl$canada <- list(
          gdp = tail(get_oecd_gdp("CAN"), 8),
          cpi = tail(get_oecd_cpi("CAN"), 12),
          unemployment = tail(get_oecd_unemployment("CAN"), 12)
        )
      }
      if (is.null(intl$australia)) {
        intl$australia <- list(
          gdp = tail(get_oecd_gdp("AUS"), 8),
          cpi = tail(get_oecd_cpi("AUS"), 12),
          unemployment = tail(get_oecd_unemployment("AUS"), 12)
        )
      }
    }, error = function(e) message("OECD fetch failed: ", e$message))
  }

  cat(toJSON(intl, auto_unbox=TRUE, pretty=TRUE))
'
```

**Data source priority:**
- FRED is preferred for individual country data (US, Japan, China, Canada, Australia) because it provides the most granular, timely series.
- ECB is the authoritative source for Euro area aggregates.
- OECD (via readoecd) provides G7/OECD aggregates and serves as a backup for any country where FRED data is unavailable (e.g., FRED API key not set).

**Graceful degradation:**
- If `fred` package is not installed or API key is missing: skip all FRED-sourced countries (US, Japan, China, Canada, Australia). Note: "Country-level data requires the fred package with a FRED API key. Install with: install.packages('fred') then fred_set_key('YOUR_KEY')."
- If `readecb` is not installed: skip Euro area data. Note: "Euro area data requires the readecb package."
- If `readoecd` is not installed: skip OECD aggregates and backup country data. Note: "OECD aggregate data requires the readoecd package."
- If ALL international packages are missing: "No international data packages available. Install fred, readecb, or readoecd for international comparisons."
- Each country fetch is wrapped in tryCatch. If one country fails, the others still proceed.

### Step 3: Show the dashboard and ask what the user needs

Present the headline numbers:

```
UK MACRO DASHBOARD
==================
GDP (quarterly):      [val]% q/q   (prev: [val]%)
Monthly GDP:          [val]% m/m
Unemployment:         [val]%        (prev: [val]%)
Employment rate:      [val]%
Inactivity rate:      [val]%        (prev: [val]%)
AWE (total pay):      [val]% y/y   (prev: [val]%)
CPI (annual):         [val]%        (prev: [val]%)
Core CPI:             [val]%
CPIH:                 [val]%        (lead ONS measure)
Bank rate:            [val]%
10yr gilt yield:      [val]%
SONIA rate:           [val]%
GBP/USD:              [val]
GBP/EUR:              [val]
House prices:         [val]% y/y
Mortgage approvals:   [val]k
Vacancies:            [val]k        (prev: [val]k)
PSNB (YTD):           £[val]bn
Trade balance:        £[val]m

Data as of: [latest date from each series]
```

**If `--full` was NOT specified**, ask using AskUserQuestion:

Question: "What output do you need?"

Options:
- A) **Full briefing** : All sections
- B) **Pick sections** : Choose which sections
- C) **Dashboard only** : Just the summary table above
- D) **Data only** : JSON file with all values

**If user picks B**, ask a follow-up (multiSelect: true):

Options:
- Output and activity (GDP quarterly + monthly, production, services, retail)
- Labour market (unemployment, employment, inactivity, claimant count, vacancies)
- Wages and earnings (AWE total, regular, real wages)
- Prices and inflation (CPI headline, core, CPIH, services, goods, RPI)
- Financial conditions (gilt yields, SONIA, mortgage rates, exchange rates, credit conditions)
- Monetary policy (Bank rate, MPC decisions, forward guidance)
- Fiscal position (PSNB, PSND, debt interest)
- Trade and external (trade balance, current account)
- Housing market (house prices, mortgage approvals, affordability)
- Productivity (output per hour, output per worker)
- International comparison (UK vs major economies and G7/OECD aggregates, requires --international data)
- Outlook and risks (growth trajectory, inflation path, key risks)

### Step 4: Generate the requested output

**Always include a key numbers block at the top:**

```markdown
<!-- KEY NUMBERS
type: macro
date: [YYYY-MM-DD]
framework: uk
gdp_qq_pct: [val]
gdp_yy_pct: [val]
unemployment_pct: [val]
employment_pct: [val]
inactivity_pct: [val]
cpi_pct: [val]
cpih_pct: [val]
core_cpi_pct: [val]
wages_yy_pct: [val]
real_wages_pct: [val]
bank_rate_pct: [val]
gilt_10y_pct: [val]
sonia_pct: [val]
gbp_usd: [val]
gbp_eur: [val]
house_prices_yy_pct: [val]
mortgage_approvals_k: [val]
vacancies_k: [val]
psnb_ytd_bn: [val]
trade_balance_m: [val]
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

The claimant count [rose/fell] by [val] in [month] to [total]. Vacancies stand at [val]k, [up/down] from [val]k in [previous period]. [Interpretation of whether the labour market is tightening or loosening.]
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

**CPI inflation [rose/fell] to [val]% in [month], [above/below] the Bank of England's 2% target.** CPIH (the ONS's lead measure, including owner-occupier housing costs) was [val]%. Core CPI (excluding food, energy, alcohol, and tobacco) was [val]%. Services CPI, closely watched by the MPC, was [val]%.

[If CPI > 3%: "Inflation remains significantly above target."]
[If CPI 2-3%: "Inflation is above target but within the range the MPC would consider manageable."]
[If CPI < 2%: "Inflation is below target."]

Goods price inflation was [val]%, [interpretation of goods vs services split].
```

**Financial conditions:**
```markdown
## Financial Conditions

**Gilt yields:** The 10-year gilt yield stands at [val]%, [up/down] from [val]% [time period ago]. [Context: "This reflects [market expectations for rates/inflation/fiscal concerns]."]

**SONIA and money markets:** The SONIA overnight rate is [val]%, [spread to Bank Rate]. [If SONIA significantly different from Bank Rate, explain why.]

**Mortgage market:** [val] mortgage approvals in [latest month], [comparison to pre-pandemic average of ~65,000/month]. [Direction and interpretation.]

**Exchange rates:** GBP/USD at [val] and GBP/EUR at [val]. [Direction over past month and interpretation for trade/inflation.]

**Consumer credit:** [If data available from boe_consumer_credit(): monthly net lending figure and interpretation.]
```

**Monetary policy:**
```markdown
## Monetary Policy

**Bank Rate stands at [val]%, [unchanged since/following the [month] decision to cut/raise by [X]bp].** Markets are pricing [X] further [cuts/hikes] by year-end.

M4 money supply [grew/contracted] [val]% year-on-year.
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

**UK average house prices [rose/fell] [val]% year-on-year to £[val] in [month].** Mortgage approvals (a leading indicator of transactions) were [val] in [month], [above/below] the pre-pandemic average of ~65,000/month.

[1-2 sentences on affordability: prices relative to earnings, mortgage rates.]
```

**Productivity:**
```markdown
## Productivity

**Output per hour [rose/fell] [val]% in [period].** Output per worker [rose/fell] [val]%. UK productivity remains approximately [val]% below the pre-2008 trend.
```

**International comparison:**
```markdown
## International Comparison

### Major economies

| Indicator | UK | US | Euro area | Japan | China | Canada | Australia | G7 avg |
|-----------|----|----|-----------|-------|-------|--------|-----------|--------|
| GDP growth | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |
| Inflation | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |
| Unemployment | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |
| Policy rate | [val]% | [val]% | [val]% | [val]% | - | [val]% | [val]% | - |

[Only include columns for countries where data was successfully retrieved. If a country was skipped (package missing or fetch failed), omit the column rather than showing blanks.]

### Interpretation

[Address these questions:
- Where is the UK in the global cycle? (leading, lagging, or in line with peers)
- Are policy rates converging or diverging? (implications for GBP and capital flows)
- Is the UK an outlier on any indicator? (e.g., higher inflation than peers, weaker growth)
- What are the trade implications? (UK's major trading partners are the EU, US, and China)]

### Data sources and comparability notes

- GDP: quarterly real growth rates. US reports annualized; others report q/q. Comparisons use q/q where possible.
- Inflation: CPI for UK/Japan/Canada/Australia, PCE for US (the Fed's preferred measure; CPI-U also available), HICP for Euro area, CPI for China. Direct comparison requires caution as basket weights differ.
- Unemployment: ILO definition for UK/Euro area/Japan/Canada/Australia. US uses BLS definition (similar to ILO). China uses surveyed urban unemployment (narrower scope).
- Policy rates: Bank Rate (UK), Fed Funds target midpoint (US), ECB main refinancing rate (Euro area), BOJ overnight call rate (Japan), BOC overnight rate (Canada), RBA cash rate (Australia).
- G7/OECD averages from OECD Economic Outlook database via readoecd package.

*Data sources: FRED (US, Japan, China, Canada, Australia), ECB Statistical Data Warehouse (Euro area), OECD (G7/OECD aggregates and backup). ONS and BoE for UK data.*
```

**Outlook and risks:**
```markdown
## Outlook and Risks

**Monetary policy:** The Bank Rate stands at [val]%. The BoE's [most recent month] decision to [hold/cut/raise] rates [by X basis points] signals [interpretation based on direction and context]. The SONIA overnight rate at [val]% suggests [market positioning]. [If SONIA curve data is available, infer the market-implied rate path direction.]

**Growth outlook:** [Based on the data trajectory: is GDP accelerating, decelerating, or stable? What do the monthly GDP and PMI signals suggest for the near term?]

**Inflation outlook:** [Is CPI falling toward target, stuck above target, or at risk of undershooting? What does the services CPI / core CPI trajectory suggest about underlying pressures?]

**Key upside risks:**
- [Risk 1, e.g., stronger global demand, fiscal loosening, labour supply recovery]
- [Risk 2]

**Key downside risks:**
- [Risk 1, e.g., geopolitical disruption, energy price shock, financial conditions tightening]
- [Risk 2]

Note: This outlook is based on the data trajectory and recent policy signals. For formal forecasts, refer to the latest BoE Monetary Policy Report and OBR Economic and Fiscal Outlook. Specific forecast numbers are not included here as they are published in PDFs that may not reflect the most recent release.
```

**Slide summary:**
```markdown
**UK Macro Snapshot, [Month Year]**

- GDP **[val]% q/q** in [quarter], monthly GDP **[val]%** in [month]
- Unemployment **[val]%**, wages growing **[val]%** y/y ([real wages interpretation])
- CPI **[val]%** ([above/below] 2% target), core **[val]%**, services **[val]%**
- Bank Rate **[val]%**, 10yr gilt **[val]%**, SONIA **[val]%**
- House prices **[up/down] [val]%** y/y, mortgage approvals [above/below] average
- GBP/USD **[val]**, GBP/EUR **[val]**

*Data from ONS and Bank of England. Powered by econstack.*
```

### Step 5: Save and present

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
