# The iPhone app: design (Sun Nov 15, 2026, ~12:20 PM)

> Written before the build: some details changed while building. `app/README.md` and the code are current.

Decided with the user in Claude Code, from mockups in the browser and the user's whiteboard sketches. This replaces
CLAUDE.md section 6 where they differ. The teammate first planned for the app is not building it any more: the user and
Claude Code build it in `app/`.

## Why it exists

The hackathon judges never install the app. They see it in the 2-minute video, and maybe live at the finals. The app's
job is to make the brain's daily road scores feel real to one driver: a notification drops in over Apple Maps as you
approach a road the model flagged today, and the app explains why the day and the road are risky. The model is the
project; the app shows what the model says, honestly.

## Goals

1. A phone notification ("Approaching risky road / I-35E · 89% more crashes than normal today") that arrives while
   Apple Maps is in front, driven by real Core Location updates and the alert rule below. This is the video's main shot.
2. A word-led home screen: a few words
   on a quiet page, each opening one page, with the tapped word becoming that page's title.
3. Color and motion from the day's real weather: animated weather symbols fill the home page and move to the border on
   inner pages.
4. Every number on screen comes from `data/` exactly (app test 2).

## Non-goals

- No live "today" mode, no live weather, no server, no network calls of any kind.
- No navigation, no route input.
- No Live Activity (stretch only, after everything else works).
- No accounts, settings screens, onboarding beyond the two permission prompts.

## Anti-goals (fails even if it works)

