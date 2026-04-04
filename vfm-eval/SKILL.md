---
name: vfm-eval
description: Value for Money evaluation. 3Es/4Es framework, unit cost benchmarks, fiscal return, evidence grading. Magenta Book compliant. Interactive.
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

# /vfm-eval: Value for Money Evaluation

Evaluate a programme, intervention, or policy against the HM Treasury Magenta Book value for money framework. Walks you through the 3Es (economy, efficiency, effectiveness), computes cost-effectiveness ratios benchmarked against published unit costs, applies additionality adjustments, estimates fiscal return, and grades the evidence quality using the Maryland Scientific Methods Scale.

The companion to `/cost-benefit`. Where `/cost-benefit` asks "should we do this?" (ex-ante appraisal), `/vfm-eval` asks "did it work? was it worth it?" (ex-post evaluation).

**This skill is interactive.** It asks about your programme, takes your cost and outcome data, runs the evaluation framework, then asks what output you need.

## Arguments

```
/vfm-eval [options]
```

**Examples:**
```
/vfm-eval
/vfm-eval --mode narrative
/vfm-eval --framework 4e
/vfm-eval --full --format word,pdf
```

**Options:**
- `--mode <type>` : `eval` (full VfM evaluation, default) or `narrative` (lighter Spending Review VfM narrative)
- `--framework <type>` : `3e` (UK Magenta Book, default), `4e` (FCDO international development), `au` (Australian ANAO 4Es with ethics), `us` (US GAO/OMB standards), `eu` (EC Better Regulation 5 criteria), `wb` (World Bank IEG 6-point rating), `dac` (OECD DAC 6 criteria), `nz` (NZ Living Standards Framework)
- `--full` : Skip interactive menus, generate all sections
- `--client "Name"` : Add "Prepared for"
- `--audit` : After generating, automatically run `/econ-audit` on the output
- `--format <type>` : Output format(s): `markdown`, `html`, `xlsx`, `word`, `pptx`, `pdf`, or `all`. Comma-separate for multiple. Default: markdown only

## Instructions

### Step 0: Load parameters

```bash
PARAMS_DIR="$HOME/econstack-data/parameters"
```

Load these parameter files:
- `$PARAMS_DIR/uk/unit-costs.json` (GMCA unit cost database for fiscal return computation)
- `$PARAMS_DIR/uk/additionality.json` (existing: deadweight, displacement, leakage benchmarks)
- `$PARAMS_DIR/uk/evidence-standards.json` (Maryland SMS decision tree and evidence levels)
- `$PARAMS_DIR/uk/vfm-benchmarks.json` (BCR categories, typical BCRs by intervention type, TOMS proxies)
- `$PARAMS_DIR/uk/discount-rates.json` (existing: for multi-year discounting if needed)

**Fallback:** If parameter files not found, use built-in defaults and tell the user: "Parameter database not found. Using built-in defaults. For the latest values, run: cd ~/econstack-data && git pull"

**Staleness check:** Same pattern as other skills. Check `expected_next_update` and `last_verified` dates.

### Step 1: Identify evaluation type and framework

**Mode selection:**

If `--mode` was not specified, ask using AskUserQuestion:

Question: "What are you evaluating?"

Options:
- A) **A specific programme or intervention** : Full VfM evaluation with 3Es/4Es framework, unit cost benchmarks, and evidence grading
- B) **I need a VfM narrative for a Spending Review bid** : Lighter structured narrative covering evidence of impact and cost-effectiveness

If A -> Mode A (full evaluation, Steps 2-10)
If B -> Mode B (Spending Review narrative, skip to Step 8b)

**Programme details:**

Ask using AskUserQuestion:

Question 1: "What is the programme or intervention called?"
(Free text. Use this as the programme name throughout.)

Question 2: "What sector does it operate in?"

Options:
- A) Employment and skills (job programmes, training, apprenticeships)
- B) Crime and justice (offender rehabilitation, youth justice, domestic violence)
- C) Health and wellbeing (prevention, mental health, substance misuse)
- D) Education (schools, early years, alternative provision)
- E) Housing and homelessness (prevention, social housing, rough sleeping)
- F) Regeneration and local growth (business support, enterprise zones, place-based)
- G) Transport
- H) Environment and energy
- I) International development (FCDO programmes)

This determines which unit cost domain to prioritise from the parameter database.

Question 3: "What stage is this evaluation?"

Options:
- A) **Mid-term** : Programme is still running. Assessing progress and early outcomes.
- B) **Final** : Programme has ended. Assessing full delivery and outcomes.
- C) **Ex-post** : Programme ended some time ago. Assessing sustained impact.

Question 4: "Which evaluation framework should this follow?"

Options:
- A) **UK 3Es** (Economy, Efficiency, Effectiveness) : HM Treasury Magenta Book (updated 2025). Default for UK domestic programmes.
- B) **FCDO 4Es** (Economy, Efficiency, Effectiveness, Equity) : UK international development standard. Adds distributional/equity assessment.
- C) **Australia 4Es** (Economy, Efficiency, Effectiveness, Ethics) : ANAO performance audit framework. PGPA Act requires "efficient, effective, economical and ethical" use of resources.
- D) **Other international framework** : EC Better Regulation, US GAO, World Bank IEG, OECD DAC, or NZ Living Standards

If D, ask a follow-up:

Options:
- **EC Better Regulation** (Effectiveness, Efficiency, Relevance, Coherence, EU Added Value) : European Commission 5-criteria framework. For EU-funded programmes.
- **US GAO/OMB** (3Es for audit + 5 evaluation standards: Rigor, Relevance, Independence, Transparency, Ethics) : US federal evaluation. Evidence Act 2018 compliance.
- **World Bank IEG** (Relevance, Efficacy, Efficiency) : 6-point outcome rating (Highly Satisfactory to Highly Unsatisfactory). For World Bank-financed projects.
- **OECD DAC** (Relevance, Coherence, Effectiveness, Efficiency, Impact, Sustainability) : 6 criteria, updated 2019. Standard for bilateral and multilateral development evaluation.
- **NZ Living Standards** (12 wellbeing domains + 4 capitals) : NZ Treasury framework. CBAx for monetisation, LSF for broader wellbeing assessment.

If `--framework` was specified, skip this question.

**Framework routing:**

Each framework determines which sections are generated and how findings are structured:

