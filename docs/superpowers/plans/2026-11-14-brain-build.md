# Brain Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the brain (notebook steps 5 to 15): danger scores for 855 DFW roads, models scored on 2023, one honest run on 2024, and the small data files Teammate 2's app reads, handed over in three "drops".

**Architecture:** One notebook, `notebook/same_rain_different_road.py` (jupytext source) built into `same_rain_different_road.ipynb` with outputs saved. Logic stays in the notebook so judges see it all in one place, and `assert`s inside the notebook pin every count. The notebook writes app files into `data/`. A small pytest file checks those files against the contract below, so a change in the brain can never quietly break the app.

**Tech Stack:** Python 3.12, pandas, numpy, scikit-learn (Ridge, RandomForestRegressor), matplotlib, jupytext, nbconvert, pytest. The environment is `notebook/.venv` (uv).

**Spec:** `CLAUDE.md` (repo root). Sections 4, 5 and 7 are the model, the tests and the app files. Where this plan and CLAUDE.md disagree, CLAUDE.md wins unless this plan says it changes CLAUDE.md.

## Progress and changes (updated Sat Nov 14, ~10:20 PM)

- **Done:** Tasks 5 to 12. Drops 0, 1, 2 pushed, tagged and emailed to Teammate 2 (GitHub `teammate2`, invited). The hand checks were run by Claude Code a second way, all matching (`docs/hand-checks.md`). The notebook runs top to bottom in ~53 s.
- **Model D** is gradient boosting (Poisson loss, weighted by normal). It beat the random forest narrowly on 2023.
- **Alert rule changed (Task 12):** the line + worst 15% of roads that day (`alert_top_share`), chosen on 2023. The line alone flagged ~780 of 853 roads on heavy-rain days. Test 6 still reports the pre-registered rule (it failed).
- **New Task 13a, the road-chemistry layer** (replaces nothing; the audit becomes Task 13b):
  - A decision model (Drex Max v1.1 from Nace AI, `console.nace.ai/v1/systemone`; Jev is the backup, same format) reads a sourced background sheet plus each day's weather, with no dates. It scores 12 road types from 0 to 4, and those scores feed Model D, making Model E.
  - The sheet was researched by 8 agents and fact-checked claim by claim (64 claims kept), then critiqued, revised and attacked from three angles.
  - **Improvement loop:** error report from 2021 → an LLM rewrites the sheet → train on 2021, test on 2022 → keep the best version. 2023 is used once at the end: E replaces D only if it beats D overall and on rain days.
  - **Blocked on:** `NACE_API_KEY` in `notebook/.env`.
- **Audit (Task 13b)** started early on steps 1 to 12: five cold reviewers plus two skeptics per finding.

## Global Constraints

- Every choice is made on 2023 (train 2021 to 2022). 2024 is opened **once**, in Task 14, only after Teammate 1 says go.
- 2020 never trains a model (COVID). It stays in the tables for look-back only.
- One fixed seed: `SEED = 42`. Row counts asserted in code.
- The notebook runs top to bottom in under 10 minutes, with no errors and outputs saved.
- Raw crash rows never leave the Mac: at most 5 raw rows shown, no crash counts in `data/`, no single crash positions on the map (at least 5 crashes behind every map point).
- No pretrained model and no AI API inside the product.
- Never use the crash file's officer-filled weather or wet-road fields (`wthr_cond_id`, `surf_cond_id`) as inputs.
- Say "855 DFW roads: state highways, toll roads and the busiest city streets", never "all DFW roads".
- Every number in the write-up and video is copied from the notebook's final results table.
- Nobody edits the other person's folder: Claude and Teammate 1 write `notebook/`, `data/` and `docs/`. Teammate 2 writes `app/`.
- Commit messages say what works now and end with the Co-Authored-By line.

## Review Focus

1. **A road in the scores but not on the map** (no 5-crash map point). The app would look up an id that isn't there. Task 7's contract test asserts both files carry the same ids.
2. **A normal of 0** (a quiet road with no crashes in the look-back) would divide by zero. Task 5 asserts `normal > 0` on every row.
3. **Rare-condition days** (ice, hail, freezing). The model will still give a number, and the app should say "rare conditions, low confidence". Task 12 asserts `rare` is true on exactly the ice-flag days.
4. **Leaking crash counts through `actual`.** On a quiet road, a daily actual score of 0 or 8.3 gives away whether a crash happened. `actual` is published for busy roads only, and the Task 7 contract test asserts that.
5. **Missing or out-of-order days** in a scores file would break Teammate 2's day picker. The contract test asserts every date of the year is present, in order, once.

