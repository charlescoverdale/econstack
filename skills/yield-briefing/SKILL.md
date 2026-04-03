---
name: yield-briefing
description: Gilt yield curve analysis. Nelson-Siegel fit, PCA, carry/rolldown, forwards, break-evens, recession signal. Uses yieldcurves + boe. Interactive section selection.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# /yield-briefing: Gilt Market and Yield Curve Analysis

Analyse the UK gilt yield curve: fit parametric models, decompose moves into level/slope/curvature, compute carry and rolldown, extract forward rates, assess break-even inflation, and check the recession signal. Follows the analytical framework used by fixed income desks and the Bank of England.

**This skill is interactive.** It fetches the curve, runs the analysis, then asks what output you need.

## Arguments

```
/yield-briefing [options]
```

**Examples:**
```
/yield-briefing
/yield-briefing --full
/yield-briefing --focus carry
```

**Options:**
- `--full` : Skip menu, generate all sections
- `--focus <area>` : Emphasise one area (snapshot, model, pca, carry, forwards, breakeven)
- `--client "Name"` : Add "Prepared for"
- `--format pdf` : Branded PDF

## Prerequisites

R packages: `yieldcurves`, `boe`. Install with:
```r
install.packages(c("yieldcurves", "boe"))
```

## Instructions

### Step 1: Fetch data and run analysis

```r
library(yieldcurves)
library(boe)

# Fetch yield curve data
nominal_curve <- boe_yield_curve()  # Nominal gilt yields by maturity
bank_rate <- boe_bank_rate()
sonia <- boe_sonia()

# Key rates
# Extract 2y, 5y, 10y, 30y from the curve data

# Layer 1: Nelson-Siegel fit
ns_fit <- yc_nelson_siegel(maturities, yields)
# Extract: beta0 (level), beta1 (slope), beta2 (curvature), tau (decay)

# Layer 2: PCA (requires a time series of curves)
# If historical data available:
pca_result <- yc_pca(yield_matrix)

# Layer 3: Level, slope, curvature
lsc <- yc_level_slope_curvature(maturities, yields)
slope_2s10s <- yc_slope(yields_2y, yields_10y)

# Layer 4: Carry and rolldown
carry <- yc_carry(maturities, yields, funding_rate = bank_rate_latest)

# Layer 5: Forward rates
forwards <- yc_forward(maturities, yields)
# Extract 1y1y, 2y1y, 5y5y forward rates

# Layer 6: Duration and convexity (for risk context)
duration <- yc_duration(maturities, yields, coupon_rates)
```

### Step 2: Show results and ask what the user needs

```
GILT CURVE SNAPSHOT
====================
2y:    [val]%  ([+/-]bp vs prev)     10y:  [val]%  ([+/-]bp)
5y:    [val]%  ([+/-]bp)             30y:  [val]%  ([+/-]bp)

2s10s: [val]bp ([change] vs prev)    5s30s: [val]bp
Bank rate: [val]%                    SONIA: [val]%

Regime: [BULL/BEAR] [FLATTENER/STEEPENER]

NS fit: level=[val]  slope=[val]  curvature=[val]
Best carry+rolldown: [maturity] ([val]bp/month)
5y5y forward: [val]%
```

**If `--full` was NOT specified**, ask using AskUserQuestion:

Question: "What output do you need?"

Options:
- A) **Full briefing** : All 6 layers
- B) **Pick sections** : Choose which analyses
- C) **Summary table** : Rates, spreads, carry only
- D) **Data only** : JSON

**If user picks B** (multiSelect: true):

Options:
- Curve snapshot and regime (key rates, spreads, bull/bear classification)
- Nelson-Siegel model fit (parameters, fitted vs actual, cheap/rich analysis)
- PCA decomposition (level/slope/curvature attribution of recent moves)
- Carry and rolldown (expected returns by maturity bucket)
- Forward rates and expectations (1y1y, 5y5y, implied rate path)
- Break-even inflation (nominal vs real, implied inflation)
- Recession signal (10y-2y and 10y-3m spread, historical context)
- Duration and convexity (risk metrics by maturity)
- Methodology summary (one paragraph)
- References

### Step 3: Generate the requested output

**Always include key numbers block and companion JSON.**

#### Section templates

**Curve snapshot and regime:**
```markdown
## Gilt Curve Snapshot

| Maturity | Yield | Change (day) | Change (week) | Change (month) |
|----------|-------|-------------|--------------|----------------|
| 2-year | [val]% | [+/-]bp | [+/-]bp | [+/-]bp |
| 5-year | [val]% | [+/-]bp | [+/-]bp | [+/-]bp |
| 10-year | [val]% | [+/-]bp | [+/-]bp | [+/-]bp |
| 30-year | [val]% | [+/-]bp | [+/-]bp | [+/-]bp |

| Spread | Value | Change |
|--------|-------|--------|
| 2s10s | [val]bp | [+/-]bp |
| 5s30s | [val]bp | [+/-]bp |
| 10y-Bank Rate | [val]bp | - |

**The curve [bull/bear] [flattened/steepened] on [date].** [Explanation of what's driving the move.]

Regime classification:
- **Bull flattener**: long yields falling faster than short (risk-off, flight to quality)
- **Bear flattener**: short yields rising faster than long (hawkish central bank tightening)
- **Bull steepener**: short yields falling faster than long (dovish pivot, rate cuts expected)
- **Bear steepener**: long yields rising faster than short (inflation fears, supply concerns)

Current regime: **[classification]**. [1-2 sentences explaining why.]
```

