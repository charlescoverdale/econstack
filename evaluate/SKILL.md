---
name: evaluate
description: Full programme evaluation (Magenta Book, Australian Commonwealth/state, OECD DAC). Evaluation plans, mid-term, final, PIR, synthesis. Process + impact + economic evaluation. Counterfactual method selection. Interactive.
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

**Only stop to ask the user when:** programme details are missing, counterfactual method needs confirming, or evidence quality is ambiguous.
**Never stop to ask about:** framework defaults (use detected framework), evaluation question wording, section ordering, or methodology prose.
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

# /evaluate: Programme Evaluation

Generate full programme evaluations aligned with the UK Magenta Book, Australian Commonwealth Evaluation Policy, and OECD DAC criteria. Covers the complete evaluation lifecycle: planning, mid-term assessment, final evaluation, post-implementation review, and synthesis.

This skill is the Magenta Book companion, the same way `/business-case` is the Green Book companion. It wraps `/vfm-eval` for the economic component but adds process evaluation, impact evaluation, and evaluation planning.

```
/cost-benefit  = Before: "Should we do this?"
/business-case = Before: "Full investment case"
/vfm-eval      = After:  "Was it value for money?" (economic evaluation only)
/evaluate      = After:  "Did it work? Why? For whom?" (full evaluation)
```

**This skill is interactive.** It confirms the evaluation type, programme details, and methodology, then generates the document section by section.

**What this skill does NOT do:**
- Does not run statistical analysis (DiD regressions, PSM, RCTs). That is R/Stata territory. The planned `causalkit` R package will handle estimation.
- Does not collect primary data (surveys, interviews, focus groups). It structures the plan for data collection.
- Does not replace a qualified evaluator. It automates the mechanical 80% (structure, templates, method selection, quality checks) so the evaluator can focus on interpretation and judgment.
- Does not assess the quality of existing evaluation evidence. For that, use `/econ-audit`.

## Arguments

```
/evaluate [programme name or description] [options]
```

**Examples:**
```
/evaluate "National Apprenticeship Programme 2020-2025"
/evaluate "Victorian Level Crossing Removal" --framework au-vic --type final
/evaluate --type plan "New early years intervention pilot"
/evaluate --type pir "Data retention regulations" --framework au
/evaluate --type midterm "Levelling Up Fund Round 2"
```

**Options:**
- `--type <type>` : Document type. `plan` (evaluation framework/plan), `midterm` (formative), `final` (summative), `pir` (post-implementation review, AU), `synthesis` (meta-evaluation). Default: ask.
- `--framework <name>` : Evaluation framework. Auto-detected. See table below.
- `--sections` : Interactive section picker (choose which sections to complete).
- `--full` : Skip interactive menus, generate all sections.
- `--with-cba <file>` : Import CBA output to compare predicted vs actual.
- `--with-vfm <file>` : Import existing VfM evaluation output for the economic component.
- `--client "Name"` : Add "Prepared for" metadata.
- `--format <type>` : Output: `markdown`, `word`, `pptx`, `pdf`, or `all`. Default: markdown.
- `--exec` : Executive summary deck (5-8 slides).
- `--audit` : Run `/econ-audit` on the output.
- `--from <file.json>` : Import all inputs from JSON, skip interactive questions. Use `--from schema` to print expected schema.

**Supported frameworks:**

| Flag | Framework | Focus | Key feature |
|------|-----------|-------|-------------|
| `uk` | UK Magenta Book (default) | Full evaluation lifecycle | Maryland SMS levels, ETF Registry, ROAMEF cycle |
| `au` | Australian Commonwealth (ACE) | 5 evaluation principles | PIR mandatory, ACE assessment, Indigenous Evaluation Strategy |
| `au-vic` | Victoria DTF | HVHR Gateway reviews | Gate 6 benefits realisation, programme evaluation for lapsing programmes |
| `au-nsw` | NSW Treasury | Investment framework | Logic model alignment with business case, CEE guidance |
| `au-qld` | Queensland PAF | Project lifecycle | Stage 8 benefits realisation, Gateway Gate 5 |
| `dac` | OECD DAC (2019 revision) | Development cooperation | 6 criteria: relevance, coherence, effectiveness, efficiency, impact, sustainability |
| `nesta` | NESTA Standards of Evidence | Innovation programmes | 5 evidence levels, Level 3+ for causal claims |
| `us` | US Evidence Act 2018 | Federal evaluation | OMB Evaluation Standards, learning agendas |

