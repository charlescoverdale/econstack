---
name: business-case
description: Five Case Model business case. Strategic, Economic, Commercial, Financial, Management cases. UK Green Book, Australian (Commonwealth/Victoria HVHR/NSW/Queensland), NZ, EU, World Bank. Interactive section picking.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
  - Skill
---



**Only stop to ask the user when:** which cases/sections to include, framework confirmation, cost or benefit figures needed, or procurement/governance details only they know.
**Never stop to ask about:** section ordering, table formatting, price base year (default to current), or methodology choices that follow from the framework selection.
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

# Business Case

Full Five Case Model business case generator. Covers all five cases (Strategic, Economic, Commercial, Financial, Management) with framework-specific guidance. Interactive: the user picks which cases and sections they want to complete.

## Arguments

```
/business-case [description] [options]
```

**Examples:**
```
/business-case
/business-case "New hospital wing in Greater Manchester"
/business-case --stage obc --framework uk
/business-case --case strategic,economic
/business-case --sections           (interactive section picker)
/business-case --full
/business-case --from inputs.json
```

**Options:**
- `--stage <name>` : Business case stage. Determines depth of each case. See stage table below.
- `--framework <name>` : Appraisal framework. Auto-detected from description if not specified. See framework table.
- `--case <list>` : Generate only specific cases. Comma-separated: `strategic`, `economic`, `commercial`, `financial`, `management`. Default: all five.
- `--sections` : Launch interactive section picker (checklist of all sub-sections across all cases)
- `--full` : Skip interactive menus, generate all sections at maximum depth
- `--format <type>` : Output format(s): `markdown`, `xlsx`, `word`, `pptx`, `pdf`, or `all`. Comma-separate for multiple. Default: markdown only
- `--client "Name"` : Add "Prepared for" metadata
- `--exec` : Generate executive summary deck (8-12 slides with action titles)
- `--audit` : After generating, automatically run `/econ-audit` on the output
- `--from <file.json>` : Import all inputs from JSON, skip interactive questions. Use `--from schema` to print the expected JSON schema.
- `--with-cba <file.json>` : Import existing `/cost-benefit` output for the economic case. Skips CBA computation.
- `--proportionality <level>` : Override auto-detected depth. `light` (<GBP 1m), `standard` (GBP 1-10m), `detailed` (GBP 10-100m), `comprehensive` (GBP 100m+)

**Supported stages:**

| Flag | Stage | UK equivalent | AU equivalent | Depth |
|------|-------|---------------|---------------|-------|
| `soc` | Strategic Outline Case | SOC | Strategic Assessment / Preliminary Evaluation | High-level, wide options |
| `obc` | Outline Business Case | OBC | Preliminary Business Case / Business Case Development | Full detail, shortlisted options |
| `fbc` | Full Business Case | FBC | Full Business Case / Second Pass | Final, negotiated, confirmed |

**Supported frameworks:**

| Flag | Framework | Discount rate | Declining? | Optimism bias approach | Business case structure |
|------|-----------|--------------|------------|------------------------|------------------------|
| `uk` | UK HM Treasury Green Book (default) | 3.5% | Yes (3.0% yr 31-75, 2.5% yr 76-125, 2.0% yr 126-200, 1.5% yr 201-300) | Fixed % uplifts by project type and stage | Five Case Model (SOC/OBC/FBC) |
| `au` | Australian Commonwealth (RMG 308) | 7% | No | Reference Class Forecasting (P50/P90) | Two-Pass Cabinet process |
| `au-vic` | Victoria DTF (HVHR) | 4% and 7% (report both) | No | RCF / P50-P90 | 3-stage lifecycle + 6 Gateway reviews |
| `au-nsw` | NSW Treasury (TPG24-29) | 7% (sensitivity: 3%, 10%) | No | RCF / P50-P90 | 3-stage (strategic/preliminary/full) |
| `au-qld` | Queensland Treasury (PAF) | 7% | No | RCF / P50-P90 | 8-stage PAF with BCDF |
| `nz` | New Zealand Treasury | 2% (non-commercial) / 8% (commercial) | No | Sensitivity testing | Better Business Cases (NZ variant) |
| `eu` | EU Better Regulation / DG Regio | 3% (advanced MS) / 5% (convergence) | No | Sensitivity testing | Regulatory Impact Assessment |
| `wb` | World Bank PAD | 10% (country-specific) | No | Sensitivity testing | Project Appraisal Document |
| `us` | US OMB Circular A-4 | 2% | Yes (long-term) | Sensitivity testing | Regulatory Impact Analysis |

---

## Framework-native heading maps

**Critical**: When generating the business case document, use the heading names and structure from the selected framework, NOT generic Five Case Model headings. The workflow steps (3-7) collect the same underlying content, but the output must be rendered in the framework's native structure and terminology.

### UK Five Case Model (`uk`)

```
Executive Summary
1. Strategic Case
   1.1 Strategic context
   1.2 Case for change
   1.3 Investment objectives
   1.4 Existing arrangements
   1.5 Business needs
   1.6 Potential scope and key service requirements
   1.7 Main benefits criteria
   1.8 Main risks
   1.9 Constraints and dependencies
2. Economic Case
   2.1 Critical success factors
   2.2 Long-listed options
   2.3 Short-listed options
   2.4 Economic appraisal
   2.5 Benefits appraisal
   2.6 Risk appraisal
   2.7 Sensitivity analysis
   2.8 Preferred option
3. Commercial Case
   3.1 Procurement strategy
   3.2 Required services
   3.3 Risk allocation and transfer
   3.4 Contract length and type
   3.5 Payment mechanisms
   3.6 Contractual issues and accountancy treatment
   3.7 Personnel implications (inc. TUPE)
4. Financial Case
   4.1 Impact on the income and expenditure account
   4.2 Impact on the balance sheet
   4.3 Overall affordability
5. Management Case
   5.1 Programme/project management arrangements
   5.2 Change management arrangements
   5.3 Benefits realisation arrangements
   5.4 Risk management arrangements
   5.5 Post-implementation review arrangements
   5.6 Gateway review arrangements
Appendices
```

### Victoria DTF Investment Lifecycle (`au-vic`)

Victoria uses a 10-chapter Investment Case / Delivery Case split, not the five-case model. Render the output in this structure:

```
Executive Summary

PART 1: INVESTMENT CASE

1. Problem Definition
   1.1 Background and context
   1.2 Problem statement
   1.3 Evidence base
   1.4 Stakeholders affected

2. Case for Change (Benefits)
   2.1 Benefits of addressing the problem
   2.2 Benefits register
   2.3 Benefits Management Plan
   2.4 Investment Logic Map

3. Response Option Development
   3.1 Strategic interventions considered
   3.2 Response options analysis
   3.3 Screening of response options

4. Project Options Assessment
   4.1 Shortlisted project options
   4.2 Stakeholder impacts
   4.3 Social impacts
   4.4 Environmental impacts
   4.5 Economic analysis (CBA at 4% and 7%)
   4.6 Financial analysis
   4.7 Sensitivity analysis
   4.8 Appraisal summary

5. Project Solution
   5.1 Preferred solution
   5.2 Key assumptions
   5.3 Evidence supporting the preferred solution

PART 2: DELIVERY CASE

6. Commercial and Procurement
   6.1 Procurement strategy
   6.2 Market engagement
   6.3 Risk allocation
   6.4 Contract type and payment mechanisms

7. Planning Environment, Heritage and Culture
   7.1 Regulatory approvals required
   7.2 Heritage and cultural considerations
   7.3 Environmental approvals

8. Project Schedule
   8.1 Key milestones
   8.2 Gateway review dates (Gates 1-6)
   8.3 Dependencies and critical path

9. Project Budget
   9.1 Capital cost estimate (P50 and P90)
   9.2 Operating cost estimate
   9.3 Funding sources and confirmation status
   9.4 Whole-of-life cost
   9.5 Affordability assessment

10. Management
    10.1 Governance and accountability
    10.2 Project management methodology
    10.3 Resource plan
    10.4 Change management
    10.5 Benefits realisation
    10.6 Monitoring and evaluation
    10.7 Risk register
    10.8 Assurance and Gateway review plan (PAP)

Appendices
  A: Investment Logic Map
  B: Benefits Management Plan
  C: Response Options Analysis Report
  D: CBA detailed tables (at 4% and 7%)
  E: Risk register
```

**Terminology mapping (VIC):**

| Generic term | Victoria DTF term |
|---|---|
| Case for change | Problem definition |
| Strategic case | Investment case (Part 1) |
| Benefits register | Benefits Management Plan |
| Options framework | Response option development |
| Short list | Project options assessment |
| Preferred option | Project solution |
| Commercial case | Commercial and procurement (Ch 6) |
| Financial case | Project budget (Ch 9) |
| Management case | Management (Ch 10) |
| Optimism bias | Reference Class Forecasting (P50/P90) |
| CDEL/RDEL | Capital cost estimate / Operating cost estimate |
| Gateway reviews | Gates 1-6 (DTF) |
| Spending Review period | State Budget forward estimates |

### NSW Treasury TPG24-29 (`au-nsw`)

NSW uses a component-based structure (Investment Case + Delivery Feasibility), not the five-case model:

