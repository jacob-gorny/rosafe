# Should the app also alert the day after a rainstorm?

Written by Claude Code on Sun Nov 15, before 2024 was opened. Information only: it changed no model or setting. It uses
2021 to 2023 only.

**The question:** should the app also alert the day after a rainstorm, because of what's left on the road?

**The answer: no.** On 2021 to 2023, a dry day right after rain has about the same number of crashes as any other dry
day, both over the whole day and in the morning. That holds after a storm too.

## How we compared

- **Day types** come from NOAA's DFW Airport daily file: a rain day (0.3 mm or more), a dry day right after a rain day,
  a dry day 2 days after, and a dry day 3 or more days after rain (the comparison group). Holidays are left out.
  "After a storm" means 12.7 mm (half an inch) or more fell the day before, a line set before running anything.
- **Crashes against normal** use the 855 roads and the app's own normals. A second view uses the four surface groups'
  8-week normal, which follows the seasons. Both views give the same answer.
- **Gap** means how much higher a day type runs than the dry days 3 or more days after rain. It counts as real if it
  stays above zero in 950 of 1,000 redraws of whole weeks, the notebook's usual rule.

## Results, 2021 to 2023 (855 roads)

| Day type | Days | Crashes vs normal | Gap vs dry 3+ days | Above zero in |
|---|---|---|---|---|
| Rain day | 213 | +14.5% | +17.5% | 1,000 of 1,000 |
| Dry, the day after rain | 120 | -2.4% | +0.1% | 497 |
| Dry, the day after 12.7 mm or more | 32 | -0.2% | +2.4% | 883 |
| Dry, 2 days after rain | 105 | -3.8% | -1.3% | 120 |
| Dry, 3 or more days after rain | 614 | -2.5% | (comparison) | |

- **The rain-day row shows the test works:** it finds a real effect when there is one.
- **2023 alone looked like a yes** (day after rain +3.9%, 964 of 1,000), but 2021 to 2022 went the other way (-1.8%,
  165 of 1,000). The 2023 result also cleared 950 with only half of 20 random seeds tried, and fell to +2.4% (910 of
  1,000) without one day, Feb 3, 2023, the day after an ice storm.
- **A separate computation** written from scratch by another agent, using all DFW crashes and a different normal (the
  8 previous same weekdays), agreed: day after rain +1.1% (768 of 1,000), after a storm +2.7% (889), rain days +12.3%
  (1,000).

## The morning after

- A first look said 6 to 10 AM ran 6.3% above a dry morning (13.0% after a storm). **That was the weekday mix.** Days
  after rain happened to fall on weekdays more often (78% against 68%), and weekday mornings hold about twice the
  share of a day's crashes that weekend mornings do. Comparing like with like, the morning after rain is -1.0% (373 of
  1,000), and +4.8% after a storm (879 of 1,000). Neither is real.
- What's left of the morning bump sits on foggy days. Fog is three times as common the day after rain, and there are
  too few such days to tell.
- **The roads do stay wet.** The day after rain, officers marked the road wet or flooded in about 24% of crashes before
  6 AM and 11% from 6 to 10 AM, against about 2% on other dry days. The number of crashes doesn't go up, though, so
  these look like crashes that would have happened anyway, on a damp road. The officer's road-surface field is used
  here only to describe crashes. It is never a model input.

## What the model and the alert did on these days (2023)

- The model predicts the day after rain like any dry day: -2.2% predicted, +0.7% actual. On dry days 3 or more days
  after rain it predicted -2.5%, and those days ran -3.0%.
- Before the rain-or-ice filter, the alert flagged 620 road-days on 14 days after rain. They ran +0.2%, right at normal.
- Adding "the day after rain" back to the shipped rule would add those 620 flags and lower its strength from +43.1% to
  +41.5%. Adding only "the day after 12.7 mm or more" would add 312 flags that ran -6.3%, giving +41.7%. Both keep the
  model's own clear-day picks, so neither tests whether the roads that were worst *during* the storm stay worse the next
  morning. That version was not tested.

## The "buildup"

The 2003 UC Berkeley release behind research claim 1 says oil and debris build up in dry weather, make roads slick when
it first starts to rain, and are washed off by the second day of rain. So the risky moment is the first rain, and that's
a rain day, which the app still alerts on. Claim 1 itself (first rain after 7 or more dry days against rain the day
after rain) came out +5.3 points on 2021 to 2023, but only 821 of 1,000, so it did not hold. 2024 is still to be added.

## Limits

- One rain gauge at DFW Airport stands in for 12 counties, so a dry day at the airport can be wet in Denton or Ellis.
- Rain totals are daily (midnight to midnight standard time), so we can't see when the rain stopped.
- More than 20 comparisons were run, and about 1 in 20 crosses the 950 line by chance. The only passes were in 2023
  alone, which fits that.
- The app also stays quiet on dry days just after ice. Across 2021 to 2023 the 24 such days ran 15.9% below normal,
  probably because people stay home after an ice storm. One of them, Feb 3, 2023, was among the year's worst misses
  (predicted 0.96, real 1.72 on the busy roads), so leftover ice is a known gap.

## How it was run

`analysis/day_after_rain.py` is appended to the notebook as it was at commit 3096948 (before the rain-or-ice change; that commit is in the team's private working repo,
not in the public copy),
cut right after step 12, and run on a copy of the repo. `analysis/run_checks.py` repeats the whole check in about 90
seconds. Every frame stops at 2023-12-31 (the notebook asserts it), and only totals over many days and roads are printed.
