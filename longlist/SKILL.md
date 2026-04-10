---
name: longlist
description: Brainstorm a longlist of benefit streams, cost categories, and beneficiaries for a project. Applies stakeholder mapping, Theory of Change, market failure, and sector template lenses. Classifies by materiality and deadweight risk. Hands off to cost-benefit, business-case, vfm-eval, or reg-impact.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
  - Skill
---

**Only stop to ask the user when:** project description is unclear, a candidate benefit needs user confirmation, or the user has reached the end of a lens and needs to decide whether to proceed.
**Never stop to ask about:** formatting, section ordering, default lens application, or output filename.
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

# /longlist: Benefits and Costs Longlist Brainstorming

The messy-whiteboard-phase skill. Before you can run a CBA, a business case, or an RIA, you need to know what benefits to measure and what costs to include. This skill helps you think through both, systematically, using multiple lenses. It generates a longlist, classifies each item, and hands off to `/cost-benefit`, `/business-case`, `/vfm-eval`, or `/reg-impact` with the structure ready to fill in.

```
/longlist       = "Help me think through all the possible benefits and costs"
     ↓
/cost-benefit   = "Now monetise and compute NPV for this list"
     ↓
/business-case  = "Wrap the CBA in the full Five Case Model"
```

The name follows the standard Treasury/consulting distinction between a *longlist* (everything you might include) and a *shortlist* (what actually makes it into the appraisal). This skill produces the longlist. `/cost-benefit` produces the shortlist.

**This skill is interactive.** It asks about the project, then applies each lens in turn, building the longlist as it goes.

## Arguments

```
/longlist [project description] [options]
```

**Examples:**
```
/longlist "New secondary school in Leeds"
/longlist "Victorian Level Crossing Removal" --framework au-vic
/longlist "Regulation to mandate climate disclosure" --framework uk-brg
/longlist "Rural broadband rollout" --scope broad
/longlist --from inputs.json
```

**Options:**
- `--framework <name>` : Align to a specific framework. Auto-detected from context, or explicitly set. See table below.
- `--scope <level>` : `narrow` (direct effects only), `standard` (default, direct + indirect), `broad` (direct + indirect + wider economic impacts + wellbeing).
- `--sector <type>` : Force a specific sector (schools, hospitals, transport, housing, employment, digital, environment). Otherwise auto-detected.
- `--costs-only` : Skip benefits, only brainstorm costs.
- `--benefits-only` : Skip costs, only brainstorm benefits.
- `--quick` : 3 lenses instead of 6. Faster but less comprehensive.
- `--full` : Skip interactive menus, apply all lenses, produce final output.
- `--format <type>` : Output: `markdown`, `word`, `xlsx`, `pdf`. Default: markdown.
- `--client "Name"` : Add "Prepared for" metadata.
- `--from <file.json>` : Import inputs from JSON. Use `--from schema` to print expected schema.

**Supported frameworks:**

| Flag | Framework | Source | Taxonomy used |
|------|-----------|--------|--------------|
| `uk-gb` | UK HM Treasury Green Book (default) | Green Book 2026 | Cash-releasing, non-cash quantifiable, non-cash qualitative, wider economic impacts, distributional |
| `uk-brg` | UK Better Regulation Framework | BRG, RPC guidance | Business compliance costs (SCM), familiarisation, direct benefits to business, consumer benefits, environmental, social |
| `uk-mhclg` | MHCLG Appraisal Guide | DLUHC (2025) | Housing, regeneration, land value, health, social cohesion |
| `au-oia` | Australian OIA / Commonwealth | OIA Impact Analysis Guide | Net community benefit, business impacts, consumer impacts, environmental, distributional |
| `au-vic` | Victoria DTF | Investment Lifecycle Guidelines | Project benefits by the IMS benefit hierarchy |
| `eu-brt` | EU Better Regulation Toolbox | EC guidance | Economic, social, environmental impacts |
| `oecd-dac` | OECD DAC criteria | 2019 revision | Relevance, effectiveness, efficiency, impact, sustainability benefits |
| `agnostic` | Framework-agnostic | Universal | Direct/indirect only, no taxonomy overlay |

## Instructions

### Step 0: Setup and framework detection

0a. Load parameters from `$PARAMS_DIR` if available. Check for reference cases in `$PARAMS_DIR/reference-cases/` that might match the project description.

0b. Auto-detect framework from context:
- "UK", "Green Book", "GBP", "HMT" -> `uk-gb`
- "regulation", "RIA", "compliance cost", "RPC", "EANDCB" -> `uk-brg`
- "housing", "regeneration", "MHCLG", "DLUHC", "Land Value Estimates" -> `uk-mhclg`
- "Australia", "AUD", "OIA", "Commonwealth" (no state) -> `au-oia`
- "Victoria", "VIC", "DTF", "HVHR" -> `au-vic`
- "EU", "Better Regulation Toolbox", "EUR" -> `eu-brt`
- "DAC", "development", "international development" -> `oecd-dac`
- If no signal: ask via AskUserQuestion with `uk-gb` recommended

0c. If `--from` provided, skip to Step 6 (classification and output).

### Step 1: Project description

```
AskUserQuestion: "Describe the project or intervention in 2-3 sentences. What is it, where, and what is it trying to achieve?"
(Free text)
```

Parse the description for:
- **Sector signals**: school, hospital, road, rail, housing, employment programme, digital, environmental, regulation
- **Scale signals**: pilot, local, regional, national, international
- **Type signals**: infrastructure, programme, regulation, reform, investment

Confirm the detection:
```
AskUserQuestion: "I've detected this as a [sector] [type] project at [scale] scale. Is this right?"
Options:
  - "Yes" (Recommended)
  - "Change sector"
  - "Change type"
  - "Change scale"
```

### Step 2: Counterfactual (do nothing baseline)

Before listing benefits, establish the counterfactual. This is the single most important step: benefits are always INCREMENTAL to the counterfactual, not absolute.

```
AskUserQuestion: "What happens if the project does NOT go ahead? (The 'do nothing' or 'do minimum' scenario.)"
(Free text)
```

Prompt for specifics:
```
AskUserQuestion: "Under 'do nothing', what changes over time without intervention? (e.g., deterioration of existing assets, demand growth, committed policies, regulatory changes already in the pipeline)"
(Free text)
```

Store this counterfactual. Every benefit will be framed as "the difference between project and counterfactual".

### Step 3: Apply brainstorming lenses

Run through 6 lenses in sequence (or 3 if `--quick`). After each lens, the user can add/remove candidates and the skill builds up the running longlist.

**LENS 1: Stakeholder mapping (who is affected?)**

```
AskUserQuestion: "Who are the direct users of this project? (The people/organisations the project is explicitly designed for)"
(Free text)
```

