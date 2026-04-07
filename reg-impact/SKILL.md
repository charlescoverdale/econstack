---
name: reg-impact
description: Regulatory Impact Assessment (UK Better Regulation, AU OIA RIS, EU Better Regulation Toolbox, US OMB). Compliance costs, CBA per option, small business test, competition filter. Interactive.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
  - Skill
  - WebSearch
  - WebFetch
---

**Only stop to ask the user when:** the regulation is unclear, the affected population is unknown, or compliance cost data is missing and cannot be estimated.
**Never stop to ask about:** template structure (use the detected framework), discount rate (use framework default), or which sections to include (include all required sections for the stage).
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

# /reg-impact: Regulatory Impact Assessment

Generate a Regulatory Impact Assessment (RIA) or Regulatory Impact Statement (RIS) for a proposed regulation, policy, or legislative change. Covers 9 frameworks: UK Better Regulation, Australian Commonwealth OIA, five Australian state frameworks (QLD, VIC, NSW, SA, WA), EU Better Regulation Toolbox, and US OMB Circular A-4.

The RIA is distinct from a CBA (which is one section within it) and distinct from a business case (which covers delivery and management, not regulatory compliance). An RIA answers: what is the problem, why should government intervene, what are the options, what are the costs and benefits of each, and how will we know if it worked?

**This skill is interactive.** It walks through each section, pulling data where available and asking for inputs where needed.

## Arguments

```
/reg-impact [description of the regulation] [options]
```

**Examples:**
```
/reg-impact "Mandatory climate risk disclosure for listed companies"
/reg-impact "Ban on single-use plastics in food packaging" --framework uk
/reg-impact "Increase minimum wage to $25/hour" --framework au
/reg-impact "New short-term rental regulations" --framework au-vic
/reg-impact "Changes to mining rehabilitation bonds" --framework au-qld
/reg-impact "New data protection requirements for AI systems" --framework eu
/reg-impact --from inputs.json
```

**Options:**
- `--framework <name>` : Regulatory framework. Auto-detected from context. `uk` (Better Regulation Framework), `au` (OIA Regulatory Impact Statement), `eu` (Better Regulation Toolbox), `us` (OMB Circular A-4/A-94).
- `--stage <name>` : Assessment stage. `screening` (quick check: is a full RIA needed?), `consultation` (draft for public consultation), `final` (submission to regulatory oversight body). Default: `final`.
- `--with-cba <file>` : Import an existing CBA output from `/cost-benefit` for the economic analysis section.
- `--full` : Skip interactive menus, generate all sections.
- `--client "Name"` : Add "Prepared for" metadata.
- `--format <type>` : Output format: `markdown`, `word`, `pptx`, `pdf`, or `all`. Default: markdown.
- `--exec` : Generate executive summary deck (5-6 slides).
- `--audit` : Run `/econ-audit` on the output.
- `--from <file.json>` : Import all inputs from JSON. Use `--from schema` to print expected schema.

**Supported frameworks:**

| Flag | Framework | Oversight body | Discount rate | Key features |
|------|-----------|---------------|--------------|-------------|
| `uk` | UK Better Regulation Framework | Regulatory Policy Committee (RPC) | 3.5% | EANDCB, Small Business Impact Test, competition filter, post-implementation review |
| `au` | Australian Commonwealth OIA | Office of Impact Analysis (OIA) | 7% | 7 RIS questions, preliminary assessment, net benefit test, mandatory review |
| `au-qld` | Queensland Impact Analysis Statement | OBPR (QPC/Treasury) | 7% | IAS (not RIS), Exclusion/Summary/Full tiers, fundamental legislative principles test, 28-day consultation |
| `au-vic` | Victorian RIS / LIA | Commissioner for Better Regulation | 4% or 7% | $2M/$8M thresholds, RIS (subordinate) + LIA (primary), Regulatory Change Measurement, $500M red tape target |
| `au-nsw` | NSW Better Regulation Statement | NSW Treasury | 7% (3%, 10% sensitivity) | Seven Better Regulation Principles, BRS/RIS dual system, Licensing Framework test |
| `au-sa` | South Australia RIS | Cabinet Office (DPC) | 7% | Multi-agency gatekeeping (DTF, DTED, DFC, DENR), family/societal impact domain |
| `au-wa` | Western Australia CRIS/DRIS | Better Regulation Unit (DTF) | 7% | Two-stage CRIS/DRIS, Executive Director sign-off, BRU Letter of Advice |
| `eu` | EU Better Regulation Toolbox | Regulatory Scrutiny Board (RSB) | 3%/5% | Proportionality, subsidiarity, SME test, stakeholder consultation, REFIT |
| `us` | US OMB Circular A-4 | OIRA | 2% | Baseline analysis, break-even analysis, transfer analysis |

