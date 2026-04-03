---
name: impact-report
description: Generate a professional economic impact assessment report using regional input-output multipliers.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Agent
  - WebSearch
  - WebFetch
---

# /impact-report: Economic Impact Assessment

Generate a professional, client-ready economic impact assessment for an investment or job creation in any UK local authority. Uses regional input-output multipliers with FLQ regionalization, additionality adjustments per HM Treasury Green Book guidance, and full methodology documentation.

## When to use

- A client asks "what's the economic impact of our £X investment in [area]?"
- A local authority needs an impact estimate for a business case or funding bid
- A consultancy needs a quick-turnaround impact assessment with proper methodology

## Arguments

```
/impact-report <amount> in <sector> in <local_authority> [options]
```

**Examples:**
```
/impact-report £10m in Manufacturing in Manchester
/impact-report 500 jobs in Construction in Glasgow
/impact-report £25m in Financial & Insurance in City of London --type2
/impact-report £5m in Accommodation & Food in Brighton and Hove --conservative
```

**Options:**
- `--type2` : Include household spending (induced) effects (default: Type I only)
- `--conservative` : Use conservative additionality (35% deadweight, 40% displacement, 20% leakage)
- `--optimistic` : Use optimistic additionality (10% deadweight, 10% displacement, 5% leakage)
- `--no-additionality` : Report gross figures only (no deadweight/displacement/leakage adjustment)
- `--format pdf` : Generate Quarto PDF (default: markdown report)
- `--format pptx` : Generate PowerPoint summary
- `--brief` : Executive summary only (1 page)

## How it works

1. Loads the multiplier data for the specified local authority from econprofile data
2. Runs the IO model computation (same methodology as econprofile.com/impact)
3. Applies additionality adjustments (HM Treasury defaults or user-specified)
4. Generates a structured report with: executive summary, methodology, results, sensitivity analysis, caveats, and references
5. Outputs as markdown (default), PDF, or PPTX

## Instructions

### Step 1: Parse the request

Extract from the user's input:
- **amount**: The investment in GBP, or number of direct jobs
- **input_type**: "output" (investment in GBP) or "jobs" (direct job creation)
- **sector**: One of the 19 SIC sections (Agriculture, Mining & Quarrying, Manufacturing, Electricity & Gas, Water & Waste, Construction, Wholesale & Retail, Transportation, Accommodation & Food, Information & Communication, Financial & Insurance, Real Estate, Professional & Scientific, Administrative & Support, Public Administration, Education, Health & Social Work, Arts & Recreation, Other Services)
- **local_authority**: The LA name or slug
- **multiplier_type**: "typeI" (default) or "typeII" (if --type2 flag)
- **additionality**: "standard" (default), "conservative", "optimistic", or "none"
- **format**: "markdown" (default), "pdf", or "pptx"

If the sector doesn't exactly match one of the 19 SIC sections, use your best judgement to map it. For example:
- "tech" or "software" -> "Information & Communication"
- "hospitality" or "hotels" -> "Accommodation & Food"
- "banking" or "finance" -> "Financial & Insurance"
- "pharma" or "chemicals" -> "Manufacturing"
- "logistics" or "shipping" -> "Transportation"
- "housing" or "development" -> "Construction"

If the local authority name is ambiguous, search the econprofile data directory for the closest match.

### Step 2: Load multiplier data

```bash
# Find the LA's multiplier data
LA_SLUG="manchester"  # derived from LA name
cat /Users/charlescoverdale/Documents/2026/Claude/Sandbox/econprofile/src/data/${LA_SLUG}/multipliers.json
```

Also load the LA's summary data for context:
```bash
cat /Users/charlescoverdale/Documents/2026/Claude/Sandbox/econprofile/src/data/${LA_SLUG}/summary.json
```

And the national benchmarks:
```bash
cat /Users/charlescoverdale/Documents/2026/Claude/Sandbox/econprofile/src/data/national-benchmarks.json
```

If the LA slug is not found, search:
```bash
ls /Users/charlescoverdale/Documents/2026/Claude/Sandbox/econprofile/src/data/ | grep -i "<search_term>"
```