## Instructions

### Step 0: Setup and framework detection

Auto-detect framework:
- "UK", "GBP", "Magenta Book", "Green Book", "HMT", "ETF" -> `uk`
- "Victoria", "VIC", "DTF", "HVHR", "Gateway" -> `au-vic`
- "NSW", "New South Wales" -> `au-nsw`
- "Queensland", "QLD", "PAF" -> `au-qld`
- "Australia", "AUD", "ACE", "OIA", "Commonwealth" (without state indicators) -> `au`
- "DAC", "OECD", "development", "bilateral", "multilateral" -> `dac`
- "NESTA", "innovation", "social enterprise" -> `nesta`
- "US", "USD", "Evidence Act", "OMB", "federal" -> `us`

If ambiguous, ask via AskUserQuestion.

### Step 1: Evaluation type

If `--type` not specified:
```
AskUserQuestion: "What type of evaluation document do you need?"
Options:
  - "Evaluation plan (pre-programme: design the evaluation before it starts)" (Recommended for new programmes)
  - "Mid-term evaluation (formative: is it on track? should we adapt?)"
  - "Final evaluation (summative: did it work? was it worth it?)"
  - "Post-implementation review (AU regulatory PIR)"
```

### Step 2: Programme details

```
AskUserQuestion: "Describe the programme or intervention being evaluated."
(Free text)
```

```
AskUserQuestion: "What are the programme's objectives?"
(Free text)
```

```
AskUserQuestion: "What is the programme's total budget and duration?"
(Free text)
```

```
AskUserQuestion: "Who is the target population?"
(Free text)
```

### Step 3: Theory of Change

Build or import the Theory of Change. This is the backbone of the entire evaluation.

```
AskUserQuestion: "Do you have an existing Theory of Change or logic model?"
Options:
  - "Yes, I'll describe it"
  - "Import from a business case (I have a /business-case output)"
  - "No, help me build one"
```

If building from scratch, walk through each level:
```
AskUserQuestion: "INPUTS: What resources go into the programme? (funding, staff, equipment)"
AskUserQuestion: "ACTIVITIES: What does the programme do? (training, building, regulating)"
AskUserQuestion: "OUTPUTS: What does it produce? (courses delivered, houses built, regulations enacted)"
AskUserQuestion: "OUTCOMES: What changes result? (employment, health, behaviour change)"
AskUserQuestion: "IMPACT: What long-term societal change is expected? (reduced inequality, economic growth)"
```

For each link in the chain, ask:
```
AskUserQuestion: "What ASSUMPTIONS connect [this level] to [next level]? What has to be true for this step to work?"
```

Render as:

```
Table N: Theory of Change

| Level      | Description | Assumptions | Testable? | Evidence |
|------------|-------------|-------------|-----------|----------|
| Inputs     |             |             |           |          |
| Activities |             |             |           |          |
| Outputs    |             |             |           |          |
| Outcomes   |             |             |           |          |
| Impact     |             |             |           |          |
```

For evaluation plans: the "Evidence" column should show the pre-existing baseline evidence supporting each assumption. If no evidence exists, mark as "To be tested" and flag this as a key evaluation risk.

For final evaluations: the "Evidence" column shows whether each assumption held, with supporting data.

### Step 4: Evaluation questions

Generate evaluation questions organised by the three evaluation types:

**Process questions** (was it implemented well?):
- Was the programme delivered as designed?
- Did it reach the intended target population?
- What were the barriers and enablers to implementation?
- Were there any unintended consequences?

