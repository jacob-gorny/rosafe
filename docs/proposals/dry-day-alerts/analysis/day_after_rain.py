
# %%
# ===================== Day-after-rain analysis (Nov 15, information only) =====================
# Appended to a COPY of the notebook, cut right after step 12's rain/dry split. 2021 to 2023 only: the practice frames
# stop at 2023-12-31 and every selection below is limited to 2021-2023 dates. Nothing is written into the repo.
# Pre-set before running: "storm" = 12.7 mm (half an inch) or more yesterday; holidays are left out of every day-type
# comparison; a gap counts as real if it is above zero in 950 of 1,000 week redraws (the notebook's rule).
import json as _json
assert not os.path.exists("OPEN_2024.flag")
OUT = {"note": "2021-2023 only; 2024 not used"}

W = wx.loc["2021-01-01":"2023-12-31"].copy()
W["prev_rain_mm"] = wx["rain_mm"].shift(1).loc[W.index]
assert W["prev_rain_mm"].notna().all() and W.index.max() == pd.Timestamp("2023-12-31")
dry_today = (W["rained"] == 0) & (W["ice"] == 0)
cat = pd.Series("", index=W.index, dtype=object)
cat[W["rained"] == 1] = "rain day"
cat[(W["rained"] == 0) & (W["ice"] == 1)] = "ice day, no rain"
cat[dry_today & (W["days_since_rain"] == 1)] = "dry, 1 day after rain"
cat[dry_today & (W["days_since_rain"] == 2)] = "dry, 2 days after rain"
cat[dry_today & (W["days_since_rain"] >= 3)] = "dry, 3+ days after rain"
assert (cat != "").all(), cat[cat == ""]
mismatch = int(((W["days_since_rain"] == 1) != (W["prev_rain_mm"] >= 0.3)).sum())
print("Check: days_since_rain == 1 vs yesterday's rain >= 0.3 mm, mismatching days:", mismatch)
OUT["days_since_mismatch"] = mismatch
hol = (W["holiday"] == 1)
after_ice = dry_today & (W["ice_last_3"] == 1)
CATS = ["rain day", "dry, 1 day after rain", "dry, 2 days after rain", "dry, 3+ days after rain", "ice day, no rain"]
PERIODS = {"2021-2022": (2021, 2022), "2023": (2023, 2023), "2021-2023": (2021, 2023)}
print("Days per type, 2021-2023 (holidays left out):",
      cat[~hol].value_counts().reindex(CATS).to_dict(), "| holidays:", int(hol.sum()),
      "| dry days within 3 days after ice:", int((after_ice & ~hol).sum()))


def day_frame(frame):
    d = (frame[frame["date"].dt.year.between(2021, 2023)].groupby("date")
         .agg(crashes=("crashes", "sum"), normal=("normal", "sum")).reset_index())
    d["cat"] = d["date"].map(cat).to_numpy()
    d["hol"] = d["date"].map(hol).to_numpy().astype(bool)
    d["after_ice"] = d["date"].map(after_ice).to_numpy().astype(bool)
    d["prev_rain_mm"] = d["date"].map(W["prev_rain_mm"]).to_numpy()
    return d


dayR = day_frame(road)        # all 855 roads, the app's own normals (fixed for busy roads, pooled for quiet ones)
dayS = day_frame(surf)        # the 4 surface groups, 8-week normal (follows the seasons)
assert len(dayR) == len(dayS) == 1095
assert road["unit"].nunique() == len(roads) == 855


def ex(d):
    return round(100 * (d["crashes"].sum() / d["normal"].sum() - 1), 1) if len(d) else None


SUB = [("  after under 5 mm", 0.3, 5), ("  after 5 to 12.7 mm", 5, 12.7), ("  after 12.7 mm or more (a storm)", 12.7, 1e9),
       ("    of which 25.4 mm or more", 25.4, 1e9)]
tables = {}
for lens, D in [("855 roads, app normal", dayR), ("surface groups, 8-week normal", dayS)]:
    rows = {}
    for pname, (y0, y1) in PERIODS.items():
        P = D[D["date"].dt.year.between(y0, y1) & ~D["hol"]]
        col = {}
        for c in CATS:
            s_ = P[P["cat"] == c]
            col[c] = (ex(s_), len(s_))
            if c == "dry, 1 day after rain":
                for lab, lo, hi in SUB:
                    t_ = s_[(s_["prev_rain_mm"] >= lo) & (s_["prev_rain_mm"] < hi)]
                    col[lab] = (ex(t_), len(t_))
        ai = P[P["after_ice"]]
        col["dry, within 3 days after ice"] = (ex(ai), len(ai))
        rows[pname] = col
    tables[lens] = rows
    print(f"\nCrashes against normal by day type ({lens}); holidays left out. Value: % (days)")
    for k in rows["2021-2023"]:
        print(f"  {k:<36}" + "".join(f"{(f'{rows[p][k][0]:+.1f}%' if rows[p][k][0] is not None else '-'):>9} ({rows[p][k][1]:>3})   "
                                       for p in PERIODS))
