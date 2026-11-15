# Could more training make "alert on any day" beat rain-or-ice days?

Written by Claude Code on Sun Nov 15, before 2024 was opened. Information only: the shipped model is unchanged. It uses
2023 only, with every model trained on 2021 to 2022.

**The question:** instead of dropping the dry-day alerts, could we retrain the model so that alerting on any day ends up
better than alerting only on rain or ice days?

**The answer: no.** We retrained Model D three ways, each aimed at a cause of the weak dry-day flags. None of them made
the any-day rule competitive.

## What we changed

Each version is Model D (gradient boosting, the same settings) with different inputs. Each gets its own alert line (the
top 10% of its training predictions) and the same cap (the worst 15% of roads that day).

- **Fix 1: no dry-spell inputs.** It drops "days since rain" and "rain in the last 7 days". In their place, rain in the
  last 7 days counts only on rain days, and the existing rain-day input (dry days before today's rain) stays. Why: on
  dry days the "days since rain" input drove about half the dry-day flags, and no extra crashes followed them.
- **Fix 2: adds the day of the week.** Why: flags on dry weekends ran 10.7% below normal while the model predicted 18%
  above.
- **Both fixes.**

## Results, 2023

| Model and rule | Line | Days with an alert | Flagged road-days | Crashes vs normal | Dry-day flags vs normal | Busy roads: right / catches |
|---|---|---|---|---|---|---|
| Shipped model, rain or ice days | 1.14 | 55 | 5,606 | +43.1% | none | 25.7% / 17.3% |
| Shipped model, any day | 1.14 | 169 | 9,904 | +38.7% | +8.6% | 25.0% / 17.6% |
| Fix 1, any day | 1.13 | 182 | 11,805 | +36.0% | +2.0% | 23.8% / 17.3% |
| Fix 2, any day | 1.15 | 214 | 11,644 | +38.4% | +11.7% | 24.6% / 16.5% |
| Both fixes, any day | 1.14 | 215 | 12,307 | +37.2% | +15.4% | 23.4% / 16.7% |
| Both fixes, rain or ice days | 1.14 | 61 | 5,781 | +41.0% | none | 24.2% / 16.5% |

- **No any-day version comes close to the shipped rule.** The highest is the shipped model itself at +38.7% (Fix 2:
  +38.4%), against +43.1%.
- **Both fixes give the strongest dry-day flags** (+15.4%, real on 2023), but that version runs only +37.2% overall.
  Its dry-day flags are worth about 2 extra crashes per 100 flags, against about 35 for a rain-day flag, because they
  land on quiet streets.
- **That version would alert on 215 days a year instead of 55.**
- **The fixes make the rain-day flags weaker:** with both fixes, rain-day flags run +41.0% and the busy roads' "right"
  rate falls from 25.7% to 23.4%.
- **Overall accuracy barely moves.** The miss on the 38 busy roads is 0.574 for the shipped model and 0.574 to 0.575
  for the others, against 0.579 for "every day is normal". On quiet roads summed by layer, Fix 2 is a little better
  (0.475 against 0.478). Nothing here is worth a model change on the last day.

## Why it's a ceiling, not a training problem

Dry days barely differ from normal: in 2023, dry days 3 or more days after rain ran 3.0% below normal across the 855
roads. There's very little dry-day danger for any model to find, however it's trained. The model already learns from
every year the rules allow: 2020 is left out because of COVID, and 2024 is the test.

These versions were tried after looking at 2023, so even the best one's 2023 numbers would be flattered.

## How it was run

`analysis/run_checks.py --variants` builds each version from the notebook as it was at commit 3096948 (in the team's private working repo, not in the public copy), cut right after
step 12, and runs it on a copy of the repo with 2024 locked. `analysis/variant_summary.py` prints the numbers above.
