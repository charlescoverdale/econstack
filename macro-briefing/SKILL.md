---
name: macro-briefing
description: Macroeconomic monitor. Supports UK, US, Euro area, and Australia. Pulls GDP, inflation, employment, wages, rates, trade, housing, and fiscal data. Each country follows its central bank's reporting structure. Interactive section selection.
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

# /macro-briefing: Macroeconomic Monitor

Generate a professional macroeconomic briefing for the UK, US, Euro area, or Australia. Each country follows its central bank's reporting structure: BoE MPR for the UK, FOMC/Beige Book for the US, ECB Economic Bulletin for the Euro area, RBA Statement on Monetary Policy for Australia.

**This skill is interactive.** It pulls the latest data, shows you a dashboard, then asks what output you need.

## Arguments

```
/macro-briefing [options]
```

**Examples:**
```
/macro-briefing                     # UK (default)
/macro-briefing --country us        # US macro briefing (Fed structure)
/macro-briefing --country eu        # Euro area briefing (ECB structure)
/macro-briefing --country au        # Australia briefing (RBA structure)
/macro-briefing --full
/macro-briefing --country us --focus prices
/macro-briefing --international
```

**Options:**
- `--country <code>` : Country to brief. `uk` (default), `us`, `eu`, `au`
- `--full` : Skip the interactive menu, generate all sections
- `--focus <area>` : Emphasise a specific area (output, labour, prices, monetary, fiscal, trade, housing)
- `--international` : Include international comparison tables (30 economies)
- `--client "Name"` : Add "Prepared for" on outputs
- `--exec` : Generate a management consulting-style executive summary deck (6 slides with action titles). Can be combined with `--format pptx` for both decks.
- `--audit` : After generating, run `/econ-audit` on the output
- `--format <type>` : Output format(s): `markdown`, `html`, `word`, `pptx`, `pdf`, or `all`. Comma-separate for multiple (e.g. `--format word,pdf`). Default: markdown only

## Country Routing

Parse the `--country` flag. Default is `uk` if not specified.

| Country | Data (Section A) | Dashboard (B) | Narrative (C) | Central bank style |
|---------|-----------------|---------------|---------------|-------------------|
| `uk` | A1: ons + boe packages | B1 | C1: 12 sections | BoE Monetary Policy Report |
| `us` | A2: fred package | B2 | C2: 8 sections | FOMC / Beige Book |
| `eu` | A3: readecb package | B3 | C3: 6 sections | ECB Economic Bulletin |
| `au` | A4: fred + readoecd | B4 | C4: 5 sections | RBA Statement on Monetary Policy |

All countries also run A5 (global indicators: Brent, VIX, consumer confidence).
If `--international` is specified, also run A6 (30-country comparison data) and D2 (comparison tables).

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

### Step 1: Identify arguments and route

Parse any flags from the user's command. Determine the country from `--country` (default: `uk`).

**Validate the country code.** Supported values: `uk`, `us`, `eu`, `au`. If the user passes an unsupported code (e.g., `--country de`, `--country nz`), stop and tell them: "Country '[code]' is not yet supported. Supported countries: uk (default), us, eu, au. More countries coming soon."

Then execute the matching pipeline:

- `uk`: A1 + A5 -> B1 -> C1 + D1
- `us`: A2 + A5 -> B2 -> C2 + D1
- `eu`: A3 + A5 -> B3 -> C3 + D1
- `au`: A4 + A5 -> B4 -> C4 + D1

If `--international` is also specified, additionally run A6 + D2.

---

## SECTION A: DATA FETCHING

### A1: UK Data Fetching

Use the ons and boe R packages. These handle ONS API changes, CSV parsing, caching, and retry logic.

Run a single Rscript to fetch all indicators:

```bash
Rscript -e '
  library(ons); library(boe); library(jsonlite)

  tryCatch({
    data <- list(
      gdp_q = tail(ons_gdp(), 8),
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
      mortgage_approvals = tail(boe_mortgage_approvals(), 12),

      # Additional indicators (referenced in narrative templates)
      cpi_services = tail(ons_get("CHMK"), 12),
      claimant_count = tail(ons_get("BCJD"), 12),
      ppi_output = tail(ons_get("JVZ7"), 12),
      m4 = tail(boe_money_supply(), 12),
      consumer_credit = tail(boe_consumer_credit(), 12)
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
*Data sources: [country-specific footer, see Step 5].*
*Latest data points: GDP [date], CPI/HICP [date], unemployment [date], [key rate name] [date].*
*[If any stale]: Note: [indicator] data is [X] days old and may not reflect the latest release.*
---

### A2: US Data Fetching

**Only run if `--country us` is specified.** Requires the `fred` R package with a FRED API key.

```bash
Rscript -e '
  library(fred); library(jsonlite)

  tryCatch({
    data <- list(
      # Output and activity
      gdp = tail(fred_series("A191RL1Q225SBEA"), 8),
      industrial_production = tail(fred_series("INDPRO"), 12),
      retail_sales = tail(fred_series("RSAFS"), 12),

      # Labour market
      unemployment = tail(fred_series("UNRATE"), 12),
      payrolls = tail(fred_series("PAYEMS"), 12),
      initial_claims = tail(fred_series("ICSA"), 12),
      jolts_openings = tail(fred_series("JTSJOL"), 12),
      avg_hourly_earnings = tail(fred_series("CES0500000003"), 12),

      # Prices
      cpi = tail(fred_series("CPIAUCSL", units="pc1"), 12),
      cpi_core = tail(fred_series("CPILFESL", units="pc1"), 12),
      pce = tail(fred_series("PCEPI", units="pc1"), 12),
      pce_core = tail(fred_series("PCEPILFE", units="pc1"), 12),

      # Monetary policy and financial conditions
      fed_funds = tail(fred_series("FEDFUNDS"), 12),
      treasury_2y = tail(fred_series("GS2"), 30),
      treasury_10y = tail(fred_series("GS10"), 30),
      yield_spread = tail(fred_series("T10Y2Y"), 30),
      hy_spread = tail(fred_series("BAMLH0A0HYM2"), 30),

      # Housing
      housing_starts = tail(fred_series("HOUST"), 12),
      case_shiller = tail(fred_series("CSUSHPINSA"), 12),
      mortgage_30y = tail(fred_series("MORTGAGE30US"), 30),

      # Consumer
      consumer_sentiment = tail(fred_series("UMCSENT"), 12),

      # Additional indicators (flagged by methodology audit)
      participation_rate = tail(fred_series("CIVPART"), 12),
      eci_wages = tail(fred_series("ECIWAG"), 8),
      cpi_shelter = tail(fred_series("CUSR0000SEHC", units="pc1"), 12),
      continuing_claims = tail(fred_series("CCSA"), 12),
      mfg_employment = tail(fred_series("MANEMP"), 12),
      nfci = tail(fred_series("NFCI"), 30)
    )
    cat(toJSON(data, auto_unbox=TRUE, pretty=TRUE))
  }, error = function(e) {
    cat(paste0("ERROR: ", e$message))
  })
