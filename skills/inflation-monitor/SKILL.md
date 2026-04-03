---
name: inflation-monitor
description: CPI decomposition, core measures, persistence, and Phillips curve analysis. Uses inflationkit + ons. Interactive section selection.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# /inflation-monitor: Inflation Analysis

Decompose UK inflation into components, compute core and underlying measures, assess persistence, estimate the Phillips curve, and track inflation breadth. Follows the analytical framework used by the Bank of England MPC and the ECB.

**This skill is interactive.** It runs the analysis, shows headline results, then asks what output you need.

## Arguments

```
/inflation-monitor [options]
```

**Examples:**
```
/inflation-monitor
/inflation-monitor --full
/inflation-monitor --focus persistence
```

**Options:**
- `--full` : Skip menu, generate all sections
- `--focus <area>` : Emphasise one area (decomposition, core, persistence, phillips)
- `--client "Name"` : Add "Prepared for"
- `--format pdf` : Branded PDF output

## Prerequisites

R packages: `inflationkit`, `ons`, `boe`. Install with:
```r
install.packages(c("inflationkit", "ons", "boe"))
```

## Instructions

### Step 1: Fetch data and run analysis

```r
library(inflationkit)
library(ons)
library(boe)

# Get CPI data
cpi_headline <- ons_cpi()
cpi_core <- ons_cpi(measure = "core")

# If inflationkit needs component-level data, use its sample data
# or fetch from ONS at the COICOP division level
components <- ik_sample_data("components")  # or fetch live

# Layer 1: Decomposition
decomposition <- ik_decompose(components)

# Layer 2: Core measures
core_trimmed <- ik_core(components, method = "trimmed_mean", trim = 0.15)
core_median <- ik_core(components, method = "weighted_median")
core_exclusion <- ik_core(components, method = "exclusion")
sticky <- ik_sticky_flexible(components)

# Layer 3: Persistence
persistence <- ik_persistence(cpi_headline, method = "sum_ar")
half_life <- ik_persistence(cpi_headline, method = "half_life")

# Layer 4: Breadth
diffusion <- ik_diffusion(components, threshold = "target")

# Layer 5: Trend
trend <- ik_trend(cpi_headline)

# Layer 6: Phillips curve (if unemployment data available)
unemployment <- ons_unemployment()
phillips <- ik_phillips(cpi_headline, unemployment)

# Layer 7: Break-even inflation
yield_data <- boe_yield_curve()
breakeven <- ik_breakeven(yield_data)
```

Extract latest values from each analysis.

### Step 2: Show results and ask what the user needs

```
INFLATION MONITOR
==================
CPI (annual):             [val]%    (prev: [val]%)
Core CPI (exclusion):     [val]%
Trimmed mean (15%):       [val]%
Weighted median:          [val]%
Services CPI:             [val]%
Goods CPI:                [val]%

Diffusion (>2% target):   [val]% of items
Persistence (sum AR):     [val]   (half-life: [val] months)
Phillips slope:           [val]

Largest contributor:      [component] ([val]pp)
Largest drag:             [component] ([val]pp)
```

**If `--full` was NOT specified**, ask using AskUserQuestion:

Question: "What output do you need?"

Options:
- A) **Full analysis** : All 7 layers
- B) **Pick sections** : Choose which analyses
- C) **Summary table** : Headline + core measures comparison
- D) **Data only** : JSON

**If user picks B** (multiSelect: true):

Options:
- Headline decomposition (COICOP contributions to annual rate)
- Core inflation measures (trimmed mean, weighted median, exclusion, comparison)
- Sticky vs flexible prices (Bryan-Meyer decomposition)
- Persistence assessment (AR coefficients, half-life, trend)
- Inflation breadth / diffusion index
- Phillips curve (output-inflation tradeoff estimate)
- Break-even inflation (market-implied expectations from gilts)
- Methodology summary (one paragraph)
- References

### Step 3: Generate the requested output

**Always include key numbers block and companion JSON.**

#### Section templates

