---
name: io-report
description: Input-output economic impact assessment (UK). Regional IO multipliers with FLQ regionalization, additionality, tax revenue, temporal profiles. 391 UK local authorities. Interactive.
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



**Only stop to ask the user when:** sector, location, or investment amount is unclear.
**Never stop to ask about:** multiplier type (default Type I), additionality rates (use HMT defaults), or data year (use latest available).
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

If learnings are found, apply them. When a prior learning influences a decision, note: "Prior learning applied: [key]".

**Capturing new learnings:** After completing this skill, log new insights via:

```bash
~/.claude/skills/econstack/bin/econstack-learnings-log '{"skill":"...","type":"...","key":"...","insight":"...","confidence":N,"source":"observed|user-stated|inferred"}'
```

Types: `framework` (preferred appraisal framework), `parameter` (custom overrides), `data-source` (preferred data), `output` (past report references), `operational` (tool/env quirks), `preference` (formatting/style). Confidence: 9-10 observed/stated, 6-8 strong inference, 4-5 weak. User-stated never decays; observed/inferred lose 1 point per 30 days. All data stored locally. Nothing transmitted.

<!-- preamble: parameter database check -->
After the update check, verify the parameter database is available and check staleness:

```bash
PARAMS_DIR="$HOME/econstack-data/parameters"
if [ -d "$PARAMS_DIR" ]; then
  PARAM_COUNT=$(find "$PARAMS_DIR" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
  echo "PARAMS: $PARAM_COUNT files loaded from $PARAMS_DIR"

  # Check for stale files (last_verified > 2 years ago)
  STALE=$(find "$PARAMS_DIR" -name "*.json" -mtime +730 2>/dev/null | wc -l | tr -d ' ')
  if [ "$STALE" -gt 0 ]; then
    echo "PARAMS_WARNING: $STALE file(s) not updated in 2+ years. Run: cd ~/econstack-data && git pull"
  fi
else
  echo "PARAMS: not found. Using built-in defaults. For full parameter support: git clone https://github.com/charlescoverdale/econstack-data.git ~/econstack-data"
fi
```

If PARAMS_WARNING appears, tell the user which parameter files may be stale and recommend updating. Continue with the skill normally using whatever parameters are available.

<!-- preamble: safety hooks -->

**Safety rules for this skill:**

1. **Parameter database is read-only.** Never write to, modify, or delete files in `~/econstack-data/parameters/`. These are shared, versioned parameters maintained separately. If a parameter needs updating, tell the user to update the econstack-data repo.

2. **Confirm before overwriting.** Before writing an output file, check if a file with the same name already exists. If it does, ask the user: "A file named [filename] already exists. Overwrite it, or save with a new name?" Do not silently overwrite.

<!-- preamble: completion status -->
**At the end of every skill run, report one of these statuses:**

- **DONE**: Analysis complete, output generated, all sections finished.
- **DONE_WITH_CONCERNS**: Output generated but with caveats (e.g., data gaps, assumptions that need review, sections below expected depth).
- **BLOCKED**: Cannot proceed (e.g., missing critical input, parameter database unavailable, framework not supported).
- **NEEDS_CONTEXT**: Need more information from the user before continuing.

Format: `STATUS: [status] | [one-line reason]`

# /io-report: Input-Output Economic Impact Assessment (UK)

Generate professional economic impact assessment content for an investment or job creation in any UK local authority. Uses regional input-output multipliers with FLQ regionalization, additionality adjustments per HM Treasury Green Book guidance, and full methodology documentation.

**This skill is interactive.** It computes the impact, shows you the key numbers, then asks what output you need: a full report, specific sections, slide-ready bullets, or just the data.

## Arguments

```
/io-report <amount> in <sector> in <local_authority> [options]
```

**Examples:**
```
/io-report £10m in Manufacturing in Manchester
/io-report 500 jobs in Construction in Glasgow
/io-report £25m in Financial & Insurance in City of London --type2
/io-report £5m in Accommodation & Food in Brighton and Hove --full
```

