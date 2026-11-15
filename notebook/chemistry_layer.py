"""The road-chemistry layer: a decision model (Drex Max by default, Jev as backup) reads a sourced background
sheet plus one day's weather and the two weeks before it, and scores how risky each road type is that day.

The model is never told the date or year, only the weather, the season and whether it is a public holiday. (Two
weeks of weather could still hint at an extreme event; it is just never told which day it is.) Every answer is cached in data/chemistry_cache.jsonl, so a rerun never calls the
API twice for the same day, sheet and model, and anyone can rerun the notebook without an API key.

The model never receives a crash count. A sheet rewritten by the improvement loop can carry lessons drawn from 2021
crash records (training data only), so "never sees crash data" is true of the daily requests, not of the sheet's
history.

Used by notebook step 13. Can also run on its own:  python chemistry_layer.py --dry-run
"""
import hashlib
import json
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

PROVIDERS = {
    "nace": {"url": "https://console.nace.ai/v1/systemone", "key_env": "NACE_API_KEY",
             "models": ["drex-max-v1.1", "drex-latest"]},
    "typesafe": {"url": "https://api.typesafe.ai/v1/systemone", "key_env": "TYPESAFE_API_KEY",
                 "models": ["jev-latest"]},
}

# Twelve road types. Every road on the map maps to exactly one (see road_type()).
ROAD_TYPES = {
    "concrete_freeway": "an interstate or freeway with a concrete surface (high speed, several lanes, heavy traffic)",
    "aoc_freeway": "an interstate or freeway with an asphalt surface laid over an older concrete road (high speed, several lanes)",
    "asphalt_freeway": "an interstate or freeway with an asphalt surface (high speed, several lanes)",
    "concrete_highway": "a US or state highway with a concrete surface (major road, 40 to 65 mph, often through suburbs)",
    "aoc_highway": "a US or state highway with an asphalt surface laid over an older concrete road (major road, 40 to 65 mph)",
    "asphalt_highway": "a US or state highway with an asphalt surface (major road, 40 to 65 mph)",
    "seal_coat_road": "a state-maintained road with a thin chip-seal / seal-coat surface (often rural, 45 to 65 mph)",
    "concrete_fm": "a farm-to-market road with a concrete surface (suburban or rural, 35 to 55 mph)",
    "asphalt_fm": "a farm-to-market road with an asphalt surface (suburban or rural two to four lanes, 35 to 60 mph)",
    "toll_road": "a toll road (high speed, controlled access, surface type not recorded)",
    "city_street": "a busy city street or county road (30 to 45 mph, many intersections, surface type not recorded)",
}
ROAD_TYPES["asphalt_city_state"] = ("a state route running as a city street, with an asphalt or asphalt-over-concrete "
                                   "surface (30 to 45 mph, many intersections)")

LEVELS = [
    "Safer than a normal day for this road (fewer crashes than usual)",
    "About a normal day for this road",
    "Somewhat riskier (roughly 10 to 25 percent more crashes than usual)",
    "Clearly riskier (roughly 25 to 50 percent more crashes than usual)",
    "Much riskier (50 percent or more crashes than usual)",
]


def road_type(layer, surface, road_class, func_sys=None):
    """Map a road's layer, surface, class and TxDOT functional class to one of the twelve types.
    Functional class 1 (interstate) and 2 (other freeway or expressway, e.g. US 75, SH 183) count as freeways."""
    if layer == "toll":
        return "toll_road"
    if layer == "city":
        return "city_street"
    if surface == "surface_treated":
        return "seal_coat_road"
    try:
        freeway = road_class == "interstate" or int(func_sys) in (1, 2)
    except (TypeError, ValueError):
        freeway = road_class == "interstate"
    if freeway:
        return {"concrete": "concrete_freeway", "asphalt_over_concrete": "aoc_freeway"}.get(surface, "asphalt_freeway")
    if road_class == "farm_to_market":
        return "concrete_fm" if surface == "concrete" else "asphalt_fm"
    if road_class == "city_street":
        return "concrete_highway" if surface == "concrete" else "asphalt_city_state"
    return {"concrete": "concrete_highway", "asphalt_over_concrete": "aoc_highway"}.get(surface, "asphalt_highway")