```
AskUserQuestion: "Who is indirectly affected? (Supply chain, neighbours, adjacent users, taxpayers, future generations, competitors)"
(Free text)
```

For each stakeholder, ask: "How does this group gain or lose?" Then categorise the resulting effects into benefits and costs.

Prompt the user through standard beneficiary categories:
- Direct users (primary beneficiary)
- Indirect users (secondary beneficiary)
- Suppliers and supply chain
- Neighbours and community
- Competing providers (potential loss)
- Government (fiscal effects)
- Taxpayers (who pays)
- Future generations (long-term effects)
- Environment (non-human beneficiaries)

**LENS 2: Market failure framing (what failure does this address?)**

```
AskUserQuestion: "What market or government failure is this project addressing?"
Options:
  - "Externality (costs/benefits not captured by the market)"
  - "Public good (non-excludable, non-rivalrous)"
  - "Information asymmetry (one party has better info)"
  - "Coordination failure (parties cannot coordinate without intervention)"
  - "Market power (monopoly, oligopoly)"
  - "Distributional (outcome is inequitable)"
  - "Multiple failures"
```

Each failure type implies specific benefit types. Suggest candidates:

- **Externality**: Reduced negative externality (emissions, noise, congestion) OR increased positive externality (knowledge spillovers, herd immunity, network effects)
- **Public good**: Non-rival consumption value, option value, existence value
- **Information asymmetry**: Better-informed decisions, reduced search costs, reduced fraud
- **Coordination failure**: Network effects, interoperability, reduced duplication
- **Market power**: Lower prices, increased choice, innovation
- **Distributional**: Transfers to disadvantaged groups (with distributional weights if using Green Book)

**LENS 3: Theory of Change (the causal chain)**

Build a quick ToC to surface benefits at each level:

```
AskUserQuestion: "INPUTS: What goes into the project? (funding, staff, equipment, land, time)"
AskUserQuestion: "ACTIVITIES: What does the project do? (build, train, regulate, deliver)"
AskUserQuestion: "OUTPUTS: What does it produce? (physical assets, services delivered, regulations enacted)"
AskUserQuestion: "OUTCOMES: What changes result? (behaviour changes, condition changes, performance changes)"
AskUserQuestion: "IMPACT: What long-term change is expected? (societal, environmental, economic)"
```

At each level, ask: "What benefits arise at this stage?" Outputs tend to generate operational benefits (utilisation, reach). Outcomes generate the main social benefits. Impact captures long-term and wider economic effects.

Also prompt at each level: "What costs arise at this stage?" Inputs are capital. Activities are operating costs. Outputs often have maintenance costs.

**LENS 4: Framework-specific taxonomy**

Apply the taxonomy from the selected framework. This catches benefits that might be invisible through other lenses.

**For `uk-gb` (Green Book):**
Walk through each category:
- Cash-releasing (direct budget savings)
- Non-cash releasing quantifiable (outputs delivered, people supported, incidents avoided)
- Non-cash qualitative (quality, safety, satisfaction)
- Wider economic impacts (agglomeration, labour supply, imperfect competition) [only if `--scope broad`]
- Distributional (impacts on low-income, protected characteristics, specific regions)
- Wellbeing (WELLBY valuation for health, social care, community programmes)
- Carbon and environmental (use DESNZ carbon values)

```
AskUserQuestion: "For each Green Book category, are there benefits we haven't captured yet?"
```

**For `uk-brg` (Better Regulation):**
- Business compliance costs (direct costs on business): these are the main COSTS in an RIA
- Familiarisation costs (reading and understanding the regulation)
- Direct benefits to business (cost savings, productivity, reduced uncertainty)
- Consumer benefits (lower prices, quality, safety, choice)
- Environmental benefits
- Social benefits
- Indirect costs (administrative burden, reduced competition, innovation effects)
- Distributional effects (small businesses, specific sectors)

Use the Standard Cost Model (SCM) for compliance cost estimation: compliance cost = affected businesses x time per business x hourly cost x frequency.

**For `au-oia`:**
- Net community benefit (the headline test)
- Business impacts (compliance, productivity, competitiveness)
- Consumer impacts (prices, choice, safety)
- Environmental impacts
- Distributional (including Indigenous communities)
- Intergenerational (under the Intergenerational Report framework)

**For `au-vic`:**
- Investment Management Standards benefit hierarchy
- KPIs and benefit measures (DTF requires measurable benefits)
- Strategic benefits vs tactical benefits
- Cost savings, revenue generation, risk reduction

**For `eu-brt`:**
- Economic impacts (GDP, employment, productivity, innovation)
- Social impacts (equality, access, labour market, health)
- Environmental impacts (climate, biodiversity, resource use)
- Fundamental rights and impact on SMEs

**For `oecd-dac`:**
- Relevance benefits (addressing beneficiary needs)
- Effectiveness benefits (achieving objectives)
- Efficiency benefits (lower cost per outcome)
- Impact benefits (higher-level positive effects)
- Sustainability benefits (persistence after intervention)

**LENS 5: Sector-specific benefit library**

If a reference case exists for this sector in `$PARAMS_DIR/reference-cases/`, load it and walk through the typical benefits for that asset type.

Read the relevant reference case file:
```bash
cat "$PARAMS_DIR/reference-cases/uk-school-new-build.json"
# Or au-transport-infrastructure.json, uk-hospital-ward.json, etc.
```

For each benefit listed in the reference case, ask the user if it applies to their project. This catches benefits economists commonly miss for that sector.

**Default sector libraries (if no reference case matches):**

- **Schools**: Educational attainment, reduced travel time, community use, health and wellbeing, safety improvements. (Construction employment is usually a double-counting trap; see Important Rules.)
- **Hospitals**: QALYs, reduced wait times, reduced emergency admissions, staff productivity, patient/visitor travel time. (Construction employment: same caveat.)
- **Transport**: Journey time savings, VOC savings, accident reduction, reliability improvements, WEIs (supplementary), operational carbon change, embodied construction emissions (cost side), induced demand caveat. Do not count journey time savings AND land value uplift together (the land value capitalises the time savings).
- **Housing**: Housing supply, reduced homelessness costs, health benefits, employment, community infrastructure, land value uplift. Note: council tax revenue is a *transfer* from residents to the council, not a net social benefit; include only in fiscal analysis, not social CBA.
- **Employment programmes**:
  - *Social benefits*: Individual earnings uplift (gross of tax), health/wellbeing improvements, reduced crime, qualification attainment
  - *Fiscal savings* (also counted as social benefits, because they free up real resources): avoided welfare spend, avoided NHS costs, avoided criminal justice costs
  - *Transfers* (include only in fiscal-only analysis, NOT social CBA): income tax and NI receipts on newly-earned earnings. Tax revenue is a transfer from worker to state, not a net social benefit. If both the gross earnings and the tax on those earnings are counted, that is double counting.
  - Deadweight for employment programmes is typically 30-50%: not all observed employment changes are caused by the programme.
