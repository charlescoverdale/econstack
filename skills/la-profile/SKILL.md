---
name: la-profile
description: Generate a professional local authority economic profile report.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Agent
---

# /la-profile: Local Authority Economic Profile

Generate a professional, client-ready economic profile for any UK local authority. Pulls together demographics, labour market, earnings, industry structure, housing, business activity, deprivation, skills, and commuting data into a single coherent briefing.

## When to use

- A client asks "give me an economic overview of [area]"
- A local authority needs a briefing pack for an inward investment pitch
- A consultancy needs baseline data for a project in a specific area
- You need to understand a local economy before building a business case

## Arguments

```
/la-profile <local_authority> [options]
```

**Examples:**
```
/la-profile Manchester
/la-profile Glasgow City
/la-profile Isle of Anglesey --brief
/la-profile Leeds --compare Birmingham
```

**Options:**
- `--brief` : Executive summary only (1-2 pages, key stats and headline findings)
- `--compare <LA>` : Include a side-by-side comparison with another LA
- `--focus labour` : Emphasise labour market and skills sections
- `--focus housing` : Emphasise housing and affordability sections
- `--focus business` : Emphasise business activity and industry structure
- `--format pdf` : Generate Quarto PDF (default: markdown)

## Instructions

### Step 1: Parse the request

Extract:
- **local_authority**: The LA name or slug
- **compare_la**: Optional second LA for comparison
- **focus**: Optional emphasis area (labour, housing, business)
- **brief**: Boolean, executive summary only
- **format**: markdown (default) or pdf

### Step 2: Load data

All data lives in the econprofile data directory. Load all available files for the LA.

```bash
LA_SLUG="manchester"  # derived from LA name
DATA_DIR="/Users/charlescoverdale/Documents/2026/Claude/Sandbox/econprofile/src/data"

# Core files (always available)
cat "$DATA_DIR/${LA_SLUG}/summary.json"
cat "$DATA_DIR/${LA_SLUG}/employment.json"
cat "$DATA_DIR/${LA_SLUG}/earnings.json"
cat "$DATA_DIR/${LA_SLUG}/housing.json"
cat "$DATA_DIR/${LA_SLUG}/population.json"

# Extended files (may not exist for all LAs)
cat "$DATA_DIR/${LA_SLUG}/gva.json" 2>/dev/null
cat "$DATA_DIR/${LA_SLUG}/industry.json" 2>/dev/null
cat "$DATA_DIR/${LA_SLUG}/deprivation.json" 2>/dev/null
cat "$DATA_DIR/${LA_SLUG}/business.json" 2>/dev/null
cat "$DATA_DIR/${LA_SLUG}/skills.json" 2>/dev/null
cat "$DATA_DIR/${LA_SLUG}/commuting.json" 2>/dev/null
cat "$DATA_DIR/${LA_SLUG}/business-demography.json" 2>/dev/null
cat "$DATA_DIR/${LA_SLUG}/benchmarks.json" 2>/dev/null

# National benchmarks
cat "$DATA_DIR/national-benchmarks.json"
```

If the LA slug is not found:
```bash
ls "$DATA_DIR/" | grep -i "<search_term>"
```

Determine the LA's country from its ONS code prefix:
- E = England
- S = Scotland
- W = Wales

Use the matching country benchmark from national-benchmarks.json throughout.

### Step 3: Analyse the data

Before writing, compute key derived metrics:

**Labour market:**
- Employment density = totalEmployment / midYearPopulation
- Top 3 sectors by employment share
- Top 3 specialised sectors (highest LQ, where LQ > 1.25)
- Earnings vs country median (% above/below)
- Earnings inequality: p90/p10 ratio
- Gender pay gap: male vs female median, gap %

**Housing:**
- Affordability: price-to-earnings ratio
- Price trend: latest year change %
- Tenure split: owned vs rented vs social (compare to national)

**Business:**
- Enterprise density per capita (if population available)
- Micro business share (0-4 employees as % of total)
- Business birth/death rates (if business-demography data available)

**Skills:**
- Highest-share occupation group
- NVQ4+ qualification rate vs national (if available)
- Commuting patterns: WFH %, dominant mode

**Deprivation:**
- IMD rank out of total, percentile
- Worst-performing domain

**Productivity:**
- GVA per job vs national
- Rank out of 391

### Step 4: Generate the report

Write the report using this structure. Omit sections where data is not available. Do not invent data.