**Headline decomposition:**
```markdown
## CPI Decomposition

**CPI inflation [rose/fell] to [val]% in [month], [down/up] from [val]%.** The [largest contributor component] contributed [val]pp to the annual rate, while [largest drag] subtracted [val]pp.

| Component | Weight | Annual rate | Contribution |
|-----------|--------|-------------|-------------|
| Food and non-alcoholic beverages | [val] | [val]% | [val]pp |
| Alcoholic beverages and tobacco | [val] | [val]% | [val]pp |
| Clothing and footwear | [val] | [val]% | [val]pp |
| Housing, water, energy, fuels | [val] | [val]% | [val]pp |
| Furniture and household | [val] | [val]% | [val]pp |
| Health | [val] | [val]% | [val]pp |
| Transport | [val] | [val]% | [val]pp |
| Communication | [val] | [val]% | [val]pp |
| Recreation and culture | [val] | [val]% | [val]pp |
| Education | [val] | [val]% | [val]pp |
| Restaurants and hotels | [val] | [val]% | [val]pp |
| Miscellaneous | [val] | [val]% | [val]pp |
| **All items CPI** | **1000** | **[val]%** | **[val]pp** |

The decomposition reveals [whether inflation is broad-based or concentrated in a few components]. Services inflation ([val]%) remains [elevated/moderate/subdued] relative to goods ([val]%).
```

**Core inflation measures:**
```markdown
## Core Inflation Measures

| Measure | Value | Signal |
|---------|-------|--------|
| Headline CPI | [val]% | Full basket |
| Core (ex food, energy, alcohol, tobacco) | [val]% | ONS standard exclusion |
| Trimmed mean (15%) | [val]% | Robust to outliers (ONS methodology) |
| Weighted median | [val]% | Middle of the price change distribution |
| Services CPI | [val]% | Domestic demand pressure |
| Goods CPI | [val]% | Global/tradeable prices |

**The trimmed mean ([val]%) and weighted median ([val]%) [converge at/diverge from] the headline rate.** [If trimmed mean < headline: "This suggests the headline is being pushed up by a small number of items with outsized price changes, rather than broad-based pressure."] [If trimmed mean > headline: "This suggests some items with large price falls are masking broader underlying pressure."]

[Compare to BoE 2% target: are underlying measures trending toward or away from target?]
```

**Sticky vs flexible prices:**
```markdown
## Sticky vs Flexible Prices

**Sticky-price inflation is [val]%, while flexible-price inflation is [val]%.** Sticky prices (items that change infrequently, such as rents, education, insurance) are a better gauge of underlying demand pressure because they reflect forward-looking pricing decisions.

[If sticky > flexible: "Sticky-price inflation running above flexible suggests demand-driven pressure that may take time to unwind."]
[If flexible > sticky: "Higher flexible-price inflation suggests supply-side or commodity-driven pressure, which tends to be more transitory."]

Based on the methodology of Bryan and Meyer (Atlanta Fed), adapted for UK COICOP classifications.
```

**Persistence assessment:**
```markdown
## Inflation Persistence

| Measure | Value | Interpretation |
|---------|-------|----------------|
| Sum of AR coefficients | [val] | [Near 1 = very persistent / 0.5-0.8 = moderately persistent / < 0.5 = transitory] |
| Half-life | [val] months | Time for a 1pp shock to halve |
| Largest AR root | [val] | Dominant persistence factor |

**Inflation persistence is currently [high/moderate/low].** A 1 percentage point shock to CPI takes approximately [val] months to halve, [compared to a pre-pandemic (2015-2019) average of approximately X months].

[If persistence > 0.8: "This is consistent with inflation expectations becoming partially de-anchored, or with second-round effects (wage-price feedback) sustaining price pressure."]
[If persistence < 0.5: "This suggests inflation shocks are dissipating relatively quickly, consistent with well-anchored expectations."]

Reference: Marques (2004), "Inflation persistence: facts or artefacts?", ECB Working Paper 371.
```

**Inflation breadth / diffusion:**
```markdown
## Inflation Breadth

**[val]% of CPI items (by weight) have inflation above the 2% target.** [If > 60%: "Inflation is broad-based, with a majority of items experiencing above-target price growth."] [If 40-60%: "Inflation breadth is moderate."] [If < 40%: "Inflation is concentrated in a minority of items."]

High breadth (>60%) tends to be associated with more persistent inflation, because it indicates generalised pricing pressure rather than sector-specific shocks. The diffusion index peaked at [val]% in [month/year] during the post-pandemic surge.

Reference: Almuzara and Rosner (2024), "A New Indicator of Inflation Breadth", FEDS Notes.
```

