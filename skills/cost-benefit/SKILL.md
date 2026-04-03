---
name: cost-benefit
description: Green Book cost-benefit analysis. Discounting, NPV, BCR, optimism bias, sensitivity, switching values. Interactive options appraisal.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# /cost-benefit: Green Book Cost-Benefit Analysis

Scaffold and compute a cost-benefit analysis following HM Treasury Green Book methodology. Handles discounting (correct declining schedule), NPV, BCR, optimism bias, additionality, sensitivity analysis, and switching values. Generates a structured report matching the Five Case Model economic case.

**This skill is interactive.** It asks you about your project, takes your cost and benefit inputs, runs the computation, then asks what output you need.

The skill handles the computation and structure. You provide the substance (what the costs and benefits are, how they're monetised). This is the 80% that's identical in every CBA.

## Arguments

```
/cost-benefit [options]
```

**Examples:**
```
/cost-benefit
/cost-benefit --framework eu
/cost-benefit --full
```

**Options:**
- `--framework uk` : UK Green Book (default)
- `--framework eu` : EU Cohesion Policy CBA Guide (3% discount rate for advanced MS)
- `--full` : Skip interactive menus where possible
- `--client "Name"` : Add "Prepared for"
- `--format pdf` : Branded PDF output

## Instructions

### Step 1: Project setup

Ask the user using AskUserQuestion:

**Question 1:** "What type of appraisal is this?"

Options:
- A) **Infrastructure project** (buildings, transport, utilities, digital)
- B) **Policy or programme** (grant scheme, service change, regulatory)
- C) **Regulatory impact assessment**

**Question 2:** "What sector?"

Options:
- A) Transport
- B) Housing and regeneration
- C) Health and social care
- D) Education and skills
- E) Environment and energy
- F) Digital infrastructure
- G) Other

Based on answers, set defaults:

| Setting | Infrastructure | Policy/Programme | RIA |
|---------|---------------|-----------------|-----|
| Appraisal period | 60 years | 10 years | 10 years |
| Optimism bias (capex) | 24% (standard buildings) | 0% | 0% |
| Optimism bias (works) | 44% (standard civil eng) | 0% | 0% |

Tell the user the defaults and ask if they want to override:

```
DEFAULTS SET
============
Framework:        UK Green Book
Discount rate:    3.5% (declining: 3.0% after year 30, 2.5% after year 75)
Appraisal period: [X] years
Optimism bias:    [X]% on capex
Price base year:  2026

Override any of these? (Enter to accept defaults)
```

**Question 3:** "How many options are you appraising (including do-nothing)?"

Default: 3 (Do Nothing, Do Minimum, Preferred Option)

For each option, ask for: name and one-line description.

### Step 2: Cost and benefit entry

Ask using AskUserQuestion:

**Question:** "How do you want to enter costs and benefits?"

Options:
- A) **Summary figures** : Total capex, annual opex, annual benefit (I'll spread them over the appraisal period)
- B) **Year-by-year** : Paste a table with costs and benefits per year
- C) **I'll describe them** : Tell me the costs and benefits in words and I'll help structure them

**If A (summary figures):**

For each option (except Do Nothing), ask:
- Total capital cost (£, one-off or phased over how many years?)
- Annual operating cost (£/year, starting from which year?)
- Annual benefit (£/year, starting from which year? growing at what rate?)
- Any residual/terminal value at end of appraisal period?

**If B (year-by-year):**

Ask the user to paste or describe a table:
```
Year | Costs (£) | Benefits (£)
0    | 5000000   | 0
1    | 2000000   | 500000
2    | 200000    | 1000000
...
```

Parse the table. If costs and benefits are already broken into categories, preserve the breakdown.

**If C (describe):**

Ask the user to describe the costs and benefits in plain English. Then structure them into categories:

Costs:
- Capital/construction
- Operating/maintenance
- Transition/implementation

Benefits:
- Direct user benefits (time savings, cost savings, revenue)
- Wider economic benefits (employment, GVA, agglomeration)
- Environmental benefits (carbon, air quality, noise)
- Social benefits (health, safety, wellbeing)
- Non-monetised benefits (describe qualitatively)

