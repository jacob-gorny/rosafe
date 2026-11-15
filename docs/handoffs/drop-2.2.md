# Drop 2.2: alerts only on days with rain or ice (Sun Nov 15, 2026, ~12:15 PM)

**For:** Teammate 2. Run `git pull --tags` and look at tag `drop-2.2`. This is a small one, and it's the last change
before 2024 opens.

## What changed for the app

1. **The app alerts only on days with rain or ice.** A rain day means 0.3 mm or more at DFW Airport. Both
   `data/scores_2023.json` and `data/sample.json` have a new header field, `"alert_weather_only": true`. On days with
   no rain and no ice, `alert` is now empty.
   - **2023:** alerts on 55 days, down from 169, and 5,606 flagged road-days, down from 9,904.
   - **Rain-day alert lists didn't change.**
2. **Nothing in the app should have to change, as long as it reads `alert` from the file** (Drop 2 asked for that).
   Please check this one thing. If the app works out the rule itself from `pred` and `alert_threshold`, switch it to
   reading `alert`, or it will still alert on dry days.
3. **Every alert day now has a weather reason** in `reasons`, so the banner can say why. For example:
   "Rain today. Risky stretch ahead: I-30. 40% more crashes than normal on days like today." This is optional, but
   it's the cheapest way to make an alert make sense.

## Why

On dry days the model's flags were weak. They ran only +8.6% above normal, against +43.1% on rain days, and on most of
those days the app had no reason to show. Rain-or-ice days only also means the app alerts on about 55 days a year
instead of 169. We checked whether the day after a rainstorm deserves an alert too. It doesn't: those days run like
any other dry day.

## Unchanged

The file names, `pred`, `alert_threshold` (1.14), the cap (the worst 15% of roads that day, at most 127),
`actual_level`, `reasons` and `routes.gpx`. Route 5's dry day still passes nothing flagged, which is now true by rule.

## Next

**Drop 3** (2024 scores, the video's demo day and the demo drives) comes about an hour after 2024 opens, around 1 PM.
**Please push `app/` to GitHub now, even if it's rough**: the code link has to include the app, and the video plan
depends on it.
