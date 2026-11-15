# Drop 2.1: audit fixes (Sat Nov 14, 2026, ~midnight)

**For:** Teammate 2. Run `git pull --tags` and look at tag `drop-2.1`. A cold audit of the brain found real problems; this drop fixes the ones that touch your files. The full story is in `docs/audit-2023.md`.

## What changed for the app (please update)

1. **`actual` is gone. Use `actual_level`.** It's "what really happened" as a level 0 to 4, named in the new header field `actual_level_names` ("below normal", "about normal", "higher than normal", "much higher than normal", "far higher than normal"). It only covers the 5 roads averaging 8+ crashes a day: **I-20, I-30, I-35E, I-635 and US 75** (ids in the file). Why: the old number let anyone work out the exact daily crash count, and TxDOT's terms forbid passing the crash data on.
2. **Road ids:** 850 roads now (was 853).
   - **Removed:** `city-white-settlement-rd-9999`, `state-fm2264-surface_treated`, `state-fm2728-asphalt`, and `city-e-bankhead-hwy-9999`, which is now `city-e-bankhead-hwy-9999-184`.
   - Your code should never hard-code ids. Read them from `roads.geojson` / `road_ids`.
3. **Map shapes are recomputed.** Every point is now an *average* of 5+ crashes (before, a point could land on one real crash's exact spot), from 2020 to 2023 only, rounded to 4 decimals. The lines look almost the same.
4. **`rare` is narrower.** Warm spring hail no longer counts as ice. 2023 now has 4 rare days, not 6.
5. **`routes.gpx` now uses real 2023 scores.** Routes 1 to 4 run on **Dec 15, 2023** and pass roads the model really flagged that day. Route 5 runs on a dry day (Aug 25, 2023) and passes nothing flagged.

## Unchanged

The format of `pred`, `alert` and `alert_threshold` (1.14), the alert rule (line + worst 15% of roads that day, at most 127 roads), the weather and reasons fields, and the file names.

## Good for the video: Dec 15, 2023

First rain after 14 dry days. The app flags 127 roads. "What really happened" on the five headline roads:
- **I-35E** and **I-20:** far higher than normal.
- **I-30:** much higher.
- **I-635:** higher.
- **US 75:** below normal. An honest miss worth showing.

## Next

**Drop 3** (2024, the final exam and the video's demo day) comes Sunday after Teammate 1 opens 2024. The format will be the same as this drop.
