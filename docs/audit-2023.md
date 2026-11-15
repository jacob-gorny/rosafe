# Audit of the brain before 2024 is opened (Sat Nov 14, 2026, finished by 10:47 PM, when it was committed as Drop 2.1)

## How the audit was run

- **Five cold reviewers** read only the code and CLAUDE.md, never the results, each through one lens: leakage and time, test definitions, statistics, data handling, privacy and the app contract.
- **Every finding went to two skeptics** told to refute it against the code.
- **Out of 47 findings:** 41 were confirmed by both skeptics, 2 split the skeptics, and 4 were refuted.
- **Every confirmed high and medium finding was then fixed or documented.** A second round of fresh reviewers checked the fixes (results at the end).

## What changed in the numbers (2023, the practice year)

| Test | Before the audit | After the fixes |
|---|---|---|
| 2. Model A beats the bar | +3.9%, real 998/1000 | **+3.8%, real 997/1000 (pass)** |
| 3. Model B over A (rain days) | +1.1%, 815/1000 | +1.6%, 880/1000 (fail) |
| 4. Model C over B (rain days) | +0.1%, 508/1000 | 0.0%, 517/1000 (fail) |
| 5. Road build helps (D) | D vs C on rain days, but C predicted a different target and is a different kind of model | **Same model with and without road build, all days: +0.0%, 573/1000 (fail).** For information, D vs ridge C on the same target: +0.2% (687) |
| 5. D beats the bar on 10 busiest | 7 of 10 (pass) | **6 of 10 (fail)** |
| 5b. Ranking of the 35 busy stretches | +0.45, 1000/1000 | +0.45, 1000/1000 (pass) |
| 5c. Quiet state / toll / city | +5.7% / +4.5% / +5.0%, all pass | +6.2% (993) / +4.0% (1000) / **+4.1% (939, fail)** |
| 6. Alert (pre-registered rule) | fail | fail |
| 7. Too good | pass (checked only A and D) | pass (now checks every model against the bar) |
| 9. Scrambled weather | pass | pass (A −2.4%, D busy −1.4%, D quiet −1.6%) |
| Forecast stand-in (new, information) | n/a | Model A knowing only yesterday's weather: +1.9%, real 990/1000. **Corrected Nov 15 (before 2024): +0.4%, could be luck (723/1000).** Two history columns (dry days and hot days before today's rain) are only set when it rains today, so the first version still knew it was raining; they are now left out of this check |
| Year drift (new) | n/a | all 2023 road-days ran **+0.1%** against normal, so the impact numbers are not the year |
| Impact, shipped alert rule | (reported for the first-guess rule: +33.5%) | **+38.7%: 7,212 crashes vs 5,199 normal on 9,904 flagged road-days** |
| Claim 1, first rain | did not hold (804) | did not hold (821) |
| Claim 2, surface | held (989) on raw levels | **held (1000/1000) on the first-rain jump against each surface's own dry days** |
| Claim 3, heat | held (991) on raw levels | **did not hold (778) once tested as a heat effect** |

**The honest summary:** today's weather really does predict crashes (Model A, +3.8%; with only yesterday's weather the edge almost vanishes, +0.4% after the Nov 15 correction), and the model ranks which busy roads suffer most in rain (+0.45), about as well as each road's earlier rain-day record (+0.47, a comparison added Nov 15), not better. It also beats "every day is normal" on quiet state and toll roads. The alert the app ships flags road-days that ran **+38.7%** above normal, against +16.8% for "warn on every road when it rains", in a year that ran +0.1% overall. Adding weather history, surface type or road build gives no day-by-day gain we can tell apart from luck on 2023 (road build does lift the rain-day ranking: +0.45 against -0.03 without it, D higher in 991/1000). One research claim held (asphalt-over-concrete jumps more on a first rain) and two did not.

**Nov 15 note (before 2024 was opened):** the shipped alert now fires only on days with rain or ice (option B2 in `docs/proposals/dry-day-alerts/`), with the same line (1.14) and cap (the worst 15% of roads that day). On 2023: 5,606 flagged road-days on 55 days, 6,499 crashes against a normal of 4,542 (**+43.1%**); busy roads: right 25.7%, catches 17.3% of bad days; no alerts on dry days. The +38.7% above is for the rule shipped until then (9,904 road-days on 169 days). The rule was picked on 2023 after comparing several versions, so 2023's numbers flatter it. Test 6 still reports the plan's first-guess rule.