```markdown
# Economic Profile: [LA Name]

**Prepared by:** EconStack
**Date:** [today's date]
**Data sources:** ONS, BRES, ASHE, DLUHC, Nomis, Census 2021
**Country:** England / Scotland / Wales

---

## At a Glance

| Indicator | [LA Name] | [Country] avg | GB avg |
|-----------|-----------|---------------|--------|
| Population | [val] | - | - |
| Workplace jobs | [val] | - | - |
| Median earnings | [val] | [val] | [val] |
| Claimant rate | [val]% | [val]% | [val]% |
| GVA per job | [val] | [val] | [val] |
| Median house price | [val] | [val] | [val] |
| Price-to-earnings | [val]x | - | - |
| Working-age % | [val]% | [val]% | [val]% |

## 1. Summary

[3-4 paragraph narrative overview. Open with the population and location context. Cover the economy's main characteristics: what kind of place is this? Service-dominated? Manufacturing heritage? Public sector dependent? Growing or declining? Affluent or deprived? What are the standout features?

Write for a reader who knows nothing about this area. Be specific: "Manchester's economy is dominated by professional services, health, and education, with 451,000 workplace jobs and a claimant rate of 6.0%, nearly double the England average of 3.6%." Not: "Manchester has a diverse economy."

Compare to the LA's own country average (England/Scotland/Wales), not just GB.]

## 2. Demographics and Population

- Mid-year population estimate: [val] ([year])
- Male/female split: [val] / [val]
- Working-age (16-64): [val]% (country avg: [val]%)
- Population change (5yr): [val]% (country avg: [val]%)
- Population trend: [growing/declining/stable] since [year]

[1-2 sentences interpreting. Is the population young and growing, or ageing and shrinking? How does the working-age share compare?]

## 3. Labour Market

### 3.1 Employment

- Total workplace jobs: [val]
- Claimant rate: [val]% (country avg: [val]%, rank [X] of [Y])

### 3.2 Industry Structure

Top 5 sectors by employment:

| Sector | Jobs | Local share | National share | Specialisation (LQ) |
|--------|------|-------------|----------------|---------------------|
| [sector] | [val] | [val]% | [val]% | [val] |
| ... | ... | ... | ... | ... |

**Specialised sectors** (LQ > 1.25): [list sectors where the area has notably higher concentration than national average]

**Under-represented sectors** (LQ < 0.5): [list]

[2-3 sentences interpreting. What does the industry structure tell us about this economy? Is it diversified or dependent on a few sectors? Are the specialised sectors growing or declining nationally?]

### 3.3 Shift-share Analysis

[If industry.json has shift-share data:]

Which sectors gained or lost jobs faster than the national trend:

| Sector | Actual change | National trend | Local competitiveness |
|--------|--------------|----------------|----------------------|
| [winners] | +[val] | [val] | +[val] |
| [losers] | -[val] | [val] | -[val] |

## 4. Earnings and Income

- Median annual earnings (workplace): [val] ([year])
- Country median: [val] ([X]% above/below)
- GB median: [val]

### Earnings Distribution

| Percentile | [LA Name] | England |
|------------|-----------|---------|
| p10 (low earners) | [val] | [val] |
| p25 | [val] | [val] |
| p50 (median) | [val] | [val] |
| p75 | [val] | [val] |
| p90 (high earners) | [val] | [val] |

- 90/10 ratio: [val] (England: [val]). [Interpretation: higher ratio = more inequality]

### Gender Pay Gap

- Male median: [val]
- Female median: [val]
- Gap: [val]% (England gap: [val]%)

[1-2 sentences. Is the gap wider or narrower than national?]

## 5. Housing and Affordability

- Median house price: [val] ([year change]% year-on-year)
- Country median: [val]
- Price-to-earnings ratio: [val]x
- Total households: [val]

### Tenure Breakdown

| Tenure | [LA Name] | England |
|--------|-----------|---------|
| Owned outright | [val]% | [val]% |
| Owned with mortgage | [val]% | [val]% |
| Social rented | [val]% | [val]% |
| Private rented | [val]% | [val]% |

[2-3 sentences. Is this area affordable? How does tenure split differ from national, and what does that indicate about the local housing market?]

## 6. Business Activity

[If business.json available:]

- Total enterprises: [val]
- Micro (0-4 employees): [val]% of total (England: [val]%)
- Small (5-49): [val]%
- Medium (50-249): [val]%
- Large (250+): [val]%

[If business-demography.json available:]

- Business birth rate: [val]%
- Business death rate: [val]%
- Net formation rate: [val]%

[1-2 sentences. Is this an entrepreneurial area? How does the business size distribution compare?]

## 7. Productivity

[If gva.json available:]

- GVA per job: [val] (national: [val])
- Rank: [X] of [Y] local authorities
- [X]% above/below national average

Largest GVA sectors:

| Sector | GVA | Share of total |
|--------|-----|----------------|
| [sector] | [val] | [val]% |
| ... | ... | ... |

[1-2 sentences interpreting.]

## 8. Deprivation

[If deprivation.json available:]

- IMD rank: [X] of [Y] (1 = most deprived)
- IMD score: [val]

Domain-level:

| Domain | Rank | Percentile |
|--------|------|------------|
| Income | [val] | [val]% |
| Employment | [val] | [val]% |
| Education | [val] | [val]% |
| Health | [val] | [val]% |
| Crime | [val] | [val]% |
| Housing & Services | [val] | [val]% |
| Living Environment | [val] | [val]% |

[1-2 sentences. Which domains are most challenging?]

## 9. Skills and Commuting

[If skills.json available:]

### Occupations

| Occupation group | [LA Name] | England |
|------------------|-----------|---------|
| Managers & directors | [val]% | [val]% |
| Professional | [val]% | [val]% |
| Associate professional | [val]% | [val]% |
| ... | ... | ... |

[If commuting.json available:]

### Commuting

- Work from home: [val]% (England: [val]%)
- Dominant commute mode: [mode] ([val]%)

## 10. Comparison with [Country] and GB

[Pull from national-benchmarks.json. Show where this LA sits relative to its country average and GB for each key metric. Use the same format as the econprofile benchmark section: metric, local value, country avg, and "X% above/below" or "Xpp higher/lower" for percentages.]

| Metric | [LA Name] | [Country] | GB | vs [Country] |
|--------|-----------|-----------|-----|-------------|
| Median earnings | [val] | [val] | [val] | [X]% above/below |
| House price | [val] | [val] | [val] | [X]% above/below |
| Claimant rate | [val]% | [val]% | [val]% | [X]pp higher/lower |
| GVA per job | [val] | [val] | [val] | [X]% above/below |
| Working-age % | [val]% | [val]% | [val]% | [X]pp higher/lower |

---

## Data Sources

- **Employment:** Business Register and Employment Survey (BRES), via Nomis. Workplace-based employee counts by SIC section.
- **Earnings:** Annual Survey of Hours and Earnings (ASHE), via Nomis. Workplace-based gross annual pay for full-time employees.
- **Population:** ONS Mid-Year Population Estimates.
- **Housing:** HM Land Registry Price Paid Data, via DLUHC. Tenure from Census 2021.
- **GVA:** Estimated using national GVA-per-job ratios applied to local sector employment. Indicative only.
- **Deprivation:** English Indices of Deprivation 2019 (MHCLG).
- **Skills & Commuting:** Census 2021, via Nomis.
- **Business:** ONS UK Business Counts and Business Demography.
- **National benchmarks:** Computed from local authority-level data (see econprofile.com methodology).

*Data powered by econprofile.com. All data from official UK government open sources.*
```

