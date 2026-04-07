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
  - Skill
---



**Only stop to ask the user when:** framework is ambiguous, discount rate needs confirming, cost/benefit figures are missing, or the user explicitly requested interactive mode.
**Never stop to ask about:** price base year (default to current), additionality rates (use HMT defaults), table formatting, output filename, or methodology choices that have a clear default in the selected framework.
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
- `--framework <name>` : CBA framework (see table below). Auto-detected from project description if not specified
- `--full` : Skip interactive menus where possible
- `--client "Name"` : Add "Prepared for"
- `--format <type>` : Output format(s): `markdown`, `xlsx`, `word`, `pptx`, `pdf`, or `all`. Comma-separate for multiple (e.g. `--format xlsx,word`). Default: markdown only
- `--from <file.json>` : Import all inputs from a JSON file. Skips all interactive questions. Use `--from schema` to print the expected JSON schema.
- `--exec` : Generate a management consulting-style executive summary deck (5-8 slides with action titles). Can be combined with `--format pptx` to get both the data deck and the narrative deck.
- `--audit` : After generating the report, automatically run `/econ-audit` on the output

**Supported frameworks:**

| Flag | Framework | Discount rate | Declining? | Optimism bias? |
|------|-----------|--------------|------------|----------------|
| `uk` | UK HM Treasury Green Book (default) | 3.5% | Yes (3.0% after yr 30, 2.5% after yr 75) | Yes, quantified by project type and stage |
| `eu` | EU Cohesion Policy CBA Guide (DG Regio) | 3% (advanced MS) / 5% (convergence) | No | No (sensitivity instead) |
| `us` | US OMB Circular A-4 (2023 revision) | 2% | Yes (long-term declining) | No (sensitivity instead) |
| `wb` | World Bank project appraisal | 10% (country-specific) | No | No (sensitivity instead) |
| `au` | Australian Government (OIA) | 7% (sensitivity at 4% and 10%) | No | No (sensitivity instead) |
| `nz` | New Zealand Treasury CBAx | 2% (non-commercial) / 8% (commercial) | No | No (sensitivity instead) |
| `eib` | European Investment Bank | 3.5-5% (aligned with EU) | No | No (sensitivity instead) |
| `adb` | Asian Development Bank | 10-12% | No | No (sensitivity instead) |

## Instructions

### Step 0: Load parameters

Before starting computation, load the parameter database for the detected framework.

```bash
PARAMS_DIR="$HOME/econstack-data/parameters"
```

Load all JSON files from `$PARAMS_DIR/{jurisdiction}/` where jurisdiction matches the framework:
- `uk` framework -> load `$PARAMS_DIR/uk/*.json`
- `eu` framework -> load `$PARAMS_DIR/eu/*.json`
- `au` framework -> load `$PARAMS_DIR/au/*.json`
- `us` framework -> load `$PARAMS_DIR/us/*.json`
- `wb` framework -> load `$PARAMS_DIR/wb/*.json`
- `adb` framework -> load `$PARAMS_DIR/adb/*.json`
- Other frameworks (nz, eib) -> parameter files not yet available, use built-in defaults below

All frameworks also load `$PARAMS_DIR/common/*.json` for shared parameters (S-curve capital phasing profiles, benefit ramp-up profiles). These are mathematical shapes that apply universally.

Read each JSON file and use the values throughout the computation. When referencing a parameter, use the loaded value. For example, instead of hardcoding "3.5%", use the value from `uk/discount-rates.json`.

**Fallback:** If `$PARAMS_DIR` does not exist or the jurisdiction directory is missing, use the built-in defaults hardcoded in this skill. Tell the user: "Parameter database not found. Using built-in defaults. For the latest values, run: cd ~/econstack-data && git pull"

**Staleness check:** For each loaded parameter file, compare today's date against `expected_next_update`. If today is past the expected update date, warn: "Note: [parameter label] ([jurisdiction]) was last verified [last_verified]. The source ([source.publication]) typically updates [source.update_frequency]. Expected update by [expected_next_update]. Values may be outdated. Run `cd ~/econstack-data && git pull` for latest."

If `last_verified` is more than 2 years old regardless of `expected_next_update`, upgrade to a stronger warning: "WARNING: [parameter label] values are over 2 years old (last verified [date]). These should be checked against the source before use in a formal appraisal."

**Citation:** When writing the methodology section, use the `source` metadata from each loaded parameter to auto-generate citations. For example: "Discount rate: 3.5% STPR (HM Treasury, The Green Book 2026)."

### Step 1: Project setup

**JSON import mode:**

If `--from <file.json>` is specified, read and parse the JSON file. The expected schema:

```json
{
  "project": "Project name",
  "framework": "uk",
  "perspective": "social | investor | fiscal | local",
  "referent_group": "All UK residents",
  "stakeholder_groups": [
    { "name": "Central government", "in_referent_group": true },
    { "name": "Local residents", "in_referent_group": true },
    { "name": "Transport users", "in_referent_group": true },
    { "name": "Foreign contractors", "in_referent_group": false }
  ],
  "stage": "obc",
  "sector": "transport",
  "appraisal_period": 60,
  "price_base_year": 2026,
  "prices": "real",
  "optimism_bias_pct": null,
  "discount_rate": null,
  "options": [
    {
      "name": "Do Nothing",
      "description": "Counterfactual description",
      "costs": { "annual_m": 2, "cost_bearer": "central government" }
    },
    {
      "name": "Option name",
      "description": "Option description",
      "costs": {
        "capex_total_m": 50,
        "capex_years": 2,
        "capex_phasing": "even | scurve | frontloaded",
        "capex_bearer": "central government",
        "opex_annual_m": 1,
        "opex_start_year": 2,
        "opex_bearer": "central government",
        "renewals": [{ "year": 25, "cost_m": 15, "description": "Deck resurfacing", "cost_bearer": "central government" }],
        "residual_pct": 10
      },
      "benefits": {
        "annual_m": 5,
        "start_year": 3,
        "growth_rate": 0.01,
        "ramp_up_years": 3,
        "benefit_recipient": "transport users"
      }
    }
  ],
  "additionality": "standard | conservative | optimistic | none",
  "carbon": { "annual_tco2e": -5000, "direction": "savings | emissions | both" },
  "distributional_weights": false,
  "place_based": false
}
```

Null values use framework defaults. Validate all required fields (project, framework, options with at least 2 entries). If any required field is missing, list the missing fields and stop.

If `perspective` is provided, use it (skip the interactive perspective question in Step 1b). If omitted, default to `"social"`. If `referent_group` is provided, use it. If omitted, default based on perspective and framework (e.g. "All UK residents" for UK social CBA). If `stakeholder_groups` is provided, use it to classify cost bearers and benefit recipients as referent or non-referent. If omitted, treat all stakeholders as within the referent group.

If `--from schema` is specified, print the schema above and stop.

Skip all interactive questions in Steps 1-3. Proceed directly to Step 4 (Compute). Still ask about output sections and file formats (Step 5) unless `--full` is also specified.

**Framework selection:**

If `--framework` was specified, use it. Otherwise, auto-detect from the project description:
- UK location, Green Book language, "business case", "five case model" -> `uk`
- EU member state, "cohesion fund", "ERDF", "major project" -> `eu`
- US location, "regulatory impact", "OMB", "federal" -> `us`
- "World Bank", "IDA", "IBRD", developing country -> `wb`
- Australia location, "RIS", "regulation impact" -> `au`
- New Zealand location, "CBAx", "Budget bid" -> `nz`
- "EIB", "European Investment Bank" -> `eib`
- "ADB", "Asian Development Bank" -> `adb`

If auto-detected, confirm with the user: "This looks like a [framework] appraisal. Is that right?" using AskUserQuestion with the detected framework as the recommended option and other plausible frameworks as alternatives.

If no framework can be inferred, ask using AskUserQuestion:

Question: "Which CBA framework should this follow?"

Options:
- UK Green Book (Recommended for UK projects)
- EU Cohesion Policy (EU-funded projects)
- US OMB Circular A-4 (US federal regulatory analysis)
- Other (World Bank, Australia, NZ, EIB, ADB)

**Project type and sector:**

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

**Question 3 (if infrastructure):** "What project stage is this appraisal for?"

Options:
- A) **Strategic Outline Case (SOC)** : Early stage, high uncertainty
- B) **Outline Business Case (OBC)** : Preferred option identified, moderate uncertainty
- C) **Full Business Case (FBC)** : Detailed design, low uncertainty

This determines the optimism bias rate. The Green Book specifies different rates by stage because uncertainty reduces as the project matures:

Use the optimism bias rates from the loaded `uk/optimism-bias.json` parameter file. The matrix contains 6 project types x 3 stages (SOC/OBC/FBC), with separate rates for capex and duration overruns.

If parameter files are not loaded, use these built-in defaults:

| Project type | SOC | OBC | FBC |
|-------------|-----|-----|-----|
| Standard buildings | 24% | 4% | 2% |
| Non-standard buildings | 51% | 18% | 4% |
| Standard civil engineering | 44% | 20% | 6% |
| Non-standard civil engineering | 66% | 34% | 6% |
| Equipment/development | 200% | 54% | 10% |
| Outsourced IT | 200% | 38% | 10% |

For non-UK frameworks that do not use optimism bias, set it to 0% and note that uncertainty is handled through sensitivity analysis instead.

**Set framework-specific defaults:**

| Setting | UK Green Book | EU Cohesion | US OMB A-4 | World Bank | Australia | NZ CBAx | EIB | ADB |
|---------|--------------|-------------|------------|------------|-----------|---------|-----|-----|
| Discount rate | 3.5% declining | 3% or 5% | 2% declining | 10% | 7% | 2% or 8% | 3.5-5% | 10-12% |
| Declining rates | Yes | No | Yes | No | No | No | No | No |
| Optimism bias | By type+stage | 0% | 0% | 0% | 0% | 0% | 0% | 0% |
| Appraisal period | By asset life | By sector (15-30yr) | By regulation life | 20-30yr | By asset life | By asset life | By sector | 20-30yr |

**EU Cohesion Policy: additional requirements.**
If the EU framework is selected:
- Ask whether the project is in an advanced member state (3% SDR) or convergence region (5% SDR).
- Ask whether the project cost exceeds EUR 50m (if so, it is a "major project" requiring full CBA under EU regulations).
- The EU requires both a **financial analysis** (Financial Net Present Value, Financial Rate of Return) and an **economic analysis** (Economic Net Present Value, Economic Rate of Return). Always produce both when using EU framework.
- Apply **fiscal correction factors** to strip out indirect taxes, subsidies, and transfer payments from the economic analysis.
- Apply **shadow wages** if the project is in a high-unemployment region (shadow wage factor typically 0.6-0.8 of market wage; ask the user for the regional unemployment rate and apply accordingly).
- EU reference periods by sector: Railways 30yr, Roads 25-30yr, Water/sanitation 30yr, Waste 25-30yr, Energy 15-25yr, Broadband 15-20yr, Ports/airports 25yr.
- Calculate the **EU co-financing gap rate**: the proportion of costs not covered by project revenues, which determines the eligible EU co-financing amount.