- Looks AI-made or template-like: no pills, chips, row dividers, boxed cards, gradient backgrounds, eyebrow labels,
  emoji. (The user's notes on what makes an interface look AI-made, applied by direction, not to the letter.)
- Says more than the data supports. The model gives a score per road per day, not a reason per road; the app never
  invents one. No claim that a road "will" have crashes.
- Shows a raw crash count, or a name, school or face (TxDOT terms; round 1 is judged blind).

## Constraints

- Native iOS, Swift and SwiftUI, a brand-new Xcode project in `app/` (hackathon rule: nothing copied from any
  older app). Xcode 27.2, iOS 27.2 SDK, simulators available, no physical iPhone connected right now.
- The app reads only `data/roads.geojson`, `data/scores_2023.json` (and `data/scores_2024.json` once Drop 3 exists) and
  `data/routes.gpx`, in the formats fixed by `docs/app-data-contract.md`. Read road ids from the files; never hard-code.
- Location never leaves the phone and is never saved (app test 9).
- Time: build window until about 2:15 PM, video shot planned for 2:30 PM, submission v1 by 5:30 PM.
- Credits: Archivo (SIL Open Font License), Apple frameworks and SF Symbols.

## Approaches

There was one sensible way to build it, so the choices below are inside it.

- **Platform.** Native SwiftUI (the team's call on Nov 14). A web app or cross-platform toolkit can't send the background
  notification over Apple Maps, which is the whole demo.
- **How the video's drive is simulated (Claude Code's call).**
  - *Chosen: the Simulator's own location route.* `xcrun simctl location <device> start --speed=29 <waypoints>` feeds
    real Core Location updates to the whole simulated phone, so Apple Maps and our app follow the same route and our
    real alert code fires the real notification. Waypoints come from `routes.gpx`. On a real phone the same effect comes
    from Xcode's GPX location simulation.
  - *Also built: an in-app "Simulate a drive"* on the Map page that replays a route from `routes.gpx` through the same
    alert code, with a moving dot on the map. It's the backup if the Simulator route misbehaves, and it runs app tests
    3 to 6.
  - *Rejected:* faking the notification with a timer. It wouldn't prove the alert code works, and the brief asks for
    honest results.
- **Notification type (Claude Code's call).** A local notification (`UNUserNotificationCenter`) with the Time Sensitive
  interruption level, so it can break through Focus (including Driving Focus) when the user allows it. No push server.
  iOS draws it; we choose the title, body, sound and app icon.

## The look (decided)

- **Font:** Archivo at its widest setting (width axis 125), bundled in the app. Everything uses it. Sizes: greeting
  34 bold, home words 38 semibold, page titles 28 bold, body 16 to 17, captions 13.
- **Colors:** ink `#17171B`, caption gray `#6D6D78`, risk red `#D42F25` (only for "above normal" numbers and flagged
  roads on the map, map lines `#E2342E`), calm green `#2F8A57` (a below-normal score), live green `#22A55B` (the
  "watching" dot only).
- **Background:** a flat, soft tint of the day's weather. Rain `#EAF2FC`, ice `#E9F6F9`, dry `#FBF5EA`. No gradients.
- **Weather tiles ("soft tiles"):** the day's weather as white 76 pt tiles (corner radius 22, a soft blue-gray shadow),
  each holding one colored SF Symbol about 40 pt tall: rain blue `#2D7FF9`, ice cyan `#3BB7E0`, fog gray `#9AA3B2`,
  sun `#F5A623`, asphalt `#3A3F47`, lane yellow `#F5C518`, clouds `#C9DAF5` (storm clouds `#8FA6C8`), umbrella
  `#1F5FD6`; never red. Home shows 7 tiles, all different, chosen by the day's `weather`, `rare` and `reasons`: rain
  (storm cloud on thunder days, drop, umbrella, car, road, a hot thermometer after "Rain after N hot days" else drizzle,
  wind), ice (snowflake, cold thermometer, snow cloud, car, road, warning sign, wind) or dry (sun, hot thermometer,
  sun-and-cloud, car, road, sunglasses, wind); fog swaps the wind for a fog cloud. Their spots come from the approved
  mockup as fractions of the screen, two cut off by the edge, and clear the greeting, the words and the bottom line
  from the iPhone SE up. Inner pages keep 3 of them, the same size, half cut off at the edges (right edge at 40% of the
  height, left edge at 72%, bottom-right corner); the page column is 48 pt in (less on phones under 396 pt wide) so
  they never touch the text, and on the Map page the two edge tiles hide behind the map.
- **Motion:** each tile floats ±5 pt, 7 s each way, neighbours in opposite directions and out of step; no spinning.
  Tapping a word: the 3 kept tiles glide to the edges (a spring, 25 ms apart) while the other 4 slide out past the
  nearest edge and fade, and the word moves into the page title (matched geometry). Tapping the title reverses it.
  With Reduce Motion on: no float, no glide, just a crossfade.
- **No** pills, row dividers, boxed cards, or eyebrows. Rows are separated by space. The only card is the road popup.

## Screens

**Home.** "Good morning" (or afternoon/evening, by the phone's clock; never a name). Three words, centered: Daily
score, Roads to avoid, Map. Weather tiles around them. One quiet line at the bottom: a live-green dot and "Watching
for risky roads · Dec 15, 2023" when location is allowed (While Using or Always) and updating; otherwise "Location
off · tap to turn on". Tapping the date part opens the day picker.

**Day picker (sheet).** The demo days as quick picks first (2023: Dec 15 rain, Jan 30 ice, Oct 25 storm, Aug 25 dry;
2024: the dates the notebook prints in step 14, once Drop 3 lands), then a calendar limited to the loaded year(s). The
chosen day is remembered between launches. Default: Dec 15, 2023 until Drop 3, then the 2024 rain demo day.

**Daily score.** Title "Daily score" with the day's score beside it: mean of all roads' `pred` minus 1, as a signed
whole percent (red when above 0, green when below). Under it: "Above (or below) a normal day, across 850 DFW roads".
On rare days add "Ice is rare, so trust this less". Then the day's numbers in a row with no boxes: rain ("17 mm",
whole millimetres, "0.3 mm" for a trace under 1 mm), days since rain ("12") and the high ("79°F"), each 28 bold over
a 13 pt label, never wrapped. Then "Why" and one bullet per entry in `reasons` (18 semibold), each with one measured
fact under it from `weather` (14 pt: rain mm, the last rain's date, fog or thunder reported at DFW Airport, "Counted
from DFW Airport daily highs" for hot days). A dry day with no reasons shows facts only ("No rain for 40 days", "Hot,
110°F"). Last, "Busiest roads: predicted, then what happened": one row per road in `actual_level` (the 5 busiest
stretches), highest `pred` first, as the name, the "+N%" and the level without "than normal" ("much higher"), looked
up by road id; under it, "What happened is a level we worked out from TxDOT's crash records for that road, never a count." The page scrolls when
Dynamic Type makes it tall.

**Roads to avoid.** The day's `alert` roads, worst `pred` first, as "name" and red "+N%" where N = round((pred-1)×100).
When two rows share a display name (two surface stretches of US 75), add a 13 pt caption with the surface. Empty state
on a day with no alerts: "Nothing to avoid today." Tapping a row opens the road popup.

**Road popup (sheet).** Road name and its +N%. "Why", with at most four bullets, all facts:
1. The day's top reason, with its measured fact.
2. Surface: for asphalt over concrete, "Asphalt laid over concrete. On first rains this surface jumped more than plain
   concrete on the same highways (2021 to 2024)" (research claim 2, which held on 2021 to 2024). Other surfaces:
   the surface name only. None for city streets and toll roads (no surface data).
3. Build: speed limit, lanes, daily traffic, each only if present ("70 mph, 4 lanes, about 76,000 cars a day").
4. For the 5 roads with `actual_level`: "What really happened: far higher than normal" (from `actual_level_names`).
Last line, caption: "Measured: busy enough to test on its own" or "Estimated from roads built like this one".

**Map.** Title "Map". Apple Maps (MapKit for SwiftUI) with only the day's flagged roads drawn, as `MapPolyline`s in red,
4 pt. Every other road is ordinary Apple Maps. Shows the user's location. A "Simulate a drive" button picks one of the
five routes and replays it (moving dot, real alert code). It always uses the **selected day's** `alert` list, like a
real drive would; the route picker shows how many of that day's flagged roads each route passes, computed in the app
(the `<desc>` dates are only labels). App test 3 runs routes 1 to 4 with Dec 15, 2023 selected and route 5 with
Aug 25, 2023 selected. Note in the code that road shapes are averaged crash
positions, so they can sit slightly off the real road when zoomed in; the map's default zoom is city level.

**Notification.** Title "Approaching risky road". Body "{display_name} · {N}% more crashes than normal today". Default
system sound, Time Sensitive. Tapping it opens the app on that road's popup.

## The alert rule

Checked on every location update, for the selected day's `alert` roads only:
- moving faster than 20 mph (8.9 m/s; use the fix's speed, or the speed between the last two fixes when invalid);
- within 0.5 mile (805 m) of the road's nearest point (distance to the polyline, not to its vertices);
- heading toward it: already on it (within 60 m of the line, since the shapes are approximate), or the distance to
  that road went down since the previous fix, or the angle between the course and the bearing to the nearest point is
  under 60°;
- armed for that road (see "pass" below).
Fire one notification per road per pass. Never while parked or walking. When several roads qualify at once, alert the
one with the highest `pred` and let the others wait for the next update (no notification storms).

A **pass** (Claude Code's call, after the builder check): after a road alerts, it stays quiet until the car has been
more than 805 m from it **and** at least 10 minutes have gone by. So a drive that starts on I-35E (route 1 does) alerts
on the first fix above 20 mph, and does not alert again for I-35E on the same 20-minute drive.

## Location and permissions

Ask for When In Use first, then Always (two steps, as iOS requires), then notifications. Background location updates
via `UIBackgroundModes: location` and `allowsBackgroundLocationUpdates`. The phone's location is only compared with the
road shapes in memory; nothing is stored or sent.

## Data loading

The repo's `data/` folder is added to the Xcode project as a folder reference, so a new Drop needs only a rebuild. On
launch: decode the GeoJSON and the scores files, check that `road_ids` matches the GeoJSON ids, and build the flagged
polylines per day on demand. If a file fails to decode, show one plain line on home saying so (never crash).

## Testing

- Unit tests (Swift Testing): decoding the real files (850 roads, 365 days, header fields); the daily score and +N%
  math; app test 2 (5 random road-days show exactly the file's `pred`); the alert rule on synthetic tracks (fires
  inside 805 m when approaching above 20 mph; stays quiet when parked, walking, moving away, or inside the 10-minute
  cooldown); the symbol-set choice for rain, ice, dry and fog days.
- In the Simulator: build, run, screenshot every page on Dec 15, Jan 30 and Aug 25; drive route 1 with
  `simctl location start` while Apple Maps is navigating, and confirm the notification arrives with sound.
- App tests 1 to 10 from CLAUDE.md section 6 stay the checklist; 7 (real drive, as a passenger) and 10 (stranger) need
  a real phone and a person.

## Settled after the builder check

- **The approved prototype** is `.superpowers/brainstorm/24109-1794762421/content/alive-prototype-v3.html` (local
  only, git-ignored): symbol positions, sizes, the spring to the border and the word-to-title move.
- **Font source:** the variable `Archivo[wdth,wght].ttf` from Google Fonts' repository (`github.com/google/fonts`,
  folder `ofl/archivo`), with its `OFL.txt`, both bundled in `app/`. Needs the user's OK to download. Fallback if
  anything goes wrong: the system font's expanded width, so the layout still works.
- **Which year the app shows:** it is built and tested on `scores_2023.json` now. `scores_2024.json` has the same
  format; when Drop 3 lands, the app loads it too, and the 2024 quick-pick dates (from the notebook's step 14) are
  added to one small list in the code. The video uses 2024 only if 2024 is opened before the shot; otherwise Dec 15,
  2023, labeled as the practice year.

## Left to the builder

File and type names, exact animation timings, how the day picker's calendar is built, and how the Xcode project is
created, as long as it is new and lives in `app/`.