def load_env(path):
    """Read KEY=value lines from a .env file into os.environ (no extra library needed)."""
    if os.path.exists(path):
        with open(path) as fh:
            lines = fh.readlines()
        for line in lines:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


SEASON = {12: "winter", 1: "winter", 2: "winter", 3: "spring", 4: "spring", 5: "spring",
          6: "summer", 7: "summer", 8: "summer", 9: "fall", 10: "fall", 11: "fall"}


def f(c):
    return round(c * 9 / 5 + 32)


def flags(row):
    out = [name for col, name in [("thunder", "thunderstorms"), ("heavy_fog", "heavy fog"), ("fog", "fog"),
                                  ("haze", "smoke or haze"), ("sleet", "sleet or small hail"), ("hail", "hail"),
                                  ("glaze", "ice glaze"), ("freezing", "freezing precipitation")] if row[col]]
    if row["heavy_fog"] and "fog" in out:
        out.remove("fog")
    if row["snow_mm"] > 0:
        out.append(f"snow ({row['snow_mm']:.0f} mm)")
    return out


def describe_day(wx, day):
    """Plain-text description of one day's weather and the 14 days before it. No date, no year."""
    import pandas as pd
    t = wx.loc[day]
    hist = wx.loc[day - pd.Timedelta(days=14): day - pd.Timedelta(days=1)]
    lines = [
        f"Season: {SEASON[day.month]} in Dallas-Fort Worth, Texas.",
        f"Public holiday today: {'yes' if t['holiday'] else 'no'}.",
        "",
        "TODAY:",
        f"- Rain: {t['rain_mm']:.1f} mm ({t['rain_mm'] / 25.4:.2f} inches)." + (" No rain." if not t["rained"] else ""),
        f"- High {f(t['high_c'])} F, low {f(t['low_c'])} F. Humidity {t['humidity_min']:.0f} to {t['humidity_max']:.0f} percent.",
        f"- Wind: average {t['wind_avg_ms'] * 2.237:.0f} mph, gusts to {t['gust_5sec_ms'] * 2.237:.0f} mph.",
        f"- Also observed: {', '.join(flags(t)) or 'nothing else'}.",
        "",
        "RECENT HISTORY:",
        f"- Days since the last rain before today: {int(t['days_since_rain'])}.",
        f"- Rain over the previous 7 days: {t['rain_last_7_mm']:.1f} mm.",
        f"- Days at 95 F or hotter in the previous 7 days: {int(t['hot_days_last_7'])}.",
        f"- Ice, sleet or freezing weather in the previous 3 days: {'yes' if t['ice_last_3'] else 'no'}.",
        "- Day by day, oldest first (rain mm / high F / other):",
    ]
    for i, (_, r) in enumerate(hist.iterrows()):
        extra = ", ".join(flags(r))
        ago = 14 - i
        lines.append(f"  {ago} day{'s' if ago > 1 else ''} ago: {r['rain_mm']:.1f} mm / {f(r['high_c'])} F"
                     + (f" / {extra}" if extra else ""))
    return "\n".join(lines)


def build_payload(model, sheet, wx, day, road_types):
    state = ("BACKGROUND: how weather affects crash risk on different road surfaces\n" + sheet.strip()
             + "\n\nCONDITIONS FOR THE DAY BEING SCORED\n" + describe_day(wx, day))
    questions = {k: {"type": "score", "criteria": LEVELS,
                     "instructions": (f"Consider {road_types[k]} in Dallas-Fort Worth. Using the background and the "
                                      "conditions, how will crash risk on this kind of road compare with a normal day "
                                      "for the same road? Normal already accounts for the day of the week.")}
                 for k in road_types}
    return {"model": model, "state": state, "questions": questions}


