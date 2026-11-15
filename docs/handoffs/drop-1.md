# Drop 1: map shapes, sample scores, demo routes (Sat Nov 14, 2026, ~9:10 PM)

**For:** Teammate 2. Run `git pull --tags` and look at tag `drop-1`. Nothing in the formats changed since Drop 0 (`docs/app-data-contract.md`).

## New in `data/`

| File | What's in it | Size |
|---|---|---|
| `roads.geojson` | **853 roads**: 257 state, 8 toll, 588 city. `MultiLineString` in [lon, lat]. 38 are `busy` (`checked: "measured"`), the rest `estimated` | 0.5 MB |
| `sample.json` | **Made-up** scores (`made_up: true`) for 14 real days, Feb 24 to Mar 9, 2023, with real weather and reasons. `alert_threshold` 1.48. Dry days have 0 alerts, rain days about 150 to 180 | 0.09 MB |
| `routes.gpx` | 5 drives, a point every 5 s at 65 mph, each up to 20 minutes. Routes 1 to 4 run on **Mar 2, 2023** (heavy rain in the sample) along I-35E, US 75, I-30 and I-20. Route 5 runs I-635 on **Feb 24** (dry, nothing flagged). Each track's `<desc>` lists the flagged roads it passes | 0.09 MB |

A picture of every road shape: `docs/road_shapes.png`.

## What you can build now

1. **Map:** draw all 853 lines, coloured by `pred` for the selected day (`pred[i]` belongs to `road_ids[i]`). Suggested colours: under 1.1 grey, 1.1 to 1.3 yellow, 1.3 and up orange, alert red.
2. **Day picker and ranked list:** the 14 sample days, plus the roads sorted by `pred`, each showing `display_name`, `reasons` and "measured" or "estimated".
3. **Alert rule against the simulated drive:** play `routes.gpx` through the same code real location will use. Fire once when faster than ~20 mph, within half a mile of a road in `alert`, and heading toward it. Stay quiet for that road for 10 minutes.
4. **App tests you can run already:** 4 (the chime comes at least half a mile early), 5 (once per road per pass), and 6 (quiet when parked: hold one GPS point for a minute next to a flagged road).

## Heads-up

- The sample flags a lot of city streets on rain days, because they're 588 of the 853 roads. The real 2023 file (Drop 2) will be different. Don't tune the look to the sample's numbers.
- `actual` is empty in the sample. In Drop 2 it only covers the 38 busy roads, on purpose.
- Some city street names look odd ("E 8Th St"). They're TxDOT's spellings in title case. Leave them unless one is unreadable.

## Next

**Drop 2: real 2023 scores** (`scores_2023.json`), expected overnight. It brings real reasons, real `actual` values for busy roads, and 3 suggested demo dates.
