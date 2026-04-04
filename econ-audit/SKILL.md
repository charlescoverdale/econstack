---
name: econ-audit
description: Audit economic analysis outputs (CBA, impact assessments, fiscal briefings) against methodology standards, academic literature, and common errors. Returns a scorecard with issues ranked by severity.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
  - WebSearch
---

<!-- preamble: update check -->
Before starting, run this silently. If it outputs UPDATE_AVAILABLE, tell the user:
"A new version of econstack is available. Run `cd ~/.claude/skills/econstack && git pull` to update."
Then continue with the skill normally.

```bash
~/.claude/skills/econstack/bin/econstack-update-check 2>/dev/null || true
```

# /econ-audit: Economic Analysis Audit

Audit any economic analysis output against methodology standards, academic literature, and practitioner best practice. Works on CBA reports, impact assessments, fiscal briefings, or any document making economic claims with numbers.

This is the "second pair of eyes" that catches errors a reviewer would flag. It checks the numbers, the methodology, the assumptions, and the framing.

**This skill is interactive.** It reads your document, runs the audit, presents the scorecard, then asks if you want fixes applied.

## Arguments

```
/econ-audit [file_or_path] [options]
```

**Examples:**
```
/econ-audit cba-london-bridge-2026-04-03.md
/econ-audit io-report-southwark-2026-04-03.md
/econ-audit .                                       # audit all econ outputs in cwd
/econ-audit --strict                                 # fail on any amber issue
```

**Options:**
- `--strict` : Treat amber issues as failures (default: only red issues fail)
- `--fix` : Auto-fix issues where possible (rewrites the file)
- `--json` : Output the audit as structured JSON
- `--framework <name>` : Override framework detection (uk, eu, us, wb, au, nz)
- `--format <type>` : Output format(s): `markdown`, `html`, `word`, `pptx`, `pdf`, or `all`. Comma-separate for multiple (e.g. `--format html,pdf`). Default: markdown only

## Instructions

### Step 1: Detect what's being audited

Read the file(s) specified. Detect the document type from content:

| Pattern | Type | Primary standards |
|---------|------|-------------------|
| NPV, BCR, discount rate, appraisal period | CBA | Green Book / EU Guide / OMB A-4 |
| Output multiplier, employment multiplier, IO model | Impact assessment | ONS IOAT, Flegg et al., HMT Additionality |
| Borrowing, debt, receipts, PSNB | Fiscal briefing | OBR methodology, fiscal rules |
| GDP, inflation, unemployment, CPI | Macro briefing | ONS methodology, data quality standards |
| Yield curve, duration, convexity | Financial analysis | Fixed income conventions |

Also look for the hidden `<!-- KEY NUMBERS -->` block or companion JSON file. If found, parse it for structured data to cross-check against the prose.

Tell the user: "Auditing [filename] as a [type]. Framework detected: [framework]."

### Step 2: Run the audit checklist

Run every applicable check from the master checklist below. Each check produces one of:

- **GREEN**: Pass. No issue.
- **AMBER**: Warning. Technically defensible but a reviewer might challenge. Or: a missed opportunity to strengthen the analysis.
- **RED**: Error. Methodologically wrong, inconsistent, or misleading. Must fix.

#### A. Numerical consistency checks

| # | Check | Severity if failed |
|---|-------|--------------------|
| A1 | Do all numbers in the executive summary match the tables? | RED |
| A2 | Does PV costs + PV benefits = correct NPV? (recompute) | RED |
| A3 | Does BCR = PV benefits / PV costs? (recompute) | RED |
| A4 | Do undiscounted totals match the sum of year-by-year figures? | RED |
| A5 | Is the VfM category consistent with the BCR value? | RED |
| A6 | Do switching values, when applied, actually produce NPV = 0? (recompute) | RED |
| A7 | Are sensitivity scenario numbers consistent with the stated +/-% variation? | RED |
| A8 | If a companion JSON exists, do all numbers match between markdown and JSON? | RED |
| A9 | Are percentage changes correctly computed (not confused with percentage point changes)? | RED |
| A10 | Are all currency figures in the stated price base year? | AMBER |

