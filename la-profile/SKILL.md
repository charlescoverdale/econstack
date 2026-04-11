---
name: la-profile
description: UK local authority economic profile. Demographics, labour market, earnings, industry structure, housing, business activity, productivity, skills, deprivation. Benchmarked against the LA's own country average and optionally compared side by side with another LA. Covers 391 UK local authorities.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - AskUserQuestion
  - Skill
---

**Only stop to ask the user when:** the LA name is ambiguous (multiple matches) or a specific comparison LA is unclear.
**Never stop to ask about:** data year (use latest), benchmark selection (default to country average), section selection, or output filename.

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

# /la-profile: UK Local Authority Economic Profile

Produces a compact economic snapshot for any of the 391 UK local authorities. Covers demographics, labour market, earnings, industry structure, housing, productivity, skills, and deprivation. Every indicator is benchmarked against the LA's country average (England, Scotland, Wales, or Northern Ireland) and can be compared side by side with another LA via `--compare`.

Good for funding bid context, place-based policy work, briefing notes, or local economic assessments.

## Arguments

```
/la-profile [LA name] [options]
```

**Examples:**
```
/la-profile "Manchester"
/la-profile "Leeds" --compare "Birmingham"
/la-profile "Glasgow City" --focus labour
/la-profile "Cornwall" --section demographics,earnings
/la-profile "Newcastle upon Tyne" --format pptx
```

**Options:**
- `--compare <LA>` : Add a second LA for side-by-side comparison.
- `--focus <topic>` : Narrow to a theme. Options: `demographics`, `labour`, `earnings`, `industry`, `housing`, `productivity`, `skills`, `deprivation`.
- `--section <name>` : Emit only one sub-component. Options: `full` (default), `headline`, `demographics`, `labour`, `earnings`, `industry`, `housing`, `productivity`, `skills`, `deprivation`. Combinable with commas.
- `--format <type>` : Output format(s). `markdown` (default, always generated), `xlsx`, `word`, `pptx`, `pdf`, or `all`.
- `--client "Name"` : Add "Prepared for" metadata.

## Data sources

All data pulled from `~/econstack-data/src/data/` which carries 16 data files per LA. Sources:

| Dimension | Source | Vintage |
|-----------|--------|---------|
| Population and demographics | ONS Mid-Year Estimates | Latest |
| Labour market | ONS Annual Population Survey (APS) | Latest |
| Earnings | ONS ASHE | Latest |
| Industry structure | ONS BRES | Latest |
| Housing | ONS House Price Index, VOA | Latest |
| Productivity (GVA per hour) | ONS subnational productivity | Latest |
| Skills and qualifications | ONS APS | Latest |
| Deprivation | MHCLG IMD (English LAs), SIMD (Scotland), WIMD (Wales), NIMDM (Northern Ireland) | Latest |

## Instructions

### Step 1: Resolve LA name and detect focus

- Match the user's LA name against the 391 LA list. If ambiguous (e.g. "Newcastle" matches both "Newcastle upon Tyne" and "Newcastle-under-Lyme"), ask once to disambiguate.
- If `--compare` is set, resolve the second LA the same way.
- If `--focus` is set, narrow the profile to the relevant section only.

### Step 2: Load data (silent)

Load the 16 data files for the target LA from the parameter database. Apply the same process to the comparison LA if `--compare` is set.

Detect the country (England, Scotland, Wales, Northern Ireland) from the LA code. Load the country's average as the default benchmark.

### Step 3: Build the profile (silent)

Walk through the standard sections internally.

1. **Demographics**: population, age structure (median age, % under 16, % over 65), ethnic composition, population growth.
2. **Labour market**: employment rate, unemployment rate, economic inactivity, workless households.
3. **Earnings**: median gross weekly pay (full-time), part-time pay, gender pay gap.
4. **Industry structure**: top 5 sectors by employment, employment in high-value sectors (professional services, tech, advanced manufacturing), public sector share.
5. **Housing**: average house price, affordability ratio (price / earnings), tenure mix, new builds.
6. **Productivity**: GVA per hour, GVA per head.
7. **Skills**: % with Level 4+ qualifications (degree or equivalent), % with no qualifications, apprenticeship starts.
8. **Deprivation**: IMD rank (of 317 English LAs, or SIMD / WIMD / NIMDM for devolved nations), LSOAs in most deprived decile.

Every indicator is benchmarked against the country average. If `--compare` is set, also show the comparison LA's value.

### Step 4: Write the output

Save `la-profile-[slug]-[YYYY-MM-DD].md` with this structure.

