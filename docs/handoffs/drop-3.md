# Drop 3: the 2024 final exam and the video's demo day (Sun Nov 15, 2026, ~12:45 PM)

**For:** the app builder (the Claude Code session building the app on branch `app` on this Mac). Merge `main` into
`app` to get the files. 2024 has been opened, once, and the model is frozen. Nothing about the file format changes.

## New files

- **`data/scores_2024.json`:** every day of 2024 (366 days), same format as `scores_2023.json`. The model was trained
  on 2021 to 2023 and never saw 2024, so these are the numbers for the video and the finals. Header: `"year": 2024`,
  `"model": "D (boosting)"` (as in 2023), `"alert_threshold": 1.12`, `"alert_weather_only": true`. Same 850 roads in
  the same order, same `actual_level` roads (I-20, I-30, I-35E, I-635, US 75). Drop 2.2 (`docs/handoffs/drop-2.2.md`)
  already changed the alert lists to rain or ice days only, and 2024 follows the same rule: `alert` is empty on days
  with no rain and no ice.
  - **Alerts:** on 79 days (2023: 55) and 7,772 flagged road-days (2023: 5,606), at most 127 roads in a day.
  - **The line is 1.12, not 1.14.** Same rule as the contract (the top 10% of the model's predictions on its training
    years), but for the final exam the model was retrained on 2021 to 2023, so the line came out at 1.12. Don't
    hard-code 1.14.
- **`docs/demo/index.html`:** the offline score viewer now holds 2023 and 2024, with a year picker. It opens on 2024
  and its demo day, Sep 23. Deep links work for 2024 too, for example `index.html#2024-09-23`. It's built from the same
  `data/` files the app reads, so it's a quick way to check app test 2.
- **`docs/figures/fig9_final_exam_2024.png`:** 2024 next to 2023, plus the alert's impact. For the video's "beats a
  simple guess" part, not for the app.

## The demo day for the video

The notebook picked these days with the same rules as 2023, from the weather and the predictions only, never from
crashes.

- **Rain day: Mon Sep 23, 2024**, the main demo day (the first rain after a dry spell with the highest predicted
  scores). It came after 11 dry days: 17 mm, with thunder and fog. Reasons in the file: "First rain after 11 dry
  days", "Rain after 4 hot days", "Heavy rain (17 mm)". 127 roads flagged. Top: I-35E (asphalt over concrete)
  1.66, FM 546 1.64, FM 920 1.64. With the contract's wording the banner reads "Risky stretch ahead: I-35E. 66% more
  crashes than normal on days like today." I-35E's concrete stretch (1.45) is flagged too.
- **Thunderstorm day: Sat Apr 20, 2024.** 59 mm, with thunder and fog. Reasons: "Heavy rain (59 mm)",
  "Thunderstorms", "Fog". 127 roads flagged. Top: I-30 3.74, President George Bush Turnpike 3.44, Spur 557 3.26. What
  really happened on the 5 busiest roads: I-20 and I-35E far higher than normal, US 75 much higher, I-30 higher, I-635
  about normal.