**Impact questions** (did it cause the observed outcomes?):
- What outcomes were achieved?
- To what extent can outcomes be attributed to the programme (vs what would have happened anyway)?
- Were there differential impacts across subgroups?
- Were there any unintended positive or negative effects?

**Economic questions** (was it value for money?):
- Were resources used economically?
- Were outputs delivered efficiently?
- Do the benefits justify the costs?

```
AskUserQuestion: "Are there additional evaluation questions specific to this programme?"
(Free text, optional)
```

### Step 5: Methodology and counterfactual design

**For evaluation plans:** help select the right counterfactual method using the decision tree:

```
AskUserQuestion: "What evaluation approach is most appropriate for this programme?"
Options:
  - "RCT (we can randomise who receives the programme)"
  - "Quasi-experimental (natural threshold, comparison group, or time series available)"
  - "Theory-based (complex programme where isolating a single causal effect is inappropriate)"
  - "Monitoring only (no counterfactual feasible)"
```

If quasi-experimental, follow up:
```
AskUserQuestion: "Which quasi-experimental method?"
Options:
  - "Difference-in-Differences (treatment and comparison groups with pre/post data)"
  - "Regression Discontinuity (eligibility threshold or cut-off score)"
  - "Propensity Score Matching (comparison group matched on observable characteristics)"
  - "Interrupted Time Series (rich pre-intervention time series, no comparison group)"
  - "Synthetic Control (single treated area, donor pool of comparators)"
```

If theory-based, follow up:
```
AskUserQuestion: "Which theory-based approach?"
Options:
  - "Contribution Analysis (assess the contribution of the programme to observed outcomes)"
  - "Realist Evaluation (Context-Mechanism-Outcome configurations: what works, for whom, in what circumstances)"
  - "Process Tracing (trace causal mechanisms through detailed case analysis)"
  - "Qualitative Comparative Analysis (QCA: identify necessary and sufficient conditions across cases)"
```

Map to methods and evidence quality:

| Method | SMS Level | Key requirements |
|---|---|---|
| Randomised Control Trial | 5 | Sufficient sample, ethical approval, implementation fidelity |
| Regression Discontinuity Design | 4 | Sharp or fuzzy cut-off, manipulation testing |
| Difference-in-Differences | 3-4 | Parallel trends assumption, pre-treatment data |
| Propensity Score Matching | 3 | Rich pre-treatment observables, common support assumption |
| Synthetic Control | 3-4 | Single treated unit, large donor pool, good pre-treatment fit |
| Interrupted Time Series | 2-3 | 8+ pre-intervention observations, no concurrent changes |
| Contribution Analysis | 2-3 | Strong theory of change, multiple evidence streams |
| Realist Evaluation | 2-3 | CMO configurations, iterative theory testing |
| Process Tracing | 2 | Detailed case knowledge, within-case evidence |
| Before-and-after (monitoring only) | 1-2 | Acknowledge attribution limitations prominently |

For each method, note:
- What data is needed (and when to start collecting)
- Key assumptions to test
- Sample size / power considerations
- Limitations

**Power and sample size guidance (for RCTs and quasi-experimental designs):**

Estimate the minimum detectable effect size (MDES) given the expected sample:
- For a 2-group RCT with 80% power and 5% significance: ~400 per group to detect a 0.2 SD effect, ~65 per group for 0.5 SD.
- For cluster-randomised designs (common in area-based policies): inflate by the design effect: DE = 1 + (m-1) x ICC, where m is cluster size and ICC is the intra-cluster correlation (typically 0.01-0.05 for education/health outcomes).
- For DiD: power depends on the number of pre/post periods and the expected effect size relative to pre-treatment variation.
- Flag if the expected sample is too small for the chosen method.

**Fallback method:** After selecting the primary method, ask:
```
AskUserQuestion: "What is your fallback if the primary method proves infeasible? (e.g., if parallel trends don't hold for DiD, fall back to ITS)"
(Free text, optional)
```

