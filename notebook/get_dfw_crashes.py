"""
Download every crash in the 12-county Dallas-Fort Worth region, 2020-2024,
from a public TxDOT map layer that carries the full CRIS crash table.

Source layer (TxDOT's own ArcGIS Online account, public, no login):
https://services.arcgis.com/KTcxiTD9dsQw4r7Z/arcgis/rest/services/TXDOT_Statewide_Bicyclist_Involved_Crashes/FeatureServer/0
The layer is titled "Bicycle Involved Crashes" but holds all crashes
(3,088,450 rows, 2020-01-01 to 2024-12-31, checked Nov 14, 2026).

Run in Colab:  !python get_dfw_crashes.py     (takes a few minutes)
Output: dfw_crashes_2020_2024.csv.gz
"""
import time
from concurrent.futures import ThreadPoolExecutor

import pandas as pd
import requests

URL = ("https://services.arcgis.com/KTcxiTD9dsQw4r7Z/arcgis/rest/services/"
       "TXDOT_Statewide_Bicyclist_Involved_Crashes/FeatureServer/0/query")

# TxDOT county numbers, taken from the CNTY_LKP sheet of TxDOT's Public Extract spec.
COUNTIES = {43: "Collin", 57: "Dallas", 61: "Denton", 70: "Ellis", 111: "Hood",
            116: "Hunt", 126: "Johnson", 129: "Kaufman", 184: "Parker",
            199: "Rockwall", 220: "Tarrant", 249: "Wise"}

# Only crash-level columns. No names, plates, case numbers or officer narrative.
# hwy_sys + hwy_nbr + hwy_sfx name the road (IH 35 E, SH 289). street_name is its
# local name. control + section mark one stretch of a state road; dfo is the
# distance along the road in miles.
FIELDS = ["crash_id", "crash_date", "crash_time", "day_of_week", "cnty_id", "city_id",
          "onsys_fl", "surf_type_id", "base_type_id", "func_sys_id", "rural_urban_type_id",
          "road_cls_id", "hwy_sys", "hwy_nbr", "hwy_sfx", "street_name",
          "control", "section", "dfo", "crash_speed_limit", "adt_curnt_amt",
          "nbr_of_lane", "wthr_cond_id", "surf_cond_id", "light_cond_id", "crash_sev_id",
          "at_intrsct_fl", "road_constr_zone_fl", "bridge_detail_id",
          "tot_injry_cnt", "death_cnt", "latitude", "longitude"]

CHUNK = 2000  # the layer returns at most 2000 rows per request


def post(data, tries=5):
    for attempt in range(tries):
        try:
            r = requests.post(URL, data={**data, "f": "json"}, timeout=180)
            j = r.json()
            if "error" not in j:
                return j
        except Exception:
            pass
        time.sleep(2 + 3 * attempt)
    raise RuntimeError(f"request failed after {tries} tries")


def main():
    where = "cnty_id IN (%s)" % ",".join(str(c) for c in COUNTIES)
    ids = sorted(post({"where": where, "returnIdsOnly": "true"})["objectIds"])
    print(f"{len(ids):,} crashes to download")
    chunks = [ids[i:i + CHUNK] for i in range(0, len(ids), CHUNK)]

    def fetch(chunk):
        j = post({"objectIds": ",".join(map(str, chunk)),
                  "outFields": ",".join(FIELDS), "returnGeometry": "false"})
        return [f["attributes"] for f in j["features"]]

    rows, t0 = [], time.time()
    with ThreadPoolExecutor(8) as pool:
        for n, part in enumerate(pool.map(fetch, chunks), 1):
            rows.extend(part)
            if n % 25 == 0 or n == len(chunks):
                print(f"  {n}/{len(chunks)} requests, {len(rows):,} rows, {time.time() - t0:.0f}s")

    df = pd.DataFrame(rows)
    df["county"] = df["cnty_id"].map(COUNTIES)
    assert len(df) == len(ids), "row count does not match the id list"
    assert df["crash_id"].is_unique, "duplicate crash ids"
    df.to_csv("dfw_crashes_2020_2024.csv.gz", index=False, compression="gzip")
    print(f"saved {len(df):,} rows to dfw_crashes_2020_2024.csv.gz")


if __name__ == "__main__":
    main()
