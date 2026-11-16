# Same Rain, Different Road: handoff to Claude Code

> **For readers of the public repo:** this is the team's working log, as written over the weekend. Some files it names (drafts, plans, the form answers, the overnight log, the video guide, the copy tool, the app worktree) stayed in the private working repo, and `data/stretches.geojson` became `data/roads.geojson`.

Written Sat Nov 14, 2026, 8:05 PM Central, from the planning chat in the Claude project "Veritas AI Hackathon". This file is the full log of what was decided and checked. It lives in the repo root as `CLAUDE.md`, so Claude Code loads it automatically. Where it disagrees with any older doc, this file wins.

**Status (Nov 15, about 12:35 PM):** notebook steps 1 to 16 built; a cold audit (47 findings, 41 confirmed) and a verification round were run and every finding was fixed or documented (`docs/audit-2023.md`). Drops 0 to 2.2 sent. Teammate 2's Mac broke, so since late morning the app is built on Teammate 1's Mac by a Claude Code session on branch `app` (worktree `.worktrees/app`). Step 13 (road-chemistry layer) is coded and waits on `NACE_API_KEY`; today's plan skips it. Overnight: more tests, an offline score viewer (`docs/demo/index.html`), drafts of the README, write-up and video script (`docs/drafts/`), judge prep, and 2024-ready demo dates and fig9 (`docs/overnight-log.md`). About 11:50 AM: alert rule B2 applied, so the app alerts only on days with rain or ice (section 6). **About 12:25 PM: 2024 opened, once.** The final exam ran clean and 59 tests pass. No model or rule changes after this point. On 2024, Model A beats the bar by +4.3% (real, 972/1000; 2023: +3.8%), and the shipped alert's flagged road-days ran +31.0% above normal (2023: +43.1%), against +8.2% for warning on every road when it rains. Results: the notebook's step 14 and `docs/figures/fig9_final_exam_2024.png`; summary in section 13. Plan for today: `docs/submission-plan.md`. Build plan: `docs/superpowers/plans/2026-11-14-brain-build.md`. **About 4:30 PM: the public repo is live at https://github.com/jacob-gorny/rosafe** (one commit made from main by the copy tool, after an independent pre-publish audit; section 13).

---

## 1. The project in plain words

1. Take five years of Dallas-Fort Worth crashes and daily weather.
2. Train a model that says, for each road and each day, "expect more crashes than usual here today".
3. Prove it on a year the model never saw, next to a simple guess.
4. An iPhone app sits in the background and chimes when you're driving toward a road the model flagged.