**RCT ethics (if RCT selected):**
Address in the ethical considerations section:
- Clinical equipoise: is there genuine uncertainty about which option is better?
- Informed consent for randomisation
- Plan for control group: waitlist design, delayed treatment, alternative treatment, or business-as-usual
- Circumstances where randomisation is ethically inappropriate: emergency response, fundamental rights, existing legal entitlements
- Reference: Magenta Book Annex A, Section A1.1

**For mid-term/final evaluations:** ask what method was actually used:
```
AskUserQuestion: "What evaluation design was used?"
Options:
  - "RCT (randomised control trial)"
  - "Quasi-experimental (DiD, regression discontinuity, propensity score matching)"
  - "Comparison group (before-and-after with matched comparator)"
  - "Before-and-after with statistical controls (no comparison group)"
  - "Monitoring data only (no counterfactual)"
```

Assign the Maryland SMS level accordingly.

### Step 6: Section-by-section generation

Present the section picker based on evaluation type:

**For evaluation plans:**
```
AskUserQuestion: "Which sections do you want to include?"
multiSelect: true
Options:
  - "Programme background and objectives (required)"
  - "Theory of Change (required)"
  - "Evaluation questions (required)"
  - "Methodology and counterfactual design (required)"
  - "Data collection plan"
  - "Ethical considerations"
  - "Governance and independence"
  - "Timeline and milestones"
  - "Budget"
  - "Dissemination plan"
```

**For mid-term evaluations:**
```
AskUserQuestion: "Which sections do you want to include?"
multiSelect: true
Options:
  - "Executive summary (required)"
  - "Progress against milestones and KPIs (required)"
  - "Process findings (implementation fidelity, reach, quality)"
  - "Early outcome data"
  - "Theory of Change check (are assumptions holding?)"
  - "Emerging risks and unintended consequences"
  - "Recommendations for adaptation"
  - "Updated evaluation plan"
```

**For final evaluations:**
```
AskUserQuestion: "Which sections do you want to include?"
multiSelect: true
Options:
  - "Executive summary (required)"
  - "Programme description and context (required)"
  - "Theory of Change assessment (required)"
  - "Process evaluation (implementation, reach, quality)"
  - "Impact evaluation (outcomes, attribution, counterfactual)"
  - "Economic evaluation (invoke /vfm-eval: economy, efficiency, effectiveness)"
  - "Equity and distributional analysis"
  - "Sustainability assessment"
  - "Lessons learned and replicability"
  - "Recommendations"
  - "Methodology annex"
```

**For AU PIR:**
All 7 sections are required. No picker needed.

### Step 7: Generate each selected section

**EVALUATION PLAN sections:**

**7a. Programme background:**
```markdown
## Programme Background

[Programme name] is a [type] programme delivered by [organisation] from [start] to [end]. The total budget is [amount]. It targets [population] with the objective of [objectives].

The programme was established in response to [policy context / evidence of need]. It forms part of [broader strategy / departmental objective].
```

**7b. Theory of Change:**
Include the table from Step 3, plus a narrative explaining the causal logic.

**7c. Evaluation questions:**
Table of questions organised by process, impact, economic, with methods mapped to each.

**7d. Methodology:**
For each evaluation question, specify: method, data source, timing, and SMS level target.

Include the counterfactual design from Step 5 with full justification.

**7e. Data collection plan:**
```
Table N: Data Collection Plan

| Data | Source | Method | Timing | Responsibility | Baseline collected? |
|------|--------|--------|--------|----------------|---------------------|
```

**7f. Ethical considerations:**
- Informed consent requirements
- Data protection and GDPR/Privacy Act compliance
- Vulnerable populations safeguards
- For AU Indigenous programmes: alignment with Indigenous Evaluation Strategy and AIATSIS ethics guidelines

