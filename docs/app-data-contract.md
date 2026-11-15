# App data contract

The files the brain (notebook) writes into `data/` and the app (Teammate 2) reads. This replaces the proposal in CLAUDE.md section 7. A format only changes with a handoff note in `docs/handoffs/`.

**`data/roads.geojson`**: a GeoJSON FeatureCollection, one Feature per road that has a drawable shape.
- `geometry`: `MultiLineString` of `[longitude, latitude]`. A road with gaps has several lines.
- `properties`: `id` (string, stable, like `state-ih30-concrete`, `toll-dallas-north-tollway`, `city-coit-rd-107`), `layer` (`state` / `toll` / `city`), `display_name` (`I-30`, `Dallas North Tollway`, `Coit Rd`), `road` (TxDOT name or street name), `surface` (`concrete`, `asphalt_over_concrete`, `asphalt`, `surface_treated`, or null), `road_class` (`interstate`, `us_state_highway`, `farm_to_market`, `county_road`, `city_street`, `tollway`), `speed_limit` (number or null), `lanes` (number or null), `daily_traffic` (number or null), `busy` (bool), `checked` (`measured` if busy, else `estimated`).

**`data/scores_2023.json`, `data/scores_2024.json`, `data/sample.json`**: one object.
```json
{
  "version": 1,
  "year": 2023,
  "model": "D",
  "made_up": false,
  "alert_threshold": 1.35,
  "alert_top_share": 0.15,
  "alert_weather_only": true,
  "actual_level_names": ["below normal", "about normal", "higher than normal", "much higher than normal", "far higher than normal"],
  "road_ids": ["state-ih35e-asphalt_over_concrete", "..."],
  "days": [
    {
      "date": "2023-01-01",
      "weather": {"rain_mm": 6.1, "days_since_rain": 10, "high_f": 61, "low_f": 44,
                  "thunder": false, "fog": true, "ice": false, "freezing": false},
      "reasons": ["First rain after 9 dry days", "Rain (6.1 mm)", "Fog"],
      "rare": false,
      "pred": [1.02, 0.97],
      "alert": [12, 40],
      "actual_level": {"state-ih35e-asphalt_over_concrete": 2}
    }
  ]
}
```
- `pred[i]` is the predicted score for `road_ids[i]`, rounded to 2 decimals. 1.0 is a normal day.
- Road shapes: every point is the average position of at least 5 crashes (strays over 300 m from the group's middle dropped), rounded to 4 decimals, from 2020 to 2023 crashes only.
- `alert` lists the indexes into `road_ids` (in increasing order) that the app should warn about that day. **Rule (changed in Drop 2):** a road is alerted if its `pred` is at or above `alert_threshold` (the top 10% of predictions on the training years, fixed once) **and** it is among the worst `alert_top_share` of roads that day: sort the roads at or above the line by `pred`, highest first (ties: lower index first), and keep the first `floor(alert_top_share × number of roads)`. Why: with the line alone, the heaviest rain day of 2023 (Oct 25) flagged 784 of the 850 roads, and on one day the line flagged all 850. The cap keeps a storm day to the roughly 15% of roads that are worst that day, and on 2023 it was right more often. **Changed in Drop 2.2:** when the header's `alert_weather_only` is true, `alert` is empty on days with no rain (`rain_mm` under 0.3) and no ice. Why: on 2023 the rule also fired on 114 dry days, and those flags ran only +8.6% above normal (the fog or thunder days among them: -4.9%). The app can simply read `alert`; the rule is spelled out so it can be checked.
- `actual_level` (**changed in Drop 2.1; replaces `actual`**) is "what really happened" as a level 0 to 4, named in `actual_level_names`. It covers only the roads that average 8 or more crashes a day (5 at present; the tests allow at most 6). Levels by real score: under 0.85 → 0, 0.85 to 1.15 → 1, 1.15 to 1.4 → 2, 1.4 to 1.8 → 3, 1.8 and up → 4. Why: a daily number (or any road with few crashes) would let someone work out how many crashes happened that day, and TxDOT's terms forbid passing the crash data on. Levels 1 to 3 can be narrow: in the 2023 file each spans 2 to 8 possible crash counts (often only 2), and with the 2021 to 2023 normals the 2024 file will use, one road's level 2 on one weekday spans a single count. The normal a level is measured against is not in the files.
- `reasons` are short day-level phrases the app can show under "why it's flagged". At most 3, most important first.
- `rare` is true on ice days: glaze, snow, freezing precipitation, or sleet or hail on a cold day (low at or below 2 C; warm spring hail is a thunderstorm, not ice). The app should show "rare conditions, low confidence".
- `sample.json` has the same shape, 14 made-up days, `"made_up": true`, `"year": 2023`.
- Alert text: `"Risky stretch ahead: {display_name}. {round((pred-1)*100)}% more crashes than normal on days like today."`

**`data/routes.gpx`**: GPX 1.1 with 5 `<trk>` tracks named `route-1` to `route-5`. Points every 5 seconds at 65 mph (about 145 m apart), each with `<time>`. All five drives follow state or toll road shapes; none uses a city street. The track `<desc>` names the demo date and the flagged roads it passes. One route passes no flagged road (the "quiet" test).