**One sentence (the organizers' format):** Our project helps a Dallas-Fort Worth driver on a rainy day by taking the weather, the last few weeks of weather and how each road is built, and giving back a warning before they reach a road that's riskier than normal that day.

**The decision it supports:** slow down on that stretch, leave earlier, or take the other road. The driver decides. One line in the write-up can say TxDOT traffic centers could use the same scores.

**The question we test:** does the same rain cause more crashes after a dry spell or a hot stretch, and does that depend on how the road is built?

**Team:** Teammate 1 builds the brain (model, notebook, tests, write-up). The iPhone app is now built by Teammate 1 with Claude Code (decided Nov 15, ~12:00 PM; Teammate 2 no longer builds it). Both must be able to explain both halves.

## 2. Hackathon facts

- Veritas AI International High School Hackathon. Track: **Climate**.
- **Deadline: Sun Nov 15, 2026, 10:59 PM Central.** Unlimited resubmits, the last one counts. Plan: version 1 submitted by 5:30 PM Sunday.
- Finalists emailed Wed Nov 18. Live finals Sat Nov 21, 10:00 AM Central: 5 minutes, then judge questions.
- Submission form: https://airtable.com/appypCyHN77hElIcS/shrXA5VBFdugmoXl6
- Briefs: https://highschoolhackathon.org/briefs.html
- Sample submission notebook (ScamCheck): https://colab.research.google.com/drive/1j240YFecsAoysQDcQg3VJfgtmLgEdhAy

**What to submit**
- Code: a Colab notebook or GitHub repo that anyone with the link can view, with outputs saved. We use a public GitHub repo.
- Write-up: about one page on the organizers' template (section 12).
- Demo video: up to 2 minutes, optional but recommended. Unlisted YouTube or Drive link.
- Form: team details, track, one-sentence pitch, links, what we added, credits.

**Rules that matter**
- All work happens this weekend. New repo, new Xcode project, nothing copied from an older project.
- AI must do the main job of the project. An app built with AI coding tools does not count on its own. So the model and its tests come first, and the app only shows what the model says.
- Coding assistants are allowed. Every dataset, library and AI tool must be credited, and both teammates must understand every part and be able to explain it to judges.
- Public or synthetic data only, no personal info.
- Report the results you actually got, weak ones too. Results that look too good usually mean test data leaked into training.
- Round 1 is judged blind: no names, school or faces in the video.
- Every project answers four questions: who is it for, what goes in and what comes out, does it beat a simple baseline, where does it fail. All results on test data the model did not see.
- Climate track musts: one location, train on earlier dates and test on later ones (never shuffle days), compare with the persistence baseline (tomorrow equals today), say what decision the prediction supports and who makes it.
- Judged on technical quality, impact, creativity, clarity.

## 3. The data (checked, in hand)

### Crashes
- Source: a public TxDOT ArcGIS layer titled "TXDOT Statewide Bicyclist Involved Crashes". Despite the title it holds every Texas crash, 2020-01-01 to 2024-12-31 (3,088,450 rows), with the full CRIS public-extract fields in lower case.
- Layer: https://services.arcgis.com/KTcxiTD9dsQw4r7Z/arcgis/rest/services/TXDOT_Statewide_Bicyclist_Involved_Crashes/FeatureServer/0
- Item page: https://www.arcgis.com/home/item.html?id=93b84dccf1ec4440b1475c4290ac21ff
- Checked against TxDOT's official yearly death totals: 2023 matches exactly (4,291), 2022 is 4,410 vs 4,407, 2024 is 4,160 vs 4,150.
- **Terms: copyright TxDOT, no commercial use, no passing the data to third parties without TxDOT's written consent.** So the raw file never goes in the public repo or any public link. The notebook downloads it when it runs. Outputs show charts and totals, at most 5 raw rows. `.gitignore` blocks the file from the first commit.
- Download: `get_dfw_crashes.py` (sent with this file). It pulls the 12 DFW counties in a few minutes and saves `dfw_crashes_2020_2024.csv.gz` (25.7 MB). How it works: get all object ids with `returnIdsOnly`, then POST them in chunks of 2,000 on 8 threads. The layer returns at most 2,000 rows per request.
- Counties (TxDOT numbers): 43 Collin, 57 Dallas, 61 Denton, 70 Ellis, 111 Hood, 116 Hunt, 126 Johnson, 129 Kaufman, 184 Parker, 199 Rockwall, 220 Tarrant, 249 Wise.
- Columns kept (crash-level only, no names, plates or narratives): crash_id, crash_date ('YYYY-MM-DD' string), crash_time, day_of_week, cnty_id, city_id, onsys_fl (0/1), surf_type_id, base_type_id, func_sys_id, rural_urban_type_id, road_cls_id, hwy_sys, hwy_nbr, hwy_sfx, street_name, control, section, dfo, crash_speed_limit, adt_curnt_amt, nbr_of_lane, wthr_cond_id, surf_cond_id, light_cond_id, crash_sev_id, at_intrsct_fl, road_constr_zone_fl, bridge_detail_id, tot_injry_cnt, death_cnt, latitude, longitude, plus county.

**Numbers to assert in code**
| What | Value |
|---|---|
| Total rows | 679,621 |
| By year 2020 to 2024 | 123,267 / 142,028 / 140,634 / 140,541 / 133,151 |
| On state-maintained roads (onsys_fl = 1) | 356,024 (52%) |
| With a surface code | 329,253 |
| Surfaced, by year 2020 to 2024 | 59,078 / 69,481 / 67,094 / 68,034 / 65,566 |
| Days present | all 1,827 |
| Rows missing latitude or longitude | about 7% |
| crash_time nulls | 0 |

**Surface codes** (the data uses newer codes than TxDOT's published 6-code lookup)
- 1 continuously reinforced concrete, 2 jointed reinforced concrete, 3 jointed plain concrete, 4 thick asphalt, 7 asphalt over concrete. These five were verified by matching 308 crashes against the City of Lewisville's labelled layer with zero mismatches.
- 5 intermediate asphalt, 6 thin asphalt, 10 thin-surfaced or seal coat. From TxDOT's standard list, not cross-checked.
- Four groups: **concrete** (1, 2, 3), **asphalt over concrete** (7), **asphalt** (4, 5, 6), **surface-treated** (10). Crashes per day: about 83 / 65 / 28 / 4.5. Shares: 46% / 36% / 15% / 2.5%.
- City streets and toll roads have no surface code, lane count, traffic count or `dfo`. They are in the project (see "Road scope" below) but scored from road class and speed limit only. 42% of surfaced crashes are on state roads that are not freeways (for example SH 289 Preston Road, much of Loop 12).
- func_sys_id: 1 interstate, 2 other freeway, 3 principal arterial, 4 minor arterial, 5 major collector.

**Roads**
- Road name = hwy_sys + hwy_nbr + hwy_sfx (IH 35E, IH 35W, SH 289). `street_name` is only the code (like 'SH0289'), so human names (Preston Road) need a hand check.
- A **road stretch** = one road plus one surface group. 33 stretches on 24 roads average at least one crash a day. Busiest: IH 35E asphalt over concrete, about 17 a day. 72 stretches average at least 0.5 a day.
- Six roads have long stretches of both concrete and asphalt over concrete with similar traffic and speed limits: IH 30, IH 635, IH 20, IH 35E, IH 35W, SL 12. Comparing surfaces on the same road is the fairest surface test.
- `dfo` is distance along the road in miles. `control` + `section` mark one piece of a state road.

**Road scope (decided Nov 14, 8:30 PM: 855 roads in three layers)**
Chosen on 2021 to 2023 crash counts only (never 2024), then frozen. Built and asserted in notebook step 3: **855 roads = 258 state + 8 toll + 589 city** (590 before the audit split county roads outside any city by county). "Busy" = at least 1 crash a day in 2021 to 2023: 35 state stretches and 3 toll roads (on 2020 to 2024 counts it was 33 state stretches; we use 2021 to 2023 so 2024 plays no part).
- **State roads:** a road plus surface stretch with at least 50 crashes in 2021 to 2023 (about one every three weeks). 258 stretches on 170 roads, 98% of surfaced crashes. Inputs: surface, road class, speed limit, lanes, daily traffic. The 35 busy stretches are the ones tested road by road.
- **Toll roads:** `road_cls_id` 6, on and off the state system, grouped by road (Dallas North Tollway, President George Bush Turnpike, Sam Rayburn Tollway, Chisholm Trail Parkway, 360 Tollway, TX 121 Express). About 9 crashes a day in all. 6 = tollway was checked: 95% of crashes on toll-named streets carry it. Most on-system crashes with no surface code (SH 121, SH 190, SH 161) are toll lanes and belong here. Names need merging ("DALLAS NORTH TLWY" and "DALLAS NORTH TOLLWAY").
- **City streets:** off-system `road_cls_id` 5 (city street) and 4 (county road), keyed by `street_name` + `city_id`, at least 50 crashes in 2021 to 2023. 590 pieces, 54% of city-street and county-road crashes. Inputs: road class and speed limit only. About 10 class and speed combinations cover 85% of these crashes, so similar streets get the same score every day.
- **Left out:** `road_cls_id` 9 (its top names are mall and shopping streets like N Town East Blvd, so probably parking-lot crashes; check TxDOT's lookup), 7 and 8 (tiny), speed limit -1 (unknown), and off-system crashes coded interstate or state highway with no state road fields.
- Say "855 DFW roads: state highways, toll roads and the busiest city streets", never "all DFW roads".

**Year-to-year checks already run**
- Per day, 2024 runs about 4% below the 2021 to 2023 average.
- Per day, October 2023 ran about 16% above February 2023 (seasons matter).
- 2024 monthly counts are complete through December.
- Construction-zone share is stable, 6.4% to 7.5% a year.
- No busy stretch changed by more than 30% in 2024 against its 2021 to 2023 average.

### Weather
- NOAA GHCN-Daily, DFW Airport: https://www.ncei.noaa.gov/data/global-historical-climatology-network-daily/access/USW00003927.csv
- Use every column that has data for 2020 to 2024 (decided Nov 14, about 8:45 PM; fill checked by Claude Code). Units are NOAA's: tenths of mm, tenths of degrees C, tenths of m/s, tenths of hPa. Measured, not modelled.
  - Over 99% filled (up to 8 blank days in humidity, pressure and wind, carried forward from the day before): PRCP rain, SNOW snowfall, SNWD snow depth, TMAX, TMIN, ADPT dew point, AWBT wet-bulb, RHAV / RHMN / RHMX humidity, ASLP / ASTP pressure, AWND average wind, WSF2 / WSF5 fastest 2-minute and 5-second wind, WDF2 / WDF5 their directions (encode as sine and cosine).
  - Day flags (blank means no): WT01 fog 479 days, WT02 heavy fog 43, WT03 thunder 292, WT08 smoke or haze 161, WT04 sleet or small hail 13, WT05 hail 12, WT06 glaze or rime 15, WT07 dust 5, WT09 blowing snow 1.
  - Empty for 2020 to 2024, so not used: TAVG, ACMH, ACSH, FMTM, GAHT, PSUN, TSUN, WDF1, WDFG, WESD, WSF1, WSFG, WV03, WT10 to WT22 (the "rain" flag WT16 is never set). PGTM is only 2% filled, so not used.
  - Flags under about 20 days are too rare to learn alone, so they also feed one combined **ice** flag (sleet, hail, glaze, blowing snow, snow, or a freezing day) and dust joins smoke or haze. Each column still has to earn its place on 2023.
- Rain day = at least 0.3 mm (0.01 inch).
- Do not use Open-Meteo for rain history. It is modelled and shows too many rain days.
- Do not use the crash file's own weather or wet-road columns as model inputs. An officer fills those in after a crash.
- Hourly rain for the same station (upgrade, only the 2024 file was checked): https://noaa-global-hourly-pds.s3.amazonaws.com/2024/72259003927.csv, field AA1.
- No live weather source has been checked yet for the app's "today" mode.

**Numbers to assert in code**
| What | Value |
|---|---|
| Days 2020 to 2024 | 1,827 |
| Rain days 2020 to 2024 | 405 |
| Rain days 2021 to 2024 | 311 |
| Rain after 7 or more dry days, 2021 to 2024 | 50 |
| Rain the day after rain, 2021 to 2024 | 132 |
| May to September rain days, 2021 to 2024 | 118 (45 after 3 or more hot days in the prior 7, 73 others) |
| 2024 alone | 92 rain days, 10 after 7 or more dry days, 13 hot-then-rain |
| Days at 95 F or hotter, 2020 to 2024 | 334 |
| Freezing days (rain or snow, low at or below 0 C), 2020 to 2024 | 3 / 4 / 7 / 4 / 5 |

## 4. The brain: design

- **Two daily tables from one function:** crashes per day per surface group (4 units) and per road (855 units across the three layers in "Road scope"; 1,562,085 rows). Days with no crashes get a 0.
- **Danger score** = crashes on that unit that day divided by its normal. Normal = the unit's average daily count over the previous 8 weeks, times a weekday factor learned from the training years. 1.0 is a normal day, 1.4 means 40% more than normal. Also score the simpler fixed normal (weekday average from training years) on 2023, and say which one was kept and why. Quiet roads (under about 1 crash a day) use the fixed normal, because 8 weeks of a quiet road is only a handful of crashes. Set the exact cutoff on 2023.
- **Split:** practice on 2023 (train on 2021 and 2022) and make every choice there. Then train on 2021 to 2023 and test on 2024 **once**. Leave 2020 out because COVID changed traffic, and say so.
- **Weather columns:** rain today (mm), rained today, days since last rain, rain over the last 7 days, high temperature, hot days in the last 7 (95 F or more), dry days before today's rain, hot days before today's rain. Plus every NOAA column listed under Weather (fog, heavy fog, thunder, haze, ice, wind, gusts, wind direction, humidity, dew point, wet-bulb, pressure, low temperature, snow, snow depth), and ice in the last 3 days. History columns use only days before today. With this many columns, Models A to C use ridge regression (linear regression with a penalty that stops it chasing noise); set the penalty on 2023.
- **Flags:** freezing day, holiday (US federal holidays plus the day after Thanksgiving). Show results with and without those days.
- **Simple guesses (baselines):** tomorrow's score equals today's (required by the Climate track), same weekday last week, always 1.0.
- **Models, each adding one thing:**
  - A: today's weather. Linear regression on the surface table.
  - B: A plus weather history.
  - C: B, with a separate model per surface.
  - D: random forest on the road table, with B's inputs plus surface, road class, speed limit, lanes and daily traffic. This one scores roads one by one. Toll roads and city streets get "unknown" for surface, lanes and traffic.
- No pretrained model and no AI API inside the product.
- One fixed random seed. Row counts asserted in code. Notebook runs top to bottom in under 10 minutes with outputs saved.

## 5. The brain: tests and pass lines

Set before any results. A test that fails still goes in the write-up.

- **Miss** = average gap between predicted and real score (mean absolute error). 0.10 means off by 10% of a normal day.
- **Gain** = percent drop in miss.
- **Real, not luck** = redraw whole weeks of the test year 1,000 times. A gain counts only if it stays above zero in at least 950.
- **Chance floor** = the miss a perfect model would still have, because crash counts are random. Print it next to every miss.

| Test | Question | Passes if |
|---|---|---|
| 1. The bar | How good is a simple guess? | No pass line. The best baseline becomes the bar |
| 2. Model A | Does today's weather beat the bar? | Real gain on all days |
| 3. Model B | Does weather history help? | Real gain over A on rain days |
| 4. Model C | Does surface help? | Real gain over B on rain days |
| 5. Model D | Does road build help, road by road? | Real gain over C, and D beats the bar on 7 of the 10 busiest roads |
| 5b. Ranking | Do the roads it calls worst in rain turn out worst? | Rank match across the 35 busy state stretches above zero in 950 of 1,000 |
| 5c. Quiet roads | Does it work on roads too quiet to test one by one? | Grouped by layer (quiet state roads, toll roads, city streets), real gain over the bar in each group. Report each group separately |
| 6. Alert | Is the alert worth having? | Right more often than "alert every time it rains" while catching as many bad days. Bad day = worst 10% of training days. Alert = model's top 10% |
| 7. Too good | Is the test year leaking in? | If the miss drops by half or more, assume a bug |
| 8. Runs clean | Can a judge rerun it? | Restart and run all, no errors, under 10 minutes |
| 9. Scrambled weather | Does the edge come from weather? | With weather shuffled across days, the gain falls to about zero |
| 10. Practice against real | Did we tune too hard on 2023? | 2024's gain has the same direction and is at least half of 2023's |

Also report an **impact number**: crashes on alert days minus what a normal day would have brought.

**Three claims from earlier research** (this replaces the "team writes three predictions" step, which Teammate 1 dropped at 8:00 PM). Write them in the notebook's first cell before anything compares crashes with rain. The planning chat never looked at crash-versus-rain results, so nothing here is tuned to the answer.
1. First rain: rain after 7 or more dry days brings a bigger jump in crashes than rain the day after rain. Background: the 2003 UC Berkeley study (link below).
2. Surface: check whether that first-rain jump differs between asphalt-over-concrete and plain concrete stretches of the six two-surface roads. No direction is claimed.
3. Heat: summer rain after 3 or more hot days is worse on asphalt-type surfaces than on concrete. Background: the Texas A&M Transportation Institute note on asphalt bleeding and flushing (link below).

Check each on 2021 to 2024 with 2024 shown alone next to it. A claim holds if the gap has the stated direction in 950 of 1,000 redraws. Report "held", "did not hold" or "too few days to tell". Read both sources before quoting them in the write-up.

## 6. The app: design

A **native iPhone app**. Teammate 1's calls on Nov 14: not a web app, and not a navigation app. The current app design is `docs/superpowers/specs/2026-11-15-app-design.md`; it wins over this section where they differ.

- It runs in the background like Life360. You open it once, allow location and notifications, and forget it. You keep driving with Apple Maps, Google Maps or nothing.
- When you're driving toward a stretch the brain flagged for that day, it chimes and drops a banner over whatever is on screen, for example "Risky stretch ahead: I-30. 40% more crashes than normal on days like today."
- It does not navigate and never asks for a route.
- Opening the app shows a map of DFW with 850 roads coloured by score and why each is flagged. Busy roads are marked "measured"; the rest "estimated from roads built like this one".
- A demo setting makes any 2024 day "today", with that day's weather, scores and what really happened. That's how it gets tested and filmed.
- A simulated drive plays a preset route through the same alert code.

**Stack:** Swift and SwiftUI in Xcode, MapKit for the map, Core Location with "Always" permission and background updates, a local notification with sound for the chime (works with the phone locked and over a maps app), `AVSpeechSynthesizer` for a spoken line when the app is open, the brain's JSON files bundled into the app. No server. Installed on their own phones from Xcode. They have a Mac with Xcode and an Apple Developer account.

**Alert rule (tuned on 2023, Nov 14 ~10:20 PM; rain or ice days only from Nov 15 ~11:50 AM):** a road is flagged when its predicted score is at or above the top-10% line of training predictions (1.14) **and** it is among the worst 15% of roads that day, at most 127 roads (the plan's first guess, the line alone, flagged ~780 of 853 roads on heavy-rain days). **It fires only on days with rain (0.3 mm or more at DFW Airport) or ice** (option B2, section 13). On other days `alert` is empty (`ALERT_WEATHER_ONLY = True` in the notebook, `"alert_weather_only": true` in the scores header). The brain writes the flagged list into the scores files, and the app keeps reading `alert` from them; the exact rule is in `docs/app-data-contract.md`. Fire once when moving faster than about 20 mph, within half a mile of a flagged stretch, and heading toward it. Stay quiet for that stretch for 10 minutes. No alert when parked or walking.

**The alert on 2023, the practice year:** 5,606 flagged road-days on 55 days, with 6,499 crashes against a normal of 4,542 (1,957 extra, +43.1%). Busy roads: right 25.7% of the time, catches 17.3% of bad days. No alerts on dry days; 310 of 365 days have no alert, and a typical rain day flags 127 roads (the cap). The rule was picked on 2023 after comparing several versions, so 2023's numbers flatter it; 2024 is the honest test. Test 6 still reports the plan's first-guess rule (it failed).

**Check Apple's current docs before writing these parts:** MapKit in SwiftUI, background location and "Always" permission (it is asked in two steps), and how Driving Focus treats notifications.

**Judges can't install it by the deadline.** People outside the developer team only get a TestFlight build after Apple's beta review (teammates need no review). So judges see the app in the video and the code in the repo. If there's time Sunday evening, submit a build for review so it might be installable by the Nov 21 finals.

**App tests**
| Test | Passes if |
|---|---|
| 1. Runs | Installs from Xcode on both phones and opens in under 3 seconds |
| 2. Same numbers | 5 random stretch-days match the notebook exactly |
| 3. Right alerts | On 5 simulated routes: a chime for every flagged stretch, none for any other |
| 4. In time | The chime comes at least half a mile before the stretch (about 28 seconds at 65 mph) |
| 5. Once | One chime per stretch per pass |
| 6. Quiet | No alert while parked or walking next to a flagged road |
| 7. Real drive | On a real phone the alert fires for the right road. Tested as a passenger, never by the driver |
| 8. In the background | With the phone locked, and with a maps app navigating in front, the alert still arrives with sound |
| 9. Private | Our code sends location nowhere and saves no history |
| 10. Stranger | Someone new hears one alert and can say what it means within 30 seconds |

**Limits to state:** iPhone only. Judges can't install it this weekend. Until a "today" mode with live weather exists, it can only replay past days. Always-on location uses battery. Scores are per day, not per hour. 855 roads, not every road. Toll roads and city streets are scored from road class and speed limit only, so similar city streets get the same score. Quiet roads are tested in groups, not one by one. Phone location can land on the service road.

## 7. How the brain reaches the app

The app never touches crash data. The notebook writes small files into `data/`, and the app bundles them. **The formats are fixed in `docs/app-data-contract.md`** (agreed Nov 14 as Drop 0; this replaced the earlier proposal) and checked by `notebook/tests/test_data_files.py`. In short:

- `roads.geojson`: one feature per road with a drawable shape (850 of 855). Every map point is the average of at least 5 crashes (2020 to 2023).
- `scores_2023.json`, `scores_2024.json`: per day, the weather, up to 3 reasons, a rare-day flag, `pred` for every road, `alert` indexes (empty on days with no rain and no ice), and a 0 to 4 `actual_level` **only for the 5 roads averaging 8 or more crashes a day** (on a quieter road it would give away that day's crash count).
- `sample.json`: made-up scores in the same format, 14 real 2023 days.
- `routes.gpx`: 5 demo drives along road shapes, a point every 5 seconds at 65 mph.
- `live.json`: what the app needs to score today from live weather. Stretch goal.

Publishing rounded scores and averaged shapes but no raw rows is the planning chat's reading of TxDOT's terms. It is not legal advice.

**Commits from the brain that the app builds on**
1. Road shapes and sample file.
2. 2023 scores, from the practice year.
3. Final 2024 scores, only after 2024 is opened.

## 8. Repo layout and rules

```
/                 README.md, CLAUDE.md (this file), .gitignore
notebook/         Teammate 1: the notebook, get_dfw_crashes.py
app/              Teammate 1 + Claude Code: the Xcode project
data/             written only by the notebook, read by the app
```

- Nobody edits the other's folder.
- `.gitignore` blocks `dfw_crashes_2020_2024.csv.gz` and any other raw crash file from the first commit.
- No keys, passwords or signing files in the repo.
- Commit small and often, with a message that says what works now.

## 9. How to work with AI on this

- AI writes almost all the code and first drafts. The humans decide, check by hand and explain.
- After each part is built, the builder checks one thing by hand, and one of them explains the part in one sentence. If neither can explain a piece of code, it gets explained until they can, or it goes.
- Every choice is made on 2023. **Nobody looks at 2024 results until the pipeline has passed the scrambled-weather test and a cold review by a fresh AI chat.** Then 2024 is run once.
- Every number in the write-up and video is copied from the notebook's final results table.
- Hand checks to do: count crashes by hand for 3 days against the table, check 3 days of weather against NOAA's file, check the 35 busy road names plus 20 random toll and city roads on a map, count "days since rain" on a calendar for one day.
- Credit line to adapt: "Claude wrote most of the code and the first drafts. We chose the question, checked the outputs by hand and can explain every step."

## 10. Suggested build order for Claude Code

**Brain (Teammate 1)**
1. Repo skeleton, `.gitignore`, this file.
2. Notebook cell 1: the three research claims. Cell 2: download and assert the counts in section 3.
3. Surface groups, road names, the road list in three layers (section 3, "Road scope"), both daily tables. Assert 7,308 rows in the surface table (4 groups x 1,827 days).
4. Weather load and columns. Assert the weather counts in section 3.
5. Normal and danger score. Average score should sit near 1.0 for every unit.
6. Write `data/stretches.geojson`, `data/sample.json`, `data/routes.gpx`. Commit 1.
7. Baselines, models A to D, tests 1 to 10, all on 2023. Write `data/scores_2023.json`. Commit 2.
8. Audit: scrambled weather, cold review. Then run 2024 once. Write `data/scores_2024.json`. Commit 3.
9. Where it fails: the 5 worst days of 2024, at least one explained. Limits.
10. Clean up: a five-line summary cell near the top, text above every step, sources, outputs saved.

**App (Teammate 2)**
1. New Xcode project in `app/`, runs on a phone.
2. Map of DFW with stretches from `sample.json`, coloured by score. Day picker and ranked list.
3. Location in the background, the alert rule, the notification chime.
4. Simulated drive through the same alert code.
5. Swap in real scores. Run the app tests.
6. Stretch: "today" mode with live weather, then a spoken alert over a maps app.

## 11. Timeline (Central)

**Saturday night**
- By 9:00 PM: data and tables built, road shapes committed, the app runs on a phone.
- By 10:15 PM: models scored on 2023, 2023 scores committed, the app draws the roads in colour.
- 10:15 to 10:45 PM: read the 2023 results and look at the app together.

**Sunday**
- 9:00 AM: restart and run all.
- 9:30 to 10:30 AM: audit (brain), simulated drive and chime (app).
- 10:30 AM: run 2024 once. No model changes after this.
- 11:00 AM: each explains their half to the other, then a fresh AI chat asks each of them 10 judge questions.
- 12:00 PM: where it fails and write-up draft (Teammate 1), real scores in the app and app tests (Teammate 2).
- 1:30 PM: write-up to one page, notebook clean-up, real-phone test.
- 2:30 to 4:30 PM: video script, record, edit, upload.
- 4:30 to 5:30 PM: README, repo check, every link tested in an incognito window, form.
- **5:30 PM: submit version 1.**
- 5:30 to 9:30 PM: app stretch goals and polish. No model changes. 10:00 PM hands off.

**If behind, cut in this order:** "today" mode, hourly rain and extra gauges, city streets (keep state and toll roads), real location (keep the simulated drive), the chime (fall back to the map), any notebook demo screen, model D (give each road model C's score for its surface), the surface-treated group.

**Never cut:** baselines next to the model, the 2024 test, one failure explained, credits, links that open. The brain ships even if the app doesn't.

## 12. Write-up, video, credits

**Write-up template (about one page)**
```
# Project name
**Track:** Climate
**Team:** names

## The problem
## What we built
## What we added        ("Our own idea", then our own question, data join and comparison)
## How it works         (Data, then Model)
## Results              (baseline X, model Y on held-out 2024, where it fails and why)
## What we'd do next
## Sources
```
Include one sentence linking weather safety to the Climate track. Make no claim that climate change is making this worse unless there is a source.

**Video (2 minutes or less):** problem 15 seconds, demo 60, how it works 30, what's next 15. Story: one real 2024 rain day, Apple Maps navigating, our alert drops in over it, then the map in the app, then the simple guess next to the model and which research claims held, then one limit. Own voices, both speak, about 250 words. No names, school or faces. If the drive is simulated, say so on screen. YouTube unlisted, checked in an incognito window.

**Credits to list**
- Crash data, use this line: "Crash data: Texas Department of Transportation, Crash Records Information System (CRIS), 2020 to 2024. Accessed Nov 14, 2026 through TxDOT's public map layer 'TXDOT Statewide Bicyclist Involved Crashes' (link). Despite its title, the layer holds all crashes. We checked its yearly death counts against TxDOT's published totals."
- NOAA daily weather records, DFW Airport station.
- City of Lewisville crash layer, used to decode the surface codes: https://services2.arcgis.com/kXGqZY4GIOcEYxoF/arcgis/rest/services/Traffic_Crashes_AASHTO_Ware_View/FeatureServer/0
- UC Berkeley, rain after a dry spell (2003): https://newsarchive.berkeley.edu/news/media/releases/2003/10/31_rain.shtml
- Texas A&M Transportation Institute, bleeding and flushing: https://tti.tamu.edu/2013/08/06/get-a-grip (the page has moved to https://pavements.tti.tamu.edu/2013/08/06/get-a-grip-new-fine-pfc-offsets-bleeding-flushing-on-roadways/)
- Every library used (pandas, scikit-learn, numpy, matplotlib, requests, Apple's frameworks).
- Every AI tool and exactly what it did. Claude so far: reviewing the idea, finding and checking the data, the download script, the plan. Add Claude Code and whatever it writes.

## 13. Decision log (Nov 14 to 15, Central)

- 5:42 PM: committed to "Same Rain, Different Road".
- About 6:00 PM: TxDOT layer found, DFW data downloaded and checked. Notebook will download the data, raw file stays private.
- 6:36 PM: the user is a driver, scores are road by road, not highways only.
- 6:49 PM: build AI-first. People step in for sign-ups, decisions and other real human work.
- 7:28 PM: Teammate 1 builds the whole brain, Teammate 2 builds the app. Commit to GitHub whenever the brain reaches a point the app can build on. Aim high.
- 7:41 PM: the app is a native iPhone app (Mac, Xcode and Apple Developer account in hand).
- 7:51 PM: the app runs in the background like Life360. No navigation, no route input.
- 8:00 PM: dropped the "team writes three predictions" step. Replaced with three claims from earlier research.
- 8:02 PM: moving the build to Claude Code.
- About 8:30 PM: expanded from 33 stretches to about 1,000 roads (856 once built) in three layers: state roads, toll roads, the busiest city streets (section 3, "Road scope"). Teammate 1's reason: a driver can't avoid the 33 busiest stretches (mostly freeways), so the alert has to cover the roads they'd take instead.
- About 8:45 PM: the model uses every NOAA daily column with data for 2020 to 2024, not just rain and temperature (section 3, Weather). Rare flags also feed one combined ice flag.
- About 9:20 PM: Model D is gradient boosting (it beat a random forest narrowly on 2023). Rejected: fine-tuning a large language model (wrong tool for a table of numbers, too little data, can't run on a phone); the hackathon briefs recommend pandas and scikit-learn for tabular projects.
- About 9:45 PM: add a road-chemistry layer. A decision model (Jev-style: situation in, typed answers with probabilities out) reads a sourced background sheet plus each day's weather (no dates) and scores each road type; its scores become extra inputs to Model D, which learns from real crashes how much to trust them. Picked Drex Max v1.1 (Nace AI): #1 on the Artificial Analysis Decision Index v2.1 (72.6), cheapest of the top five, same request format as Jev. Backup: Jev 1.14. An LLM improvement loop may rewrite the background sheet using training-year errors only.
- About 10:20 PM: alert rule tuned on 2023 (line + worst 15% of roads that day). Test 6 still reports the pre-registered first-guess rule (it did not pass).
- About 11:30 PM to midnight: cold audit (5 lenses, 2 skeptics per finding) and a verification round. Main changes: Test 5 is now D against the same model without road-build inputs, on all days (was D vs C on rain days, a different target and model kind); claims 2 and 3 tested as a jump against each surface's own dry days and as a heat effect (claim 2 two-sided at 975/1000); map points are averages of 5+ crashes from 2020-2023 only; `actual` replaced by a 0-4 `actual_level` for the 5 roads averaging 8+ crashes a day (TxDOT terms); warm hail no longer counts as ice; the sheet-picking fold uses 2021-only normals; 2024 is not sent to the decision model before step 14; every redraw test has its own fixed seed; boosting stays Model D unless the forest wins 950/1000 redraws (it won 513).
- Nov 15, overnight (Claude Code, overnight; 2024 still locked, no emails, nothing submitted): an offline score viewer for judges and the video, built from `data/` by `notebook/make_viewer.py`; when 2024 opens, step 14 prints 2024's demo dates and which demo drives pass flagged roads, and step 16 draws fig9 (2024 next to 2023), both dry-run on 2023 while locked; library versions pinned in `requirements.txt` after a check with older versions (scikit-learn 1.6.1 shifts Model D's numbers slightly, e.g. rank match +0.42 not +0.45, but no verdict changes).
- Nov 15, overnight, after a 9-agent fact-check of the drafts (77 confirmed findings, all fixed in the drafts) and a cold "judge" read: information-only rows added before 2024 opens (no model, setting or pass line changed; the dry run asserts that each one final_exam reports equals its 2023 value; the weather-days-only rule row is step 12 only). On 2023: a one-line rain rule beats the bar by 3.0% (real) and Model A beats it by only 0.9% (802/1000), so most of the edge is rain; Model D beats the bar road by road by 0.9% (real, 989/1000); the 5b ranking (+0.45) does not beat each road's earlier rain-day record (+0.47, D higher in 385/1000) but beats the model without road build (-0.03, 991/1000); the shipped alert's flagged road-days ran +43.1% on rain days and +8.6% on dry days (4,298 of 9,904 flags), and the same rule on weather days only would run +41.6%. **Open decision for Teammate 1 before 2024: keep dry-day alerts or alert only on weather days** (Claude Code first recommended weather days only; it now recommends rain or ice days only, option B2: see the second fact-check round entry below). (Decided Nov 15: B2.) final_exam also reports persistence on the test year, the every-rain-day rule's impact and the shipped rule's hit rates. The 1,000-redraw ranking now runs from per-week sums (identical draws, 17 s to 0.1 s).
- Nov 15, overnight, a fourth check (notebook text and repo docs) found the step 7 hand check printing 9 single-road, single-day crash counts; it now prints only whether the counts match (TxDOT terms). Those counts remain in earlier commits' saved notebook outputs, so the public repo should start from a fresh history (see the overnight log).
- Nov 15, overnight, after a second fact-check round (56 more findings, all fixed): the forecast stand-in leaked today's rain through two history columns (dry_days_before_rain and hot_days_before_rain are only set when it rains today). Fixed before 2024 by leaving them out of that check: Model A with only yesterday's weather now beats the bar by +0.4% (723/1000, could be luck), not +1.9%. The edge needs today's weather, so a live mode needs a good rain forecast. A second variant of the dry-day proposal was added: alert only on rain or ice days (2023: 5,606 flagged road-days at +43.1%), Claude Code's recommendation; both variants are in `docs/proposals/dry-day-alerts/`.
- Nov 15, about 11:50 AM, before 2024 was opened: **the alert fires only on days with rain (0.3 mm or more at DFW Airport) or ice** (option B2; Claude Code's recommendation, accepted by Teammate 1). Same line and cap as before; the rule and its 2023 numbers are in section 6. Why, in reasons that don't hang on 2023's decimals: most of the model's edge is rain, every alert comes with a weather reason the driver can see, and the app alerts on about 55 days a year instead of 169. Two checks, information only (`docs/proposals/dry-day-alerts/`). On 2021 to 2023, a dry day right after rain runs like any other dry day (+0.1%, 497 of 1,000 redraws; after 12.7 mm or more, +2.4%, 883 of 1,000, not real), and so does the morning after once the weekday mix is taken out (-1.0%, 373 of 1,000). In the Berkeley study, oil and debris that build up in dry weather are lifted by the first rain and washed off by the second day, so the risky moment is the first rain, which is a rain day and still alerts (`day-after-rain.md`). Retraining Model D three ways on 2021 to 2022 and scoring on 2023 (without the two dry-spell inputs, with the day of the week, or both) did not make the any-day rule competitive: with both changes it ran +37.2% against B2's +43.1%, would alert on 215 days and weakened the rain-day flags (+41.0%); the shipped model is unchanged (`retraining-check.md`).
- Nov 15, about 12:25 PM: **2024 opened, once** (`notebook/OPEN_2024.flag`). Trained on 2021 to 2023 with every setting frozen; the final exam ran clean and 59 tests pass. No model or rule changes after this. On 2024 (2023 in brackets): Model A beats the bar by +4.3%, real in 972/1000 [+3.8%], so Test 10 passed; Tests 3, 4, 5, 5c on city streets and 6 failed, as in 2023. Unlike 2023, the other weather columns added real value beyond rain (Model A over the rain-only guess +3.5%, 982/1000 [+0.9%, 802/1000]); the alert rule stays as it was fixed before 2024 opened. The shipped alert's 7,772 flagged road-days on 79 days ran +31.0% above normal [+43.1%], against +8.2% for warning on every road when it rains [+16.8%] (same rule; its line, set from the training years' predictions, is 1.12 [1.14]). Claims on 2021 to 2024: 2 held, 1 and 3 did not; none held on 2024 alone. The failure to explain is Wed Jan 17, 2024, the dry day after the mid-January freeze (busy roads 1.22 against 0.66 predicted): probably leftover ice, which a dry day in the daily weather record doesn't show, so the app stayed quiet. Main demo day: Mon Sep 23, 2024 (route 1; banner "I-35E. 66% more crashes than normal").
- Nov 15, about 3:45 PM: the project is named **Rosafe** (tagline "Same rain, different road") and the team **AYA** (Teammate 1's call). Teammate 1 rewrote the write-up with Claude Code in his own voice in Google Docs and approved it; `WRITEUP.md` is that text. The public repo will be `jacob-gorny/rosafe`.
- Nov 15, about 4:30 PM: **the public repo went live** (Teammate 1's OK), at https://github.com/jacob-gorny/rosafe. Before publishing, an independent audit read the exported copy through four lenses (identity and blind judging, TxDOT terms, secrets and private links, links and numbers), and a skeptic re-checked each finding: 28 confirmed, three of them blockers, all fixed first: one line in this file, and measured scores for named roads on single days in `docs/handoffs/drop-2.md`, which together with the published road averages back out single-road, single-day crash counts. Every code, write-up, Colab and credits link was then opened signed out. `app/` in that copy was still a placeholder.
- Nov 15, about 6:25 PM: **the app merged into main** (Teammate 1's OK, given in this session after the app session's final review; merge commit 4635d69). On the merged code, 93 app tests (7 suites) and 59 notebook tests pass. A short audit of the app's files ran before the public copy was updated with them; its fixes are in (two lines in the app's design docs named other projects, "no network calls" now says our code, since Apple's map loads its own tiles, and the Daily score page's note says the level is ours, worked out from TxDOT's records).

## 14. Open items

- 2024 is done: opened once at about 12:25 PM, Nov 15 (`notebook/OPEN_2024.flag`). Results: the notebook's step 14 (step 15 for the worst days), `docs/figures/fig9_final_exam_2024.png` and section 13. No model or rule changes after this. Still open (timing in `docs/submission-plan.md`): the app, the public repo and Colab timing, the write-up, the video and the form (below).
- Public repo: **published Nov 15, about 4:30 PM** at https://github.com/jacob-gorny/rosafe (decided about 1:40 PM: Teammate 1's own GitHub account, not a neutral organization). Any later update is a fresh export from main by the copy tool, never a push from the working repo: the working repo stays private, because its old commits hold single road-day crash counts (section 13). Judges get a separate public copy with one fresh commit, made by `tools/make_public_copy.py --own-account --name rosafe`: teammate names and the school are replaced in every file, the one commit has a neutral author, and the username appears only in the repo's own links. The crash file stays on Teammate 1's Mac only and is git-ignored.
- Blind judging: the briefs say Round 1 is reviewed without names or schools. The public copy's files carry no teammate names or school, but its URL holds Teammate 1's GitHub username (his call). The video must show no names, faces, school or username, and its YouTube channel name must be neutral.
- Colab (tested Nov 15, about 6:17 PM, from the public repo on Teammate 1's personal Google account): the free runtime crashed at Step 10 (Model D), most likely out of memory. Measured on the laptop with Colab's library versions (pandas 2.2.3, scikit-learn 1.6.1), the notebook peaks at about 12.4 GB; with the pinned versions about 10.7 GB. A fresh clone of the public repo runs clean on the laptop in 3.5 minutes and prints exactly the saved outputs (Test 8 passes there). The README points judges to the saved outputs and a laptop rerun.
- The app is on main (merged Nov 15, about 6:25 PM); see `app/README.md`. Not done: a real-car drive (app test 7), delivery on a real phone's lock screen and over Apple Maps (test 8; checked in the Simulator), the stranger test (test 10), TestFlight.
- Write-up: done (`WRITEUP.md`, Teammate 1's own text). Video and form: in progress; the video guide is `docs/video-guide.md` and the form answers are drafted in `docs/submission-form-answers.md`. Version 1 goes in by 5:30 PM.
- The data file formats in section 7 were agreed as Drop 0 (`docs/app-data-contract.md`).
- The kickoff email (Nov 13, 10:50 PM Central) and the live form were read on Nov 15: one-page write-up, code link, optional video up to 2 minutes, one submission per team, closes 11:59 PM Eastern. Details in `docs/submission-form-answers.md`.
- No live weather source checked for a "today" mode.
- Hourly rain: only the 2024 file was checked.
- Surface codes 5, 6 and 10 were not cross-checked against a labelled source.
- `road_cls_id` 9 is assumed to be parking-lot crashes. Not checked against TxDOT's lookup.
- City street names need cleanup ("N BELT LINE RD" and "BELT LINE RD"). Not decided whether to merge them.
- Not decided: scoring crashes per mile driven so roads can be compared with each other (needs traffic counts, so state roads only).
- The two Claude docs from the planning chat (build plan and project brief) still mention the dropped predictions step in places. This file is the source of truth.