**7g. Governance:**
- Evaluation commissioner vs evaluation team (independence)
- Steering group composition
- Quality assurance (peer review, ETF engagement for UK)
- For UK: ETF Evaluation Registry requirements (mandatory from April 2024)

**7h. Timeline:**
```
Table N: Evaluation Timeline

| Milestone | Date | Deliverable |
|-----------|------|-------------|
| Baseline data collection | [date] | Baseline report |
| Mid-term evaluation | [date] | Mid-term report |
| Final data collection | [date] | Data report |
| Final evaluation | [date] | Final evaluation report |
| Dissemination | [date] | Summary, presentations |
```

**7i. Budget:**
```
Table N: Evaluation Budget

| Activity | Cost | % of programme budget |
|----------|------|----------------------|
| Baseline data collection | | |
| Mid-term evaluation | | |
| Final evaluation | | |
| External evaluator | | |
| Data analysis | | |
| Dissemination | | |
| TOTAL | | |
```

Note: International benchmarks suggest 3-10% of programme budget for evaluation (ILO: 5%, Kellogg Foundation: 5-10% for formative, 15-20% for summative). For UK, the ETF recommends proportionate spending.

**7j. Dissemination plan:**
- Who are the primary users of the evaluation?
- How will findings feed into decisions?
- Publication plan (GOV.UK, Evaluation Registry, academic)

---

**MID-TERM EVALUATION sections:**

**Progress against milestones:**
```
Table N: Progress Against Plan

| Milestone / KPI | Target | Actual | RAG | Notes |
|-----------------|--------|--------|-----|-------|
```

**Process findings:**
- Implementation fidelity: was it delivered as designed? What adaptations were made and why?
- Reach: how many of the target population participated? Who was excluded?
- Quality: participant satisfaction, delivery quality indicators
- Barriers and enablers: what helped/hindered delivery?

**Theory of Change check:**
Revisit each assumption from the ToC. For each: is the evidence supporting it, contradicting it, or inconclusive?

```
Table N: Theory of Change Check

| Assumption | Evidence | Status |
|------------|----------|--------|
| [assumption 1] | [what we've observed] | Holding / At risk / Not holding |
```

---

**FINAL EVALUATION sections:**

**Process evaluation:**
```markdown
## Process Evaluation

### Implementation Fidelity
[Was the programme delivered as designed? What adaptations were made?]

### Reach and Coverage
[Did the programme reach its target population? Coverage rate: X out of Y eligible.]

### Quality of Delivery
[Participant satisfaction, delivery quality metrics.]

### Barriers and Enablers
[What factors helped or hindered delivery?]

### Unintended Consequences
[Any positive or negative effects not anticipated in the Theory of Change.]
```

**Impact evaluation:**
```markdown
## Impact Evaluation

### Evidence Quality
This evaluation uses [method] to assess programme impact, corresponding to Maryland Scientific Methods Scale Level [N] ([description]).

[Justification for the method. Key assumptions. Limitations.]

### Headline Findings
[Key impact findings with effect sizes. Include confidence intervals where available.]

### Attribution Assessment
[What proportion of observed outcomes can be attributed to the programme vs other factors?]

### Subgroup Analysis
[Were there differential impacts by gender, age, geography, ethnicity, income?]
```

**Economic evaluation:**
If user selected this section, invoke `/vfm-eval`:
```
Invoke /vfm-eval with the programme data to generate:
- Economy assessment (cost benchmarking)
- Efficiency assessment (delivery rate)
- Effectiveness assessment (BCR, NPSV, fiscal return)
- Sensitivity analysis
```

Or, if `--with-vfm` was provided, import the VfM output.

**Equity and distributional analysis:**
```markdown
## Equity and Distributional Analysis

### Impact by Income Group
[Were benefits equitably distributed? Did the programme reduce or widen inequality?]

### Geographic Distribution
[Where were benefits concentrated? Urban vs rural? Deprived vs affluent areas?]

### Protected Characteristics
[Impact by gender, ethnicity, disability, age. Equality Act 2010 (UK) / anti-discrimination legislation (AU).]
```