#### B. Discount rate and time horizon

| # | Check | Severity if failed |
|---|-------|--------------------|
| B1 | Is the discount rate correct for the stated framework? | RED |
| B2 | For UK Green Book: is the declining schedule applied correctly after year 30? (not flat 3.5%) | RED |
| B3 | For UK Green Book: are discount factors computed cumulatively (not by applying lower rate from year 0)? | RED |
| B4 | Is the appraisal period appropriate for the asset type / project? | AMBER |
| B5 | Is the price base year stated? | AMBER |
| B6 | Are costs in real terms (not nominal)? Or if nominal, is deflation documented? | AMBER |
| B7 | For projects > 30 years: does the report acknowledge the declining rate schedule? | AMBER |

#### C. Optimism bias and risk

| # | Check | Severity if failed |
|---|-------|--------------------|
| C1 | For UK infrastructure: is optimism bias applied? (must not be 0% without justification) | RED |
| C2 | Is the optimism bias rate appropriate for the project type AND stage? | AMBER |
| C3 | Is optimism bias applied to capex but not opex (unless justified)? | AMBER |
| C4 | Is Monte Carlo / probabilistic analysis included for projects > £100m PV? | AMBER |
| C5 | Are switching values computed and interpreted correctly? (direction must match NPV sign) | RED |
| C6 | Does the sensitivity analysis cover a meaningful range (not just +/-5%)? | AMBER |
| C7 | Are residual values unreasonably high? (flag if residual > 15% of capex for assets with 60+ year appraisal periods; > 20% for shorter periods) | AMBER |

#### D. Additionality

| # | Check | Severity if failed |
|---|-------|--------------------|
| D1 | Are additionality adjustments applied (deadweight, displacement, leakage)? | AMBER |
| D2 | Are the rates cited with a source (HMT Additionality Guide, MHCLG, etc.)? | AMBER |
| D3 | Are the rates plausible for the project type? (e.g., displacement > 50% for retail) | AMBER |
| D4 | Is the net additionality factor correctly computed? (product of (1-d)(1-disp)(1-l)(1-s)) | RED |
| D5 | Are carbon benefits excluded from additionality adjustments? (they should be) | AMBER |

#### E. Double counting and transfers

| # | Check | Severity if failed |
|---|-------|--------------------|
| E1 | Are any benefits counted twice? (e.g., journey time savings AND land value uplift derived from them) | RED |
| E2 | Are taxes, subsidies, or grants included as costs/benefits in a social CBA? (they should not be, as they are transfers) | RED |
| E3 | If both economic AND financial analysis are presented, are transfers handled differently in each? | AMBER |
| E4 | Are wider economic impacts (agglomeration, labour supply) presented separately from core benefits? | AMBER |
| E5 | Is there clear separation between gross and net figures throughout? | AMBER |
| E6 | Are sunk costs included? (costs already incurred that cannot be recovered should be excluded from the appraisal) | RED |
| E7 | Is the counterfactual (Do Nothing) static? (it should evolve over time to reflect deterioration, demand growth, committed policies, not be fixed at the current state) | AMBER |

#### F. Multiplier and IO model checks (impact assessments)

| # | Check | Severity if failed |
|---|-------|--------------------|
| F1 | Is the multiplier type stated (Type I vs Type II)? | AMBER |
| F2 | Is Type II used without justification? (Type I is more conservative and defensible) | AMBER |
| F3 | Is the multiplier plausible for the sector and area? (Type I typically 1.0-1.8; flag if > 2.0) | RED |
| F4 | Is the regionalization method stated (FLQ, CILQ, SLQ, etc.)? | AMBER |
| F5 | Are employment multipliers consistent with output multipliers? | AMBER |
| F6 | Is the data source and year stated? | AMBER |
| F7 | Are the results described as "indicative upper bounds" or similar caveat? | AMBER |
| F8 | Does the report acknowledge fixed input proportions / no substitution? | AMBER |

