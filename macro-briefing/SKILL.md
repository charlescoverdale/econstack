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