- **Digital transformation**: Staff efficiency, error reduction, citizen time savings, fraud reduction, legacy system decommissioning. Reference class: IT project cost overruns average 35% (Flyvbjerg); flag accordingly.
- **Environmental**:
  - *Operational benefits*: Carbon reductions (operational), air quality, biodiversity, water quality, flood risk reduction, amenity, ecosystem services
  - *Construction-phase costs*: Embodied construction emissions (valued at DESNZ shadow price), habitat disturbance
  - Always split carbon into embodied (construction) and operational (in-use). Embodied may offset operational savings for 10-20 years depending on the asset type.
- **Regulation**: Compliance costs (primary cost, use Standard Cost Model), direct benefits (what the regulation achieves), consumer benefits, competition effects, innovation effects. Do not double count: if you net business efficiency gains against compliance costs, do not also list business efficiency as a separate benefit.

**LENS 6: "Have you considered..." nudges (commonly missed benefits)**

Run through a checklist of frequently overlooked items:

- Construction phase employment and IO multiplier effects (flag: usually a double-counting trap, see Important Rules)
- Avoided costs under the counterfactual (what we'd pay if we didn't do this)
- Option value (flexibility to respond to future conditions)
- Learning and knowledge spillovers
- Network effects (value increases with users)
- Wellbeing effects (WELLBY, if relevant)
- Carbon impacts: split into embodied (construction) and operational (in-use)
- Equity and distributional effects
- Community cohesion / social capital
- Risk reduction (tail risks avoided)
- Agglomeration effects (if broad scope)
- Competitive effects on other providers
- Induced demand (for transport)
- Displacement (would someone else have provided this?)
- Leakage (do benefits flow outside the target area or beneficiary group?)

**Benefit optimism check (Flyvbjerg).** Published ex-post evaluations of transport projects find benefits are overstated by 50% on average (Flyvbjerg 2005). Similar biases have been documented for sports facilities (Crompton 1995) and employment programmes. Ask the user:
```
AskUserQuestion: "For this project's headline benefits, is there published ex-post evidence from comparable projects that supports the magnitudes you're expecting? Or are the benefit estimates drawn from ex-ante modelling assumptions?"
Options:
  - "Ex-post evidence from comparable projects"
  - "Ex-ante modelling only"
  - "Mix of both"
```
If "ex-ante only", flag the top 3 benefits as "Deadweight risk: Medium or higher" and add a note in the methodology section. Do not reduce magnitudes here (that happens in `/cost-benefit`).
REF: Flyvbjerg, B. (2005), "Measuring inaccuracy in travel demand forecasting", Transport Reviews 25(5); Crompton, J.L. (1995), "Economic Impact Analysis of Sports Facilities and Events", Journal of Sport Management 9(1).

```
AskUserQuestion: "I'll check a list of commonly overlooked items. Tell me which apply to your project."
```

For each item the user confirms, add to the longlist. For each item the user rejects, note why in the methodology section.

### Step 4: Cost brainstorming

If `--benefits-only` was specified, skip to Step 5.

Apply the same structured approach to costs:

**LENS A: Direct project costs**

- Capital costs (construction, equipment, land, professional fees, contingency, optimism bias)
- Operating costs (staffing, maintenance, utilities, consumables)
- Decommissioning costs (end-of-life)
- One-off transition costs (setup, training, change management)

**Exclude sunk costs.** Do NOT include costs already incurred that cannot be recovered (prior feasibility spend, earlier study costs, land already purchased). Sunk costs are irrelevant to the forward-looking decision per Green Book 2022 §5.17. If the user mentions sunk costs, record them as context but do not enter them into the cost longlist.

**Reference class forecasting prompt (Flyvbjerg).** Ask the user:
```
AskUserQuestion: "Capital cost estimates are systematically optimistic. Flyvbjerg et al. (2003) found typical overruns of 28% for roads, 45% for rail, 20% for buildings, and 35% for IT. Has your capital cost estimate been benchmarked against comparable completed projects, or is it a bottom-up engineering estimate?"
Options:
  - "Benchmarked against comparable projects"
  - "Bottom-up engineering estimate"
  - "Order-of-magnitude guess"
```
If "bottom-up" or "order-of-magnitude", flag capital cost certainty as "Estimated" or "Uncertain" in the classification and note in the methodology section that reference class forecasting has not been applied. This is for the brainstorm only; the actual optimism bias uplift is applied in `/cost-benefit`.
REF: Flyvbjerg, B., Bruzelius, N., Rothengatter, W. (2003), "Megaprojects and Risk", Cambridge University Press.

**LENS B: Indirect and induced costs**

- Transition disruption (construction disruption, service interruption during change)
- Displacement costs (activity lost from elsewhere)
- Opportunity cost of capital
- Monitoring and evaluation costs (typically 1-5% of programme budget)

**LENS C: Compliance and regulatory costs (if regulation)**

Use the Standard Cost Model:
```
Compliance cost = Number of affected businesses
                  x (staff time per business x hourly cost) + direct costs
                  x frequency per year
```

Components:
- Staff time (reading, understanding, implementing, reporting)
- Equipment or system upgrades
- Certification or audit fees
- Familiarisation (one-off)
- Ongoing compliance (annual)

**LENS D: Costs to other parties**

- Consumers (if prices go up)
- Suppliers (if requirements change)
- Competitors (negative spillover effects)
- Future users (intergenerational cost transfers)
- Environment (negative externalities created)

**LENS E: Risk costs**

- Expected value of risks (probability x impact)
- Risk contingency
- Insurance and bonding
- Reserve for known unknowns

### Step 5: Consolidate longlist

Compile the running list of benefits and costs captured across all lenses. Remove duplicates. Merge closely related items.

Present the preliminary longlist for user review:
```
AskUserQuestion: "Here is the longlist of [N] benefits and [M] costs. Review it, remove any that don't apply, and add any we missed."
```

Target longlist size:
- `--quick` mode: 10-15 items
- Standard: 20-30 items
- `--scope broad`: 30-50 items

### Step 6: Classify each item

For each item in the longlist, apply multiple classification axes.

**Axes for BENEFITS:**