## Every confirmed finding and what was done

**High**
1. **Test 5 compared two different targets.** C predicted the surface group's score (rolling normal), while D predicted each road's own score (fixed normal). *Fixed:* C is refit per surface on the road table (the same target, weighted the same way, with its penalty picked on 2023). Test 5 now runs on all days, as CLAUDE.md says, with rain days shown as an extra.
2. (Same finding, statistics lens.) *Fixed* as above.
3. **Map points were medians**, and the median of an odd count is a real crash's coordinate. *Fixed:* each point is now the average of at least 5 crashes, after dropping strays more than 300 m from the middle, rounded to 4 decimals. A contract test checks the rounding.
4. **Busy roads' daily crash counts could be read back out of `actual`** (score = count / normal). *Fixed:* replaced by `actual_level`, a 0 to 4 level, only for the 5 roads averaging 8+ crashes a day, so each level spans several counts. A contract test forbids the old field.

**Medium**
5. **The sheet-picking fold** (train 2021, test 2022) used normals and train_rate fitted on 2021 to 2022. *Fixed:* the fold is rebuilt from 2021 alone, with an assert.
6. **Map shapes used 2024 crash rows.** *Fixed:* shapes use 2020 to 2023 only.
7. **"Today's weather" is the whole measured day,** including hours after some crashes. *Documented* in step 4 and in the limits. It stands in for a perfect morning forecast, and a live version would do somewhat worse.
8. and 13. **The bar from Test 1 was never used** (tests hard-coded "always 1.0"). *Fixed:* every test uses the chosen bar, with an assert that it is one guess everywhere.
9. **Test 7 skipped models.** *Fixed:* it checks every model's gain against the bar, plus chance floors.
10. and 16. **Claim 3 compared levels, not the heat effect.** *Fixed:* the verdict is now the heat effect on asphalt-type minus that on concrete. The level comparison is shown as an extra. The verdict changed to "did not hold".
11. and 25. **Roads and the busy/quiet split were chosen on 2021 to 2023 counts,** including the practice year. *Documented* in step 3: 2023 numbers are a little flattering, and 2024 plays no part in choosing roads.
12., 18. and 39. **The impact number and the rule table didn't use the rule the app ships.** *Fixed:* both run the exact `pick_alerts` code on 2-decimal predictions.
14. **Claim 2's two-sided verdict used 950/50** (a 10% test). *Fixed:* 975 on either side.
15. **Claim 2 compared raw first-rain levels.** *Fixed:* each surface's first-rain jump is measured against its own dry days.
17. **The `week_redraw` self-test could fail by chance.** *Fixed:* deterministic checks. Every redraw now also uses its own fixed seed, so a test's result can't shift when unrelated code changes.
19. **Warm spring hail counted as "ice".** *Fixed:* hail, sleet and blowing snow count as ice only when the low is at or below 2 C. Ice days fell from 9/15/6/10 to 8/10/4/5 (2021 to 2024).
20. **Eleven major freeways were described to the decision model as suburban highways.** *Fixed:* TxDOT functional classes 1 and 2 map to the freeway types.
21. **`chem_p_high` could silently become 0.** *Fixed:* asserts the probability keys are 0 to 4.
22. (Same as 3.) *Fixed.*
23. and 26. **The chemistry layer would send 2024 weather before step 14.** *Fixed:* 2024 days are scored only in step 14.
24. **"The decision model never sees crash data" overstated it,** because a rewritten sheet can carry 2021 lessons. *Fixed:* the wording now says so.

