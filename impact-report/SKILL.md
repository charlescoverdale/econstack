---
name: impact-report
description: Generate economic impact assessment sections using regional input-output multipliers. Interactive, lets you pick which sections you need.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Agent
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

# /impact-report: Economic Impact Assessment

Generate professional economic impact assessment content for an investment or job creation in any UK local authority. Uses regional input-output multipliers with FLQ regionalization, additionality adjustments per HM Treasury Green Book guidance, and full methodology documentation.

**This skill is interactive.** It computes the impact, shows you the key numbers, then asks what output you need: a full report, specific sections, slide-ready bullets, or just the data.

## Arguments

```
/impact-report <amount> in <sector> in <local_authority> [options]
```

**Examples:**
```
/impact-report £10m in Manufacturing in Manchester
/impact-report 500 jobs in Construction in Glasgow
/impact-report £25m in Financial & Insurance in City of London --type2
/impact-report £5m in Accommodation & Food in Brighton and Hove --full
```

**Options:**
- `--type2` : Include household spending (induced) effects (default: Type I only)
- `--conservative` : Use conservative additionality (35% deadweight, 40% displacement, 20% leakage)
- `--optimistic` : Use optimistic additionality (10% deadweight, 10% displacement, 5% leakage)
- `--no-additionality` : Report gross figures only
- `--client "Name"` : Add "Prepared for: [Name]" on outputs
- `--full` : Skip the interactive menu, generate the complete report
- `--format <type>` : Output format(s): `markdown`, `html`, `word`, `pptx`, `pdf`, or `all`. Comma-separate for multiple (e.g. `--format word,pdf`). Default: markdown only

## Instructions

### Step 1: Parse the request

Extract from the user's input:
- **amount**: The investment in GBP, or number of direct jobs
- **input_type**: "output" (investment in GBP) or "jobs" (direct job creation)
- **sector**: One of the 19 SIC sections. If the user says something informal, map it:
  - "tech"/"software" -> Information & Communication
  - "hospitality"/"hotels" -> Accommodation & Food
  - "banking"/"finance" -> Financial & Insurance
  - "pharma"/"chemicals" -> Manufacturing
  - "logistics"/"shipping" -> Transportation
  - "housing"/"development" -> Construction
- **local_authority**: The LA name or slug
- **multiplier_type**: "typeI" (default) or "typeII" (if --type2)
- **additionality**: "standard" (default), "conservative", "optimistic", or "none"
- **client**: Optional client name
- **full**: If true, skip the interactive menu and generate the complete report
- **formats**: List of output formats. Default: `["markdown"]`. Parse `--format` flag by splitting on commas. If `--format all`, expand to `["markdown", "html", "word", "pptx", "pdf"]`

### Step 2: Load data and compute

Load the multiplier data:

```bash
DATA_DIR="$HOME/econstack-data/src/data"
cat "$DATA_DIR/${LA_SLUG}/multipliers.json"
cat "$DATA_DIR/${LA_SLUG}/summary.json"
cat "$DATA_DIR/${LA_SLUG}/employment.json"
cat "$DATA_DIR/national-benchmarks.json"
```

If the LA slug is not found:
```bash
ls "$DATA_DIR/" | grep -i "<search_term>"
```

**Compute the impact using these formulas:**

If input is investment (GBP):
```
directOutput = amount
directJobs = round((amount / 1,000,000) * directEmploymentPerMillion)
```

If input is jobs:
```
directJobs = amount
directOutput = round((amount / directEmploymentPerMillion) * 1,000,000)
```

Type I:
```
totalOutput = round(directOutput * outputMultiplier)
indirectOutput = totalOutput - directOutput
totalJobs = round(directJobs * employmentMultiplier)
indirectJobs = totalJobs - directJobs
```

Type II (if requested):
```
totalOutputII = round(directOutput * outputMultiplierTypeII)
inducedOutput = totalOutputII - totalOutputI
totalJobsII = round(directJobs * employmentMultiplierTypeII)
inducedJobs = totalJobsII - totalJobsI
```

Expanded outputs:
```
gvaImpact = round(totalOutput * gvaToOutputRatio)
earningsImpact = round(totalJobs * averageEarningsPerJob)
```

Additionality:
```
Standard:      deadweight=20%, displacement=25%, leakage=10%, substitution=0%
Conservative:  deadweight=35%, displacement=40%, leakage=20%, substitution=5%
Optimistic:    deadweight=10%, displacement=10%, leakage=5%,  substitution=0%

factor = (1 - deadweight/100) * (1 - displacement/100) * (1 - leakage/100) * (1 - substitution/100)
netOutput = round(totalOutput * factor)
netJobs = round(totalJobs * factor)
```