## Instructions

### Step 0: Framework detection and setup

Auto-detect framework from context:
- "UK", "GBP", "RPC", "EANDCB" -> `uk`
- "Queensland", "QLD", "QPC", "IAS" -> `au-qld`
- "Victoria", "VIC", "BRV", "Commissioner for Better Regulation", "LIA" -> `au-vic`
- "NSW", "New South Wales", "BRS", "Better Regulation Statement" -> `au-nsw`
- "South Australia", "SA", "DPC" (in AU context) -> `au-sa`
- "Western Australia", "WA", "BRU", "CRIS", "DRIS" -> `au-wa`
- "Australia", "AUD", "OIA", "Commonwealth" (without state indicators) -> `au`
- "EU", "EUR", "RSB", "subsidiarity", "REFIT" -> `eu`
- "US", "USD", "OIRA", "OMB", "A-4" -> `us`

If ambiguous (e.g., "Australian regulation" without a state), ask:
```
AskUserQuestion: "Which Australian jurisdiction?"
Options:
  - "Commonwealth (federal, OIA)" (Recommended)
  - "Queensland (QPC/OBPR)"
  - "Victoria (Better Regulation Victoria)"
  - "New South Wales (NSW Treasury)"
```

Load parameters from the parameter database:
```bash
PARAMS_DIR="$HOME/econstack-data/parameters"
cat "$PARAMS_DIR/${FRAMEWORK}/discount-rates.json"
```

### Step 1: Problem definition

```
AskUserQuestion: "Describe the regulation or policy change in 2-3 sentences."
```

```
AskUserQuestion: "What is the problem this regulation addresses?"
Options:
  - "Market failure (externality, information asymmetry, public good, market power)"
  - "Regulatory failure (existing regulation is ineffective or outdated)"
  - "Government objective (equity, safety, environment, international obligation)"
  - "Risk mitigation (emerging risk that current framework does not address)"
```

```
AskUserQuestion: "What evidence exists for this problem? (Data, reports, incidents, international comparisons)"
(Free text)
```

For UK framework: this feeds into the RPC's "evidence of the problem" assessment. The RPC will red-rate an RIA that asserts a problem without evidence.

For AU framework: this maps to RIS Question 1 ("What is the problem you are trying to solve?") and Question 2 ("Why is government action needed?").

### Step 2: Rationale for intervention

```
AskUserQuestion: "Why is government action (specifically regulation) needed? Why can't the market, industry self-regulation, or existing laws solve this?"
(Free text)
```

For UK: reference the Green Book market failure framework. If the intervention is not addressing a market failure, the rationale must be especially strong.

For AU: the OIA requires demonstration that non-regulatory alternatives have been considered. Ask:
```
AskUserQuestion: "Have non-regulatory alternatives been considered?"
Options:
  - "Yes, but they are insufficient (explain why)"
  - "No, regulation is the only viable approach (explain why)"
  - "Self-regulation was tried and failed"
  - "International obligations require legislation"
```

### Step 3: Objectives

```
AskUserQuestion: "What are the objectives of this regulation? (What outcome should it achieve?)"
(Free text)
```

Check: are the objectives SMART? (Specific, Measurable, Achievable, Relevant, Time-bound). Flag if they are vague.

### Step 4: Options

Every RIA requires at least three options:

**Option 0: Do nothing / status quo.** What happens if no new regulation is introduced? This is the baseline against which all other options are measured.