```markdown
<!-- KEY NUMBERS
type: la-profile
la: [LA name]
compare: [compare LA or none]
country: [England|Scotland|Wales|NI]
population: [value]
employment_rate: [value]
median_pay: [value]
imd_rank: [value]
date: [YYYY-MM-DD]
-->

# Local Authority Profile: [LA name]

**Country**: [England | Scotland | Wales | Northern Ireland] · **Date**: [YYYY-MM-DD]
[If --compare: "**Compared with**: [Compare LA]"]

## Headline

| Indicator | [LA] | [Country average] | [Compare LA, if used] | Position |
|-----------|-----:|------------------:|---------------------:|:--------:|
| Population | [val] | - | [val] | - |
| Employment rate (16-64) | [val]% | [val]% | [val]% | [above / below average] |
| Median weekly pay (FT) | GBP [val] | GBP [val] | GBP [val] | [above / below average] |
| GVA per hour | GBP [val] | GBP [val] | GBP [val] | [above / below average] |
| Level 4+ qualifications | [val]% | [val]% | [val]% | [above / below average] |
| IMD rank (of 317, if English) | [val] | - | [val] | [most / least deprived quintile] |

[One-sentence headline summary: e.g. "Manchester has a strong labour market but below-average productivity and material deprivation in northern wards."]

## Demographics

[One paragraph: population size and growth, age structure, ethnic composition. One small table if needed.]

## Labour market

[One paragraph: employment rate, unemployment, inactivity, workless households, how the LA compares to the country average.]

## Earnings

Table: Earnings compared.

| Metric | [LA] | [Country average] | Gap |
|--------|-----:|------------------:|:---:|
| Median gross weekly pay (FT) | GBP [val] | GBP [val] | [+/-] |
| Median gross weekly pay (PT) | GBP [val] | GBP [val] | [+/-] |
| Gender pay gap (%) | [val]% | [val]% | [+/-] |

## Industry structure

Table: Top 5 sectors by employment.

| Sector | Jobs | Share | Vs country avg |
|--------|-----:|------:|:--------------:|
| [Sector 1] | [val] | [val]% | [+/-] |
| [Sector 2] | [val] | [val]% | [+/-] |
| [Sector 3] | [val] | [val]% | [+/-] |
| [Sector 4] | [val] | [val]% | [+/-] |
| [Sector 5] | [val] | [val]% | [+/-] |

## Housing

[One paragraph: average price, affordability, tenure mix, new builds. One small table.]

## Productivity

[One paragraph: GVA per hour, GVA per head, position vs country average, trend.]

## Skills

[One paragraph: Level 4+ share, no qualifications share, apprenticeships, key skills gaps.]

## Deprivation

[One paragraph: IMD rank, most deprived LSOAs in the LA, any notable concentrations.]

## Data sources

ONS APS, ASHE, BRES, Mid-Year Estimates, subnational productivity. MHCLG IMD (or SIMD / WIMD / NIMDM). Latest available vintages. Sourced from `~/econstack-data/src/data/`.
```

**Sub-component selection** (via `--section`): emit only the requested sections. Always include the header block and Headline table.

- `full` (default): the whole profile.
- `headline`: headline table only.
- `demographics` / `labour` / `earnings` / `industry` / `housing` / `productivity` / `skills` / `deprivation`: that single section.
- Combinable: `--section headline,labour,earnings`.

**Format exports** (via `--format`):
- **Markdown (.md)**: always generated.
- **Excel (.xlsx)**: workbook with sheets per dimension (Demographics, Labour, Earnings, Industry, Housing, Productivity, Skills, Deprivation). Historical series back 5 years.
- **Word (.docx)**: one document, full profile.
- **PowerPoint (.pptx)**: 4 slides: (1) Headline, (2) Labour and earnings, (3) Industry and productivity, (4) Deprivation and skills.
- **PDF**: render through econstack Quarto template.
- **`all`**: expand to all formats.

Tell the user (listing only files produced):
```
LA profile complete. [LA]. Population [val], employment rate [val]%, median pay [val].

Saved:
  la-profile-[slug]-[date].md
  [other formats if requested]
```

## Important rules

- **Benchmark against the country average by default.** England, Scotland, Wales, and Northern Ireland are separate benchmarks. Do not default to UK average unless explicitly requested.
- **IMD is country-specific.** English LAs use MHCLG IMD; Scottish LAs use SIMD; Welsh LAs use WIMD; Northern Ireland LAs use NIMDM. Do not mix.
- **Every indicator has a vintage.** Cite the source dataset and release date in the Data sources footer.
- **Honest on productivity.** Subnational GVA per hour is an ONS experimental series. Flag in the footer.
- **Em dashes**: never use em dashes. Use commas, colons, parentheses, or "and".

## Integration with other skills

- `/io-report` uses this skill's labour and industry data when computing regional IO impacts for the same LA.
- `/market-research` may use this skill for the geography section of a place-based market report.
- `/cost-benefit` and `/business-case` may reference this skill for the Strategic Case context of a place-based investment.