For each benefit category, ask: "Can you estimate the annual value? If not, I'll note it as non-monetised."

### Step 3: Additionality adjustments

Ask: "Do you want to apply additionality adjustments to the benefits?"

Options:
- A) **Standard** (HM Treasury defaults: 20% deadweight, 25% displacement, 10% leakage)
- B) **Custom** (I'll specify my own rates)
- C) **None** (gross benefits, no adjustment)

If A, apply:
```
adjusted_benefit = benefit * (1 - 0.20) * (1 - 0.25) * (1 - 0.10) = benefit * 0.54
```

If B, ask for deadweight %, displacement %, leakage %, substitution %.

### Step 4: Compute

Run the following computations for each option vs Do Nothing:

**Discount factors:**
```
For t = 0 to appraisal_period:
  if t <= 30: r = 0.035
  elif t <= 75: r = 0.030
  elif t <= 125: r = 0.025
  elif t <= 200: r = 0.020
  elif t <= 300: r = 0.015
  else: r = 0.010

  discount_factor(t) = 1 / (1 + r)^t

  Note: for years beyond 30, the discount factor must be computed
  cumulatively, not by simply using the lower rate for all years.
  df(31) = df(30) / (1 + 0.030)
  df(32) = df(31) / (1 + 0.030)
  etc.
```

**Optimism bias:**
```
adjusted_capex = capex * (1 + optimism_bias_rate)
adjusted_opex = opex  (no optimism bias on opex unless user specifies)
```

**Present values:**
```
PV_costs = sum over t of [adjusted_cost(t) * discount_factor(t)]
PV_benefits = sum over t of [adjusted_benefit(t) * discount_factor(t)]
```

**Summary metrics:**
```
NPV = PV_benefits - PV_costs
BCR = PV_benefits / PV_costs

VfM category:
  BCR < 1.0  -> Poor
  1.0 - 1.5  -> Low
  1.5 - 2.0  -> Medium
  2.0 - 4.0  -> High
  > 4.0      -> Very High
```

**Switching values:**
For the top 2-3 cost/benefit items, compute the percentage change that would make NPV = 0:
```
switching_value_benefits = -NPV / PV_benefits * 100
  (benefits would need to fall by this % for NPV to reach zero)

switching_value_costs = NPV / PV_costs * 100
  (costs would need to rise by this % for NPV to reach zero)
```

**Sensitivity analysis:**
Run three scenarios:
- **Optimistic:** benefits +20%, costs -20%
- **Central:** as computed
- **Pessimistic:** benefits -20%, costs +20%

Compute NPV and BCR for each.

### Step 5: Show results and ask what the user needs

```
CBA RESULTS
============
                    Do Nothing    Do Minimum    Preferred
PV Costs (£m):     0             [val]         [val]
PV Benefits (£m):  0             [val]         [val]
NPV (£m):          0             [val]         [val]
BCR:               -             [val]         [val]
VfM:               -             [val]         [val]

Switching value (benefits): [val]% fall makes NPV = 0
Switching value (costs):    [val]% rise makes NPV = 0

Sensitivity:
              Pessimistic    Central    Optimistic
NPV (£m):    [val]          [val]      [val]
BCR:         [val]          [val]      [val]
```

**If `--full` was NOT specified**, ask using AskUserQuestion:

Question: "What output do you need?"

Options:
- A) **Full economic case** : All sections for a Five Case Model submission
- B) **Pick sections** : Choose what you need
- C) **Summary table only** : Just the numbers
- D) **Data only** : JSON with all computed values

**If user picks B** (multiSelect: true):

Options:
- Options summary (descriptions and rationale)
- Cost table (undiscounted and discounted, with optimism bias)
- Benefit table (undiscounted and discounted, with additionality)
- NPV and BCR comparison (all options, VfM categories)
- Switching values (what % change breaks the case)
- Sensitivity analysis (optimistic/central/pessimistic)
- Distributional note (who bears costs, who receives benefits)
- Appraisal summary table (one-page consolidated view)
- Methodology note (discount rate, optimism bias, additionality assumptions)
- References