**Option 1: Non-regulatory / voluntary approach.** Self-regulation, industry codes, guidance, information campaigns.

**Option 2+: Regulatory options.** Different levels of intervention (light-touch vs prescriptive), different scope (all businesses vs large only), different mechanisms (ban vs tax vs standard vs disclosure).

```
AskUserQuestion: "List the regulatory options being considered (2-4 options beyond do-nothing)."
(Free text)
```

For each option, ask:
```
AskUserQuestion: "For Option [N]: briefly describe what it involves, who it affects, and how it would be enforced."
(Free text)
```

### Step 5: Cost-benefit analysis per option

This is the core economic section. For each option (including do-nothing as the baseline):

**Costs to business (compliance costs):**

Use the Standard Cost Model (SCM) where applicable:
```
Compliance cost = Number of affected businesses
                  x Cost per business (time + direct costs)
                  x Frequency per year
```

```
AskUserQuestion: "How many businesses or organisations are affected by this regulation?"
```

```
AskUserQuestion: "What are the main compliance activities? (e.g., reporting, training, equipment, testing, record-keeping)"
(Free text)
```

For each compliance activity, estimate:
- Staff time (hours per occurrence x hourly cost)
- Direct costs (equipment, testing, certification fees)
- One-off setup costs vs ongoing annual costs
- Familiarisation costs (reading and understanding the new regulation)

**Costs to government:**
- Administration and enforcement costs
- Monitoring and inspection costs

**Benefits:**
- Monetise where possible (health outcomes, environmental improvements, accident reduction, consumer savings)
- Quantify-but-not-monetise where monetisation is speculative
- Describe qualitatively where quantification is not feasible

**CBA computation:**

If `--with-cba` provided: import the CBA output and summarise.

Otherwise, invoke the `/cost-benefit` skill internally:
```
Invoke /cost-benefit with:
  --framework [current framework]
  Appraisal period: [regulation lifetime, typically 10 years]
  Options: [from Step 4]
```

Or, for simpler regulations, compute directly:

```
NPV per option = PV(benefits) - PV(costs)
BCR per option = PV(benefits) / PV(costs)
```

Using framework-appropriate discount rates:
- UK: 3.5% (Green Book STPR)
- AU Commonwealth: 7% (OIA standard)
- AU-QLD: 7% (Queensland Treasury)
- AU-VIC: 4% or 7% (Victorian DTF, report both for high-impact RIS)
- AU-NSW: 7% central, with 3% and 10% sensitivity (TPP17-03)
- AU-SA: 7% (follows Commonwealth convention)
- AU-WA: 7% (follows Commonwealth convention)
- EU: 3% or 5% (depending on member state)
- US: 2% (OMB A-4 2023 revision)

**For UK framework, compute EANDCB:**
```
EANDCB = Equivalent Annual Net Direct Cost to Business
       = NPV of direct costs to business (annualised over appraisal period)
```

This is the headline figure the RPC assesses. It determines the "in/out" regulatory budget classification.

### Step 6: Framework-specific tests

**UK Better Regulation:**

**Small and Micro Business Assessment (SaMBA):**
```
AskUserQuestion: "Does this regulation affect small businesses (under 50 employees) or micro businesses (under 10 employees)?"
Options:
  - "Yes, and they will be subject to the same requirements as large businesses"
  - "Yes, but with exemptions or lighter requirements"
  - "No, small/micro businesses are exempt"
  - "Not applicable (regulation targets large businesses only)"
```

If small businesses are affected without exemption, justify why an exemption is not possible. The RPC expects this justification to be robust.

**Competition assessment (OFT 4 questions):**
1. Will the regulation directly or indirectly limit the number or range of suppliers?
2. Will it limit the ability of suppliers to compete?
3. Will it limit suppliers' incentives to compete vigorously?
4. Will it limit the choices and information available to consumers?

If the answer to any is "yes," a detailed competition assessment is needed.

**Australian OIA:**