| Axis | Values |
|------|--------|
| Description | One-sentence plain-English explanation of the benefit and who receives it |
| Beneficiary type | Direct user / Indirect / Supply chain / Community / Government / Environment |
| Primary/secondary | Primary (intended beneficiary) / Secondary (side effect) |
| Direction | Direct (immediate) / Indirect (via another actor or market) |
| Monetisation | Cash-releasing / Monetisable via unit value / Quantifiable but not monetised / Qualitative |
| **How to quantify / monetise** | Brief suggested method for estimating the benefit. Accepts any of five method types: (1) **published unit value** with a specific data source and URL (e.g. "TAG journey time values × hours saved × annual trips — [DfT TAG Data Book](https://www.gov.uk/government/publications/tag-data-book)"); (2) **analytical approach** (e.g. "hedonic pricing on local house prices pre/post", "contingent valuation study", "revealed preference via travel cost method", "structural gravity model"); (3) **primary research** (e.g. "semi-structured interviews with 20 beneficiaries", "willingness-to-pay survey, sample 400, stratified by income", "Delphi panel of 8 sector experts"); (4) **benchmarking / comparables** (e.g. "triangulate against published ex-post evaluation of [similar project]", "regional comparables from ONS LA data"); (5) **modelled** (e.g. "econometric model of wage premium using LFS microdata", "ONS IO multipliers × sector output"). See the Quantification Method Library below. For items where no good method exists, record "Qualitative only — narrative treatment" and mark monetisation as Qualitative. |
| Materiality | H (top 3-5 benefits, >20% of total) / M (5-20%) / L (<5%, often non-monetised) |
| Deadweight risk | Low (clearly incremental) / Medium (partial overlap with BAU) / High (largely would have happened anyway) |
| Dependencies | Independent / Conditional on [other benefit] / Overlapping with [other benefit] (flag if this benefit is already implicit in another line) |
| Timing | Construction phase / Ramp-up phase / Steady-state / Long-term |
| Evidence base | Strong (published unit values) / Moderate (indirect evidence) / Weak (assumption-based) |
| CBA contender | **Strong** (high materiality, low deadweight, monetisable, strong evidence, independent) / **Moderate** (medium materiality OR some deadweight OR indirect evidence) / **Weak** (low materiality OR high deadweight OR qualitative OR weak evidence OR dependent on another benefit) |
| Include in CBA? | Yes (strong contender, include in core) / Supplementary (moderate, include with caveats) / No (weak, excluded with reason) |

The **CBA contender** rating is the headline output: it synthesises materiality, deadweight risk, evidence strength, and dependency into a simple three-way flag. Derivation rule:
- **Strong**: materiality = H AND deadweight risk = Low AND evidence = Strong AND dependencies = Independent AND monetisation in {cash-releasing, monetisable}
- **Weak**: materiality = L OR deadweight risk = High OR evidence = Weak OR dependencies != Independent OR monetisation = Qualitative
- **Moderate**: everything else

**Axes for COSTS:**

| Axis | Values |
|------|--------|
| Description | One-sentence plain-English explanation of the cost and who bears it |
| Cost type | Capital / Operating / One-off / Ongoing / Transfer (flag transfers as NOT to include in social CBA) |
| Payer | Government / Users / Business / Consumers / Other |
| Direction | Direct / Indirect |
| Certainty | Known / Estimated / Uncertain |
| **How to quantify / monetise** | Brief suggested method. Accepts the same five method types as benefits: (1) published unit value with data source and URL (e.g. "BCIS £/sqm × GIA"); (2) analytical approach (e.g. "Standard Cost Model formula", "bottom-up quantity surveyor estimate"); (3) primary research (e.g. "survey of 50 affected businesses on compliance time"); (4) benchmarking (e.g. "Flyvbjerg reference class forecasting against comparable rail projects"); (5) modelled (e.g. "whole life carbon assessment per RICS methodology"). See the Quantification Method Library below. |
| Timing | Construction / Ramp-up / Steady-state / Decommissioning |
| Materiality | H / M / L |
| CBA contender | **Strong** (direct, known or estimated, H materiality) / **Moderate** (indirect OR M materiality) / **Weak** (L materiality OR uncertain OR transfer) |
| Include in CBA? | Yes / Supplementary / No (with reason) |

