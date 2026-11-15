# Hand checks (run by Claude Code, Nov 14, 2026)

The plan asked for four checks "by hand". Claude Code ran them **a second way** and compared. The crash, weather and days-since-rain checks recompute from the raw files (the crash recount reuses only the notebook's surface-code table); the road-name check tests the notebook's own crash-to-road grouping against a second TxDOT field (`street_name`). It covered the 35 busy state stretches; the plan's 20 random toll and city roads were not checked. All of them are in notebook step 7, so they rerun every time the notebook does. Every check matched.

| Check | How it was done the second way | Result |
|---|---|---|
| Crash counts | 3 busy roads (I-35E asphalt-over-concrete, US 75 concrete, I-30 concrete) on 3 days (Mar 17 2021, Aug 5 2022, Nov 24 2023): read the raw crash file line by line with Python's `csv` module and counted | 9 of 9 match the daily table (the counts themselves aren't shown: TxDOT terms) |
| Weather | Read NOAA's raw rows for the same 3 days and converted the units by hand | Rain and high temperature match on all 3 (Mar 17 2021: 26.4 mm, 21.7 C) |
| Days since rain | For Nov 24 2023, stepped back one day at a time until a day with 0.3 mm or more | 5 days, same as the notebook |
| Road names | For each of the 35 busy state stretches, checked the share of its crashes whose TxDOT road code (`street_name`, like `IH0030`) matches the name we gave it | 100% for all 35 |

**What each check proves, in one sentence (for judges):**
- **Crash counts:** on the 9 road-days checked (three busy state stretches), the table the model learns from matches a separate recount of the raw file. Toll roads and city streets were not recounted.
- **Weather:** rain and high temperature, the two columns checked, are NOAA's real measurements for those 3 days, in the right units. The other 35 weather columns were not checked this way.
- **Days since rain:** "days since rain" only looks backwards and counts the way we say it does (one day checked here; step 8 rechecks it on 3 random dates). The other history inputs were not checked this way.
- **Road names:** the 35 busy state stretches carry the road their TxDOT road codes say. The other 815 names on the map were not checked this way, and toll-road names come from our own merging rules (for example SH 190 and SH 161 become the President George Bush Turnpike).

**What the road-name check does not prove:** that each line is drawn in the right place. For that, look at `docs/road_shapes.png`. The shapes trace DFW's real network: I-35E and US 75 into downtown Dallas, the Bush Turnpike's arc across the north, the Dallas North Tollway running straight north, Chisholm Trail in southwest Fort Worth.