'
```

If fred is not installed or the API key is missing, tell the user:
"The US macro briefing requires the fred R package with a FRED API key.
Install with: install.packages('fred')
Set key with: fred_set_key('YOUR_KEY')
Get a free key from: https://fredaccount.stlouisfed.org/apikeys"
Stop.

**Note on US GDP convention:** The BEA reports GDP growth as an annualized rate (quarterly change x4, roughly). This is different from the UK/EU convention of reporting quarter-on-quarter growth. Always state "annualized" when presenting US GDP growth, and note that dividing by ~4 gives the approximate q/q rate for international comparison.

---

### A3: Euro Area Data Fetching

**Only run if `--country eu` is specified.** Uses the `readecb` R package. No API key required.

```bash
Rscript -e '
  library(readecb); library(jsonlite)

  tryCatch({
    data <- list(
      # Economic activity
      gdp = tail(ecb_gdp(), 8),

      # Labour market
      unemployment = tail(ecb_unemployment(), 12),

      # Prices (full ECB decomposition)
      hicp = tail(ecb_hicp(), 12),
      hicp_core = tail(ecb_get("ICP.M.U2.N.XEF000.4.ANR"), 12),
      hicp_services = tail(ecb_get("ICP.M.U2.N.SERV00.4.ANR"), 12),
      hicp_food = tail(ecb_get("ICP.M.U2.N.FOOD00.4.ANR"), 12),
      hicp_neig = tail(ecb_get("ICP.M.U2.N.IGD_NNRG.4.ANR"), 12),

      # Monetary and financial conditions
      ecb_rates = tail(ecb_policy_rates(), 30),
      estr = tail(ecb_estr(), 30),
      euribor_3m = tail(ecb_euribor("3M"), 30),
      euribor_12m = tail(ecb_euribor("12M"), 30),
      yield_2y = tail(ecb_yield_curve("2"), 30),
      yield_10y = tail(ecb_yield_curve("10"), 30),
      m3 = tail(ecb_money_supply("M3"), 12),
      lending_rates = tail(ecb_lending_rates(), 12),
      mortgage_rates = tail(ecb_mortgage_rates(), 12),

      # Fiscal
      govt_debt = tail(ecb_government_debt(), 8),

      # Exchange rates
      eur_usd = tail(ecb_exchange_rate("USD"), 30)
    )
    cat(toJSON(data, auto_unbox=TRUE, pretty=TRUE))
  }, error = function(e) {
    cat(paste0("ERROR: ", e$message))
  })
'
```

If readecb is not installed, tell the user:
"The Euro area macro briefing requires the readecb R package. Install with: install.packages('readecb')"
Stop.

---

### A4: Australia Data Fetching

**Only run if `--country au` is specified.** Uses three sources in priority order: `readabs` (ABS time series, richest), `readrba` (RBA statistics), `fred` (OECD MEI series). Falls back gracefully if packages are not installed.

```bash
Rscript -e '
  library(jsonlite)
  data <- list()

  # --- readabs (primary: ABS time series) ---
  if (requireNamespace("readabs", quietly = TRUE)) {
    library(readabs)
    tryCatch({
      # GDP (ABS 5206.0 National Accounts)
      data$gdp = tail(read_abs_series("A2304402X"), 8)  # GDP chain volume, seasonally adjusted

      # Labour force (ABS 6202.0)
      data$unemployment = tail(read_abs_series("A84423050A"), 12)  # Unemployment rate, SA
      data$participation = tail(read_abs_series("A84423051L"), 12)  # Participation rate, SA
      data$employment = tail(read_abs_series("A84423043C"), 12)    # Employment total, SA
      data$fulltime = tail(read_abs_series("A84423044F"), 12)      # Full-time employment, SA
      data$hours_worked = tail(read_abs_series("A84423091C"), 12)  # Monthly hours worked, SA

      # CPI (ABS 6401.0, quarterly)
      data$cpi = tail(read_abs_series("A2325846C"), 8)       # CPI all groups, annual % change
      data$trimmed_mean = tail(read_abs_series("A3604512T"), 8) # Trimmed mean, annual % change (RBA preferred core)

      # Wage Price Index (ABS 6345.0, quarterly)
      data$wpi = tail(read_abs_series("A2713849V"), 8)  # WPI total hourly rates, y/y

      # Retail sales (ABS 8501.0)
      data$retail = tail(read_abs_series("A3348585R"), 12)  # Retail turnover, SA

      # Building approvals (ABS 8731.0)
      data$building_approvals = tail(read_abs_series("A83728908F"), 12)  # Total dwellings, SA

      data$source_abs <- "ABS via readabs"
    }, error = function(e) message("readabs fetch failed: ", e$message))
  }

  # --- readrba (RBA statistics) ---
  if (requireNamespace("readrba", quietly = TRUE)) {
    library(readrba)
    tryCatch({
      data$rba_rate = tail(read_rba(series_id = "FIRMMCRT"), 12)    # Cash rate target
      data$aud_usd = tail(read_rba(series_id = "FXRUSD"), 30)       # AUD/USD exchange rate
      data$source_rba <- "RBA via readrba"
    }, error = function(e) message("readrba fetch failed: ", e$message))
  }

  # --- FRED (backup for any missing core series) ---
  if (requireNamespace("fred", quietly = TRUE)) {
    library(fred)
    if (is.null(data$gdp)) tryCatch({ data$gdp = tail(fred_series("NAEXKP01AUQ189S"), 8) }, error = function(e) NULL)
    if (is.null(data$cpi)) tryCatch({ data$cpi = tail(fred_series("CPALTT01AUM661N"), 12) }, error = function(e) NULL)
    if (is.null(data$unemployment)) tryCatch({ data$unemployment = tail(fred_series("LRUNTTTTAUM156S"), 12) }, error = function(e) NULL)
    if (is.null(data$rba_rate)) tryCatch({ data$rba_rate = tail(fred_series("IRSTCB01AUM156N"), 12) }, error = function(e) NULL)
    # Iron ore (key for terms of trade and fiscal revenue)
    tryCatch({ data$iron_ore = tail(fred_series("PIORECRUSDM"), 30) }, error = function(e) NULL)
  }

  # --- readoecd (final fallback) ---
  if (requireNamespace("readoecd", quietly = TRUE)) {
    library(readoecd)
    if (is.null(data$gdp)) tryCatch({ data$gdp = tail(get_oecd_gdp("AUS"), 8) }, error = function(e) NULL)
    if (is.null(data$unemployment)) tryCatch({ data$unemployment = tail(get_oecd_unemployment("AUS"), 12) }, error = function(e) NULL)
  }

  if (length(data) == 0) {
    cat("ERROR: No AU data retrieved. Install readabs (recommended) for full coverage, or fred/readoecd for headlines.")
  } else {
    cat(toJSON(data, auto_unbox=TRUE, pretty=TRUE))
  }
'
```

**Package priority:**
- `readabs` (recommended): Provides the richest data. ABS time series for GDP, labour force (6 series), CPI (headline + trimmed mean), WPI, retail sales, building approvals. Install with: `install.packages("readabs")`
- `readrba`: RBA cash rate and AUD/USD exchange rate. Install with: `install.packages("readrba")`
- `fred`: Backup for core indicators if readabs not installed, plus iron ore price (FRED only). Requires API key.
- `readoecd`: Final fallback for GDP and unemployment.

If only `fred` is available, the briefing runs with ~5 indicators and notes the limitation. If `readabs` is available, the briefing has 12+ indicators matching a professional RBA SoMP structure.

---

### A5: Global Indicators

**Run for ALL countries.** These provide energy, financial stress, and forward-looking context.

```bash
Rscript -e '
  library(jsonlite)
  global <- list()

  if (requireNamespace("fred", quietly = TRUE)) {
    library(fred)
    tryCatch({ global$brent = tail(fred_series("DCOILBRENTEU"), 30) }, error = function(e) NULL)
    tryCatch({ global$henry_hub = tail(fred_series("DHHNGSP"), 30) }, error = function(e) NULL)
    tryCatch({ global$vix = tail(fred_series("VIXCLS"), 30) }, error = function(e) NULL)
  }

  cat(toJSON(global, auto_unbox=TRUE, pretty=TRUE))