**Low**
27. and 32. **Test 9 and Model E always retrained boosting.** *Fixed:* they use the same model kind as D (`FIT_D`).
28. **The "no ice days" variant dropped warm hail days.** *Fixed* by the ice fix.
29. **Bad days used ≥ on discrete scores.** *Fixed:* strictly above the 90th percentile (9.6% of training road-days).
30. **Test 5b runs on 35 stretches; CLAUDE.md's planning said 33.** *Documented:* 35 is the busy count on 2021 to 2023, which keeps 2024 out of the selection. CLAUDE.md was updated.
31. **Claim redraws were counted over fewer than 1,000 when a draw missed a group.** *Fixed:* always out of 1,000.
33. **The "mean score near 1.0" check is true by construction for fixed normals.** *Kept,* plus an out-of-sample 2023 printout.
34. (Same as 5.) *Fixed.*
35. **TX 121 Express spellings formed their own unit.** *Fixed:* they join the SH 121 toll lanes.
36. **State shapes broke at county lines.** *Fixed:* `dfo` runs continuously across counties, so the county split was removed.
37. **The surface table includes about 1,000 toll-lane crashes that the road table puts in the toll layer.** *Documented.* It keeps the planning totals asserted in CLAUDE.md.
38. **County roads outside any city shared code 9999.** *Fixed:* keyed by county too.
40. **Contract tests didn't check the protective rounding.** *Fixed:* new tests for 2-decimal predictions, 4-decimal shape points and `actual_level`.
41. **Demo routes named roads from the made-up sample.** *Fixed:* routes are written from the real 2023 scores (Dec 15 rain day, a dry day for route 5).

**One more change found while fixing:** forest and boosting are tied on 2023 (1.0524 against 1.0525), so tiny data changes flipped the pick. Now boosting is the default, and the forest replaces it only if it wins in 950 of 1,000 week redraws. It won 513 (536 before each test got its own seed), so Model D is gradient boosting.

**Split findings** (one skeptic agreed):
- **Test 5 on rain days only:** CLAUDE.md says all days. *Fixed:* all days is the pass line.
- **Test 6's alert line comes from all roads' training predictions but is judged on busy roads:** *kept by design.* The line is global, because the app uses one line, and bad days can only be judged on roads with enough crashes.

**Refuted** (both skeptics). One refuted finding was later reversed: the hand-check output printed 9 crash counts, each for one busy road on one day. Both skeptics called them totals, not records, but a single road's count for a single day is what finding 4 protects. On Nov 15, before 2024 opened, the hand check was changed to print only whether the two counts match. The other refuted findings:
- The chance floor isn't a true lower bound, so Test 7's floor check can misfire (two reviewers raised it).
- The 5-crashes-per-point assert always passes.

## Second round: did the fixes work?

Seven fresh reviewers, one per theme, checked the 26 high, medium and split findings against the new code. They rated 15 fixed, 8 partly fixed, 2 documented only and 1 not fixed, and reported 21 new small issues (none high). Everything they raised was then handled:

- **Test 5 still mixed model kinds** (linear C against boosted D). *Fixed:* the pass line is now D against the **same model without road-build inputs**. Ridge C is kept as information only, and information-only rows carry no pass/fail.
- **The Step 10 text still showed the old Test 5 pass line,** and the Step 1 claims text didn't mention the stricter tests. *Fixed:* both carry dated notes saying what changed after the audit and before 2024.
- **Map points:** the reviewer confirmed **0 of 10,776 points equal a raw crash position** (the audit had found 7,492 of 12,131). The plot title and README still said "median". *Fixed.* A point can sit where several crashes cluster (an intersection), but it always stands for at least 5. That is now stated.
- **The road-name hand check still read 2024.** *Fixed:* 2020 to 2023, like the shapes.
- **The impact needed the year's own baseline.** *Added:* all 2023 road-days ran +0.1% against normal.
- **Test 6:** the first-guess line now uses the exact app rule (`shipped_mask`, defined next to `pick_alerts`). The notebook prints the share of busy road-days it alerts (9.9%), asserts every busy road is on the map, and explains why the line comes from all roads.
- **Test 7 stopped the notebook instead of recording a failure.** *Fixed:* it records pass or fail and prints a loud warning.
- **Decision-model answers weren't range-checked.** *Fixed:* probabilities must sum to 1, the score must be 0 to 4 and the confidence 0 to 1. "Can't remember famous storms" is softened to "is never told the date or year".
- **"A little flattering" was a claim with no measurement.** *Reworded:* the direction is untested, and 2024 is free of it.
- **Perfect same-day weather was promised in the limits but missing.** *Added* to the README limits, plus the forecast stand-in check above.
- **Busy-road counts were typed in.** *Fixed:* asserted (38 roads, 35 state stretches).
- **Docs:** the contract says "roads averaging 8+ crashes a day (5 at present)". This file now exists, which fixes the dangling link.