**Nelson-Siegel model fit:**
```markdown
## Nelson-Siegel Model

| Parameter | Value | Interpretation | Change vs prior |
|-----------|-------|----------------|-----------------|
| beta0 (Level) | [val] | Long-run yield level | [+/-][val] |
| beta1 (Slope) | [val] | Short-end factor (negative = upward sloping) | [+/-][val] |
| beta2 (Curvature) | [val] | Belly factor (hump/trough) | [+/-][val] |
| tau (Decay) | [val] | Speed of exponential decay | [+/-][val] |

**The level parameter is [val]%, [up/down] [val]bp from [prior period].** [Interpretation of what's driving the level change: global rates, inflation expectations, term premium.]

The slope parameter is [val], indicating [a normally upward-sloping / flat / inverted] curve. The curvature parameter is [val], [indicating a hump at medium maturities / relatively flat curvature].

### Fitted vs Actual (Cheap/Rich Analysis)

| Maturity | Actual | Fitted | Residual | Signal |
|----------|--------|--------|----------|--------|
| 2y | [val]% | [val]% | [+/-]bp | [Cheap/Rich/Fair] |
| 5y | [val]% | [val]% | [+/-]bp | [Cheap/Rich/Fair] |
| 10y | [val]% | [val]% | [+/-]bp | [Cheap/Rich/Fair] |
| 20y | [val]% | [val]% | [+/-]bp | [Cheap/Rich/Fair] |
| 30y | [val]% | [val]% | [+/-]bp | [Cheap/Rich/Fair] |

[Maturities trading >3bp above the fitted curve are "cheap" (undervalued). Below are "rich" (overvalued). This can signal relative value opportunities.]

Reference: Nelson & Siegel (1987), "Parsimonious Modeling of Yield Curves", Journal of Business; Diebold & Li (2006), "Forecasting the Term Structure of Government Bond Yields", Journal of Econometrics.
```

**PCA decomposition:**
```markdown
## Principal Component Analysis

| Component | Variance explained | Interpretation |
|-----------|-------------------|----------------|
| PC1 (Level) | [val]% | Parallel shift in all yields |
| PC2 (Slope) | [val]% | Short and long ends move in opposite directions |
| PC3 (Curvature) | [val]% | Belly moves opposite to wings |
| Total (3 PCs) | [val]% | |

**[val]% of recent curve variation is explained by level moves.** [If PC2 contribution is unusually high: "Slope moves have been more important than usual, consistent with changing monetary policy expectations." If PC3 is elevated: "Curvature moves are significant, potentially reflecting supply/demand imbalances at specific maturities."]

[Attribution of the latest move: "Today's curve shift was primarily a level move ([+/-]bp), with a [flattening/steepening] contribution from the slope factor ([+/-]bp at the long end)."]

Reference: Litterman & Scheinkman (1991), "Common Factors Affecting Bond Returns", Journal of Fixed Income.
```

**Carry and rolldown:**
```markdown
## Carry and Rolldown

Expected excess return by maturity, assuming the curve shape remains unchanged:

| Maturity | Yield | Carry (bp/m) | Rolldown (bp/m) | Total (bp/m) | Total (bp/yr) |
|----------|-------|-------------|----------------|-------------|--------------|
| 2y | [val]% | [val] | [val] | [val] | [val] |
| 5y | [val]% | [val] | [val] | [val] | [val] |
| 10y | [val]% | [val] | [val] | [val] | [val] |
| 30y | [val]% | [val] | [val] | [val] | [val] |

**The best carry+rolldown is at the [X]-year point ([val]bp/month).** [If the curve is flat or inverted, carry may be negative at the front end.]

Carry = yield minus funding rate (Bank Rate [val]%). Rolldown = capital gain from the bond "rolling down" the curve as its remaining maturity shortens (requires an upward-sloping curve). Carry+rolldown is the dominant source of excess return in government bonds when the curve shape is stable.

Reference: Koijen, Moskowitz & Pedersen (2018), "Carry", Journal of Financial Economics.
```

**Forward rates and expectations:**
```markdown
## Forward Rates

| Forward | Rate | Interpretation |
|---------|------|----------------|
| 1y1y | [val]% | Market-implied Bank Rate in 1 year |
| 2y1y | [val]% | Market-implied Bank Rate in 2 years |
| 5y5y | [val]% | Long-run "neutral" rate expectation |
| Current Bank Rate | [val]% | |

**The 5y5y forward rate is [val]%.** This is the market's best estimate of where the "neutral" interest rate settles in the medium term. [If well above Bank Rate: "Markets expect rates to settle significantly above the current level." If near Bank Rate: "Markets see current rates as close to neutral."]

The implied path from forward rates suggests [X] 25bp [cuts/hikes] are priced by year-end, bringing Bank Rate to approximately [val]%.

Important caveat: forward rates embed a term premium (compensation for interest rate risk), so they systematically overpredict future rate increases. They are not pure expectations. The expectations hypothesis consistently fails empirically.
```