**7 RIS Questions** (the backbone of the Australian RIS):
1. What is the problem you are trying to solve?
2. Why is government action needed?
3. What policy options are you considering?
4. What is the likely net benefit of each option?
5. Who was consulted and how did their views influence the proposal?
6. What is the best option from those considered?
7. How will you implement and evaluate the chosen option?

The skill maps its sections to these 7 questions.

**EU Better Regulation:**

**Subsidiarity check:** Is EU-level action necessary, or can member states act individually?

**SME test:** Impact on small and medium enterprises. Include a specific SME cost estimate.

**Proportionality check:** Is the regulatory response proportionate to the problem?

**US OMB:**

**Baseline analysis:** What happens under current regulation? (Not "do nothing" but "continue current rules.")

**Transfer analysis:** Distinguish between real resource costs and transfers between groups (e.g., a tax transfers money from businesses to government but is not a net cost to society).

**Break-even analysis:** What is the minimum benefit required for the regulation to be justified?

**Queensland (au-qld):**

**Fundamental legislative principles test:** Does the regulation have sufficient regard to the rights and liberties of individuals? Does it have sufficient regard to the institution of Parliament? These are constitutional requirements under the Legislative Standards Act 1992.

**Competition impact assessment:** Consistent with National Competition Policy obligations. Does the regulation restrict competition? If so, demonstrate that the benefits outweigh the costs and that the objectives can only be achieved by restricting competition.

**Direct costs calculation:** Use the Queensland Direct Costs Calculator tool (simplified or standard version) to estimate compliance costs. The OBPR provides both versions.

**Victoria (au-vic):**

**Regulatory Change Measurement (RCM):** For high-impact RIS ($8M+ per year), quantify the change in regulatory burden using the Victorian RCM methodology. Three cost types: administrative costs (paperwork, reporting), compliance costs (substantive changes to behaviour), delay costs (time waiting for approvals). Use the RCM Toolkit from DTF.

**Small business impact statement:** Mandatory within the "Preferred option summary" section (Question 5). Describe specific impacts on small businesses and any accommodations (phased implementation, simplified compliance, exemptions).

**Commissioner for Better Regulation assessment:** The Commissioner independently assesses the adequacy of each RIS. Allow 3-4 business days per draft for low-impact, 10 business days for high-impact. Budget for 3-4 draft iterations.

**NSW (au-nsw):**

**Licensing Framework assessment:** If the proposal creates a new licence or revises an existing one, apply the NSW Licensing Framework. Demonstrate that licensing is the least restrictive option that achieves the regulatory objective.

**Principles-based assessment:** Unlike the prescriptive templates of other jurisdictions, NSW requires demonstration that each of the Seven Better Regulation Principles has been satisfied. This is a principles check, not a template fill.

**SA (au-sa):**

**Multi-agency gatekeeping:** Circulate the draft RIS to all four assessment agencies (DTF, DTED, DFC, DENR) plus Cabinet Office simultaneously. All must assess adequacy before proceeding. Allow time for this parallel review process.

**Family and societal impact assessment:** Unique to SA. Explicitly assess the impact on families, including: financial impacts on households, impacts on family relationships and stability, impacts on children and young people.

**WA (au-wa):**

**Agency Self-Assessment Template:** Must be completed and signed off at Executive Director level before the BRU will engage. This is the gateway to the full process.

**BRU Letter of Advice:** The BRU issues formal Letters of Advice at both the CRIS and DRIS stages. These are independent assessments of the adequacy of the analysis. Address all points raised in the first Letter before finalising the DRIS.

### Step 7: Sensitivity and risk

- What are the key uncertainties in the cost and benefit estimates?
- Compute switching values: how much would costs need to increase (or benefits decrease) for the preferred option to have negative NPV?
- For UK: RPC expects sensitivity analysis as a minimum. Monte Carlo for regulations with EANDCB > GBP 50m.
- Identify the main risks to successful implementation.

### Step 8: Post-implementation review plan

```
AskUserQuestion: "When should this regulation be reviewed? (Default: 5 years for UK, mandatory within 2 years for AU)"
```

Outline:
- Review date
- Evaluation questions (did it achieve the objectives? Were costs as expected?)
- Data requirements for the review
- Who will conduct the review

