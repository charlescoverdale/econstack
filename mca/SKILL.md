---
name: mca
description: Multi-criteria analysis. Produces one scoring matrix, one ranked verdict, and a sensitivity note. Supports the five econstack frameworks (uk-gb, eu-brg, wb, adb, au-vic) and a --rigorous flag for Green Book MCDA (0-100 scale, swing weighting).
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - AskUserQuestion
  - Skill
---

**Only stop to ask the user when:** the problem description is missing, or there are fewer than 2 options to compare.
**Never stop to ask about:** sector detection, criterion wording, scoring scale, weighting method, output filename, or formatting. Pick sensible defaults.

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

# /mca: Multi-Criteria Analysis

Options appraisal skill. Produces a single scoring matrix, a ranked verdict, and a one-paragraph sensitivity note. For first-time users, the default output is the whole deliverable: no optional sections, no menus, no JSON companion.

```
/mca            = "Rank my options against several criteria"
     ↓
/cost-benefit   = "Now monetise the top-ranked option"
```

The output is one table and one paragraph. That is the whole skill.

## Arguments

```
/mca [problem description] [options]
```

**Examples:**
```
/mca "Choose between 3 sites for a new hospital in Leeds"
/mca "Compare 4 regulatory options for online safety" --rigorous
/mca "5 renewable energy technologies for a rural council" --framework wb
/mca --from decision.md
```

**Options:**
- `--framework <name>` : `uk-gb` (default), `eu-brg`, `wb`, `adb`, or `au-vic`. Auto-detected from context if not set.
- `--rigorous` : Switch to Green Book MCDA defaults: 0-100 scoring, swing weighting, explicit value-function anchors. Use for formal government business cases at the longlist stage.
- `--weights <spec>` : Override equal-weight default. Format: `"criterion1:20,criterion2:30,..."` (any format summing to 100).
- `--scale 3|5|7|100` : Override 1-5 default scale. `100` forces the rigorous anchor-based form.
- `--from <file.md>` : Import problem, options, criteria, weights, and scores from a markdown file.
- `--section <name>` : Emit only one sub-component instead of the full deliverable. Options: `full` (default), `matrix` (scoring table only), `verdict` (headline only), `sensitivity` (sensitivity paragraph only), `cost` (cost comparison table only). Combinable with commas: `--section matrix,cost`.
- `--format <type>` : Output format(s). Options: `markdown` (default, always generated), `xlsx`, `word`, `pptx`, `pdf`, or `all`. Comma-separate for multiple: `--format markdown,xlsx,pptx`.

## Supported frameworks

| Flag | Framework | Scoring convention | Weighting convention |
|------|-----------|--------------------|----------------------|
| `uk-gb` | UK HM Treasury Green Book (default) | 1-5 (MCA) or 0-100 (MCDA with `--rigorous`) | Equal default; swing weighting under `--rigorous` |
| `eu-brg` | EU Better Regulation Guidelines | Qualitative scale aligned to impact direction (+++ / ++ / + / 0 / - / -- / ---), translated to 1-7 internally | Equal default |
| `wb` | World Bank Economic Analysis | 1-5 with explicit beneficiary lens | Equal default; distributional weights optional |
| `adb` | ADB Guidelines for Economic Analysis | 1-5 with explicit poverty and gender lens | Equal default |
| `au-vic` | Victorian Treasury HVHR | 1-5 aligned to Investment Logic Map benefit hierarchy | Equal default; Decision Conference style under `--rigorous` |

**Auto-detection rules:**
- "HVHR", "Investment Logic Map", "Victorian", "Melbourne", AUD → `au-vic`
- "ADB", "Asian Development Bank", DMC country → `adb`
- "World Bank", "IBRD", "IDA" → `wb`
- "regulation", "RIA", "compliance cost", EU context → `eu-brg`
- Everything else → `uk-gb`

## Instructions

### Step 1: Get the problem and options

Ask in ONE `AskUserQuestion` batch (not several). If the command-line argument already contains a problem description, skip to parsing.

**Required inputs:**
1. **Problem**: one or two sentences describing the decision and what matters. Free text.
2. **Options**: the alternatives being compared. Free text, can be comma-separated or bullet list. If fewer than 2 options are provided, ask once for more.

