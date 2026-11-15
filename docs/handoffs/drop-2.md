# Drop 2: real 2023 scores (Sat Nov 14, 2026, ~10:30 PM)

**For:** Teammate 2. Run `git pull --tags` and look at tag `drop-2`.

## New in `data/`

| File | What's in it | Size |
|---|---|---|
| `scores_2023.json` | **Real** Model D predictions for all 365 days of 2023 and all 853 roads (`made_up: false`). `actual` for the 38 busy roads only. `alert_threshold` 1.14, `alert_top_share` 0.15 | 2.1 MB |
| `sample.json` | Rewritten with the new alert rule (still made up) | 0.09 MB |

These are honest predictions: the model learned from 2021 and 2022 only, and had never seen 2023.

## One format change: the alert rule (`alert_top_share`)

With the old rule, a heavy-rain day flagged about **780 of the 853 roads**. A driver would get pinged on every road, which defeats the point. The new rule keeps a road only if it is above the line **and** among the worst 15% of roads that day. In practice that's at most **127 roads** on the worst day and **0 on a dry day**. On 2023 it was also right more often.

- **You don't have to compute anything:** keep reading `alert`. It already follows the new rule.
- **The header has one new field,** `alert_top_share` (0.15). The exact rule is in `docs/app-data-contract.md` if you want to check it.
- **Everything else is unchanged.**

## Three 2023 dates to test with

| Date | What happened | What the app should show |
|---|---|---|
| **Dec 15, 2023** | First rain after 14 dry days, 15 mm. **Best demo day:** the busy roads ran 1.81× normal against a prediction of 1.57× *(per-road measured scores removed on Nov 15 under TxDOT's terms; see Drop 2.1)* | 127 alerts. Reasons: "First rain after 14 dry days", "Heavy rain (15 mm)", "Fog" |
| **Oct 25, 2023** | 64 mm thunderstorm, the day after rain. **An honest miss:** predicted 1.78×, actual 1.21× on busy roads. | 127 alerts. Good for showing predicted vs actual honestly |
| **Aug 26, 2023** | Dry, ordinary day | 0 alerts. Nothing should chime |

## What you can build now

- Swap `sample.json` for `scores_2023.json` and the map shows real colours.
- **"Predicted vs what really happened"** on busy roads (`actual`). This is the strongest thing for the video.
- **Rare-day banner:** 2023 has 6 ice days with `rare: true`.
- **App test 2 (same numbers):** pick 5 random road-days and check the app shows exactly the `pred` values in the file.

## Heads-up

- The 2024 file (Drop 3) is what the video uses. It comes Sunday ~11 AM, after Teammate 1 opens 2024.
- The model may get one more upgrade before then (a road-chemistry layer). If it does, you'll get a fresh `scores_2023.json` in the **same format**, with no code changes on your side.