'
```

If fred is not available, note: "Global indicators (oil, VIX) require the fred package." Continue without them.

**PMI data:** Manufacturing and services PMIs (S&P Global, ISM) are proprietary and not available through free APIs. When writing the outlook section, Claude should reference the latest PMI readings from its training data and flag: "PMI figures are from Claude's knowledge base and may not reflect the most recent release. Check S&P Global or ISM for current readings."

---

### A6: International Comparison Data

**Only run if `--international` is specified (combinable with any `--country`).**

**If `--international` is specified:**

Fetch international data from three sources in priority order:
1. **FRED** (US Federal Reserve): best for US data and some international series. Requires API key.
2. **ECB** (via readecb): best for Euro area data. No API key required.
3. **OECD** (via readoecd): best for cross-country comparisons and countries not covered by FRED/ECB. No API key required. Use as backup when FRED is unavailable.

**FRED series codes for the top 30 economies:**

FRED hosts OECD Main Economic Indicators (MEI) series for most major economies using standardised code patterns. The key patterns are:

| Indicator | FRED code pattern | Example (Germany) |
|-----------|------------------|-------------------|
| Real GDP (quarterly) | NAEXKP01{CC}Q189S | NAEXKP01DEQ189S |
| CPI (monthly) | CPALTT01{CC}M661N | CPALTT01DEM661N |
| Unemployment (monthly) | LRUNTTTT{CC}M156S | LRUNTTTTDEM156S |
| Policy rate (monthly) | IRSTCB01{CC}M156N | IRSTCB01DEM156N |

Where {CC} is the 2-letter ISO country code. Exceptions noted in the table below.

| # | Economy | ISO | FRED GDP | FRED CPI | FRED Unemployment | OECD code | Notes |
|---|---------|-----|----------|----------|-------------------|-----------|-------|
| 1 | United States | US | A191RL1Q225SBEA | CPIAUCSL | UNRATE | USA | GDP is BEA annualized; also fetch PCEPI, FEDFUNDS, GS10 |
| 2 | China | CN | CHNRGDPEXP | CHNCPIALLMINMEI | LRUN64TTCNM156S | CHN | Urban surveyed unemployment only |
| 3 | Germany | DE | NAEXKP01DEQ189S | CPALTT01DEM661N | LRUNTTTTDEM156S | DEU | |
| 4 | Japan | JP | JPNRGDPEXP | JPNCPIALLMINMEI | LRUNTTTTJPM156S | JPN | Also IRSTCB01JPM156N for BOJ rate |
| 5 | India | IN | NAEXKP01INQ189S | CPALTT01INM661N | LRUNTTTTINM156S | IND | Unemployment data patchy on FRED; OECD backup |
| 6 | United Kingdom | GB | - | - | - | GBR | UK data from ons/boe packages (primary briefing) |
| 7 | France | FR | NAEXKP01FRQ189S | CPALTT01FRM661N | LRUNTTTTFRM156S | FRA | |
| 8 | Italy | IT | NAEXKP01ITQ189S | CPALTT01ITM661N | LRUNTTTTITM156S | ITA | |
| 9 | Brazil | BR | NAEXKP01BRQ189S | CPALTT01BRM661N | LRUNTTTTBRM156S | BRA | |
| 10 | Canada | CA | NAEXKP01CAQ189S | CPALTT01CAM661N | LRUNTTTTCAM156S | CAN | Also IRSTCB01CAM156N for BOC rate |
| 11 | Russia | RU | NAEXKP01RUQ189S | CPALTT01RUM661N | LRUNTTTTRUM156S | RUS | Data may be incomplete post-2022 |
| 12 | South Korea | KR | NAEXKP01KRQ189S | CPALTT01KRM661N | LRUNTTTTKRM156S | KOR | Also IRSTCB01KRM156N for BOK rate |
| 13 | Australia | AU | NAEXKP01AUQ189S | CPALTT01AUM661N | LRUNTTTTAUM156S | AUS | Also IRSTCB01AUM156N for RBA rate |
| 14 | Mexico | MX | NAEXKP01MXQ189S | CPALTT01MXM661N | LRUNTTTTMXM156S | MEX | |
| 15 | Spain | ES | NAEXKP01ESQ189S | CPALTT01ESM661N | LRUNTTTTESM156S | ESP | |
| 16 | Indonesia | ID | NAEXKP01IDQ189S | CPALTT01IDM661N | LRUNTTTTIDM156S | IDN | Quarterly unemployment only |
| 17 | Netherlands | NL | NAEXKP01NLQ189S | CPALTT01NLM661N | LRUNTTTTNLM156S | NLD | |
| 18 | Saudi Arabia | SA | - | CPALTT01SAM661N | - | SAU | GDP via OECD only; limited FRED coverage |
| 19 | Turkey | TR | NAEXKP01TRQ189S | CPALTT01TRM661N | LRUNTTTTTRM156S | TUR | |
| 20 | Switzerland | CH | NAEXKP01CHQ189S | CPALTT01CHM661N | LRUNTTTTCHM156S | CHE | Also IRSTCB01CHM156N for SNB rate |
| 21 | Poland | PL | NAEXKP01PLQ189S | CPALTT01PLM661N | LRUNTTTTPLM156S | POL | |
| 22 | Taiwan | TW | - | - | - | - | Not on FRED or OECD; skip |
| 23 | Belgium | BE | NAEXKP01BEQ189S | CPALTT01BEM661N | LRUNTTTTBEM156S | BEL | |
| 24 | Sweden | SE | NAEXKP01SEQ189S | CPALTT01SEM661N | LRUNTTTTSEM156S | SWE | Also IRSTCB01SEM156N for Riksbank rate |
| 25 | Argentina | AR | NAEXKP01ARQ189S | CPALTT01ARM661N | LRUNTTTTARM156S | ARG | CPI data unreliable pre-2017 |
| 26 | Ireland | IE | NAEXKP01IEQ189S | CPALTT01IEM661N | LRUNTTTTIEM156S | IRL | GDP distorted by multinationals; modified domestic demand (GNI*) preferred |
| 27 | Norway | NO | NAEXKP01NOQ189S | CPALTT01NOM661N | LRUNTTTTNOM156S | NOR | Also IRSTCB01NOM156N for Norges Bank rate |
| 28 | Israel | IL | NAEXKP01ILQ189S | CPALTT01ILM661N | LRUNTTTTILM156S | ISR | |
| 29 | Austria | AT | NAEXKP01ATQ189S | CPALTT01ATM661N | LRUNTTTTATM156S | AUT | |
| 30 | Nigeria | NG | - | - | - | - | Not on FRED MEI; skip |

```bash
Rscript -e '
  library(jsonlite)
  intl <- list()

  # ================================================================
  # FRED: fetch top 30 economies using standardised MEI series codes
  # ================================================================
  if (requireNamespace("fred", quietly = TRUE)) {
    library(fred)

    # Country definitions: name, ISO, GDP code, CPI code, unemployment code, policy rate code (if available)
    countries <- list(
      list(key="us", name="United States",
           gdp="A191RL1Q225SBEA", cpi="CPIAUCSL", unemp="UNRATE",
           rate="FEDFUNDS", extras=list(pce="PCEPI", treasury_10y="GS10")),
      list(key="china", name="China",
           gdp="CHNRGDPEXP", cpi="CHNCPIALLMINMEI", unemp="LRUN64TTCNM156S"),
      list(key="germany", name="Germany",
           gdp="NAEXKP01DEQ189S", cpi="CPALTT01DEM661N", unemp="LRUNTTTTDEM156S"),
      list(key="japan", name="Japan",
           gdp="JPNRGDPEXP", cpi="JPNCPIALLMINMEI", unemp="LRUNTTTTJPM156S",
           rate="IRSTCB01JPM156N"),
      list(key="india", name="India",
           gdp="NAEXKP01INQ189S", cpi="CPALTT01INM661N", unemp="LRUNTTTTINM156S"),
      list(key="france", name="France",
           gdp="NAEXKP01FRQ189S", cpi="CPALTT01FRM661N", unemp="LRUNTTTTFRM156S"),
      list(key="italy", name="Italy",
           gdp="NAEXKP01ITQ189S", cpi="CPALTT01ITM661N", unemp="LRUNTTTTITM156S"),
      list(key="brazil", name="Brazil",
           gdp="NAEXKP01BRQ189S", cpi="CPALTT01BRM661N", unemp="LRUNTTTTBRM156S"),
      list(key="canada", name="Canada",
           gdp="NAEXKP01CAQ189S", cpi="CPALTT01CAM661N", unemp="LRUNTTTTCAM156S",
           rate="IRSTCB01CAM156N"),
      list(key="russia", name="Russia",
           gdp="NAEXKP01RUQ189S", cpi="CPALTT01RUM661N", unemp="LRUNTTTTRUM156S"),
      list(key="south_korea", name="South Korea",
           gdp="NAEXKP01KRQ189S", cpi="CPALTT01KRM661N", unemp="LRUNTTTTKRM156S",
           rate="IRSTCB01KRM156N"),
      list(key="australia", name="Australia",
           gdp="NAEXKP01AUQ189S", cpi="CPALTT01AUM661N", unemp="LRUNTTTTAUM156S",
           rate="IRSTCB01AUM156N"),
      list(key="mexico", name="Mexico",
           gdp="NAEXKP01MXQ189S", cpi="CPALTT01MXM661N", unemp="LRUNTTTTMXM156S"),
      list(key="spain", name="Spain",
           gdp="NAEXKP01ESQ189S", cpi="CPALTT01ESM661N", unemp="LRUNTTTTESM156S"),
      list(key="indonesia", name="Indonesia",
           gdp="NAEXKP01IDQ189S", cpi="CPALTT01IDM661N", unemp="LRUNTTTTIDM156S"),
      list(key="netherlands", name="Netherlands",
           gdp="NAEXKP01NLQ189S", cpi="CPALTT01NLM661N", unemp="LRUNTTTTNLM156S"),
      list(key="saudi_arabia", name="Saudi Arabia",
           cpi="CPALTT01SAM661N"),
      list(key="turkey", name="Turkey",
           gdp="NAEXKP01TRQ189S", cpi="CPALTT01TRM661N", unemp="LRUNTTTTTRM156S"),
      list(key="switzerland", name="Switzerland",
           gdp="NAEXKP01CHQ189S", cpi="CPALTT01CHM661N", unemp="LRUNTTTTCHM156S",
           rate="IRSTCB01CHM156N"),
      list(key="poland", name="Poland",
           gdp="NAEXKP01PLQ189S", cpi="CPALTT01PLM661N", unemp="LRUNTTTTPLM156S"),
      list(key="belgium", name="Belgium",
           gdp="NAEXKP01BEQ189S", cpi="CPALTT01BEM661N", unemp="LRUNTTTTBEM156S"),
      list(key="sweden", name="Sweden",
           gdp="NAEXKP01SEQ189S", cpi="CPALTT01SEM661N", unemp="LRUNTTTTSEM156S",
           rate="IRSTCB01SEM156N"),
      list(key="argentina", name="Argentina",
           gdp="NAEXKP01ARQ189S", cpi="CPALTT01ARM661N", unemp="LRUNTTTTARM156S"),
      list(key="ireland", name="Ireland",
           gdp="NAEXKP01IEQ189S", cpi="CPALTT01IEM661N", unemp="LRUNTTTTIEM156S"),
      list(key="norway", name="Norway",
           gdp="NAEXKP01NOQ189S", cpi="CPALTT01NOM661N", unemp="LRUNTTTTNOM156S",
           rate="IRSTCB01NOM156N"),
      list(key="israel", name="Israel",
           gdp="NAEXKP01ILQ189S", cpi="CPALTT01ILM661N", unemp="LRUNTTTTILM156S"),
      list(key="austria", name="Austria",
           gdp="NAEXKP01ATQ189S", cpi="CPALTT01ATM661N", unemp="LRUNTTTTATM156S")
    )

    for (c in countries) {
      tryCatch({
        d <- list()
        if (!is.null(c$gdp))   d$gdp          <- tail(fred_series(c$gdp), 8)
        if (!is.null(c$cpi))   d$cpi          <- tail(fred_series(c$cpi), 12)
        if (!is.null(c$unemp)) d$unemployment <- tail(fred_series(c$unemp), 12)
        if (!is.null(c$rate))  d$policy_rate  <- tail(fred_series(c$rate), 12)
        if (!is.null(c$extras)) {
          for (nm in names(c$extras)) {
            d[[nm]] <- tail(fred_series(c$extras[[nm]]), 12)
          }
        }
        if (length(d) > 0) intl[[c$key]] <- d
      }, error = function(e) message(c$name, " FRED fetch failed: ", e$message))
    }
  }

  # ================================================================
  # ECB: Euro area aggregate (primary source, more timely than FRED)
  # ================================================================
  if (requireNamespace("readecb", quietly = TRUE)) {
    tryCatch({
      library(readecb)
      intl$euro_area <- list(
        gdp          = tail(ecb_get("MNA.Q.Y.I8.W2.S1.S1.B.B1GQ._Z._Z._Z.EUR.LR.GY"), 8),
        hicp         = tail(ecb_get("ICP.M.U2.N.000000.4.ANR"), 12),
        unemployment = tail(ecb_get("STS.M.I8.S.UNEH.RTT000.4.000"), 12),
        ecb_rate     = tail(ecb_get("FM.D.U2.EUR.4F.KR.MRR_FR.LEV"), 30)
      )
    }, error = function(e) message("ECB fetch failed: ", e$message))
  }

  # ================================================================
  # OECD: aggregates (G7, OECD, G20) and backup for missing countries
  # ================================================================
  if (requireNamespace("readoecd", quietly = TRUE)) {
    tryCatch({
      library(readoecd)
      intl$aggregates <- list(
        gdp_g7     = tail(get_oecd_gdp("G-7"), 8),
        gdp_g20    = tail(get_oecd_gdp("G-20"), 8),
        gdp_oecd   = tail(get_oecd_gdp("OECD"), 8),
        cpi_g7     = tail(get_oecd_cpi("G-7"), 12),
        cpi_oecd   = tail(get_oecd_cpi("OECD"), 12),
        unemp_g7   = tail(get_oecd_unemployment("G-7"), 12),
        unemp_oecd = tail(get_oecd_unemployment("OECD"), 12)
      )

      # Fill any country that FRED missed (no API key, or series unavailable)
      oecd_backfill <- list(
        japan     = "JPN", india     = "IND", france    = "FRA",
        italy     = "ITA", brazil    = "BRA", canada    = "CAN",
        south_korea = "KOR", australia = "AUS", mexico  = "MEX",
        spain     = "ESP", indonesia = "IDN", netherlands = "NLD",
        turkey    = "TUR", switzerland = "CHE", poland  = "POL",
        belgium   = "BEL", sweden    = "SWE", ireland  = "IRL",
        norway    = "NOR", israel    = "ISR", austria  = "AUT",
        germany   = "DEU", argentina = "ARG"
      )
      for (key in names(oecd_backfill)) {
        if (is.null(intl[[key]])) {
          cc <- oecd_backfill[[key]]
          tryCatch({
            intl[[key]] <- list(
              gdp          = tail(get_oecd_gdp(cc), 8),
              cpi          = tail(get_oecd_cpi(cc), 12),
              unemployment = tail(get_oecd_unemployment(cc), 12)
            )
          }, error = function(e) NULL)
        }
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

---

## SECTION B: DASHBOARDS

### Step 3: Show the dashboard and ask what the user needs

Present the country-specific dashboard.

### B1: UK Dashboard

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

### B2: US Dashboard

```
US MACRO DASHBOARD
==================
GDP (annualized q/q):  [val]%        (prev: [val]%)
Nonfarm payrolls:      +[val]k       (prev: +[val]k)
Unemployment:          [val]%        (prev: [val]%)
Initial claims:        [val]k        (4wk avg: [val]k)
CPI (annual):          [val]%        (prev: [val]%)
Core CPI:              [val]%
PCE (annual):          [val]%        (Fed's preferred measure)
Core PCE:              [val]%
Fed funds rate:        [val]%
2yr Treasury:          [val]%
10yr Treasury:         [val]%
10y-2y spread:         [val]bp
HY spread:             [val]bp
30yr mortgage:         [val]%
Housing starts:        [val]k (SAAR)
Case-Shiller HPI:     [val]% y/y
Consumer sentiment:    [val]         (prev: [val])
Brent crude:           $[val]/bbl
VIX:                   [val]

Data as of: [latest date from each series]
```

### B3: Euro Area Dashboard

```
EURO AREA MACRO DASHBOARD
==========================
GDP (q/q):             [val]%        (prev: [val]%)
Unemployment:          [val]%        (prev: [val]%)
HICP (annual):         [val]%        (prev: [val]%)
Core HICP:             [val]%
Services HICP:         [val]%
ECB deposit rate:      [val]%
ECB MRO rate:          [val]%
ESTR:                  [val]%
3m EURIBOR:            [val]%
12m EURIBOR:           [val]%
2yr AAA yield:         [val]%
10yr AAA yield:        [val]%
M3 growth (y/y):       [val]%
NFC lending rate:      [val]%
Mortgage rate:         [val]%
EUR/USD:               [val]
Govt debt/GDP:         [val]%
Brent crude:           EUR [val]/bbl

Data as of: [latest date from each series]
```

### B4: Australia Dashboard

**If readabs + readrba available (full coverage):**
```
AUSTRALIA MACRO DASHBOARD
==========================
GDP (q/q):             [val]%        (prev: [val]%)
Unemployment:          [val]%        (prev: [val]%)
Participation rate:    [val]%
Employment:            [val]k        (full-time: [val]k)
CPI (annual, q/q):     [val]%        (prev: [val]%)
Trimmed mean CPI:      [val]%        (RBA preferred core)
WPI (y/y):             [val]%
RBA cash rate:         [val]%
AUD/USD:               [val]
Retail sales (m/m):    [val]%
Building approvals:    [val]k
Iron ore:              US$[val]/t
Brent crude:           A$[val]/bbl

Data as of: [latest date from each series]
```

**If FRED/OECD only (limited coverage):**
```
AUSTRALIA MACRO DASHBOARD
==========================
GDP (q/q):             [val]%        (prev: [val]%)
Unemployment:          [val]%        (prev: [val]%)
CPI (annual):          [val]%        (prev: [val]%)
RBA cash rate:         [val]%
Iron ore:              US$[val]/t
Brent crude:           A$[val]/bbl

Data as of: [latest date]. Install readabs + readrba for full coverage (12+ indicators).
```

### Interactive Menu

**If `--full` was NOT specified**, ask using AskUserQuestion:

Question: "What output do you need?"

Options:
- A) **Full briefing** : All sections
- B) **Pick sections** : Choose which sections
- C) **Dashboard only** : Just the summary table above
- D) **Data only** : JSON file with all values