```
Executive Summary

INVESTMENT CASE

3.1 Case for Change
    3.1.1 Problem definition
    3.1.2 Stakeholders
    3.1.3 Strategic context and alignment
    3.1.4 Logic model
    3.1.5 Objectives

3.2 Options
    3.2.1 Options framework (scope, solution, delivery, funding, timing)
    3.2.2 Long list and screening
    3.2.3 Short list
    3.2.4 Multi-criteria analysis
    3.2.5 Recommended option

3.3 Cost-Benefit Analysis
    3.3.1 Costs (capital and operating)
    3.3.2 Benefits (monetised and non-monetised)
    3.3.3 CBA results (NPV, BCR at 7%)
    3.3.4 Distributional analysis
    3.3.5 Sensitivity analysis (at 3% and 10%)

3.4 Financial Analysis
    3.4.1 Financial appraisal
    3.4.2 Financial Impact Statement (FIS)
    3.4.3 Funding sources

3.5 Risk Analysis
    3.5.1 Risk identification and register
    3.5.2 Risk quantification
    3.5.3 Sensitivity testing of key risks

3.6 Monitoring and Evaluation Approach
    3.6.1 M&E plan
    3.6.2 Benefits management framework

DELIVERY FEASIBILITY

4.1 Procurement Approach
    4.1.1 Market engagement
    4.1.2 Delivery model selection
    4.1.3 Contract strategy

4.2 Management Approach
    4.2.1 Governance
    4.2.2 Project management
    4.2.3 Stakeholder management
    4.2.4 Legal and regulatory compliance

Appendices
```

**Terminology mapping (NSW):**

| Generic term | NSW term |
|---|---|
| Strategic case | Investment Case: Case for Change (3.1) |
| Economic case | Investment Case: CBA (3.3) |
| Commercial case | Delivery Feasibility: Procurement Approach (4.1) |
| Financial case | Investment Case: Financial Analysis (3.4) |
| Management case | Delivery Feasibility: Management Approach (4.2) |
| Optimism bias | P50/P90 estimate basis |
| Financial Impact Statement | FIS (NSW-specific, required) |
| Gateway review | INSW IIAF / Treasury REAF / DCS DAF |

### Queensland PAF BCDF (`au-qld`)

Queensland uses a 20-chapter, 3-section structure (the most granular of all frameworks):

```
Executive Summary and Recommendation

SECTION A: PROPOSAL CONTEXT

1. Proposal Background (A1)
   1.1 Proposal context
   1.2 History of the proposal

2. Governance and Assurance (A2)
   2.1 Proposal owner
   2.2 Overall approach
   2.3 Steering committee
   2.4 Working group(s)
   2.5 Project team roles
   2.6 Assurance approach
   2.7 Assurance activities

3. Service Need (A3)
   3.1 Service need
   3.2 Stakeholders and stakeholder engagement
   3.3 Current state
   3.4 Benefits sought
   3.5 Options analysis
   3.6 Recommended option(s) / reference project(s)

4. Strategic Considerations (A4)
   4.1 Strategic alignment
   4.2 Policy issues

SECTION B: CONSIDERATIONS AND ANALYSIS

5. Risk (B1)
   5.1 Overall approach to risk
   5.2 Risk framework
   5.3 Outcomes

6. Base Case (B2)
   6.1 Approach
   6.2 Base case description
   6.3 Outcomes

7. Reference Project(s) (B3)
   7.1 Approach
   7.2 Objectives/outcomes/benefits
   7.3 Scope
   7.4 Activities
   7.5 Reference design

8. Legal and Regulatory Considerations (B4)
   8.1 Legislative issues
   8.2 Regulatory issues
   8.3 Approvals required
   8.4 Other legal matters

9. Public Interest Consideration (B5)
   9.1 Community consultation
   9.2 Impact on stakeholders
   9.3 Public access and equity
   9.4 Consumer rights
   9.5 Safety and security
   9.6 Privacy

10. Sustainability Assessment (B6)
    10.1 Approach
    10.2 Results

11. Social Impact Evaluation (B7)
    11.1 Social impact baseline
    11.2 Evaluation
    11.3 Negative impacts and mitigations

12. Environmental Assessment (B8)
    12.1 Identification of environmental impacts
    12.2 Environmental impacts and mitigations

13. Economic Analysis (B9)
    13.1 Approach
    13.2 Benefits
    13.3 Costs
    13.4 CBA results
    13.5 Socio-economic narrative
    13.6 Sensitivity and scenario analysis
    13.7 QA review

14. Financial Analysis (B10)
    14.1 Capital costs
    14.2 Operating costs
    14.3 Terminal value
    14.4 Sensitivity analysis
    14.5 Key financial elements
    14.6 Commercial analysis

15. Affordability Analysis (B11)
    15.1 Affordability assessment

16. Appraisal Summary Table (B12)
    16.1 Summary of key consequences

SECTION C: DELIVERY

17. Market Consideration (C1)
    17.1 Market sounding outcomes

18. Delivery Model Analysis (C2)
    18.1 Delivery model options
    18.2 Private finance assessment (if applicable)

19. Public Sector Comparator (C3)
    19.1 PSC analysis (if PPP)

20. Implementation Plan (C4)
    20.1 Implementation governance
    20.2 Project management plan
    20.3 Procurement strategy and plan
    20.4 Change management
    20.5 Resource requirements
    20.6 Benefits realisation

Conclusions and Recommendations
Health Checks A/B/C
Appendices (Benefits register, Risk register, Stakeholder engagement plan)
```

**Terminology mapping (QLD):**

| Generic term | Queensland BCDF term |
|---|---|
| Case for change | Service need (A3) |
| Do Nothing | Base case (B2) |
| Strategic case | Proposal Context (Section A) |
| Options appraisal | Options analysis within Service Need (A3.5) |
| Preferred option | Reference project(s) (B3) / Recommended option (A3.6) |
| Economic case | Economic Analysis (B9) |
| Commercial case | Market Consideration (C1) + Delivery Model (C2) |
| Financial case | Financial Analysis (B10) + Affordability (B11) |
| Management case | Implementation Plan (C4) |
| Statutory duties | Sustainability (B6) + Social Impact (B7) + Environmental (B8) + Public Interest (B5) |
| Risk register | Risk (B1) |

### Commonwealth RMG 308 (`au`)

The Commonwealth framework is less template-prescriptive. Use this structure:

```
Executive Summary

1. Strategic Context
   1.1 Alignment to government objectives
   1.2 Policy narrative
   1.3 Summary of First Pass and conditions

2. Options Analysis
   2.1 Options considered at First Pass
   2.2 Detailed analysis of shortlisted options
   2.3 Preferred option recommendation

3. Cost-Benefit Analysis
   3.1 Direct costs and benefits
   3.2 Wider social and economic benefits
   3.3 Distributional analysis
   3.4 Sensitivity analysis

4. Financial Analysis
   4.1 Detailed cost estimates (probabilistic)
   4.2 Funding options
   4.3 Whole-of-life costs
   4.4 Affordability

5. Risk Management
   5.1 Risk identification and register
   5.2 Mitigation strategies
   5.3 Residual risk assessment

6. Implementation Approach
   6.1 Delivery schedule
   6.2 Governance and accountability
   6.3 Monitoring and reporting
   6.4 Resource requirements

7. Benefits Realisation
   7.1 Measurable targets and timelines
   7.2 Benefits owners
   7.3 Tracking and reporting

8. Exit Strategy
   8.1 Triggers for review
   8.2 Wind-down process
   8.3 Residual obligations

Appendices
```

### New Zealand Better Business Cases (`nz`)

NZ uses the UK Five Case Model with minor terminology differences:

```
Executive Summary

1. Strategic Case
   1.1 Strategic context
   1.2 Organisational overview
   1.3 Contribution to existing strategies
   1.4 Investment objectives
   1.5 Existing arrangements and business needs
   1.6 Potential business scope and key service requirements
   1.7 Main benefits
   1.8 Main risks
   1.9 Optimism bias
   1.10 Key constraints, dependencies and assumptions
   1.11 Te Tiriti o Waitangi obligations

2. Economic Case
   2.1 Critical success factors (CSFs)
   2.2 Options identification
   2.3 Options assessment
   2.4 Recommended preferred way forward
   2.5 Indicative costs and benefits

3. Commercial Case
   3.1 Procurement strategy
   3.2 Required services
   3.3 Contract provisions
   3.4 Potential for risk sharing
   3.5 Payment mechanisms
   3.6 Contractual issues and accountancy treatment

4. Financial Case
   4.1 Impact on financial statements
   4.2 Funding sources
   4.3 Overall affordability

5. Management Case
   5.1 Programme management strategy and framework
   5.2 Governance arrangements
   5.3 Programme structure
   5.4 Programme reporting arrangements
   5.5 Key roles and responsibilities
   5.6 Outline programme plan
   5.7 Organisational change management
   5.8 Benefits realisation management
   5.9 Risk management
   5.10 Programme and business assurance arrangements

Annexes
```

