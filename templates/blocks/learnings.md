<!-- preamble: project learnings -->
After the update check, run this silently to load prior learnings for this project:

```bash
eval "$(~/.claude/skills/econstack/bin/econstack-slug)"
~/.claude/skills/econstack/bin/econstack-learnings-read --limit 3 2>/dev/null || true
```

If learnings are found, apply them to this session. When a prior learning influences a decision (e.g., defaulting to a framework because the user always picks it, or applying a custom parameter override), note: "Prior learning applied: [key]".

**Capturing new learnings:** After completing this skill, log any new insights about the user's preferences, parameter choices, or project-specific quirks using:

```bash
~/.claude/skills/econstack/bin/econstack-learnings-log '<json>'
```

Learning types for econstack:

| Type | When to log | Example |
|------|-------------|---------|
| `framework` | User picks or confirms a framework | `{"skill":"cost-benefit","type":"framework","key":"uk-green-book","insight":"User prefers UK Green Book with 3.5% declining","confidence":9,"source":"observed"}` |
| `parameter` | User overrides a default parameter | `{"skill":"cost-benefit","type":"parameter","key":"optimism-bias-zero","insight":"User always sets optimism bias to 0% with justification for this project","confidence":8,"source":"observed"}` |
| `data-source` | User states a data preference | `{"skill":"macro-briefing","type":"data-source","key":"ons-abs-preferred","insight":"User prefers ONS ABS over HMRC for sector data","confidence":7,"source":"user-stated"}` |
| `output` | A report is generated | `{"skill":"cost-benefit","type":"output","key":"last-cba","insight":"Generated cba-hospital-uk-2026-04-07.json","confidence":10,"source":"observed"}` |
| `operational` | A tool or dependency is unavailable | `{"skill":"cost-benefit","type":"operational","key":"no-r-available","insight":"R is not installed, use deterministic sensitivity only","confidence":9,"source":"observed"}` |
| `preference` | User requests a specific format or style | `{"skill":"fiscal-briefing","type":"preference","key":"aud-millions-no-decimals","insight":"User wants all tables in AUD millions, no decimal places","confidence":8,"source":"user-stated"}` |

Confidence guide: 9-10 for directly observed or user-stated preferences. 6-8 for strong inferences. 4-5 for weak inferences. User-stated learnings never decay; observed/inferred learnings lose 1 confidence point per 30 days.

All learnings are stored locally at `~/.econstack/projects/` on the user's machine. Nothing is transmitted to any server.