---

## How the work is split, and the handoff system

**Teammate 1 + Claude build the brain. Teammate 2 builds the app.** The only thing that crosses between them is the files in `data/`, in the exact formats below. Once Teammate 2 has a format, it doesn't change without a note.

**A "drop" is a finished, tested piece of the brain the app can build on.** Each drop:

1. Passes the notebook (restart and run all) and `pytest notebook/tests`.
2. Is committed and pushed to `origin/main` with a message starting `Drop N:`.
3. Gets a git tag `drop-N` so Teammate 2 can always find it.
4. Comes with a handoff note in `docs/handoffs/drop-N.md`: what's new in `data/`, what changed, what the app can now do, what's next and when. Claude writes it, and Teammate 1 sends Teammate 2 the link (or pastes it).

| Drop | Files | What Teammate 2 can build with it | Target time (Central) |
|---|---|---|---|
| 0 | `docs/app-data-contract.md` (the formats) | Start the Xcode project and parse the formats | now |
| 1 | `roads.geojson`, `sample.json`, `routes.gpx` | Map with all 855 roads, colours from sample scores, day picker, simulated drive, alert rule | Sat 10:00 PM |
| 2 | `scores_2023.json` | Real 2023 scores, "why it's flagged", rare-day banner, app test 2 (numbers match) | Sun 2:00 AM (overnight) |
| 3 | `scores_2024.json` | The demo day for the video, real alerts, app tests 3 to 8 | Sun 11:00 AM |

Claude pushes drops on its own once their tests pass. Teammate 1 approving this plan is the OK for those pushes. Anything else outward-facing (making the repo public, GitHub issues, messages) waits for Teammate 1.

## The app data contract

In [`docs/app-data-contract.md`](../../app-data-contract.md). Task 7 points CLAUDE.md section 7 there.

---

### Task 5: Normal and danger score (notebook step 5)

**Files:**
- Modify: `notebook/same_rain_different_road.py` (new step after step 4)

**Interfaces:**
- Consumes: `road_daily`, `surface_daily` (columns `unit`, `date`, `crashes`), `roads` (`unit`, `layer`, `busy`, `per_day`), `ALL_DAYS`.
- Produces: `add_score(daily: pd.DataFrame, train_years: tuple[int, int], quiet: pd.Series) -> pd.DataFrame`, which adds `weekday_factor`, `normal_rolling`, `normal_fixed`, `normal`, `score`. `QUIET_CUTOFF` (crashes a day; set on 2023, start at 1.0). Objects `road_scored` and `surface_scored` hold the practice split (train 2021 to 2022).

- [ ] **Step 1:** Write the asserts first, at the end of the step: `normal > 0` on every 2021 to 2024 row; the mean score per surface unit in 2021 to 2022 is between 0.95 and 1.05; the mean score per busy road in 2021 to 2022 is between 0.9 and 1.1; `len(road_scored) == 856 * 1_827`.
- [ ] **Step 2:** Implement. The weekday factor is the unit's mean count by weekday divided by its overall mean, over the training years only. `normal_rolling` is the mean of the previous 56 days (shifted by 1, so today never counts) times the weekday factor. `normal_fixed` is the unit's training-years mean times the weekday factor. Quiet roads (`per_day < QUIET_CUTOFF`) use `normal_fixed`, and the rest use `normal_rolling`. `score = crashes / normal`.
- [ ] **Step 3:** Add a printed table comparing the rolling and fixed normals on 2023 for busy roads and surface units (mean absolute score swing). Write one markdown sentence on which one is kept and why, filled in from the printed numbers.
- [ ] **Step 4:** Run `cd notebook && .venv/bin/python -I same_rain_different_road.py`. Expected: all asserts pass.
- [ ] **Step 5:** Commit: `Notebook step 5: normal and danger score, scores average 1.0 on training years`.

### Task 6: Road shapes (notebook step 6, writes `data/roads.geojson`)

**Files:**
- Modify: `notebook/same_rain_different_road.py`
- Create: `data/roads.geojson` (written by the notebook)

