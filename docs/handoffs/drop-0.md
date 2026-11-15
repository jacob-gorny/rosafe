# Drop 0: start the app (Sat Nov 14, 2026)

**For:** Teammate 2. **From:** Teammate 1 and Claude Code (the brain).

## What the project is, in two lines

The brain (a notebook in `notebook/`) gives 856 DFW roads a danger score for each day: 1.0 is a normal day, 1.4 means 40% more crashes than normal. Your app runs in the background and chimes when the phone is driving toward a road the brain flagged that day. It never navigates and never asks for a route. The full project log is `CLAUDE.md` in the repo root. Read sections 6 and 7 first.

## How we hand things over

- You own `app/`. We never touch it. You never edit `notebook/`, `data/` or `docs/`.
- The app only ever reads the files in `data/`. Their formats are fixed in [`docs/app-data-contract.md`](../app-data-contract.md). If a format ever changes, there's a note in `docs/handoffs/` first.
- Each time a piece of the brain is finished and tested, it's pushed as a commit starting `Drop N:`, tagged `drop-N`, with a note in `docs/handoffs/drop-N.md` saying what's new and what you can build with it. Run `git pull --tags` to get it.

| Drop | Files | What you can build | Expected |
|---|---|---|---|
| 0 (this) | the formats | Xcode project, data models that decode the formats | now |
| 1 | `roads.geojson`, `sample.json`, `routes.gpx` | Map of all roads coloured by sample scores, day picker, ranked list, simulated drive, alert rule | Sat night |
| 2 | `scores_2023.json` | Real 2023 scores, "why it's flagged", rare-day banner, app test 2 | Sun early morning |
| 3 | `scores_2024.json` | The demo day for the video, final alerts, app tests 3 to 8 | Sun ~11 AM |

## What you can do right now

1. Accept the GitHub invite to `jacob-gorny/rosafe` and clone it.
2. Make a **new** Xcode project (SwiftUI, iOS) inside `app/`. Nothing copied from older apps (hackathon rule).
3. Write `Codable` structs for the scores file and a GeoJSON reader for `roads.geojson`, straight from the contract. Until Drop 1 lands, test them on a tiny hand-made file with 2 roads and 2 days.
4. Get it running on your phone from Xcode (app test 1: opens in under 3 seconds).

## Things to know

- **856 roads, three layers:** state roads (258), toll roads (8) and busy city streets (590). Only 38 are "busy" (`checked: "measured"`). The rest are "estimated from roads built like this one". Show that difference somewhere.
- **`actual` only covers busy roads.** That's on purpose (TxDOT's data terms), not a bug.
- **On `rare` days** (ice, hail, freezing), show "rare conditions, low confidence".
- **Alert text:** "Risky stretch ahead: {display_name}. {N}% more crashes than normal on days like today."
- **The alert rule (first guess, tune it):** fire once when moving faster than about 20 mph, within half a mile of a flagged road, and heading toward it. Stay quiet for that road for 10 minutes.
- **Check Apple's current docs** before writing MapKit in SwiftUI, background location with "Always" permission (asked in two steps), and how Driving Focus treats notifications.
- No keys, passwords or signing files in the repo.