- **Dry day: Wed Jan 17, 2024**, 0 roads flagged (the model predicted below normal everywhere, top road 0.73, and as
  a dry day it's outside the rain-or-ice rule anyway). **It was not a calm day.** It's one of the model's five worst
  days of 2024 on the 38 busy roads (see below). Never show it as a calm or safe day.
- **Calm dry day for the "nothing flagged" shot: Mon Aug 19, 2024.** The hottest 2024 day with no rain, fog, thunder,
  ice or holiday and no alerts: 107 F, 10 days since rain, daily score +2%. Picked from weather and predictions only,
  never from what really happened (the rule every demo day follows).
- **Which demo drives in `routes.gpx` pass flagged roads on Sep 23** (the notebook's list):
  - Route 1, along I-35E: FM 66, I-35E.
  - Route 2, along US 75: FM 455, Sam Rayburn Tollway.
  - Route 3, along I-30: FM 551, President George Bush Turnpike, US 80.
  - Route 4, along I-20: I-20, President George Bush Turnpike, SH 360, Spur 408, US 287, US 67.
  - Route 5, along I-635: Dallas North Tollway, I-35E, I-635, IH 635 toll lanes, President George Bush Turnpike.

  The drives themselves are unchanged (they follow the road shapes); only the day changes. Their `<desc>` lines and
  point times still carry the 2023 dates. **Use route 1 for the video:** it drives I-35E, the top road that day (it
  also passes flagged FM 66). On Sep 23 every drive passes a flagged road, so for the "quiet" test (a drive that
  passes nothing flagged) use Aug 19, 2024. Route 1 starts right on the flagged I-35E stretch, so its alert fires on
  the first fix, not half a mile ahead; FM 66 is the flagged road it approaches from a distance.
- **What really happened on the 5 busiest roads on Sep 23:** I-20 and I-635 far higher than normal, I-35E much higher,
  I-30 about normal, US 75 below normal. Their predictions: I-35E 1.66, I-635 1.44 and I-20 1.39 (all three flagged),
  I-30 1.32 and US 75 1.25 (not flagged). 3 of the 5 ran above normal; US 75 is the honest miss again, as on Dec 15,
  2023.

## Jan 17, 2024: the failure, not a calm day

This is the miss the write-up explains. Mon Jan 15 was an ice day (1.8 mm, a low of 11 F, `rare: true`). The model
predicted fewer crashes than normal (its top road only 0.81), so nothing passed the line, and all 5 busiest roads ran
below normal: the freeze probably kept people home. Tue Jan 16 was dry with a low of 12 F, and the 5 busiest roads ran
below normal again. On Wed Jan 17 (dry, low 16 F, high 44 F) the 38 busy roads' combined score was 1.22 against a
prediction of 0.66, with I-30, I-635 and US 75 much higher than normal. Probably people went back out while ice was
still on the roads, and a dry day in the daily weather record shows none of that. The model predicted below normal (top
road 0.73, under the 1.12 line), so the app stayed quiet. The same pattern hit Feb 3, 2023. This is the honest limit: leftover ice after a freeze.

## How the alert did in 2024

- The road-days it flagged ran **+31.0%** above normal (8,223 crashes against a normal of 6,278, so 1,945 extra).
  That's weaker than 2023's +43.1%, but far above the +8.2% for warning on every road whenever it rains (2023: +16.8%).
  All 2024 road-days ran -2.2% against normal.
- On the busy roads it was right 20.9% of the time and caught 23.2% of bad days (2023: 25.7% and 17.3%). Test 6, which
  scores the plan's first-guess rule rather than this one, failed again, as in 2023: right more often than warning on
  every rain day (18.0% against 13.3%), but it caught fewer bad days (29.3% against 39.0%).
- **Rain and the other weather.** In 2023 most of the edge came from whether it rained. In 2024 the rain-only guess
  beat the bar by only +0.9% (773 of 1,000, not real; 2023: +3.0%, real), and Model A beat the rain-only guess by
  +3.5% (982 of 1,000, real; 2023: +0.9%, 802, not real). So in 2024 the other weather columns added real value. If
  the app says where the edge comes from, give the year. This doesn't change the alert rule, which was fixed before
  2024 opened.

## Please do

1. Keep reading `alert` from the file. Don't work the rule out from `pred` and `alert_threshold`.
2. Let the day picker offer the 2024 days, with Mon Sep 23, 2024 as the default demo day.
3. Run app test 2 ("same numbers") on 5 random road-days of 2024.
4. Record the drive for the video on Sep 23, 2024, with route 1. The caption says "Simulated drive".

## Suggestions (your call)

- **Banner wording.** A cold review flagged "40% more crashes than normal on days like today" as sounding like a measured
  fact. On the 38 busiest roads, the model's typical miss for one road on one day was 0.573 in 2024 (2023: 0.574;
  quieter roads are even more random day to day), so the number is a heads-up, not a promise.
  Something like "Risky stretch ahead: I-35E. Expect more crashes than usual today." reads more honestly. The exact
  score can stay on the map screen.
- **Name the stretch next to "what really happened".** Each level is for one stretch (the ids in `actual_level`), and a
  road's other stretches can score differently. On Sep 23 the I-35E level is for the same stretch the banner names, but
  the flagged I-30 (1.62) is its asphalt stretch, while the I-30 level is for its concrete stretch (1.32, not flagged).
  US 75 is the same: its flagged stretch (1.49) is asphalt over concrete, while its level is for its concrete stretch
  (1.25, not flagged). Showing "I-30 (concrete)" next to the level keeps them apart.

## Unchanged

`roads.geojson`, `routes.gpx`, `sample.json`, `scores_2023.json`, the alert rule as Drop 2.2 left it (line + worst 15%
of roads that day, at most 127 roads, only on days with rain or ice; only the line's value in the 2024 file differs)
and the contract in `docs/app-data-contract.md`.
