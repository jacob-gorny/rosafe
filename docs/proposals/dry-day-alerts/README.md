# Proposal: stop the alert firing on clear days

**Applied: option B2, rain or ice days only (Sun Nov 15, about 11:50 AM Central, before 2024 was opened).** The line
(1.14) and the cap (the worst 15% of roads that day, at most 127) are unchanged. The notebook now has
`ALERT_WEATHER_ONLY = True`, and the header of `scores_2023.json` has `"alert_weather_only": true`.

**Later checks** (2021 to 2023 only, information only; neither changed the model or the rule), both in this folder:
`day-after-rain.md` (should the app also alert the day after rain? No: a dry day right after rain runs like any other
dry day) and `retraining-check.md` (could retraining Model D make alerting on any day competitive? No: no any-day
version beat +38.7%, against B2's +43.1%, and the shipped model is unchanged).

The rest of this file is the proposal as written overnight, kept as the record of the options.

Written by Claude Code overnight (Sun Nov 15). **Not applied.** It's Teammate 1's decision, and it has to be made **before
2024 is opened**: it's a 2023 choice, and after 2024 opens no model or rule may change.

## Why

The shipped rule ("score at least 1.14 and among the worst 15% of roads that day") fired on 114 of 2023's 294 dry days
(12 of them at the full 127 roads), because the model's prediction also moves with temperature, humidity, season and
holidays. Those dry-day flags were weak, and on 102 of those days the app has no weather reason to show for the alert
(100 list no reason at all, 2 list only "Holiday").

## The three options, all measured on 2023 (the practice year)

| Option | Flagged road-days | Crashes against normal on them | Busy roads: right / catches bad days |
|---|---|---|---|
| **A. Keep it** (shipped until Nov 15) | 9,904 (4,298 on dry days) | +38.7% (rain days +43.1%, dry days +8.6%) | 25.0% / 17.6% |
| **B. Only on days with rain, fog, thunder or ice** | 6,121 | +41.6% (the 515 fog or thunder flags on dry days: -4.9%) | 25.1% / 17.5% |
| **B2. Only on days with rain or ice** | 5,606 | +43.1% | 25.7% / 17.3% |

All 2023 ice days also had rain, so B2 is the same as "rain days only" on 2023. Test 6 keeps the plan's original rule
under every option.

**Claude Code's recommendation: B2.** It's the simplest rule ("the app warns on rainy or icy days"), it matches what the
model is good at (most of its edge is rain), it has the strongest flags, and it never chimes on a clear day.

## How to apply (about 5 minutes, before 2024 opens)

From the repo root, run one of these, then rerun the notebook and the tests:

```bash
python3 docs/proposals/dry-day-alerts/apply_rain_or_ice_only.py .
```

```bash
python3 docs/proposals/dry-day-alerts/apply_weather_days_only.py .
```

```bash
cd notebook && unset MPLBACKEND && .venv/bin/jupytext --to ipynb same_rain_different_road.py && .venv/bin/jupyter nbconvert --to notebook --execute --inplace same_rain_different_road.ipynb && .venv/bin/python make_viewer.py && .venv/bin/python -m pytest tests -q
```

The script changes the notebook (the rule, `shipped_mask`, the file writer, the rule table, the final exam, fig5's label
and the step 12 note), `notebook/tests/test_data_files.py` (the alert check now applies the rule's day filter) and
`docs/app-data-contract.md` (a new header field, `alert_weather_only`). Both versions were run end to end on a copy of
the repo: the notebook runs clean and every test passes. `scores_2023.json` changes (fewer alerts), so Teammate 2 needs a
short Drop 2.2 note: the app should keep reading `alert` from the file, so nothing in the app should have to change
(Drop 2 told Teammate 2 to read `alert`; the app isn't in the repo yet, so check with him that it doesn't recompute the
rule). Then the docs' alert numbers need updating (`docs/read-this-first-sunday.md`, the drafts, the judge prep,
`docs/demo/demo-plan.md`, `docs/audit-2023.md` and `CLAUDE.md`; some of these are internal files, not in the public copy). The script also leaves the notebook's top cell
("Results at a glance": +38.7%, +43.1% on rain days, +8.6% on dry days) unchanged, and the viewer footer in
`notebook/viewer_template.html` ("The alert also fires on some dry days") becomes wrong. Edit both before rerunning
the notebook and rebuilding the viewer.