| Framework | Criteria assessed | VfM classification | Rating scale |
|-----------|------------------|-------------------|-------------|
| UK 3Es | Economy, Efficiency, Effectiveness | DfT BCR categories (Poor to Very High) | RAG per dimension |
| FCDO 4Es | Economy, Efficiency, Effectiveness, Equity | DfT BCR categories + equity narrative | RAG per dimension |
| Australia 4Es | Economy, Efficiency, Effectiveness, Ethics | No standard categories | RAG per dimension |
| EC Better Regulation | Effectiveness, Efficiency, Relevance, Coherence, EU Added Value | No BCR categories | Narrative per criterion |
| US GAO/OMB | 3Es (audit) + 5 standards (evaluation quality) | No BCR categories | Standards met / partially met / not met |
| World Bank IEG | Relevance, Efficacy, Efficiency | 6-point outcome rating | Highly Satisfactory to Highly Unsatisfactory |
| OECD DAC | Relevance, Coherence, Effectiveness, Efficiency, Impact, Sustainability | No standard categories | Narrative per criterion |
| NZ Living Standards | 12 wellbeing domains assessed qualitatively, CBAx for monetisation | CBAx BCR (no threshold categories) | Wellbeing dashboard |

For all frameworks, the core VfM computation (cost per outcome, BCR, additionality, fiscal return) is the same. What differs is how findings are structured and which additional dimensions (equity, ethics, coherence, sustainability, wellbeing) are assessed.

### Step 2: Logic model / theory of change

Ask: "Describe your programme in a few sentences. What does it do, who does it target, and what outcomes does it aim to achieve?"

From the user's description, construct a logic model table:

```markdown
## Logic Model

| Stage | Description |
|-------|-------------|
| **Inputs** | [Resources: funding (GBP X), staff (N FTE), facilities, partner organisations] |
| **Activities** | [What the programme does: training courses, mentoring, outreach, construction, service delivery] |
| **Outputs** | [Direct deliverables: N people trained, N sessions delivered, N units built, N assessments completed] |
| **Outcomes** | [Changes for beneficiaries: N people into employment, N qualifications gained, N reduced reoffending, N health improvements] |
| **Impact** | [Longer-term systemic change: reduced poverty, improved public health, stronger local economy, safer communities] |
```

Present the table and ask the user to confirm or amend. The logic model anchors the entire evaluation: every subsequent step traces back to this chain.

If the user provides a detailed description, populate the table fully. If they give a brief description, populate what you can and mark gaps with "[To be confirmed]".

### Step 3: Economy assessment (1st E)

Ask: "What was the total programme cost (GBP)?"
Ask: "What was the original budget (GBP)?" (If different from actual cost.)
Ask: "How many [primary output from logic model] were delivered?"

**Compute:**

```
cost_per_output = total_cost / outputs_delivered
budget_variance_pct = ((total_cost - budget) / budget) * 100
```

**Benchmark against GMCA unit costs:**

Load the relevant domain from `uk/unit-costs.json` based on the sector selected in Step 1. Find the closest matching unit cost.

```markdown
## Economy Assessment

| Metric | Value | Benchmark | Assessment |
|--------|-------|-----------|------------|
| Total programme cost | GBP [val] | Budget: GBP [val] | [Under/on/over budget] |
| Budget variance | [val]% | < 5% target | [GREEN/AMBER/RED] |
| Cost per [output] | GBP [val] | GMCA benchmark: GBP [val] | [Below/in line/above] |

**Assessment:** [1-2 sentences. Were inputs purchased at the right price and quantity?]
```

**RAG rating (from uk/vfm-benchmarks.json):**
- GREEN: Budget variance < 5% AND cost per output at or below benchmark
- AMBER: Budget variance 5-20% OR cost per output 1-1.5x benchmark
- RED: Budget variance > 20% OR cost per output > 1.5x benchmark

### Step 4: Efficiency assessment (2nd E)

Ask: "How many [outputs] were originally planned?"
Ask: "How many were actually delivered?"

**Compute:**

```
delivery_rate = (outputs_delivered / outputs_planned) * 100
cost_efficiency_ratio = cost_per_output / benchmark_cost_per_output
```

```markdown
## Efficiency Assessment

| Metric | Value | Target | Assessment |
|--------|-------|--------|------------|
| Planned outputs | [val] | | |
| Delivered outputs | [val] | | |
| Delivery rate | [val]% | > 90% for GREEN | [GREEN/AMBER/RED] |
| Cost per output | GBP [val] | GBP [val] (benchmark) | [val]x benchmark |

**Assessment:** [1-2 sentences. How well were inputs converted into outputs? Were there delivery issues?]
```

**RAG rating:**
- GREEN: Delivery rate > 90%
- AMBER: Delivery rate 70-90%
- RED: Delivery rate < 70%

### Step 5: Effectiveness assessment (3rd E)

Ask: "What outcomes were achieved? List each outcome type and the number achieved."
(E.g., "200 people moved into sustained employment, 50 gained a Level 2 qualification, 30 fewer reoffending events")

Parse the outcomes into a structured list.

**Evidence quality:**

Ask using AskUserQuestion:

Question: "What evaluation design was used to measure these outcomes?"

Options:
- A) **Randomised control trial (RCT)** : Participants were randomly assigned to treatment and control groups
- B) **Quasi-experimental** : Used DiD, regression discontinuity, instrumental variables, or synthetic control
- C) **Before-and-after with comparison group** : Compared outcomes for participants vs a similar untreated group over time
- D) **Before-and-after with statistical controls but no comparison group** : Compared participant outcomes before and after, with regression adjustment or propensity score matching, but no separate untreated comparison group
- E) **Simple before-and-after, no controls** : Compared participant outcomes before and after, no comparison group, no statistical controls
- F) **No formal evaluation design** : Monitoring data only, descriptive statistics

Assign the Maryland SMS evidence level using the decision tree from `uk/evidence-standards.json`:
- A -> Level 5
- B -> Level 4
- C -> Level 3
- D -> Level 2 (before-after with adequate statistical controls per SMS scoring guide Q4b)
- E -> Level 1 (simple pre-post without counterfactual or controls)
- F -> Level 1

**Additionality:**

Ask using AskUserQuestion:

Question: "Do you want to apply additionality adjustments to the outcomes?"