### Step 3: Show the key numbers and ask what the user needs

After computing, present the results and ask what output format they want:

```
IMPACT COMPUTED
===============
£[amount] in [sector] in [LA name]

Key numbers:
  Net additional output:  [val]  (after additionality)
  Net additional jobs:    [val]
  Gross output:           [val]  (before additionality)
  Gross jobs:             [val]
  GVA contribution:       [val]
  Earnings impact:        [val]
  Output multiplier:      [val]x
  Additionality factor:   [val]%
```

**If `--full` was NOT specified**, ask the user what they need using AskUserQuestion:

Question: "What output do you need?"

Options:
- A) **Full report** : Complete 8-section report (exec summary, impact tables, additionality, sensitivity, risks, local context, methodology, references)
- B) **Key sections only** : Let me pick which sections I want
- C) **Slide summary** : 5 bullet points ready for PowerPoint, plus a one-line methodology note
- D) **Data only** : Just the JSON file with all computed values (for my own analysis)

**If user picks B**, ask a follow-up:

Question: "Which sections? (pick all that apply)"

Options (multiSelect: true):
- Executive summary (3 paragraphs, leads with net impact)
- Impact tables (gross and net, direct/indirect/induced breakdown)
- Additionality adjustment (HM Treasury defaults, net impact calculation)
- Sensitivity analysis (multiplier +/-15% AND additionality scenarios)
- Key risks (2-3 project-specific observations from LA data)
- Local economic context (employment, earnings, claimant rate vs benchmarks)
- Full methodology (IO model, FLQ, technical parameters, 2 pages)
- Methodology summary (one paragraph for slide footers or email footnotes)
- References (10 academic and government citations)

Then generate ONLY the selected sections, each clearly separated.

**After the content questions (or immediately after showing key numbers for options A/C/D), ask about output formats.**

**If `--format` was NOT specified on the command line**, ask using AskUserQuestion:

Question: "What file formats do you need?"

Options (multiSelect: true):
- Markdown (.md) : Default, always included. Plain text you can paste anywhere
- HTML : Branded single-page report, ready to open in a browser or email
- Word (.docx) : Formatted document for editing in Microsoft Word
- PowerPoint (.pptx) : Slide deck with key numbers, tables, and methodology note
- PDF : Branded consulting-quality PDF via Quarto

Markdown is always generated regardless of selection. If the user selects nothing beyond markdown, that is fine.

**If `--format` was specified on the command line**, skip the format question and use the specified format(s).

**If `--full` was specified** (without `--format`), skip all questions and generate markdown only. If `--full` was specified WITH `--format`, skip content questions but generate the specified format(s).

### Step 4: Generate the requested output

**Always include at the very top of any output file:**

```markdown
<!-- KEY NUMBERS
net_output: [val]
net_jobs: [val]
gross_output: [val]
gross_jobs: [val]
gva: [val]
tax: [val]
multiplier: [val]
additionality_factor: [val]
la: [LA name]
sector: [sector]
amount: [amount]
date: [date]
-->
```

This block is invisible when rendered but lets the user (or a future tool) extract the headline numbers without parsing the prose.

**Always write a companion JSON file** alongside any markdown output:
Save as `impact-data-{la-slug}-{date}.json` with all computed values, inputs, and metadata.

```json
{
  "input": { "la": "", "sector": "", "amount": 0, "inputType": "", "multiplierType": "", "additionality": "" },
  "multiplier": { "output": 0, "employment": 0, "lambda": 0, "method": "FLQ", "delta": 0.3 },
  "grossImpact": { "output": 0, "jobs": 0, "gva": 0, "directOutput": 0, "directJobs": 0, "indirectOutput": 0, "indirectJobs": 0, "inducedOutput": 0, "inducedJobs": 0 },
  "additionality": { "deadweight": 0, "displacement": 0, "leakage": 0, "substitution": 0, "factor": 0 },
  "netImpact": { "output": 0, "jobs": 0, "gva": 0 },
  "sensitivity": {
    "multiplier": { "low": { "output": 0, "jobs": 0 }, "high": { "output": 0, "jobs": 0 } },
    "additionality": { "optimistic": { "output": 0, "jobs": 0 }, "conservative": { "output": 0, "jobs": 0 } }
  },
  "context": { "totalEmployment": 0, "medianEarnings": 0, "claimantRate": 0, "gvaPerJob": 0 },
  "metadata": { "dataYear": 2023, "source": "ONS IOAT 2023 (Blue Book 2025)", "generatedAt": "" }
}
```