For NZ framework, ask whether the proposal is commercial (8%) or non-commercial (2%).

**Question 4:** "Are your cost estimates in real (today's prices) or nominal (future prices including inflation)?"

Options:
- A) **Real prices** (today's prices, no inflation. This is standard for CBA.)
- B) **Nominal prices** (include expected inflation. I'll deflate to real terms.)
- C) **Not sure** (I'll assume real prices and note the assumption.)

If nominal, ask for the assumed inflation rate and deflate all costs/benefits to real terms before discounting. Note: Green Book and most frameworks require real prices. Discounting already accounts for the time value of money.

Tell the user the defaults and ask if they want to override:

```
DEFAULTS SET
============
Framework:        [Framework name]
Discount rate:    [X]% [declining schedule if applicable]
Appraisal period: [X] years
Optimism bias:    [X]% on capex ([stage name] stage)
Price base year:  2026
Prices:           Real (2026 prices)

Override any of these? (Enter to accept defaults)
```

**Question 5:** "How many options are you appraising (including do-nothing)?"

Default: 3 (Do Nothing, Do Minimum, Preferred Option)

For each option, ask for: name and one-line description.

**For Do Nothing:** Ask "Does the Do Nothing option have any costs? (e.g., ongoing deterioration costs, emergency repairs, growing congestion costs, decommissioning)." If yes, capture Do Nothing costs. Many infrastructure projects have a non-zero counterfactual where doing nothing incurs increasing costs over time.

### Step 1b: Standing and perspective

This step establishes **whose costs and benefits are being counted**. Every CBA must be conducted from a defined perspective, with a clearly identified referent group. Without this, the analysis risks summing benefits to one group against costs borne by another, producing a misleading result. This follows the Campbell & Brown multiple account framework.

**If `--from` JSON import mode:** Skip these questions. Use the `perspective`, `referent_group`, and `stakeholder_groups` fields from the JSON (with defaults as described in the schema section above).

**Question 1:** Ask using AskUserQuestion:

"What perspective should this CBA take?"

Options:
- A) **Social/public** (default for public sector appraisals): Net benefits to society as a whole. Includes externalities, uses shadow prices where markets are distorted. Transfers (taxes, subsidies) net to zero. This is the standard Green Book perspective.
- B) **Investor/private**: Net benefits to the investing entity only. Uses market prices. Captures cash flows in and out of the entity. Taxes and subsidies are real costs/revenues to the entity.
- C) **Government fiscal**: Net impact on public finances. Counts changes in tax revenues, public spending, and transfer payments. Useful alongside a social CBA to show the Exchequer impact.
- D) **Local/regional**: Net benefits to a defined geographic area. Benefits and costs that leak outside the area boundary are tracked separately.

Default to A (social/public) for UK Green Book, EU, World Bank, and ADB frameworks. Default to B (investor) if the user described a private-sector project.

**Question 2:** Ask using AskUserQuestion (options depend on perspective chosen):

"Who is the referent group? (Whose costs and benefits should this analysis count?)"

If social/public perspective:
- A) **All [country] residents** (default). The standard for national-level public investment appraisal.
- B) **Regional population** (e.g. all residents of a specific region, devolved nation, or state). Appropriate for sub-national appraisals.
- C) **Custom** (I'll describe the group)

If investor/private perspective:
- A) **The investing entity** (default). Net cash flows to the organisation making the investment.
- B) **Equity holders** (returns to shareholders/owners after debt service)
- C) **Custom** (I'll describe the group)

If government fiscal perspective:
- A) **Central government / HM Treasury** (default for UK). Changes in Exchequer receipts and spending.
- B) **Local authority** (changes in council tax, business rates, grants, spending)
- C) **All levels of government** (central + local + devolved)
- D) **Custom** (I'll describe)

If local/regional perspective:
- Ask: "What is the geographic boundary for this analysis?" (e.g. local authority name, LEP area, combined authority, region)
- All residents and businesses within the boundary are the referent group.

Store the `perspective` and `referent_group` for use throughout the analysis.

**Stakeholder groups:**

Ask: "Who are the main stakeholder groups affected by this project?"

Suggest defaults based on the project type and sector:
- Infrastructure/transport: central government (funder), local authority, transport users, local residents, construction sector, private operators
- Health: NHS/health authority (funder), patients, carers, wider public (health externalities)
- Housing: DLUHC/Homes England (funder), local authority, homebuyers/tenants, existing residents, developers
- Policy/regulatory: government (regulator), regulated businesses, consumers, third parties

For each stakeholder group, ask: "Is [group] within your referent group?" Default to yes for groups that match the referent group definition (e.g. all UK-resident groups are "yes" for a national social CBA). Default to no for foreign entities (foreign contractors, overseas suppliers).

Store the stakeholder groups and their referent/non-referent classification. These are used in Step 2 to tag costs and benefits, and in Step 6 to produce the multiple-account table.

**Display the standing summary:**

```
STANDING AND PERSPECTIVE
========================
Perspective:    [Social/Investor/Fiscal/Local]
Referent group: [Description]

Stakeholder groups:
  [Group 1]              In referent group
  [Group 2]              In referent group
  [Group 3]              Outside referent group

Costs and benefits will be tagged to these groups in the next step.
```

### Step 2: Cost and benefit entry

Ask using AskUserQuestion:

**Question:** "How do you want to enter costs and benefits?"

Options:
- A) **Summary figures** : Total capex, annual opex, annual benefit (I'll spread them over the appraisal period)
- B) **Year-by-year** : Paste a table with costs and benefits per year
- C) **I'll describe them** : Tell me the costs and benefits in words and I'll help structure them

**If A (summary figures):**

For each option (except Do Nothing, unless Do Nothing has costs), ask:

**Costs (tag each item to a stakeholder group from Step 1b):**
- Total capital cost (£, one-off or phased over how many years?)
- "Who bears the capital cost?" Default to the funder identified in Step 1b (e.g. central government for public projects, the investing entity for private). Let the user override. If costs are split between funders (e.g. 60% central government grant, 40% local authority match), capture the split.
- Capital phasing profile: "How should capital costs be spread over the construction period?"
  - A) **Even spread** (equal annual amounts)
  - B) **S-curve** (slow start, peak in middle years, tail off). This is more realistic for construction projects. Apply a bell-curve distribution: ~10% in first year, ramping to ~25-30% in peak years, tapering to ~10% in final year.
  - C) **Front-loaded** (most spend in early years)
  - D) **Custom** (I'll specify the annual split)
- Annual operating cost (£/year, starting from which year?)
- "Who bears the operating costs?" Default to the entity responsible for ongoing operations (may differ from the capital funder).
- Any major renewal/replacement costs at specific years? (e.g., "bridge deck resurfacing at year 15 costing £20m, bearing replacement at year 30 costing £40m"). These are lumpy whole-life costs that differ from routine annual opex. If yes, capture each renewal event: year, cost, description, and cost bearer.
- Any residual/terminal value at end of appraisal period?

**Benefits (tag each item to a stakeholder group from Step 1b):**
- Annual benefit (£/year, at full maturity)
- "Who receives this benefit?" Default based on sector (e.g. "transport users" for transport, "patients" for health). Let the user override. If benefits are split across groups, capture the split (e.g. 70% to direct users, 30% to wider public through reduced congestion).
- Benefit ramp-up: "How quickly do benefits reach full value after construction?"
  - A) **Immediate** (full benefits from year 1 of operation)
  - B) **Linear ramp-up over [X] years** (e.g., 25% in year 1, 50% in year 2, 75% in year 3, 100% in year 4). Default: 3 years for infrastructure, 1 year for policy.
  - C) **Custom ramp-up** (I'll specify the profile)
- Growth rate after reaching full maturity (% per year)
- Starting from which year?

**Carbon impacts (if applicable):**
Ask: "Does this project have significant carbon impacts (positive or negative)?"
- A) **Yes, net carbon reduction** (e.g., mode shift to active travel, energy efficiency)
- B) **Yes, net carbon increase** (e.g., embodied carbon in construction, induced traffic)
- C) **Both** (construction emissions but operational carbon savings)
- D) **Not material** (skip carbon valuation)

If carbon impacts exist, ask for estimated annual tonnes of CO2e (positive = emissions, negative = savings). Apply carbon values from the loaded parameter database:
- UK framework: use the `non_traded.schedule` from `uk/carbon-values.json`. Interpolate linearly between data points. For years beyond the schedule, extrapolate at 1.5% real annual growth.
- EU/EIB framework: use the `eib_shadow_price.schedule` from `eu/carbon-values.json`. Interpolate linearly.
- AU framework: use `au/carbon-values.json` if available, otherwise ask the user for a carbon price.
- US framework: use the `sc_co2.at_2_percent.schedule` from `us/carbon-values.json`. These are EPA 2023 social cost of carbon estimates (damage-based, NOT target-consistent like UK). Interpolate linearly. Present sensitivity at 1.5% and 2.5% discount rates.
- Other frameworks (WB, NZ, EIB, ADB): parameter files not yet available. Use built-in defaults: $50/tCO2, or ask the user.

*Carbon values are sourced from the econstack-data parameter database. Check `last_verified` dates in each file. Sources update periodically (DESNZ annually, EIB ~5 years).*

Carbon benefits/costs are included as a separate line item in the benefit/cost tables, not subject to additionality adjustments (they are global externalities, not local economic activity).

**OECD carbon benchmark context:** When writing the carbon section of the report, load `oecd/carbon-benchmarks.json` and note how the carbon price used in the appraisal compares to the OECD benchmarks. For example: "The carbon value of [X]/tCO2 used in this appraisal is [above/below] the OECD net-zero pathway benchmark of EUR 120/tCO2 by 2030." This gives international context regardless of which national framework is selected.

**Perspective consistency checks (run after all costs and benefits are entered):**

After the user has entered all cost and benefit items, check for consistency with the perspective chosen in Step 1b:

- If perspective is **investor/private** and the user entered externalities (carbon savings, air quality improvements, noise reduction, wider economic benefits, health externalities): warn "You've included externalities ([list items]), but the perspective is investor/private. Externalities are impacts on third parties and are typically excluded from private appraisals. They belong in a social CBA. Remove these from the investor analysis? (I can run a parallel social CBA that includes them.)"

- If perspective is **social/public** and the user entered only private cash flows (revenues, direct costs) with no wider benefits or externalities: note "This analysis is from a social/public perspective, but the benefits entered are all private cash flows. A social CBA should also consider externalities (environmental, health, congestion, safety) and wider economic impacts. Are there non-market benefits to add?"