Options:
- A) **Standard** (central estimates: 20% deadweight, 25% displacement, 10% leakage, no multiplier, net factor 0.54)
- B) **Custom rates** (I'll specify my own deadweight, displacement, leakage, substitution, and multiplier)
- C) **None** (report gross outcomes only)

If A, load from `uk/additionality.json`:
```
net_outcomes = gross_outcomes * 0.54
```
Note: The standard scenario uses a multiplier of 1.0 (no multiplier effect), which is conservative. This is appropriate for most programme-level evaluations. For area-based impact assessments where supply chain effects are material, consider using custom rates with a multiplier > 1.0.

If B, ask for deadweight %, displacement %, leakage %, substitution %, and multiplier. Load multiplier guidance from `uk/additionality.json`:
- Type I multiplier (supply chain only): typically 1.3-1.5
- Type II multiplier (supply chain + income): typically 1.5-2.0
- Default 1.0 if no multiplier evidence

Compute:
```
net_factor = (1 - deadweight) * (1 - displacement) * (1 - leakage) * (1 - substitution)
net_outcomes = gross_outcomes * net_factor * multiplier
```
Per HM Treasury Additionality Guide (4th Edition, 2014), the multiplier is applied after all other additionality adjustments.

**Price base year check:**

Ask: "What year are your programme costs expressed in? (e.g., 2023 prices, nominal/outturn)"

If the user's cost price year differs from the parameter file's price_base_year (2023), apply a GDP deflator adjustment to bring all values to the same price year. If the user is unsure, assume nominal/outturn prices and note the assumption.

```
If programme costs are in a different price year from unit costs:
  adjusted_unit_cost = unit_cost * (GDP_deflator_programme_year / GDP_deflator_unit_cost_year)
  Note: Approximate GDP deflator growth of 2-3% per year can be used if precise deflators are unavailable.
```

Always state the price base year in the output: "All values in [year] prices."

**Monetise outcomes:**

For each outcome type, identify the appropriate monetary value:
- Employment outcomes -> use cost_of_unemployment_individual from uk/unit-costs.json (GBP 13,000/yr wider economic cost, 2023 prices) for the main BCR. Use fiscal_benefit_employment (GBP 7,800/yr) for the fiscal BCR in Step 6.
- Qualification outcomes -> use level_2/3_qualification_lifetime from uk/unit-costs.json (these are already lifetime present values, do not discount further)
- Crime reduction -> use reoffending_event from uk/unit-costs.json (GBP 18,000 per event, one-off)
- Health outcomes -> use relevant costs from uk/unit-costs.json. For health/wellbeing programmes, consider QALY (GBP 70,000, 2019 prices) or WELLBY (GBP 13,000, 2019 prices) valuation per Green Book supplementary guidance on wellbeing (2021).
- Wellbeing outcomes -> use WELLBY from uk/unit-costs.json (GBP 13,000/WELLBY in 2019 prices, GBP 15,300 in 2023 prices). One WELLBY = one point on a 0-10 life satisfaction scale sustained for one year. Use when subjective wellbeing is the primary outcome and clinical health measures (QALYs) are not appropriate.
- If no direct unit cost match, ask the user for a monetary value per outcome

**Benefit duration:**

Ask using AskUserQuestion:

Question: "How long do you expect the benefits to persist?"

Options:
- A) **1 year** : Conservative. Benefits last for the programme year only.
- B) **2 years** : Moderate. Benefits persist for a short period after the programme ends.
- C) **3 years** : Benefits persist for the medium term (e.g., sustained employment).
- D) **5+ years** : Long-term persistence (e.g., qualifications, infrastructure). I'll specify.
- E) **Lifetime values already used** : The unit costs I'm using are already lifetime present values (e.g., qualification premia). No further time adjustment needed.

If E, skip discounting. Otherwise, use the benefit duration to compute discounted present value.

**Note:** For outcomes already expressed as lifetime values (e.g., Level 2 qualification lifetime value of GBP 48,000), these are pre-discounted. Do not apply further discounting. For annual flow values (e.g., GBP 13,000/year cost of unemployment avoided), discount each year's benefit.

**Persistence/decay rates:**

Ask using AskUserQuestion:

Question: "Do you expect benefit levels to remain constant over the benefit period, or decay over time?"

Options:
- A) **Constant** : Same annual benefit each year (default assumption)
- B) **Declining (10% per year)** : Benefits decay at 10% p.a. (e.g., some participants lose employment)
- C) **Declining (20% per year)** : Benefits decay at 20% p.a. (e.g., short-term health interventions)
- D) **Custom decay rate** : I'll specify

If B, C, or D, model declining benefit streams:
```
annual_benefit_t = annual_benefit_year1 * (1 - decay_rate)^(t-1)
```

The decay-adjusted annual benefit for each year is then discounted using the Green Book STPR. This is more realistic than flat benefits: Barnett (2010) and Boardman et al. (2018) recommend modelling declining benefit streams for employment, health, and skills outcomes.

**Discount benefits (Green Book compliant):**

Load the discount rate schedule from `$PARAMS_DIR/uk/discount-rates.json`. For most VfM evaluations (benefit duration < 30 years), use the standard STPR of 3.5%.

Compute discounted present value of benefits:

```
# For annual flow benefits (e.g., employment, rent savings):
PV_benefits = 0
for t in 1 to benefit_duration:
    if t <= 30:
        r = 0.035  # Green Book STPR years 0-30
    elif t <= 75:
        r = 0.030  # years 31-75
    else:
        r = 0.025  # years 76-125
    discount_factor_t = 1 / (1 + r)^t
    PV_benefits += annual_benefit * discount_factor_t

# For one-off benefits (e.g., crime event avoided, qualification lifetime value):
# No discounting needed if the benefit occurs in year 0.
# If the benefit occurs in a future year, discount to year 0.

total_monetised_benefits = sum(PV_benefits_by_outcome_type)
```

Show the discount table in the output:

```markdown
### Discounting

| Year | Annual benefit | Discount factor (3.5%) | Present value |
|------|---------------|----------------------|---------------|
| 1 | GBP [val] | [val] | GBP [val] |
| 2 | GBP [val] | [val] | GBP [val] |
| ... | ... | ... | ... |
| **Total PV** | | | **GBP [val]** |

Discount rate: Green Book STPR (3.5% for years 0-30). Source: HM Treasury Green Book 2026.
```