**Phillips curve:**
```markdown
## Phillips Curve

**The estimated Phillips curve slope is [val].** A 1 percentage point increase in the unemployment gap is associated with a [val] percentage point [decrease/increase] in CPI inflation.

| Parameter | Estimate | Std. Error |
|-----------|----------|------------|
| Constant | [val] | [val] |
| Slack (unemployment gap) | [val] | [val] |
| Lagged inflation | [val] | [val] |

[If slope near 0: "The Phillips curve is flat, meaning changes in labour market slack have limited effect on inflation through the demand channel. This is consistent with the post-GFC experience across advanced economies (Blanchard 2016)."]
[If slope significantly negative: "The Phillips curve has steepened, suggesting monetary policy tightening (which increases unemployment) is effective at reducing inflation."]

Standard errors computed using Newey-West HAC to account for autocorrelation.

References: Blanchard (2016), "The Phillips Curve: Back to the '60s?"; Hazell et al. (2022), "The Slope of the Phillips Curve: Evidence from U.S. States", QJE.
```

**Break-even inflation:**
```markdown
## Break-Even Inflation

| Horizon | Nominal yield | Real yield | Break-even |
|---------|-------------|-----------|------------|
| 5-year | [val]% | [val]% | [val]% |
| 10-year | [val]% | [val]% | [val]% |
| 20-year | [val]% | [val]% | [val]% |

**Market-implied inflation expectations at the 10-year horizon are [val]%.** [Interpretation vs 2% target.]

Important caveats: UK break-evens are RPI-based (typically ~1pp above CPI equivalent due to the formula effect). They also embed an inflation risk premium and a liquidity premium (index-linked gilts are less liquid), both of which are time-varying. These are not pure measures of inflation expectations.

Data from Bank of England yield curve estimates.
```

**Methodology summary (one paragraph):**
```markdown
**Methodology:** CPI decomposition by COICOP division with weighted contributions. Core measures: 15% symmetric trimmed mean (ONS methodology), weighted median, and exclusion-based (ex food, energy, alcohol, tobacco). Persistence via AR(p) sum of coefficients and half-life (Marques 2004). Breadth via weighted diffusion index against the 2% target (Almuzara and Rosner 2024). Phillips curve: hybrid specification with Newey-West HAC standard errors. Sticky/flexible decomposition per Bryan and Meyer (Atlanta Fed). Data from ONS CPI (D7G7) and Bank of England. Analysis via inflationkit.
```

**References:**
```markdown
## References

- Bryan, M. and Cecchetti, S. (1994). "Measuring Core Inflation." In Mankiw, N.G. (ed.), Monetary Policy. University of Chicago Press.
- Bernanke, B. and Blanchard, O. (2023). "What Caused the U.S. Pandemic-Era Inflation?" Brookings Papers on Economic Activity.
- Blanchard, O. (2016). "The Phillips Curve: Back to the '60s?" AEA Papers and Proceedings.
- Marques, C. (2004). "Inflation persistence: facts or artefacts?" ECB Working Paper 371.
- Hazell, J., Herre, J., Nakamura, E. and Steinsson, J. (2022). "The Slope of the Phillips Curve: Evidence from U.S. States." QJE, 137(3).
- Stock, J. and Watson, M. (2019). "Slack and Cyclically Sensitive Inflation."
- Almuzara, M. and Rosner, G. (2024). "A New Indicator of Inflation Breadth." FEDS Notes.
- Bils, M. and Klenow, P. (2004). "Some Evidence on the Importance of Sticky Prices." JPE.
- Mankikar, A. and Paisley, J. (2004). "Core Inflation: A Critical Guide." Bank of England Working Paper.
```

### Step 4: Save and present

Save as `inflation-monitor-{date}.md`. Always save `inflation-data-{date}.json`.

If `--format pdf`, render through template.

## Important Rules

- Never use em dashes.
- Never attribute econstack to any individual.
- Every section stands alone.
- Services CPI is the indicator the MPC watches most closely for domestic inflation pressure. Always report it.
- Target-consistent: compare core measures to the 2% target, not just to each other.
- Persistence interpretation: sum of AR coefficients near 1 = very persistent, < 0.5 = transitory.
- Half-life should be in months, not abstract units.
- Phillips curve: always use HAC standard errors, always note the slope interpretation.
- Break-even caveats: always note RPI basis, inflation risk premium, and liquidity premium.
- Be specific about dates and data vintages.
- The companion JSON must include every computed value.
