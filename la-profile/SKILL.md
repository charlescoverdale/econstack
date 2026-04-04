---
name: la-profile
description: Local authority economic profile (UK). 391 UK local authorities. Interactive, lets you pick which sections you need.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

<!-- preamble: update check -->
Before starting, run this silently. If it outputs UPDATE_AVAILABLE, tell the user:
"A new version of econstack is available. Run `cd ~/.claude/skills/econstack && git pull` to update."
Then continue with the skill normally.

```bash
~/.claude/skills/econstack/bin/econstack-update-check 2>/dev/null || true
```

# /la-profile: Local Authority Economic Profile (UK)

Generate professional economic profile content for any UK local authority. Covers demographics, labour market, earnings, industry structure, housing, business activity, productivity, deprivation, skills, and national benchmarking.

**This skill is interactive.** It loads the data, shows you the headline stats, then asks what output you need: the full profile, specific sections, a slide summary, or an elevator pitch.

## Arguments

```
/la-profile <local_authority> [options]
```

**Examples:**
```
/la-profile Manchester
/la-profile Glasgow City
/la-profile Leeds --compare Birmingham
/la-profile Bristol --focus housing
/la-profile Isle of Anglesey --full
```

**Options:**
- `--full` : Skip the interactive menu, generate the complete profile
- `--compare <LA>` : Include side-by-side comparison with another LA
- `--focus labour` : Emphasise labour market and skills
- `--focus housing` : Emphasise housing and affordability
- `--focus business` : Emphasise business activity and industry structure
- `--client "Name"` : Add "Prepared for: [Name]" on outputs
- `--format <type>` : Output format(s): `markdown`, `html`, `word`, `pptx`, `pdf`, or `all`. Comma-separate for multiple. Default: markdown only

## Instructions

### Step 1: Parse the request

Extract:
- **local_authority**: The LA name or slug
- **compare_la**: Optional second LA for comparison
- **focus**: Optional emphasis area
- **full**: If true, skip the interactive menu
- **client**: Optional client name

### Step 2: Load all available data

```bash
DATA_DIR="$HOME/econstack-data/src/data"

# Core (always available)
cat "$DATA_DIR/${LA_SLUG}/summary.json"
cat "$DATA_DIR/${LA_SLUG}/employment.json"
cat "$DATA_DIR/${LA_SLUG}/earnings.json"
cat "$DATA_DIR/${LA_SLUG}/housing.json"
cat "$DATA_DIR/${LA_SLUG}/population.json"

# Extended (may not exist)
cat "$DATA_DIR/${LA_SLUG}/industry.json" 2>/dev/null
cat "$DATA_DIR/${LA_SLUG}/skills.json" 2>/dev/null
cat "$DATA_DIR/${LA_SLUG}/commuting.json" 2>/dev/null

# Benchmarks
cat "$DATA_DIR/national-benchmarks.json"
```

Determine country from ONS code: E = England, S = Scotland, W = Wales. Use the matching country benchmark throughout.

If the LA slug is not found:
```bash
ls "$DATA_DIR/" | grep -i "<search_term>"
```

### Step 3: Show headline stats and ask what the user needs

Present the key numbers:

```
[LA NAME] — Economic Profile
=============================
Country:           [England/Scotland/Wales]
Population:        [val] ([year])
Workplace jobs:    [val]
Median earnings:   £[val] ([X]% vs [country] avg)
Claimant rate:     [val]%
GVA per job:       £[val] (rank [X] of 391)
Median house price: £[val] (affordability [X]x earnings)
IMD rank:          [X] of [Y] (if available)
```

**If `--full` was NOT specified**, ask the user using AskUserQuestion:

Question: "What output do you need for [LA name]?"

Options:
- A) **Full profile** : Complete 7-section economic profile
- B) **Pick sections** : Let me choose which sections I want
- C) **Elevator pitch** : One paragraph characterizing this economy (for meetings or email intros)
- D) **Slide summary** : 5-6 bullet points ready for PowerPoint
- E) **Data only** : Just the JSON file with all stats and benchmarks

**If user picks B**, ask a follow-up:

Question: "Which sections? (pick all that apply)"