#### Section templates

Use these templates for each requested section. Each section should stand alone (do not reference "Section 3" or "as noted above"). A consultant may use any section independently.

**Executive summary:**
```markdown
## Executive Summary

A [amount] [sector] investment in [LA name] would support an estimated [net jobs] net additional jobs and generate [net output] in net additional economic output, after accounting for deadweight, displacement, and leakage.

Before these adjustments, the gross impact is [total output] in total economic output and [total jobs] jobs, comprising [direct output] in direct output and [indirect output] in indirect (supply chain) effects. The estimated GVA contribution is [GVA] and total earnings impact is [earnings].

These estimates use Type I input-output multipliers from ONS 2023 data with standard HM Treasury additionality adjustments. They should be treated as indicative upper bounds. [If the area has notable characteristics from the risk analysis, mention the most important one here.]
```

**Impact tables:**
```markdown
## Impact Breakdown

| Impact | Direct | Indirect (supply chain) | [Induced] | Total |
|--------|--------|------------------------|-----------|-------|
| Economic output | [val] | [val] | [val] | [val] |
| Employment (jobs) | [val] | [val] | [val] | [val] |

| Metric | Gross | Net additional |
|--------|-------|----------------|
| Economic output | [val] | [val] |
| Employment | [val] jobs | [val] jobs |
| GVA | [val] | [val] |
| Expanded outputs | Value |
|-----------------|-------|
| GVA contribution | [val] |
| Earnings impact | [val] |
```

**Additionality adjustment:**
```markdown
## Additionality Adjustment

Not all estimated impact is genuinely new. Adjustments based on HM Treasury Additionality Guide (4th edition, 2014) and MHCLG Appraisal Guide (3rd edition, 2025):

| Adjustment | Rate | Rationale |
|------------|------|-----------|
| Deadweight | [X]% | Activity that would have occurred without the intervention |
| Displacement | [X]% | Activity shifted from other businesses or areas |
| Leakage | [X]% | Benefits flowing outside the target area |
| Substitution | [X]% | Firms replacing one activity with another |
| **Net additionality factor** | **[X]%** | |

These are median values from HM Treasury guidance. Actual rates vary by intervention type. For retail/leisure, displacement is typically higher (40-75%). For export-oriented manufacturing, it may be lower (10-15%). Users should adjust based on the specific intervention.
```

**Sensitivity analysis:**
```markdown
## Sensitivity Analysis

### Multiplier variation (+/- 15%)

| Scenario | Output multiplier | Total output | Total jobs |
|----------|-------------------|--------------|------------|
| Low (-15%) | [val]x | [val] | [val] |
| **Central** | **[val]x** | **[val]** | **[val]** |
| High (+15%) | [val]x | [val] | [val] |

### Additionality scenarios

| Scenario | Deadweight | Displacement | Leakage | Net output | Net jobs |
|----------|-----------|--------------|---------|-----------|---------|
| Optimistic | 10% | 10% | 5% | [val] | [val] |
| **Standard** | **20%** | **25%** | **10%** | **[val]** | **[val]** |
| Conservative | 35% | 40% | 20% | [val] | [val] |

The choice of additionality assumptions has a larger effect on results than multiplier variation. [1-2 sentences interpreting the range.]
```

**Key risks:**
```markdown
## Key Risks to This Estimate

[Generate 2-3 project-specific observations from the LA data. Use these patterns:]

- If sector LQ < 0.5: "[LA]'s [sector] sector is small (LQ [X]), meaning local supply chains may be thinner than the multiplier implies."
- If sector LQ > 2.0: "[LA] is highly specialised in [sector] (LQ [X]), which supports the multiplier but increases exposure to sector-specific shocks."
- If claimant rate > 5%: "Claimant rate of [X]% suggests labour market slack, supporting the spare capacity assumption."
- If claimant rate < 2%: "Tight labour market (claimant rate [X]%) means new jobs may be filled by commuters or migrants rather than local residents."
- If GVA per job significantly differs from national: "Local productivity ([val]) is [X]% [above/below] national, which [supports/complicates] the GVA estimates."
- On sector aggregation: "The '[sector]' classification averages sub-industries with very different characteristics."
```

**Local economic context:**
```markdown
## Local Economic Context

[LA name] supports [total employment] workplace jobs with median earnings of [val], [X]% [above/below] the [country] average of [val]. The claimant rate is [X]%, [comparison to country and GB]. Productivity (GVA per job) is [val], ranking [X]th of 391 local authorities.

[1-2 sentences characterizing the economy: service-dominated? manufacturing heritage? public sector dependent? Use the sector employment data.]
```

