"""Checks every file in data/ against docs/app-data-contract.md, so a brain change can't quietly break the app.

Run: cd notebook && .venv/bin/python -m pytest tests -q
"""
import json
import math
import xml.etree.ElementTree as ET
from datetime import date, timedelta
from pathlib import Path

import pytest

DATA = Path(__file__).resolve().parents[2] / "data"
PROPS = {"id", "layer", "display_name", "road", "surface", "road_class", "speed_limit", "lanes",
         "daily_traffic", "busy", "checked"}
SURFACES = {"concrete", "asphalt_over_concrete", "asphalt", "surface_treated", None}
CLASSES = {"interstate", "us_state_highway", "farm_to_market", "county_road", "city_street", "tollway", None}
WEATHER = {"rain_mm", "days_since_rain", "high_f", "low_f", "thunder", "fog", "ice", "freezing"}
SCORE_FILES = [p for p in ["sample.json", "scores_2023.json", "scores_2024.json"] if (DATA / p).exists()]


def load(name):
    return json.loads((DATA / name).read_text())


@pytest.fixture(scope="module")
def geo():
    return load("roads.geojson")


@pytest.fixture(scope="module")
def geo_ids(geo):
    return {f["properties"]["id"] for f in geo["features"]}


@pytest.fixture(scope="module")
def busy_ids(geo):
    return {f["properties"]["id"] for f in geo["features"] if f["properties"]["busy"]}


def test_geojson_properties(geo):
    assert geo["type"] == "FeatureCollection" and len(geo["features"]) > 800
    for f in geo["features"]:
        p = f["properties"]
        assert set(p) == PROPS, p["id"]
        assert p["layer"] in {"state", "toll", "city"}
        assert p["checked"] == ("measured" if p["busy"] else "estimated")
        assert p["surface"] in SURFACES and p["road_class"] in CLASSES
        assert (p["surface"] is None) == (p["layer"] != "state")
        assert f["geometry"]["type"] == "MultiLineString"
        for line in f["geometry"]["coordinates"]:
            assert len(line) >= 2
            for lon, lat in line:
                assert -98.3 <= lon <= -95.8 and 32.0 <= lat <= 33.6


def test_geojson_ids_unique(geo, geo_ids):
    assert len(geo_ids) == len(geo["features"])


@pytest.mark.parametrize("name", SCORE_FILES)
def test_ids_match(name, geo_ids):
    s = load(name)
    assert len(s["road_ids"]) == len(set(s["road_ids"]))
    assert set(s["road_ids"]) == geo_ids


@pytest.mark.parametrize("name", SCORE_FILES)
def test_header(name):
    s = load(name)
    assert s["version"] == 1 and isinstance(s["year"], int) and s["model"]
    assert s["made_up"] == (name == "sample.json")
    assert s["alert_threshold"] > 1.0
    assert 0 < s["alert_top_share"] <= 1


@pytest.mark.parametrize("name", SCORE_FILES)
def test_days_complete(name):
    s = load(name)
    dates = [date.fromisoformat(d["date"]) for d in s["days"]]
    assert dates == sorted(set(dates)), "dates repeat or are out of order"
    assert all(b - a == timedelta(days=1) for a, b in zip(dates, dates[1:])), "a day is missing"
    if name == "sample.json":
        assert len(dates) == 14
    else:
        assert dates[0] == date(s["year"], 1, 1) and dates[-1] == date(s["year"], 12, 31)


@pytest.mark.parametrize("name", SCORE_FILES)
def test_arrays_line_up(name):
    s = load(name)
    n, t, share = len(s["road_ids"]), s["alert_threshold"], s["alert_top_share"]
    k = int(share * n)
    for d in s["days"]:
        p = d["pred"]
        assert len(p) == n
        assert all(isinstance(x, (int, float)) and x >= 0 and not math.isnan(x) for x in p)
        assert d["alert"] == sorted(set(d["alert"]))
        # The contract's alert rule, recomputed independently: at or above the line, then the worst k that day
        # (ties broken by lower index first).
        expected = sorted(sorted((i for i, x in enumerate(p) if x >= t), key=lambda i: (-p[i], i))[:k])
        w = d["weather"]
        if s.get("alert_weather_only") and not (w["rain_mm"] >= 0.3 or w["ice"]):
            expected = []                      # the app alerts only on days with rain or ice
        assert d["alert"] == expected
        assert len(d["alert"]) <= k
        assert set(d["weather"]) == WEATHER
        assert isinstance(d["reasons"], list) and len(d["reasons"]) <= 3


@pytest.mark.parametrize("name", SCORE_FILES)
def test_actual_levels(name, busy_ids):
    s = load(name)
    assert len(s["actual_level_names"]) == 5
    keys = set()
    for d in s["days"]:
        assert "actual" not in d, "the old numeric 'actual' must not come back"
        assert set(d["actual_level"]) <= busy_ids, "actual_level must never cover a quiet road"
        assert all(isinstance(v, int) and 0 <= v <= 4 for v in d["actual_level"].values())
        keys |= set(d["actual_level"])
    assert len(keys) <= 6, "only the handful of busiest roads may get a 'what really happened' level"


@pytest.mark.parametrize("name", SCORE_FILES)
def test_rounding(name):
    for d in load(name)["days"]:
        assert all(abs(x * 100 - round(x * 100)) < 1e-6 for x in d["pred"]), "pred must be rounded to 2 decimals"


def test_shape_points_rounded(geo):
    for f in geo["features"]:
        for line in f["geometry"]["coordinates"]:
            for lon, lat in line:
                assert abs(lon * 1e4 - round(lon * 1e4)) < 1e-6 and abs(lat * 1e4 - round(lat * 1e4)) < 1e-6


@pytest.mark.parametrize("name", SCORE_FILES)
def test_rare_matches_ice(name):
    for d in load(name)["days"]:
        assert d["rare"] == (d["weather"]["ice"] or d["weather"]["freezing"])


def test_routes():
    ns = {"g": "http://www.topografix.com/GPX/1/1"}
    root = ET.parse(DATA / "routes.gpx").getroot()
    tracks = root.findall("g:trk", ns)
    assert [t.find("g:name", ns).text for t in tracks] == [f"route-{i}" for i in range(1, 6)]
    for t in tracks:
        pts = t.findall(".//g:trkpt", ns)
        assert len(pts) > 20
        assert all(p.find("g:time", ns) is not None for p in pts)
        lon = [float(p.get("lon")) for p in pts]
        lat = [float(p.get("lat")) for p in pts]
        steps = [math.hypot((lon[i + 1] - lon[i]) * 93_500, (lat[i + 1] - lat[i]) * 111_000) for i in range(len(pts) - 1)]
        assert 120 <= sorted(steps)[len(steps) // 2] <= 170, "points should be about 5 s apart at 65 mph"