#### G. Framing and interpretation

| # | Check | Severity if failed |
|---|-------|--------------------|
| G1 | Is NPV presented as the primary metric (not BCR)? (Green Book is explicit about this) | AMBER |
| G2 | Are non-monetised benefits described with direction and magnitude? | AMBER |
| G3 | Is the counterfactual (Do Nothing) properly specified? (not static baseline) | AMBER |
| G4 | Are caveats and limitations clearly stated? | AMBER |
| G5 | Is the analysis described as "indicative" or "estimates" (not "will create X jobs")? | AMBER |
| G6 | Are switching value interpretations correct for the NPV sign? | RED |
| G7 | For negative NPV: does the report explain what would need to change (not just state "Poor VfM")? | AMBER |
| G8 | Are incremental costs/benefits shown when comparing 3+ options? | AMBER |
| G9 | Is the methodology section sufficient for a reviewer to replicate the analysis? | AMBER |
| G10 | Are references provided to the framework and supplementary guidance used? | AMBER |
| G11 | Are all benefits independent? (flag if benefit B depends on benefit A materialising first, creating a dependency chain that inflates total benefits) | AMBER |
| G12 | Are real and nominal values mixed in the same table or computation? (all values must be in consistent price terms) | RED |

#### H. Sector-specific checks

**Transport:**
| # | Check | Severity if failed |
|---|-------|--------------------|
| H1 | Are TAG values used for time savings, VOC, accident reduction? | AMBER |
| H2 | Is the value of time split by trip purpose (work/commute/leisure)? | AMBER |
| H3 | Are induced traffic effects acknowledged? | AMBER |
| H4 | Is benefit ramp-up applied (not instant full benefits post-construction)? | AMBER |

**Health:**
| # | Check | Severity if failed |
|---|-------|--------------------|
| H5 | Are QALYs/DALYs valued at the correct framework-specific rate? | AMBER |
| H6 | Is the QALY/DALY value source cited? | AMBER |

**Environment/carbon:**
| # | Check | Severity if failed |
|---|-------|--------------------|
| H7 | Is the carbon price from the correct source for the framework? | AMBER |
| H8 | Does the carbon price increase over time (not flat)? | AMBER |
| H9 | Are embodied construction emissions included alongside operational savings? | AMBER |

#### I. Academic and empirical checks

| # | Check | Severity if failed |
|---|-------|--------------------|
| I1 | Reference Class Forecasting: are the cost estimates consistent with the empirical distribution of cost overruns for this project type? (Flyvbjerg et al. 2003 found average overrun of 28% for roads, 45% for rail, 20% for buildings) | AMBER |
| I2 | Multiplier plausibility: is the employment multiplier consistent with the range found in the academic literature? (Moretti 2010 finds local multipliers of 1.5-2.5 for tradeable sectors) | AMBER |
| I3 | Benefit optimism: are benefit estimates consistent with ex-post evaluations of similar projects? (Flyvbjerg 2005 found benefits overestimated by 50% on average for transport) | AMBER |
| I4 | Discount rate justification: does the chosen rate align with the Ramsey formula parameters for the relevant economy? | AMBER |
| I5 | Does the analysis acknowledge key empirical findings relevant to the project type (e.g., Crompton 1995 on sports facility overestimation, Venables 2007 on agglomeration)? | AMBER |
| I6 | For residual values: is the assumed remaining asset life consistent with engineering benchmarks for this asset type? (e.g., bridges 100-120 years, buildings 60 years, IT systems 5-10 years) | AMBER |

#### J. Data quality and interpretation (macro briefings)