**Compute BCR:**

```
cost_per_outcome = total_cost / total_net_outcomes
bcr = total_monetised_benefits / total_cost
```

All costs are assumed to occur in year 0 (programme period). If programme costs span multiple years, discount them too using the same schedule.

Classify VfM using DfT categories from `uk/vfm-benchmarks.json` (6 categories, May 2025):
- BCR < 0: Very Poor (negative net benefits)
- 0 <= BCR < 1.0: Poor
- 1.0 <= BCR < 1.5: Low
- 1.5 <= BCR < 2.0: Medium
- 2.0 <= BCR < 4.0: High
- BCR >= 4.0: Very High

Boundary rule: boundary values go into the upper category (per DfT VfM Supplementary Guidance on Categories, November 2024). So BCR of exactly 1.0 is Low, 1.5 is Medium, 2.0 is High, 4.0 is Very High.

**Compute RPSC (Return on Public Sector Cost):**

Per the Green Book, RPSC measures net benefits to society per pound of net public sector cost:

```
net_public_sector_cost = total_cost - PV(fiscal_savings_that_flow_back_to_public_sector)
rpsc = total_monetised_benefits / net_public_sector_cost
```

If fiscal return was computed in Step 6, use those discounted fiscal savings. Otherwise, set net_public_sector_cost = total_cost (RPSC equals BCR).

RPSC will always be >= BCR because the denominator is smaller. Present RPSC alongside BCR in the effectiveness assessment.

**Benchmark:**

Compare the BCR against typical BCRs for the intervention type from `uk/vfm-benchmarks.json`. E.g., "The BCR of 2.3 compares to a typical range of 1.0-3.0 for employment programmes."

```markdown
## Effectiveness Assessment

### Outcomes

| Outcome | Gross | Net additional | Value per outcome | Total value |
|---------|-------|---------------|------------------|-------------|
| [Type 1] | [val] | [val] | GBP [val] | GBP [val] |
| [Type 2] | [val] | [val] | GBP [val] | GBP [val] |
| **Total** | **[val]** | **[val]** | | **GBP [val]** |

Additionality: [X]% deadweight, [X]% displacement, [X]% leakage (net factor: [X]%).

### Value for Money

| Metric | Value | Category |
|--------|-------|----------|
| Total monetised benefits (PV) | GBP [val] | |
| Total programme cost | GBP [val] | |
| **BCR** | **[val]** | **[VfM category]** |
| **RPSC** | **[val]** | (Return on Public Sector Cost) |
| Cost per net outcome | GBP [val] | |
| Evidence level | SMS Level [N] | [Method name] |

**Assessment:** [2-3 sentences. Did the programme achieve its intended outcomes? How does the BCR compare to similar interventions? How confident are we in these findings given the evidence level?]

*Note: Always interpret BCR alongside the evidence level. A BCR of 3.0 based on Level 5 (RCT) evidence is much more credible than a BCR of 3.0 based on Level 1 (descriptive) evidence.*
```

### Step 5b: Sensitivity analysis (mandatory)

**This section is always generated.** Per Green Book and Magenta Book requirements, key assumptions must be tested.

Compute the BCR under the following scenarios:

```
Sensitivity tests:
1. Discount rate: recompute BCR at 1.5% (lower bound) and 7% (upper bound)
2. Additionality: recompute BCR using optimistic and conservative scenarios from uk/additionality.json
3. Benefit duration: recompute BCR with +/- 1 year on the assumed benefit duration
4. Decay rate: if constant benefits assumed, test with 10% annual decay
5. Switching values: for each key parameter (additionality, benefit duration, unit cost per outcome),
   compute the value at which the BCR crosses 1.0 (i.e., the programme breaks even)
```

Present as:

```markdown
## Sensitivity Analysis

### Scenario testing

| Scenario | BCR | VfM category | Change from central |
|----------|-----|-------------|-------------------|
| **Central case** | **[val]** | **[category]** | - |
| Lower discount rate (1.5%) | [val] | [category] | [+/- val] |
| Higher discount rate (7%) | [val] | [category] | [+/- val] |
| Optimistic additionality (net factor [val]) | [val] | [category] | [+/- val] |
| Conservative additionality (net factor [val]) | [val] | [category] | [+/- val] |
| Benefit duration +1 year | [val] | [category] | [+/- val] |
| Benefit duration -1 year | [val] | [category] | [+/- val] |
| 10% annual decay (if not already applied) | [val] | [category] | [+/- val] |

### Switching values

| Parameter | Central value | Switching value (BCR = 1.0) | Headroom |
|-----------|--------------|---------------------------|----------|
| Net additionality factor | [val] | [val] | [val]% |
| Benefit duration | [val] years | [val] years | [val] years |
| Value per outcome | GBP [val] | GBP [val] | [val]% |

**Assessment:** [1-2 sentences. Is the VfM conclusion robust to plausible variations in assumptions? Which parameter is the BCR most sensitive to? Are there scenarios where the VfM category changes?]
```

### Step 5c: Opportunity cost (brief)

Include a brief note in the effectiveness assessment:

```markdown
### Opportunity cost

The programme cost of GBP [val] could alternatively have funded [brief comparison, e.g., "approximately [N] additional apprenticeship places at GBP [val] each" or "[N] school places"]. This comparison is illustrative only and does not account for differences in outcomes or targeting.
```

Use a relevant comparator from `uk/unit-costs.json` in the same sector. If the programme is in employment, compare to apprenticeship cost. If in crime, compare to prison places. Keep it to 1-2 sentences.

### Step 6: Fiscal return (optional)

Ask using AskUserQuestion:

Question: "Would you like to estimate the fiscal return (savings to the Exchequer)?"

Options:
- A) **Yes** : Compute fiscal savings using GMCA unit costs
- B) **No** : Skip fiscal return

If yes:

For each outcome type, look up the relevant fiscal unit cost from `uk/unit-costs.json`. Fiscal unit costs represent the direct saving to public services when a negative outcome is avoided.