For UK: reference Green Book Annex 3 distributional weights.

**Sustainability assessment:**
```markdown
## Sustainability

### Financial Sustainability
[Can the programme's benefits be maintained without continued public funding?]

### Institutional Sustainability
[Are the delivery structures, skills, and partnerships in place to sustain outcomes?]

### Behavioural Sustainability
[Will behaviour changes persist after the programme ends?]

### Environmental Sustainability
[Are there environmental benefits or costs that continue post-programme?]
```

For OECD DAC: this maps directly to the "Sustainability" criterion.

**Lessons learned:**
```markdown
## Lessons Learned

### What Worked
[Factors that contributed to success. Be specific about context.]

### What Didn't Work
[Factors that hindered outcomes. Be honest.]

### For Whom
[Which subgroups benefited most/least? In what circumstances?]

### Replicability
[Could this programme be replicated elsewhere? What conditions are needed?]

### Scalability
[Could it be scaled up? What would change at larger scale?]
```

**Recommendations:**
```markdown
## Recommendations

Based on this evaluation, we recommend:

1. [Continue / Expand / Redesign / Discontinue] the programme because [evidence-based rationale].
2. [Specific improvement based on process findings.]
3. [Evidence improvement: commission higher-quality impact evaluation if SMS < 3.]
4. [Policy implication: what should decision-makers take from this?]
```

---

**AU POST-IMPLEMENTATION REVIEW (7 sections, all mandatory):**

```markdown
## Post-Implementation Review

### 1. Problem Definition
Was the original problem correctly identified? Has the problem changed since implementation?

[Compare the problem as stated in the original RIS/IA with current evidence.]

### 2. Government Action Justification
Was government intervention necessary? Could the market or self-regulation have addressed the problem?

[Assess whether the rationale for intervention still holds.]

### 3. Policy Options Considered
Were alternatives properly assessed in the original impact analysis?

[Review whether the options analysis was adequate. Were better alternatives available?]

### 4. Policy Impacts
What were the actual costs and benefits compared to the original estimates?

| | Original estimate | Actual | Difference |
|---|---|---|---|
| Total cost | | | |
| Total benefit | | | |
| Net benefit | | | |
| Businesses affected | | | |
| Compliance cost per business | | | |

[Distributional impacts. Unintended consequences.]

### 5. Stakeholder Consultation
Was consultation adequate during development? What do stakeholders say now?

[Review of original consultation process. Current stakeholder views.]

### 6. Net Benefit Assessment
Has the regulation delivered a net community benefit?

[Evidence-based assessment. If costs exceed benefits, recommend reform or repeal.]

### 7. Implementation and Evaluation
What lessons have been learned? Are monitoring mechanisms adequate?

[Implementation experience. Data collection. Ongoing effectiveness.]
```

Timing: 2 years (if IA was missing/insufficient) or 5 years (if substantial economic impact).

---

**EVALUATION SYNTHESIS / META-EVALUATION:**

For portfolio-level assessment across multiple evaluations.

```markdown
## Evaluation Synthesis

### 1. Scope and Methodology
[How many evaluations were reviewed? What search strategy was used? What quality criteria were applied for inclusion?]

### 2. Quality Assessment
[Grade each included evaluation using SMS levels and/or NESTA standards.]

Table N: Quality of Included Evaluations

| Evaluation | Programme | SMS Level | Method | Key finding | Quality notes |
|------------|-----------|-----------|--------|-------------|---------------|

### 3. Synthesis of Findings
[What do the evaluations collectively tell us? Identify consistent findings, contradictory evidence, and effect sizes across studies.]

### 4. Common Themes
[Cross-cutting patterns: what implementation factors predict success? what programme characteristics are associated with larger effects?]

### 5. Evidence Gaps
[What questions remain unanswered? Where is the evidence base weak? What types of evaluations are needed?]

### 6. Implications for Policy
[Based on the body of evidence, what should decision-makers do? What confidence level for each recommendation?]

### 7. Implications for Future Evaluation
[What evaluation methods should be prioritised? Where should evaluation investment focus?]
```