**Options:**
- `--type2` : Include household spending (induced) effects (default: Type I only)
- `--conservative` : Use conservative additionality (35% deadweight, 40% displacement, 20% leakage, 5% substitution)
- `--optimistic` : Use optimistic additionality (10% deadweight, 10% displacement, 5% leakage)
- `--no-additionality` : Report gross figures only
- `--client "Name"` : Add "Prepared for: [Name]" on outputs
- `--full` : Skip the interactive menu, generate the complete report
- `--format <type>` : Output format(s): `markdown`, `html`, `word`, `pptx`, `pdf`, or `all`. Comma-separate for multiple (e.g. `--format word,pdf`). Default: markdown only
- `--exec` : Generate a management consulting-style executive summary deck (6 slides with action titles). Can be combined with `--format pptx` for both decks.
- `--audit` : After generating the report, automatically run `/econ-audit` on the output

## Instructions

### Step 1: Parse the request

Extract from the user's input:
- **amount**: The investment in GBP, or number of direct jobs
- **input_type**: "output" (investment in GBP) or "jobs" (direct job creation)
- **sector**: One of the 19 SIC sections. If the user says something informal, map it:
  - "tech"/"software" -> Information & Communication (J)
  - "hospitality"/"hotels" -> Accommodation & Food (I)
  - "banking"/"finance" -> Financial & Insurance (K)
  - "pharma"/"chemicals" -> Manufacturing (C)
  - "logistics"/"shipping" -> Transportation (H)
  - "housing"/"development" -> Construction (F)
  - "retail"/"shops"/"supermarket" -> Wholesale & Retail (G)
  - "farming"/"agriculture"/"agri" -> Agriculture (A)
  - "defence"/"military" -> Public Administration (O)
  - "care"/"social care"/"NHS"/"hospital" -> Health & Social Work (Q)
  - "restaurants"/"pubs"/"cafes"/"bars" -> Accommodation & Food (I)
  - "warehousing"/"distribution"/"logistics" -> Transportation (H)
  - "data centres"/"AI"/"cyber"/"digital" -> Information & Communication (J)
  - "clean energy"/"renewables"/"solar"/"wind"/"nuclear" -> Electricity & Gas (D)
  - "biotech"/"life sciences"/"R&D" -> Professional & Scientific (M)
  - "creative"/"media"/"film"/"gaming" -> Arts & Recreation (R)
  - "insurance"/"banking"/"fintech" -> Financial & Insurance (K)
  - "property"/"housing"/"development" -> Real Estate (L) or Construction (F)
  - "waste"/"recycling"/"water" -> Water & Waste (E)
  - "admin"/"outsourcing"/"facilities"/"cleaning"/"security" -> Administrative & Support (N)
  - "schools"/"university"/"training" -> Education (P)

  If the sector still cannot be mapped after checking all mappings, display the full list of 19 SIC sections and use AskUserQuestion with the top 4 most likely matches as options (based on keyword similarity to the user's input).

- **local_authority**: The LA name or slug
- **multiplier_type**: "typeI" (default) or "typeII" (if --type2)
- **additionality**: "standard" (default), "conservative", "optimistic", or "none"
- **client**: Optional client name
- **full**: If true, skip the interactive menu and generate the complete report
- **formats**: List of output formats. Default: `["markdown"]`. Parse `--format` flag by splitting on commas. If `--format all`, expand to `["markdown", "html", "word", "pptx", "pdf"]`
- **audit**: If true, run `/econ-audit` after generating the report

### Step 2: Load data and compute

Load the multiplier data and parameters:

```bash
DATA_DIR="$HOME/econstack-data/src/data"
PARAMS_DIR="$HOME/econstack-data/parameters"
cat "$DATA_DIR/${LA_SLUG}/multipliers.json"
cat "$DATA_DIR/${LA_SLUG}/summary.json"
cat "$DATA_DIR/${LA_SLUG}/employment.json"
cat "$DATA_DIR/national-benchmarks.json"
cat "$PARAMS_DIR/uk/tax-parameters.json"
cat "$PARAMS_DIR/uk/additionality.json"
```

Use the tax thresholds and rates from `uk/tax-parameters.json` for the tax revenue estimate. Use the additionality scenarios from `uk/additionality.json`. If the parameter files are not found, use the built-in defaults below.

**LA fuzzy matching:**

If the LA slug is not found exactly in ~/econstack-data/src/data/:

1. Slugify the input (lowercase, replace spaces with hyphens, remove apostrophes).
2. Try exact match on the slugified version.
3. Try case-insensitive partial match: ls ~/econstack-data/src/data/ | grep -i "{slug}"
4. Try matching on just the first word: ls ~/econstack-data/src/data/ | grep -i "{first_word}"
5. Try common aliases:
   - "London" -> suggest "city-of-london", "westminster", "camden", "tower-hamlets", "southwark"
   - "Edinburgh" -> "city-of-edinburgh"
   - "Bristol" -> "bristol-city-of"
   - "Hull" -> "kingston-upon-hull-city-of"
   - "Stoke" -> "stoke-on-trent"
   - "Brighton" -> "brighton-and-hove"
   - "Newcastle" -> "newcastle-upon-tyne"
   - "Southend" -> "southend-on-sea"
6. If multiple matches found, present them as AskUserQuestion options (max 4).
7. If no matches: "No local authority found matching '[input]'. The data covers 391 UK local authorities. Try the official LA name (e.g., 'Kingston upon Hull' not 'Hull', 'City of Edinburgh' not 'Edinburgh')."

**Input validation (before computing):**

Before proceeding to computation, validate:
- If amount <= 0: "Investment amount must be positive. Got [amount]." Stop and ask for a valid amount.
- If the sector's `directEmploymentPerMillion` is 0, null, or missing in multipliers.json: "No employment intensity data available for [sector] in [LA]. This sector may be too small locally to produce reliable estimates. Try a broader sector classification or a neighbouring authority." Stop.
- If the LA slug directory does not exist in ~/econstack-data/src/data/: follow the fuzzy matching procedure below.
- If multipliers.json is missing or cannot be parsed: "Multiplier data not found for [LA]. The econstack-data package may need updating. Run: cd ~/econstack-data && git pull" Stop.

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

**Tax revenue estimate:**

Compute estimated Exchequer contributions from the generated employment. Use tax thresholds and rates from the loaded `uk/tax-parameters.json`. If not loaded, use the built-in defaults shown below.

```
# Load from parameters (or use defaults)
personal_allowance = tax_params.income_tax.personal_allowance  # default: 12570
basic_rate = tax_params.income_tax.basic_rate.rate              # default: 0.20
basic_threshold = tax_params.income_tax.basic_rate.threshold    # default: 50270
higher_rate = tax_params.income_tax.higher_rate.rate            # default: 0.40
employee_nic_rate = tax_params.national_insurance.employee.rate      # default: 0.08
employee_nic_threshold = tax_params.national_insurance.employee.threshold  # default: 12570
employer_nic_rate = tax_params.national_insurance.employer.rate      # default: 0.138
employer_nic_threshold = tax_params.national_insurance.employer.threshold  # default: 9100
vat_rate = tax_params.vat.standard_rate                         # default: 0.20
local_spending = tax_params.modelling_assumptions.local_spending_from_wages  # default: 0.60
vatable_proportion = tax_params.modelling_assumptions.vatable_spending_proportion  # default: 0.50

# Effective income tax rate (simplified, based on sector average earnings)
if averageEarningsPerJob <= personal_allowance:
    effective_income_tax_rate = 0.0
elif averageEarningsPerJob <= basic_threshold:
    effective_income_tax_rate = (averageEarningsPerJob - personal_allowance) * basic_rate / averageEarningsPerJob
else:
    effective_income_tax_rate = ((basic_threshold - personal_allowance) * basic_rate + (averageEarningsPerJob - basic_threshold) * higher_rate) / averageEarningsPerJob

income_tax = round(totalJobs * averageEarningsPerJob * effective_income_tax_rate)

# Employee NICs
nics_employee = round(totalJobs * max(0, averageEarningsPerJob - employee_nic_threshold) * employee_nic_rate)

# Employer NICs
nics_employer = round(totalJobs * max(0, averageEarningsPerJob - employer_nic_threshold) * employer_nic_rate)

# VAT on consumer spending from wages
# Use effective NIC rate (NICs only apply above threshold, not on full earnings)
effective_nic_rate = max(0, averageEarningsPerJob - employee_nic_threshold) * employee_nic_rate / averageEarningsPerJob
net_earnings = averageEarningsPerJob * (1 - effective_income_tax_rate - effective_nic_rate)
vat_estimate = round(totalJobs * net_earnings * local_spending * vatable_proportion * vat_rate)

total_tax_revenue = income_tax + nics_employee + nics_employer + vat_estimate
```

These are indicative estimates using simplified effective rates. Actual tax revenue depends on individual circumstances, allowances, and reliefs. The estimates assume all jobs are filled by UK taxpayers. Tax year: loaded from `uk/tax-parameters.json` (default: 2024/25).

Additionality (load scenarios from `uk/additionality.json`, or use built-in defaults):
```
Standard:      deadweight=20%, displacement=25%, leakage=10%, substitution=0%  (net factor: 0.54)
Conservative:  deadweight=35%, displacement=40%, leakage=20%, substitution=5%  (net factor: 0.296)
Optimistic:    deadweight=10%, displacement=10%, leakage=5%,  substitution=0%  (net factor: 0.769)

factor = (1 - deadweight) * (1 - displacement) * (1 - leakage) * (1 - substitution)
netOutput = round(totalOutput * factor)
netJobs = round(totalJobs * factor)
```

**Temporal profile (optional):**

After computing the steady-state impact, ask: "Do you want a multi-year impact profile showing construction and operational phases?"

Options:
- A) **No** (single steady-state estimate, the default)
- B) **Yes** (show construction phase, ramp-up, and steady-state separately)