Options (multiSelect: true):
- Summary narrative (3-4 paragraphs characterizing the local economy)
- Demographics and population (mid-year estimate, age profile, growth trend)
- Labour market (employment by sector, specialisation, shift-share)
- Earnings and income (percentiles, gender pay gap, inequality)
- Housing and affordability (prices, tenure, price-to-earnings)
- Skills and commuting (occupations, qualifications, commute modes)
- National benchmarking (vs country and GB averages)
- Methodology note (one paragraph on data sources)

Then generate ONLY the selected sections.

### Step 4: Generate the requested output

**Always include a key stats block at the top of any output file:**

```markdown
<!-- KEY STATS
la: [LA name]
country: [country]
population: [val]
workplace_jobs: [val]
median_earnings: [val]
claimant_rate: [val]
gva_per_job: [val]
median_house_price: [val]
price_to_earnings: [val]
imd_rank: [val]
date: [date]
-->
```

**Always write a companion JSON file** as `la-data-{slug}-{date}.json`:

```json
{
  "la": { "name": "", "slug": "", "onsCode": "", "country": "" },
  "population": { "estimate": 0, "year": "", "workingAgePct": 0, "change5yr": 0 },
  "employment": { "total": 0, "topSectors": [], "specialisedSectors": [], "claimantRate": 0 },
  "earnings": { "median": 0, "p10": 0, "p25": 0, "p75": 0, "p90": 0, "genderGap": 0, "year": "" },
  "housing": { "medianPrice": 0, "priceToEarnings": 0, "yearChange": 0, "tenure": {} },
  "productivity": { "gvaPerJob": 0, "rank": 0, "totalRanked": 0, "topGVASectors": [] },
  "business": { "totalEnterprises": 0, "microPct": 0, "birthRate": 0 },
  "deprivation": { "imdRank": 0, "totalLAs": 0, "worstDomain": "" },
  "benchmarks": {
    "country": { "name": "", "medianEarnings": 0, "medianHousePrice": 0, "claimantRate": 0, "gvaPerJob": 0 },
    "gb": { "medianEarnings": 0, "medianHousePrice": 0, "claimantRate": 0, "gvaPerJob": 0 }
  },
  "metadata": { "sources": "ONS, BRES, ASHE, DLUHC, Nomis, Census 2021", "generatedAt": "" }
}
```

#### Section templates

Each section stands alone. Do not reference other sections.

**At a glance table:**
```markdown
## At a Glance

| Indicator | [LA Name] | [Country] avg | GB avg |
|-----------|-----------|---------------|--------|
| Population | [val] | - | - |
| Workplace jobs | [val] | - | - |
| Median earnings | [val] | [val] | [val] |
| Claimant rate | [val]% | [val]% | [val]% |
| GVA per job | [val] | [val] | [val] |
| Median house price | [val] | [val] | [val] |
| Price-to-earnings | [val]x | - | - |
| Working-age % | [val]% | [val]% | [val]% |
```

**Summary narrative:**
```markdown
## Summary

[3-4 paragraphs. First paragraph: population, location context, type of economy. Second: labour market character (what sectors dominate, what's specialised, employment rate). Third: earnings and housing affordability. Fourth: productivity and outlook.

Write for someone who knows nothing about this area. Be concrete: "Manchester's economy is dominated by professional services, health, and education, with 451,000 workplace jobs" not "Manchester has a diverse economy."

Compare to the LA's own country average (England/Scotland/Wales). Do not just compare to England for Scottish/Welsh LAs.]
```

**Elevator pitch:**
```markdown
[One paragraph, 4-5 sentences. Characterize the economy for someone in a meeting who asks "tell me about this area." Include: population, dominant sectors, earnings vs national, one distinctive feature (specialisation, deprivation, growth, affordability). End with one forward-looking observation.]
```