---

### Step 8: Quality checks

Run cross-section consistency checks:
1. Do evaluation questions in the methodology section match the questions listed in the evaluation questions section?
2. Does the data collection plan cover all data needed for the specified methods?
3. Is the evaluation budget proportionate to the programme budget?
4. Does the Theory of Change include testable assumptions at every link?
5. For final evaluations: does the evidence quality rating (SMS level) match the method described?
6. For final evaluations: do the recommendations follow from the findings?

### Step 9: Executive summary

Generate a 1-page executive summary:

For evaluation plans:
- Programme and evaluation objectives
- Planned methodology and evidence standard target
- Timeline and budget
- Key risks to evaluation delivery

For mid-term evaluations:
- Progress RAG assessment
- Key process findings
- Early outcome signals
- Recommended adaptations

For final evaluations:
- Headline impact findings
- Evidence quality (SMS level)
- VfM assessment (BCR if available)
- Key lessons
- Recommendation (continue/expand/redesign/discontinue)

For AU PIR:
- Has the regulation delivered net community benefit? (Yes/No/Mixed)
- Actual vs estimated costs and benefits
- Recommendation (retain/reform/repeal)

### Step 10: Output

Save as `eval-{type}-{slugified-programme}-{date}.md`.

Add KEY NUMBERS block:
```markdown
<!-- KEY NUMBERS
type: evaluation
eval_type: [plan/midterm/final/pir/synthesis]
framework: [uk/au/au-vic/au-nsw/au-qld/dac/nesta/us]
programme: [name]
programme_budget: [value]
evaluation_budget_pct: [value]
counterfactual_method: [rct/did/rdd/psm/its/sc/contribution/realist/monitoring]
sms_level: [1-5, target for plans, actual for finals]
bcr: [value, if economic eval included]
n_participants: [value]
recommendation: [continue/expand/redesign/discontinue]
date: [date]
-->
```

Generate companion JSON with this schema:
```json
{
  "programme": {"name": "", "budget": 0, "duration": "", "target_population": ""},
  "evaluation": {"type": "", "framework": "", "sms_level": 0, "method": ""},
  "theory_of_change": [{"level": "", "description": "", "assumptions": "", "evidence": ""}],
  "evaluation_questions": {"process": [""], "impact": [""], "economic": [""]},
  "findings": {"process": "", "impact": "", "economic": {"bcr": 0, "npsv": 0}},
  "recommendations": [""],
  "metadata": {"generated": "", "evaluator": "", "framework_version": ""}
}
```

**References (include in every evaluation output):**

For UK framework:
```markdown
## References

- HM Treasury (2020, updated 2025). "The Magenta Book: Central Government Guidance on Evaluation."
- HM Treasury (2022, updated 2026). "The Green Book: Central Government Guidance on Appraisal and Evaluation."
- Evaluation Task Force (2022). "ETF Strategy 2022-2025."
- What Works Centre for Local Economic Growth. "Maryland Scientific Methods Scale Guide."
- Bloom, H. (2006). "The Core Analytics of Randomized Experiments for Social Research." MDRC Working Paper.
- Pawson, R. and Tilley, N. (1997). "Realistic Evaluation." Sage.
```

For AU framework:
```markdown
## References

- Australian Centre for Evaluation (2023). "Commonwealth Evaluation Policy."
- Office of Impact Analysis (2023). "Post-Implementation Review Guidance."
- Productivity Commission (2023). "Indigenous Evaluation Strategy."
- Victorian DTF (2025). "Investment Lifecycle and HVHR Guidelines."
- NSW Treasury (2016, updated). "NSW Government Program Evaluation Guidelines."
```

For OECD DAC:
```markdown
## References

- OECD DAC Network on Development Evaluation (2019). "Better Criteria for Better Evaluation."
- OECD (2021). "Applying Evaluation Criteria Thoughtfully."
```

