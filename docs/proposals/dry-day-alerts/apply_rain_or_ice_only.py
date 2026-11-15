"""PROPOSAL (option B2): the app alerts only on days with rain (0.3 mm or more) or ice. Apply only if Teammate 1 chooses it,
before 2024 is opened. Test 6 keeps the plan's first-guess rule, ungated."""
import sys
from pathlib import Path

root = Path(sys.argv[1])
nb = root / "notebook" / "same_rain_different_road.py"
s = nb.read_text()


def sub(old, new):
    global s
    assert s.count(old) == 1, old[:120]
    s = s.replace(old, new)


sub('''ALERT_TOP_SHARE = 0.15   # the alert rule: also among the worst 15% of roads that day (step 12 shows why)
''', '''ALERT_TOP_SHARE = 0.15   # the alert rule: also among the worst 15% of roads that day (step 12 shows why)
ALERT_WEATHER_ONLY = True  # and only on days with rain or ice (chosen on 2023, before 2024; step 12)


def weather_day(w):
    """Rain (0.3 mm or more) or ice that day: the only days the app alerts on."""
    return bool(w["rained"] or w["ice"])
''')

sub('''def shipped_mask(frame, col, threshold, top_share):
    """Exactly the app's rule, as a mask over frame rows: pick_alerts on 2-decimal predictions in app order (ties by
    position), day by day. top_share=1.0 is the plain line with no cap."""
    alerted = set()
    for day, g in frame[frame["unit"].isin(APP_POS)].groupby("date"):
''', '''def shipped_mask(frame, col, threshold, top_share, weather_only=False):
    """Exactly the app's rule, as a mask over frame rows: pick_alerts on 2-decimal predictions in app order (ties by
    position), day by day. top_share=1.0 is the plain line with no cap. weather_only skips days with no rain
    and no ice."""
    alerted = set()
    for day, g in frame[frame["unit"].isin(APP_POS)].groupby("date"):
        if weather_only and not weather_day(wx.loc[day]):
            continue
''')

sub('''                     "pred": pr, "alert": pick_alerts(pr, threshold, top_share), "actual_level": act})''',
    '''                     "pred": pr, "alert": pick_alerts(pr, threshold, top_share) if weather_day(w) or not ALERT_WEATHER_ONLY else [],
                     "actual_level": act})''')

sub('''                   "alert_threshold": threshold, "alert_top_share": top_share, "actual_level_names": LEVEL_NAMES,''',
    '''                   "alert_threshold": threshold, "alert_top_share": top_share, "alert_weather_only": ALERT_WEATHER_ONLY,
                   "actual_level_names": LEVEL_NAMES,''')

sub('''rules[f"global line + worst {ALERT_TOP_SHARE:.0%} today, weather days only (extra)"] = (
    rules[f"global line + worst {ALERT_TOP_SHARE:.0%} today"] & weather_day)''',
    '''rules[f"global line + worst {ALERT_TOP_SHARE:.0%} today, rain or ice days only"] = (
    rules[f"global line + worst {ALERT_TOP_SHARE:.0%} today"] & weather_day)
SHIPPED_RULE = f"global line + worst {ALERT_TOP_SHARE:.0%} today" + (", rain or ice days only" if ALERT_WEATHER_ONLY else "")''')

# the mask variable above was named weather_day in the info patch; rename it so it doesn't shadow the function
sub('''weather_day = ((r23["rained"] == 1) | (r23["ice"] == 1) | (r23["thunder"] == 1) | (r23["fog"] == 1)
               | (r23["heavy_fog"] == 1)).to_numpy()''',
    '''weather_rows = ((r23["rained"] == 1) | (r23["ice"] == 1)).to_numpy()''')
sub('''    rules[f"global line + worst {ALERT_TOP_SHARE:.0%} today"] & weather_day)
SHIPPED_RULE''', '''    rules[f"global line + worst {ALERT_TOP_SHARE:.0%} today"] & weather_rows)
SHIPPED_RULE''')

sub('''chosen = rule_table.loc[f"global line + worst {ALERT_TOP_SHARE:.0%} today"]''', '''chosen = rule_table.loc[SHIPPED_RULE]''')
sub('''print(f"\\nShipped rule: global line ({ALERT_THRESHOLD:.2f}) + worst {ALERT_TOP_SHARE:.0%} of roads that day. At most "''',
    '''print(f"\\nShipped rule: global line ({ALERT_THRESHOLD:.2f}) + worst {ALERT_TOP_SHARE:.0%} of roads that day"
      f"{', only on days with rain or ice' if ALERT_WEATHER_ONLY else ''}. At most "''')
sub('''m_ship = rules[f"global line + worst {ALERT_TOP_SHARE:.0%} today"]''', '''m_ship = rules[SHIPPED_RULE]''')
sub('''    ship_ = shipped_mask(r_te, final_col, line_, ALERT_TOP_SHARE)''',
    '''    ship_ = shipped_mask(r_te, final_col, line_, ALERT_TOP_SHARE, weather_only=ALERT_WEATHER_ONLY)''')
sub('''         (f"The alert the app ships (line + worst {ALERT_TOP_SHARE:.0%} of roads that day)", IMPACT_SHIPPED_2023["extra_%"], INK["orange"])]''',
    '''         (f"The alert the app ships (line + worst {ALERT_TOP_SHARE:.0%} of roads,\\nrain or ice days only)" if ALERT_WEATHER_ONLY
          else f"The alert the app ships (line + worst {ALERT_TOP_SHARE:.0%} of roads that day)", IMPACT_SHIPPED_2023["extra_%"], INK["orange"])]''')
sub('''# *Added Nov 15, before 2024 was opened (information only):* the shipped alert's flagged road-days split into rain
# days and dry days. The alert also fires on some dry days, because the model's prediction moves with temperature,
# humidity, season and holidays, not only with rain.
''', '''# *Added Nov 15, before 2024 was opened:* the shipped alert's flagged road-days split into rain days and dry days. The
# line-plus-15% rule also fired on 114 dry days of 2023, because the model's prediction moves with temperature,
# humidity, season and holidays, not only with rain, and those dry-day flags ran only +8.6% above normal. **Decision
# (Nov 15, before 2024 was opened):** the app alerts only on days with rain or ice. The rule table shows
# both versions; Test 6 still reports the plan's first-guess rule.
''')
nb.write_text(s)

# the contract test: recompute the gate from the file's own weather fields
t = root / "notebook" / "tests" / "test_data_files.py"
ts = t.read_text()
old_t = '''        assert d["alert"] == expected
'''
new_t = '''        w = d["weather"]
        if s.get("alert_weather_only") and not (w["rain_mm"] >= 0.3 or w["ice"]):
            expected = []                      # the app alerts only on days with rain or ice
        assert d["alert"] == expected
'''
assert ts.count(old_t) == 1
t.write_text(ts.replace(old_t, new_t))

# the contract
c = root / "docs" / "app-data-contract.md"
cs = c.read_text()
old_c = "The app can simply read `alert`; the rule is spelled out so it can be checked."
assert cs.count(old_c) == 1
cs = cs.replace(old_c, "**Changed in Drop 2.2:** when the header's `alert_weather_only` is true, `alert` is empty on days with no rain "
                "(`rain_mm` under 0.3) and no ice. Why: on 2023 the rule also fired on 114 dry days, and those flags ran only "
                "+8.6% above normal (the fog or thunder days among them: -4.9%). The app can simply read `alert`; the rule is spelled out so it can be checked.")
c.write_text(cs)
print("option B2 (rain or ice days only) applied to", root)