| # | Check | Severity if failed |
|---|-------|--------------------|
| J1 | Is the data freshness stated? (date of latest data point for each indicator must be visible) | AMBER |
| J2 | Are seasonal adjustments consistently applied? (do not mix SA and NSA series in comparisons) | RED |
| J3 | Is the unemployment rate the ILO measure (not claimant count)? These are different concepts. | AMBER |
| J4 | Is CPI or CPIH specified? (ONS lead measure is now CPIH; if using CPI, note the distinction) | AMBER |
| J5 | Are real wages correctly computed? (nominal wage growth minus CPI inflation, not divided by CPI) | RED |
| J6 | Is the GDP measure specified? (quarterly growth, annual growth, or level; q/q and y/y must not be confused) | AMBER |
| J7 | Are labour market figures described as 3-month rolling averages (not point-in-time monthly data)? | AMBER |
| J8 | Are comparisons like-for-like? (q/q compared to q/q, not q/q compared to y/y) | RED |
| J9 | Are pre-pandemic comparisons dated? (specify which quarter/year, not just "pre-pandemic levels") | AMBER |
| J10 | Are forward-looking statements clearly attributed? (BoE, OBR, market expectations; not presented as fact) | AMBER |

### Step 3: Present the scorecard

```
ECONOMIC AUDIT: [filename]
===========================
Type:      [CBA / Impact Assessment / Fiscal Briefing / etc.]
Framework: [UK Green Book / EU / US OMB / etc.]
Date:      [date]

SCORECARD
---------
Category                    RED   AMBER   GREEN   Score
A. Numerical consistency     0      1       9     9/10
B. Discount rate & horizon   0      0       7     7/7
C. Optimism bias & risk      1      2       4     4/7
D. Additionality             0      1       4     4/5
E. Double counting           0      0       7     7/7
F. Multiplier/IO model       -      -       -     n/a
G. Framing & interpretation  0      3       9     9/12
H. Sector-specific           0      1       3     3/4
I. Academic/empirical        0      2       4     4/6
J. Data quality (macro)      0      0      10    10/10
-------------------------------------------------
OVERALL                      1     10      57    57/68

GRADE: [A / B / C / D / F]
  A (90%+):  Publication-ready. Minor improvements possible.
  B (75-89%): Strong analysis. Address amber issues before submission.
  C (60-74%): Adequate but has gaps. Needs revision.
  D (40-59%): Significant issues. Major revision required.
  F (<40%):   Fundamental errors. Redo the analysis.

Grade capping rules (override the mechanical percentage):
- If 1-2 RED issues exist: grade is capped at C (regardless of overall %).
- If 3-4 RED issues exist: grade is capped at D.
- If 5+ RED issues exist: grade is F.

A single RED error (e.g., wrong discount rate applied to all 60 years) is a
fundamental methodological failure. It should not be masked by passing all
other checks. These caps ensure the grade reflects the severity of issues,
not just their quantity.

Note: Category F applies only to impact assessments. Category J applies only
to macro briefings. Categories not applicable to the document type are marked
n/a and excluded from the score calculation.
```

Then list each non-GREEN issue:

```
RED ISSUES (must fix)
---------------------
[C1] Optimism bias is 0% on a UK infrastructure project.
     The Green Book requires optimism bias for all infrastructure. At OBC
     stage for standard civil engineering, apply 20%.
     FIX: Multiply capital costs by 1.20. This will change PV costs,
     NPV, BCR, and switching values.
     REF: Green Book Supplementary Guidance: Optimism Bias (Table 1)

AMBER ISSUES (should address)
-----------------------------
[G3] The Do Nothing counterfactual is described as static.
     The Green Book requires the counterfactual to project forward
     including existing trends. For a bridge, this means modelling
     growing congestion, deterioration costs, and committed policies.
     SUGGESTION: Add 1-2 sentences describing what happens without
     intervention over the appraisal period.
     REF: Green Book (2022) Chapter 5, para 5.8

[I1] Capital cost estimates are at risk of Reference Class Forecasting bias.
     Flyvbjerg et al. (2003) found average cost overruns of 28% for road
     projects and 45% for rail. Your 44% optimism bias partially addresses
     this, but consider whether the base estimate already includes some
     risk contingency (if so, there may be double-counting of risk).
     REF: Flyvbjerg, B. (2003). "Megaprojects and Risk." Cambridge UP.
```

### Step 4: Ask what the user wants to do