Do NOT ask sector, scale, weighting method, number of criteria, rigour level, format, filename, or anything else. Detect sector from the problem description. Default everything else.

### Step 2: Generate criteria and descriptors (silent)

Walk through these internally. Do not show stakeholder lists, lens-by-lens working, or sector templates in the output.

1. **Detect the sector** from the problem description (infrastructure, policy, technology, site selection, regulatory, education, health, transport, etc.).
2. **Generate 5-7 criteria** covering at least these 4 standard dimensions: strategic, economic, social and environmental, deliverability. Add a 5th dimension (e.g. poverty/equity for `wb` / `adb`, ILM alignment for `au-vic`, fundamental rights for `eu-brg`) when the framework calls for it.
3. **Write one-sentence descriptors per criterion**. Each must be measurable or assessable, an end not a means, and non-redundant with the others.
4. **Generate scale anchors**: for 1-5, write one line for each of scores 1, 3, 5 (worst, neutral, best). Interpolate 2 and 4 only if the scale is 1-7 or the user asks. For 0-100 (under `--rigorous`), write anchors at 0, 25, 50, 75, 100.
5. **Exclude cost-related criteria**. Green Book, World Bank, and ADB all require costs to be assessed separately. If a cost criterion seems tempting (affordability, value for money), move it to a separate cost line below the scoring matrix.
6. **Apply CBA linkage check**: if the user mentions a parallel CBA or passes a longlist file, exclude any criterion that overlaps with a monetised benefit in that CBA. No double counting.

### Step 3: Score the options (silent)

Use the problem description, option descriptions, and any context the user has provided to generate best-estimate scores for each option on each criterion. This is an internal first pass to present to the user for review, not a final answer.

Scoring rules:
- Anchor the scale at realistic best and worst cases across the actual options.
- Be honest about uncertainty. If a criterion cannot be scored from available information, mark it "?" and flag in the sensitivity note.
- Apply the framework lens: `wb` and `adb` require explicit distributional and poverty scoring; `au-vic` requires alignment to ILM benefits.

### Step 4: Present draft for confirmation (one interactive check)

Show the user the draft scoring matrix in a single block and ask once:

```
Draft scoring matrix (central case):

[Markdown table with criterion, weight, option columns, scores, weighted totals]

Confirm, edit, or regenerate?
- [A] Confirm and produce the final output
- [B] Edit specific scores or weights (describe)
- [C] Regenerate with different criteria
```

Apply edits if requested. Do not iterate more than twice before producing the final output.

### Step 5: Compute

- Weighted score per option per criterion: `score × weight`
- Weighted total per option: sum across criteria
- Ranked verdict: sort options by weighted total, highest first
- **Sensitivity** (four quick tests, reported in one paragraph only):
  1. Equal-weights comparison: does the ranking hold if all weights are set equal?
  2. Remove-a-criterion: for each criterion in turn, does the ranking hold if that criterion is dropped?
  3. Top-weight threshold: by how much would the highest-weighted criterion need to change for the winner to flip?
  4. Tie margin: how close are the top two options in weighted total (as a percentage)?

Report the four tests in one compact paragraph under the scoring matrix. No separate sensitivity section with multiple tables. One paragraph only.

### Step 6: Write the output

Save `mca-[slug]-[YYYY-MM-DD].md` with this exact structure. Nothing more, nothing less.