For UK: reference the Regulatory Policy Committee's post-implementation review guidance.
For AU: mandatory review within 5-10 years (shorter for significant regulations). The OIA tracks compliance.

### Step 9: Consultation summary

```
AskUserQuestion: "Has public consultation been conducted? If yes, summarise the key feedback."
(Free text, or "Not yet" / "Planned")
```

For UK at `final` stage: consultation is expected. At `consultation` stage: this section describes the planned consultation.
For AU: consultation is mandatory. RIS Question 5 covers this explicitly.

### Step 10: Executive summary and recommendation

Generate a 1-page executive summary covering:
1. The problem (2 sentences)
2. The preferred option (2 sentences)
3. Headline costs and benefits (EANDCB for UK, net benefit for AU)
4. Key risks and mitigations
5. Recommendation

### Step 11: Output

Assemble the full document:

**UK structure:**
1. Title and RPC reference
2. Executive summary
3. Problem under consideration
4. Rationale for intervention
5. Policy objective
6. Description of options
7. Monetised and non-monetised costs and benefits of each option
8. EANDCB calculation
9. Small and Micro Business Assessment
10. Competition assessment
11. Wider impacts (equality, environment, health, human rights)
12. Post-implementation review plan
13. Summary table (costs/benefits/EANDCB per option)
14. Annex: analytical methodology

**AU Commonwealth structure (7 RIS questions):**
1. Cover sheet (entity, contact officer, RIS ID)
2. Executive summary
3. Q1: What is the problem?
4. Q2: Why is government action needed?
5. Q3: What options are being considered?
6. Q4: What is the net benefit of each option?
7. Q5: Who was consulted?
8. Q6: What is the best option?
9. Q7: How will it be implemented and evaluated?
10. Appendix: detailed CBA tables

**Queensland structure (Impact Analysis Statement):**

Note: Queensland uses "Impact Analysis Statement" (IAS), not RIS. Three tiers: Exclusion IAS, Summary IAS, Full IAS (Consultation + Decision).

For Summary IAS:
1. Header (lead department, proposal name, instrument title, date)
2. Nature, size and scope of the problem
3. Objectives of government action
4. Policy options considered
5. Impacts of the proposal (costs and benefits)
6. Direct costs (using Queensland Direct Costs Calculator)
7. Consultation undertaken
8. Consistency with fundamental legislative principles

For Full IAS (Consultation IAS, released for 28-day public consultation):
1. Problem identification with evidence
2. Objectives of government action
3. Options analysis (regulatory and non-regulatory)
4. Impact analysis per option with CBA
5. Competition impact assessment (National Competition Policy)
6. Consultation plan and stakeholder engagement
7. Recommended option with justification
8. Consistency with fundamental legislative principles
9. Implementation and evaluation strategy

For Full IAS (Decision IAS, post-consultation):
All sections from Consultation IAS, plus:
10. Summary of submissions received and key issues raised
11. Agency response to consultation feedback
12. Any changes to the preferred option based on consultation

**Victorian structure (RIS or LIA):**

Note: Victoria has two instruments: RIS (subordinate legislation, under Subordinate Legislation Act 1994) and LIA (primary legislation, under Cabinet Handbook). Both follow the same 7-question structure but LIAs are assessed by the Commissioner for Better Regulation.

Thresholds: < $2M/year = no RIS. $2M-$8M/year = low-impact RIS. > $8M/year = high-impact RIS.

Seven mandatory questions:
1. Problem analysis: why is the Government considering action?
2. Objectives: which outcomes is the Government aiming to achieve?
3. Options identification: what are the possible courses of action?
4. Impact analysis: what are the expected impacts (benefits and costs) and what is the preferred option?
5. Preferred option summary: characteristics including small business and competition impacts
6. Implementation plan: how will the preferred option be put into place?
7. Evaluation strategy: when and how will the Government evaluate effectiveness?

For high-impact RIS: add Regulatory Change Measurement (RCM) analysis quantifying the change in regulatory burden using the Victorian RCM methodology (administrative costs, compliance costs, delay costs).

**NSW structure (Better Regulation Statement):**