- If perspective is **social/public** and the user included taxes, subsidies, or grants as costs or benefits: warn "Taxes, subsidies, and grants are transfer payments between parties within the referent group. In a social CBA, they net to zero and should be excluded from the efficiency analysis. (They are relevant in a fiscal or investor perspective.) Remove transfers from the social analysis?"

- If perspective is **local/regional** and the user tagged benefits to groups outside the geographic boundary: note "[X]% of total benefits accrue to groups outside the [area] boundary. These will appear in the efficiency NPV but not the referent group NPV. This is expected for local appraisals but worth highlighting to decision-makers."

- If perspective is **government fiscal** and the user included consumer surplus or user benefits: warn "Consumer surplus and user benefits are relevant to a social CBA but not to a fiscal analysis, which tracks impacts on public finances only. Remove non-fiscal items?"

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

Ask structured questions to extract quantifiable information:

For costs, ask:
  "What is the total capital/construction cost? (If unsure, give a range e.g., '£50-100m'. I'll use the midpoint for the central estimate and the bounds for sensitivity.)"
  "What are the ongoing annual costs to operate and maintain?"
  "Are there any one-off transition or implementation costs?"

For benefits, ask sector-specific questions:

  If transport:
  - "How many people will use this per day/year?"
  - "How much journey time will they save (minutes per trip)?"
  - "What mix of trip purposes? (work/commute/leisure)"
  - "Are there safety improvements? (fewer accidents expected?)"
  -> Apply TAG values automatically from the tables in this skill

  If health/social care:
  - "How many patients/people benefit per year?"
  - "What health outcome improvement do you expect? (QALYs, life years, reduced hospital admissions?)"
  -> Apply QALY/DALY values automatically from the tables in this skill

  If housing/regeneration:
  - "How many homes will be built/improved?"
  - "What is the expected land value uplift?"
  - "Are there construction jobs during the build phase?"

  If environment/energy:
  - "What are the carbon savings (tonnes CO2e per year)?"
  - "Are there air quality or noise improvements?"
  -> Apply carbon values automatically from the tables in this skill

  For all sectors:
  - "What is the main benefit to users? (time saved, money saved, improved quality?)"
  - "How many people benefit per year?"
  - "Can you estimate the value per person per year? (If not, I'll note it as non-monetised.)"
  - "Which stakeholder group receives this benefit?" (Refer to the groups defined in Step 1b. If a benefit accrues to multiple groups, ask for the approximate split.)

If the user gives a range for any value, use the midpoint for the central estimate and the bounds for sensitivity analysis (low = lower bound, high = upper bound). This is more useful than asking for a single point estimate.

Then structure the responses into the standard benefit categories, tagging each to a stakeholder group:
- Direct user benefits (time savings, cost savings, revenue) -> tag to direct users (e.g. transport users, patients)
- Wider economic benefits (employment, GVA, agglomeration) -> tag to wider economy / local residents
- Environmental benefits (carbon, air quality, noise) -> tag to wider public / global (carbon)
- Social benefits (health, safety, wellbeing) -> tag to affected communities
- Non-monetised benefits (describe qualitatively with direction and magnitude) -> tag to relevant group

**Transport benefit monetisation (if sector is Transport):**

If the user describes benefits in physical units rather than monetary values, offer to monetise using DfT Transport Analysis Guidance (TAG) standard values. Ask:

"Would you like me to apply TAG standard values to monetise transport benefits?"

If yes, load values from `uk/vtts.json` and `uk/vsl.json` in the parameter database. If parameter files are not loaded, use these built-in defaults (2022 prices):

| Benefit type | TAG value | Unit | Source |
|-------------|-----------|------|--------|
| Working time savings | £19.61/hr | per person | TAG A1.3 |
| Commuting time savings | £7.63/hr | per person | TAG A1.3 |
| Leisure time savings | £6.56/hr | per person | TAG A1.3 |
| Vehicle operating cost savings (car) | £0.14/km | per vehicle-km | TAG A1.3 |
| Fatal accident prevented | £2.35m | per fatality | TAG A4.1 |
| Serious injury prevented | £264,500 | per casualty | TAG A4.1 |
| Slight injury prevented | £20,400 | per casualty | TAG A4.1 |
| Noise (change in exposure) | varies by dB change | per household/yr | TAG A3 |
| Air quality (NOx, PM) | varies by location | per tonne | TAG A3 |

Ask for physical quantities (e.g., "How many person-hours of journey time will be saved per year? What mix of trip purposes: work/commute/leisure?"). Then compute annual benefit = quantity x TAG value.

Note: TAG values are updated annually. These are indicative. For a formal WebTAG appraisal, use the current TAG Data Book.

*Data vintage: 2026 TAG Data Book. Updated annually by DfT. If this analysis is more than 12 months after 2026, verify against the latest TAG Data Book at https://www.gov.uk/government/publications/tag-data-book.*

**Health benefit monetisation (if sector is Health or benefits include safety/health):**

If health outcomes are described in physical units, offer to monetise using framework-specific QALY/DALY/VPF values from the loaded parameter database.

**For UK, EU, AU, and US frameworks:** Load values from `{jurisdiction}/health-values.json` and `{jurisdiction}/vsl.json`. Use the `source` metadata for citations.

For US: note that three agencies publish different VSL values (DOT $13.7M, EPA $12.5M, HHS $13.6M). Use DOT for transport CBA, EPA for environmental, HHS for health. The `us/vsl.json` file documents all three with methodology notes. Also load `us/vsl.json` for the MAIS injury severity fractions (DOT's method for valuing non-fatal injuries as fractions of VSL).

**For other frameworks (NZ, WB, EIB, ADB):** Parameter files not yet available. Use these built-in defaults:

**New Zealand:**
| Health metric | Value | Source |
|--------------|-------|--------|
| QALY | NZD 56,000-$68,000 | PHARMAC implicit threshold |
| VSL | NZD 4.99m (2024 NZD) | NZ Treasury CBAx; Ministry of Transport |
| VSLY | NZD 198,000 | Derived from VSL |

*Built-in defaults last updated 2026-04. For UK, EU, AU: check `last_verified` in parameter files.*

Use the values matching the selected framework. If the user provides health outcomes in DALYs rather than QALYs, note that for CBA purposes these are typically treated symmetrically (1 DALY averted = 1 QALY gained), though they are conceptually different measures (DALYs measure burden of disease; QALYs measure health utility).

**Wider economic impacts (if infrastructure project):**

For infrastructure projects, ask: "Do you want to include wider economic impacts (WEIs) beyond direct user benefits?"

Options:
- A) **No** (standard appraisal, direct benefits only. This is the default and most defensible approach.)
- B) **Yes, qualitatively** (note agglomeration, labour supply, imperfect competition effects but do not monetise)
- C) **Yes, with estimates** (I'll provide estimates of agglomeration/labour supply impacts)

If B or C, note that WEIs should be presented separately from core transport benefits to avoid double-counting. The Green Book and TAG recommend WEIs are reported as supplementary analysis, not included in the primary BCR.

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

### Step 3b: Distributional weighting (optional)

Ask: "Do you want to apply distributional (equity) weights to the analysis?"

Options:
- A) **No** (standard unweighted analysis. This is the default.)
- B) **Yes, UK Green Book welfare weights** (weight benefits to lower-income groups more heavily)
- C) **Yes, US OMB A-4 income weights** (2023 revision endorses income-based weights)
- D) **Yes, custom weights** (I'll specify weights by income group)

If distributional weights are applied:

**UK Green Book approach:**
Load the elasticity and median income from `uk/distributional-weights.json`. If parameter files are not loaded, use built-in defaults: e = 1.3, median household income = GBP 35,000.

```
weight(income) = (median_income / income) ^ elasticity
```

Example weights (using default values):
- Household on £20,000: weight = (35000/20000)^1.3 = 2.07 (benefits count double)
- Household on £35,000: weight = 1.00 (median, no adjustment)
- Household on £60,000: weight = (35000/60000)^1.3 = 0.50 (benefits count half)
- Household on £100,000: weight = (35000/100000)^1.3 = 0.26

Ask the user to estimate the income distribution of beneficiaries and cost-bearers. Compute a weighted NPV alongside the unweighted NPV. Present both.

**US OMB A-4 (2023) approach:**
Load the elasticity and median income from `us/distributional-weights.json`. If parameter files are not loaded, use built-in defaults: e = 1.4, median household income = $75,000. The revised A-4 formally endorses income-based distributional weights and makes them a requirement for significant regulatory actions (>$100M annual impact).

For other frameworks, present distributional analysis qualitatively unless the user provides custom weights.

**Always present distributional analysis as supplementary**, alongside (not replacing) the unweighted NPV. The weighted NPV answers: "Does this project disproportionately benefit lower-income groups?"

### Step 3c: Place-based adjustments (UK Green Book only)

If the framework is UK Green Book, ask: "Is this project in a Levelling Up priority area or an area with specific place-based considerations?"

Options:
- A) **No / Not sure** (skip place-based adjustments)
- B) **Yes, Levelling Up priority area** (e.g., Category 1 area under the Levelling Up Fund)
- C) **Yes, devolution deal area** (specific local growth priorities)
- D) **Yes, Freeport or Investment Zone**

If yes, note the following in the methodology and appraisal summary:
- The Green Book (2020 update and subsequent guidance) requires consideration of place-based impacts, particularly for projects in areas with lower productivity, higher deprivation, or weaker economic performance.
- Place-based considerations may justify: lower displacement rates (economic activity is less likely to displace existing activity in weaker economies), lower deadweight (intervention is more likely to be additional in areas with less private investment), and stronger weighting of non-monetised benefits (regeneration, social cohesion).
- Flag if the project location is in the bottom quartile of the Index of Multiple Deprivation (IMD) or equivalent.
- Note any alignment with local Industrial Strategy, Local Skills Improvement Plans, or devolution deal priorities.

Place-based analysis does not change the discount rate or core NPV calculation. It provides context for the appraisal and may justify more favourable additionality assumptions.

### Step 4: Compute

Run the following computations for each option vs Do Nothing:

**Discount factors (framework-specific):**

For UK Green Book (declining schedule, computed cumulatively):

Use the schedule from the loaded `uk/discount-rates.json` parameter file. Each entry specifies a year band and its rate. If parameter files are not loaded, use the built-in defaults: 3.5% (years 0-30), 3.0% (31-75), 2.5% (76-125), 2.0% (126-200), 1.5% (201-300), 1.0% (301+).

```
df(0) = 1.0
For t = 1 to appraisal_period:
  r = rate from discount schedule for year t

  df(t) = df(t-1) / (1 + r)

  CRITICAL: discount factors must be computed cumulatively.
  Do NOT apply the lower rate from year 0. Each year discounts
  from the previous year's factor at the rate for that year band.
```