```
# For annual fiscal savings, discount over the same benefit duration used in Step 5:
PV_fiscal_saving = 0
for t in 1 to benefit_duration:
    annual_fiscal_saving_t = sum(net_outcomes_by_type * fiscal_unit_cost_by_type)
    if decay_rate > 0:
        annual_fiscal_saving_t = annual_fiscal_saving_t * (1 - decay_rate)^(t-1)
    discount_factor_t = 1 / (1 + 0.035)^t  # Green Book STPR
    PV_fiscal_saving += annual_fiscal_saving_t * discount_factor_t

# For one-off fiscal savings (e.g., crime events avoided), no time dimension needed.
total_fiscal_saving = PV_fiscal_saving + one_off_fiscal_savings
fiscal_bcr = total_fiscal_saving / total_cost
```

```markdown
## Fiscal Return

| Outcome avoided | Net additional | Fiscal unit cost | Fiscal saving |
|----------------|---------------|-----------------|---------------|
| [Reoffending event] | [val] | GBP [val] | GBP [val] |
| [Benefit claim] | [val] | GBP [val] | GBP [val] |
| [Hospital admission] | [val] | GBP [val] | GBP [val] |
| **Total** | | | **GBP [val]** |

| Metric | Value |
|--------|-------|
| Total fiscal saving | GBP [val] |
| Programme cost | GBP [val] |
| **Fiscal BCR** | **[val]** |

**Assessment:** [1-2 sentences. Does the programme pay for itself in fiscal savings alone?]

*Fiscal unit costs are national averages from the GMCA Unit Cost Database (Green Book supplementary guidance). Actual savings depend on local service configuration. Avoid double-counting: check whether unit costs for different outcome types include overlapping cost components.*
```

### Step 7: Additional framework dimensions

**This step generates framework-specific sections beyond the core 3Es. Skip if UK 3Es only.**

**FCDO 4Es: Equity assessment**

```markdown
## Equity Assessment (4th E)

### Who benefited?

| Dimension | Programme participants | Target population | Reach |
|-----------|----------------------|-------------------|-------|
| Gender | [M/F/other breakdown] | [target] | [met/unmet] |
| Income group | [breakdown] | [target] | [met/unmet] |
| Geography | [urban/rural/specific areas] | [target] | [met/unmet] |
| Disability | [breakdown] | [target] | [met/unmet] |
| Ethnicity | [breakdown] | [target] | [met/unmet] |
| Age | [breakdown] | [target] | [met/unmet] |

### Differential impact

[Were outcomes different for different groups? Did marginalised populations benefit equally? Were there unintended exclusionary effects?]

### Equity-adjusted VfM

[Does the programme represent better or worse VfM when equity considerations are included? Would distributional weighting (Green Book Annex 3) increase or decrease the BCR?]
```

**Australia 4Es: Ethics assessment**

```markdown
## Ethics Assessment (4th E)

### Compliance with PGPA Act requirements

| Principle | Assessment |
|-----------|------------|
| Proper use of public resources | [Were resources used for their intended purpose?] |
| Probity and governance | [Were procurement and delivery processes fair and transparent?] |
| Accountability | [Were decision-makers accountable? Were conflicts of interest managed?] |
| Compliance | [Were relevant laws, regulations, and policies followed?] |

### Ethical conduct

[Were there any ethical concerns in programme delivery? Were participants treated fairly? Was informed consent obtained where relevant?]
```

**EC Better Regulation: Relevance, Coherence, EU Added Value**

```markdown
## Relevance

[To what extent do the intervention's objectives correspond to current needs and priorities? Have circumstances changed since the intervention was designed?]

## Coherence

### Internal coherence
[Are the intervention's components consistent with each other? Do they work together or create contradictions?]

### External coherence
[Is the intervention consistent with other EU policies and international obligations? Are there synergies or conflicts with related interventions?]

## EU Added Value

[What is the additional value from EU-level action compared to what Member States could have achieved alone? What would happen if the intervention were discontinued?]
```

**World Bank IEG: Outcome rating**

Compute the IEG 6-point outcome rating:

The IEG rates three dimensions, with Relevance split into two sub-dimensions:

```
Relevance:
  - Relevance of objectives: Were the project's objectives relevant to the country's development priorities and the Bank's strategy?
  - Relevance of design: Was the project design appropriate for achieving the objectives?
  Rate each sub-dimension as: High, Substantial, Modest, or Negligible.
  Overall Relevance = judgment-based synthesis of the two sub-ratings.

Efficacy: To what extent did the project achieve its stated objectives?
  Rate as: High, Substantial, Modest, or Negligible.

Efficiency: How economically were resources converted into results?
  Rate as: High, Substantial, Modest, or Negligible.

Overall Outcome = judgment-informed synthesis (not mechanical):
  The IEG uses validator judgment informed by the sub-ratings. The following are guidelines, not rigid rules:
  - Highly Satisfactory: All dimensions High or Substantial, outcomes exceeded expectations, no shortcomings
  - Satisfactory: All dimensions Substantial+, outcomes broadly met expectations
  - Moderately Satisfactory: Most dimensions Substantial+, minor shortcomings in one area
  - Moderately Unsatisfactory: Significant shortcomings in one or more dimensions, but some positive results
  - Unsatisfactory: Major shortcomings across dimensions, objectives largely not achieved
  - Highly Unsatisfactory: Severe shortcomings, negligible results, fundamental design or relevance failures

  Note: A Negligible rating on Efficacy is a strong signal for Unsatisfactory or below. A Negligible Relevance of Design does not automatically trigger the same if objectives were relevant and efficacy was Substantial. The overall rating requires judgment.

6-point scale:
  Highly Satisfactory (6), Satisfactory (5), Moderately Satisfactory (4),
  Moderately Unsatisfactory (3), Unsatisfactory (2), Highly Unsatisfactory (1)
```

```markdown
## IEG Outcome Rating

| Dimension | Rating | Rationale |
|-----------|--------|-----------|
| Relevance of objectives | [High/Substantial/Modest/Negligible] | [1-line assessment] |
| Relevance of design | [High/Substantial/Modest/Negligible] | [1-line assessment] |
| **Relevance (overall)** | **[High/Substantial/Modest/Negligible]** | |
| Efficacy | [High/Substantial/Modest/Negligible] | [1-line assessment] |
| Efficiency | [High/Substantial/Modest/Negligible] | [1-line assessment] |
| **Overall Outcome** | **[6-point rating]** | [1-line synthesis] |

*Rating methodology: IEG ICR Review Manual (August 2018). The overall outcome rating is a judgment-informed synthesis, not a mechanical average of sub-ratings.*
```