**If user picks B**, ask a follow-up (multiSelect: true) with country-specific sections:

**UK sections:**
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
- International comparison (requires --international data)
- Outlook and risks

**US sections:**
- Output and activity (GDP annualized, industrial production, retail sales)
- Labour market (payrolls, unemployment, claims, JOLTS, earnings)
- Prices (CPI headline/core, PCE headline/core)
- Monetary policy (Fed funds, FOMC context)
- Financial conditions (Treasuries, yield curve, HY spreads, mortgage rates)
- Housing (starts, Case-Shiller, affordability)
- Consumer (sentiment, retail trajectory)
- Outlook and risks

**Euro area sections:**
- Economic activity (GDP, production)
- Labour market (unemployment, employment, wages)
- Prices (HICP headline, core, services, food, non-energy goods)
- Monetary and financial conditions (ECB rates, ESTR, EURIBOR, yields, M3, lending)
- Fiscal (government debt/GDP)
- Outlook and risks

**Australia sections:**
- Domestic economy (GDP, consumption)
- Labour market (unemployment, participation)
- Inflation (CPI headline, trimmed mean)
- Financial conditions (cash rate, yields)
- Outlook and risks

---

## SECTION C: NARRATIVE TEMPLATES

### Step 4: Generate the requested output

Use the narrative templates matching the selected country. C1 for UK, C2 for US, C3 for EU, C4 for AU. All countries also use D1 (traffic-light outlook) in their Outlook section.