### Step 5: Comparison mode

If `--compare <LA>` was specified, load data for the second LA and add a comparison section after each main section. Use a two-column table format:

```markdown
| Metric | [LA1] | [LA2] |
|--------|-------|-------|
| ... | ... | ... |
```

End with a "Key Differences" paragraph highlighting the 3-4 most notable contrasts.

### Step 6: Save and present

Save the report as `la-profile-{slug}-{date}.md` in the current working directory.

**If `--format pdf` was specified**, also render as a branded PDF:

```bash
ECONSTACK_DIR="${CLAUDE_SKILL_DIR}/../.."
"$ECONSTACK_DIR/scripts/render-report.sh" la-profile-{slug}-{date}.md \
  --title "Economic Profile: {LA Name}" \
  --subtitle "{Country} | Data from ONS, BRES, ASHE, DLUHC"
```

If the render script is not found at the expected path, try `~/.claude/skills/econstack/scripts/render-report.sh`. If Quarto is not installed, tell the user: "PDF rendering requires Quarto (https://quarto.org). The markdown report has been saved."

Present a concise summary to the user:

```
LA PROFILE GENERATED
====================
Area:              [LA name]
Country:           [England/Scotland/Wales]
Population:        [val]
Workplace jobs:    [val]
Median earnings:   [val] ([X]% vs country avg)
Claimant rate:     [val]%
GVA per job:       [val] (rank [X]/[Y])
House price:       [val] (affordability [X]x earnings)
IMD rank:          [X] of [Y]

Report saved: la-profile-{slug}-{date}.md
PDF saved:    la-profile-{slug}-{date}.pdf (if --format pdf)
```

## Important Rules

- Never use em dashes. Use colons, periods, commas, or parentheses.
- Never connect econprofile or econstack to any individual person. Present as brands/products.
- Only report data that exists in the JSON files. Never invent or extrapolate data.
- If a data file is missing for the LA, omit that section entirely. Do not leave placeholder text.
- Always show comparisons to the LA's own country (England/Scotland/Wales), not just England.
- Use "workplace-based" when describing employment and earnings (these are where people work, not where they live).
- Currency in GBP with commas. Jobs as whole numbers.
- LQ interpretation: >1.25 = specialised, 0.75-1.25 = average, <0.75 = under-represented. >2.0 = highly specialised.
- Percentile interpretation for earnings: p10 is the low end, p90 is the high end, p50 is the median.
- IMD interpretation: rank 1 = most deprived, lower rank = more deprived. Only available for English LAs.
- Price-to-earnings: <5x is affordable, 5-8x is moderate, 8-12x is expensive, >12x is severely unaffordable.
- The narrative should tell a story about the local economy, not just list numbers. What kind of place is this? What are its strengths and challenges?