OUT["by_day_type"] = {lens: {p: {k: list(v) for k, v in cols.items()} for p, cols in rows.items()} for lens, rows in tables.items()}


def gap_test(D, a_mask, b_mask, seed):
    full, above, below, days = redraw_stat(D, {"a": a_mask, "b": b_mask}, lambda s: ratio(s, "a") / ratio(s, "b") - 1,
                                           seed=seed)
    return {"gap_%": round(100 * full, 1), "above_in_1000": int(round(1000 * above)),
            "below_in_1000": int(round(1000 * below)), "days": days}


print("\nWeek-redraw tests (gap = how much higher the first day type runs than dry days 3+ days after rain; real if above "
      "zero in 950/1000)")
OUT["gap_tests"] = {}
seed_ = SEED + 500
for lens, D in [("855 roads, app normal", dayR), ("surface groups, 8-week normal", dayS)]:
    for pname, (y0, y1) in PERIODS.items():
        inp = D["date"].dt.year.between(y0, y1).to_numpy() & ~D["hol"].to_numpy()
        base = inp & (D["cat"] == "dry, 3+ days after rain").to_numpy()
        for lab, a in [("day after rain", inp & (D["cat"] == "dry, 1 day after rain").to_numpy()),
                       ("day after a storm (12.7 mm+)", inp & (D["cat"] == "dry, 1 day after rain").to_numpy()
                        & (D["prev_rain_mm"] >= 12.7).to_numpy()),
                       ("2 days after rain", inp & (D["cat"] == "dry, 2 days after rain").to_numpy()),
                       ("rain day (check)", inp & (D["cat"] == "rain day").to_numpy())]:
            seed_ += 1
            r_ = gap_test(D, a, base, seed_)
            OUT["gap_tests"][f"{lens} | {pname} | {lab}"] = r_
            print(f"  {lens:<31} {pname:<10} {lab:<30} gap {r_['gap_%']:+5.1f}%  above zero {r_['above_in_1000']:>4}/1000  "
                  f"days {r_['days']}")


def month_matched(D, a_mask, b_mask):
    """Day type a against dry days 3+ days after rain in the same month, weighted by a's normal (takes out season)."""
    D = D.assign(_a=a_mask, _b=b_mask, ym=D["date"].dt.to_period("M"))
    num = den = 0.0
    for _, g in D.groupby("ym"):
        a, b = g[g["_a"]], g[g["_b"]]
        if len(a) and len(b):
            w_ = a["normal"].sum()
            num += w_ * (a["crashes"].sum() / a["normal"].sum()) / (b["crashes"].sum() / b["normal"].sum())
            den += w_
    return round(100 * (num / den - 1), 1)


print("\nSame-month check (day after rain vs dry 3+ days in the same month):")
OUT["month_matched"] = {}
for lens, D in [("855 roads, app normal", dayR), ("surface groups, 8-week normal", dayS)]:
    for pname, (y0, y1) in PERIODS.items():
        inp = D["date"].dt.year.between(y0, y1).to_numpy() & ~D["hol"].to_numpy()
        v = month_matched(D, inp & (D["cat"] == "dry, 1 day after rain").to_numpy(),
                          inp & (D["cat"] == "dry, 3+ days after rain").to_numpy())
        OUT["month_matched"][f"{lens} | {pname}"] = v
        print(f"  {lens:<31} {pname:<10} {v:+.1f}%")

# Per surface group (8-week normal), 2021-2023: day after rain vs dry 3+.
print("\nBy surface group, 2021-2023, 8-week normal (day after rain / day after a storm / dry 3+):")
OUT["by_surface"] = {}
S3 = surf[surf["date"].dt.year.between(2021, 2023)].copy()
S3["cat"] = S3["date"].map(cat).to_numpy()
S3["hol"] = S3["date"].map(hol).to_numpy().astype(bool)
S3["prev_rain_mm"] = S3["date"].map(W["prev_rain_mm"]).to_numpy()
for u, g in S3[~S3["hol"]].groupby("unit"):
    d1_ = g[g["cat"] == "dry, 1 day after rain"]
    v = (ex(d1_), ex(d1_[d1_["prev_rain_mm"] >= 12.7]), ex(g[g["cat"] == "dry, 3+ days after rain"]), ex(g[g["cat"] == "rain day"]))
    OUT["by_surface"][u] = v
    print(f"  {u:<24} day after rain {v[0]:+.1f}%   after a storm {v[1]:+.1f}%   dry 3+ {v[2]:+.1f}%   rain day {v[3]:+.1f}%")