For NESTA:
```markdown
## References

- NESTA (2013). "Standards of Evidence: An Approach that Balances the Need for Evidence with Innovation."
```

If `--format` specified, invoke export skills. If `--audit`, run `/econ-audit`.

## OECD DAC Framework (when --framework dac)

Structure the evaluation around the 6 criteria (2019 revision):

1. **Relevance**: Do the objectives respond to beneficiary and country needs?
2. **Coherence**: Is it compatible with other interventions? (Internal coherence: synergies within. External coherence: consistency with other actors.)
3. **Effectiveness**: Did it achieve its objectives? Differential results across groups?
4. **Efficiency**: Were results delivered in an economic and timely way?
5. **Impact**: Significant positive or negative, intended or unintended higher-level effects?
6. **Sustainability**: Will net benefits continue?

Not all 6 criteria must be used in every evaluation. Select those most relevant to the programme. Equity and environmental effects should be considered across all criteria.

## Victorian DTF Framework (when --framework au-vic)

For HVHR projects: align evaluation with the Gateway review process. Gate 6 (Benefits Realisation) occurs 6-18 months after project completion. Gate 6 evaluation reports must be released to DTF. All red/amber recommendations must be reported to the Treasurer with an action plan.

For lapsing programmes (seeking additional Budget funding): evaluation evidence is required. Programmes over AUD 20 million must commission external evaluation. Align evaluation timeline with the Victorian Budget cycle. Use DTF programme evaluation templates where available.

## US Evidence Act Framework (when --framework us)

The Foundations for Evidence-Based Policymaking Act (2018) requires federal agencies to:
1. Develop **Learning Agendas** (multi-year strategic plans for evidence building)
2. Produce **Annual Evaluation Plans** (specific evaluations planned for the year)
3. Designate an **Evaluation Officer** (senior official responsible for evaluation)
4. Maintain an **evidence-building capacity assessment**

Follow OMB Memorandum M-21-27 evaluation standards: relevance and utility, rigor, independence and objectivity, transparency, ethics. For detailed US federal evaluation templates, refer to the OMB Evidence Team guidance and agency-specific Learning Agendas.

## NESTA Standards (when --framework nesta)

Map evaluation evidence to the 5 NESTA levels:

| Level | What it shows | Typical methods |
|---|---|---|
| 1 | Logical reason why it could work | Theory of Change, logic model |
| 2 | Some positive change among participants | Pre/post surveys, cohort tracking |
| 3 | Causing the impact (less impact among non-participants) | RCT, quasi-experimental with control group |
| 4 | Why and how it works, independently validated, reasonable cost | Multiple replication evaluations, fidelity studies |
| 5 | Can be operated by others at scale with continued positive impact | Manualised delivery, independent replication at multiple sites |

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
- An evaluation is not advocacy. It reports what happened, honestly, including failures and unintended consequences. If the programme did not achieve its objectives, say so clearly.
- Evidence quality (SMS level) must always be stated alongside impact findings. A high impact estimate with Level 1 evidence is not the same as a modest estimate with Level 4 evidence.
- The Theory of Change is not decoration. For final evaluations, every assumption must be tested against evidence.
- Process evaluation is not optional in a full evaluation. Understanding WHY outcomes occurred (or didn't) is as important as measuring WHAT happened.
- For evaluation plans: the counterfactual method must be specified before the programme starts, not retrofitted after. Baseline data collection is time-critical.
- Recommendations must follow from the evidence. "Continue the programme" is not justified by "stakeholders liked it" if the impact evaluation shows no effect.
- For AU PIR: the 7 sections are mandatory. Do not skip any.
- The evaluation skill does NOT perform statistical analysis (regressions, matching, etc.). It structures the evaluation document and specifies the methods. For actual statistical analysis, use R/Stata. The planned `causalkit` R package will handle DiD, RDD, IV, and synthetic control estimation.