### C1: UK Narrative Templates (BoE MPR structure)

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

### G7 economies

| Indicator | UK | US | Germany | Japan | France | Italy | Canada | G7 avg |
|-----------|----|----|---------|-------|--------|-------|--------|--------|
| GDP growth | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |
| Inflation | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |
| Unemployment | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |
| Policy rate | [val]% | [val]% | ECB [val]% | [val]% | ECB [val]% | ECB [val]% | [val]% | - |

### Major emerging and other advanced economies

| Indicator | China | India | Brazil | S. Korea | Australia | Mexico | Indonesia | Turkey |
|-----------|-------|-------|--------|----------|-----------|--------|-----------|--------|
| GDP growth | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |
| Inflation | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |
| Unemployment | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |

### European peers

| Indicator | UK | Germany | France | Spain | Netherlands | Switzerland | Sweden | Poland |
|-----------|----|----|---------|-------|-------------|-------------|--------|--------|
| GDP growth | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |
| Inflation | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |
| Unemployment | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% | [val]% |

### Aggregates

| Indicator | UK | G7 | G20 | OECD | Euro area |
|-----------|----|----|-----|------|-----------|
| GDP growth | [val]% | [val]% | [val]% | [val]% | [val]% |
| Inflation | [val]% | [val]% | - | [val]% | [val]% |
| Unemployment | [val]% | [val]% | - | [val]% | [val]% |

[Only include rows/columns for countries where data was successfully retrieved. Omit countries rather than showing blanks. If fewer than 4 countries available in a sub-table, merge into the table above it.]

### Interpretation