**OECD DAC: Coherence, Impact and Sustainability**

```markdown
## Coherence

### Internal coherence
[Are the intervention's components consistent with each other? Do the different activities and objectives work together, or are there tensions or contradictions?]

### External coherence
[Is the intervention consistent with other interventions in the same context? Are there synergies or duplications with other programmes addressing the same issue? Does it align with the partner country's own policies and priorities?]

## Impact

[What difference has the intervention made? What are the positive and negative, intended and unintended, higher-level effects? Consider social, environmental, economic, and political impacts.]

## Sustainability

[Will the benefits last? Are the results likely to continue after the intervention ends? What are the risks to sustainability? Are there exit strategies or handover plans?]
```

**NZ Living Standards: Wellbeing dashboard**

```markdown
## Wellbeing Assessment (NZ Living Standards Framework)

| Domain | Impact | Evidence |
|--------|--------|---------|
| Health | [Positive/Neutral/Negative] | [Brief rationale] |
| Income, consumption and wealth | [Positive/Neutral/Negative] | [Brief rationale] |
| Housing | [Positive/Neutral/Negative] | [Brief rationale] |
| Knowledge and skills | [Positive/Neutral/Negative] | [Brief rationale] |
| Work, care and volunteering | [Positive/Neutral/Negative] | [Brief rationale] |
| Safety | [Positive/Neutral/Negative] | [Brief rationale] |
| Family and friends | [Positive/Neutral/Negative] | [Brief rationale] |
| Subjective wellbeing | [Positive/Neutral/Negative] | [Brief rationale] |
| Cultural capability and belonging | [Positive/Neutral/Negative] | [Brief rationale] |
| Environmental amenity | [Positive/Neutral/Negative] | [Brief rationale] |
| Engagement and voice | [Positive/Neutral/Negative] | [Brief rationale] |
| Leisure and play | [Positive/Neutral/Negative] | [Brief rationale] |

### Four capitals impact

| Capital | Direction | Assessment |
|---------|-----------|------------|
| Natural capital | [+/-/neutral] | [Brief rationale] |
| Human capital | [+/-/neutral] | [Brief rationale] |
| Social capital | [+/-/neutral] | [Brief rationale] |
| Financial/physical capital | [+/-/neutral] | [Brief rationale] |
```

**US GAO/OMB: Evaluation quality standards**

```markdown
## Evaluation Quality Assessment (OMB M-20-12)

| Standard | Met? | Evidence |
|----------|------|---------|
| Rigor | [Met/Partially/Not met] | [Evaluation design, SMS level, data quality] |
| Relevance and utility | [Met/Partially/Not met] | [Are findings actionable? Do they address key questions?] |
| Independence and objectivity | [Met/Partially/Not met] | [Who conducted the evaluation? Were there conflicts of interest?] |
| Transparency | [Met/Partially/Not met] | [Are methods documented? Is data available? Pre-registration?] |
| Ethics | [Met/Partially/Not met] | [IRB approval? Informed consent? Equity considerations?] |
```

Ask the user for the data to populate whichever framework-specific section applies. If they don't have the data for certain dimensions, note this as a gap rather than omitting the section.

### Step 8: Show results and ask what output

```
VFM EVALUATION RESULTS
======================
Programme:         [name]
Sector:            [sector]
Evaluation stage:  [mid-term / final / ex-post]
Framework:         [3Es / 4Es / DAC]

ECONOMY
  Total cost:          GBP [val]
  Cost per output:     GBP [val]  (benchmark: GBP [val])  [GREEN/AMBER/RED]
  Budget variance:     [val]%

EFFICIENCY
  Delivery rate:       [val]%                               [GREEN/AMBER/RED]
  Cost efficiency:     [val]x benchmark                     [GREEN/AMBER/RED]

EFFECTIVENESS
  Net outcomes:        [val]  (after [val]% additionality)
  Cost per outcome:    GBP [val]
  BCR:                 [val]  ([VfM category])
  RPSC:                [val]  (Return on Public Sector Cost)
  Evidence level:      SMS Level [N] ([method])
  Benchmark:           Typical BCR for [sector]: [range]

FISCAL RETURN (if computed)
  Fiscal saving (PV):  GBP [val]
  Fiscal BCR:          [val]

SENSITIVITY
  BCR range:           [val] (conservative) to [val] (optimistic)
  Key switching value: [parameter] at [val] flips VfM to Poor

OVERALL VFM:           [Very Poor / Poor / Low / Medium / High / Very High]
                       Evidence: SMS Level [N]
```

**If `--full` was NOT specified**, ask using AskUserQuestion:

Question: "What output do you need?"

Options:
- A) **Full evaluation report** : All sections
- B) **Pick sections** : Choose which sections
- C) **Dashboard only** : Just the summary table above
- D) **Data only** : JSON file with all computed values

**If user picks B**, ask a follow-up (multiSelect: true):

Options:
- Logic model / theory of change
- Economy assessment (cost analysis, benchmarks)
- Efficiency assessment (delivery rate, cost-efficiency)
- Effectiveness assessment (outcomes, BCR, RPSC, evidence level)
- Sensitivity analysis (scenario testing, switching values)
- Fiscal return (unit cost savings)
- Equity assessment (4Es/FCDO only)
- VfM summary and classification
- Recommendations (what to improve, whether to continue funding)
- Methodology note (evaluation design, data sources, limitations)

### Step 8b: Spending Review narrative (Mode B)

**Only if Mode B was selected in Step 1.**

Ask:
- "Programme name and one-line description?"
- "Total cost and time period (e.g., GBP 50m over 3 years)?"
- "Key outputs and outcomes achieved?"
- "Is there any formal evaluation evidence? What method was used?"

From the responses, generate a structured VfM narrative (1-2 pages):