# ---- Why: time of day and the officer's road-surface field (analysis only, never a model input) ----
CR = crashes[crashes["year"].between(2021, 2023) & crashes["unit"].isin(set(roads["unit"]))].copy()
assert CR["date"].max() <= pd.Timestamp("2023-12-31")
per_day_cr = CR.groupby("date").size().reindex(dayR["date"], fill_value=0).to_numpy()
assert (per_day_cr == dayR["crashes"].to_numpy()).all(), "crash-level and daily-table counts differ"
CR["cat"] = CR["date"].map(cat).to_numpy()
CR["hol"] = CR["date"].map(hol).to_numpy().astype(bool)
CR["prev_rain_mm"] = CR["date"].map(W["prev_rain_mm"]).to_numpy()
CR = CR[~CR["hol"]]
CR["hour"] = CR["crash_time"].astype(str).str.slice(0, 2).astype(int)
BL = ["midnight to 6 AM", "6 to 10 AM", "10 AM to 4 PM", "4 to 8 PM", "8 PM to midnight"]
CR["block"] = pd.cut(CR["hour"], [0, 6, 10, 16, 20, 24], right=False, labels=BL)
CR["wet"] = CR["surf_cond_id"].isin([2, 3])
code_check = CR.groupby("cat")["surf_cond_id"].apply(lambda s: s.value_counts(normalize=True).round(3).head(4).to_dict())
print("\nOfficer's surface code shares by day type (code check):", code_check.to_dict())

nd = dayR[~dayR["hol"]].groupby("cat")["normal"].sum()
nd_storm = dayR[~dayR["hol"] & (dayR["cat"] == "dry, 1 day after rain") & (dayR["prev_rain_mm"] >= 12.7)]["normal"].sum()
base_c = CR[CR["cat"] == "dry, 3+ days after rain"]
d1_c = CR[CR["cat"] == "dry, 1 day after rain"]
st_c = d1_c[d1_c["prev_rain_mm"] >= 12.7]
OUT["by_hour"] = {}
print("\nBy time of day, 2021-2023: day after rain vs dry 3+ days (crashes per unit of normal), and wet-road share")
for b in BL:
    nb, n1, ns = (base_c["block"] == b).sum(), (d1_c["block"] == b).sum(), (st_c["block"] == b).sum()
    g1 = 100 * ((n1 / nd["dry, 1 day after rain"]) / (nb / nd["dry, 3+ days after rain"]) - 1)
    gs = 100 * ((ns / nd_storm) / (nb / nd["dry, 3+ days after rain"]) - 1)
    w1 = 100 * d1_c.loc[d1_c["block"] == b, "wet"].mean()
    ws = 100 * st_c.loc[st_c["block"] == b, "wet"].mean()
    wb = 100 * base_c.loc[base_c["block"] == b, "wet"].mean()
    OUT["by_hour"][b] = {"day_after_gap_%": round(g1, 1), "storm_after_gap_%": round(gs, 1), "wet_share_day_after_%": round(w1, 1),
                         "wet_share_storm_after_%": round(ws, 1), "wet_share_dry3_%": round(wb, 1), "crashes_day_after": int(n1)}
    print(f"  {b:<18} day after rain {g1:+5.1f}%  after a storm {gs:+5.1f}%  | wet road: day after {w1:4.1f}%, after a storm "
          f"{ws:4.1f}%, dry 3+ {wb:4.1f}%")
wet_tot = {c: round(100 * CR.loc[CR["cat"] == c, "wet"].mean(), 1) for c in CATS if (CR["cat"] == c).any()}
wet_tot["dry, 1 day after a storm"] = round(100 * st_c["wet"].mean(), 1)
OUT["wet_share_%"] = wet_tot
print("Wet or standing-water road (officer's field), share of crashes:", wet_tot)

# ---- 2023: what the model predicts and what each alert rule does on these days ----
r23c = r23["date"].map(cat).to_numpy()
r23h = r23["holiday"].astype(bool).to_numpy()
print("\n2023, app roads: the model's predicted vs actual crashes against normal, by day type (holidays left out)")
OUT["model_2023"] = {}
for c in CATS:
    sel = (r23c == c) & ~r23h
    if sel.any():
        nn = r23.loc[sel, "normal"].sum()
        pv = 100 * ((r23.loc[sel, "D"] * r23.loc[sel, "normal"]).sum() / nn - 1)
        av = 100 * (r23.loc[sel, "crashes"].sum() / nn - 1)
        OUT["model_2023"][c] = {"predicted_%": round(pv, 1), "actual_%": round(av, 1), "days": int(r23.loc[sel, "date"].nunique())}
        print(f"  {c:<26} predicted {pv:+5.1f}%   actual {av:+5.1f}%   ({r23.loc[sel, 'date'].nunique()} days)")