Note: NSW uses two instruments: Better Regulation Statement (BRS, for Cabinet proposals) and RIS (for subordinate legislation under Subordinate Legislation Act 1989). Both must satisfy the Seven Better Regulation Principles.

Seven Better Regulation Principles:
1. Need for government action established (benefits outweigh costs)
2. Objective of government action is clear
3. Impact properly understood across a range of options
4. Action is effective and proportional
5. Consultation has informed regulatory development
6. Simplification, repeal, reform or consolidation considered
7. Regulation will be periodically reviewed

BRS structure:
1. Executive summary / overview
2. Proportionality demonstration
3. Consultation approach and summary of stakeholder views
4. Cost-benefit analysis (preferred option provides greatest net benefit)
5. Preferred option justification
6. Licensing Framework assessment (if new/revised licence proposed)

**South Australia structure:**
1. Problem description (nature, evidence, scale, who is affected)
2. Objectives of government action
3. Statement of options (regulatory and non-regulatory)
4. Cost-benefit analysis per option
5. Consultation evidence
6. Recommended option with justification
7. Implementation, monitoring and review

Note: SA uses a multi-agency gatekeeping process. The RIS is assessed across four domains by different agencies: business and regional impacts (DTED), CBA quality (DTF), family and societal impacts (DFC), environmental impacts (DENR).

**Western Australia structure (CRIS/DRIS):**

Note: WA uses a two-stage process with BRU Letters of Advice at each stage. Starts with Agency Self-Assessment Template signed off at Executive Director level.

Consultation RIS (CRIS):
1. Problem definition
2. Non-regulatory and regulatory options
3. Comparative analysis of options
4. Expected costs and benefits per option
(BRU reviews and issues Letter of Advice before publication)

Decision RIS (DRIS):
1. Executive summary
2. Issue statement
3. Policy objectives
4. Options considered
5. Impact assessment
6. Consultation summary (incorporating CRIS feedback)
7. Preferred option with supporting reasons
8. Implementation and enforcement details
9. Evaluation/review plan
(BRU reviews and issues second Letter of Advice)

**EU structure:**
1. Context and problem definition
2. Subsidiarity and proportionality
3. Objectives
4. Policy options
5. Impact assessment (economic, social, environmental)
6. Comparison of options
7. Preferred option
8. Monitoring and evaluation
9. Annexes (SME test, stakeholder consultation)

**US structure:**
1. Executive summary
2. Need for regulatory action
3. Regulatory alternatives
4. Benefits and costs of alternatives
5. Transfer analysis
6. Distributional effects
7. Uncertainty analysis
8. Break-even analysis

Save as `ria-{slugified-topic}-{date}.md`.

Add KEY NUMBERS block:
```markdown
<!-- KEY NUMBERS
type: ria
framework: [uk/au/eu/us]
regulation: [topic]
preferred_option: [name]
eandcb: [value, UK only]
npv_preferred: [value]
bcr_preferred: [value]
businesses_affected: [count]
annual_compliance_cost: [value]
review_date: [date]
date: [date]
-->
```

Generate companion JSON. If `--format` specified, invoke export skills. If `--audit`, run `/econ-audit`.

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
- The RIA is not an advocacy document. It presents the evidence for and against each option, including the preferred option. An RIA that only presents benefits is a political document, not an analytical one.
- Always include the do-nothing baseline. The RPC and OIA will reject an RIA without a proper counterfactual.
- Compliance costs must be estimated bottom-up (Standard Cost Model), not top-down. "We estimate costs of GBP 10m" without showing the calculation is not acceptable.
- EANDCB (UK) is the single most scrutinised number in a UK RIA. Get it right. Show the full calculation.
- For AU, the 7 RIS questions are not optional. Every question must be answered, even if the answer is brief.
- Sensitivity analysis is mandatory, not optional. The oversight body will red-rate an RIA without it.
- The post-implementation review plan is not boilerplate. It must specify evaluation questions, data requirements, and a realistic timeline.
- When monetising benefits, be conservative. Overstated benefits are the single most common reason for RPC red ratings.