```markdown
# MCA: [Problem name]

**Framework**: [uk-gb | eu-brg | wb | adb | au-vic] · **Method**: [MCA / MCDA rigorous] · **Scale**: [1-5 | 0-100] · **Date**: [YYYY-MM-DD]

**Problem**: [one-sentence problem statement]

**Options compared**: [comma-separated list]

**Verdict**: **[Option X] preferred** ([weighted total] / [max possible]). [One-sentence reason grounded in the top 2-3 criteria that drove the ranking.]

## Scoring matrix

Table 1: MCA scoring matrix (weighted scores in brackets).

| Criterion | Weight | [Option A] | [Option B] | [Option C] |
|-----------|:------:|:----------:|:----------:|:----------:|
| [Criterion 1] | [w]% | [s] ([ws]) | [s] ([ws]) | [s] ([ws]) |
| [Criterion 2] | [w]% | [s] ([ws]) | [s] ([ws]) | [s] ([ws]) |
| [Criterion 3] | [w]% | [s] ([ws]) | [s] ([ws]) | [s] ([ws]) |
| [Criterion 4] | [w]% | [s] ([ws]) | [s] ([ws]) | [s] ([ws]) |
| [Criterion 5] | [w]% | [s] ([ws]) | [s] ([ws]) | [s] ([ws]) |
| **Weighted total** | **100%** | **[total]** | **[total]** | **[total]** |
| **Rank** | | **[#]** | **[#]** | **[#]** |

Source: Authors' analysis using [framework name] scoring lens.

Criteria descriptions (one line each):
- **[Criterion 1]**: [descriptor]
- **[Criterion 2]**: [descriptor]
- ...

## Sensitivity

[One paragraph covering all four sensitivity tests. Example shape: "Ranking is robust under equal weights and under the remove-a-criterion test. The top-weighted criterion (environmental impact, 25%) would need to drop below 12% for Option B to overtake Option A. The margin between the top two options is X%, so the verdict is [robust / borderline]."]

## Cost comparison

[One compact table with each option's cost estimate and a note that cost is assessed separately from the MCA per framework convention. If the user provided a parallel CBA, reference it instead of duplicating numbers.]

| Option | Capital cost | Recurrent cost | Comment |
|--------|--------------|---------------|---------|
| [Option A] | [GBP m] | [GBP m/yr] | [one line] |
| [Option B] | [GBP m] | [GBP m/yr] | [one line] |
| [Option C] | [GBP m] | [GBP m/yr] | [one line] |

## Next step

Hand this to `/cost-benefit` if you need monetised NPV for the top-ranked option. Use `/business-case` if you need the full Five Case Model wrapper.

<!-- KEY NUMBERS
type: mca
project: [name]
framework: [framework]
method: [mca|mcda]
scale: [5|100]
n_options: [count]
n_criteria: [count]
preferred_option: [name]
preferred_score: [value]
runner_up: [name]
runner_up_score: [value]
margin_pct: [value]
sensitivity_robust: [true|false]
date: [YYYY-MM-DD]
-->
```

That is the full default deliverable. No methodology section. No JSON companion. No detail tables beyond the one scoring matrix. No weighting-method walkthrough.

**Sub-component selection** (via `--section`): if the user wants only part of the output, emit only those parts. Rules:
- `--section full` (default): emit the whole structure above.
- `--section matrix`: emit only the header block + the scoring matrix table + source note.
- `--section verdict`: emit only the header block + the one-line verdict.
- `--section sensitivity`: emit only the header block + the sensitivity paragraph.
- `--section cost`: emit only the header block + the cost comparison table.
- `--section matrix,cost`: emit header + scoring matrix + cost comparison only.

In all sub-component modes, always include the header block at the top so the output is self-explanatory. Always include the KEY NUMBERS comment at the bottom.

**Format exports** (multi-format via `--format`):
- **Markdown (.md)**: always generated. `mca-[slug]-[date].md`.
- **Excel (.xlsx)** (if `xlsx` in `--format`): invoke the `xlsx` skill. One workbook, one sheet with the scoring matrix. Blue input cells for scores and weights so the user can re-run without re-invoking this skill. Conditional formatting on the weighted totals row (green for rank 1, amber rank 2, grey rank 3+). Save as `mca-[slug]-[date].xlsx`.
- **Word (.docx)** (if `word` in `--format`): invoke the `docx` skill. One document: header block, scoring matrix, verdict, sensitivity paragraph, cost comparison. Page break before the scoring matrix if the header block runs over. Save as `mca-[slug]-[date].docx`.
- **PowerPoint (.pptx)** (if `pptx` in `--format`): invoke the `pptx` skill. One deck, 4 slides max: (1) Problem and options (title slide), (2) Scoring matrix (one big table), (3) Verdict and sensitivity, (4) Cost comparison. Action titles on every slide. Save as `mca-[slug]-[date].pptx`.
- **PDF** (if `pdf` in `--format`): render the markdown through the econstack Quarto template via `scripts/render-report.sh`. Save as `mca-[slug]-[date].pdf`.
- **`--format all`**: expand to `markdown,xlsx,word,pptx,pdf`.