If yes, ask:
- "How many years is the construction/build phase?" (Default: 2 years)
- "What percentage of the investment is construction spend?" (Default: 100% for infrastructure, 50% for mixed projects)

Compute:
- Construction phase: apply the Construction sector (F) multiplier to the construction spend, spread over the build years
- Operational ramp-up: 50% of steady-state impact in year 1 of operations, 75% in year 2, 100% from year 3
- Steady-state: the full operational impact as already computed

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
  Tax revenue:            [val]
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
- Tax revenue estimate (income tax, NICs, VAT from generated employment)
- Additionality adjustment (HM Treasury defaults, net impact calculation)
- Sensitivity analysis (multiplier +/-15% AND additionality scenarios)
- Key risks (2-3 project-specific observations from LA data)
- Local economic context (employment, earnings, claimant rate vs benchmarks)
- Multi-year impact profile (construction, ramp-up, and steady-state phases)
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
type: impact
date: [YYYY-MM-DD]
framework: uk
la: [LA name]
sector: [sector]
amount: [amount]
net_output_m: [val]
net_jobs_n: [val]
gross_output_m: [val]
gross_jobs_n: [val]
gva_m: [val]
tax_revenue: [val]
multiplier_output: [val]
multiplier_employment: [val]
additionality_factor: [val]
-->
```

This block is invisible when rendered but lets the user (or a future tool) extract the headline numbers without parsing the prose.

**Always write a companion JSON file** alongside any markdown output:
Save as `impact-data-{la-slug}-{date}.json` with all computed values, inputs, and metadata.

```json
{
  "input": { "la": "", "sector": "", "amount": 0, "inputType": "", "multiplierType": "", "additionality": "" },
  "multiplier": { "output": 0, "employment": 0, "lambda": 0, "method": "FLQ", "delta": 0.3 },
  "grossImpact": { "output": 0, "jobs": 0, "gva": 0, "directOutput": 0, "directJobs": 0, "indirectOutput": 0, "indirectJobs": 0, "inducedOutput": 0, "inducedJobs": 0, "taxRevenue": { "incomeTax": 0, "nicsEmployee": 0, "nicsEmployer": 0, "vatEstimate": 0, "total": 0 } },
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

The estimated annual Exchequer contribution is [total_tax_revenue] in income tax, NICs, and VAT.

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

**Tax revenue estimate:**
```markdown
## Estimated Exchequer Contribution

| Tax type | Gross estimate (£) | Net additional (£) |
|----------|-------------------|-------------------|
| Income tax | [val] | [val] |
| Employee NICs | [val] | [val] |
| Employer NICs | [val] | [val] |
| VAT (on wage spending) | [val] | [val] |
| **Total** | **[val]** | **[val]** |

Net additional figures apply the same additionality factor ([X]%) as the employment estimates.

These are indicative estimates using simplified effective tax rates. Actual Exchequer receipts depend on individual circumstances, tax allowances, pension contributions, and reliefs. The estimates assume all jobs are filled by UK taxpayers paying standard rates.

*Methodology: income tax computed at 20% basic rate on earnings above £12,570 personal allowance (2024/25 thresholds). Employee NICs at 8% above £12,570. Employer NICs at 13.8% above £9,100. VAT estimated on 60% of net earnings spent locally, with 50% of spending subject to 20% standard rate.*
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
| Substitution | [X]% | Replacing existing activity. Typically low for investment interventions |
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
- Always include a multiplier benchmark: "[LA]'s [sector] output multiplier of [X]x compares to the national average of [national_multiplier]x. [If local < national by >10%: 'The local economy has thinner supply chains for this sector, meaning more spending leaks to other areas.' If local > national by >10%: 'Strong local supply chains in this sector support above-average multiplier effects.' If within 10%: 'This is broadly in line with the national average.']"

To compute the national benchmark, load 3-5 other LA multipliers for the same sector from ~/econstack-data/src/data/ (choose LAs with similar lambda values, or well-known comparators like Manchester, Birmingham, Leeds). Compute the unweighted average as a benchmark.
```

**Local economic context:**
```markdown
## Local Economic Context

[LA name] supports [total employment] workplace jobs with median earnings of [val], [X]% [above/below] the [country] average of [val]. The claimant rate is [X]%, [comparison to country and GB]. Productivity (GVA per job) is [val], ranking [X]th of 391 local authorities.

[1-2 sentences characterizing the economy: service-dominated? manufacturing heritage? public sector dependent? Use the sector employment data.]
```

**Multi-year impact profile:**
```markdown
## Multi-Year Impact Profile

| Phase | Year | Output (£m) | Jobs | GVA (£m) | Tax revenue (£) |
|-------|------|-------------|------|----------|-----------------|
| Construction | 1 | [val] | [val] | [val] | [val] |
| Construction | 2 | [val] | [val] | [val] | [val] |
| Operational (50% ramp-up) | 3 | [val] | [val] | [val] | [val] |
| Operational (75% ramp-up) | 4 | [val] | [val] | [val] | [val] |
| **Operational (steady-state)** | **5+** | **[val]** | **[val]** | **[val]** | **[val]** |

Construction phase impacts use the Construction sector (SIC F) multiplier ([val]x) applied to the annual construction spend. Operational impacts use the [sector] multiplier ([val]x). Benefits ramp up over 2 years as the project reaches full operational capacity.

Note: Construction jobs are temporary (lasting the build period only). Operational jobs are sustained annually at steady-state.
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

Save the output as `io-report-{la-slug}-{date}.md` (or just the selected sections).
Always save the companion `impact-data-{la-slug}-{date}.json`.

**Then generate each additional format the user selected:**

**Markdown** (always generated):
Save as `io-report-{slug}-{date}.md`. This is the primary output. No extra steps needed.

**HTML** (if selected):
Generate a self-contained HTML file with inline CSS. Use GOV.UK-style navy branding (#003078), KPI cards at the top, professional tables with navy headers and alternating row stripes, callout boxes for key notes. The HTML must be fully self-contained (no external CSS/JS) so it can be emailed or opened offline. Save as `io-report-{slug}-{date}.html`.

**Word (.docx)** (if selected):
Invoke the `/docx` skill to convert the markdown report into a formatted Word document. Pass the full markdown content and instruct the skill to:
- Use a professional layout with navy (#003078) headings
- Format all tables with borders and header row styling
- Include the report title and subtitle on the first page
- If `--client` was specified, include "Prepared for: [client]" on the first page
Save as `io-report-{slug}-{date}.docx`.

**PowerPoint (.pptx)** (if selected):
Invoke the `/pptx` skill to create a slide deck. Instruct it to create these slides:
1. Title slide: "Economic Impact Assessment" with LA name, sector, amount, and date
2. Key numbers slide: the 6 KPI values (net output, net jobs, gross output, gross jobs, GVA, multiplier) in a clean grid layout
3. Impact breakdown slide: the direct/indirect/total table
4. Sensitivity slide: the additionality scenarios table
5. Methodology slide: one-paragraph methodology summary and key caveats
Use navy (#003078) as the accent colour. If `--client` was specified, include "Prepared for: [client]" on the title slide.
Save as `io-report-{slug}-{date}.pptx`.

**Executive summary deck** (if `--exec` specified):

Invoke the `/pptx` skill to create a management consulting-style executive summary deck. Every slide follows the **action title + evidence** pattern: a 2-line strapline stating the conclusion (a complete sentence, NOT a topic label), then 3-4 dot points proving it.

Formatting: Action title 24-28pt bold navy (#003078). Body 14-16pt, one key number bolded per bullet. Footer 10pt light grey with methodology note + date. Clean white background, no decorative elements. Slide numbers bottom-right.

**Slide 1: Title**
- "Economic Impact Assessment" (large, navy)
- [Investment/project description], [area], date, "Prepared for: [client]" if specified

**Slide 2: Headline impact**
- Action title: "This investment supports [X] jobs and [currency][X]m GVA in [area]"
- Evidence:
  - Total employment impact: **[X] jobs** (direct + indirect + induced)
  - Total GVA impact: **[currency][X]m**
  - Total output impact: **[currency][X]m**
  - Tax revenue generated: **[currency][X]m**
- Optional: simple KPI grid (4 boxes with the headline numbers)

**Slide 3: Direct vs indirect**
- Action title: "For every direct job, [X] additional jobs are supported in the supply chain"
- Evidence:
  - Direct: **[X] jobs** / **[currency][X]m** GVA
  - Indirect (supply chain): **[X] jobs** / **[currency][X]m** GVA
  - [If Type II]: Induced (spending): **[X] jobs** / **[currency][X]m** GVA
  - Multiplier: **[val]** ([Type I/II])

**Slide 4: Tax and fiscal return**
- Action title: "The investment generates [currency][X]m in additional tax revenue over [X] years"
- Evidence:
  - Income tax and NICs: **[currency][X]m**
  - Business rates: **[currency][X]m**
  - VAT and other: **[currency][X]m**
  - [If temporal profile computed]: Peak impact in year [X], fading over [X] years

**Slide 5: Sensitivity**
- Action title: "Under conservative assumptions, the impact is [X] jobs and [currency][X]m GVA"
- Evidence:
  - Conservative: **[X] jobs**, **[currency][X]m** GVA (high additionality adjustments)
  - Central: **[X] jobs**, **[currency][X]m** GVA
  - Optimistic: **[X] jobs**, **[currency][X]m** GVA (low adjustments)
  - Key sensitivity: [which assumption matters most]

**Slide 6: Context and caveats**
- Action title: "[Area]'s [sector] multiplier of [val] is [above/below/in line with] comparable areas"
- Evidence:
  - Benchmark comparison (2-3 comparable areas with multipliers)
  - Key caveat: IO models assume fixed coefficients and no supply constraints
  - [Any area-specific context: e.g. labour market tightness, sector concentration]
- Footer: "Full impact report: io-report-{slug}-{date}.md"

Save as `io-exec-{slug}-{date}.pptx`.

**PDF** (if selected):
Render the markdown through the EconStack template:
```bash
ECONSTACK_DIR="$HOME/.claude/skills/econstack"
"$ECONSTACK_DIR/scripts/render-report.sh" io-report-{la-slug}-{date}.md \
  --title "Economic Impact Assessment" \
  --subtitle "{LA name} | {Sector} | {Amount}" \
  [--client "{client name}" if specified]
```
If Quarto is not installed, tell the user: "PDF rendering requires Quarto (https://quarto.org). The markdown report has been saved."

Tell the user what was generated, listing only the files that were actually produced:
```
Files saved:
  io-report-{slug}-{date}.md     (report / selected sections)
  impact-data-{slug}-{date}.json     (structured data)
  io-report-{slug}-{date}.html   (if HTML selected)
  io-report-{slug}-{date}.docx   (if Word selected)
  io-report-{slug}-{date}.pptx   (if PowerPoint selected)
  io-report-{slug}-{date}.pdf    (if PDF selected)
```

**If `--audit` was specified:**

After saving all files, invoke the `/econ-audit` skill on the generated markdown file:
  /econ-audit io-report-{la-slug}-{date}.md

This produces an audit scorecard alongside the report, catching any methodology issues. The audit will cross-check the companion JSON against the prose numbers.

## Important Rules

- Never use em dashes.
- Never attribute econstack to any individual.
- Every section stands alone.
- **Table and figure formatting (universal across all econstack outputs):**
  - **Numbering**: Every table is "Table 1: [short description]", every figure/chart is "Figure 1: [short description]". Numbering restarts at 1 for each report. The caption goes above the table/figure.
  - **Source note**: Below every table and figure: "Source: [Author/Publisher] ([year])." If multiple sources: "Sources: [Source 1]; [Source 2]."
  - **Notes line**: Below the source, if needed: "Notes: [caveats, e.g. 'real 2026 prices', '2024-25 data', 'estimated from available figures']."
  - **Minimal formatting (low ink-to-data ratio)**: No heavy borders or gridlines. Thin rule under the header row only. No shading on data cells (light grey alternating rows permitted in Excel/HTML only). Right-align all numbers. Left-align all text. Bold totals rows only. No decorative elements.
  - **Number formatting**: Currency with comma separators and 1 decimal place for millions (e.g. "GBP 45.2m" / "AUD 45.2m"), whole numbers for counts (e.g. "1,250 jobs"), percentages to 1 decimal place (e.g. "3.5%").
  - **Consistency**: The same metric must use the same unit and precision throughout the report. Do not switch between "GBP m" and "GBP bn" for the same order of magnitude.
- Cross-check every number in the executive summary against the tables. They must match.
- Always save the companion JSON file regardless of which sections are selected.
- The methodology section is the credibility layer. When included, include it in full.
- Type I is the default (conservative). Only use Type II when explicitly requested.
- If the user asks for a sector that doesn't match the 19-sector list, map it and note the mapping.
- The key numbers block at the top of the markdown is always included, even for partial outputs.
- When Word or PowerPoint format is selected, invoke the `/docx` or `/pptx` skill to generate the file. Pass the markdown content and the companion JSON data so the skill has all the numbers it needs.
- Markdown is always generated, even when other formats are selected. It is the source for all other formats.
