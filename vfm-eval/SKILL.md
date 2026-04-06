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
- `--exec` : Generate a management consulting-style executive summary deck (7 slides with action titles). Can be combined with `--format pptx` for both decks.
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
- A) **Sector defaults** (use sector-specific estimates from the Additionality Guide, based on the sector selected in Step 1)
- B) **Custom rates** (I'll specify my own deadweight, displacement, leakage, substitution, and multiplier)
- C) **None** (report gross outcomes only)

If A, use the sector selected in Step 1 to load sector-specific additionality parameters. The Additionality Guide (4th Edition) provides the following ranges by intervention type:

| Sector | Deadweight | Displacement | Leakage | Net factor |
|--------|-----------|-------------|---------|------------|
| Employment and skills | 15-25% | 10-20% | 5-15% | 0.51-0.73 |
| Crime and justice | 10-20% | 5-10% | 5-10% | 0.66-0.81 |
| Health and wellbeing | 15-25% | 5-15% | 5-10% | 0.58-0.73 |
| Education | 10-20% | 10-20% | 5-10% | 0.58-0.73 |
| Housing and homelessness | 20-35% | 15-25% | 10-20% | 0.39-0.61 |
| Regeneration and local growth | 20-35% | 25-50% | 10-25% | 0.24-0.54 |
| Transport | 10-20% | 10-25% | 5-15% | 0.51-0.73 |
| Environment and energy | 15-25% | 5-15% | 5-10% | 0.58-0.73 |
| International development | 10-20% | 5-15% | 15-30% | 0.48-0.73 |

Use the midpoint of each range as the central estimate for the selected sector. Apply substitution = 0% and multiplier = 1.0 as defaults.

```
# Example for Employment and skills:
deadweight = 0.20, displacement = 0.15, leakage = 0.10
net_factor = (1-0.20) * (1-0.15) * (1-0.10) = 0.80 * 0.85 * 0.90 = 0.612
net_outcomes = gross_outcomes * 0.612
```

Note: These sector defaults are derived from ranges in the Additionality Guide. The Guide emphasises that actual additionality depends on the specific intervention, local context, and labour market conditions. The defaults are starting points for assessment, not definitive values. For regeneration and local growth programmes, displacement is particularly high (25-50%) because new activity often displaces existing local businesses.

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

**Compute NPSV and RPSC (Green Book metrics):**

Per the Green Book, two additional metrics complement the BCR:

```
# Net Present Social Value: the absolute net benefit
npsv = total_monetised_benefits - total_cost

# Return on Public Sector Cost: net benefit per pound of net public sector outlay
net_public_sector_cost = total_cost - PV(fiscal_savings_that_flow_back_to_public_sector)
rpsc = npsv / net_public_sector_cost
```

If fiscal return was computed in Step 6, use those discounted fiscal savings to compute net_public_sector_cost. Otherwise, set net_public_sector_cost = total_cost.

RPSC interpretation: a positive RPSC means the programme generates net benefits. RPSC of 0.5 means every GBP 1 of net public sector cost generates GBP 0.50 of net social benefit. RPSC can be negative (net costs exceed net benefits). Present NPSV and RPSC alongside BCR in the effectiveness assessment.

Note: RPSC uses NPSV (benefits minus costs) in the numerator, not total benefits. This is the standard Green Book formulation. Do not confuse with BCR (which uses total benefits / total costs).

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
| **NPSV** | **GBP [val]** | (Net Present Social Value) |
| **RPSC** | **[val]** | (Return on Public Sector Cost: NPSV / net public sector cost) |
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

### Optimism bias note

If the benefit duration is 3+ years or the evaluation stage is "mid-term" (i.e., some benefits are projected rather than observed), include:

"This evaluation assumes benefits persist for [N] years. [N-observed] years of benefits are projected forward from observed data. Per Green Book supplementary guidance, forward-looking projections are subject to optimism bias. Flyvbjerg et al. find systematic overestimation of benefits (typically 20-40%) in programme evaluations. The sensitivity analysis above tests the robustness of the BCR to shorter benefit duration and benefit decay, which partially addresses this risk."

If all benefits are fully observed (evaluation stage = "ex-post" or "final" with benefit duration <= observed period), omit this note.
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
  NPSV:                GBP [val]
  RPSC:                [val]  (NPSV / net public sector cost)
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

**Executive summary deck** (if `--exec` specified):