For US OMB A-4 (declining long-term):

Use the schedule from `us/discount-rates.json` (field `revised_a4.schedule`). If parameter files are not loaded, use built-in defaults: 2.0% (years 0-56), 1.7% (57-115), 1.1% (116+).

Also present sensitivity at legacy A-4 rates (3% and 7%) from `us/discount-rates.json` (field `legacy_a4`). The A-4 revision is subject to executive order changes, so presenting both sets provides defensibility.

```
df(0) = 1.0
For t = 1 to appraisal_period:
  r = rate from discount schedule for year t

  df(t) = df(t-1) / (1 + r)
```

For all other frameworks (flat rate):
```
df(t) = 1 / (1 + r)^t
where r is the framework's social discount rate.
```

**Capital cost phasing:**
```
If even spread:
  capex_per_year = total_capex / construction_years

If S-curve (bell-curve distribution):
  Use the S-curve profiles from `uk/construction-benchmarks.json` (field `s_curve_profiles`).
  Built-in defaults if parameters not loaded:
  For a 5-year build: weights [0.10, 0.20, 0.30, 0.25, 0.15]
  For a 3-year build: weights [0.20, 0.50, 0.30]
  Weights must sum to 1.0. Multiply total_capex by each weight.

If front-loaded:
  Declining weights (e.g., 5-year: [0.35, 0.25, 0.20, 0.12, 0.08])
```

**Optimism bias:**
```
adjusted_capex = capex * (1 + optimism_bias_rate)
adjusted_opex = opex  (no optimism bias on opex unless user specifies)
adjusted_renewals = renewals * (1 + optimism_bias_rate)  (same rate as capex)
```

**Benefit ramp-up:**
```
If linear ramp-up over N years:
  For year i of operation (i = 1 to N):
    benefit(i) = full_annual_benefit * (i / N)
  For year i > N:
    benefit(i) = full_annual_benefit * (1 + growth_rate)^(i - N)
```

**Whole-life costs:**
```
For each renewal event at year Y with cost C:
  cost(Y) += C * (1 + optimism_bias_rate)
These are added to the year-by-year cost schedule alongside opex.
```

**Carbon valuation:**
```
If carbon impacts specified:
  carbon_value(t) = annual_tonnes_CO2e * carbon_price(t)
  where carbon_price follows the framework-specific schedule.
  Add as a separate benefit line (if savings) or cost line (if emissions).
  NOT subject to additionality adjustments.
```

**Do Nothing costs:**
```
If Do Nothing has costs (e.g., deterioration, growing congestion):
  PV_do_nothing_costs = sum over t of [do_nothing_cost(t) * df(t)]
  NPV for intervention options is computed as:
    NPV = (PV_benefits + PV_avoided_do_nothing_costs) - PV_intervention_costs
  where PV_avoided_do_nothing_costs = PV_do_nothing_costs (these are costs
  you avoid by intervening, so they count as benefits of the intervention).
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

VfM category (UK Green Book):
  BCR < 1.0  -> Poor
  1.0 - 1.5  -> Low
  1.5 - 2.0  -> Medium
  2.0 - 4.0  -> High
  > 4.0      -> Very High

For non-UK frameworks, use NPV as the primary metric and note that
VfM categories are a UK-specific convention.
```

**Referent group analysis (Campbell-Brown identity check):**

Using the stakeholder tags from Step 2 and the referent/non-referent classification from Step 1b, compute three NPV figures for each option:

```
For each cost/benefit item tagged to a stakeholder group:
  If stakeholder is in referent group:
    Add to referent_group_costs or referent_group_benefits
  Else:
    Add to non_referent_costs or non_referent_benefits

Efficiency_NPV = PV_all_benefits - PV_all_costs
Referent_Group_NPV = PV_referent_benefits - PV_referent_costs
Non_Referent_NPV = PV_non_referent_benefits - PV_non_referent_costs

Identity check: Efficiency_NPV = Referent_Group_NPV + Non_Referent_NPV
(This must hold by construction. If it does not, there is a tagging error.)
```

**Interpretation guidance:**

- If Referent_Group_NPV is positive: the project delivers net benefits to the group the decision-maker represents.
- If Efficiency_NPV is positive but Referent_Group_NPV is negative: the project creates value overall, but the referent group is a net loser. This is common when benefits leak outside the referent group boundary (e.g. a local project whose benefits accrue nationally, or a public project that generates private profits for non-resident firms).
- If Non_Referent_NPV is large relative to Efficiency_NPV: flag this. It means a significant share of project value accrues to parties outside the referent group. The decision-maker should understand where the value goes.

For social CBAs with a national referent group, non-referent flows are typically small (foreign contractors, imported materials, returns to overseas investors). If non-referent flows exceed 10% of Efficiency NPV, flag for review.

For local/regional CBAs, non-referent flows are often substantial (tax revenues to central government, benefits to commuters from outside the area, profits to national firms). The gap between Efficiency NPV and Referent Group NPV is the key insight for local decision-makers.

**Computation-stage perspective warnings:**

After computing the referent group analysis, check:

- If Efficiency NPV > 0 but Referent Group NPV < 0: flag prominently. "The project creates net value overall (Efficiency NPV: [val]), but the referent group ([description]) is a net loser (Referent Group NPV: [val]). Most of the value accrues to parties outside the referent group. The decision-maker should consider whether this distribution is acceptable, or whether cost/benefit sharing arrangements (e.g. developer contributions, tax sharing, benefit capture mechanisms) could improve the position of the referent group."

- If Referent Group NPV > 0 but one or more stakeholder groups within the referent group are significant net losers: note "While the referent group benefits overall, [group name] bears [X]% of costs but receives only [Y]% of benefits. Compensation or mitigation measures may be needed for political or equity reasons."

- If perspective is fiscal and the project shows positive social NPV but negative fiscal NPV: note "This project delivers social value but costs the Exchequer more than it returns in tax/spending savings. This is typical for public goods (the social benefit justifies the fiscal cost)."

**Incremental analysis (if 3+ options):**
```
In addition to comparing each option vs Do Nothing, compute the
incremental NPV and BCR of moving from one option to the next:

  incremental_NPV = NPV(Option 3) - NPV(Option 2)
  incremental_BCR = (PV_benefits_3 - PV_benefits_2) / (PV_costs_3 - PV_costs_2)

This answers: "Is the additional spend to go from Do Minimum to Preferred
worth it?" A project with high absolute BCR but low incremental BCR may
not justify the extra cost over a cheaper option.
```

**Switching values:**
For the top 2-3 cost/benefit items, compute the percentage change that would make NPV = 0:
```
switching_value_benefits_pct = abs(NPV / PV_benefits) * 100
switching_value_costs_pct = abs(NPV / PV_costs) * 100

IMPORTANT: Interpret these correctly based on the sign of NPV:
  If NPV > 0:
    "Benefits could fall by [X]% before NPV turns negative"
    "Costs could rise by [X]% before NPV turns negative"
  If NPV < 0:
    "Benefits would need to rise by [X]% for NPV to reach zero"
    "Costs would need to fall by [X]% for NPV to reach zero"
```

**Sensitivity analysis (framework-specific):**

Sensitivity analysis is mandatory for all frameworks. The depth and type depends on the framework.

**1. Scenario sensitivity (all frameworks):**

Run three scenarios:
- **Optimistic:** benefits +20%, costs -20%
- **Central:** as computed
- **Pessimistic:** benefits -20%, costs +20%

Compute NPV and BCR for each. Present as a table.

**2. Per-variable sensitivity / tornado analysis (all frameworks):**

For each of the top 5 cost and benefit items (by PV magnitude), compute NPV with that single variable at +/-20% while holding all other variables at their central values. This identifies which assumptions the conclusion is most sensitive to.

```
For each key variable V in [capex, opex, main_benefit_1, main_benefit_2, growth_rate, ...]:
  NPV_high = compute NPV with V at +20%, all else central
  NPV_low  = compute NPV with V at -20%, all else central
  range    = NPV_high - NPV_low
```

Present as a tornado table, sorted by range (widest first):

```markdown
| Variable | -20% NPV ([currency]m) | Central NPV | +20% NPV ([currency]m) | Range | NPV still positive? |
|----------|----------------------|-------------|----------------------|-------|---------------------|
| [Var with widest range] | [val] | [val] | [val] | [val] | [Yes/No at -20%] |
| [Second widest] | [val] | [val] | [val] | [val] | [Yes/No] |
| [Third] | [val] | [val] | [val] | [val] | [Yes/No] |
```

Interpretation: "The conclusion is most sensitive to [top variable]. A 20% [increase/decrease] in [variable] alone would [change/not change] the VfM assessment."

**3. Discount rate sensitivity (framework-specific):**

| Framework | Required discount rate tests |
|-----------|---------------------------|
| UK Green Book | Central (3.5% declining). Also test: health-specific (1.5% for health outcomes), flat 3.5% (to show impact of declining schedule), and if appraisal period > 30 years, show impact of rate step-down at year 31 |
| US OMB A-4 | Central (2% revised declining). Also test: legacy 3% and legacy 7% (required for backward compatibility with pre-2023 A-4) |
| Australia (OIA) | **Three rates mandatory**: 4%, 7% (central), 10%. Present all three in a comparison table. |
| EU Cohesion | Central (3% or 5%). Also test: the alternative rate (if 3% central, show 5% sensitivity, and vice versa) |
| World Bank | Central (typically 6% ERR). Also test: 3% and 10% |
| NZ CBAx | Central (2% or 8%). Also test: the alternative rate |
| EIB | Central (3.5-5%). Also test: 2% lower bound and 6% upper bound |
| ADB | Central (9-12%). Also test: 6% and 15% |

Present as a comparison table:

```markdown
| Discount rate | PV Costs ([currency]m) | PV Benefits ([currency]m) | NPV ([currency]m) | BCR |
|--------------|----------------------|--------------------------|-------------------|-----|
| [Low rate]% | [val] | [val] | [val] | [val] |
| **[Central rate]%** | **[val]** | **[val]** | **[val]** | **[val]** |
| [High rate]% | [val] | [val] | [val] | [val] |

[Interpretation: "The project delivers positive NPV at all tested discount rates" or "The project is sensitive to the discount rate: NPV turns negative at rates above [X]%"]
```

For Australia specifically: the OIA CBA guide requires all three rates (4%, 7%, 10%) to be presented with equal prominence, not as "central with sensitivity". The 7% rate is the default but the decision-maker should see all three.

**4. Named scenario analysis (recommended for UK Green Book, optional elsewhere):**

The Green Book Supplementary Guidance on Uncertainty recommends testing specific risk scenarios, not just blanket percentage changes. If the project has identifiable risk events, construct 2-3 named scenarios:

```markdown
| Scenario | Description | Key assumption changes | NPV ([currency]m) | BCR |
|----------|------------|----------------------|-------------------|-----|
| **Central** | Base case | As modelled | [val] | [val] |
| **Delayed construction** | 2-year construction delay | +2 years to benefit start, +10% capex | [val] | [val] |
| **Low demand** | Demand 30% below forecast | Benefits -30%, growth rate halved | [val] | [val] |
| **High input costs** | Material cost inflation | Capex +25%, opex +15% | [val] | [val] |
```

Tailor scenarios to the project type:
- Transport: low demand, construction delay, induced traffic (disbenefit)
- Health: lower clinical effectiveness, slower adoption
- Housing: house price fall, reduced demand
- Energy: technology cost change, carbon price scenario
- Policy/regulatory: lower compliance rate, higher admin costs

**5. Break-even analysis by variable (recommended for Australian and all frameworks):**

For each key variable, compute the exact value at which NPV = 0:

```markdown
| Variable | Central value | Break-even value | Change required | Plausibility |
|----------|-------------|-----------------|-----------------|-------------|
| Annual benefit | [currency][val]m | [currency][val]m | -[X]% | [Plausible / Implausible] |
| Capital cost | [currency][val]m | [currency][val]m | +[X]% | [Plausible / Implausible] |
| Benefit growth rate | [X]% | [X]% | [direction + magnitude] | [Plausible / Implausible] |
| Discount rate | [X]% | [X]% | +[X]pp | [Plausible / Implausible] |
```

This extends switching values (which give aggregate percentages) to show the specific break-even point for each variable individually. The "Plausibility" column helps decision-makers assess whether the break-even point is within the range of realistic outcomes.

**Probabilistic sensitivity / Monte Carlo (optional, offer for large projects):**

For projects with PV costs exceeding £100m (or equivalent), or when the user requests it, offer a probabilistic risk analysis:

Ask: "Would you like a probabilistic (Monte Carlo) sensitivity analysis? This samples from distributions around your cost and benefit estimates to show the probability of achieving positive NPV."

If yes, generate and run an R script to perform the simulation. Do NOT attempt to reason through 10,000 iterations as text. Write the script, execute it, and parse the JSON output.

```bash
Rscript -e '
  library(jsonlite)
  set.seed(42)
  n <- 10000

  pv_costs <- PV_COSTS_VALUE
  pv_benefits <- PV_BENEFITS_VALUE

  # Triangular distribution sampler
  rtri <- function(n, min, mode, max) {
    u <- runif(n)
    f <- (mode - min) / (max - min)
    ifelse(u < f,
      min + sqrt(u * (max - min) * (mode - min)),
      max - sqrt((1 - u) * (max - min) * (max - mode)))
  }

  cost_mult <- rtri(n, min=0.80, mode=1.00, max=1.50)
  benefit_mult <- rtri(n, min=0.50, mode=1.00, max=1.20)

  npv <- pv_benefits * benefit_mult - pv_costs * cost_mult
  bcr <- (pv_benefits * benefit_mult) / (pv_costs * cost_mult)

  result <- list(
    mean_npv = mean(npv),
    median_npv = median(npv),
    p5 = quantile(npv, 0.05),
    p25 = quantile(npv, 0.25),
    p75 = quantile(npv, 0.75),
    p95 = quantile(npv, 0.95),
    mean_bcr = mean(bcr),
    prob_npv_positive = mean(npv > 0) * 100,
    prob_bcr_gt_1 = mean(bcr > 1) * 100,
    prob_bcr_gt_2 = mean(bcr > 2) * 100
  )
  cat(toJSON(result, auto_unbox=TRUE, pretty=TRUE))
'
```

**IMPORTANT:** Replace `PV_COSTS_VALUE` and `PV_BENEFITS_VALUE` with the actual numeric PV values (in millions) computed in Step 4 before running the script. If R is not available, note: "Monte Carlo simulation requires R. The deterministic sensitivity analysis above is still valid."

Parse the JSON output and report:

Present as a table:

| Percentile | NPV (£m) | BCR |
|-----------|----------|-----|
| P5 (worst) | [val] | [val] |
| P25 | [val] | [val] |
| P50 (median) | [val] | [val] |
| P75 | [val] | [val] |
| P95 (best) | [val] | [val] |
| **Mean** | **[val]** | **[val]** |

Probability of positive NPV: [X]%
Probability of BCR > 1.0: [X]%
Probability of BCR > 2.0: [X]%