**Break-even inflation:**
```markdown
## Break-Even Inflation

| Horizon | Nominal | Real | Break-even |
|---------|---------|------|------------|
| 5-year | [val]% | [val]% | [val]% |
| 10-year | [val]% | [val]% | [val]% |
| 20-year | [val]% | [val]% | [val]% |

**10-year break-even inflation is [val]%.** [Interpretation vs BoE target.]

Caveats:
- UK break-evens are RPI-based. RPI typically runs ~1pp above CPI due to the formula effect. A 3.5% RPI break-even is consistent with approximately 2.5% CPI expectations.
- Break-evens embed an **inflation risk premium** (compensation for inflation uncertainty) that biases them upward.
- They also embed a **liquidity premium** (index-linked gilts are less liquid than conventionals) that biases them downward.
- Both premia are time-varying and unobservable, so break-evens are noisy measures of true inflation expectations.
```

**Recession signal:**
```markdown
## Yield Curve Recession Signal

| Spread | Current | Signal |
|--------|---------|--------|
| 10y-2y | [val]bp | [Positive / Flat / Inverted] |
| 10y-3m | [val]bp | [Positive / Flat / Inverted] |

**The 10-year minus 2-year spread is [val]bp, [positive/inverted].** [If inverted: "An inverted yield curve has preceded every UK and US recession since at least 1968. However, the timing between inversion and recession onset varies (6-24 months), and false positives are possible." If positive: "The curve is not signalling imminent recession risk."]

The 10y-3m spread ([val]bp) is considered the more robust academic predictor (Estrella & Mishkin 1998).

Reference: Estrella & Mishkin (1998), "Predicting U.S. Recessions: Financial Variables as Leading Indicators", Review of Economics and Statistics.
```

**Methodology summary:**
```markdown
**Methodology:** Yield curve data from Bank of England (nominal gilts). Nelson-Siegel fit using nonlinear least squares (Nelson & Siegel 1987). PCA on a matrix of daily yield observations (Litterman & Scheinkman 1991). Carry = yield minus Bank Rate; rolldown from implied forward rates assuming unchanged curve (Koijen et al. 2018). Forward rates extracted from the zero-coupon curve. Break-even inflation = nominal minus real gilt yields (RPI-based, subject to risk and liquidity premia). Analysis via yieldcurves and boe R packages.
```

**References:**
```markdown
## References

- Nelson, C.R. and Siegel, A.F. (1987). "Parsimonious Modeling of Yield Curves." Journal of Business, 60(4), 473-489.
- Svensson, L.E.O. (1994). "Estimating and Interpreting Forward Interest Rates." NBER WP 4871.
- Diebold, F.X. and Li, C. (2006). "Forecasting the Term Structure of Government Bond Yields." Journal of Econometrics, 130, 337-364.
- Litterman, R. and Scheinkman, J. (1991). "Common Factors Affecting Bond Returns." Journal of Fixed Income, 1(1), 54-61.
- Adrian, T., Crump, R.K. and Moench, E. (2013). "Pricing the Term Structure with Linear Regressions." Journal of Financial Economics, 110(1), 110-138.
- Estrella, A. and Mishkin, F.S. (1998). "Predicting U.S. Recessions: Financial Variables as Leading Indicators." Review of Economics and Statistics, 80(1), 45-61.
- Koijen, R.S.J., Moskowitz, T.J. and Pedersen, L.H. (2018). "Carry." Journal of Financial Economics, 127(2), 197-225.
- Anderson, N. and Sleath, J. (2001). "New estimates of the UK real and nominal yield curves." Bank of England Working Paper 126.
- Bank of England. "Yield Curves: Terminology and Concepts."
```

### Step 4: Save and present

Save as `yield-briefing-{date}.md`. Always save `yield-data-{date}.json`.

## Important Rules

- Never use em dashes.
- Never attribute econstack to any individual.
- Every section stands alone.
- Yields in % to 2 decimal places. Spreads and changes in basis points (bp).
- Always classify the curve regime (bull/bear x flattener/steepener). This is the first thing a desk head reads.
- Carry/rolldown: funding rate is Bank Rate unless the user specifies otherwise.
- Forward rates: always caveat the expectations hypothesis failure. Forwards are not forecasts.
- Break-evens: always note RPI basis (~1pp above CPI), inflation risk premium, and liquidity premium.
- PCA: typical variance explained is PC1 ~90%, PC2 ~7%, PC3 ~2%. Flag if materially different.
- Nelson-Siegel: cheap/rich threshold is 3bp (>3bp above fitted = cheap, >3bp below = rich).
- Be specific about dates and data sources.