**Slide summary:**
```markdown
**[LA Name] — Economic Snapshot**

- Population **[val]**, [growing/stable/declining] ([X]% over 5 years)
- **[val] workplace jobs**, dominated by [top 2 sectors]
- Median earnings **£[val]** ([X]% [above/below] [country] average)
- House prices **£[val]** ([X]x earnings, [affordable/moderate/expensive/severely unaffordable])
- [One distinctive feature: "Highly specialised in [sector] (LQ [X])" or "IMD rank [X], one of the most deprived in England" or "GVA per job [X]% above national, ranking [Y]th"]
- [One risk or challenge: "Claimant rate [X]%, nearly double the national average" or "Population declining, working-age share below average"]

*Data: ONS, BRES, ASHE, DLUHC. Powered by econstack.*
```

**Demographics and population:**
```markdown
## Demographics and Population

- Mid-year population: [val] ([year])
- Male/female: [val] / [val]
- Working-age (16-64): [val]% ([country] avg: [val]%)
- Population change (5yr): [val]% ([country] avg: [val]%)

[1-2 sentences interpreting. Growing or shrinking? Young or old? How does the working-age share compare?]
```

**Labour market:**
```markdown
## Labour Market

Total workplace jobs: [val]. Claimant rate: [val]% ([country] avg: [val]%, rank [X] of [Y]).

### Top sectors by employment

| Sector | Jobs | Local share | National share | LQ |
|--------|------|-------------|----------------|----|
| [sector] | [val] | [val]% | [val]% | [val] |
| ... | ... | ... | ... | ... |

**Specialised sectors** (LQ > 1.25): [list]
**Under-represented** (LQ < 0.5): [list]

[2-3 sentences: What does this tell us? Service-dominated? Manufacturing heritage? Public sector dependent? Are the specialised sectors growing or declining nationally?]

[If shift-share data available:]
### Shift-share analysis

| Sector | Actual change | Expected (national trend) | Local competitiveness |
|--------|--------------|---------------------------|----------------------|
| [winners] | +[val] | [val] | +[val] |
| [losers] | -[val] | [val] | -[val] |
```

**Earnings and income:**
```markdown
## Earnings and Income

Median annual earnings (workplace): [val] ([year]). [Country] median: [val] ([X]% above/below).

| Percentile | [LA Name] | England |
|------------|-----------|---------|
| p10 | [val] | [val] |
| p25 | [val] | [val] |
| p50 (median) | [val] | [val] |
| p75 | [val] | [val] |
| p90 | [val] | [val] |

90/10 ratio: [val] (England: [val]). [Higher = more inequality.]

### Gender pay gap

Male median: [val]. Female median: [val]. Gap: [val]% (England: [val]%).

[1-2 sentences. Wider or narrower than national? What does this suggest about the local labour market?]
```

**Housing and affordability:**
```markdown
## Housing and Affordability

Median house price: [val] ([year change]% year-on-year). Price-to-earnings: [val]x. [Interpretation: <5x affordable, 5-8x moderate, 8-12x expensive, >12x severely unaffordable.]

| Tenure | [LA Name] | England |
|--------|-----------|---------|
| Owned outright | [val]% | [val]% |
| Owned with mortgage | [val]% | [val]% |
| Social rented | [val]% | [val]% |
| Private rented | [val]% | [val]% |

[2-3 sentences. How does affordability compare? What does the tenure mix tell us? High social renting = council housing legacy. High private renting = transient population or student city.]
```

**Skills and commuting:**
```markdown
## Skills and Commuting

[If occupation data available:]

| Occupation group | [LA Name] | England |
|------------------|-----------|---------|
| Managers & directors | [val]% | [val]% |
| Professional | [val]% | [val]% |
| Associate professional | [val]% | [val]% |
| Admin & secretarial | [val]% | [val]% |
| Skilled trades | [val]% | [val]% |
| Caring & leisure | [val]% | [val]% |
| Sales & customer service | [val]% | [val]% |
| Process & plant | [val]% | [val]% |
| Elementary | [val]% | [val]% |

[If commuting data available:]
Work from home: [val]% (England: [val]%). Dominant commute mode: [mode] ([val]%).
```

**National benchmarking:**
```markdown
## Benchmarking

| Metric | [LA Name] | [Country] | GB | vs [Country] |
|--------|-----------|-----------|-----|-------------|
| Median earnings | [val] | [val] | [val] | [X]% above/below |
| House price | [val] | [val] | [val] | [X]% above/below |
| Claimant rate | [val]% | [val]% | [val]% | [X]pp higher/lower |
| GVA per job | [val] | [val] | [val] | [X]% above/below |
| Working-age % | [val]% | [val]% | [val]% | [X]pp higher/lower |

Use percentage points (pp) for metrics that are already percentages. Use relative % for currency values.
```