[Interpretation: "There is a [X]% probability that this project delivers positive
value for money. Under the worst 5% of scenarios, the NPV is [val]. Under the
best 5%, it is [val]."]
```

The user may override the distribution parameters if they have better estimates of cost/benefit uncertainty ranges. The triangular distribution is used because it requires only min/mode/max (easy for users to specify) and is standard in Green Book risk analysis.

**Distributional weighting computation (if selected in Step 3b):**

```
weighted_NPV = sum over t of [
  (weighted_benefit(t) - weighted_cost(t)) * discount_factor(t)
]

where weighted_benefit = benefit * weight(income_of_beneficiaries)
and weighted_cost = cost * weight(income_of_cost_bearers)

Present alongside unweighted NPV:
  Unweighted NPV: £[val]m
  Distributionally weighted NPV: £[val]m
  [If weighted > unweighted: "Distributional weighting improves the case
  because benefits accrue disproportionately to lower-income groups."]
```

### Step 5: Show results and ask what the user needs

```
CBA RESULTS ([Framework])
==========================
Perspective:    [Social/Investor/Fiscal/Local]
Referent group: [Description]

                    Do Nothing    Do Minimum    Preferred
PV Costs (£m):     [val]         [val]         [val]
PV Benefits (£m):  [val]         [val]         [val]
NPV (£m):          0             [val]         [val]
BCR:               -             [val]         [val]
VfM:               -             [val]         [val]

Referent Group NPV (£m):  0     [val]         [val]
Non-Referent NPV (£m):    0     [val]         [val]

Incremental (Do Min -> Preferred):
  Incremental NPV: [val]    Incremental BCR: [val]

Switching value (benefits): [val]% [rise/fall] makes NPV = 0
Switching value (costs):    [val]% [fall/rise] makes NPV = 0

Sensitivity:
              Pessimistic    Central    Optimistic
NPV (£m):    [val]          [val]      [val]
BCR:         [val]          [val]      [val]

[If distributional weights applied:]
Distributionally weighted NPV: [val]

[If Monte Carlo run:]
Probability of positive NPV: [X]%
```

Note: PV Costs for Do Nothing may be non-zero if the counterfactual has costs (e.g., deterioration, emergency repairs). In that case, these avoided costs count as benefits of intervention.

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
- Carbon impact (if applicable: tonnes CO2e, carbon price, PV of carbon costs/benefits)
- NPV and BCR comparison (all options, VfM categories)
- Incremental analysis (if 3+ options: is the extra spend from Do Min to Preferred worth it?)
- Switching values (what % change breaks the case)
- Sensitivity analysis (optimistic/central/pessimistic)
- Stakeholder analysis (multiple account table: referent group vs non-referent group breakdown by stakeholder)
- Distributional analysis (who bears costs, who receives benefits; welfare weights if applied)
- Place-based context (levelling up, IMD ranking, local priorities; UK only)
- Monte Carlo / probabilistic analysis (probability distribution of NPV outcomes)
- Financial analysis (cash flow to the investing entity, separate from economic/social CBA)
- Appraisal summary table (one-page consolidated view)
- Methodology note (discount rate, optimism bias, additionality assumptions)
- Risk register (project-specific risks with likelihood, impact, mitigation)
- Multi-criteria analysis (non-monetised benefits scoring)
- References

**After the content questions, ask about output formats.**

**If `--format` was NOT specified on the command line**, ask using AskUserQuestion:

Question: "What file formats do you need?"

Options (multiSelect: true):
- Markdown (.md) : Default, always included. Plain text you can paste anywhere
- Excel (.xlsx) : Full CBA model workbook with IB-style formatting (blue inputs, linked formulas, scenario toggles)
- Word (.docx) : Formatted document for editing in Microsoft Word
- PowerPoint (.pptx) : Slide deck with key numbers, tables, and methodology note
- PDF : Branded consulting-quality PDF via Quarto

Markdown is always generated regardless of selection. If the user selects nothing beyond markdown, that is fine.

**If `--format` was specified on the command line**, skip the format question and use the specified format(s). If `--format all`, expand to `["markdown", "xlsx", "word", "pptx", "pdf"]`.

**If `--full` was specified** (without `--format`), skip all questions and generate markdown only. If `--full` was specified WITH `--format`, skip content questions but generate the specified format(s).

### Step 6: Generate the requested output

**Always include the key numbers block at the very top of any markdown output:**

```markdown
<!-- KEY NUMBERS
framework: [framework name]
perspective: [social/investor/fiscal/local]
referent_group: [description]
project: [project name]
preferred_option: [option name]
npv_m: [val]
referent_group_npv_m: [val]
bcr: [val]
vfm: [category]
pv_costs_m: [val]
pv_benefits_m: [val]
switching_value_benefits_pct: [val]
switching_value_costs_pct: [val]
optimism_bias_pct: [val]
additionality_factor: [val]
discount_rate: [val]
appraisal_period: [val]
price_base_year: [val]
date: [date]
-->
```

This block is invisible when rendered but lets the user (or a future tool) extract the headline numbers without parsing the prose.

**Always save a companion JSON file** alongside any markdown output: `cba-data-{project-slug}-{date}.json`.

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

| Variable | Central PV (£m) | Value at NPV = 0 (£m) | Change required |
|----------|-----------------|----------------------|-----------------|
| Total benefits | [val] | [val] | [val]% [increase/decrease] |
| Total costs | [val] | [val] | [val]% [decrease/increase] |
| [Key benefit] | [val] | [val] | [val]% [increase/decrease] |

[IMPORTANT: Use the correct interpretation based on whether NPV is positive or negative.

If NPV > 0:
  "Benefits could fall by [val]% (or costs rise by [val]%) before the preferred
  option ceases to represent positive value for money."
  If switching value > 30%: "This suggests the case is robust to significant
  variation in assumptions."
  If switching value < 15%: "The case is sensitive to assumptions. Small changes
  could alter the conclusion."

If NPV < 0:
  "Benefits would need to rise by [val]% (or costs fall by [val]%) for the
  preferred option to achieve positive value for money on monetised benefits alone."
  Add: "The gap could narrow if non-monetised benefits were quantified."
  If switching value < 25%: "The case is close to breakeven and may be viable
  with refined benefit estimates or inclusion of non-monetised benefits."
  If switching value > 50%: "The gap is substantial. A strong strategic case
  or materially higher benefit estimates would be needed."]
```

**Sensitivity analysis:**
```markdown
## Sensitivity Analysis

### Scenario sensitivity

| Scenario | PV Benefits ([currency]m) | PV Costs ([currency]m) | NPV ([currency]m) | BCR | VfM still positive? |
|----------|--------------------------|----------------------|-------------------|-----|---------------------|
| Pessimistic (-20% benefits, +20% costs) | [val] | [val] | [val] | [val] | [Yes/No] |
| **Central** | **[val]** | **[val]** | **[val]** | **[val]** | **Yes/No** |
| Optimistic (+20% benefits, -20% costs) | [val] | [val] | [val] | [val] | [Yes/No] |

[Interpretation: does the option still represent positive VfM under pessimistic assumptions?]

### Per-variable sensitivity (tornado analysis)

Each variable tested independently at +/-20%, all others held at central values. Sorted by impact (widest range first).

| Variable | -20% NPV ([currency]m) | Central NPV | +20% NPV ([currency]m) | Range | NPV positive at worst? |
|----------|----------------------|-------------|----------------------|-------|----------------------|
| [Most sensitive variable] | [val] | [val] | [val] | [val] | [Yes/No] |
| [Second most sensitive] | [val] | [val] | [val] | [val] | [Yes/No] |
| [Third] | [val] | [val] | [val] | [val] | [Yes/No] |
| [Fourth] | [val] | [val] | [val] | [val] | [Yes/No] |
| [Fifth] | [val] | [val] | [val] | [val] | [Yes/No] |

The conclusion is most sensitive to **[top variable]**. [Interpretation of what this means for the robustness of the case.]

### Discount rate sensitivity

| Discount rate | PV Costs ([currency]m) | PV Benefits ([currency]m) | NPV ([currency]m) | BCR |
|--------------|----------------------|--------------------------|-------------------|-----|
| [Low rate]% | [val] | [val] | [val] | [val] |
| **[Central rate]% (framework default)** | **[val]** | **[val]** | **[val]** | **[val]** |
| [High rate]% | [val] | [val] | [val] | [val] |

[For UK: "NPV at 3.5% declining (Green Book default): [val]. At flat 3.5% (without declining schedule): [val]. The declining schedule [increases/has minimal effect on] NPV for this [X]-year appraisal."]
[For AU: "The Australian Government requires presentation at 4%, 7% (central), and 10%. The project delivers positive NPV at [all three / 4% and 7% only / 7% only]."]
[For US: "NPV at revised A-4 rate (2% declining): [val]. At legacy 3%: [val]. At legacy 7%: [val]."]

### Break-even analysis by variable

| Variable | Central value | Break-even value (NPV=0) | Change required | Plausibility |
|----------|-------------|--------------------------|-----------------|-------------|
| [Benefit 1] | [currency][val]m/yr | [currency][val]m/yr | -[X]% | [Plausible / Unlikely / Implausible] |
| [Capital cost] | [currency][val]m | [currency][val]m | +[X]% | [Plausible / Unlikely / Implausible] |
| [Benefit growth rate] | [X]% p.a. | [X]% p.a. | [change] | [Plausibility] |
| [Discount rate] | [X]% | [X]% | +[X]pp | [Plausibility] |
| [Appraisal period] | [X] years | [X] years | -[X] years | [Plausibility] |

[Interpretation: "The most plausible route to a negative NPV is [variable]. The break-even point of [value] would require [real-world interpretation, e.g. 'demand 35% below the central forecast, which exceeds the worst outcome observed in comparable projects']."]

### Named scenario analysis

| Scenario | Description | Key changes vs central | NPV ([currency]m) | BCR |
|----------|------------|----------------------|-------------------|-----|
| **Central** | Base case | As modelled | [val] | [val] |
| **[Scenario 1]** | [e.g. "Construction delay"] | [e.g. "+2yr delay, +10% capex"] | [val] | [val] |
| **[Scenario 2]** | [e.g. "Low demand"] | [e.g. "Benefits -30%"] | [val] | [val] |
| **[Scenario 3]** | [e.g. "High input costs"] | [e.g. "Capex +25%, opex +15%"] | [val] | [val] |

[Interpretation: "Under [X] of [Y] scenarios tested, the project still delivers positive NPV. The case is [robust / sensitive to specific risks / marginal]."]
```

**Incremental analysis (if 3+ options):**
```markdown
## Incremental Analysis

Comparing the additional cost and benefit of moving from [Option 2] to [Option 3]:

| Metric | [Option 2] vs Do Nothing | [Option 3] vs Do Nothing | Increment ([Option 2] to [Option 3]) |
|--------|------------------------|------------------------|--------------------------------------|
| PV Costs (£m) | [val] | [val] | [val] |
| PV Benefits (£m) | [val] | [val] | [val] |
| NPV (£m) | [val] | [val] | [val] |
| BCR | [val] | [val] | [val] |

[If incremental BCR > 1.0: "The additional spend to move from [Option 2] to [Option 3] generates positive incremental value (BCR [val]). The larger option is justified."]
[If incremental BCR < 1.0: "The additional spend to move from [Option 2] to [Option 3] does not generate sufficient incremental benefit (BCR [val]). Consider whether [Option 2] delivers sufficient outcomes at lower cost."]

Note: NPV is the primary ranking metric (Green Book). However, incremental BCR helps decision-makers understand whether the extra spend on a larger option is justified, or whether a smaller, cheaper option delivers better marginal returns.
```

**Carbon impact (if applicable):**
```markdown
## Carbon Impact

| Carbon category | Annual tCO2e | Direction | PV of carbon value (£m) |
|----------------|-------------|-----------|------------------------|
| [Construction embodied carbon] | [val] | Emission (+) | [val] |
| [Operational carbon savings] | [val] | Saving (-) | [val] |
| **Net carbon impact** | **[val]** | **[net direction]** | **[val]** |

Carbon valued at [framework-specific price] per tCO2e ([source]: [price path description]).

Carbon values are not subject to additionality adjustments (they are global externalities). They are included in the benefit/cost totals above.
```

**Financial analysis (if requested):**
```markdown
## Financial Analysis

This section presents the financial (cash flow) case for the investing entity, separate from the economic (societal welfare) analysis above. The financial analysis:
- Includes taxes, grants, and transfers (which cancel in social CBA)
- Uses a financial discount rate (cost of capital to the investing entity)
- Shows the funding requirement and financial sustainability

| Year | Capital outlay | Operating costs | Revenue/funding | Net cash flow | Cumulative cash flow |
|------|---------------|----------------|-----------------|---------------|---------------------|
| [year-by-year rows] |

| Metric | Value |
|--------|-------|
| Total funding requirement | £[val]m |
| Financial NPV (at [X]% cost of capital) | £[val]m |
| Financial rate of return (FRR) | [val]% |
| Payback period | [val] years |

[Note: A negative financial NPV is common for public infrastructure. It means the project requires public subsidy to be financially viable, which is the rationale for public investment. The economic case (positive societal NPV) provides the justification.]
```

**Stakeholder analysis and distributional analysis:**
```markdown
## Stakeholder Analysis (Multiple Account Framework)

**Perspective:** [Social/Investor/Fiscal/Local]
**Referent group:** [Description, e.g. "All UK residents"]

### Multiple account table

| Stakeholder group | In referent group? | PV Costs ([currency]m) | PV Benefits ([currency]m) | Net position ([currency]m) |
|-------------------|-------------------|----------------------|--------------------------|--------------------------|
| [Group 1, e.g., central government] | Yes | [val] | [val] | [val] |
| [Group 2, e.g., local residents] | Yes | [val] | [val] | [val] |
| [Group 3, e.g., transport users] | Yes | [val] | [val] | [val] |
| [Group 4, e.g., private operator] | Yes | [val] | [val] | [val] |
| [Group 5, e.g., foreign contractors] | No | [val] | [val] | [val] |
| **Referent group total** | | **[val]** | **[val]** | **[val]** |
| **Non-referent group total** | | **[val]** | **[val]** | **[val]** |
| **Efficiency total (all groups)** | | **[val]** | **[val]** | **[val]** |

Identity check: Referent group NPV ([val]) + Non-referent group NPV ([val]) = Efficiency NPV ([val]).

[Interpretation:
- Which groups are net contributors (bear more costs than they receive in benefits) and which are net beneficiaries.
- If Referent Group NPV differs from Efficiency NPV, explain where the value leaks to (e.g. "Foreign contractors capture [X]% of project value through construction contracts").
- For local/regional CBAs: "Of the total efficiency gain, [X]% accrues within the [area] boundary."
- If any group within the referent group is a significant net loser, flag this as a potential political or equity concern even if the aggregate referent group NPV is positive.]

### Who bears the costs and who receives the benefits

| Group | Share of costs | Share of benefits | Net position |
|-------|---------------|------------------|-------------|
| [Group 1] | [X]% | [X]% | Net [contributor/beneficiary] |
| [Group 2] | [X]% | [X]% | Net [contributor/beneficiary] |
| [Group 3] | [X]% | [X]% | Net [contributor/beneficiary] |

[If welfare weights applied:]

### Distributionally weighted analysis

Using Green Book welfare weights (elasticity of marginal utility = 1.3):

| Income group | Estimated share of benefits | Welfare weight | Weighted share |
|-------------|---------------------------|---------------|---------------|
| Below median income | [X]% | [val] | [val]% |
| Around median income | [X]% | 1.00 | [X]% |
| Above median income | [X]% | [val] | [val]% |

| Metric | Unweighted | Distributionally weighted |
|--------|-----------|--------------------------|
| NPV ([currency]m) | [val] | [val] |
| BCR | [val] | [val] |

[Interpretation: "Distributional weighting [increases/decreases] the NPV by [currency][val]m, reflecting that benefits accrue disproportionately to [lower/higher]-income groups."]
```

**Place-based context (UK Green Book only, if applicable):**
```markdown
## Place-Based Context

[Project location] is in [local authority], which ranks [X] of 317 on the Index of Multiple Deprivation ([year]). [Key deprivation characteristics: income, employment, education, health, barriers to housing].

| Place-based indicator | Local value | England average | Comparison |
|----------------------|-------------|-----------------|------------|
| IMD rank (1 = most deprived) | [val] | - | [decile] |
| Claimant count rate | [X]% | [X]% | [above/below] |
| Median weekly earnings | £[val] | £[val] | [above/below] |
| GVA per head | £[val] | £[val] | [above/below] |
| Levelling Up Fund category | [1/2/3] | - | [Priority/Standard] |

[Relevance to the appraisal: "The area's [characteristic] suggests [lower displacement / higher additionality / stronger regeneration case]. This context supports [adjustment or interpretation]."

If the area is a Levelling Up Category 1 area, Freeport, or Investment Zone, note: "This project aligns with government place-based investment priorities."]
```

**Monte Carlo / probabilistic analysis (if computed):**
```markdown
## Probabilistic Risk Analysis

10,000 Monte Carlo iterations with cost uncertainty (triangular: 0.80 to 1.50, mode 1.00) and benefit uncertainty (triangular: 0.50 to 1.20, mode 1.00).

| Percentile | NPV (£m) | BCR |
|-----------|----------|-----|
| P5 (worst 5%) | [val] | [val] |
| P25 | [val] | [val] |
| **P50 (median)** | **[val]** | **[val]** |
| P75 | [val] | [val] |
| P95 (best 5%) | [val] | [val] |
| **Mean** | **[val]** | **[val]** |

| Probability metric | Value |
|-------------------|-------|
| Probability of NPV > 0 | [X]% |
| Probability of BCR > 1.0 | [X]% |
| Probability of BCR > 2.0 | [X]% |

[Interpretation: "There is a [X]% probability that this project delivers positive value for money. Even under the worst 5% of scenarios, the NPV is £[val]m, suggesting the downside risk is [limited/significant]. The distribution is [symmetric/skewed toward negative outcomes], reflecting the asymmetric risk profile typical of [infrastructure/policy] projects."

If probability of NPV > 0 exceeds 70%: "The probabilistic analysis supports the central case."
If probability of NPV > 0 is 40-70%: "The outcome is uncertain. The case depends heavily on benefit realisation."
If probability of NPV > 0 is below 40%: "The probabilistic analysis suggests the project is more likely than not to deliver negative NPV."]
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

**Risk register:**
```markdown
## Risk Register

| # | Risk | Likelihood | Impact | Mitigation | Residual risk |
|---|------|-----------|--------|------------|---------------|
| R1 | Cost overrun beyond optimism bias | Medium/High | High | Reference class forecasting, fixed-price contracts | Medium |
| R2 | Benefit shortfall / demand below forecast | Medium | High | Conservative demand assumptions, phased delivery | Medium |
| R3 | Construction delay | Medium | Medium | Programme contingency, early contractor engagement | Low |
| R4 | Regulatory/planning risk | Low/Medium | High | Early engagement, planning pre-application | Low |

[Generate 4-6 project-specific risks based on:
- Sector (transport: demand risk, induced traffic; health: clinical outcomes; energy: technology risk)
- Scale (larger projects: supply chain, labour market constraints)
- Location (urban: planning, disruption; rural: access, connectivity)
- Framework (UK: spending review risk; EU: co-financing conditions)
- Stage (SOC: scope creep; OBC: procurement risk; FBC: delivery risk)]

Likelihood: Low / Low-Medium / Medium / Medium-High / High
Impact: Low / Medium / High / Very High
Residual risk: the risk level after mitigation measures are applied.
```

**Multi-criteria analysis:**
```markdown
## Multi-Criteria Analysis: Non-Monetised Benefits

| Criterion | Weight | Do Nothing | [Option 2] | [Option 3] |
|-----------|--------|-----------|------------|------------|
| [Regeneration impact] | [X]/10 | 0 | [1-5] | [1-5] |
| [Environmental quality] | [X]/10 | 0 | [1-5] | [1-5] |
| [Social inclusion / equity] | [X]/10 | 0 | [1-5] | [1-5] |
| [Deliverability / feasibility] | [X]/10 | [1-5] | [1-5] | [1-5] |
| [Strategic alignment] | [X]/10 | [1-5] | [1-5] | [1-5] |
| **Weighted total** | | **[val]** | **[val]** | **[val]** |

Scoring: 0 = no impact, 1 = slight positive, 2 = moderate positive, 3 = significant positive, 4 = large positive, 5 = transformative.

[Ask the user to score each criterion, or suggest scores based on the project description with justification. Criteria should be tailored to the project type and sector.]

This analysis complements the monetised NPV/BCR assessment. Where non-monetised benefits are significant, the MCA may support a different option ranking than NPV alone.
```


**Methodology note:**
```markdown
**Methodology:** Social cost-benefit analysis following [framework name and edition]. Discount rate: [rate and schedule]. [If optimism bias applied: "Optimism bias: [X]% on capital costs ([source], [project type], [stage])."] [If additionality applied: "Additionality: [X]% deadweight, [X]% displacement, [X]% leakage ([source])."] [If carbon valued: "Carbon valued at [price]/tCO2e ([source])."] All costs and benefits in [year] real prices. NPV and BCR computed for each option against the Do Nothing counterfactual. [If benefit ramp-up used: "Benefits ramped up linearly over [X] years post-construction."] [If S-curve phasing: "Capital costs phased using an S-curve profile over [X] years."]
```

**References (framework-specific):**

For UK Green Book:
```markdown
## References

- HM Treasury (2022, updated 2026). "The Green Book: Central Government Guidance on Appraisal and Evaluation."
- HM Treasury. "Green Book supplementary guidance: optimism bias."
- HM Treasury. "Green Book supplementary guidance: discounting."
- HM Treasury (2014). "Additionality Guide", 4th edition.
- DLUHC (2025). "The Appraisal Guide", 3rd edition.
- DESNZ (2024). "Valuation of greenhouse gas emissions: for policy appraisal and evaluation."
- Campbell, H.F. and Brown, R.P.C. (2016). "Cost-Benefit Analysis: Financial and Economic Appraisal Using Spreadsheets", 2nd edition. Routledge.
- Campbell, H.F. and Brown, R.P.C. (2016). "Cost-Benefit Analysis: Financial and Economic Appraisal Using Spreadsheets", 2nd edition. Routledge.
- Boardman, A.E. et al. (2018). "Cost-Benefit Analysis: Concepts and Practice", 5th edition. Cambridge University Press.
```

For EU Cohesion Policy:
```markdown
## References

- European Commission (2014). "Guide to Cost-Benefit Analysis of Investment Projects." DG Regional and Urban Policy.
- European Commission (2021). "Economic Appraisal Vademecum 2021-2027."
- European Investment Bank (2023). "The Economic Appraisal of Investment Projects at the EIB", 2nd edition.
- Campbell, H.F. and Brown, R.P.C. (2016). "Cost-Benefit Analysis: Financial and Economic Appraisal Using Spreadsheets", 2nd edition. Routledge.
- Boardman, A.E. et al. (2018). "Cost-Benefit Analysis: Concepts and Practice", 5th edition.
```

For US OMB:
```markdown
## References

- Office of Management and Budget (2023). "Circular A-4: Regulatory Analysis." Revised November 2023.
- Office of Management and Budget (2023). "Circular A-94: Guidelines and Discount Rates for Benefit-Cost Analysis of Federal Programs." Revised November 2023.
- EPA (2023). "Report on the Social Cost of Greenhouse Gases."
- Campbell, H.F. and Brown, R.P.C. (2016). "Cost-Benefit Analysis: Financial and Economic Appraisal Using Spreadsheets", 2nd edition. Routledge.
- Boardman, A.E. et al. (2018). "Cost-Benefit Analysis: Concepts and Practice", 5th edition.
```

For other frameworks, include the framework's primary guidance document plus Campbell & Brown (2016) and Boardman et al. (2018) as general references.

**Slide summary:**
```markdown
**[Project Name]: Value for Money Summary**

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

**Then generate each additional format the user selected:**

**Markdown** (always generated):
Save as `cba-{project-slug}-{date}.md`. This is the primary output. No extra steps needed.

**Excel (.xlsx)** (if selected):
Invoke the `/xlsx` skill to create an investment-bank-quality CBA model workbook. Pass the companion JSON data and instruct the skill to create the following sheets:

1. **Cover** sheet: Project name, date, framework, price base year, appraisal period, "Prepared for" (if `--client`). Clean title block, no gridlines. Below the title block, include a **Model Guide** section explaining:
   - Purpose: "This workbook contains a full cost-benefit analysis following HM Treasury Green Book methodology."
   - Sheet descriptions: one-line explanation of each sheet and what it contains (Assumptions, Cost Schedule, Benefit Schedule, Summary, Sensitivity)
   - How to use: "Blue cells are user inputs. Change these to run your own scenarios. All other cells are formulas and should not be edited."
   - Key conventions: "All values in £m unless stated. Discount factors use the Green Book declining schedule (3.5% years 0-30, 3.0% years 31-75, 2.5% years 76+). Optimism bias is applied to capital costs only."
   - Caveats: "These are indicative estimates. See the Methodology note in the Summary sheet for full details and limitations."

2. **Assumptions** sheet: All input parameters in a clearly labelled panel:
   - Discount rate schedule (3.5% / 3.0% / 2.5% with year thresholds)
   - Optimism bias rate
   - Additionality rates (deadweight, displacement, leakage, net factor)
   - Benefit growth rates
   - Appraisal period
   - **Formatting:** Blue font (#0000FF) on light blue fill (#DCE6F1) for all user-adjustable inputs. Black font for calculated/derived values. This is the IB convention: blue = input, black = formula.

3. **Cost Schedule** sheet: Year-by-year cost schedule for each option:
   - Columns: Year | Capex (raw) | Optimism bias adjustment | Capex (adjusted) | Opex | Total cost (undiscounted) | Discount factor | PV cost
   - Totals row at bottom with SUM formulas
   - **Formatting:** Header row in dark navy (#003078) with white text. Alternating row stripes (#F2F2F2). Currency formatted to 1 decimal (£m). Discount factors to 6 decimal places.

4. **Benefit Schedule** sheet: Year-by-year benefit schedule for each option:
   - Columns: Year | Gross benefit | Growth factor | Gross benefit (grown) | Additionality factor | Net benefit | Residual value | Total benefit (undiscounted) | Discount factor | PV benefit
   - Totals row at bottom
   - Same formatting as Cost Schedule.

5. **Summary** sheet: The key results dashboard:
   - Options comparison table (PV costs, PV benefits, NPV, BCR, VfM category for each option)
   - Switching values table
   - Sensitivity analysis table (pessimistic/central/optimistic)
   - **Formatting:** KPI values in large bold font. Positive NPV in green (#006100), negative NPV in red (#9C0006). BCR < 1.0 highlighted red, BCR >= 2.0 highlighted green. Conditional formatting on VfM category.

6. **Sensitivity** sheet: Full sensitivity matrix:
   - Rows: benefit variation (-30% to +30% in 10% steps)
   - Columns: cost variation (-30% to +30% in 10% steps)
   - Cell values: NPV for each combination
   - **Formatting:** Heat map conditional formatting (red for negative NPV, green for positive). Central case highlighted with thick border.

General Excel formatting rules (IB/Goldman style):
- Font: Calibri 10pt throughout. Headers Calibri 11pt bold.
- Blue font (#0000FF) on light blue fill (#DCE6F1) for ALL user inputs/assumptions. This is the single most important formatting convention.
- Black font for all formulas and calculated values.
- Thin borders on all data tables. Thick bottom border on header rows and total rows.
- No gridlines on any sheet. Print area set.
- Column widths auto-fitted. Row heights consistent.
- Number formats: currency to 1dp with £ symbol, percentages to 1dp, years as integers, discount factors to 6dp.
- Freeze panes: freeze header row and year column on schedule sheets.
- Sheet tab colours: Cover (navy), Assumptions (blue), Cost Schedule (red), Benefit Schedule (green), Summary (gold), Sensitivity (grey).

Save as `cba-{project-slug}-{date}.xlsx`.

**Word (.docx)** (if selected):
Invoke the `/docx` skill to convert the markdown report into a formatted Word document. Pass the full markdown content and instruct the skill to:
- Use a professional layout with navy (#003078) headings
- Format all tables with borders and header row styling
- Include the report title and subtitle on the first page
- If `--client` was specified, include "Prepared for: [client]" on the first page
Save as `cba-{project-slug}-{date}.docx`.

**PowerPoint (.pptx)** (if selected):
Invoke the `/pptx` skill to create a slide deck. Instruct it to create these slides:
1. Title slide: "Cost-Benefit Analysis" with project name, framework, and date
2. Options slide: table of options with descriptions
3. Key results slide: PV costs, PV benefits, NPV, BCR, VfM for each option in a clean grid
4. Cost breakdown slide: cost table (capital/operating, optimism bias, PV)
5. Benefit breakdown slide: benefit table (categories, additionality, PV)
6. Switching values slide: table showing how far assumptions can move before NPV turns negative/positive
7. Sensitivity slide: pessimistic/central/optimistic table with interpretation
8. Methodology slide: one-paragraph methodology summary and key caveats
Use navy (#003078) as the accent colour. If `--client` was specified, include "Prepared for: [client]" on the title slide.
Save as `cba-{project-slug}-{date}.pptx`.

**Executive summary deck** (if `--exec` specified):

Invoke the `/pptx` skill to create a management consulting-style executive summary deck. This is a separate file from the standard PPTX. Every slide follows the **action title + evidence** pattern: a 2-line strapline at the top stating the conclusion (not a topic label), then 3-4 dot points or a chart proving it.

**Formatting rules for all exec summary slides:**
- Action title: 2 lines max, bold, 24-28pt, navy (#003078). Must be a complete sentence stating an insight, NOT a topic label. "This project delivers high value for money" not "Value for Money Results".
- Subtitle/strapline: 16pt, dark grey (#333333), directly below title
- Body: 3-4 bullet points, 14-16pt. One key number bolded per point.
- Charts: simple (bar, waterfall, tornado), max one per slide, navy (#003078) / grey (#666666) / light blue (#4472C4) palette
- Footer on every slide: 10pt, light grey, methodology one-liner + date + "Source: [framework]"
- No decorative elements, no gradients, no clip art. Clean white background.
- Slide numbers bottom-right

**Slide 1: Title**
- Project name (large, navy)
- "Cost-Benefit Analysis" subtitle
- Framework, date, "Prepared for: [client]" if specified
- Perspective and referent group in small text

**Slide 2: The ask**
- Action title: "This appraisal evaluates [X] options for [1-line project description]"
- Evidence: 1 bullet per option (name + 1-line description)
- Note the counterfactual: "The Do Nothing scenario assumes [description]"
- If perspective is not social/public, note: "Analysis from [perspective] perspective, counting impacts on [referent group]"

**Slide 3: Headline verdict**
- Action title: "[Preferred option] delivers [VfM category] value for money" (or "does not deliver positive value for money" if NPV < 0)
- Evidence:
  - **NPV: [currency][val]m** under central assumptions
  - **BCR: [val]** ([VfM category])
  - Benefits could fall **[switching value]%** before the case turns negative (or "Benefits would need to rise [X]% to break even" if NPV < 0)
  - Referent Group NPV: [val] (if materially different from Efficiency NPV, explain in 1 line)

**Slide 4: Who pays, who benefits**
- Action title: "[Primary cost-bearer] funds the project; [primary beneficiary group] captures most of the value" (or whatever the multiple-account table reveals)
- Evidence: Simplified 3-4 row version of the multiple-account table:
  - [Group 1]: net [contributor/beneficiary] by [currency][val]m
  - [Group 2]: net [contributor/beneficiary] by [currency][val]m
  - [Group 3 if outside referent group]: captures [currency][val]m (outside referent group)
- If Referent Group NPV differs significantly from Efficiency NPV, explain in 1 bullet

**Slide 5: Cost breakdown**
- Action title: "Total costs of [currency][val]m are [front-loaded / spread over X years / concentrated in years X-Y]"
- Evidence:
  - Capital: [currency][val]m (including [X]% optimism bias)
  - Operating: [currency][val]m over [X] years
  - [If renewals]: Major renewal at year [X]: [currency][val]m
- Optional: simple stacked bar chart showing cost phasing over time

**Slide 6: Benefit breakdown**
- Action title: "Benefits of [currency][val]m are driven by [top benefit category]"
- Evidence:
  - [Top category]: [currency][val]m PV ([X]% of total)
  - [Second category]: [currency][val]m PV
  - [Third category]: [currency][val]m PV
  - Non-monetised: [1-line description of key non-monetised benefits]
- Optional: horizontal bar chart of benefit categories

**Slide 7: How robust is the case?**
- Action title: "The case is robust: benefits could fall [X]% before NPV turns negative" (or "The case is sensitive to assumptions: a [X]% change in [key variable] would reverse the conclusion")
- Evidence:
  - Pessimistic scenario: NPV [currency][val]m, BCR [val]
  - Central scenario: NPV [currency][val]m, BCR [val]
  - Optimistic scenario: NPV [currency][val]m, BCR [val]
  - [If Monte Carlo was run]: Probability of positive NPV: [X]%
- Optional: tornado chart showing switching values for top 3 variables

**Slide 8: Risks and next steps**
- Action title: "Recommend proceeding to [next stage] subject to [key condition]" (or "Further analysis needed before proceeding" if case is marginal)
- Evidence:
  - Top 3 risks (1 bullet each: risk + mitigation)
  - 2-3 recommended next steps
- Footer: "Full CBA report: cba-{slug}-{date}.md"

Save as `cba-exec-{project-slug}-{date}.pptx`.

If `--exec` is combined with `--format pptx`, generate both files (the standard data deck AND the exec summary deck).

**PDF** (if selected):
Render the markdown through the EconStack template:
```bash
ECONSTACK_DIR="$HOME/.claude/skills/econstack"
"$ECONSTACK_DIR/scripts/render-report.sh" cba-{project-slug}-{date}.md \
  --title "Cost-Benefit Analysis" \
  --subtitle "[Project name]" \
  [--client "{client name}" if specified]
```
If Quarto is not installed, tell the user: "PDF rendering requires Quarto (https://quarto.org). The markdown report has been saved."

Tell the user what was generated, listing only the files that were actually produced:
```
Files saved:
  cba-{slug}-{date}.md       (report / selected sections)
  cba-data-{slug}-{date}.json (structured data)
  cba-{slug}-{date}.xlsx     (if Excel selected)
  cba-{slug}-{date}.docx     (if Word selected)
  cba-{slug}-{date}.pptx     (if PowerPoint selected)
  cba-{slug}-{date}.pdf      (if PDF selected)
```

**If `--audit` was specified:**

After saving all files, invoke the `/econ-audit` skill on the generated markdown file:
  /econ-audit cba-{project-slug}-{date}.md

This produces an audit scorecard alongside the report, catching any methodology issues before submission. The audit will cross-check the companion JSON against the prose numbers.

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
- **Always establish perspective and referent group before entering costs and benefits.** A CBA without a defined perspective is methodologically incomplete. The perspective determines what counts as a cost or benefit (e.g. taxes are a cost in an investor CBA but a transfer in a social CBA). The referent group determines whose NPV matters to the decision-maker.
- **Always produce the multiple-account table.** Every CBA output must include the stakeholder-level breakdown showing referent vs non-referent group flows. This is the core output that prevents the error of summing everyone's benefits against one group's costs.
- **Verify the Campbell-Brown identity.** Referent Group NPV + Non-Referent Group NPV must equal Efficiency NPV. If it does not, there is a stakeholder tagging error.
- **Discount rate must use the correct schedule for the selected framework.** For UK Green Book, do not apply 3.5% flat beyond year 30. For flat-rate frameworks, use the correct rate. This is the most common CBA error.
- **Optimism bias must not be zero** for UK Green Book infrastructure projects unless the user explicitly overrides with justification. Flag it if they set it to 0. For non-UK frameworks, optimism bias is typically 0% (handled through sensitivity instead); do not apply it unless the user requests it.
- **Always ask about project stage** for UK Green Book infrastructure appraisals. SOC/OBC/FBC determines the optimism bias rate. Using SOC rates at FBC stage overstates costs; using FBC rates at SOC stage understates risk.
- **Benefit ramp-up is the default for infrastructure.** Benefits rarely start at full value on day one. Default to a 3-year linear ramp-up for infrastructure unless the user specifies otherwise.
- **Carbon valuation should be prompted** for any project with plausible environmental impacts. Use framework-specific carbon prices. Carbon costs/benefits are not subject to additionality adjustments.
- **Incremental analysis is required** when appraising 3+ options. Always show the incremental NPV/BCR of moving between adjacent options, not just each vs Do Nothing.
- **Switching values must be interpreted correctly.** When NPV is negative, benefits need to rise (not fall). When NPV is positive, benefits can fall. Never state "benefits would need to fall by X%" when NPV is already negative.
- **Do not double count.** If a benefit appears in two categories (e.g., journey time savings AND land value uplift that derives from those savings), flag the potential overlap.
- **Transfers are not costs or benefits.** Taxes, subsidies, and grants are transfers between parties. They cancel at the societal level in social CBA. Only include them in financial CBA.
- **Sunk costs are excluded.** Costs already incurred that cannot be recovered should not be included.
- **NPV is the primary metric, not BCR.** The Green Book is clear: NPV determines the ranking. BCR is supplementary. A project with higher NPV but lower BCR is preferred.
- **Always compute switching values.** They are the most useful output for decision-makers because they answer "how wrong can we be before this stops being worth doing?"
- Be specific about price base year, appraisal period, and which Green Book edition.
- The companion JSON must include the full year-by-year discounted cost/benefit schedule.
- When Excel, Word, PowerPoint, or PDF format is selected, invoke the corresponding skill (`/xlsx`, `/docx`, `/pptx`, or render script) to generate the file. Pass the markdown content and the companion JSON data so the skill has all the numbers it needs.
- Markdown is always generated, even when other formats are selected. It is the source for all other formats.
- The Excel model is the highest-value output for most users. It must be IB-quality: blue inputs, linked formulas, proper number formatting, conditional formatting on NPV/BCR. Do not cut corners on Excel formatting.
