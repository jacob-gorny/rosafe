
# %%
# ---- Variant summary (2023 practice year only; appended after dayafter_analysis.py) ----
def tot(m):
    f = r23[m]
    return {"flags": int(m.sum()), "crashes": int(f["crashes"].sum()), "normal": round(float(f["normal"].sum()), 1),
            "extra": round(float(f["crashes"].sum() - f["normal"].sum()), 1), "pct": ex(f)}


base_feats = FEAT_B + ROAD_FEATURES
print("\nVARIANT", os.environ.get("VARIANT"), "| added:", sorted(set(FEAT_D) - set(base_feats)),
      "| removed:", sorted(set(base_feats) - set(FEAT_D)))
print("VARIANT line:", round(ALERT_THRESHOLD, 3), "| D_KIND:", D_KIND)
dry_m = ship & ~rain_or_ice
V = {"line": round(ALERT_THRESHOLD, 3), "D_KIND": D_KIND,
     "A": tot(ship), "B2": tot(ship & rain_or_ice), "A_dry": tot(dry_m)}
for k in ["A", "B2", "A_dry"]:
    V[k]["extra_per_100_flags"] = round(100 * V[k]["extra"] / max(V[k]["flags"], 1), 1)
pdays = pd.Series(ship).groupby(r23["date"].to_numpy()).sum()
V["A_days_with_flag"] = int((pdays > 0).sum())
V["A_dry_days_with_flag"] = int(((pdays > 0) & (day_rain.reindex(pdays.index).to_numpy() == 0)).sum())
V["B2_days_with_flag"] = int((pd.Series(ship & rain_or_ice).groupby(r23["date"].to_numpy()).sum() > 0).sum())
V["A_busy"] = hit_rates(ship[busy_mask], bad_all[busy_mask])
V["B2_busy"] = hit_rates((ship & rain_or_ice)[busy_mask], bad_all[busy_mask])

# Dry-day flags: do they pick the right roads on the same day, and do they beat each road's own usual dry day?
dryday = (~rain_or_ice) & (~r23h)
dd = r23[dryday].copy()
dd["flag"] = ship[dryday]
fdays = dd.loc[dd["flag"], "date"].unique()
same = dd[dd["date"].isin(fdays)]
f_, u_ = same[same["flag"]], same[~same["flag"]]
if len(f_):
    V["dry_flags_vs_same_day_unflagged_%"] = round(100 * ((f_["crashes"].sum() / f_["normal"].sum())
                                                          / (u_["crashes"].sum() / u_["normal"].sum()) - 1), 1)
    lvl = dd[~dd["flag"]].groupby("unit").agg(c=("crashes", "sum"), n=("normal", "sum"))
    lvl = (lvl["c"] + 5) / (lvl["n"] + 5)           # each road's usual dry day, shrunk toward 1 by 5 pseudo-crashes
    exp_ = (f_["normal"] * f_["unit"].map(lvl).fillna(1.0)).sum()
    V["dry_flags_vs_own_road_dry_level_%"] = round(100 * (f_["crashes"].sum() / exp_ - 1), 1)
    full, above, below, days = redraw_stat(r23[dry_m], {"a": np.ones(int(dry_m.sum()), bool)},
                                           lambda s: ratio(s, "a") - 1, seed=SEED + 4242)
    V["A_dry_vs_normal_above_zero_in_1000"] = int(round(1000 * above))
    V["A_dry_busy_road_flags"] = int((ship & ~rain_or_ice & busy_mask).sum())

# Model quality on 2023 (lower miss is better)
b_ = rte[rte["unit"].isin(busy_units)]
q_, qb_ = quiet_groups(rte, "D"), quiet_groups(rte, BAR_COL)
V["busy_miss_D"], V["busy_miss_bar"] = round(float(miss(b_["D"], b_["score"])), 4), round(float(miss(b_[BAR_COL], b_["score"])), 4)
V["quiet_miss_D"], V["quiet_miss_bar"] = round(float(miss(q_["pred"], q_["score"])), 4), round(float(miss(qb_["pred"], qb_["score"])), 4)
rd_ = b_[b_["rained"] == 1]
V["busy_rain_miss_D"], V["busy_rain_miss_bar"] = round(float(miss(rd_["D"], rd_["score"])), 4), round(float(miss(rd_[BAR_COL], rd_["score"])), 4)
print("VARIANT RESULT", _json.dumps(V, default=str))