### Step 6: Generate the requested output

**Always include key numbers block and companion JSON.**

#### Section templates

**Options summary:**
```markdown
## Options

| Option | Description |
|--------|------------|
| 1. Do Nothing | [Counterfactual: what happens without intervention] |
| 2. [Do Minimum] | [description] |
| 3. [Preferred] | [description] |

The counterfactual (Do Nothing) is not a static baseline. It projects forward what happens without intervention, including existing trends and committed policies.
```

**Cost table:**
```markdown
## Costs

All costs in [year] prices, discounted at the Green Book social time preference rate (3.5%, declining).

| Cost category | Undiscounted (£m) | Optimism bias | Adjusted (£m) | PV (£m) |
|--------------|-------------------|---------------|---------------|---------|
| Capital | [val] | [X]% | [val] | [val] |
| Operating (over [X] years) | [val] | 0% | [val] | [val] |
| **Total** | **[val]** | | **[val]** | **[val]** |

Optimism bias of [X]% applied to capital costs based on Green Book supplementary guidance for [project type]. This can be reduced as the project matures and risks are mitigated through the Reference Class Forecasting approach.
```

**Benefit table:**
```markdown
## Benefits

| Benefit category | Undiscounted (£m) | Additionality factor | Adjusted (£m) | PV (£m) |
|-----------------|-------------------|---------------------|---------------|---------|
| [Category 1] | [val] | [X]% | [val] | [val] |
| [Category 2] | [val] | [X]% | [val] | [val] |
| **Total monetised** | **[val]** | | **[val]** | **[val]** |

Additionality adjustments: [X]% deadweight, [X]% displacement, [X]% leakage (net factor: [X]%).

**Non-monetised benefits:**
- [Benefit described qualitatively with direction and estimated magnitude]
```

**NPV and BCR:**
```markdown
## Value for Money

| Metric | Do Nothing | [Option 2] | [Option 3] |
|--------|-----------|------------|------------|
| PV Costs (£m) | 0 | [val] | [val] |
| PV Benefits (£m) | 0 | [val] | [val] |
| **NPV (£m)** | **0** | **[val]** | **[val]** |
| **BCR** | - | **[val]** | **[val]** |
| **VfM category** | - | **[category]** | **[category]** |

[Preferred option] has an NPV of £[val]m and a BCR of [val], representing [category] value for money. [If non-monetised benefits are significant: "Accounting for non-monetised benefits (described above), the overall VfM case is [stronger/weaker] than the BCR alone suggests."]

Note: BCR thresholds are indicative, not deterministic. The Green Book (2026) states that a BCR below 1 may still represent value for money if non-monetised benefits are sufficiently strong.
```

**Switching values:**
```markdown
## Switching Values

| Variable | Central value | Switching value | Change required |
|----------|--------------|-----------------|-----------------|
| Total benefits | £[val]m PV | £[val]m PV | [val]% decrease |
| Total costs | £[val]m PV | £[val]m PV | [val]% increase |
| [Key benefit] | £[val]m PV | £[val]m PV | [val]% decrease |

Benefits would need to fall by [val]% (or costs rise by [val]%) for the preferred option to no longer represent positive value for money. [If switching value > 30%: "This suggests the case is robust to significant variation in assumptions." If < 15%: "The case is sensitive to assumptions. Small changes could alter the conclusion."]
```

**Sensitivity analysis:**
```markdown
## Sensitivity Analysis

| Scenario | Benefits | Costs | NPV (£m) | BCR |
|----------|----------|-------|----------|-----|
| Pessimistic (-20% benefits, +20% costs) | [val] | [val] | [val] | [val] |
| **Central** | **[val]** | **[val]** | **[val]** | **[val]** |
| Optimistic (+20% benefits, -20% costs) | [val] | [val] | [val] | [val] |

[Interpretation: does the option still represent positive VfM under pessimistic assumptions?]
```