ship = rules[f"global line + worst {ALERT_TOP_SHARE:.0%} today"]
rain_or_ice = ((r23["rained"] == 1) | (r23["ice"] == 1)).to_numpy()
wthr = ((r23["rained"] == 1) | (r23["ice"] == 1) | (r23["thunder"] == 1) | (r23["fog"] == 1) | (r23["heavy_fog"] == 1)).to_numpy()
d1m = r23c == "dry, 1 day after rain"
prev23 = r23["date"].map(W["prev_rain_mm"]).to_numpy()
d1storm = d1m & (prev23 >= 12.7)
aicem = r23["date"].map(after_ice).to_numpy().astype(bool)
print("\nThe shipped rule's 2023 flags by day type (A, before any day filter):")
OUT["ship_flags_by_type"] = {}
for c in CATS + ["  of which after a storm (12.7 mm+)"]:
    sel = ship & (d1storm if c.startswith("  of which") else (r23c == c))
    f_ = r23[sel]
    v = (int(sel.sum()), ex(f_), int(f_["date"].nunique()))
    OUT["ship_flags_by_type"][c] = v
    print(f"  {c:<36} {v[0]:>5} flagged road-days on {v[2]:>3} days, {v[1] if v[1] is None else f'{v[1]:+.1f}%'} vs normal")
f_hol = r23[ship & r23h]
OUT["ship_flags_on_holidays"] = (int(len(f_hol)), ex(f_hol))
print(f"  (of all these, on holidays: {len(f_hol)} road-days, {ex(f_hol)}% vs normal)")

seed_ = SEED + 900
OUT["flag_redraws"] = {}
for lab, m in [("A's flags, day after rain", ship & d1m), ("A's flags, day after a storm", ship & d1storm),
               ("A's flags, dry 3+ days", ship & (r23c == "dry, 3+ days after rain"))]:
    seed_ += 1
    if m.sum():
        full, above, below, days = redraw_stat(r23[m], {"a": np.ones(int(m.sum()), bool)}, lambda s: ratio(s, "a") - 1, seed=seed_)
        OUT["flag_redraws"][lab] = {"vs_normal_%": round(100 * full, 1), "above_in_1000": int(round(1000 * above)), "days": days}
        print(f"  redraw: {lab:<30} {100 * full:+.1f}% vs normal, above zero in {round(1000 * above)}/1000 (days {days})")

opts = {
    "A. any day (the rule until Nov 15)": ship,
    "B. rain, fog, thunder or ice": ship & wthr,
    "B2. rain or ice": ship & rain_or_ice,
    "C. rain or ice, or the day after rain": ship & (rain_or_ice | d1m),
    "C-storm. rain or ice, or the day after 12.7 mm+": ship & (rain_or_ice | d1storm),
    "C-ice. rain or ice, or up to 3 days after ice": ship & (rain_or_ice | aicem),
}
day_rain = r23.groupby("date")["rained"].first()
rows = []
for name, m in opts.items():
    hr = hit_rates(m[busy_mask], bad_all[busy_mask])
    per_day = pd.Series(m).groupby(r23["date"].to_numpy()).sum()
    rows.append({"option": name, "flagged road-days": int(m.sum()), "vs normal %": ex(r23[m]),
                 "busy right %": hr["right_%"], "busy caught %": hr["bad_days_caught_%"],
                 "days with a flag": int((per_day > 0).sum()),
                 "dry days with a flag": int(((per_day > 0) & (day_rain.reindex(per_day.index).to_numpy() == 0)).sum())})
opt_table = pd.DataFrame(rows).set_index("option")
print("\nThe options on 2023 (practice year):")
print(opt_table.to_string())
OUT["options_2023"] = opt_table.reset_index().to_dict(orient="records")
expect = {"A. any day (the rule until Nov 15)": (9904, 38.7, 25.0, 17.6), "B. rain, fog, thunder or ice": (6121, 41.6, 25.1, 17.5),
          "B2. rain or ice": (5606, 43.1, 25.7, 17.3)}
for k, v in expect.items():
    got = tuple(opt_table.loc[k, ["flagged road-days", "vs normal %", "busy right %", "busy caught %"]].tolist())
    print("reproduces README" if got == v else "DOES NOT MATCH README", k, got, v)
    OUT.setdefault("readme_match", {})[k] = got == v

with open(os.environ.get("DAYAFTER_OUT", "dayafter_results.json"), "w") as fh:
    _json.dump(OUT, fh, indent=1, default=str)
print("\nwrote results json")