def sheet_hash(sheet):
    return hashlib.sha256(sheet.encode()).hexdigest()[:12]


def call(provider, payload, key, timeout=60, tries=6):
    url = PROVIDERS[provider]["url"]
    for attempt in range(tries):
        try:
            r = requests.post(url, headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
                              json=payload, timeout=timeout)
            if r.status_code == 200:
                return r.json()
            if r.status_code in (429, 500, 502, 503, 504):
                wait = float(r.headers.get("retry-after", 2 + 3 * attempt))
                time.sleep(min(wait, 60))
                continue
            raise RuntimeError(f"{provider} returned {r.status_code}: {r.text[:300]}")
        except requests.RequestException:
            time.sleep(2 + 3 * attempt)
    raise RuntimeError(f"{provider}: no answer after {tries} tries")


def pick_model(provider, key):
    """First model in our preference list that this key can use."""
    try:
        r = requests.get(PROVIDERS[provider]["url"].replace("/systemone", "/models"),
                         headers={"Authorization": f"Bearer {key}"}, timeout=30)
        names = {m.get("name") or m.get("id") for m in r.json().get("data", r.json().get("models", []))}
        for m in PROVIDERS[provider]["models"]:
            if m in names:
                return m
    except Exception:
        pass
    return PROVIDERS[provider]["models"][-1]


def run(wx, days, sheet, cache_path, provider="nace", model=None, workers=4, dry_run=False, log=print):
    """Score every road type for every day. Returns {date: {type: {score, confidence, probabilities}}}.
    Cached answers are reused; only missing days call the API."""
    cache = {}
    if os.path.exists(cache_path):
        with open(cache_path) as fh:
            for line in fh:
                rec = json.loads(line)
                cache[(rec["day"], rec["sheet"], rec["model"])] = rec["answers"]
    key = os.environ.get(PROVIDERS[provider]["key_env"])
    if model is None:
        model = pick_model(provider, key) if (key and not dry_run) else PROVIDERS[provider]["models"][0]
    sh = sheet_hash(sheet)
    todo = [d for d in days if (d.strftime("%Y-%m-%d"), sh, model) not in cache]
    log(f"chemistry layer: {provider}/{model}, sheet {sh}: {len(days) - len(todo)} days cached, {len(todo)} to score")
    if dry_run:
        return {"model": model, "sheet": sh, "example": build_payload(model, sheet, wx, days[0], ROAD_TYPES), "todo": len(todo)}
    if todo and not key:
        raise RuntimeError(f"No {PROVIDERS[provider]['key_env']} in notebook/.env and {len(todo)} days are not cached")

    def one(day):
        resp = call(provider, build_payload(model, sheet, wx, day, ROAD_TYPES), key)
        answers = {k: {"score": a.get("score"), "confidence": a.get("confidence"), "probabilities": a.get("probabilities")}
                   for k, a in resp["answers"].items()}
        return day, resp.get("model", model), answers, resp.get("usage", {})

    used = {"input_tokens": 0}
    with open(cache_path, "a") as out, ThreadPoolExecutor(workers) as pool:
        futures = [pool.submit(one, d) for d in todo]
        for n, fut in enumerate(as_completed(futures), 1):
            day, answered_by, answers, usage = fut.result()
            rec = {"day": day.strftime("%Y-%m-%d"), "sheet": sh, "model": model, "answered_by": answered_by,
                   "answers": answers}
            out.write(json.dumps(rec) + "\n")
            out.flush()
            cache[(rec["day"], sh, model)] = answers
            used["input_tokens"] += usage.get("input_tokens", 0) or 0
            if n % 100 == 0 or n == len(todo):
                log(f"  {n}/{len(todo)} days scored, {used['input_tokens']:,} input tokens so far")
    return {d.strftime("%Y-%m-%d"): cache[(d.strftime("%Y-%m-%d"), sh, model)] for d in days}


if __name__ == "__main__":
    import argparse
    import sys
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    print("Import this from the notebook (step 13). --dry-run is run from there too.", file=sys.stderr)
