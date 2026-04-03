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
- `--client "Name"` : Add "Prepared for: [Name]" on the cover page
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
- **client**: Optional client name for the cover page
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

Write the report to a file in the current working directory. Use the following structure.

**Critical rules for the report:**
- Lead with the net impact (the number the client will use), then explain the gross figure.
- Cross-check every number in the executive summary against the detailed tables. They must match exactly.
- Generate 2-3 project-specific risk observations from the LA data (see section 5 below).
- Use action titles for findings sections (what the section SAYS, not what it IS). Keep label titles for methodology and reference sections.

```markdown
# Economic Impact Assessment: [Investment Description]

**Prepared for:** [Client name, if --client specified, otherwise omit this line]
**Prepared by:** EconStack
**Date:** [today's date]
**Local authority:** [LA name]
**Methodology:** Regional input-output model (FLQ regionalization)

---

## Executive Summary

[IMPORTANT: Lead with the net additional impact, not the gross figure. The net number is what goes into the business case.]

[Example structure:]

A [amount] [sector] investment in [LA name] would support an estimated [net jobs] net additional jobs and generate [net output] in net additional economic output, after accounting for deadweight, displacement, and leakage.

Before these adjustments, the gross impact is [total output] in total economic output and [total jobs] jobs. The estimated GVA contribution is [GVA], with approximately [total tax] in associated tax revenue.

These estimates are based on Type I input-output multipliers using ONS 2023 data, with additionality adjustments per HM Treasury guidance. They should be treated as indicative upper bounds. See the methodology section and caveats for important limitations.

## 1. The investment generates [total output] in total output and supports [total jobs] jobs

| Parameter | Value |
|-----------|-------|
| Investment / Direct jobs | [amount] |
| Sector | [sector] |
| Local authority | [LA name] |
| Multiplier type | Type I / Type II |
| Output multiplier | [value]x |
| Employment multiplier | [value]x |

| Impact | Direct | Indirect (supply chain) | [Induced (household)] | Total |
|--------|--------|------------------------|----------------------|-------|
| Economic output (GBP) | [val] | [val] | [val] | [val] |
| Employment (jobs) | [val] | [val] | [val] | [val] |

For every pound of direct spending, an additional [X]p circulates through the local economy via supply chain purchases from local firms. [1-2 sentences interpreting what the multiplier means for this specific area and sector.]

### GVA and fiscal effects

| Metric | Value |
|--------|-------|
| GVA contribution | [val] |
| Earnings impact | [val] |
| Estimated income tax | [val] |
| Estimated NICs | [val] |
| Estimated VAT | [val] |
| **Estimated total tax** | **[val]** |

> Tax estimates are rough approximations based on sector-average earnings and standard rates (20% income tax, 21.8% total NICs, VAT at 20% on 35% of earnings). Margin of error: 30-50%.

## 2. After additionality adjustments, the net additional impact is [net output]

Not all estimated impact is genuinely new. The following adjustments are applied based on HM Treasury Additionality Guide (4th edition, 2014) and MHCLG Appraisal Guide (3rd edition, 2025).

| Adjustment | Rate | Rationale |
|------------|------|-----------|
| Deadweight | [X]% | Activity that would have occurred without the intervention |
| Displacement | [X]% | Activity shifted from other businesses or areas |
| Leakage | [X]% | Benefits flowing outside the target area |
| Substitution | [X]% | Firms replacing one activity with another |
| **Net additionality factor** | **[X]%** | |

| Metric | Gross | Net additional |
|--------|-------|----------------|
| Economic output | [val] | [val] |
| Employment | [val] jobs | [val] jobs |
| GVA | [val] | [val] |
| Tax revenue | [val] | [val] |

## 3. Results are robust to variation in key assumptions

### Multiplier sensitivity (+/- 15%)

| Scenario | Output multiplier | Total output | Total jobs |
|----------|-------------------|--------------|------------|
| Low (-15%) | [val]x | [val] | [val] |
| **Central** | **[val]x** | **[val]** | **[val]** |
| High (+15%) | [val]x | [val] | [val] |

### Additionality sensitivity

The choice of additionality assumptions has a larger effect on results than the multiplier variation. The table below shows how net impact changes across the three HM Treasury presets:

| Scenario | Deadweight | Displacement | Leakage | Net output | Net jobs |
|----------|-----------|--------------|---------|-----------|---------|
| Optimistic | 10% | 10% | 5% | [val] | [val] |
| **Standard** | **20%** | **25%** | **10%** | **[val]** | **[val]** |
| Conservative | 35% | 40% | 20% | [val] | [val] |

[1-2 sentences interpreting the range. Example: "Even under conservative assumptions, the investment generates [X] net additional jobs and [Y] in net output."]

## 4. Key risks to this estimate

[Generate 2-3 project-specific observations from the LA data. These should be specific to the area and sector, not generic. Use the employment data, LQ, claimant rate, and other LA stats to make these concrete.]

**Use these patterns:**

- If the sector's LQ < 0.5 in this LA: "[LA]'s [sector] sector is small relative to the national economy (location quotient [X]), meaning local supply chains may be thinner than the multiplier implies. The actual indirect impact could be lower."
- If the sector's LQ > 2.0: "[LA] has a highly specialised [sector] economy (location quotient [X]), which supports the multiplier estimate. However, specialisation also means the area is more exposed to sector-specific shocks."
- If claimant rate > 5%: "The claimant rate of [X]% is above the national average, suggesting some labour market slack. This supports the spare capacity assumption underlying the model."
- If claimant rate < 2%: "The claimant rate of [X]% is well below the national average, suggesting a tight labour market. In practice, new jobs may be filled by commuters or migrants rather than local residents, which would reduce local spending effects."
- If GVA per job is significantly above/below national: "Productivity in [LA] ([GVA per job]) is [X]% [above/below] the national average, which [supports/complicates] the use of national-average GVA-to-output ratios."
- On sector aggregation: "The '[sector]' classification covers a range of sub-industries with different multiplier profiles. If this specific investment is in [plausible high-value subsector], the actual multiplier may be higher than the sector average."

## 5. Local economic context

[LA name] supports [total employment] workplace jobs with median earnings of [val], which is [X]% [above/below] the [country] average of [val]. The claimant rate is [X]%. Productivity (GVA per job) is [val], ranking [X]th of 391 local authorities.

[1-2 additional sentences on the area's economic character: service-dominated? Manufacturing heritage? Public sector dependent? Use the employment sector data to characterize the economy.]

## 6. Methodology

### 6.1 Input-output model

This assessment uses a regional input-output (IO) model derived from the ONS Input-Output Analytical Tables (2023), published as part of Blue Book 2025. The national technical coefficients matrix at 104 industries is aggregated to 19 SIC sections using output-weighted averaging. This matrix is regionalized using the Flegg Location Quotient (FLQ) method (Flegg et al. 1995), which adjusts national coefficients to reflect the local economy's sectoral structure and size.

The Leontief inverse of the regionalized matrix yields Type I multipliers, capturing direct effects (the initial expenditure) and indirect effects (supply chain purchases from local firms). [If Type II: The matrix is augmented with a household row and column representing the wage-consumption loop, yielding Type II multipliers that additionally capture induced effects.]

Employment multipliers are derived by weighting the Leontief inverse columns by sector-level employment intensity (jobs per million pounds of output), sourced from BRES via Nomis.

### 6.2 Why [LA name]'s multiplier is [X]x

Multipliers vary by area because local economies differ in their supply chain linkages. [LA name]'s regional size parameter (lambda) is [val]. [Interpretation: high = larger, more self-sufficient economy; low = smaller, more import-dependent.]

Lambda is computed as [log2(1 + RE/NE)]^delta, where RE is total local employment (BRES) and NE is total national employment. Delta = 0.3, a conventional value (Flegg et al. 1995, Bonfiglio & Chelli 2008; optimal range 0.1-0.4 per Flegg & Tohmo 2013). The geography used is the local authority district boundary.

### 6.3 Technical parameters

| Parameter | Value |
|-----------|-------|
| Data source | ONS Input-Output Analytical Tables, 2023 (Blue Book 2025) |
| Sector classification | 19 SIC sections (A-S), aggregated from 104 industries |
| Regionalization method | Flegg Location Quotient (FLQ) |
| FLQ delta parameter | 0.3 |
| Lambda for [LA] | [val] |
| Multiplier type | Type I [or Type II] |
| Additionality source | HM Treasury (2014); MHCLG (2025) |

### 6.4 Additionality framework

The additionality adjustments follow the HM Treasury Additionality Guide (BIS, 2009; updated 2014) and are consistent with the MHCLG Appraisal Guide (3rd edition, 2025).

- **Deadweight:** Activity that would have occurred without the intervention. Green Book range: 0-40%.
- **Displacement:** Activity shifted from other businesses or areas. Range: 0-75%. Higher for retail/leisure, lower for export-oriented sectors.
- **Leakage:** Benefits flowing outside the target area. Range: 5-50%, depending on area size.
- **Substitution:** Firms replacing one activity with another. Typically low for investment-driven interventions.

## 7. Important caveats

- **Spare capacity assumed.** The model assumes the local economy can absorb additional demand. In a tight labour market, actual impacts may be smaller.
- **Fixed input proportions.** If input prices change, the model still assumes the same quantities. No substitution or efficiency gains are captured.
- **No price effects.** Large investments can push up local wages and costs, reducing net benefit.
- **Data vintage.** Based on 2023 economic structure (ONS Blue Book 2025). The economy continues to evolve.
- **Sector aggregation.** The 19-sector classification averages sub-industries with very different characteristics. A specific investment may have a higher or lower multiplier than the sector average suggests.
- **Tax estimates are rough approximations** based on sector-average earnings and standard rates. Margin of error: 30-50%.
- **LA boundaries are administrative, not economic.** Commuting, supply chains, and spending cross LA boundaries. Impacts may spill into neighbouring areas.
- **IO multipliers are generally considered indicative upper bounds.** Econometric evidence from the What Works Centre for Local Economic Growth suggests real-world local employment multipliers are often lower than IO estimates.
- These are indicative estimates, not formal economic impact assessments. For investment decisions exceeding £50m, consider commissioning a bespoke Computable General Equilibrium (CGE) model or econometric study.

## 8. References

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

Save the report as `impact-report-{la-slug}-{date}.md` in the current working directory.

**If `--format pdf` was specified**, also render as a branded PDF:

```bash
# The render script wraps the markdown in the EconStack Quarto template and compiles via Typst
ECONSTACK_DIR="${CLAUDE_SKILL_DIR}/../.."
"$ECONSTACK_DIR/scripts/render-report.sh" impact-report-{la-slug}-{date}.md \
  --title "Economic Impact Assessment" \
  --subtitle "{LA name} | {Sector} | {Amount}" \
  [--client "{client name}" if specified]
```

If the render script is not found at the expected path, try `~/.claude/skills/econstack/scripts/render-report.sh`. If Quarto is not installed, tell the user: "PDF rendering requires Quarto (https://quarto.org). Install with: brew install quarto. The markdown report has been saved and can be converted manually."

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
PDF saved:    impact-report-{slug}-{date}.pdf (if --format pdf)
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