For each item, present the axes and let the user classify (or accept the skill's suggestion). The skill should pre-fill the "How to quantify / monetise" field by looking up the item against the Quantification Method Library below, and let the user override.

```
AskUserQuestion: "For [item]: I suggest [direct/indirect], [primary/secondary], [monetisation type], [H/M/L materiality]. Quantification method: [suggested method from library]. Accept or change?"
Options:
  - "Accept"
  - "Change quantification method"
  - "Change direct/indirect"
  - "Change monetisation"
  - "Change materiality"
  - "Remove from longlist"
```

Use `--full` mode to auto-classify without prompting.

### Quantification Method Library

The skill references this library when suggesting a method for each longlist item. Methods span five types: published unit values (cite source and URL), analytical approaches, primary research, benchmarking, and modelled estimates. Where a method refers to a loaded parameter file, the suggestion should include the `$PARAMS_DIR` path so that `/cost-benefit` can load the same parameters downstream.

**Transport benefits:**
- *Journey time savings* (unit value): TAG values per minute by trip purpose × minutes saved × annual trips. Load `$PARAMS_DIR/uk/tag-values.json`. Source: [DfT TAG Data Book](https://www.gov.uk/government/publications/tag-data-book).
- *Accident reduction* (unit value): TAG casualty unit costs by severity × casualties avoided. Source: DfT TAG A4.1.
- *Reliability improvements* (modelled): Reliability ratio × standard deviation of journey time × trips, per TAG Unit A1.3.
- *Vehicle operating cost savings* (unit value): TAG VOC formula by vehicle type × vehicle-km.
- *Agglomeration (WEI)* (modelled): Effective density elasticity × change in effective density, per TAG Unit A2.4. Supplementary only.
- *Carbon operational* (unit value): DESNZ shadow carbon price × tCO2e by year. Load `$PARAMS_DIR/uk/carbon-values.json`. Source: [DESNZ Valuation of GHG Emissions](https://www.gov.uk/government/publications/valuation-of-greenhouse-gas-emissions-for-policy-appraisal-and-evaluation).

**Health benefits:**
- *QALYs gained* (unit value): GBP 70,000/QALY (Green Book supplementary) or GBP 20,000-30,000/QALY (NICE threshold, used for health technology appraisal). Cite which. Source: [Green Book supplementary guidance on wellbeing](https://www.gov.uk/government/publications/green-book-supplementary-guidance-wellbeing).
- *Reduced emergency admissions* (unit value): NHS Reference Costs (HRG-level) × admissions avoided. Source: [NHS England Reference Costs](https://www.england.nhs.uk/costing-in-the-nhs/national-cost-collection/).
- *Mental health improvements* (unit value or survey): PSSRU unit costs for mental health services, OR primary WEMWBS survey of beneficiaries.
- *Wellbeing (WELLBY)* (unit value): GBP 13,000 per WELLBY (1-point life satisfaction uplift × 1 person × 1 year). Source: HMT Green Book Supplementary Guidance: Wellbeing (2021).

**Employment and skills benefits:**
- *Individual earnings uplift* (modelled or unit value): Published wage premium by qualification (e.g. Level 3 = GBP 3,200/year lifetime NPV uplift, BIS 2011) × participants × deadweight-adjusted success rate.
- *Fiscal savings — avoided benefits* (unit value): GMCA unit cost: avoided JSA + Universal Credit + housing benefit × person-years unemployed avoided. Load `$PARAMS_DIR/uk/gmca-unit-costs-full.json`. Source: [GMCA Unit Cost Database](https://www.greatermanchester-ca.gov.uk/what-we-do/research/research-cost-benefit-analysis/).
- *Fiscal savings — avoided NHS costs* (unit value): GMCA NHS unit costs × utilisation reduction.
- *Fiscal savings — avoided criminal justice costs* (unit value): Home Office HORR99 unit costs by offence type × offences avoided. Source: [Home Office Research Report 99](https://www.gov.uk/government/publications/the-economic-and-social-costs-of-crime).
- *Productivity gain* (analytical): Matched difference-in-differences on payroll data, OR firm-level survey of labour productivity.

**Housing and place benefits:**
- *Land value uplift* (unit value): MHCLG Land Value Estimates × hectares × uplift factor. Source: [MHCLG Land Value Estimates for Policy Appraisal](https://www.gov.uk/government/publications/land-value-estimates-for-policy-appraisal).
- *Reduced homelessness costs* (unit value): Crisis/MHCLG unit cost per homeless household × households avoided. Source: Crisis "At what cost" (2015).
- *Health uplift from housing* (analytical): Published meta-analyses of housing-health effects (BRE 2021) applied to cohort size.
- *Amenity / community cohesion* (survey): WEMWBS or ONS4 wellbeing survey pre/post, OR hedonic pricing on nearby properties.

**Education and children's services benefits:**
- *Educational attainment uplift* (modelled): DfE earnings returns by qualification level × deadweight-adjusted cohort. Source: [DfE Returns to Qualifications](https://www.gov.uk/government/publications/returns-to-qualifications-at-ages-26-30-and-34).
- *Reduced SEND / looked-after children costs* (unit value): Department for Education / CIPFA unit costs per placement × placements avoided.
- *School travel time* (unit value): TAG values, as for transport.

**Environmental benefits:**
- *Carbon operational* (unit value): DESNZ shadow carbon price × tCO2e. As above.
- *Air quality* (unit value): Defra air quality damage costs × pollutant reduction. Source: [Defra Air Quality Damage Costs Guidance](https://www.gov.uk/government/publications/assess-the-impact-of-air-quality).
- *Biodiversity net gain* (unit value): Natural England BNG metric × statutory units, OR published values from Defra ENCA.
- *Flood risk reduction* (modelled): EA Flood Damage Costs × probability × properties protected. Source: [EA Flood and Coastal Erosion Risk Management Appraisal Guidance](https://www.gov.uk/government/publications/flood-and-coastal-erosion-risk-management-appraisal-guidance).
- *Ecosystem services* (unit value or analytical): Defra ENCA guidebook values, OR primary contingent valuation study.
- *Amenity value of green space* (unit value or survey): Defra ENCA green space values, OR hedonic pricing on property prices.

**Digital and service benefits:**
- *Staff time saved* (unit value): ONS ASHE hourly wages × hours saved × FTEs. Source: [ONS Annual Survey of Hours and Earnings](https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/earningsandworkinghours/bulletins/annualsurveyofhoursandearnings/latest).
- *Citizen time saved* (unit value): TAG non-work time values × hours saved × users.
- *Error reduction* (analytical): Historical error rate × cost per error (bottom-up estimate), OR published error-rate benchmarks.
- *Fraud reduction* (analytical): Cabinet Office Fraud Strategy unit values × cases avoided.

**Regulatory benefits (Better Regulation):**
- *Direct business benefits* (analytical or survey): Standard Cost Model applied to savings side, OR survey of affected businesses.
- *Consumer benefits: lower prices* (modelled): Price elasticity × price change × market size.
- *Consumer benefits: better information* (analytical): Willingness-to-pay from stated preference study, OR revealed preference via market outcomes.
- *Safety improvements* (unit value): VPF (value of preventing a fatality) × fatalities avoided. GBP 2.35M per fatality (DfT TAG).
- *Competition effects* (modelled): Simulation of price-cost margins, OR natural experiment from comparable markets.

**Construction and project costs:**
- *Capital construction* (unit value): BCIS £/sqm × GIA × building type factor. Load `$PARAMS_DIR/uk/construction-benchmarks.json`. Source: [BCIS Online](https://service.bcis.co.uk/). Australia: Rawlinsons Construction Cost Guide.
- *Land acquisition* (unit value or primary): VOA market comparables, OR district valuer primary assessment.
- *Professional fees* (unit value): Typically 10-15% of capex (RICS guidance).
- *Operating and maintenance* (unit value or analytical): BCIS FM benchmarks, OR historical ratio (2-5% of capex per year), OR bottom-up FM contract pricing.
- *Optimism bias* (unit value): HMT Supplementary Guidance Table 1 percentages by project type and stage. Load `$PARAMS_DIR/uk/optimism-bias.json`.
- *Embodied construction carbon* (modelled): RICS Whole Life Carbon Assessment methodology × capex intensity factors × DESNZ shadow price.
- *Risk costs* (analytical): Monte Carlo over risk register, OR P50/P90 contingency from Flyvbjerg reference class.

**Compliance costs (Better Regulation):**
- *Familiarisation costs* (unit value): Standard Cost Model: affected businesses × hours to read × median wage. Source: [BEIS Better Regulation Framework Manual](https://www.gov.uk/government/publications/better-regulation-framework).
- *Ongoing compliance* (unit value): Standard Cost Model: affected businesses × annual hours × wage rate + direct costs × frequency.
- *Administrative burden reduction* (unit value): Same SCM, applied to savings side.

**Qualitative-only items:**
- *Community cohesion, social capital, cultural value*: Qualitative only, narrative treatment. Flag in the CBA as supplementary and describe direction and magnitude only.
- *Fundamental rights, dignity, procedural fairness*: Qualitative only. Cite any rights-based frameworks (e.g. Equality Act) but do not attempt monetisation.

**When no library entry matches:** Suggest the closest analogue, OR propose a primary research method (interviews, survey, Delphi panel, case studies), OR recommend a benchmarking approach against a published ex-post evaluation of a comparable project. Never leave the field blank — even "Qualitative only, narrative treatment" is a valid entry.

If the user's project uses a non-UK framework, substitute the equivalent sources: NZ CBAx parameters for New Zealand, EU Better Regulation Toolbox for EU, OMB Circular A-4 and EPA BenMAP for US, ATAP for Australian transport, etc. The skill should auto-suggest framework-appropriate sources based on the `--framework` flag.

### Step 7: Generate the longlist table

Produce the output:

```markdown
# Benefits and Costs Longlist: [Project Name]

## Counterfactual

[Description of the do-nothing scenario from Step 2]

## Benefits Longlist

The headline table below is the main output. A "Strong" contender is a benefit that is material, clearly incremental to the counterfactual, monetisable, backed by strong evidence, and independent of other benefits in the list. A "Weak" contender fails one or more of those tests. The "How to quantify / monetise" column gives a concrete suggested method for each item: a specific data source and URL, an analytical approach, a primary research method (interviews, survey, Delphi), a benchmarking approach, or a modelled estimate. See the Detail table further down for the full classification axes.

Table 1: Benefits Longlist (headline view)

| # | Benefit | Description | How to quantify / monetise | CBA contender | Why |
|---|---------|-------------|----------------------------|---------------|-----|
| 1 | Travel time savings | Reduced journey times for commuters and freight using the new link | TAG values per minute by trip purpose × minutes saved × annual trips. [DfT TAG Data Book](https://www.gov.uk/government/publications/tag-data-book). | **Strong** | High materiality, monetisable at DfT TAG values, strong evidence base, low deadweight |
| 2 | Accident reduction | Fewer collisions on the improved road surface and alignment | TAG casualty unit costs by severity × casualties avoided. DfT TAG A4.1. | **Strong** | Monetisable at DfT TAG values, strong evidence |
| 3 | Reliability improvements | More predictable journey times, reducing scheduling buffer | Modelled: reliability ratio × standard deviation of journey time × trips (TAG A1.3). | **Moderate** | Monetisable via TAG but evidence base is thinner; moderate materiality |
| 4 | Agglomeration (WEI) | Productivity gains from closer effective proximity of firms and workers | Modelled: effective density elasticity × change in effective density (TAG A2.4). Supplementary only. | **Moderate** | Supplementary in Green Book and partially capitalised in land values |
| 5 | Carbon reduction (operational) | Reduced CO2e from traffic diverted to shorter route | DESNZ shadow carbon price × tCO2e reduction by year. `$PARAMS_DIR/uk/carbon-values.json`. | **Strong** | DESNZ values; not adjusted for additionality |
| 6 | Construction employment | Jobs supported during the 3-year build phase | Not applicable: do not include | **Weak** | Classic double-counting trap: the labour is already paid for in the capital cost. Only include if there is true labour market slack. |
| 7 | Land value uplift | Increase in nearby land values post-scheme | Would use MHCLG Land Value Estimates × uplift, BUT excluded | **Weak** | Capitalises the journey time savings already counted in row 1. Including both double-counts. |
| 8 | Community severance reduction | Reduced barrier effect between neighbourhoods | Qualitative only, narrative treatment. If material, run a WEMWBS survey of affected residents pre/post. | **Moderate** | No published unit value; primary research would strengthen |
| ... | | | | | |

Source: Authors' analysis using [framework] framework.

Table 1b: Benefits Longlist (full detail)

| # | Benefit | Beneficiary | Direct/Indirect | Primary/Secondary | Monetisation | Method | Materiality | Deadweight | Dependencies | Timing | Evidence | Contender | Include? |
|---|---------|-------------|-----------------|-------------------|--------------|--------|-------------|------------|--------------|--------|----------|-----------|----------|
| 1 | Travel time savings | Commuters, freight users | Direct | Primary | Monetisable (DfT TAG) | Unit value: TAG × minutes × trips | H | Low | Independent | Steady-state | Strong | Strong | Yes |
| ... | | | | | | | | | | | | | |

## Costs Longlist

Table 2: Costs Longlist (headline view)

| # | Cost | Description | How to quantify / monetise | CBA contender | Why |
|---|------|-------------|----------------------------|---------------|-----|
| 1 | Construction (capital) | Civil engineering, plant, materials, professional fees, contingency | BCIS £/sqm × GIA × building type factor (for buildings) OR SPON's / Rawlinsons for infrastructure elements. `$PARAMS_DIR/uk/construction-benchmarks.json`. [BCIS Online](https://service.bcis.co.uk/). Cross-check: Flyvbjerg reference class (28% road / 45% rail / 20% building overrun). | **Strong** | High materiality, direct, known scope, bearer clearly identified |
| 2 | Land acquisition | Purchase of land for the alignment | VOA market comparables OR district valuer primary assessment. | **Strong** | High materiality, direct |
| 3 | Operating and maintenance | Annual upkeep, inspections, resurfacing over appraisal period | Historical ratio: typically 2-5% of capex per year OR bottom-up FM contract pricing OR BCIS FM benchmarks. | **Strong** | Material, ongoing, direct |
| 4 | Optimism bias uplift | HMT-required uplift on capital costs to correct for systematic under-estimation | HMT Supplementary Guidance Table 1 % by project type and stage. `$PARAMS_DIR/uk/optimism-bias.json`. | **Strong** | Required by Green Book for all infrastructure |
| 5 | Embodied construction carbon | CO2e emissions from cement, steel, plant, transport during construction | RICS Whole Life Carbon Assessment methodology × capex intensity factors × DESNZ shadow carbon price. | **Moderate** | Valued at DESNZ shadow price; often missed entirely |
| 6 | Construction disruption | Lost time for road users during the build phase | Modelled: reduced capacity × affected trips × TAG time values × disruption period. Sensitivity on duration. | **Moderate** | Indirect, uncertain magnitude |
| 7 | Prior feasibility spend | Study costs already incurred before this appraisal | Not applicable: exclude | **Weak (EXCLUDE)** | Sunk cost. Green Book 2022 §5.17: exclude from the appraisal entirely. |
| ... | | | | | |

Source: Authors' analysis.

Table 2b: Costs Longlist (full detail)

| # | Cost | Payer | Type | Direction | Certainty | Method | Materiality | Timing | Contender | Include? |
|---|------|-------|------|-----------|-----------|--------|-------------|--------|-----------|----------|
| 1 | Construction | Government | Capital | Direct | Estimated | Unit value: BCIS £/sqm × GIA | H | Year 1-3 | Strong | Yes |
| ... | | | | | | | | | | |

Note on multipliers: Where the longlist references input-output multiplier effects, the default is Type I (direct + indirect only). Type II (including induced consumption) is only used with explicit justification, per the rule in the Green Book supplementary guidance and HMT Additionality Guide.

## Shortlist Recommendation

Based on the CBA contender ratings, the following items should be in the core CBA:

**Core benefits (Strong contenders):**
- [List of Strong-rated benefits]

**Core costs (Strong contenders):**
- [List of Strong-rated costs]

**Supplementary analysis (Moderate contenders):**
- [List of Moderate items with their caveats]

**Excluded (Weak contenders, with reason):**
- [List of Weak-rated items, each with the specific reason: high deadweight / qualitative / dependency / sunk cost / transfer / double-counting trap]

## Methodology

Brainstorming applied the following lenses:
1. Stakeholder mapping
2. Market failure framing ([which failure identified])
3. Theory of Change
4. [Framework] taxonomy
5. Sector-specific benefit library ([sector])
6. Commonly missed items checklist (including Flyvbjerg benefit-optimism check)

Counterfactual: [description]. All benefits and costs are incremental to this baseline.

Framework: [framework name and source].

The CBA contender rating (Strong/Moderate/Weak) synthesises materiality, deadweight risk, evidence strength, and dependencies. See the SKILL.md file for the derivation rule.

## Next Steps

Hand this longlist to `/cost-benefit`, `/business-case`, `/vfm-eval`, or `/reg-impact` to formalise and monetise:

```
/cost-benefit --from longlist-[project-slug]-[date].json
```

The companion JSON file contains the structured longlist for machine-readable handoff.
```

### Step 8: Output

Always generate the markdown file: `longlist-[slugified-project]-[date].md`. This is the primary output and contains the headline benefit/cost tables, the full-detail tables, the shortlist recommendation, and the methodology section.

Always save the companion JSON: `longlist-[slugified-project]-[date].json`. Schema:

```json
{
  "project": {"name": "", "sector": "", "framework": "", "scope": ""},
  "counterfactual": "",
  "benefits": [
    {
      "id": 1,
      "name": "",
      "description": "",
      "beneficiary": "",
      "direct_indirect": "direct|indirect",
      "primary_secondary": "primary|secondary",
      "monetisation": "cash|monetisable|quantifiable|qualitative",
      "quantification_method": {
        "method_type": "unit_value|analytical|primary_research|benchmarking|modelled|qualitative_only",
        "summary": "One-line description shown in the table",
        "data_source": "e.g. DfT TAG Data Book, GMCA Unit Cost Database, NHS Reference Costs",
        "data_source_url": "https://...",
        "params_file": "e.g. uk/tag-values.json (relative to $PARAMS_DIR), empty if not applicable",
        "formula_or_approach": "e.g. TAG £/min × minutes saved × annual trips",
        "primary_research_details": "For primary research methods only: sample size, method (interview|survey|Delphi|focus_group|case_study), rough cost estimate",
        "notes": ""
      },
      "materiality": "H|M|L",
      "deadweight_risk": "low|medium|high",
      "dependencies": "independent|conditional|overlapping",
      "dependency_note": "",
      "timing": "construction|ramp-up|steady-state|long-term",
      "evidence": "strong|moderate|weak",
      "cba_contender": "strong|moderate|weak",
      "include": "yes|supplementary|no",
      "exclusion_reason": "",
      "lens_source": ["stakeholder", "market-failure", "toc", "taxonomy", "sector", "checklist"]
    }
  ],
  "costs": [
    {
      "id": 1,
      "name": "",
      "description": "",
      "payer": "",
      "type": "capital|operating|one-off|ongoing|transfer",
      "direction": "direct|indirect",
      "certainty": "known|estimated|uncertain",
      "quantification_method": {
        "method_type": "unit_value|analytical|primary_research|benchmarking|modelled|qualitative_only",
        "summary": "",
        "data_source": "",
        "data_source_url": "",
        "params_file": "",
        "formula_or_approach": "",
        "primary_research_details": "",
        "notes": ""
      },
      "materiality": "H|M|L",
      "timing": "",
      "cba_contender": "strong|moderate|weak",
      "include": "yes|supplementary|no",
      "exclusion_reason": ""
    }
  ],
  "metadata": {
    "generated": "",
    "framework": "",
    "lenses_applied": [""],
    "total_benefits": 0,
    "total_costs": 0,
    "strong_benefits": 0,
    "strong_costs": 0
  }
}
```

Add KEY NUMBERS block at the end of the markdown file:

```markdown
<!-- KEY NUMBERS
type: longlist
project: [name]
framework: [framework]
n_benefits: [count]
n_costs: [count]
n_strong_benefits: [Strong contender count]
n_strong_costs: [Strong contender count]
n_weak_benefits: [Weak contender count]
n_weak_costs: [Weak contender count]
date: [date]
-->
```

**Format exports.** If `--format` includes any of `word`, `xlsx`, `pptx`, `pdf`, invoke the corresponding Anthropic skill(s) to generate them. The markdown is always generated regardless.

- **Markdown** (default, always generated): `longlist-[slug]-[date].md`
- **Word (.docx)** (if `word` in `--format`): Invoke the `docx` skill. Instruct it to create a document with a cover page ("Benefits and Costs Longlist", project name, framework, date), Table 1 (benefits headline view, 6 columns including "How to quantify / monetise"), Table 1b (benefits full detail), Table 2 (costs headline view, 6 columns including "How to quantify / monetise"), Table 2b (costs full detail), shortlist recommendation, methodology, and a references section listing every data source URL cited in the quantification methods column. Use green highlighting for Strong contenders, amber for Moderate, red for Weak. Hyperlink all data source URLs. Save as `longlist-[slug]-[date].docx`.
- **Excel (.xlsx)** (if `xlsx` in `--format`): Invoke the `xlsx` skill. Create one workbook with five sheets: `Summary` (counts by contender, counterfactual), `Benefits (headline)`, `Benefits (detail)`, `Costs (headline)`, `Costs (detail)`. Each row is one item. Columns match the markdown tables. The "How to quantify / monetise" column should include clickable hyperlinks to the data source URLs. Apply conditional formatting: green fill on "Strong" cells, amber on "Moderate", red on "Weak". Also add a sixth sheet `References` listing every data source and parameter file cited, with its URL. Save as `longlist-[slug]-[date].xlsx`.
- **PowerPoint (.pptx)** (if `pptx` in `--format`): Invoke the `pptx` skill. Create a summary deck: (1) title slide, (2) counterfactual slide, (3) Strong benefits slide, (4) Moderate/Weak benefits slide, (5) Strong costs slide, (6) Moderate/Weak costs slide, (7) shortlist recommendation, (8) methodology. Save as `longlist-[slug]-[date].pptx`.
- **PDF** (if `pdf` in `--format`): Render the markdown through the EconStack template via `scripts/render-report.sh`. Save as `longlist-[slug]-[date].pdf`.

Tell the user what was generated, listing only the files that were actually produced.

Tell the user:
```
Longlist complete. [N] benefits and [M] costs identified.

CBA contender summary:
- Benefits: [X] Strong, [Y] Moderate, [Z] Weak
- Costs: [X] Strong, [Y] Moderate, [Z] Weak

Files saved:
  longlist-[slug]-[date].md     (headline + detail tables + methodology)
  longlist-[slug]-[date].json   (companion JSON for handoff)
  [other formats as requested]

Next step: run `/cost-benefit --from longlist-[slug]-[date].json` to formalise and monetise.
Or: run `/business-case --from longlist-[slug]-[date].json` for the full Five Case Model.
Or: run `/reg-impact --from longlist-[slug]-[date].json` for a Regulatory Impact Assessment.
```

## Integration with other skills

**Invoked from `/cost-benefit`**: At Step 2 (Cost and benefit entry), the CBA skill offers to run `/longlist` first if the user is vague about benefits and costs, or auto-loads an existing `longlist-*.json` file via `--from`.

**Invoked from `/business-case`**: At Step 3d (Benefits register), the business-case skill offers to run `/longlist` first for projects above GBP 5m, or pre-populates the register from an existing `longlist-*.json` file.

**Reads from reference cases**: If a reference case exists for the project's asset type (`$PARAMS_DIR/reference-cases/*.json`), use it to pre-populate the sector-specific lens (LENS 5).

**Writes output JSON**: The companion JSON uses field names compatible with `/cost-benefit --from`, `/business-case --from`, `/vfm-eval --from`, and `/reg-impact --from` schemas, so the handoff is seamless.

## Important Rules

- Never use em dashes.
- Never attribute econstack to any individual.
- Every section stands alone.
- **Numbering**: Every table is "Table 1: [short description]", every figure/chart is "Figure 1: [short description]". Numbering restarts at 1 for each report. The caption goes above the table/figure.
- **Source note**: Below every table and figure: "Source: [Author/Publisher] ([year])." If multiple sources: "Sources: [Source 1]; [Source 2]."
- **Notes line**: Below the source, if needed: "Notes: [caveats, e.g. 'real 2026 prices', '2024-25 data', 'estimated from available figures']."
- **Minimal formatting (low ink-to-data ratio)**: No heavy borders or gridlines. Thin rule under the header row only. No shading on data cells (light grey alternating rows permitted in Excel/HTML only). Right-align all numbers. Left-align all text. Bold totals rows only. No decorative elements.
- **Number formatting**: Currency with comma separators and 1 decimal place for millions (e.g. "GBP 45.2m" / "AUD 45.2m"), whole numbers for counts (e.g. "1,250 jobs"), percentages to 1 decimal place (e.g. "3.5%").
- **Consistency**: The same metric must use the same unit and precision throughout the report. Do not switch between "GBP m" and "GBP bn" for the same order of magnitude.

### Methodology rules

- The counterfactual (do-nothing baseline) is not optional. Every benefit must be incremental to it. Refuse to proceed without one. The counterfactual must be *dynamic* (what evolves over time without intervention: deterioration, demand growth, committed policies), not a static snapshot of today.
- Brainstorming is NOT committing. Items on the longlist may be excluded in the final CBA. The purpose is to think systematically, not to produce an advocacy document.
- Deadweight risk is the single most important filter for benefits. High-deadweight benefits (the outcome would have happened anyway) should be flagged prominently and default to Weak contender.
- Leakage, displacement, and deadweight are all additionality concepts. All three should be considered when flagging benefit risk:
  - *Deadweight*: would the outcome have happened anyway?
  - *Displacement*: does this project just shift activity from elsewhere?
  - *Leakage*: do the benefits flow outside the target area or beneficiary group?
- Materiality is a judgement call, not an exact calculation. H/M/L should reflect the expected contribution to total NPV, not just the absolute value.
- The skill does NOT monetise. It identifies and classifies. Monetisation happens in `/cost-benefit` or `/vfm-eval`.
- Framework alignment matters: a Green Book brainstorm is different from a Better Regulation brainstorm. Apply the right taxonomy.
- Sunk costs are excluded entirely. Resources already committed that cannot be recovered are irrelevant to the forward-looking decision (Green Book 2022 §5.17). If the user mentions sunk costs, record them as context but do not put them on the longlist.
- Carbon benefits are NOT adjusted for deadweight, displacement, or leakage. They are valued at the full DESNZ shadow carbon price in the UK framework, and equivalent rates in other frameworks. Additionality adjustments apply only to non-carbon benefits.
- Carbon must be split into *embodied* (construction) and *operational* (in-use) components. Embodied carbon is a cost; operational carbon change is typically a benefit for green projects and a cost for business-as-usual. Embodied can offset operational for the first 10-20 years depending on asset type.

### Classic double-counting traps to flag as Weak contenders

These are the three most common double-counting errors in practice. The skill must recognise them and downgrade the second item when both are present on the longlist:

1. **Construction employment + capital cost.** If capital cost is already on the cost side, construction employment is NOT a separate benefit. The labour is already paid for inside the capital figure. Only include if there is genuine labour market slack and the opportunity cost of that labour is below the market wage (i.e. otherwise-unemployed local workers). Even then, flag as Weak and supplementary.
2. **Journey time savings + land value uplift.** Land values capitalise accessibility improvements, including journey time savings. If journey time savings are counted at DfT TAG values, land value uplift near the scheme is already partially captured and should not be added separately.
3. **Gross earnings + tax revenue on those earnings.** Tax on new earnings is a transfer from the worker to the state, not a net social benefit. If individual earnings are on the benefits side (valued gross of tax), income tax and NI receipts are NOT a separate benefit.

When the user lists both items from any of these three pairs, the skill must:
- Add both to the full longlist (for transparency)
- Mark the second item as Weak contender in the headline table
- Put the second item in the "Excluded (Weak contenders)" list with the specific double-counting reason

### Sector-specific rules

- **Regulation (Better Regulation Framework):** compliance costs are costs, not benefits. Do not double-count by listing "business efficiency" as a benefit if you've already netted it against compliance costs.
- **Transport (TAG):** always include induced demand as a caveat. Journey time savings overstate the benefit if demand responds.
- **Employment programmes:** deadweight is typically 30-50%. Do not assume the programme causes all observed employment changes. Distinguish fiscal savings (real resource release, counted as social benefits) from tax receipts (transfers, counted only in fiscal-only analysis).

### Empirical benchmarks (to cite when flagging items)

- Flyvbjerg et al. (2003): typical cost overruns of 28% (roads), 45% (rail), 20% (buildings), 35% (IT).
- Flyvbjerg (2005): transport benefits overstated by 50% on average ex-post.
- Crompton (1995): sports facility economic impact studies routinely overestimate benefits by 2-5x.
- Moretti (2010): local employment multipliers of 1.5-2.5 for tradeable sectors only.
- HMT Additionality Guide (2014): typical deadweight for area-based programmes 20-50%; typical displacement for retail 40-70%.