Ask using AskUserQuestion (two questions):

**Question 1:** "What would you like to do with the audit results?"

Options:
- A) **Apply fixes** : Fix all RED issues and as many AMBER issues as possible in the source file
- B) **Fix RED only** : Fix only the critical errors, leave AMBER as notes
- C) **Save audit report** : Save the scorecard and issue list as a separate file
- D) **Just the scorecard** : I've seen enough, thanks

**Question 2 (if A, B, or C):** "What file formats do you need for the audit report?"

If `--format` was NOT specified on the command line, ask using AskUserQuestion:

Options (multiSelect: true):
- Markdown (.md) : Default, always included. Plain text scorecard and issue list
- HTML : Branded single-page report with colour-coded scorecard (red/amber/green), ready to open in browser or email
- Word (.docx) : Formatted audit report for editing in Microsoft Word
- PowerPoint (.pptx) : Summary slide deck with scorecard, key issues, and recommendations
- PDF : Branded consulting-quality PDF via Quarto

If `--format` was specified, skip the format question and use the specified format(s). If `--format all`, expand to `["markdown", "html", "word", "pptx", "pdf"]`.

Markdown is always generated regardless of selection.

If A or B:
- For each fixable issue, edit the source file directly.
- Recompute any affected numbers (NPV, BCR, switching values, sensitivity) after fixing.
- After fixing, re-run the audit to confirm all RED issues are resolved.
- Save a diff summary showing what changed.

### Step 5: Save and generate formats

Always save the markdown audit report: `audit-{source-filename}-{date}.md`
If `--json` specified, also save: `audit-{source-filename}-{date}.json`

**Then generate each additional format the user selected:**

**Markdown** (always generated):
Save as `audit-{source-filename}-{date}.md`. This is the primary output.