**Appraisal summary table:**
```markdown
## Appraisal Summary Table

| Dimension | [Option 2] | [Option 3] |
|-----------|------------|------------|
| **Monetised (£m PV)** | | |
| Costs | [val] | [val] |
| Benefits | [val] | [val] |
| NPV | [val] | [val] |
| BCR | [val] | [val] |
| **Non-monetised** | | |
| [Benefit 1] | [Slight positive / Moderate positive / Large positive] | [assessment] |
| [Benefit 2] | [assessment] | [assessment] |
| **VfM assessment** | **[category]** | **[category]** |
```

**Methodology note:**
```markdown
**Methodology:** Social cost-benefit analysis following HM Treasury Green Book (2026). Discount rate: social time preference rate of 3.5% for years 0-30, declining to 3.0% for years 31-75, 2.5% for years 76-125. Optimism bias: [X]% on capital costs (Green Book supplementary guidance, [project type]). Additionality: [X]% deadweight, [X]% displacement, [X]% leakage (HM Treasury Additionality Guide, 4th edition, 2014). All costs and benefits in [year] real prices. NPV and BCR computed for each option against the Do Nothing counterfactual.
```

**References:**
```markdown
## References

- HM Treasury (2026). "The Green Book: Central Government Guidance on Appraisal and Evaluation."
- HM Treasury. "Green Book supplementary guidance: optimism bias."
- HM Treasury. "Green Book supplementary guidance: discounting."
- HM Treasury (2014). "Additionality Guide", 4th edition.
- MHCLG (2025). "The Appraisal Guide", 3rd edition.
- Boardman, A.E. et al. (2018). "Cost-Benefit Analysis: Concepts and Practice", 5th edition. Cambridge University Press.
```

**Slide summary:**
```markdown
**[Project Name] — Value for Money Summary**

- **Preferred option:** [name]
- **NPV: £[val]m** | **BCR: [val]** | **VfM: [category]**
- PV costs £[val]m (including [X]% optimism bias on capex)
- PV benefits £[val]m (net of additionality: [X]% factor)
- Switching value: benefits would need to fall **[val]%** for NPV to turn negative
- [One sentence on robustness: "Positive NPV maintained under pessimistic assumptions" or "Sensitive to benefit estimates"]

*Green Book methodology. [Year] prices. [X]-year appraisal period.*
```

### Step 7: Save and present

Save as `cba-{project-slug}-{date}.md`. Always save `cba-data-{project-slug}-{date}.json`.

The JSON includes all inputs, computed discount factors, year-by-year PV schedule, summary metrics, sensitivity results, and switching values.

If `--format pdf`, render through the template:
```bash
ECONSTACK_DIR="${CLAUDE_SKILL_DIR}/../.."
"$ECONSTACK_DIR/scripts/render-report.sh" cba-{project-slug}-{date}.md \
  --title "Cost-Benefit Analysis" \
  --subtitle "[Project name]"
```

## Important Rules

- Never use em dashes.
- Never attribute econstack to any individual.
- Every section stands alone.
- **Discount rate must use the correct declining schedule.** Do not apply 3.5% flat beyond year 30. This is the most common CBA error.
- **Optimism bias must not be zero** for infrastructure projects unless the user explicitly overrides with justification. Flag it if they set it to 0.
- **Do not double count.** If a benefit appears in two categories (e.g., journey time savings AND land value uplift that derives from those savings), flag the potential overlap.
- **Transfers are not costs or benefits.** Taxes, subsidies, and grants are transfers between parties. They cancel at the societal level in social CBA. Only include them in financial CBA.
- **Sunk costs are excluded.** Costs already incurred that cannot be recovered should not be included.
- **NPV is the primary metric, not BCR.** The Green Book is clear: NPV determines the ranking. BCR is supplementary. A project with higher NPV but lower BCR is preferred.
- **Always compute switching values.** They are the most useful output for decision-makers because they answer "how wrong can we be before this stops being worth doing?"
- Be specific about price base year, appraisal period, and which Green Book edition.
- The companion JSON must include the full year-by-year discounted cost/benefit schedule.