**NZ-specific additions**: Section 1.11 (Te Tiriti o Waitangi) is mandatory. CBAx (Treasury's online CBA tool) should be referenced where applicable.

---

## Important rules

- Never use em dashes.
- Never attribute econstack to any individual.
- Every section stands alone.
- The five cases are interconnected. Cross-reference between cases where figures or assumptions must be consistent (e.g., financial case costs must reconcile with economic case costs; management case benefits realisation must trace to strategic case benefits register).
- When the user picks specific sections, still flag any cross-case inconsistencies or missing dependencies.

---

## Table and figure formatting (universal across all econstack outputs)

- **Table and figure formatting (universal across all econstack outputs):**
  - **Numbering**: Every table is "Table 1: [short description]", every figure/chart is "Figure 1: [short description]". Numbering restarts at 1 for each report. The caption goes above the table/figure.
  - **Source note**: Below every table and figure: "Source: [Author/Publisher] ([year])." If multiple sources: "Sources: [Source 1]; [Source 2]."
  - **Notes line**: Below the source, if needed: "Notes: [caveats, e.g. 'real 2026 prices', '2024-25 data', 'estimated from available figures']."
  - **Minimal formatting (low ink-to-data ratio)**: No heavy borders or gridlines. Thin rule under the header row only. No shading on data cells (light grey alternating rows permitted in Excel/HTML only). Right-align all numbers. Left-align all text. Bold totals rows only. No decorative elements.
  - **Number formatting**: Currency with comma separators and 1 decimal place for millions (e.g. "GBP 45.2m" / "AUD 45.2m"), whole numbers for counts (e.g. "1,250 jobs"), percentages to 1 decimal place (e.g. "3.5%").
  - **Consistency**: The same metric must use the same unit and precision throughout the report. Do not switch between "GBP m" and "GBP bn" for the same order of magnitude.

---

## Parameter database

Load framework-specific parameters from the econstack parameter database:

```
PARAMS_DIR="$HOME/econstack-data/parameters"
```

**Files to load (by framework):**

For `uk`:
- `$PARAMS_DIR/uk/discount-rates.json`
- `$PARAMS_DIR/uk/optimism-bias-rates.json`
- `$PARAMS_DIR/uk/carbon-values.json`
- `$PARAMS_DIR/uk/vsl.json`
- `$PARAMS_DIR/uk/gdp-deflators.json`

For `au`, `au-vic`, `au-nsw`, `au-qld`:
- `$PARAMS_DIR/au/discount-rates.json`
- `$PARAMS_DIR/au/carbon-values.json`
- `$PARAMS_DIR/au/procurement-thresholds.json`
- `$PARAMS_DIR/au/vsl.json`
- `$PARAMS_DIR/au/cpi-deflators.json`

For all frameworks:
- `$PARAMS_DIR/common/benefit-categories.json`
- `$PARAMS_DIR/common/risk-probability-scales.json`
- `$PARAMS_DIR/common/csf-baseline.json`
- `$PARAMS_DIR/common/options-framework-templates.json`

**Staleness check**: For each loaded file, compare `last_verified` date against today. If > 2 years: RED warning. If past `expected_next_update`: AMBER warning. If `$PARAMS_DIR` does not exist, use built-in defaults and notify the user.

---

## Instructions

### Step 0: Setup and framework detection

0a. Parse all arguments from the user's command.

0b. Load parameters from `$PARAMS_DIR` based on detected framework. Apply staleness warnings.

0c. If no `--framework` specified, auto-detect from the project description:
- Keywords like "NHS", "Green Book", "UK", "Whitehall", "GBP", "Levelling Up" -> `uk`
- Keywords like "DTF", "HVHR", "Victoria", "Melbourne", "VicRoads" -> `au-vic`
- Keywords like "NSW", "Sydney", "Infrastructure NSW", "INSW" -> `au-nsw`
- Keywords like "Queensland", "PAF", "BCDF", "Brisbane" -> `au-qld`
- Keywords like "Commonwealth", "RMG", "PGPA", "AUD" (without state indicators) -> `au`
- Keywords like "NZ", "CBAx", "Wellington" -> `nz`
- Keywords like "EU", "DG Regio", "cohesion", "EUR" -> `eu`
- Keywords like "World Bank", "IDA", "IBRD", "PAD" -> `wb`
- If ambiguous, ask via `AskUserQuestion`

0d. Confirm framework with the user:
```
AskUserQuestion: "Detected framework: UK HM Treasury Green Book. Is this correct?"
Options: [detected framework] (Recommended), [list other frameworks]
```

0e. If `--from <file.json>` is provided, load all inputs from JSON and skip to Step 8 (compute and output). If `--from schema` is provided, print the full JSON schema and stop.

### Step 1: Project setup (interactive)

1a. Ask for the project description (if not provided as argument):
```
AskUserQuestion: "Describe the project or programme in 1-2 sentences."
```

1b. Ask for the business case stage:
```
AskUserQuestion: "What stage is this business case?"
Options:
  - "Strategic Outline Case (SOC) — early scoping, wide options" (Recommended for new projects)
  - "Outline Business Case (OBC) — detailed, shortlisted options"
  - "Full Business Case (FBC) — final, confirmed, pre-contract"
```

For Australian frameworks, map the stage labels:
- `au`: SOC = First Pass, OBC/FBC = Second Pass
- `au-vic`: SOC = Gate 1 (Concept & Feasibility), OBC = Gate 2 (Business Case), FBC = Gate 4 (Tender Decision)
- `au-nsw`: SOC = Strategic Assessment, OBC = Preliminary Business Case, FBC = Full Business Case
- `au-qld`: SOC = PAF Stage 1-2, OBC = PAF Stage 3, FBC = PAF Stage 4-5

1c. Ask for the estimated total cost (to set proportionality):
```
AskUserQuestion: "What is the estimated total investment cost?"
Options:
  - "Under [currency] 1m — light-touch"
  - "[currency] 1-10m — standard"
  - "[currency] 10-100m — detailed"
  - "Over [currency] 100m — comprehensive"
```

Use the proportionality level to adjust depth throughout. For `au-vic`, also check HVHR thresholds: if TEI > AUD 100m with medium risk, or > AUD 250m with any risk, flag that HVHR Gateway reviews will be required.

1d. Ask for the sector:
```
AskUserQuestion: "What sector does this project fall into?"
Options:
  - "Transport / infrastructure"
  - "Health / social care"
  - "Education / skills"
  - "Housing / regeneration"
  (Other: free text)
```

1e. Ask for the price base year:
```
AskUserQuestion: "What price base year should be used?"
Options:
  - "[current year] prices (Recommended)"
  - "[previous year] prices"
  (Other: free text)
```

### Step 2: Section picker

This is the core interactive step. Present ALL available sections across all five cases and let the user pick which ones they want to complete.

2a. If `--full` is set, select all sections and skip to Step 3.

2b. If `--case <list>` is set, pre-select all sections within those cases and skip to Step 3.

2c. If `--sections` is set OR no case/full flags given, present the interactive section picker:

```
AskUserQuestion: "Which cases do you want to include in this business case?"
multiSelect: true
Options:
  - "Strategic Case — case for change, objectives, benefits" (Recommended)
  - "Economic Case — options appraisal, CBA, value for money" (Recommended)
  - "Commercial Case — procurement, contracts, risk allocation"
  - "Financial Case — costs, funding, affordability"
  - "Management Case — governance, delivery, M&E"
```

2d. For each selected case, ask which sections within it to complete. Group as a multiSelect checklist. Mark sections that are REQUIRED at the current stage vs optional.

**Strategic Case sections:**
```
AskUserQuestion: "Which Strategic Case sections do you want to complete?"
multiSelect: true
Options:
  - "Case for change + market/government failure (required at all stages)"
  - "Theory of Change (required at OBC/FBC)"
  - "SMART objectives + investment objectives (required at all stages)"
  - "Benefits register + Critical Success Factors (required at OBC/FBC)"
```
Additional sections shown if proportionality >= standard:
  - "Constraints, dependencies and stakeholders"
  - "Strategic fit and policy alignment"
  - "PESTLE analysis"
  - "Statutory duties screening (UK) / Indigenous policy (AU)"

**Economic Case sections:**
```
AskUserQuestion: "Which Economic Case sections do you want to complete?"
multiSelect: true
Options:
  - "Options Framework Filter — long list to short list (required at all stages)"
  - "Cost-Benefit Analysis — full CBA per option (required at OBC/FBC)"
  - "Appraisal Summary Table (required at OBC/FBC)"
  - "Sensitivity analysis + switching values (required at OBC/FBC)"
```
Additional sections shown if proportionality >= detailed:
  - "Distributional analysis"
  - "Place-based effects (UK Levelling Up / AU regional)"
  - "Monte Carlo simulation (recommended for projects over GBP/AUD 100m)"

**Commercial Case sections:**
```
AskUserQuestion: "Which Commercial Case sections do you want to complete?"
multiSelect: true
Options:
  - "Procurement route + justification (required at OBC/FBC)"
  - "Risk allocation matrix (required at OBC/FBC)"
  - "Contract type, KPIs and payment mechanism"
  - "Market engagement and social value"
```
Additional sections if proportionality >= standard:
  - "Personnel implications (TUPE / staff transfer)"
  - "Lots strategy and SME access"

**Financial Case sections:**
```
AskUserQuestion: "Which Financial Case sections do you want to complete?"
multiSelect: true
Options:
  - "Capital and revenue cost profile (required at all stages)"
  - "Funding sources and confirmation status (required at OBC/FBC)"
  - "Whole life cost and affordability table (required at OBC/FBC)"
  - "Balance sheet treatment and accounting (required at FBC)"
```
Additional sections if proportionality >= detailed:
  - "Inflation assumptions and deflators"
  - "Spending Review / budget period alignment"

**Management Case sections:**
```
AskUserQuestion: "Which Management Case sections do you want to complete?"
multiSelect: true
Options:
  - "Governance structure and SRO (required at OBC/FBC)"
  - "Key milestones and delivery plan (required at all stages)"
  - "Risk register (required at OBC/FBC)"
  - "Benefits Realisation Plan + M&E plan (required at OBC/FBC)"
```
Additional sections if proportionality >= standard:
  - "Resource plan"
  - "Change management approach"
  - "Assurance and Gateway review plan"
  - "Post-project evaluation plan (required at FBC)"

2e. Store the selected sections. Throughout Steps 3-7, SKIP any section the user did not select. For skipped sections within a selected case, add a placeholder: "[Section name]: Not included in this version. To be completed at [next stage]."

---

### Step 3: Strategic Case

Only execute sub-steps for sections the user selected in Step 2.

**3a. Case for change**

Ask:
```
AskUserQuestion: "What is the case for change? What problem or opportunity drives this investment?"
(Free text)
```

Then ask about market/government failure:
```
AskUserQuestion: "What type of market or government failure justifies intervention?"
Options:
  - "Public goods — non-excludable, non-rivalrous"
  - "Externalities — costs/benefits not captured by market"
  - "Information asymmetry — one party has better information"
  - "Coordination failure — parties cannot coordinate without intervention"
  - "Market power — monopoly/oligopoly"
  - "Distributional — market outcome is inequitable"
  (Other: free text)
```

For Australian frameworks, also ask:
```
AskUserQuestion: "Is there a specific government policy mandate or ministerial direction requiring this investment?"
(Free text, optional)
```

**3b. Theory of Change**

Build the Theory of Change interactively as a chain:

Ask for each link in sequence:
```
AskUserQuestion: "What INPUTS will this project require? (funding, staff, equipment, etc.)"
AskUserQuestion: "What ACTIVITIES will be undertaken?"
AskUserQuestion: "What OUTPUTS will be produced? (deliverables, assets, services)"
AskUserQuestion: "What OUTCOMES are expected? (changes in behaviour, conditions, performance)"
AskUserQuestion: "What is the ultimate IMPACT? (long-term societal change)"
```

For each link, ask: "What assumptions connect [this level] to [next level]?"

Render as a table:

```
Table N: Theory of Change

| Level      | Description                     | Assumptions                |
|------------|---------------------------------|----------------------------|
| Inputs     | [user input]                    | —                          |
| Activities | [user input]                    | [user input]               |
| Outputs    | [user input]                    | [user input]               |
| Outcomes   | [user input]                    | [user input]               |
| Impact     | [user input]                    | [user input]               |
```

**Quality check**: Flag any assumptions that are untestable or have no evidence base. Warn if the chain has logical gaps (e.g., outputs that don't plausibly lead to stated outcomes).

**3c. SMART objectives**

Ask:
```
AskUserQuestion: "List the SMART objectives for this investment (max 6). Each should be Specific, Measurable, Achievable, Realistic, Time-bound."
(Free text — parse into individual objectives)
```

**Quality check each objective:**
- Flag vague language: "improve", "enhance", "support", "strengthen" without a measurable target
- Flag missing time bounds
- Flag objectives that are outputs, not outcomes
- Suggest rewording where needed

Also ask:
```
AskUserQuestion: "What are the spending objectives? (What the spending is intended to achieve in policy terms)"
AskUserQuestion: "What are the investment objectives? (What the investment itself must deliver)"
```

**3d. Benefits register and CSFs**

Inject the 5 baseline Critical Success Factors (these apply to ALL business cases regardless of framework):
1. Strategic fit and business needs
2. Value for money (optimise social value)
3. Supplier capacity and capability
4. Affordability
5. Achievability

Ask:
```
AskUserQuestion: "Are there additional project-specific Critical Success Factors beyond the five baseline factors?"
(Free text, optional)
```

Build the benefits register interactively:
```
AskUserQuestion: "List the expected benefits of this investment."
(Free text — parse into individual benefits)
```

For each benefit, ask:
```
AskUserQuestion: "For benefit '[name]': what category?"
Options:
  - "Cash releasing — direct financial savings"
  - "Non-cash releasing quantifiable — measurable but not direct savings"
  - "Qualitative — important but cannot be quantified"
```

Render as:

```
Table N: Benefits Register

| # | Benefit | Category | Owner | Baseline | Target | Measurement |
|---|---------|----------|-------|----------|--------|-------------|
```

**3e. Constraints, dependencies, stakeholders**

```
AskUserQuestion: "What constraints apply? (legal, ethical, political, technological, environmental)"
AskUserQuestion: "What external dependencies exist? (other projects, approvals, third parties)"
AskUserQuestion: "Who are the key stakeholders? For each, note their interest and influence level."
```

**3f. Strategic fit**

```
AskUserQuestion: "How does this investment align with organisational strategy and government priorities?"
```

For UK: prompt for alignment with departmental Single Departmental Plan, cross-government strategies, and Levelling Up missions.
For AU: prompt for alignment with government policy priorities, National Agreement objectives, and state-specific strategies.

**3g. PESTLE analysis**

```
AskUserQuestion: "Complete the PESTLE analysis. For each factor, describe the key considerations."
```

Build as table with rows: Political, Economic, Social, Technological, Legal, Environmental.

**3h. Statutory duties screening**

The 2026 Green Book mandates assessment of three statutory duties as **cross-cutting requirements**, not optional add-ons. At SOC: screening. At OBC: proportionate assessment. At FBC: full assessment with evidence. These are mandatory for all business cases under UK frameworks.

For UK frameworks:
- Environmental Principles (Environment Act 2021) (mandatory)
- Biodiversity Duty (mandatory)
- Public Sector Equality Duty (Equality Act 2010) (mandatory)

For Australian frameworks:
- Environment Protection and Biodiversity Conservation Act 1999 (EPBC Act)
- Indigenous Procurement Policy (Commonwealth) / equivalent state policies
- Climate Change Act 2022 (net zero obligations)
- Native Title Act 1993 (where land is involved)

Ask:
```
AskUserQuestion: "Has a screening assessment been completed for statutory duties? Summarise the findings or note if assessment is pending."
```

At OBC/FBC for UK: do not accept "screening" as sufficient. Require proportionate/full assessment.

---

### Step 4: Economic Case

Only execute sub-steps for sections the user selected in Step 2.

**4a. Options Framework Filter**

Present the five filter dimensions. For each, ask the user to identify realistic options:

```
AskUserQuestion: "OPTIONS FRAMEWORK FILTER — SCOPE: What scope options exist? (e.g., national vs regional, full service vs targeted, high quality vs minimum standard)"
```

```
AskUserQuestion: "OPTIONS FRAMEWORK FILTER — SOLUTION: What solution options exist? (e.g., new build, refurbish, digital, regulatory, grant programme, tax incentive)"
```

```
AskUserQuestion: "OPTIONS FRAMEWORK FILTER — DELIVERY: What delivery options exist? (e.g., in-house, outsource, PPP, joint venture, arms-length body)"
```

```
AskUserQuestion: "OPTIONS FRAMEWORK FILTER — IMPLEMENTATION: What implementation options exist? (e.g., big bang, phased rollout, pilot then scale, regional sequencing)"
```

```
AskUserQuestion: "OPTIONS FRAMEWORK FILTER — FUNDING: What funding options exist? (e.g., 100% public, co-funded, private finance, user charges, blended)"
```

Render as:

```
Table N: Options Framework Filter

| Dimension      | Option A        | Option B        | Option C        |
|----------------|-----------------|-----------------|-----------------|
| Scope          |                 |                 |                 |
| Solution       |                 |                 |                 |
| Delivery       |                 |                 |                 |
| Implementation |                 |                 |                 |
| Funding        |                 |                 |                 |
```

Generate the long list: identify all plausible combinations (not full Cartesian product; only combinations that make practical sense). Present as a numbered list.

**4b. Long list to short list**

Screen each long-list option against the Critical Success Factors using Green/Amber/Red:

```
Table N: CSF Screening

| Option | CSF 1: Strategic fit | CSF 2: VfM | CSF 3: Supplier | CSF 4: Affordability | CSF 5: Achievability | Overall |
|--------|---------------------|-------------|-----------------|---------------------|---------------------|---------|
```

Red on any CSF = option rejected. Carry forward Green/Amber options to the short list.

**Mandatory short-list members:**
- Option 0: Do Nothing / Business As Usual (the counterfactual)
- Option 1: Do Minimum (least intervention that addresses the need)
- Options 2-4: Realistic alternatives including the preferred option

**Building the counterfactual (Do Nothing):** The Do Nothing option must project forward, not freeze at today's state. It must include: (1) deterioration of existing assets over time, (2) demand and population growth, (3) committed policies and already-funded projects, (4) regulatory changes already enacted, (5) inflation and cost escalation. For AU: also account for state/Commonwealth budget allocations already committed. A static baseline is a common cause of rejection by Treasury reviewers. Reference: Green Book 2026, Chapter 5.

For Australian frameworks: "Do Nothing" means maintaining current budget allocation and accounting for autonomous trends, not literal inaction.

```
AskUserQuestion: "Confirm the short list. These options will proceed to detailed appraisal."
```

**4c. Cost-Benefit Analysis**

If `--with-cba <file.json>` was provided:
- Import the CBA output
- Validate it covers all short-listed options
- Skip to 4d

Otherwise, for each short-listed option, invoke the `/cost-benefit` skill:

```
Invoke /cost-benefit with:
  --framework [current framework]
  --stage [current stage]
  Price base year: [from Step 1e]
  Appraisal period: [ask user if not yet determined]
  Options: [short-listed options from 4b]
```

If the user selected the "Cost-Benefit Analysis" section but NOT the full Economic Case, run a simplified CBA:
- Ask for summary cost and benefit figures per option (not year-by-year)
- Ask: "Have additionality adjustments been applied to these benefit figures? (deadweight, displacement, leakage)" If not, apply HMT standard rates (20% deadweight, 25% displacement, 10% leakage) or ask for project-specific rates. Reference: HMT Additionality Guide, 4th edition.
- Ask: "Do these benefit figures include a ramp-up period, or are full benefits assumed from year 1?" If no ramp-up, apply a default profile appropriate to the project type (typically 2-5 years for infrastructure, 1-3 years for programmes).
- Compute NPV and BCR using framework-appropriate discount rate
- Skip detailed sensitivity (but include switching values)

**Framework-specific discount rate application:**

For `uk`: Apply 3.5% declining schedule. Use Green Book supplementary guidance rates.
For `au` / `au-nsw` / `au-qld`: Apply 7% flat. Sensitivity at 4% and 10%.
For `au-vic`: Compute at BOTH 4% and 7%. Report both sets of results. Transport projects must present both.
For `nz`: 2% for non-commercial, 8% for commercial. Confirm which applies.
For `eu`: 3% for advanced member states, 5% for convergence regions. Ask which.
For `wb`: 10% default. Ask for country-specific rate if available.
For `us`: 2% (OMB A-4 2023 revision).

**Optimism bias application:**

For `uk`: Apply stage-specific uplifts from Green Book supplementary guidance:

```
Table N: Optimism Bias Rates (UK)

| Project type                | Works duration | Capital expenditure |
|                             | Upper | Lower  | Upper | Lower       |
|-----------------------------|-------|--------|-------|-------------|
| Standard buildings          | 4%    | 1%     | 24%   | 2%          |
| Non-standard buildings      | 39%   | 2%     | 51%   | 4%          |
| Standard civil engineering  | 20%   | 1%     | 44%   | 3%          |
| Non-standard civil eng.     | 25%   | 3%     | 66%   | 6%          |
| Equipment/development       | 54%   | 10%    | 200%  | 10%         |
| Outsourcing                 | —     | —      | 41%   | 0%          |
```

Note: Outsourcing rates apply to **operating expenditure**, not capital expenditure. All other rows apply to capital expenditure.

SOC: use upper bound. OBC: use midpoint. FBC: use lower bound (with evidence of mitigation).

For Australian frameworks: Do NOT apply fixed percentage optimism bias. Instead:
```
AskUserQuestion: "Australian frameworks use Reference Class Forecasting (RCF) rather than fixed optimism bias uplifts. Which cost estimate basis are you using?"
Options:
  - "P50 — 50th percentile (median expected cost)"
  - "P90 — 90th percentile (high confidence, recommended for budget)"
  - "Deterministic estimate — single point estimate (will add contingency separately)"
```

If P50, note that some Australian treasuries (notably Victoria DTF) recommend using P90 for budget submissions because systematic optimism bias means P90 may be closer to the true expected cost.

For sensitivity: test NPSV at P50, P75, and P90 cost estimates. NSW: also test +/-20% on base cost per TPG23-08. Victoria: present results at both 4% and 7% discount rates for each cost estimate basis.

**4d. Appraisal Summary Table**

Compile all monetised, quantified-non-monetised, and qualitative impacts across all options:

```
Table N: Appraisal Summary Table

| Impact                        | Do Nothing | Do Minimum | Option A   | Option B   |
|-------------------------------|------------|------------|------------|------------|
| MONETISED (PV, [currency]m)   |            |            |            |            |
|   Direct costs                |            |            |            |            |
|   Direct benefits             |            |            |            |            |
|   Indirect benefits           |            |            |            |            |
|   Carbon                      |            |            |            |            |
|   Wider economic impacts      |            |            |            |            |
| NPSV                          |            |            |            |            |
| BCR                           |            |            |            |            |
| QUANTIFIED (not monetised)    |            |            |            |            |
|   [metric 1]                  |            |            |            |            |
|   [metric 2]                  |            |            |            |            |
| QUALITATIVE                   |            |            |            |            |
|   [impact 1]                  |            |            |            |            |
| DISTRIBUTIONAL                |            |            |            |            |
|   [dimension 1]               |            |            |            |            |
```

Source: Authors' analysis. Notes: [price base], [discount rate], [appraisal period].

**Important**: Wider economic impacts (agglomeration, labour supply, imperfect competition) must be presented **below the BCR line** as supplementary analysis. Do NOT include WEIs in the primary BCR computation. The BCR should reflect core direct costs and benefits only. Reference: Green Book 2026, Chapter 8.

**4e. Sensitivity analysis and switching values**

Run sensitivity analysis on the preferred option:

1. **Scenario analysis**: Optimistic / Central / Pessimistic
2. **Per-variable tornado**: Vary each key assumption +/-25%, rank by impact on NPSV
3. **Discount rate sensitivity**: Test at alternative rates
   - UK: declining schedule (central), plus STPR component sensitivity per Green Book supplementary guidance on discounting. Use 1.5% only for health/QALY-specific sensitivity.
   - AU: 4%, 7% (central), 10%
   - AU-VIC: 4% (central low), 7% (central high) (already computed both)
4. **Switching values**: For each key variable, compute the % change that makes NPSV = 0 or changes the preferred option
5. **Break-even analysis**: When does the project break even (cumulative discounted benefits = cumulative discounted costs)?

For projects over GBP/AUD 100m (or if user selected Monte Carlo):
6. **Monte Carlo simulation**: 10,000 iterations. Report P5, P25, P50, P75, P95 of NPSV distribution.

**4f. Distributional analysis**

If selected:
```
AskUserQuestion: "What distributional dimensions should be analysed?"
multiSelect: true
Options:
  - "Income/deprivation — impact by income quintile or deprivation decile"
  - "Geography — regional distribution of costs and benefits"
  - "Protected characteristics — Equality Act 2010 (UK) / anti-discrimination (AU)"
  - "Intergenerational — distribution across age cohorts"
```

For UK: Apply Green Book distributional weights if income dimension selected. Reference Levelling Up missions if geography selected.
For AU: Reference Closing the Gap targets if relevant to First Nations communities. Reference state-specific regional development priorities.

**4g. Place-based effects**

If selected (primarily UK, but increasingly AU):
```
AskUserQuestion: "Does this investment have significant place-based effects? Describe the geographic focus."
```

For UK: Assess against Levelling Up missions. Note the 2026 Green Book explicitly supports bundled place-based business cases (housing + transport + skills as a single strategic proposal).
For AU: Assess against Regional Development priorities and city deals.

**4h. Preferred option recommendation**

Synthesise:
- NPSV and BCR rankings
- Non-monetised impacts from AST
- Sensitivity robustness
- Switching value margins
- Distributional considerations
- Qualitative factors

Write the recommendation narrative:
"Option [X] is the preferred option because [rationale referencing all dimensions]. It delivers an NPSV of [value] and a BCR of [value] under the central case. The option is robust to sensitivity testing, with switching values of [X]% on costs and [Y]% on benefits before the preferred option changes."

For UK: Explicitly note the 2026 Green Book position that VfM is a balanced judgement, not a single BCR threshold.
For AU: Note the requirement that the option with the highest net benefit should be recommended, with reasons disclosed if an alternative is preferred.

---

### Step 5: Commercial Case

Only execute sub-steps for sections the user selected in Step 2.

**5a. Procurement route and justification**

```
AskUserQuestion: "What procurement route is proposed?"
Options:
  - "Open tender" (Recommended for transparency)
  - "Restricted tender"
  - "Competitive dialogue"
  - "Negotiated procedure"
  - "Framework call-off"
  - "Direct award (requires justification)"
  (Other: free text)
```

```
AskUserQuestion: "Justify this procurement route. Why is it appropriate for this project?"
(Free text)
```

**Framework-specific procurement context:**

For UK: Reference Public Contracts Regulations 2015 / Procurement Act 2023 thresholds. Social value weighting minimum 10% (PPN 06/20).

For AU Commonwealth: Reference Commonwealth Procurement Rules (November 2025 update). Open tender threshold: AUD 125,000. Below threshold: Australian businesses only. Note Indigenous Procurement Policy requirements:
- Mandatory Set-Aside (MSA): contracts AUD 80,000-200,000 in remote areas for Indigenous businesses
- Mandatory Minimum Requirements (MMR): contracts AUD 7.5m+ in specified industries must include Indigenous participation targets

For AU-VIC: Reference Victorian Government Purchasing Board policies. Social procurement framework.
For AU-NSW: Reference NSW Procurement Policy Framework.
For AU-QLD: Reference Queensland Procurement Policy.

**5b. Risk allocation matrix**

```
AskUserQuestion: "For each risk category, indicate the proposed allocation. The principle is: risk sits with the party best placed to manage it."
```

Build the risk allocation matrix:

```
Table N: Risk Allocation Matrix

| Risk category              | Public | Private | Shared | Rationale                    |
|----------------------------|--------|---------|--------|------------------------------|
| Design risk                |        |         |        |                              |
| Construction/delivery risk |        |         |        |                              |
| Demand/volume risk         |        |         |        |                              |
| Availability risk          |        |         |        |                              |
| Technology/obsolescence    |        |         |        |                              |
| Regulatory/legislative     |        |         |        |                              |
| Operating cost risk        |        |         |        |                              |
| Force majeure              |        |         |        |                              |
| Residual value risk        |        |         |        |                              |
```

**Quality check**: Flag if all risk is allocated to one party (likely unrealistic). Flag if rationale is missing for any shared risk.

**5c. Contract type, KPIs, payment mechanism**

```
AskUserQuestion: "What contract type is proposed?"
Options:
  - "Fixed price"
  - "Cost-plus"
  - "Target cost (pain/gain share)"
  - "Outcome-based / payment by results"
  - "Alliance"
  (Other: free text)
```

```
AskUserQuestion: "What are the key performance indicators (KPIs)? For each, specify the target and measurement frequency."
```

Render as:

```
Table N: Key Performance Indicators

| KPI | Target | Measurement frequency | Remedy for failure |
|-----|--------|-----------------------|--------------------|
```

```
AskUserQuestion: "Describe the payment mechanism. How is the supplier paid, and how is payment linked to performance?"
```

**Quality check**: Flag KPIs that are input-focused rather than outcome-focused. Flag payment mechanisms with no performance linkage.

**5d. Market engagement and social value**

```
AskUserQuestion: "What market engagement has been undertaken? (e.g., Prior Information Notice, market sounding events, supplier meetings)"
```

At SOC stage: acceptable to describe planned engagement. At OBC/FBC: must describe completed engagement and findings.

```
AskUserQuestion: "How will social value be incorporated in procurement evaluation?"
```

For UK: minimum 10% weighting (PPN 06/20). Describe the themes: COVID-19 recovery, tackling inequality, fighting climate change, equal opportunity, wellbeing.
For AU: Social Procurement Framework requirements. Indigenous participation targets.

**5e. Personnel implications**

```
AskUserQuestion: "Are there staff transfer implications (TUPE in UK / employment law in AU)?"
Options:
  - "Yes — staff will transfer to new provider"
  - "No staff transfer implications"
  - "To be determined"
```

If yes: describe the number of affected staff, current terms, and transfer approach.

---

### Step 6: Financial Case

The financial case must comply with **Managing Public Money** (MPM). If the spending is novel, contentious, or repercussive (NCR), flag that mandatory HMT referral is required regardless of Delegated Authority Limits. For UK frameworks, ask:
```
AskUserQuestion: "Is this spending novel, contentious, or repercussive?"
Options:
  - "No — standard spending within precedent"
  - "Novel — no precedent or established policy"
  - "Contentious — may attract public/Parliamentary criticism"
  - "Repercussive — sets a precedent with wider implications"
  - "Unsure — will need to check with finance team"
```
If NCR: note in the financial case that HMT referral is required.

Only execute sub-steps for sections the user selected in Step 2.

**6a. Capital and revenue cost profile**

For UK:
```
AskUserQuestion: "Provide the capital costs (CDEL) by year and category."
```

For AU:
```
AskUserQuestion: "Provide the capital costs by year and category."
```

Build the cost profile table. Accept input in one of three modes:
```
AskUserQuestion: "How would you like to enter costs?"
Options:
  - "Summary totals only (SOC-level)" (Recommended at SOC)
  - "Year-by-year breakdown by category" (Recommended at OBC/FBC)
  - "Import from spreadsheet (paste or file path)"
```

Render as:

```
Table N: Capital Cost Profile ([currency]m, [price base] prices)

| Category          | Year 1 | Year 2 | Year 3 | Year 4 | Year 5 | Total |
|-------------------|--------|--------|--------|--------|--------|-------|
| Construction      |        |        |        |        |        |       |
| Equipment         |        |        |        |        |        |       |
| Professional fees |        |        |        |        |        |       |
| Land acquisition  |        |        |        |        |        |       |
| Contingency       |        |        |        |        |        |       |
| Optimism bias     |        |        |        |        |        |       |
| TOTAL CAPITAL     |        |        |        |        |        |       |
```

```
Table N: Revenue Cost Profile ([currency]m, [price base] prices)

| Category          | Year 1 | Year 2 | Year 3 | ... | Year N | Total |
|-------------------|--------|--------|--------|-----|--------|-------|
| Operating costs   |        |        |        |     |        |       |
| Staffing          |        |        |        |     |        |       |
| Maintenance       |        |        |        |     |        |       |
| Other             |        |        |        |     |        |       |
| TOTAL REVENUE     |        |        |        |     |        |       |
```

For UK: separately identify CDEL, RDEL, and AME (Annually Managed Expenditure).
For AU: separately identify departmental capital budget (DCB), administered capital budget (ACB), and departmental operating appropriations.

**6b. Funding sources**

```
AskUserQuestion: "What are the funding sources for this investment? For each, indicate whether funding is confirmed, indicative, or sought."
```

Render as:

```
Table N: Funding Sources

| Source                   | Amount ([currency]m) | Status      | Conditions           |
|--------------------------|----------------------|-------------|----------------------|
| Departmental budget      |                      | Confirmed   |                      |
| [Other government body]  |                      | Indicative  |                      |
| Private sector           |                      | Sought      |                      |
| User charges             |                      | Projected   |                      |
| TOTAL FUNDING            |                      |             |                      |
| FUNDING GAP              |                      |             |                      |
```

**Quality check**: Flag if total funding < total cost (funding gap exists). Flag if no confirmed funding at OBC/FBC stage. Flag if funding conditions are unresolved.

**6c. Whole life cost and affordability**

Compute whole life cost = total capital + total revenue over the appraisal period.

Build the affordability table:

```
Table N: Affordability Summary ([currency]m, nominal)

| [currency]m              | Year 1 | Year 2 | Year 3 | Year 4 | Year 5 | Total |
|--------------------------|--------|--------|--------|--------|--------|-------|
| Capital (gross)          |        |        |        |        |        |       |
| Revenue (gross)          |        |        |        |        |        |       |
| Total gross cost         |        |        |        |        |        |       |
| Less: income             |        |        |        |        |        |       |
| NET COST                 |        |        |        |        |        |       |
| Funded by:               |        |        |        |        |        |       |
|   Departmental budget    |        |        |        |        |        |       |
|   External funding       |        |        |        |        |        |       |
| FUNDING GAP / SURPLUS    |        |        |        |        |        |       |
```

For UK: note alignment with Spending Review periods. Flag if costs fall beyond the current SR period and funding is uncommitted.
For AU: note alignment with Budget forward estimates (typically 4 years). Flag if costs extend beyond the forward estimates.

**6d. Balance sheet treatment**

At FBC stage:
```
AskUserQuestion: "What is the proposed accounting treatment?"
Options:
  - "On balance sheet — public sector asset"
  - "Off balance sheet — PFI/PPP (IFRS 16 / IPSAS 43)"
  - "Service concession (IFRIC 12 / IPSAS 32)"
  - "To be confirmed with finance team"
```

Note: Balance sheet treatment is a financial reporting matter, separate from VfM assessment. The economic case evaluates social costs and benefits regardless of accounting treatment.

**6e. Inflation and deflators**

```
AskUserQuestion: "What inflation assumption is used to convert from [price base] prices to nominal?"
Options:
  - "GDP deflator (Recommended for UK)"
  - "CPI (Recommended for AU)"
  - "Sector-specific inflation rate"
  - "No inflation adjustment (real prices throughout)"
```

For UK: use OBR GDP deflator forecasts.
For AU: use Treasury/RBA CPI forecasts.

---

### Step 7: Management Case

Only execute sub-steps for sections the user selected in Step 2.

**7a. Governance structure**

```
AskUserQuestion: "Who is the Senior Responsible Owner (SRO)?"
AskUserQuestion: "Who is the Project Director / delivery lead?"
AskUserQuestion: "Describe the governance structure (board, sub-committees, reporting lines)."
```

At SOC: outline structure is sufficient.
At OBC/FBC: named individuals, terms of reference, meeting frequency.

```
AskUserQuestion: "What project management methodology will be used?"
Options:
  - "PRINCE2"
  - "Agile"
  - "Hybrid (PRINCE2 + Agile)"
  - "MSP (Managing Successful Programmes)"
  (Other: free text)
```

**7b. Key milestones**

```
AskUserQuestion: "List the key milestones with target dates."
```

Render as:

```
Table N: Key Milestones

| # | Milestone                    | Target date | Dependencies | RAG |
|---|------------------------------|-------------|--------------|-----|
| 1 | Business case approval       |             |              |     |
| 2 | Procurement launch           |             |              |     |
| 3 | Contract award               |             |              |     |
| 4 | Construction start           |             |              |     |
| 5 | Practical completion         |             |              |     |
| 6 | Operational go-live          |             |              |     |
| 7 | Post-project evaluation      |             |              |     |
```

For AU-VIC HVHR: include Gateway review dates as milestones (Gates 1-6).
For AU-NSW: include Gateway review dates aligned to INSW/REAF/DAF framework.

**7c. Risk register**

```
AskUserQuestion: "List the top risks for this project. For each, estimate probability (1-5) and impact (1-5)."
```

Render as:

```
Table N: Risk Register

| ID | Risk                  | Category   | Prob (1-5) | Impact (1-5) | Score | Expected value | Mitigation           | Owner  | Status |
|----|-----------------------|------------|------------|--------------|-------|----------------|----------------------|--------|--------|
```

Risk categories: Strategic, Financial, Operational, Reputational, Legal/Regulatory, Technical, Environmental.

Probability scale: 1 = Rare (<5%), 2 = Unlikely (5-20%), 3 = Possible (20-50%), 4 = Likely (50-80%), 5 = Almost certain (>80%).
Impact scale: 1 = Negligible, 2 = Minor, 3 = Moderate, 4 = Major, 5 = Severe.

**Quality check**: Flag if no risks scored 4+ (unrealistic for any material project). Flag if mitigations are generic ("monitor and review"). For projects involving grants, loans, or payments to third parties: check that **fraud risk** is included in the risk register. The Green Book 2026 specifically requires fraud risk assessment where public funds are distributed.

For UK: reference Orange Book for risk management framework.
For AU: reference AS/NZS ISO 31000 risk management standard.

**7d. Benefits Realisation Plan**

Build the BRP from the benefits register (Step 3d):

```
Table N: Benefits Realisation Plan

| Benefit | Category        | Owner  | Baseline | Target | KPI          | Measurement method | First review | End date |
|---------|-----------------|--------|----------|--------|--------------|--------------------|--------------|----------|
```

```
AskUserQuestion: "How will benefits be tracked and reported? Who reviews progress?"
```

For UK: reference the Guide for Effective Benefits Management in Major Projects.
For AU-VIC: note that Gate 6 (Benefits Review) is mandatory for HVHR projects, 6-18 months post-completion.

**7e. Monitoring and Evaluation plan**

```
AskUserQuestion: "What evaluation approach is planned?"
Options:
  - "Experimental (RCT) — Maryland SMS Level 5"
  - "Quasi-experimental (DiD, regression discontinuity) — Level 3-4"
  - "Theory-based evaluation — Level 2-3"
  - "Process evaluation only — Level 1-2"
  - "To be determined"
```

Build the M&E plan:

```
Table N: Monitoring and Evaluation Plan

| Element              | Detail                                |
|----------------------|---------------------------------------|
| Evaluation questions | [What will be tested?]                |
| Methodology          | [Selected approach]                   |
| Evidence standard    | [Maryland SMS Level X]                |
| Data requirements    | [What data, collected how, by whom]   |
| Timeline             | [Mid-term / final / post-project]     |
| Budget               | [% of programme cost, typically 1-5%] |
| Independence         | [Internal / mixed / external]         |
| Ethics               | [Any ethical review needed]           |
```

For UK: reference the Magenta Book (evaluation guidance now fully separated from Green Book in 2026 edition).
For AU: reference the Commonwealth Evaluation Policy and Toolkit.
For AU carbon valuation: use the relevant state/Commonwealth guidance. Victoria: DTF Technical Guidelines on Economic Evaluation. NSW: TPG23-08 carbon values. Commonwealth: OIA does not prescribe a single source; use the social cost of carbon from peer-reviewed literature or the ACCU market price as a lower bound, with sensitivity.

**Quality check**: Flag if M&E budget is 0% or not specified. Flag if evaluation methodology cannot answer the stated evaluation questions. Flag if no counterfactual is planned for an effectiveness evaluation.

**7f. Resource plan**

```
AskUserQuestion: "What resources are needed for delivery?"
```

Render as:

```
Table N: Resource Plan

| Role                | FTE | Source (internal/external) | Cost ([currency]k pa) | Duration |
|---------------------|-----|---------------------------|----------------------|----------|
```

**7g. Change management**

```
AskUserQuestion: "Describe the change management approach: communication plan, training, transition to business-as-usual."
```

**7h. Assurance and Gateway reviews**

At FBC stage:
```
AskUserQuestion: "What assurance arrangements are in place?"
```

For UK: reference IPA Gateway review process. Projects GBP 5m+ require Gateway reviews. List planned Gateway review dates (Gates 0-5).
For AU-VIC: HVHR projects require DTF Gateway reviews (Gates 1-6). List planned Gate dates. Note: RAPs (Recommendation Action Plans) required for Gates 1-4.
For AU-NSW: reference INSW IIAF / Treasury REAF / DCS DAF as applicable.
For AU-QLD: reference PAF Gateway alignment.

**7i. Exit strategy (AU frameworks, optional for UK)**

For Australian Commonwealth (RMG 308) business cases, an exit strategy is mandatory for all material investments.

```
AskUserQuestion: "Describe the exit strategy: how can this investment be wound down if objectives are not met or circumstances change?"
```

The exit strategy should cover: (1) triggers for review (performance thresholds, policy changes), (2) wind-down process and timeline, (3) residual obligations (contracts, staff, assets), (4) asset disposal approach, (5) stakeholder communication.

For UK: while not formally required by the Green Book, an exit strategy strengthens the management case and is recommended for programmes with uncertain demand or time-limited funding.

**7j. Post-project evaluation**

At FBC stage:
```
AskUserQuestion: "When will the post-project evaluation take place? (Typically 1-3 years after completion)"
AskUserQuestion: "What will the evaluation assess? (costs vs budget, benefits vs forecast, lessons learned, unintended consequences)"
```

---

### Step 8: Cross-cutting elements

**8a. Consistency checks (auto-run)**

Run these checks across all completed cases:

1. **Cost consistency**: Do financial case costs match economic case costs (after adjusting for transfers, taxes, and social vs accounting basis)?
2. **Benefits consistency**: Do management case BRP benefits match strategic case benefits register?
3. **Risk consistency**: Are risks in the management case risk register reflected in economic case risk costs?
4. **Timeline consistency**: Do management case milestones align with financial case cost phasing?
5. **Options consistency**: Is the preferred option the same across all cases?

Flag any inconsistencies to the user. Ask them to resolve before finalising.

6. **Reviewers checklist**: Cross-check the final business case against the HMT Business Case Reviewers Checklist (2022) to ensure all elements that Treasury spending teams assess are addressed. Key items: Is the case for change compelling? Are options genuinely different? Is the counterfactual realistic? Are costs complete (whole-life, including optimism bias)? Is the BCR computed correctly? Is the preferred option justified on balanced VfM (not BCR alone)?

**8b. Statutory duties assessment**

If the user selected statutory duties in Step 2, compile the full assessment here. Otherwise, add a placeholder noting the requirement.

**8c. Place-based analysis summary**

If applicable, compile the place-based analysis referencing economic case distributional findings.

---

### Step 9: Executive summary

Generate a 1-page executive summary covering:

1. **The investment**: project name, organisation, total cost, appraisal period
2. **The case for change**: 2-3 sentences from the strategic case
3. **The preferred option**: name, brief description
4. **Value for money**: NPSV, BCR, VfM category, key non-monetised benefits
5. **Affordability**: total cost, funding status, any funding gap
6. **Deliverability**: key risks, governance arrangements
7. **Recommendation**: proceed / proceed with conditions / do not proceed
8. **Next steps**: what approvals are needed, timeline

Include a "traffic light dashboard" across all five cases:

```
Table N: Business Case Dashboard

| Case         | Status | Key finding                                    |
|--------------|--------|------------------------------------------------|
| Strategic    | GREEN  | Strong case for change, aligned with priorities |
| Economic     | GREEN  | BCR of X.X, robust to sensitivity              |
| Commercial   | AMBER  | Procurement route to be confirmed               |
| Financial    | GREEN  | Fully funded within departmental budget         |
| Management   | AMBER  | M&E plan to be finalised                        |
```

RAG rules:
- GREEN: Case is complete and robust at the current stage
- AMBER: Case is progressing but has gaps or unconfirmed elements appropriate to this stage
- RED: Case has significant weaknesses that must be resolved before approval

---

### Step 10: Output generation

10a. If `--sections` was used (partial business case), prepend a cover note:
"This document covers selected sections of the business case. Sections marked 'not included' require completion at the [next stage] stage."

10b. Assemble the full document in this order:
1. Cover page (project name, organisation, stage, date, version, author, client)
2. Executive summary (Step 9)
3. Strategic Case (Step 3)
4. Economic Case (Step 4)
5. Commercial Case (Step 5)
6. Financial Case (Step 6)
7. Management Case (Step 7)
8. Appendices:
   - A: Theory of Change (full diagram)
   - B: Options Framework Filter (full long list)
   - C: Detailed CBA tables (if generated)
   - D: Risk register (full)
   - E: Benefits register (full)
   - F: Methodology note (must contain: (1) Framework and version cited, (2) Discount rate and full schedule applied, (3) Appraisal period and justification, (4) Price base year, (5) Key data sources with dates, (6) Key assumptions listed, (7) Limitations and caveats, (8) Software/tools used)

10c. Add KEY NUMBERS block at the end (machine-readable):

```
<!-- KEY NUMBERS
project: [name]
framework: [uk/au/au-vic/au-nsw/au-qld/nz/eu/wb/us]
stage: [soc/obc/fbc]
price_base: [year]
discount_rate: [rate]
appraisal_period: [years]
total_cost_pv: [value]
total_benefit_pv: [value]
npsv: [value]
bcr: [value]
preferred_option: [name]
currency: [GBP/AUD/NZD/EUR/USD]
generated: [date]
-->
```

10d. Generate companion JSON file with all structured data (reloadable via `--from`).

10e. If `--format` specified, invoke the appropriate export skill:
- `xlsx`: Invoke `/xlsx` skill
- `word` or `docx`: Invoke `/docx` skill
- `pptx`: Invoke `/pptx` skill
- `pdf`: Invoke `/pdf` skill

10f. If `--exec` specified, generate an executive summary deck (8-12 slides):

Slide structure:
1. Title slide: "[Project name]: [Stage] Business Case"
2. The case for change (strategic case summary)
3. Options considered (OFF summary + short list)
4. The preferred option (what it delivers)
5. Value for money (NPSV, BCR, sensitivity headline)
6. Commercial approach (procurement route, key terms)
7. Affordability (cost profile, funding status)
8. Delivery plan (milestones, governance)
9. Risks and mitigations (top 5)
10. Dashboard and recommendation
11. Next steps and approvals needed

Formatting: Action title 24-28pt bold navy (#003078). Must be a complete sentence stating an insight, NOT a topic label. Body 14-16pt, one key number bolded per bullet. Footer 10pt light grey with source + date. Clean white background, no decorative elements. Slide numbers bottom-right. Charts in navy (#003078) / grey (#666666) / light blue (#4472C4) palette.

10g. If `--audit` specified, invoke `/econ-audit` on the generated output.

---

## Framework-specific appendix: Australian variations

### Commonwealth (RMG 308)

The Commonwealth Investment Framework under the PGPA Act 2013 does not formally use "Five Case Model" terminology but covers equivalent ground. Key differences:

- **Two-Pass Cabinet process**: First Pass (equivalent to SOC: strategic assessment + initial options) and Second Pass (equivalent to OBC/FBC: detailed business case + implementation plan)
- **Exit strategy**: Required for all material investments. Describe how the investment can be wound down if it fails or is no longer needed.
- **Whole-of-life management strategy**: Governance, risk controls, and operational arrangements for the full lifecycle
- **Department of Finance consultation**: Entities must consult DoF about materiality thresholds

When `--framework au` is selected, map stages: SOC = First Pass preparation, OBC = First Pass, FBC = Second Pass.

### Victoria HVHR

Victoria's High Value High Risk framework applies when any of these conditions are met:
- High risk on the Project Profile Model (PPM)
- Medium risk on PPM AND TEI between AUD 100m and AUD 250m
- Low risk on PPM but TEI exceeds AUD 250m
- Designated by Government

Key additions when `--framework au-vic` is selected:

1. **Project Profile Model (PPM) assessment**: Ask user for the PPM risk rating. Flag HVHR requirements if triggered.
2. **Gateway reviews**: Include Gates 1-6 in the milestones table. Note RAP requirements for Gates 1-4.
3. **Dual discount rates**: ALWAYS compute CBA at both 4% and 7%. Present both sets of results.
4. **Project Assurance Plan (PAP)**: Note the requirement for Treasurer-approved PAP for HVHR projects.
5. **Gate 6 benefits review**: Mandatory 6-18 months post-completion. Include in M&E plan.
6. **DTF reporting**: All red/amber Gateway recommendations must be reported to the Treasurer with an action plan.

### NSW (TPG24-29)

Key additions when `--framework au-nsw` is selected:

1. **Lean Business Case / Short Form Assessment**: For smaller proposals below the full business case threshold. If proportionality = light, offer lean format.
2. **Three Gateway Coordination Agencies**: Determine which applies:
   - NSW Treasury (REAF) for recurrent expenditure
   - Infrastructure NSW (INSW / IIAF) for capital infrastructure
   - Department of Customer Service (DCS / DAF) for ICT/digital
3. **Centre for Economic Evidence**: Note that NSW Treasury's CEE can assist with CBA methodology.
4. **Discount rate**: 7% central, sensitivity at 3% and 10%.

### Queensland (PAF)

Key additions when `--framework au-qld` is selected:

1. **8-stage PAF lifecycle**: Map the five cases across the 8 PAF stages. The business case sits primarily at PAF Stage 3 but draws from Stages 1-2.
2. **Business Case Development Framework (BCDF)**: The BCDF provides detailed "how-to" guidance within the PAF structure.
3. **Alliance and PPP guidelines**: Queensland has specific supporting guidelines for alliance establishment and PPP procurement. Flag if the commercial case involves either model.

---

## Framework-specific appendix: Other international variations

### New Zealand Better Business Cases

NZ adopted the UK Five Case Model with local adaptation. Key differences:
- Discount rate: 2% for non-commercial activities, 8% for commercial
- CBAx: Treasury's online cost-benefit analysis tool. Note its availability for CBA computation.
- Te Tiriti o Waitangi: Obligations under the Treaty of Waitangi must be considered in the strategic case.

### EU Better Regulation

The EU framework centres on Regulatory Impact Assessment:
- Problem definition, objectives, options, CBA, preferred solution, M&E
- Discount rate: 3% for advanced member states, 5% for convergence regions
- Cohesion policy projects use the EC Guide to CBA of Investment Projects

### World Bank PAD

The Project Appraisal Document structure:
- Strategic context and rationale
- Project development objectives
- Results framework
- Economic and Financial Analysis (EIRR, NPV, BCR at 10% or country-specific)
- Environmental and social safeguards
- Fiduciary assessment

### US OMB

Federal business cases use OMB Circular A-94 (revised) and A-4:
- Discount rate: 2% (A-4 2023 revision)
- Regulatory Impact Analysis for regulations
- Capital Programming Guide (OMB A-11 Part 7) for investments
- Federal Acquisition Regulation (FAR) for procurement

---

## JSON schema (for --from)

When `--from schema` is invoked, print the following structure:

```json
{
  "project": {
    "name": "string",
    "description": "string",
    "organisation": "string",
    "sector": "string",
    "stage": "soc|obc|fbc",
    "framework": "uk|au|au-vic|au-nsw|au-qld|nz|eu|wb|us",
    "price_base_year": "number",
    "appraisal_period_years": "number",
    "estimated_total_cost": "number",
    "currency": "GBP|AUD|NZD|EUR|USD"
  },
  "cases_to_include": ["strategic", "economic", "commercial", "financial", "management"],
  "strategic_case": {
    "case_for_change": "string",
    "market_failure_type": "string",
    "theory_of_change": {
      "inputs": "string",
      "activities": "string",
      "outputs": "string",
      "outcomes": "string",
      "impact": "string",
      "assumptions": ["string"]
    },
    "smart_objectives": ["string"],
    "spending_objectives": ["string"],
    "investment_objectives": ["string"],
    "benefits": [
      {
        "name": "string",
        "category": "cash_releasing|non_cash_quantifiable|qualitative",
        "owner": "string",
        "baseline": "string",
        "target": "string",
        "measurement": "string"
      }
    ],
    "critical_success_factors": ["string"],
    "constraints": ["string"],
    "dependencies": ["string"],
    "stakeholders": [
      {
        "name": "string",
        "interest": "string",
        "influence": "high|medium|low"
      }
    ],
    "strategic_fit": "string",
    "pestle": {
      "political": "string",
      "economic": "string",
      "social": "string",
      "technological": "string",
      "legal": "string",
      "environmental": "string"
    }
  },
  "economic_case": {
    "options_framework": {
      "scope": ["string"],
      "solution": ["string"],
      "delivery": ["string"],
      "implementation": ["string"],
      "funding": ["string"]
    },
    "short_list": [
      {
        "name": "string",
        "description": "string",
        "costs_pv": "number",
        "benefits_pv": "number",
        "npsv": "number",
        "bcr": "number"
      }
    ],
    "preferred_option": "string",
    "preferred_option_rationale": "string",
    "cba_import_file": "string (optional, path to /cost-benefit JSON output)"
  },
  "commercial_case": {
    "procurement_route": "string",
    "procurement_justification": "string",
    "contract_type": "string",
    "contract_duration_years": "number",
    "risk_allocation": [
      {
        "risk": "string",
        "allocation": "public|private|shared",
        "rationale": "string"
      }
    ],
    "kpis": [
      {
        "kpi": "string",
        "target": "string",
        "frequency": "string",
        "remedy": "string"
      }
    ],
    "payment_mechanism": "string",
    "market_engagement": "string",
    "social_value": "string",
    "personnel_implications": "string"
  },
  "financial_case": {
    "capital_costs": {
      "categories": ["string"],
      "years": ["number"],
      "values": [["number"]]
    },
    "revenue_costs": {
      "categories": ["string"],
      "years": ["number"],
      "values": [["number"]]
    },
    "funding_sources": [
      {
        "source": "string",
        "amount": "number",
        "status": "confirmed|indicative|sought|projected",
        "conditions": "string"
      }
    ],
    "income_streams": {
      "categories": ["string"],
      "years": ["number"],
      "values": [["number"]]
    },
    "inflation_assumption": "string",
    "contingency_percent": "number",
    "balance_sheet_treatment": "string"
  },
  "management_case": {
    "sro": "string",
    "project_director": "string",
    "governance_description": "string",
    "methodology": "string",
    "milestones": [
      {
        "milestone": "string",
        "target_date": "string",
        "dependencies": "string"
      }
    ],
    "risk_register": [
      {
        "risk": "string",
        "category": "string",
        "probability": "number (1-5)",
        "impact": "number (1-5)",
        "mitigation": "string",
        "owner": "string"
      }
    ],
    "benefits_realisation": {
      "tracking_approach": "string",
      "review_frequency": "string"
    },
    "evaluation": {
      "methodology": "string",
      "evidence_standard": "string",
      "timeline": "string",
      "budget_percent": "number",
      "independence": "string"
    },
    "resources": [
      {
        "role": "string",
        "fte": "number",
        "source": "internal|external",
        "cost_pa": "number"
      }
    ],
    "change_management": "string",
    "assurance_plan": "string",
    "exit_strategy": "string",
    "post_project_evaluation": "string"
  }
}
```
