# econstack

Claude Code skills for professional economic analysis. Generate client-ready reports, impact assessments, and briefings using UK and international economic data.

## What is this?

econstack is a collection of Claude Code skills that turn raw economic data into professional deliverables. Each skill encodes a specific analytical workflow (impact assessment, macro briefing, sector analysis) with proper methodology, references, and caveats built in.

Think of it as the difference between "pull some data and make a chart" and "generate a 10-page impact assessment with IO methodology, additionality adjustments per HM Treasury guidance, sensitivity analysis, and full academic references." The methodology is baked into the skills so you get consistent, credible output every time.

## Skills

### `/impact-report`
Generate an economic impact assessment for an investment or job creation in any UK local authority. Uses regional input-output multipliers with FLQ regionalization of ONS 2023 data.

```
/impact-report £10m in Manufacturing in Manchester
/impact-report 500 jobs in Construction in Glasgow --type2
/impact-report £25m in Financial & Insurance in City of London --conservative
```

**Output:** A structured report with executive summary, gross/net impact tables, sensitivity analysis, additionality adjustments (HM Treasury/MHCLG guidance), methodology documentation, caveats, and academic references.

### More skills coming
- `/macro-briefing` : UK macro dashboard report (GDP, inflation, employment, rates)
- `/la-profile` : Full local authority economic profile
- `/sector-analysis` : Industry deep dive with BRES data and IO multipliers
- `/fiscal-monitor` : Public finances report using OBR data

## Prerequisites

These skills depend on data from the [econprofile](https://econprofile.com) data pipeline. The econprofile repository must be cloned locally at a known path for the skills to access multiplier and LA data.

Required:
- Claude Code (claude.ai/code)
- econprofile repo cloned locally (for IO multiplier and LA data)

Optional:
- R with [ons](https://cran.r-project.org/package=ons), [boe](https://cran.r-project.org/package=boe), [fred](https://cran.r-project.org/package=fred) packages (for live data in future skills)
- Quarto (for PDF report rendering)

## Installation

```bash
# Clone into your Claude Code skills directory
git clone https://github.com/charlescoverdale/econstack.git ~/.claude/skills/econstack
```

Then use any skill by typing its command in Claude Code (e.g. `/impact-report £5m in Manufacturing in Leeds`).

## Data Sources

All data comes from official open sources:

- **ONS Input-Output Analytical Tables 2023** (Blue Book 2025): technical coefficients matrix, 104 industries aggregated to 19 SIC sections
- **BRES via Nomis**: employment by sector per local authority, location quotients
- **ASHE via Nomis**: earnings data per local authority
- **DLUHC**: housing data, local authority revenue
- **HM Treasury**: additionality guidance, Green Book framework
- **MHCLG**: Appraisal Guide (3rd edition, 2025)

## Methodology

The IO impact model uses Flegg Location Quotient (FLQ) regionalization of the national input-output table (Flegg et al. 1995). Delta = 0.3, a conventional value supported by Bonfiglio & Chelli (2008). Type I multipliers capture direct and indirect (supply chain) effects. Type II optionally adds induced (household spending) effects.

Additionality adjustments follow HM Treasury guidance (2014) and MHCLG (2025): deadweight, displacement, leakage, and substitution. Three presets (standard, conservative, optimistic) based on ranges from the Additionality Guide.

Full methodology and references are included in every generated report.

## Related Projects

- [econprofile](https://econprofile.com): 391 LA economic profiles (data source for these skills)
- [macrowithr](https://macrowithr.com): Applied macroeconomics textbook with R
- [ons](https://cran.r-project.org/package=ons): R package for ONS data
- [boe](https://cran.r-project.org/package=boe): R package for Bank of England data
- [nowcast](https://cran.r-project.org/package=nowcast): R package for economic nowcasting
- [debtkit](https://cran.r-project.org/package=debtkit): R package for debt sustainability analysis
- [yieldcurves](https://cran.r-project.org/package=yieldcurves): R package for yield curve fitting
- [inflationkit](https://cran.r-project.org/package=inflationkit): R package for inflation analysis