**Full methodology:**
```markdown
## Methodology

### Input-output model

This assessment uses a regional input-output (IO) model derived from the ONS Input-Output Analytical Tables (2023), published as part of Blue Book 2025. The national technical coefficients matrix at 104 industries is aggregated to 19 SIC sections using output-weighted averaging. This matrix is regionalized using the Flegg Location Quotient (FLQ) method (Flegg et al. 1995), which adjusts national coefficients to reflect the local economy's sectoral structure and size.

The Leontief inverse of the regionalized matrix yields Type I multipliers, capturing direct effects (the initial expenditure) and indirect effects (supply chain purchases from local firms). [If Type II: When household spending is included, the matrix is augmented with a household row and column, yielding Type II multipliers that additionally capture induced effects.]

Employment multipliers are derived by weighting the Leontief inverse columns by sector-level employment intensity (jobs per million pounds of output), sourced from BRES via Nomis.

### Why [LA name]'s multiplier is [X]x

Multipliers vary by area because local economies differ in their supply chain linkages. [LA name]'s regional size parameter (lambda) is [val]. [Interpretation.]

Lambda is computed as [log2(1 + RE/NE)]^delta, where RE is total local employment (BRES) and NE is total national employment. Delta = 0.3 (Flegg et al. 1995; optimal range 0.1-0.4 per Flegg & Tohmo 2013). The geography is the local authority district boundary.

### Technical parameters

| Parameter | Value |
|-----------|-------|
| Data source | ONS Input-Output Analytical Tables, 2023 (Blue Book 2025) |
| Sector classification | 19 SIC sections (A-S), aggregated from 104 industries |
| Regionalization | Flegg Location Quotient (FLQ), delta = 0.3 |
| Lambda for [LA] | [val] |
| Multiplier type | Type I [or Type II] |
| Additionality | HM Treasury (2014); MHCLG (2025) |

### Additionality framework

Based on HM Treasury Additionality Guide (BIS, 2009; updated 2014) and MHCLG Appraisal Guide (3rd edition, 2025):

- **Deadweight:** Activity that would have occurred anyway. Range: 0-40%.
- **Displacement:** Activity shifted from elsewhere. Range: 0-75%.
- **Leakage:** Benefits flowing outside the area. Range: 5-50%.
- **Substitution:** Replacing existing activity. Typically low for investment interventions.

### Caveats

- Spare capacity assumed. In a tight labour market, actual impacts may be smaller.
- Fixed input proportions. No substitution or efficiency gains captured.
- No price effects. Large investments can push up local costs.
- Based on 2023 economic structure (ONS Blue Book 2025).
- 19-sector aggregation averages sub-industries with different characteristics.
- LA boundaries are administrative, not economic. Impacts spill across boundaries.
- IO multipliers are generally indicative upper bounds.
- These are indicative estimates, not formal economic impact assessments.
```

**Methodology summary (one paragraph):**
```markdown
**Methodology:** Estimates from a regional input-output model using ONS 2023 data (Blue Book 2025), regionalized via the Flegg Location Quotient method (Flegg et al. 1995). [Standard/Conservative/Optimistic] additionality adjustments applied per HM Treasury guidance (2014) and MHCLG (2025). Type [I/II] multipliers. Indicative upper bounds, not a formal assessment. See full methodology for details and limitations.
```

**References:**
```markdown
## References

- ONS (2025). "UK Input-Output Analytical Tables: industry by industry, 2023". Blue Book 2025.
- Flegg, A.T., Webber, C.D. and Elliott, M.V. (1995). "On the Appropriate Use of Location Quotients in Generating Regional Input-Output Tables". Regional Studies, 29(6), pp. 547-561.
- Flegg, A.T. and Tohmo, T. (2013). "Regional Input-Output Tables and the FLQ Formula". Regional Studies, 47(5), pp. 703-721.
- Bonfiglio, A. and Chelli, F. (2008). "Assessing the Behaviour of Non-Survey Methods for Constructing Regional Input-Output Tables". Economic Systems Research, 20(3), pp. 301-315.
- HM Treasury (2014). "Additionality Guide", 4th edition.
- MHCLG (2025). "The Appraisal Guide", 3rd edition.
- HM Treasury (2022). "The Green Book".
- What Works Centre for Local Economic Growth (2024). "Toolkit: Local Multipliers".
- Crompton, J.L. (1995). "Economic Impact Analysis of Sports Facilities and Events". Journal of Sport Management, 9(1).
```