**Interfaces:**
- Consumes: `crashes` (`unit`, `layer`, `dfo`, `latitude`, `longitude`), `roads`.
- Produces: `road_shapes(crashes, roads) -> dict[str, list[list[tuple[float, float]]]]` (unit to lines), `road_id(unit: str) -> str` (the slug ids in the contract), and the file `data/roads.geojson`. `roads["id"]` and `roads["has_shape"]` are added to `roads`.

- [ ] **Step 1:** Asserts: every map point averages at least 5 crashes; every coordinate is inside lon -98.3 to -95.8 and lat 32.0 to 33.6; ids are unique and match `^[a-z0-9_-]+$`; at least 95% of busy roads have a shape (print the share for every layer).
- [ ] **Step 2:** State roads: bin crashes by `dfo` into 0.5-mile bins (using all 5 years of positions, since positions aren't outcomes), keep bins with at least 5 crashes, take each bin's median lon and lat, order by `dfo`, and start a new line at a gap over 1.5 miles. Toll and city: bin positions into cells of about 400 m (0.004 degrees), keep cells with at least 5, order the cells along the street's main direction (first principal component of the cell centres), and start a new line where neighbours are more than 1.2 km apart. Drop lines with fewer than 2 points.
- [ ] **Step 3:** Write the GeoJSON with the properties in the contract. Print how many roads have no shape, by layer. Those roads stay in the model, but `has_shape` is false and they're left out of every app file.
- [ ] **Step 4:** Draw a matplotlib map of all shapes coloured by layer as a visual check. Run the script. Expected: asserts pass, and the map looks like DFW's road network.
- [ ] **Step 5:** Commit: `Notebook step 6: map shapes for N roads (averaged, 5+ crashes per point)`.

### Task 7: Sample scores, demo routes, contract test, Drop 1

**Files:**
- Modify: `notebook/same_rain_different_road.py` (step 7: `write_scores_file`)
- Create: `data/sample.json`, `data/routes.gpx` (written by the notebook)
- Create: `notebook/tests/test_data_files.py`
- Create: `docs/handoffs/drop-1.md`, `docs/hand-checks.md` (Claude runs the hand checks itself and records them: 3 days of crash counts recounted straight from the raw file, 3 days of weather against NOAA's raw rows, the 35 busy road names against where their shapes sit on the map, one "days since rain" counted day by day)
- Modify: `CLAUDE.md` section 7 (point to this contract; rename `stretches.geojson` to `roads.geojson`), `notebook/requirements-dev.txt` (add `pytest`)

**Interfaces:**
- Consumes: `roads` (with `id`, `has_shape`), `wx`.
- Produces: `write_scores_file(path: str, year: int, model: str, days: pd.DataFrame, preds: pd.DataFrame, actual: pd.DataFrame | None, threshold: float, made_up: bool) -> None`, reused by Tasks 12 and 14. `make_routes(shapes, roads, demo_flags) -> str` (GPX text).

- [ ] **Step 1: Write the failing tests** in `notebook/tests/test_data_files.py`, parametrised over whichever of `sample.json`, `scores_2023.json` and `scores_2024.json` exist:
  - `test_geojson_properties`: every feature has exactly the contract's property keys, the `layer` and `checked` values are from the allowed sets, and the geometry is a MultiLineString.
  - `test_ids_match`: each scores file's `road_ids` equals the set of geojson ids.
  - `test_days_complete`: dates run from Jan 1 to Dec 31 with no gaps and no repeats (sample: 14 days in a row).
  - `test_arrays_line_up`: `len(pred) == len(road_ids)` on every day, and every `alert` index is valid and has `pred >= alert_threshold`.
  - `test_actual_busy_only`: `actual` keys are a subset of the busy ids.
  - `test_rare_matches_ice`: `rare == weather.ice or weather.freezing`.
  - `test_routes`: the GPX parses, has 5 tracks, and every point has a time; the 65 mph tracks space points 120 to 170 m apart.
- [ ] **Step 2:** Run `cd notebook && .venv/bin/python -m pytest tests -q`. Expected: FAIL (the files don't exist yet).
- [ ] **Step 3:** Implement `write_scores_file` and `make_routes`. The sample uses 14 real 2023 dates and real weather, with made-up `pred` values (`1 + 0.4 * rained + noise` from `rng`). Pick 5 routes that run along road shapes, 4 of them crossing roads flagged in the sample.
- [ ] **Step 4:** Run the notebook, then pytest. Expected: everything passes.
- [ ] **Step 5:** Write `docs/handoffs/drop-1.md` (files, formats, what Teammate 2 can build now, what's next and when). Commit `Drop 1: map shapes for N roads, sample scores, demo routes`, tag `drop-1`, push with tags.

### Task 8: Model table, baselines and the scoring kit (notebook step 8)

**Files:**
- Modify: `notebook/same_rain_different_road.py`

**Interfaces:**
- Consumes: `road_scored`, `surface_scored`, `wx`, `roads`.
- Produces: `FEATURES_TODAY: list[str]` (every same-day weather column plus the flags), `FEATURES_HISTORY: list[str]` (`days_since_rain`, `rain_last_7_mm`, `hot_days_last_7`, `dry_days_before_rain`, `hot_days_before_rain`, `ice_last_3`), `ROAD_FEATURES` (surface one-hot with an unknown level, road class one-hot, `speed_limit`, `lanes`, `daily_traffic`, each with an "unknown" indicator). Also these functions:
  - `miss(pred, actual, weight=None) -> float` (mean absolute error)
  - `chance_floor(pred, normal, n_sims=200) -> float` (draw counts from a Poisson distribution with mean `normal * pred` using `rng`, then return the MAE between `pred` and `counts / normal`)
  - `week_redraw(a_err, b_err, dates, n=1000) -> float` (the share of 1,000 redraws of whole calendar weeks in which `b` beats `a`)
  - `baselines(df) -> pd.DataFrame` (columns `persistence`, `same_weekday_last_week`, `always_one`)
- [ ] **Step 1:** Asserts: no feature column is null; no feature uses `wthr_cond_id` or `surf_cond_id`; every history feature equals its value recomputed from yesterday's row on 3 random dates; `week_redraw` of an error series against itself returns about 0.5 (0.4 to 0.6).
- [ ] **Step 2:** Implement, then print Test 1 (the bar) on 2023 for the surface table, the busy roads and the quiet-road groups: each baseline's miss, next to the chance floor. The best baseline becomes the bar.
- [ ] **Step 3:** Run. Commit: `Notebook step 8: features, baselines, chance floor, week redraws`.

### Task 9: Models A, B and C on the surface table (notebook step 9)

**Files:**
- Modify: `notebook/same_rain_different_road.py`

**Interfaces:**
- Consumes: `surface_scored`, the feature lists, `miss`, `chance_floor`, `week_redraw`.
- Produces: `fit_ridge(train_df, features, alpha) -> Pipeline` (StandardScaler then Ridge), and fitted `model_a`, `model_b`, `models_c` (dict surface to Pipeline). `RESULTS` is a list of dicts (`test`, `question`, `pass_line`, `value`, `passed`, `note`) that every later task appends to.

- [ ] **Step 1:** Choose alpha from `[0.1, 1, 10, 100, 1000]` by 2023 miss, and print the table. Write it down: choosing on 2023 and then reporting 2023 flatters the result a little, and that's exactly why 2024 exists.
- [ ] **Step 2:** Test 2 (A beats the bar on all days, real in at least 950 of 1,000), Test 3 (B beats A on rain days), Test 4 (C beats B on rain days). Print each with its miss, gain, redraw share and chance floor, and add each to `RESULTS`.
- [ ] **Step 3:** Print the 10 biggest ridge weights for B, in plain words ("rain today, per mm: +x%").
- [ ] **Step 4:** Run. Commit: `Notebook step 9: models A to C on 2023 (tests 2 to 4)`.

### Task 10: Model D on all 855 roads (notebook step 10)

**Files:**
- Modify: `notebook/same_rain_different_road.py`

**Interfaces:**
- Consumes: `road_scored`, the feature lists, `models_c`, `RESULTS`.
- Produces: `fit_forest(train_df, features) -> RandomForestRegressor` and fitted `model_d`. `predict_roads(model, df) -> pd.Series` (score per road-day).

- [ ] **Step 1:** Train `RandomForestRegressor(n_estimators=200, min_samples_leaf=200, max_features=0.5, n_jobs=-1, random_state=SEED)` on 2021 to 2022 road-days, target `score`, with `sample_weight = normal`. With that weighting, each leaf predicts total crashes divided by total normal for the road-days in it, which is the honest pooled rate for quiet roads. Assert that training takes under 4 minutes.
- [ ] **Step 2:** Test 5: D beats C on the 35 busy state stretches on rain days (real), and D beats the bar on at least 7 of the 10 busiest roads. Test 5b: rank match (Spearman) on rain days across the 35 busy stretches is above zero in 950 of 1,000 redraws. Test 5c: for each quiet group (quiet state, toll, city), sum crashes and normals per day, compare D's normal-weighted mean prediction with the bar, real gain. Report each group even if it fails.
- [ ] **Step 3:** Print the forest's top 15 inputs by permutation importance on 2023.
- [ ] **Step 4:** Run, and check the whole notebook is still under 10 minutes. Commit: `Notebook step 10: model D on 856 roads (tests 5, 5b, 5c)`.

### Task 11: The honesty tests and the three claims on 2021 to 2023 (notebook step 11)

**Files:**
- Modify: `notebook/same_rain_different_road.py`

**Interfaces:**
- Consumes: everything above.
- Produces: `alert_check(preds, actual_bad, threshold) -> dict`, `claim_check(df, claim: int, years) -> dict` (`gap`, `share`, `verdict` of "held" / "did not hold" / "too few days to tell"), and `ALERT_THRESHOLD` (the top 10% of D's training-year predictions).

- [ ] **Step 1:** Test 6: a bad day is the worst 10% of training days by score, and an alert is a prediction at or above `ALERT_THRESHOLD`. Compare precision with "alert every time it rains" at the same or better recall. Then the impact number: crashes on alert days minus what normal days would have brought, computed for busy roads and pooled groups (totals only).
- [ ] **Step 2:** Test 7 (too good): if any 2023 miss drops by half or more against the bar, print a loud warning, and Claude investigates before going on. Test 9 (scrambled weather): shuffle the weather rows across days with `rng`, refit A and D, and check the gain falls to about zero (within ±2%).
- [ ] **Step 3:** The three claims on 2021 to 2023, comparing the mean surface-table score across day groups with 1,000 week redraws, using the exact definitions in CLAUDE.md. Claim 2 uses the six two-surface roads. Leave a placeholder column for 2024, filled in by Task 14.
- [ ] **Step 4:** Show results with and without freezing days and holidays for Tests 2 and 5.
- [ ] **Step 5:** Run. Commit: `Notebook step 11: alert test, scrambled weather, three claims on 2021 to 2023`.

### Task 12: 2023 scores for the app, Drop 2

**Files:**
- Modify: `notebook/same_rain_different_road.py` (step 12)
- Create: `data/scores_2023.json`, `docs/handoffs/drop-2.md`

**Interfaces:**
- Consumes: `write_scores_file`, `model_d`, `ALERT_THRESHOLD`, `wx`.
- Produces: `day_reasons(wx_row) -> list[str]` (at most 3, from: "First rain after N dry days", "Rain after N hot days", "Heavy rain (N mm)", "Thunderstorms", "Fog", "Ice on the roads", "Holiday"), and the file.

- [ ] **Step 1:** Write `scores_2023.json` for shaped roads only, with `actual` for busy roads only.
- [ ] **Step 2:** Run the notebook and pytest. Expected: all pass, and the file is under 8 MB.
- [ ] **Step 3:** Write `docs/handoffs/drop-2.md`, including 3 good 2023 demo dates (a first rain after a dry spell, a thunderstorm day, a quiet day) so Teammate 2 can test now. Commit `Drop 2: real 2023 scores for N roads`, tag `drop-2`, push.

### Task 13: Audit and cold review (before 2024 is opened)

**Files:**
- Create: `docs/audit-2023.md`

- [ ] **Step 1:** Restart and run all from a clean kernel (`nbconvert --execute`). Record the run time and confirm no errors (Test 8 on 2023).
- [ ] **Step 2:** Dispatch a fresh reviewer subagent with only the notebook source and CLAUDE.md sections 4 and 5, not the results. Ask it for leakage (future data in features or normals, 2024 anywhere before Task 14, officer fields), wrong test definitions, and anything that inflates results. Fix whatever it confirms, rerun, and record both in `docs/audit-2023.md`.
- [ ] **Step 3:** Write the "results so far" summary for Teammate 1: the `RESULTS` table on 2023 in plain words, which tests passed and failed, and the 3 claims. **Stop here.** 2024 is opened only after Teammate 1 reads it and says go.
- [ ] **Step 4:** Commit: `Audit: clean run, cold review fixes, 2023 results summary`.

### Task 14: Open 2024 once, Drop 3

**Files:**
- Modify: `notebook/same_rain_different_road.py` (step 14)
- Create: `data/scores_2024.json`, `docs/handoffs/drop-3.md`

- [ ] **Step 1:** Refit the normal, A to D and `ALERT_THRESHOLD` on 2021 to 2023 with every setting frozen from 2023. Score 2024 once. Run every test again on 2024 and add the results to `RESULTS` with a `year` column. Test 10: 2024's gain has the same direction as 2023's and is at least half of it.
- [ ] **Step 2:** Fill in the 2024 column of the three claims.
- [ ] **Step 3:** Write `scores_2024.json`. Run the notebook and pytest. Pick the video demo day: a 2024 rain day where the model's top alert road really did run high, plus one honest miss.
- [ ] **Step 4:** Write `docs/handoffs/drop-3.md`. Commit `Drop 3: final 2024 scores (opened once)`, tag `drop-3`, push. No model changes after this commit.

### Task 15: Where it fails, clean-up, write-up and video drafts

**Files:**
- Modify: `notebook/same_rain_different_road.py` (step 15, the summary cell at the top, sources)
- Create: `docs/writeup.md`, `docs/video-script.md`, and update `README.md`

- [ ] **Step 1:** The 5 worst 2024 days (the biggest misses on busy roads). For each, list its weather and reasons, and explain at least one in plain words.
- [ ] **Step 2:** Final results table (every number in the write-up comes from here), a five-line summary cell near the top, markdown above every step, sources and credits (from CLAUDE.md section 12, plus Claude Code and what it wrote).
- [ ] **Step 3:** Draft `docs/writeup.md` on the organizers' template (about 1 page), `docs/video-script.md` (2 minutes, about 250 words, two voices, no names or school), and the README: how to run, results, limits, credits.
- [ ] **Step 4:** Restart and run all, run pytest, commit `Results, failures explained, write-up and video drafts`, push.

---

## Teammate 1's checkpoints (the only things that need a human)

| When | What | Time |
|---|---|---|
| Now | Approve this plan. Invite Teammate 2 to the repo (give Claude his GitHub username, or do it in GitHub settings). Send Teammate 2 Drop 0 (`docs/handoffs/drop-0.md`) | 10 min |
| After Drop 1 | Skim `docs/hand-checks.md` (Claude ran the checks). Be able to say in one sentence what each check proves, since judges may ask | 5 min |
| Whenever you stop for the night | Say "keep going". Leave the Mac plugged in, lid open, with this session open (Claude asks the app to keep the Mac awake). Claude runs Tasks 8 to 13 and stops at the 2024 gate | 1 min |
| Sun 9:00 AM | Read the 2023 summary and the audit with Teammate 2. Each explains one model in one sentence | 30 min |
| Sun ~10:30 AM | Say "open 2024". Claude runs Task 14 | 1 min |
| Sun 11:00 AM to 1:30 PM | Judge-question practice, then edit the write-up draft | 2.5 h |
| Sun 2:30 to 4:30 PM | Record and edit the video (both voices, no faces or names) | 2 h |
| Sun 4:30 to 5:30 PM | Make the repo public, test every link in an incognito window, fill in the form, submit v1 | 1 h |

## Timeline (Central)

| Time | Brain (Claude, autonomous) | Teammate 2 |
|---|---|---|
| Sat 9:00 to 9:30 PM | Task 5 | New Xcode project, parse the contract with a hand-made sample |
| 9:30 to 10:00 PM | Tasks 6 and 7, Drop 1 | |
| 10:00 PM to Sun 2:00 AM | Tasks 8 to 12, Drop 2 (overnight, while Teammate 1 sleeps) | Map, colours, day picker from Drop 1 |
| Sun 2:00 to 3:00 AM | Task 13, then stop at the 2024 gate | |
| Sun 9:00 to 10:30 AM | Fixes from Teammate 1's review, rerun | Background location, alert rule, chime, simulated drive |
| 10:30 to 11:00 AM | Task 14, Drop 3 | Swap in 2024, app tests |
| 11:00 AM to 1:30 PM | Task 15 | App tests, real-phone test as a passenger |
| 1:30 to 5:30 PM | Fixes only | Video footage |

**If it slips, cut in this order** (CLAUDE.md section 11): "today" mode, hourly rain and extra gauges, city streets (keep state and toll), real location (keep the simulated drive), the chime, model D (each road gets model C's score for its surface), the surface-treated group. **Never cut:** the baselines, the 2024 test, one failure explained, credits, links that open.