Invoke the `/pptx` skill to create a management consulting-style executive summary deck. Every slide follows the **action title + evidence** pattern: a 2-line strapline stating the conclusion, then 3-4 dot points or a chart proving it.

Formatting: Action title 24-28pt bold navy (#003078). Body 14-16pt, one key number bolded per bullet. Footer 10pt light grey with methodology note + date. Clean white background, no decorative elements. Slide numbers bottom-right. Charts in navy/grey/light blue palette.

**Slide 1: Title**
- Programme name (large, navy), "Value for Money Evaluation", framework, date, "Prepared for: [client]" if specified

**Slide 2: Headline verdict**
- Action title: "[Programme] delivered [High/Medium/Low] value for money" (or "Evidence for value for money is [insufficient/mixed]")
- Evidence:
  - **BCR: [val]** ([VfM category])
  - Evidence quality: **[Maryland SMS level]** ([description])
  - [If RPSC computed]: Return on public sector cost: **[val]**
  - [1-line overall assessment]

**Slide 3: What was delivered**
- Action title: "[Programme] reached [X] beneficiaries and delivered [key outcome]"
- Evidence: Simplified logic model as 4 bullets (inputs, activities, outputs, outcomes)
- Or: key output metrics (e.g. "500 people into employment", "2,000 training completions")

**Slide 4: Economy and efficiency**
- Action title: "Costs were [X]% [above/below] benchmark for comparable programmes" (or "Costs are in line with comparators")
- Evidence:
  - Unit cost: **[currency][val]** per [outcome] vs benchmark of **[currency][val]**
  - Total programme cost: **[currency][val]m** over [X] years
  - [If GMCA unit cost data available]: Compared against [N] similar programmes
  - [Assessment of economy/efficiency]

**Slide 5: Effectiveness**
- Action title: "For every [currency]1 spent, [currency][BCR] in benefits were generated"
- Evidence:
  - BCR: **[val]** (PV benefits [currency][val]m / PV costs [currency][val]m)
  - Evidence grade: **[Maryland level]** ([what this means in plain language])
  - Key outcome: [primary outcome metric and magnitude]
  - [If counterfactual available]: Compared to [counterfactual method] control group

**Slide 6: Fiscal return**
- Action title: "Every [currency]1 of public spend generated [currency][X] in fiscal savings" (or "The programme has a [positive/negative] fiscal return over [X] years")
- Evidence:
  - Discounted fiscal return: **[currency][val]m**
  - Fiscal payback period: **[X] years**
  - Top fiscal saving categories (2-3 bullets)
  - [If persistence modelled]: Benefits decay to zero over [X] years

**Slide 7: Recommendations**
- Action title: "Recommend [continuing/scaling/modifying/discontinuing] the programme"
- Evidence: 3-4 actionable recommendations, each as 1 bullet
- Footer: "Full evaluation report: vfm-eval-{slug}-{date}.md"

Save as `vfm-exec-{slug}-{date}.pptx`.

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

**Methodology annex:**

When the user selects "Methodology note" from the section picker, or when `--full` is specified, generate the following detailed methodology annex. This should be a standalone section that a government economist, auditor, or peer reviewer can read to understand every assumption, data source, and computational step.

```markdown
## Methodology

### Evaluation framework

This evaluation follows the HM Treasury Magenta Book (2020, updated July 2025) [3Es/4Es] framework. The three dimensions of value for money are:

- **Economy:** Were inputs purchased at the right price and quality? Assessed by benchmarking programme unit costs against published comparators.
- **Efficiency:** Were inputs converted into outputs at an acceptable rate? Assessed by comparing planned vs delivered outputs.
- **Effectiveness:** Did the programme achieve its intended outcomes? Assessed by computing a benefit-cost ratio (BCR) from monetised outcomes.

[If 4Es: "A fourth dimension, **Equity**, assesses whether benefits were distributed fairly across target populations, per FCDO guidance (2019)."]

### Evidence quality

Evidence quality is graded using the Maryland Scientific Methods Scale (SMS), the standard used by the What Works Centre for Local Economic Growth and adopted across UK government for impact evaluation.

| SMS Level | Design | Counterfactual strength |
|-----------|--------|------------------------|
| 5 | Randomised control trial (RCT) | Strongest: eliminates observable and unobservable selection bias |
| 4 | Quasi-experimental (RDD, IV) | Strong: exploits natural experiments or policy thresholds |
| 3 | Difference-in-differences with comparison group | Moderate: controls for time-invariant differences and common trends |
| 2 | Before-and-after with statistical controls | Limited: controls for observable confounders only |
| 1 | Simple before-and-after or descriptive | Weakest: no counterfactual, cannot attribute outcomes to programme |

This evaluation uses [evaluation method] (SMS Level [N]). [1-2 sentences on what this means for the credibility of the BCR. E.g., "At Level 1, the BCR should be interpreted as indicative. The observed outcomes cannot be attributed solely to the programme; external trends may explain part of the improvement."]

Source: [What Works Centre SMS Scoring Guide](https://whatworksgrowth.org/resource-library/the-maryland-scientific-methods-scale-sms/).

### Additionality

Net additional outcomes are computed per the HM Treasury Additionality Guide (4th edition, 2014):

```
net_additional = gross_outcomes * (1 - deadweight) * (1 - displacement) * (1 - leakage) * (1 - substitution) * multiplier
```

| Parameter | Value used | Rationale |
|-----------|-----------|-----------|
| Deadweight | [val]% | [Sector default / custom. What would have happened without the programme.] |
| Displacement | [val]% | [Sector default / custom. Activity displaced from elsewhere in the local economy.] |
| Leakage | [val]% | [Sector default / custom. Benefits that accrue outside the target area.] |
| Substitution | [val]% | [Sector default / custom. Firms substituting subsidised for unsubsidised activity.] |
| Multiplier | [val] | [1.0 (no multiplier) / Type I / Type II. Indirect and induced effects.] |
| **Net factor** | **[val]** | |

[If sector defaults used: "Sector-specific central estimates derived from Additionality Guide ranges for [sector]. See the Guide for full ranges and guidance on when to deviate."]

Source: [HM Treasury Additionality Guide, 4th edition (2014)](https://www.gov.uk/government/publications/green-book-supplementary-guidance-additionality).

### Monetisation

Outcomes are monetised using the following unit values:

| Outcome type | Unit value | Price year | Source |
|-------------|-----------|-----------|--------|
| [Outcome 1] | GBP [val] | [year] | [GMCA Unit Cost Database / Green Book / custom] |
| [Outcome 2] | GBP [val] | [year] | [source] |
[If WELLBY: "| Wellbeing impact | GBP 13,000/WELLBY | 2019 | Green Book Wellbeing Guidance (2021) |"]

Unit costs are national averages from the Greater Manchester Combined Authority (GMCA) Unit Cost Database, adopted as Green Book supplementary guidance. Actual costs vary by region, local service configuration, and individual circumstances.

[If price base year adjustment applied: "Programme costs (in [year] prices) were adjusted to [year] prices using the GDP deflator to ensure comparability with unit cost benchmarks."]

Source: [GO Lab Unit Cost Database](https://golab.bsg.ox.ac.uk/knowledge-bank/resources/unit-cost-database/).

### Discounting

Multi-year benefits are discounted to present value using the Green Book Social Time Preference Rate (STPR):

| Period | Discount rate | Source |
|--------|-------------|--------|
| Years 0-30 | 3.5% | Green Book 2026, Ramsey formula: delta=0.5%, L=1%, mu=1, g=2% |
| Years 31-75 | 3.0% | Green Book declining schedule |
| Years 76-125 | 2.5% | Green Book declining schedule |

Benefit duration: [N] years. [If decay: "Annual benefits decline at [val]% per year to reflect outcome persistence decay (e.g., some participants leave employment over time)."]

All costs are assumed to occur in year 0 (programme period). [If multi-year costs: "Programme costs spanning multiple years were also discounted."]

Source: [HM Treasury Green Book 2026](https://www.gov.uk/government/publications/the-green-book-appraisal-and-evaluation-in-central-government).

### Key metrics

| Metric | Formula | Value |
|--------|---------|-------|
| BCR | PV(benefits) / PV(costs) | [val] |
| NPSV | PV(benefits) - PV(costs) | GBP [val] |
| RPSC | NPSV / net public sector cost | [val] |
| Fiscal BCR | PV(fiscal savings) / PV(costs) | [val] |
| Cost per net outcome | PV(costs) / net additional outcomes | GBP [val] |

VfM classification follows DfT categories (May 2025): Very Poor (BCR < 0), Poor (0 to < 1.0), Low (1.0 to < 1.5), Medium (1.5 to < 2.0), High (2.0 to < 4.0), Very High (>= 4.0). Boundary values go to the upper category.

Source: [DfT Value for Money Framework (May 2025)](https://www.gov.uk/government/publications/dft-value-for-money-framework).

### Sensitivity analysis

Key assumptions were tested per Green Book and Magenta Book requirements:

- **Discount rate:** Central (3.5%), low (1.5%), high (7%)
- **Additionality:** Central (net factor [val]), optimistic ([val]), conservative ([val])
- **Benefit duration:** Central ([N] years), +/- 1 year
- **Decay rate:** [If applicable: "[val]% annual decay" / "Tested at 10% if constant assumed"]
- **Switching values:** Parameters at which the BCR crosses 1.0

[If optimism bias note included: "Forward-looking benefit projections are subject to optimism bias per Green Book supplementary guidance (Flyvbjerg et al.). The sensitivity analysis on benefit duration and decay rate partially addresses this."]

### Data sources

| Data element | Source | Vintage | Access |
|-------------|--------|---------|--------|
| Programme costs | [Programme monitoring data] | [year] | [Provided by user] |
| Programme outcomes | [Programme monitoring data / evaluation report] | [year] | [Provided by user] |
| Unit costs | GMCA Unit Cost Database; NHS NCC; HMPPS; PSSRU | 2023-2025 | [GO Lab, NHS England, gov.uk] |
| Additionality parameters | HM Treasury Additionality Guide (4th ed.) | 2014 | [gov.uk] |
| Discount rates | HM Treasury Green Book | 2026 | [gov.uk] |
| BCR benchmarks | DfT VfM Framework; What Works Centre | 2024-2025 | [gov.uk, whatworksgrowth.org] |
[If WELLBY: "| WELLBY value | Green Book Wellbeing Guidance | 2021 | [gov.uk] |"]

### Limitations

1. **Evidence quality:** This evaluation is based on SMS Level [N] evidence. [If Level 1-2: "Without a credible counterfactual, the BCR may overstate or understate the true programme impact. External trends, selection effects, and regression to the mean cannot be ruled out."]
2. **Unit cost precision:** Unit costs are national averages. Actual costs in [programme location] may differ due to local service configuration, labour market conditions, and demographic factors.
3. **Benefit persistence:** [If assumptions made about future benefits: "The assumed benefit duration of [N] years is an estimate. Actual persistence depends on the sustainability of outcomes, which may be affected by external factors not captured in this evaluation."]
4. **Double-counting risk:** [If multiple outcome types monetised: "Where multiple outcome types are monetised, there is a risk that unit costs for different outcomes overlap (e.g., homelessness costs may include a health component). The unit costs used have been checked for overlap where documentation permits, but some residual double-counting risk remains."]
5. **Scope:** This evaluation covers the quantitative VfM assessment only. It does not replace a process evaluation, qualitative assessment, or strategic review of the programme's theory of change.

*This methodology annex was generated by econstack. All parameters, sources, and computations are documented in the companion JSON file (`vfm-data-{slug}-{date}.json`).*
```

**Slide summary:**
```markdown
**[Programme Name]: Value for Money Evaluation**

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
- **Table and figure formatting (universal across all econstack outputs):**
  - **Numbering**: Every table is "Table 1: [short description]", every figure/chart is "Figure 1: [short description]". Numbering restarts at 1 for each report. The caption goes above the table/figure.
  - **Source note**: Below every table and figure: "Source: [Author/Publisher] ([year])." If multiple sources: "Sources: [Source 1]; [Source 2]."
  - **Notes line**: Below the source, if needed: "Notes: [caveats, e.g. 'real 2026 prices', '2024-25 data', 'estimated from available figures']."
  - **Minimal formatting (low ink-to-data ratio)**: No heavy borders or gridlines. Thin rule under the header row only. No shading on data cells (light grey alternating rows permitted in Excel/HTML only). Right-align all numbers. Left-align all text. Bold totals rows only. No decorative elements.
  - **Number formatting**: Currency with comma separators and 1 decimal place for millions (e.g. "GBP 45.2m"), whole numbers for counts (e.g. "1,250 jobs"), percentages to 1 decimal place (e.g. "3.5%").
  - **Consistency**: The same metric must use the same unit and precision throughout the report. Do not switch between "GBP m" and "GBP bn" for the same order of magnitude.
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