```markdown
## Value for Money Evidence: [Programme Name]

### What the programme does

[1 paragraph: description, target group, theory of change]

### Evidence of impact

[1-2 paragraphs: outcomes achieved, evaluation method and SMS level, comparison to similar interventions from What Works evidence base]

Evidence level: SMS Level [N] ([method]). [Interpretation of evidence strength.]

### Cost-effectiveness

[1 paragraph: cost per outcome, benchmarked against GMCA unit costs and similar programmes]

| Metric | Value | Benchmark |
|--------|-------|-----------|
| Total cost | GBP [val] | |
| Cost per [outcome] | GBP [val] | GBP [val] (GMCA) |
| BCR (if computable) | [val] | Typical: [range] for [sector] |

### Optimism bias note

[If the narrative includes forward-looking projections (e.g., projected future outcomes or scale-up estimates): "Forward-looking estimates should be adjusted for optimism bias per Green Book supplementary guidance. The Green Book recommends uplift factors of 10-40% for programme costs depending on the intervention type and stage (Flyvbjerg et al.). Without adjustment, projected BCRs may be overstated."]

[If the narrative is purely ex-post (reporting what has already happened): omit this section.]

### Case for continued funding

[1-2 paragraphs: why this represents value for money, what would be lost if funding ceased, how the programme could be improved]

*Data sources: Programme monitoring data, [evaluation report if available], GMCA Unit Cost Database, What Works Centre evidence reviews.*
```

After generating the narrative, ask about output formats (same as Step 9).

### Step 9: Output formats

**If `--format` was NOT specified on the command line**, ask using AskUserQuestion:

Question: "What file formats do you need?"

Options (multiSelect: true):
- Markdown (.md) : Default, always included
- HTML : Self-contained branded page for email or browser
- Excel (.xlsx) : Investment banking-style workbook with cover page, model sheets, and formatted tables
- Word (.docx) : Formatted document for editing
- PowerPoint (.pptx) : Slide deck with VfM dashboard and key findings
- PDF : Branded consulting-quality PDF via Quarto

Markdown is always generated regardless of selection.

### Step 10: Save and present

**Always include a key numbers block at the top:**

```markdown
<!-- KEY NUMBERS
type: vfm_evaluation
date: [YYYY-MM-DD]
framework: [3e/4e/dac]
programme: [name]
total_cost: [val]
outputs_delivered: [val]
net_outcomes: [val]
bcr: [val]
vfm_category: [Very Poor/Poor/Low/Medium/High/Very High]
rpsc: [val]
evidence_level: [1-5]
fiscal_bcr: [val]
additionality_factor: [val]
-->
```

**Always save a companion JSON file:** `vfm-data-{programme-slug}-{date}.json`

Save the main output as `vfm-eval-{programme-slug}-{date}.md`.

**Then generate each additional format the user selected:**