### Step 3: Compute the impact

Use the same methodology as econprofile's ImpactCalculator. The computation is:

**If input is investment (GBP):**
```
directOutput = amount
directJobs = (amount / 1,000,000) * directEmploymentPerMillion
```

**If input is jobs:**
```
directJobs = amount
directOutput = (amount / directEmploymentPerMillion) * 1,000,000
```

**Type I totals:**
```
totalOutput = directOutput * outputMultiplier
indirectOutput = totalOutput - directOutput
totalJobs = directJobs * employmentMultiplier
indirectJobs = totalJobs - directJobs
```

**Type II (if requested):**
```
totalOutputII = directOutput * outputMultiplierTypeII
inducedOutput = totalOutputII - totalOutputI
totalJobsII = directJobs * employmentMultiplierTypeII
inducedJobs = totalJobsII - totalJobsI
```

**Expanded outputs:**
```
gvaImpact = totalOutput * gvaToOutputRatio
earningsImpact = totalJobs * averageEarningsPerJob
estimatedIncomeTax = earningsImpact * 0.20
estimatedNICs = earningsImpact * 0.218
estimatedVAT = earningsImpact * 0.35 * 0.20
totalTax = estimatedIncomeTax + estimatedNICs + estimatedVAT
```

**Additionality adjustment:**
```
Standard:      deadweight=20%, displacement=25%, leakage=10%, substitution=0%
Conservative:  deadweight=35%, displacement=40%, leakage=20%, substitution=5%
Optimistic:    deadweight=10%, displacement=10%, leakage=5%,  substitution=0%

additionalityFactor = (1 - deadweight/100) * (1 - displacement/100) * (1 - leakage/100) * (1 - substitution/100)
netOutput = totalOutput * additionalityFactor
netJobs = totalJobs * additionalityFactor
```

### Step 4: Generate the report

Write the report to a file in the current working directory. Use the following structure:

```markdown
# Economic Impact Assessment: [Investment Description]

**Prepared by:** EconStack
**Date:** [today's date]
**Local authority:** [LA name]
**Methodology:** Regional input-output model (FLQ regionalization)

---

## Executive Summary

[2-3 paragraph summary of the key findings. Include: total output, total jobs, GVA contribution, net additional impact after additionality. Written for a non-technical reader. No jargon.]

## 1. Investment Parameters

| Parameter | Value |
|-----------|-------|
| Investment / Direct jobs | [amount] |
| Sector | [sector] |
| Local authority | [LA name] |
| Multiplier type | Type I / Type II |
| Output multiplier | [value]x |
| Employment multiplier | [value]x |

## 2. Gross Impact Estimates

### 2.1 Output and Employment

| Impact | Direct | Indirect (supply chain) | [Induced (household)] | Total |
|--------|--------|------------------------|----------------------|-------|
| Economic output (GBP) | [val] | [val] | [val] | [val] |
| Employment (jobs) | [val] | [val] | [val] | [val] |

### 2.2 GVA and Fiscal Effects

| Metric | Value |
|--------|-------|
| GVA contribution | [val] |
| Earnings impact | [val] |
| Estimated income tax | [val] |
| Estimated NICs | [val] |
| Estimated VAT | [val] |
| **Estimated total tax** | **[val]** |

*Tax estimates are rough approximations based on sector-average earnings and standard rates. Margin of error: 30-50%. See methodology for details.*

### 2.3 Interpretation

[For every pound of direct spending, an additional Xp circulates through the local economy via supply chain purchases. The [sector] sector in [LA] has an output multiplier of [X]x, meaning...]

## 3. Additionality Adjustment

Not all estimated impact is genuinely new. The following adjustments are applied based on HM Treasury Additionality Guide (4th edition, 2014) and MHCLG Appraisal Guide (3rd edition, 2025).

| Adjustment | Rate | Rationale |
|------------|------|-----------|
| Deadweight | [X]% | Activity that would have occurred without the intervention |
| Displacement | [X]% | Activity shifted from other businesses or areas |
| Leakage | [X]% | Benefits flowing outside the target area |
| Substitution | [X]% | Firms replacing one activity with another |
| **Net additionality factor** | **[X]%** | |

### 3.1 Net Additional Impact

| Metric | Gross | Net additional |
|--------|-------|----------------|
| Economic output | [val] | [val] |
| Employment | [val] jobs | [val] jobs |
| GVA | [val] | [val] |

## 4. Sensitivity Analysis

How results change with +/- 15% variation in the output multiplier:

| Scenario | Output multiplier | Total output | Total jobs |
|----------|-------------------|--------------|------------|
| Low (-15%) | [val]x | [val] | [val] |
| **Central** | **[val]x** | **[val]** | **[val]** |
| High (+15%) | [val]x | [val] | [val] |

## 5. Why [LA Name]'s Multiplier is [X]x

[Explain why this specific area has this multiplier. Reference the lambda value, what it means about the local economy's self-sufficiency, and how it compares to other areas.]

Lambda (regional size parameter) for [LA] is [val]. [Interpretation based on lambda value.]

Lambda is computed as [log2(1 + RE/NE)]^delta, where RE is total local employment (BRES) and NE is total national employment. The geography used is the local authority district boundary.

## 6. Local Economic Context

[Pull key stats from the LA's summary data: total employment, median earnings, claimant rate. Compare to national benchmarks. 2-3 sentences providing context for the impact estimate.]

## 7. Methodology

### 7.1 Input-Output Model

This assessment uses a regional input-output (IO) model derived from the ONS Input-Output Analytical Tables (2023), published as part of Blue Book 2025. The national technical coefficients matrix at 104 industries is aggregated to 19 SIC sections using output-weighted averaging. This matrix is regionalized using the Flegg Location Quotient (FLQ) method (Flegg et al. 1995), which adjusts national coefficients to reflect the local economy's sectoral structure and size.

The Leontief inverse of the regionalized matrix yields Type I multipliers, capturing direct effects (the initial expenditure) and indirect effects (supply chain purchases from local firms). [If Type II: The matrix is augmented with a household row and column representing the wage-consumption loop, yielding Type II multipliers that additionally capture induced effects.]

Employment multipliers are derived by weighting the Leontief inverse columns by sector-level employment intensity (jobs per million pounds of output), sourced from BRES via Nomis.

### 7.2 Technical Parameters

| Parameter | Value |
|-----------|-------|
| Data source | ONS Input-Output Analytical Tables, 2023 (Blue Book 2025) |
| Sector classification | 19 SIC sections (A-S), aggregated from 104 industries |
| Regionalization method | Flegg Location Quotient (FLQ) |
| FLQ delta parameter | 0.3 (Flegg et al. 1995, Bonfiglio & Chelli 2008) |
| Lambda for [LA] | [val] |
| Multiplier type | Type I [or Type II] |
| Additionality source | HM Treasury Additionality Guide (4th edition, 2014); MHCLG Appraisal Guide (3rd edition, 2025) |

### 7.3 Additionality Framework

The additionality adjustments follow the HM Treasury Additionality Guide (BIS, 2009; updated 2014) and are consistent with the MHCLG Appraisal Guide (3rd edition, 2025). These reflect typical findings from evaluations of economic development interventions across the UK.

- **Deadweight:** The proportion of activity that would have occurred without the intervention. Green Book guidance range: 0-40%.
- **Displacement:** Activity shifted from other businesses or areas rather than genuinely new. Range: 0-75%. Higher for retail/leisure, lower for export-oriented sectors.
- **Leakage:** Benefits flowing outside the target area. Range: 5-50%, depending on area size.
- **Substitution:** Firms replacing one activity with another. Typically low for investment-driven interventions.

## 8. Important Caveats

- **Spare capacity assumed.** The model assumes the local economy can absorb additional demand. In a tight labour market, actual impacts may be smaller.
- **Fixed input proportions.** If input prices change, the model still assumes the same quantities. No substitution or efficiency gains are captured.
- **No price effects.** Large investments can push up local wages and costs, reducing net benefit.
- **Data vintage.** Based on 2023 economic structure (ONS Blue Book 2025). The economy continues to evolve.
- **Sector aggregation.** The 19-sector classification averages sub-industries with very different characteristics. A specific investment may have a higher or lower multiplier than the sector average suggests.
- **Tax estimates are rough approximations** based on sector-average earnings and standard rates. Margin of error: 30-50%.
- **LA boundaries are administrative, not economic.** Commuting, supply chains, and spending cross LA boundaries. Impacts may spill into neighbouring areas.
- **IO multipliers are generally considered indicative upper bounds.** Econometric evidence from the What Works Centre for Local Economic Growth suggests real-world local employment multipliers are often lower than IO estimates.
- These are indicative estimates, not formal economic impact assessments. For investment decisions exceeding £50m, consider commissioning a bespoke Computable General Equilibrium (CGE) model or econometric study.

## 9. References

- ONS (2025). "UK Input-Output Analytical Tables: industry by industry, 2023". Office for National Statistics. Blue Book 2025.
- Flegg, A.T., Webber, C.D. and Elliott, M.V. (1995). "On the Appropriate Use of Location Quotients in Generating Regional Input-Output Tables". Regional Studies, 29(6), pp. 547-561.
- Flegg, A.T. and Tohmo, T. (2013). "Regional Input-Output Tables and the FLQ Formula: A Case Study of Finland". Regional Studies, 47(5), pp. 703-721.
- Bonfiglio, A. and Chelli, F. (2008). "Assessing the Behaviour of Non-Survey Methods for Constructing Regional Input-Output Tables". Economic Systems Research, 20(3), pp. 301-315.
- HM Treasury (2014). "Additionality Guide: A Standard Approach to Assessing the Additional Impact of Interventions", 4th edition. Department for Business, Innovation and Skills.
- MHCLG (2025). "The Appraisal Guide", 3rd edition. Ministry of Housing, Communities and Local Government.
- HM Treasury (2022). "The Green Book: Central Government Guidance on Appraisal and Evaluation".
- What Works Centre for Local Economic Growth (2024). "Toolkit: Local Multipliers". whatworksgrowth.org/resource-library/toolkit-local-multipliers.
- Crompton, J.L. (1995). "Economic Impact Analysis of Sports Facilities and Events: Eleven Sources of Misapplication". Journal of Sport Management, 9(1), pp. 14-35.

---

*Indicative estimates based on regional input-output modelling. Not a formal economic impact assessment. See methodology and caveats for limitations.*
*Powered by EconStack. Data from ONS, BRES, DLUHC via econprofile.com.*
```