**HTML** (if selected):
Generate a self-contained HTML file with inline CSS. Use a traffic-light colour scheme:
- RED issues: red background (#FFCCCC) with red border (#CC0000)
- AMBER issues: amber background (#FFF3CD) with amber border (#CC8800)
- GREEN checks: green text (#006100)
- Scorecard table with colour-coded cells
- Grade displayed prominently with appropriate colour
- KPI summary bar at the top (total checks, RED count, AMBER count, grade)
The HTML must be fully self-contained (no external CSS/JS) so it can be emailed or opened offline.
Save as `audit-{source-filename}-{date}.html`.

**Word (.docx)** (if selected):
Invoke the `/docx` skill to create a formatted Word document. Instruct the skill to:
- Use a professional layout with colour-coded issue severity (red/amber headings)
- Format the scorecard as a table with coloured cells
- Include a cover page with "Economic Audit Report", the source filename, date, and grade
- Structure: Executive summary (grade + key findings), Scorecard table, RED issues, AMBER issues, Recommendations, References
Save as `audit-{source-filename}-{date}.docx`.

**PowerPoint (.pptx)** (if selected):
Invoke the `/pptx` skill to create a summary slide deck:
1. Title slide: "Economic Audit Report" with source filename, date, grade
2. Scorecard slide: the full category table with colour-coded scores
3. RED issues slide: one slide per RED issue (or combined if few), with issue, fix, and reference
4. AMBER highlights slide: top 3-5 most impactful AMBER issues
5. Recommendations slide: prioritised action list
6. Methodology slide: brief note on audit checklist and sources
Use red (#CC0000) for RED issue headers, amber (#CC8800) for AMBER, green (#006100) for pass indicators.
Save as `audit-{source-filename}-{date}.pptx`.

**PDF** (if selected):
Render the markdown through the EconStack template:
```bash
ECONSTACK_DIR="${CLAUDE_SKILL_DIR}/../.."
"$ECONSTACK_DIR/scripts/render-report.sh" audit-{source-filename}-{date}.md \
  --title "Economic Audit Report" \
  --subtitle "[source filename] | Grade: [grade]"
```
If Quarto is not installed, tell the user: "PDF rendering requires Quarto (https://quarto.org). The markdown report has been saved."

Tell the user what was generated, listing only the files that were actually produced:
```
Files saved:
  audit-{filename}-{date}.md     (scorecard and issues)
  audit-{filename}-{date}.json   (if --json specified)
  audit-{filename}-{date}.html   (if HTML selected)
  audit-{filename}-{date}.docx   (if Word selected)
  audit-{filename}-{date}.pptx   (if PowerPoint selected)
  audit-{filename}-{date}.pdf    (if PDF selected)
  [source file]                   (if fixes applied)
```

## Key References for Audit Checks

The audit draws on these sources. Cite them when flagging issues:

**Frameworks:**
- HM Treasury (2022, updated 2026). "The Green Book."
- HM Treasury (2014). "Additionality Guide", 4th edition.
- DLUHC (2025). "The Appraisal Guide", 3rd edition.
- DfT. "Transport Analysis Guidance (TAG) Data Book."
- DESNZ (2024). "Valuation of greenhouse gas emissions."
- European Commission (2014). "Guide to Cost-Benefit Analysis."
- OMB (2023). "Circular A-4: Regulatory Analysis."

**Academic (cost overruns and benefit optimism):**
- Flyvbjerg, B., Bruzelius, N., Rothengatter, W. (2003). "Megaprojects and Risk: An Anatomy of Ambition." Cambridge University Press.
- Flyvbjerg, B. (2005). "Measuring inaccuracy in travel demand forecasting." Transport Reviews, 25(5).
- Flyvbjerg, B. (2006). "From Nobel Prize to project management: Getting risks right." Project Management Journal, 37(3).
- Kahneman, D. and Tversky, A. (1979). "Prospect Theory: An Analysis of Decision under Risk." Econometrica, 47(2).

**Academic (multipliers and local economic impacts):**
- Flegg, A.T. et al. (1995). "On the Appropriate Use of Location Quotients." Regional Studies, 29(6).
- Moretti, E. (2010). "Local Multipliers." American Economic Review: Papers & Proceedings, 100(2).
- Crompton, J.L. (1995). "Economic Impact Analysis of Sports Facilities and Events." Journal of Sport Management, 9(1).

**Academic (discounting):**
- Ramsey, F.P. (1928). "A Mathematical Theory of Saving." Economic Journal, 38(152).
- Stern, N. (2007). "The Economics of Climate Change." Cambridge University Press.
- Weitzman, M.L. (2001). "Gamma Discounting." American Economic Review, 91(1).

**Academic (wider economic impacts):**
- Venables, A.J. (2007). "Evaluating Urban Transport Improvements." Journal of Transport Economics and Policy, 41(2).
- Graham, D.J. (2007). "Agglomeration, Productivity, and Transport Investment." Journal of Transport Economics and Policy, 41(3).

## Important Rules

- Never use em dashes.
- Never attribute econstack to any individual.
- Every issue must cite a specific source (framework document, academic paper, or empirical finding).
- RED issues must include a concrete fix instruction, not just "this is wrong."
- AMBER issues must include a specific suggestion, not just "consider reviewing."
- The audit must be reproducible: another economist should reach the same conclusions given the same checklist.
- Do not invent issues that are not supported by the checklist. If the analysis is good, say so.
- Cross-check every number you can. Recompute NPV, BCR, and switching values independently and compare.
- If a companion JSON file exists, verify every number in the prose against the JSON. Mismatches between prose and data are RED.
- Be precise about which academic finding supports each flag. Do not vaguely cite "the literature."
- The grade is mechanical (% of checks that pass) with RED caps applied. If any RED issues exist, the grade is capped at C regardless of overall percentage. If 3+ RED issues exist, capped at D. If 5+ RED, grade is F. Do not override with subjective judgment beyond these caps.
- If the document type is not recognized, tell the user and ask what type of analysis it is.
- If the document references hardcoded values (TAG rates, carbon prices, QALY values, median incomes), check their vintage. Flag as AMBER if more than 12 months old with: "[Value] dated [year] may be outdated. Verify against latest [source]."