**HTML** (if selected):
Generate a self-contained HTML file with inline CSS. Navy branding (#003078), RAG-coloured cells in the 3E dashboard (green/amber/red), KPI cards at the top. Save as `vfm-eval-{slug}-{date}.html`.

**Excel (.xlsx)** (if selected):
Invoke the `/xlsx` skill to generate an investment banking-style workbook. Save as `vfm-eval-{slug}-{date}.xlsx`.

The workbook must have the following structure and formatting:

**Sheet 1: Cover**
- Row 1-2: blank
- Row 3: Programme name in bold, 18pt, navy (#003078)
- Row 5: "Value for Money Evaluation" in 14pt, navy
- Row 7: Framework (e.g., "UK 3Es (HM Treasury Magenta Book)")
- Row 8: Evaluation stage (e.g., "Final evaluation")
- Row 9: Date
- Row 11: "Prepared by [--client if specified, otherwise blank]"
- Row 13: "CONFIDENTIAL" in red if --client specified
- Column A width: 60. No gridlines on this sheet.
- Bottom of sheet: "Powered by econstack" in grey 8pt italic

**Sheet 2: VfM Dashboard**
- KPI summary row at top (merged cells, large font):
  - BCR | VfM Category | Evidence Level | Fiscal BCR
  - BCR cell: bold 24pt. GREEN fill if BCR > 2.0, AMBER (#FFC000) if 1.0-2.0, RED (#FF0000) if < 1.0
- 3E RAG table below:
  - Columns: Dimension | Rating | Finding
  - Rating cells: fill colour matches RAG (GREEN=#00B050, AMBER=#FFC000, RED=#FF0000), white bold text
- Borders: thin borders on all data cells, thick border on header row
- Header row: navy (#003078) fill, white bold text, 11pt Calibri
- Data rows: alternating white / light grey (#F2F2F2)
- All currency cells: GBP format with comma separators, no decimals
- All percentage cells: 1 decimal place with % symbol
- Column widths auto-fitted, minimum 12

**Sheet 3: Economy**
- Economy assessment table with benchmarks
- Budget variance highlighted (conditional: green if < 5%, amber 5-20%, red > 20%)
- Cost per output vs benchmark comparison

**Sheet 4: Efficiency**
- Delivery rate table
- Planned vs delivered comparison

**Sheet 5: Effectiveness**
- Outcomes table (gross, net, value per outcome, total value)
- Additionality assumptions clearly stated
- Discounting table showing year-by-year PV computation
- BCR computation: benefits row, cost row, BCR row (highlighted)
- Evidence level and benchmark comparison

**Sheet 6: Sensitivity**
- Scenario testing table (all scenarios from Step 5b)
- Switching values table
- Conditional formatting: highlight rows where VfM category changes from central case

**Sheet 7: Fiscal Return** (if computed)
- Fiscal unit cost table
- Fiscal BCR and RPSC computation

**Sheet 8: Assumptions**
- All parameters used: discount rate, additionality rates, unit costs, benefit duration
- Source for each parameter
- Price base year
- Formatted as a clean reference table

**IB formatting standards (apply to all data sheets):**
- Font: Calibri 10pt for data, 11pt for headers
- Headers: navy (#003078) fill, white bold text
- Alternating row shading: white / #F2F2F2
- Thin borders on all data cells
- Thick bottom border on header rows and total rows
- Numbers right-aligned, text left-aligned
- Currency: `#,##0` format (no decimals) with GBP prefix in header
- Percentages: `0.0%` format
- Ratios (BCR): `0.00` format
- Total/summary rows: bold, with top border (thin) and bottom border (double)
- No merged cells in data tables (merged cells only on Cover and KPI row)
- Print area set on each sheet. Landscape orientation for wide tables.
- Freeze panes: top row frozen on all data sheets
- Sheet tab colours: Cover=navy, Dashboard=navy, Economy=green, Efficiency=green, Effectiveness=green, Sensitivity=orange, Fiscal=blue, Assumptions=grey

**Word (.docx)** (if selected):
Invoke the `/docx` skill. Navy headings, formatted tables with RAG colours, title page with programme name and date. Save as `vfm-eval-{slug}-{date}.docx`.

**PowerPoint (.pptx)** (if selected):
Invoke the `/pptx` skill. Slides: (1) Title with programme name, (2) Logic model, (3) 3E dashboard with RAG, (4) Effectiveness (BCR + evidence level), (5) Fiscal return (if computed), (6) Recommendations. Save as `vfm-eval-{slug}-{date}.pptx`.

**PDF** (if selected):
```bash
ECONSTACK_DIR="$HOME/.claude/skills/econstack"
"$ECONSTACK_DIR/scripts/render-report.sh" vfm-eval-{slug}-{date}.md \
  --title "Value for Money Evaluation" \
  --subtitle "[Programme name]"
```

Tell the user what was generated:
```
Files saved:
  vfm-eval-{slug}-{date}.md       (evaluation report)
  vfm-data-{slug}-{date}.json     (structured data)
  vfm-eval-{slug}-{date}.html     (if HTML selected)
  vfm-eval-{slug}-{date}.xlsx     (if Excel selected)
  vfm-eval-{slug}-{date}.docx     (if Word selected)
  vfm-eval-{slug}-{date}.pptx     (if PowerPoint selected)
  vfm-eval-{slug}-{date}.pdf      (if PDF selected)
```

**If `--audit` was specified:**

After saving all files, invoke the `/econ-audit` skill on the generated markdown file:
  /econ-audit vfm-eval-{slug}-{date}.md

#### Section templates

**VfM summary:**
```markdown
## Value for Money Summary

| Dimension | Rating | Finding |
|-----------|--------|---------|
| Economy | [GREEN/AMBER/RED] | [1-line: cost vs benchmark, budget variance] |
| Efficiency | [GREEN/AMBER/RED] | [1-line: delivery rate, cost-efficiency] |
| Effectiveness | [GREEN/AMBER/RED] | [1-line: BCR, evidence level] |
| Equity | [GREEN/AMBER/RED or N/A] | [1-line: distributional reach] |
| **Overall VfM** | **[Category]** | **BCR [val], SMS Level [N]** |

[2-3 sentences synthesising the overall VfM assessment. What is the headline? Is the programme worth continuing? What would improve it?]
```

**Recommendations:**
```markdown
## Recommendations

Based on the VfM assessment above:

1. **[Continue / Expand / Redesign / Discontinue]:** [1-2 sentences rationale based on BCR and evidence]
2. **Improve evidence:** [If SMS < 3: "Commission a quasi-experimental evaluation to strengthen the evidence base." If SMS >= 3: "Maintain the current evaluation design."]
3. **[Programme-specific recommendation]:** [Based on the 3E findings. E.g., "Reduce unit costs by [mechanism]" or "Improve targeting to increase outcome rate."]
4. **[Programme-specific recommendation]:** [E.g., "Extend follow-up period to capture sustained outcomes."]

*These recommendations are based on the quantitative VfM assessment. They should be considered alongside qualitative evidence, strategic priorities, and political context.*
```

**Methodology note:**
```markdown
**Methodology:** Value for Money evaluation following the HM Treasury Magenta Book [3Es/4Es] framework. Economy assessed by benchmarking unit costs against the GMCA Unit Cost Database (Green Book supplementary guidance). Efficiency assessed by delivery rate against targets. Effectiveness assessed using [evaluation method] (Maryland SMS Level [N]) with additionality adjustments per HM Treasury Additionality Guide (4th edition, 2014) [if multiplier > 1.0: "including Type [I/II] multiplier of [val]"]. BCR and RPSC computed from discounted monetised benefits (Green Book STPR [val]%) vs total programme cost [if decay: "with [val]% annual benefit decay"]. Sensitivity analysis conducted on discount rate, additionality, and benefit duration. Fiscal return estimated using GMCA fiscal unit costs, discounted over [val] years. [If WELLBY: "Wellbeing impacts monetised using WELLBY valuation (GBP 13,000, 2019 prices) per Green Book supplementary guidance."] [If 4Es: "Equity assessed against FCDO equity framework (2019)."] All unit costs in [year] prices.
```

**Slide summary:**
```markdown
**[Programme Name] — Value for Money Evaluation**

- Total cost: **GBP [val]** over [period]
- Delivered **[val] [outputs]** ([val]% of target)
- **[val] net additional outcomes** (after [val]% additionality)
- **BCR: [val]** ([VfM category]) | RPSC: [val] | Evidence: SMS Level [N]
- [If fiscal return: Fiscal saving: **GBP [val]** (fiscal BCR: [val])]
- Sensitivity: BCR range [val]-[val] across scenarios
- [1-line headline recommendation]

*Magenta Book framework. GMCA unit costs. Green Book discounting. [Evaluation method]. Powered by econstack.*
```

## Important Rules

- Never use em dashes. Use colons, periods, commas, or parentheses.
- Never attribute econstack to any individual. Present as a brand/product.
- Every section stands alone. No cross-references between sections.
- **Always present BCR alongside SMS evidence level.** A high BCR with weak evidence is less credible than a moderate BCR with strong evidence. Never present BCR alone.
- **Always include the logic model.** It anchors the entire evaluation. Without it, the 3Es assessment lacks context.
- **Fiscal return is supplementary, not primary.** The primary metric is the BCR or cost-effectiveness ratio. Fiscal return shows only the savings to the Exchequer, not the full social benefit.
- **Unit costs are national averages.** Always caveat that actual costs depend on local service configuration and individual circumstances.
- **Avoid double-counting.** If a programme prevents homelessness AND reduces crime, check whether the homelessness unit cost already includes a crime component. The GMCA database notes what is included in each cost.
- **The skill does not run statistical impact evaluation.** It works with aggregate programme data (total costs, total outcomes). For DiD, RCT analysis, or other statistical methods, use R/Stata directly or the planned causalkit package.
- **For 4Es/FCDO mode, equity is not optional.** Always include the equity assessment, even if the data is limited. Note data gaps explicitly.
- **Conservative defaults:** Standard additionality, central unit costs, no optimism about outcomes.
- **Magenta Book compliance:** The output should be recognisable to a government economist as following Magenta Book structure. Use the correct terminology (3Es, additionality, counterfactual, net additional).
- Be specific about dates. "[Year]" not "last year".
- The companion JSON must include all computed values, inputs, and parameter sources.