**Methodology note (one paragraph):**
```markdown
**Data sources:** Employment from BRES via Nomis (workplace-based). Earnings from ASHE via Nomis (workplace-based, full-time employees). Population from ONS Mid-Year Estimates. Housing from HM Land Registry via DLUHC, tenure from Census 2021. GVA estimated from national ratios applied to local employment (indicative only). Deprivation from English IMD 2019. Skills and commuting from Census 2021. National benchmarks computed from local authority-level data. Powered by econstack.
```

### Step 5: Comparison mode

If `--compare <LA>` was specified, load data for both LAs. After the user selects sections, generate each section with two-column tables:

```markdown
| Metric | [LA1] | [LA2] |
|--------|-------|-------|
```

End with a "Key Differences" paragraph highlighting the 3-4 most notable contrasts.

### Step 6: Save and present

### Output formats

**If `--format` was NOT specified on the command line**, ask using AskUserQuestion:

Question: "What file formats do you need?"

Options (multiSelect: true):
- Markdown (.md) : Default, always included
- HTML : Self-contained branded page for email or browser
- Word (.docx) : Formatted document for editing
- PowerPoint (.pptx) : Slide deck with key charts and tables
- PDF : Branded consulting-quality PDF via Quarto

Markdown is always generated regardless of selection.

### Save and present

Save output as `la-profile-{slug}-{date}.md`. Always save `la-data-{slug}-{date}.json`.

**Then generate each additional format the user selected:**

**HTML** (if selected):
Generate a self-contained HTML file with inline CSS. Navy branding (#003078), KPI cards, professional tables. Save as `la-profile-{slug}-{date}.html`.

**Word (.docx)** (if selected):
Invoke the `/docx` skill. Navy headings, formatted tables, title page with LA name and country. Save as `la-profile-{slug}-{date}.docx`.

**PowerPoint (.pptx)** (if selected):
Invoke the `/pptx` skill. Slides: (1) Title with LA name, (2) Key stats dashboard, (3) Employment/industry, (4) Earnings/housing, (5) Deprivation/benchmarks. Save as `la-profile-{slug}-{date}.pptx`.

**PDF** (if selected):
```bash
ECONSTACK_DIR="${CLAUDE_SKILL_DIR}/../.."
"$ECONSTACK_DIR/scripts/render-report.sh" la-profile-{slug}-{date}.md \
  --title "Economic Profile: {LA Name}" \
  --subtitle "{Country} | Data from ONS, BRES, ASHE, DLUHC"
```

Tell the user what was generated:
```
Files saved:
  la-profile-{slug}-{date}.md     (profile / selected sections)
  la-data-{slug}-{date}.json      (structured data)
  la-profile-{slug}-{date}.html   (if HTML selected)
  la-profile-{slug}-{date}.docx   (if Word selected)
  la-profile-{slug}-{date}.pptx   (if PowerPoint selected)
  la-profile-{slug}-{date}.pdf    (if PDF selected)
```

## Important Rules

- Never use em dashes. Use colons, periods, commas, or parentheses.
- Never connect econstack to any individual person.
- Every section must stand alone. No cross-references between sections.
- Only report data that exists in the JSON files. Never invent data.
- If a data file is missing, omit that section. Do not leave placeholders.
- Always compare to the LA's own country (England/Scotland/Wales), not just England.
- Use "workplace-based" for employment and earnings data.
- Currency in GBP with commas. Jobs as whole numbers.
- LQ: >1.25 specialised, 0.75-1.25 average, <0.75 under-represented, >2.0 highly specialised.
- Price-to-earnings: <5x affordable, 5-8x moderate, 8-12x expensive, >12x severely unaffordable.
- IMD: rank 1 = most deprived. England only.
- The narrative should characterize the economy, not just list numbers. What kind of place is this?
- The key stats block at the top is always included, even for partial outputs.
- The companion JSON is always saved, even for partial outputs.