**Slide summary:**
```markdown
**[Amount] [Sector] Investment in [LA Name]**

- Generates **[net output] net additional economic output** ([gross output] gross)
- Supports **[net jobs] net additional jobs** ([gross jobs] gross)
- GVA contribution of **[GVA]**, earnings impact of **[earnings]**
- Based on Type [I/II] IO multipliers (ONS 2023) with [standard/conservative/optimistic] additionality
- [One sentence on the area's key characteristic, e.g. "Manchester's service-dominated economy has limited local manufacturing supply chains, producing a modest 1.06x multiplier"]

*Methodology: Regional IO model, FLQ regionalization, ONS Blue Book 2025. HM Treasury additionality adjustments. Indicative estimates.*
```

### Step 5: Save and present

Save the output as `impact-report-{la-slug}-{date}.md` (or just the selected sections).
Always save the companion `impact-data-{la-slug}-{date}.json`.

**Then generate each additional format the user selected:**

**Markdown** (always generated):
Save as `impact-report-{slug}-{date}.md`. This is the primary output. No extra steps needed.

**HTML** (if selected):
Generate a self-contained HTML file with inline CSS. Use GOV.UK-style navy branding (#003078), KPI cards at the top, professional tables with navy headers and alternating row stripes, callout boxes for key notes. The HTML must be fully self-contained (no external CSS/JS) so it can be emailed or opened offline. Save as `impact-report-{slug}-{date}.html`.

**Word (.docx)** (if selected):
Invoke the `/docx` skill to convert the markdown report into a formatted Word document. Pass the full markdown content and instruct the skill to:
- Use a professional layout with navy (#003078) headings
- Format all tables with borders and header row styling
- Include the report title and subtitle on the first page
- If `--client` was specified, include "Prepared for: [client]" on the first page
Save as `impact-report-{slug}-{date}.docx`.

**PowerPoint (.pptx)** (if selected):
Invoke the `/pptx` skill to create a slide deck. Instruct it to create these slides:
1. Title slide: "Economic Impact Assessment" with LA name, sector, amount, and date
2. Key numbers slide: the 6 KPI values (net output, net jobs, gross output, gross jobs, GVA, multiplier) in a clean grid layout
3. Impact breakdown slide: the direct/indirect/total table
4. Sensitivity slide: the additionality scenarios table
5. Methodology slide: one-paragraph methodology summary and key caveats
Use navy (#003078) as the accent colour. If `--client` was specified, include "Prepared for: [client]" on the title slide.
Save as `impact-report-{slug}-{date}.pptx`.

**PDF** (if selected):
Render the markdown through the EconStack template:
```bash
ECONSTACK_DIR="${CLAUDE_SKILL_DIR}/../.."
"$ECONSTACK_DIR/scripts/render-report.sh" impact-report-{la-slug}-{date}.md \
  --title "Economic Impact Assessment" \
  --subtitle "{LA name} | {Sector} | {Amount}" \
  [--client "{client name}" if specified]
```
If Quarto is not installed, tell the user: "PDF rendering requires Quarto (https://quarto.org). The markdown report has been saved."

Tell the user what was generated, listing only the files that were actually produced:
```
Files saved:
  impact-report-{slug}-{date}.md     (report / selected sections)
  impact-data-{slug}-{date}.json     (structured data)
  impact-report-{slug}-{date}.html   (if HTML selected)
  impact-report-{slug}-{date}.docx   (if Word selected)
  impact-report-{slug}-{date}.pptx   (if PowerPoint selected)
  impact-report-{slug}-{date}.pdf    (if PDF selected)
```

## Important Rules

- Never use em dashes. Use colons, periods, commas, or parentheses.
- Never attribute econstack to any individual. Present as a brand/product.
- Every section must stand alone. Do not reference "Section 3" or "as discussed above." A consultant may use any section independently.
- Cross-check every number in the executive summary against the tables. They must match.
- Always save the companion JSON file regardless of which sections are selected.
- The methodology section is the credibility layer. When included, include it in full.
- Type I is the default (conservative). Only use Type II when explicitly requested.
- If the user asks for a sector that doesn't match the 19-sector list, map it and note the mapping.
- The key numbers block at the top of the markdown is always included, even for partial outputs.
- When Word or PowerPoint format is selected, invoke the `/docx` or `/pptx` skill to generate the file. Pass the markdown content and the companion JSON data so the skill has all the numbers it needs.
- Markdown is always generated, even when other formats are selected. It is the source for all other formats.