### Step 5: Save and present

Save the report as:
- `impact-report-{la-slug}-{date}.md` in the current working directory
- If `--format pdf` was specified, also render via Quarto (if available) or note that PDF generation requires Quarto
- If `--format pptx` was specified, generate a summary slide deck

Present the key findings to the user in a concise summary:
```
IMPACT REPORT GENERATED
=======================
Location:    [LA name]
Sector:      [sector]
Investment:  [amount]

GROSS IMPACT
  Total output:    [val]
  Total jobs:      [val]
  GVA:             [val]
  Tax revenue:     [val]

NET ADDITIONAL (after additionality)
  Net output:      [val]
  Net jobs:        [val]

Report saved: impact-report-{slug}-{date}.md
```

## Important Rules

- Never use em dashes. Use colons, periods, commas, or parentheses.
- Never attribute econprofile or econstack to any individual. Present as a brand/product.
- Always include the full methodology section. This is what makes the report credible.
- Always include caveats. Honest about limitations.
- Format currency as GBP with commas (e.g. "GBP 5,000,000" or "£5.0m" in summaries).
- Round jobs to whole numbers. Round currency to nearest pound (or £Xm/£Xk in summaries).
- The additionality section is what separates this from naive IO analysis. Always include it unless --no-additionality is specified.
- Tax estimates get the strongest caveats. They are the least reliable output.
- Type I is the default because it is more conservative. Only use Type II when explicitly requested.
- If the user asks for a sector that doesn't exist in the 19-sector classification, map it to the closest match and note the mapping in the report.