Tell the user (listing only the files actually produced):
```
MCA complete. [N] options × [M] criteria. Preferred: [Option X] ([score] / [max]).

Saved:
  mca-[slug]-[date].md
  [other formats if requested]

Next: /cost-benefit for monetisation of the preferred option, or /business-case for the full Five Case wrapper.
```

## Framework-specific rules

### `uk-gb` (UK Green Book)
- Default 1-5 scale. Under `--rigorous`, forced to 0-100 with anchor-based value functions and swing weighting.
- Cost criteria excluded from the scoring matrix (Green Book requires separate cost assessment). Always include a Cost comparison table below the matrix.
- Green Book MCDA is formally required at the **longlist** stage, not the shortlist stage. At shortlist, CBA or CEA apply. If the user's problem implies a shortlist decision, note: "Green Book requires CBA or CEA at shortlist. Use `/cost-benefit` instead." Then proceed anyway if the user insists.

### `eu-brg` (EU Better Regulation Guidelines)
- Use the impact direction scale: +++ strongly positive, ++ moderate positive, + weakly positive, 0 neutral, - weakly negative, -- moderately negative, --- strongly negative. Internally map to 7-point numeric for computation.
- Always include the six EU BRG impact categories: economic, business (including SMEs), consumer, social, environmental, fundamental rights. Drop any you do not need rather than adding non-standard ones.

### `wb` (World Bank)
- Add a Poverty impact and Distributional incidence criterion by default. These are required by OP 10.04 for all WB-financed projects.
- Tag each criterion with its incidence (which income group gains or loses).

### `adb` (Asian Development Bank)
- Add a Poverty impact criterion AND a Gender-disaggregated benefit criterion. Both are required by ADB Economic Analysis Guidelines.
- Score climate co-benefits explicitly using the ADB Climate Typology.

### `au-vic` (Victorian Treasury HVHR)
- Map criteria directly to the Investment Logic Map benefit hierarchy. Each criterion must correspond to a named ILM benefit with an owner, KPI, baseline, target, and realisation timeframe (carry the owner and KPI through; baseline / target / timeframe handled in the business case).
- Under `--rigorous`, apply the Decision Conference framing: this skill structures the analysis, but actual scoring and weighting for an HVHR business case should be done in a facilitated workshop.

## Important rules

- **Two interactive moments at most.** Step 1 collects the problem and options in one batch. Step 4 confirms the draft matrix. No other AskUserQuestion calls.
- **Silent brainstorm.** Do not narrate criterion generation, sector detection, or scoring logic. Show the result.
- **Costs go in a separate table**, never inside the scoring matrix. All five frameworks require this.
- **No double counting with CBA.** If a parallel CBA exists, any criterion that overlaps with a monetised CBA benefit is excluded from the MCA.
- **One clean deliverable.** One scoring matrix, one sensitivity paragraph, one cost comparison, one next-step line. No methodology section, no appendix, no weighting walkthrough.
- **Equal weights are the default.** Research consistently shows equal weights perform well when true weights are uncertain. Do not ask the user to supply weights unless they explicitly invoke `--weights`.
- **AHP is not supported.** Pairwise comparisons add complexity without first-time-user value. Use `--rigorous` for Green Book MCDA instead.
- **No JSON companion file.** Downstream skills parse the markdown.
- **Em dashes**: never use em dashes. Use commas, colons, parentheses, or "and".

## Integration with other skills

- `/cost-benefit` consumes the preferred option's cost estimate (from the Cost comparison table) and any monetisable criteria. It produces Economic NPV + Financial NPV.
- `/business-case` wraps the MCA into the Strategic Case and Economic Case of the Five Case Model.
- `/longlist` feeds into `/mca` when the user needs to sift many options before detailed appraisal.
- `/reg-impact` uses the same structure for regulatory options but with the Standard Cost Model on the cost side.