[Address these questions:
- Where is the UK in the global cycle? (leading, lagging, or in line with G7 peers)
- How does the UK compare to its European peers specifically? (post-Brexit divergence or convergence)
- Are policy rates converging or diverging across major central banks? (implications for GBP and capital flows)
- Is the UK an outlier on any indicator? (e.g., higher inflation than peers, weaker growth, tighter labour market)
- What are the trade-weighted implications? (UK's major partners: EU ~42% of trade, US ~16%, China ~7%)]

### Data sources and comparability notes

- GDP: quarterly real growth rates. US reports annualized (divide by ~4 for approximate q/q comparison); all others report q/q. OECD data standardised to q/q.
- Inflation: CPI for most countries, PCE for US (Fed's preferred measure), HICP for Euro area and individual EU members. Basket weights and methodologies differ across jurisdictions.
- Unemployment: ILO harmonised definition for OECD countries. China uses surveyed urban unemployment (narrower scope). India data has longer publication lags.
- Policy rates: Bank Rate (UK), Fed Funds (US), ECB main refinancing rate (Euro area members), BOJ (Japan), BOC (Canada), RBA (Australia), Riksbank (Sweden), SNB (Switzerland), BOK (South Korea), Norges Bank (Norway).
- Aggregates: G7, G20, and OECD totals from OECD Economic Outlook database.
- Countries not covered: Taiwan (not on FRED or OECD), Nigeria (limited FRED coverage), Saudi Arabia (GDP via OECD only).

*Data sources: FRED (27 countries via OECD MEI series), ECB Statistical Data Warehouse (Euro area aggregate), OECD (G7/G20/OECD aggregates and backup for missing countries). ONS and BoE for UK data.*
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

---

### C2: US Narrative Templates (FOMC / Beige Book structure)

Each section follows the same bold-lead-sentence pattern as the UK templates. Every section stands alone.

**US key numbers block:**
```markdown
<!-- KEY NUMBERS
type: macro
date: [YYYY-MM-DD]
framework: us
gdp_annualized_pct: [val]
unemployment_pct: [val]
payrolls_change_k: [val]
cpi_pct: [val]
cpi_core_pct: [val]
pce_pct: [val]
pce_core_pct: [val]
fed_funds_pct: [val]
treasury_2y_pct: [val]
treasury_10y_pct: [val]
yield_spread_bp: [val]
mortgage_30y_pct: [val]
housing_starts_k: [val]
case_shiller_yy_pct: [val]
consumer_sentiment: [val]
brent_usd: [val]
-->
```

**Output and activity:**
```markdown
## Output and Activity

**Real GDP grew at an annualized rate of [val]% in [quarter], [above/below/in line with] the prior quarter's [val]%.** On an approximate quarter-on-quarter basis (~[val/4]%), this compares to [UK/EU equivalent] of [val]%. Industrial production [rose/fell] [val]% in [month]. Retail sales [rose/fell] [val]%.

[1-2 sentences on sectoral composition or momentum.]
```

**Labour market:**
```markdown
## Labour Market

**The economy added [val]k nonfarm jobs in [month], [above/below] the 3-month average of [val]k.** The unemployment rate stands at [val]%, [up/down] from [val]%. Initial jobless claims averaged [val]k over the past 4 weeks.

Job openings (JOLTS) stand at [val]m, giving a vacancies-to-unemployed ratio of [computed]. Average hourly earnings grew [val]% year-on-year. [Interpretation: is the labour market tight, balanced, or loosening?]
```

**Prices:**
```markdown
## Prices

**CPI inflation [rose/fell] to [val]% in [month], while the Fed's preferred measure (core PCE) was [val]%.** Headline PCE was [val]%. Core CPI (excluding food and energy) was [val]%.

The divergence between CPI and PCE [is/is not] significant because [shelter weighting, methodology differences]. [Services vs goods decomposition if relevant.]

*Note: The Fed targets 2% PCE inflation, not CPI. PCE gives lower weight to shelter and uses a chain-weighted methodology.*
```

**Monetary policy:**
```markdown
## Monetary Policy

**The federal funds rate stands at [val]%, [unchanged since / following the [month] FOMC decision to [cut/raise] by [X]bp].** Markets are pricing [X] further [cuts/hikes] by year-end.

[1-2 sentences on FOMC guidance, dot plot implications, or key dissents if relevant.]
```

**Financial conditions:**
```markdown
## Financial Conditions

**Treasury yields:** The 10-year yield stands at [val]%, with the 2-year at [val]%. The 2s10s spread is [val]bp, [indicating/suggesting]. [If inverted: "The yield curve remains inverted, historically a recession signal, though the current inversion has lasted [duration]."]

**Credit conditions:** The high-yield spread is [val]bp, [tight/widening/stable by historical standards]. [Interpretation.]

**Mortgage rates:** The 30-year fixed rate is [val]%, [up/down] from [val]% [period ago]. [Impact on housing affordability.]
```

**Housing:**
```markdown
## Housing

**Housing starts [rose/fell] to [val]k (SAAR) in [month].** The Case-Shiller national home price index is [val]% higher year-on-year. With 30-year mortgage rates at [val]%, affordability remains [assessment].

[1-2 sentences on supply vs demand dynamics.]
```

**Consumer:**
```markdown
## Consumer

**The University of Michigan consumer sentiment index [rose/fell] to [val] in [month], [above/below] its long-run average of ~85.** Retail sales [rose/fell] [val]% in [month], suggesting [consumer spending assessment].

[1-2 sentences on consumer balance sheets, savings rate if data available.]
```

**Outlook and risks:** Use the traffic-light system from Section D1.

**US slide summary:**
```markdown
**US Macro Snapshot, [Month Year]**

- GDP **[val]% annualized** in [quarter], payrolls **+[val]k** in [month]
- Unemployment **[val]%**, avg hourly earnings **[val]%** y/y
- CPI **[val]%**, core PCE **[val]%** (Fed target: 2%)
- Fed funds **[val]%**, 10yr Treasury **[val]%**, 2s10s **[val]bp**
- Housing starts **[val]k**, Case-Shiller **[val]%** y/y, 30yr mortgage **[val]%**
- Consumer sentiment **[val]**, Brent **$[val]/bbl**

*Data from FRED (Federal Reserve Economic Data). Powered by econstack.*
```

---

### C3: Euro Area Narrative Templates (ECB Economic Bulletin structure)

**Euro area key numbers block:**
```markdown
<!-- KEY NUMBERS
type: macro
date: [YYYY-MM-DD]
framework: eu
gdp_qq_pct: [val]
unemployment_pct: [val]
hicp_pct: [val]
hicp_core_pct: [val]
hicp_services_pct: [val]
ecb_deposit_pct: [val]
ecb_mro_pct: [val]
estr_pct: [val]
euribor_3m_pct: [val]
yield_10y_pct: [val]
m3_yy_pct: [val]
eur_usd: [val]
govt_debt_gdp_pct: [val]
brent_eur: [val]
-->
```

**Economic activity:**
```markdown
## Economic Activity

**Euro area real GDP grew [val]% quarter-on-quarter in [quarter], [above/below] the previous quarter's [val]%.** On a year-on-year basis, output was [val]% higher/lower.

[1-2 sentences on sectoral composition, industrial production, or consumption.]
```

**Labour market:**
```markdown
## Labour Market

**The euro area unemployment rate [rose/fell] to [val]% in [month], [up/down] from [val]%.** [Comparison to pre-pandemic rate.]

[1-2 sentences on employment growth and wage dynamics if data available.]
```

**Prices:**
```markdown
## Prices

**HICP inflation [rose/fell] to [val]% in [month].** Core HICP (excluding energy and food) was [val]%. Services inflation was [val]%. Food inflation was [val]%. Non-energy industrial goods (NEIG) inflation was [val]%.

[The ECB closely monitors the services/core split. Interpret: is underlying inflation sticky or easing?]

*Note: The ECB targets 2% HICP inflation symmetrically. The HICP decomposition (services, food, NEIG, energy) is the standard ECB reporting framework.*
```

**Monetary and financial conditions:**
```markdown
## Monetary and Financial Conditions

**ECB policy rates:** The deposit facility rate stands at [val]%, the main refinancing rate at [val]%, and the marginal lending rate at [val]%. [Context on latest Governing Council decision.]

**Money markets:** ESTR (the euro short-term rate) is [val]%. 3-month EURIBOR is [val]%, 12-month EURIBOR is [val]%.

**Sovereign yields:** The 10-year AAA-rated euro area government bond yield is [val]%, the 2-year is [val]%. [Interpretation of term structure.]

**Credit conditions:** Bank lending rates to non-financial corporations are [val]%. Mortgage rates are [val]%. M3 money supply grew [val]% year-on-year. [Interpretation of credit impulse.]

**Exchange rate:** EUR/USD at [val]. [Direction and implications for import prices.]
```

**Fiscal:**
```markdown
## Fiscal

**Euro area general government debt stands at [val]% of GDP.** [1-2 sentences on aggregate fiscal stance or notable country-level developments if relevant.]
```

**Outlook and risks:** Use the traffic-light system from Section D1.

**Euro area slide summary:**
```markdown
**Euro Area Macro Snapshot, [Month Year]**

- GDP **[val]% q/q** in [quarter]
- Unemployment **[val]%**, HICP **[val]%**, core **[val]%**, services **[val]%**
- ECB deposit rate **[val]%**, ESTR **[val]%**, 10yr AAA **[val]%**
- M3 **[val]%** y/y, NFC lending rate **[val]%**, mortgage rate **[val]%**
- EUR/USD **[val]**, Brent **EUR [val]/bbl**
- Govt debt **[val]%** of GDP

*Data from ECB Statistical Data Warehouse (via readecb R package). Powered by econstack.*
```

---

### C4: Australia Narrative Templates (RBA Statement on Monetary Policy structure)

**Australia key numbers block:**
```markdown
<!-- KEY NUMBERS
type: macro
date: [YYYY-MM-DD]
framework: au
gdp_qq_pct: [val]
unemployment_pct: [val]
participation_pct: [val]
cpi_pct: [val]
trimmed_mean_pct: [val]
wpi_yy_pct: [val]
rba_rate_pct: [val]
aud_usd: [val]
retail_mm_pct: [val]
building_approvals_k: [val]
iron_ore_usd: [val]
brent_aud: [val]
-->
```

**Domestic economy:**
```markdown
## Domestic Economy

**Australian real GDP grew [val]% quarter-on-quarter in [quarter], [above/below] the previous quarter's [val]%.** On an annual basis, growth is [val]%.

Retail sales [rose/fell] [val]% in [month], suggesting [consumer spending assessment]. Building approvals were [val]k in [month], [up/down] from [val]k, [interpretation for dwelling investment outlook].

[1-2 sentences on demand composition: household consumption, dwelling investment, government spending, net exports. If iron ore data available: "Iron ore prices at US$[val]/t [support/weigh on] the terms of trade."]
```

**Labour market:**
```markdown
## Labour Market

**The unemployment rate [rose/fell] to [val]% in [month], [up/down] from [val]%.** The participation rate is [val]%, [above/below] its pre-pandemic average of ~66%. Total employment stands at [val]k, with [val]k full-time and [val]k part-time.

Monthly hours worked [rose/fell] [val]% in [month]. [Interpretation: hours worked often leads employment turning points.]

[1-2 sentences: is the labour market tightening or loosening? Full-time vs part-time composition? Underemployment context?]
```

**Inflation:**
```markdown
## Inflation

**CPI inflation [rose/fell] to [val]% year-on-year in the [month] quarter.** Trimmed mean inflation, the RBA's preferred core measure, was [val]%.

[Interpretation relative to the RBA's 2-3% target band. If both are within the band: "Both headline and underlying inflation are within the RBA's target band." If trimmed mean is above band: "Underlying inflation remains above the RBA's 2-3% target."]

The Wage Price Index grew [val]% year-on-year in [quarter]. [Interpretation: are wages growing faster or slower than inflation? Is real wage growth positive?]

*Note: Australian CPI is published quarterly (not monthly), with a ~4-week lag after the quarter end. Trimmed mean CPI strips out the most volatile items and is the RBA's primary gauge of underlying inflation. The 2-3% target band is wider than the UK (2%), US (2% PCE), or Euro area (2% HICP).*
```

**Financial conditions:**
```markdown
## Financial Conditions

**The RBA cash rate stands at [val]%, [unchanged since / following the [month] decision to [cut/raise] by [X]bp].** [1-2 sentences on rate outlook and market pricing.]

The Australian dollar is at US$[val], [up/down] from US$[val] [period ago]. [Interpretation: AUD movements affect import prices and the competitiveness of exports. A weaker AUD supports commodity exporters but adds to imported inflation.]

[If iron ore data available: "Iron ore at US$[val]/t is [above/below] the ~US$100/t level that roughly balances the terms of trade for budget forecasting purposes."]

[If Brent crude data available: "Brent crude at A$[val]/bbl. Australia is a net energy exporter (LNG, coal), so higher oil/gas prices tend to support the terms of trade."]
```

**Outlook and risks:** Use the traffic-light system from Section D1.

**Australia slide summary:**
```markdown
**Australia Macro Snapshot, [Month Year]**

- GDP **[val]% q/q** in [quarter], retail sales **[val]%** m/m
- Unemployment **[val]%**, participation **[val]%**, WPI **[val]%** y/y
- CPI **[val]%**, trimmed mean **[val]%** (RBA target: 2-3%)
- RBA cash rate **[val]%**, AUD/USD **[val]**
- Iron ore **US$[val]/t**, building approvals **[val]k**

*Data from ABS (via readabs), RBA (via readrba), and FRED. Powered by econstack.*
```

---

## SECTION D: CROSS-CUTTING

### D1: Traffic-Light Macro Assessment

Include this table in the "Outlook and Risks" section for ALL countries. It provides a structured, at-a-glance assessment.

```markdown
### Macro Assessment

| Dimension | Signal | Assessment |
|-----------|--------|------------|
| Growth | [GREEN/AMBER/RED] | [1-line rationale] |
| Inflation | [GREEN/AMBER/RED] | [1-line rationale] |
| Labour market | [GREEN/AMBER/RED] | [1-line rationale] |
| Financial conditions | [GREEN/AMBER/RED] | [1-line rationale] |
| External/trade | [GREEN/AMBER/RED] | [1-line rationale] |

Signal key: GREEN = improving or on target | AMBER = mixed signals, watch | RED = deteriorating or off target
```

**Assessment rules (quantitative thresholds):**

| Dimension | GREEN | AMBER | RED |
|-----------|-------|-------|-----|
| Growth | GDP q/q > 0.3% (UK/EU/AU) or annualized > 1.5% (US) | GDP 0-0.3% q/q or decelerating | GDP negative or near-zero for 2+ quarters |
| Inflation | Within 0.5pp of target | 0.5-1.5pp from target, moving in right direction | >1.5pp from target and sticky or moving wrong way |
| Labour market | Unemployment stable or falling, below NAIRU estimate | Unemployment rising <0.5pp in 3 months | Unemployment rising >0.5pp in 3 months |
| Financial conditions | Yield spreads stable, credit flowing, exchange rate orderly | Spreads widening moderately, credit slowing | HY spread >500bp, yield curve deeply inverted, credit contraction |
| External/trade | Trade balance improving or stable, commodity prices supportive | Trade deficit widening, mixed commodity signals | Terms of trade shock, major trading partner recession |

**Country-specific targets:**

| Country | Inflation target | Trend growth (approx) | NAIRU estimate | Key rate |
|---------|-----------------|----------------------|----------------|----------|
| UK | 2% CPI | ~1.5% | ~4.5% | Bank Rate |
| US | 2% PCE | ~2.0% | ~4.0% | Fed funds |
| Euro area | 2% HICP (symmetric) | ~1.0% | ~6.5% | ECB deposit |
| Australia | 2-3% CPI band | ~2.5% | ~4.5% | RBA cash |

Target-consistent wage growth: inflation target + trend productivity growth. UK ~3.5%, US ~3.5%, EU ~3.0%, AU ~3.5-4.5%.

After the traffic-light table, include the existing upside/downside risk format:

```markdown
**Key upside risks:**
- [Risk 1]
- [Risk 2]

**Key downside risks:**
- [Risk 1]
- [Risk 2]
```

---

### Step 5: Output formats

**If `--format` was NOT specified on the command line**, ask using AskUserQuestion:

Question: "What file formats do you need?"

Options (multiSelect: true):
- Markdown (.md) : Default, always included
- HTML : Self-contained branded page for email or browser
- Word (.docx) : Formatted document for editing
- PowerPoint (.pptx) : Slide deck with dashboard and key sections
- PDF : Branded consulting-quality PDF via Quarto

Markdown is always generated regardless of selection.

**If `--format` was specified**, skip the question and use the specified format(s).

### Step 6: Save and present

Save as `macro-briefing-{country}-{date}.md`. Always save `macro-data-{country}-{date}.json`.

**Then generate each additional format the user selected:**

**HTML** (if selected):
Generate a self-contained HTML file with inline CSS. GOV.UK-style navy branding (#003078), dashboard KPI cards at the top, professional tables. Save as `macro-briefing-{country}-{date}.html`.

**Word (.docx)** (if selected):
Invoke the `/docx` skill. Pass the markdown content. Navy headings, formatted tables, title page with country and date. If `--client` specified, include "Prepared for". Save as `macro-briefing-{country}-{date}.docx`.

**PowerPoint (.pptx)** (if selected):
Invoke the `/pptx` skill. Create slides: (1) Title, (2) Dashboard table, (3) Key sections as selected, (4) Traffic-light assessment, (5) Data sources. Navy accent. Save as `macro-briefing-{country}-{date}.pptx`.

**Executive summary deck** (if `--exec` specified):

Invoke the `/pptx` skill to create a management consulting-style executive summary deck. Every slide follows the **action title + evidence** pattern: a 2-line strapline stating the conclusion (a complete sentence, NOT a topic label), then 3-4 dot points proving it.

Formatting: Action title 24-28pt bold navy (#003078). Body 14-16pt, one key number bolded per bullet. Footer 10pt light grey with data source + vintage date. Clean white background, no decorative elements. Slide numbers bottom-right. Charts in navy/grey/light blue palette.

**Slide 1: Title**
- "[Country] Macroeconomic Outlook" (large, navy)
- [Month Year], "Prepared for: [client]" if specified

**Slide 2: Traffic light dashboard**
- Action title: "The [country] economy is [expanding steadily / slowing / in recession / showing mixed signals]"
- Evidence: 6-8 key indicators in a compact GREEN/AMBER/RED grid
  - GDP growth: **[X]%** [traffic light]
  - Inflation: **[X]%** [traffic light]
  - Unemployment: **[X]%** [traffic light]
  - Wage growth: **[X]%** [traffic light]
  - Policy rate: **[X]%** [traffic light]
  - [1-2 more as relevant]

**Slide 3: Growth and inflation**
- Action title: "GDP growth is [accelerating/decelerating/stable] at [X]%, with inflation [above/at/below] target at [X]%"
- Evidence:
  - GDP: **[X]%** ([quarterly/annual], [latest period])
  - Inflation (CPI): **[X]%** ([latest month])
  - Core inflation: **[X]%**
  - [Key driver: e.g. "Growth driven by services/consumption/exports"]
- Optional: simple line chart suggestion (GDP + inflation trends)

**Slide 4: Labour market**
- Action title: "[Labour market] is [tight/loosening/stable] with unemployment at [X]%"
- Evidence:
  - Employment rate: **[X]%** ([vs pre-pandemic/historical average])
  - Unemployment: **[X]%**
  - Wage growth (nominal): **[X]%**, real: **[X]%**
  - [Key trend: e.g. "Vacancies falling but employment resilient"]

**Slide 5: Monetary policy**
- Action title: "[Central bank] is [holding rates / expected to cut / tightening further] at [X]%"
- Evidence:
  - Current policy rate: **[X]%**
  - Last decision: [date, action]
  - Market expectations: [next move, timing]
  - [Key consideration: e.g. "Inflation persistence vs growth slowdown"]

**Slide 6: Outlook and risks**
- Action title: "Key risks are [1-line summary of top risk]"
- Evidence: 3-4 bullets, each a risk or turning point
  - [Risk 1 with direction and magnitude]
  - [Risk 2]
  - [Risk 3]
  - [Optional: upcoming data releases or policy decisions to watch]
- Footer: "Full briefing: macro-briefing-{country}-{date}.md"

Save as `macro-exec-{country}-{date}.pptx`.

**PDF** (if selected):
```bash
ECONSTACK_DIR="$HOME/.claude/skills/econstack"
"$ECONSTACK_DIR/scripts/render-report.sh" macro-briefing-{country}-{date}.md \
  --title "[Country Name] Macroeconomic Briefing" \
  --subtitle "[Month Year]"
```
Where country name is: "UK" / "US" / "Euro Area" / "Australia".

Tell the user what was generated:
```
Files saved:
  macro-briefing-{country}-{date}.md      (report)
  macro-data-{country}-{date}.json        (structured data)
  macro-briefing-{country}-{date}.html    (if HTML selected)
  macro-briefing-{country}-{date}.docx    (if Word selected)
  macro-briefing-{country}-{date}.pptx    (if PowerPoint selected)
  macro-briefing-{country}-{date}.pdf     (if PDF selected)
```

Country-specific data source footer:
- UK: *Data sources: ONS (via ons R package), Bank of England (via boe R package).*
- US: *Data sources: FRED (Federal Reserve Economic Data, via fred R package).*
- EU: *Data sources: ECB Statistical Data Warehouse (via readecb R package).*
- AU: *Data sources: ABS (via readabs), RBA (via readrba), FRED, and OECD.*

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
- Bold lead sentence in every section: state the finding, not just the topic.
- All comparisons need context: vs previous period, vs year ago, vs target/forecast where applicable.
- Be specific about dates. "Q4 2025" not "last quarter". "February 2026" not "last month".
- The companion JSON must include every data point used in the briefing, with dates and sources.
- **UK-specific:** Target-consistent wage growth is approximately 3-3.5% (2% inflation target + 1-1.5% productivity growth). CPI services is the MPC's closest-watched indicator. Real wages = nominal AWE growth minus CPI.
- **US-specific:** Always distinguish PCE (Fed's preferred) from CPI. GDP is reported annualized, always state this. Note the 2s10s yield spread and its historical recession signal.
- **EU-specific:** Report the full HICP decomposition (services, food, NEIG, energy). Note which countries are in the euro area vs EU. ECB targets 2% symmetrically.
- **AU-specific:** CPI is quarterly, not monthly. The RBA's target band is 2-3%, wider than other central banks. Note data limitations honestly.
