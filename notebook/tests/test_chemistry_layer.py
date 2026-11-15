"""Unit tests for chemistry_layer.py: road types, what the decision model sees, the request, the cache and retries.

No API key and no network needed: requests are faked. Run: cd notebook && .venv/bin/python -m pytest tests -q
"""
import json
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import chemistry_layer as chem  # noqa: E402

YEAR = re.compile(r"\b(19|20)\d\d\b")


@pytest.fixture
def wx():
    """Twenty synthetic days with every column describe_day reads."""
    days = pd.date_range("2022-03-01", periods=20, freq="D")
    rng = np.random.default_rng(0)
    rain = np.where(rng.random(20) < 0.3, rng.uniform(0.3, 30, 20), 0.0)
    df = pd.DataFrame({
        "rain_mm": rain, "rained": (rain >= 0.3).astype(int), "high_c": rng.uniform(10, 36, 20),
        "low_c": rng.uniform(-3, 20, 20), "humidity_min": 30.0, "humidity_max": 90.0, "wind_avg_ms": 4.0,
        "gust_5sec_ms": 12.0, "thunder": 0, "heavy_fog": 0, "fog": 0, "haze": 0, "sleet": 0, "hail": 0, "glaze": 0,
        "freezing": 0, "snow_mm": 0.0, "holiday": 0, "days_since_rain": 3, "rain_last_7_mm": 12.0,
        "hot_days_last_7": 1, "ice_last_3": 0}, index=days)
    df.loc[days[-1], ["thunder", "fog"]] = 1
    return df


@pytest.mark.parametrize("args,expected", [
    (("toll", None, "tollway", None), "toll_road"),
    (("city", None, "city_street", None), "city_street"),
    (("city", None, "county_road", None), "city_street"),
    (("state", "surface_treated", "farm_to_market", 5), "seal_coat_road"),
    (("state", "concrete", "interstate", 1), "concrete_freeway"),
    (("state", "asphalt_over_concrete", "us_state_highway", 2), "aoc_freeway"),      # US 75-style freeway
    (("state", "asphalt", "us_state_highway", 2.0), "asphalt_freeway"),              # functional class as float
    (("state", "concrete", "us_state_highway", 3), "concrete_highway"),
    (("state", "asphalt_over_concrete", "us_state_highway", 3), "aoc_highway"),
    (("state", "asphalt", "us_state_highway", None), "asphalt_highway"),
    (("state", "concrete", "farm_to_market", 4), "concrete_fm"),
    (("state", "asphalt_over_concrete", "farm_to_market", 4), "asphalt_fm"),
    (("state", "concrete", "city_street", 3), "concrete_highway"),
    (("state", "asphalt", "city_street", 3), "asphalt_city_state"),
    (("state", "concrete", "us_state_highway", float("nan")), "concrete_highway"),   # unknown class: not a freeway
])
def test_road_type(args, expected):
    assert chem.road_type(*args) == expected


def test_every_road_type_has_a_description():
    assert len(chem.ROAD_TYPES) == 12
    assert all(isinstance(v, str) and len(v) > 30 for v in chem.ROAD_TYPES.values())
    assert len(chem.LEVELS) == 5


def test_describe_day_has_no_date_and_two_weeks(wx):
    text = chem.describe_day(wx, wx.index[-1])
    assert not YEAR.search(text), "a year leaked into what the decision model sees"
    assert "March" not in text and "Mar" not in text
    assert text.count(" ago: ") == 14
    assert "1 day ago:" in text and not re.search(r"(?<!\d)1 days ago", text)
    assert "Season: spring" in text
    assert "thunderstorms" in text and "fog" in text


def test_payload_shape(wx):
    payload = chem.build_payload("drex-max-v1.1", "Wet roads are slick. [1]", wx, wx.index[-1], chem.ROAD_TYPES)
    assert payload["model"] == "drex-max-v1.1"
    assert set(payload["questions"]) == set(chem.ROAD_TYPES)
    for q in payload["questions"].values():
        assert q["type"] == "score" and q["criteria"] == chem.LEVELS and q["instructions"]
    assert payload["state"].startswith("BACKGROUND") and "CONDITIONS FOR THE DAY BEING SCORED" in payload["state"]
    assert not YEAR.search(payload["state"])


def test_dry_run_and_cache_reuse(wx, tmp_path):
    cache = tmp_path / "cache.jsonl"
    days = list(wx.index[-5:])
    sheet = "Wet roads are slick."
    dry = chem.run(wx, days, sheet, str(cache), provider="nace", model="drex-max-v1.1", dry_run=True, log=lambda *_: None)
    assert dry["todo"] == 5 and dry["sheet"] == chem.sheet_hash(sheet)
    rec = {"day": days[0].strftime("%Y-%m-%d"), "sheet": chem.sheet_hash(sheet), "model": "drex-max-v1.1",
           "answered_by": "drex-max-v1.1", "answers": {"city_street": {"score": 2.0, "confidence": 0.5, "probabilities": {}}}}
    cache.write_text(json.dumps(rec) + "\n")
    again = chem.run(wx, days, sheet, str(cache), provider="nace", model="drex-max-v1.1", dry_run=True, log=lambda *_: None)
    assert again["todo"] == 4, "a cached day must not be scored again"
    other = chem.run(wx, days, sheet + " changed", str(cache), provider="nace", model="drex-max-v1.1", dry_run=True,
                     log=lambda *_: None)
    assert other["todo"] == 5, "a changed sheet must not reuse old answers"


def test_run_without_key_refuses(wx, tmp_path, monkeypatch):
    monkeypatch.delenv("NACE_API_KEY", raising=False)
    with pytest.raises(RuntimeError, match="NACE_API_KEY"):
        chem.run(wx, list(wx.index[-2:]), "sheet", str(tmp_path / "c.jsonl"), provider="nace", model="drex-max-v1.1",
                 log=lambda *_: None)


class FakeResponse:
    def __init__(self, status, body=None, headers=None):
        self.status_code, self._body, self.headers, self.text = status, body or {}, headers or {}, json.dumps(body or {})

    def json(self):
        return self._body


def test_call_retries_then_succeeds(monkeypatch):
    replies = [FakeResponse(429, headers={"retry-after": "0"}), FakeResponse(503), FakeResponse(200, {"answers": {}})]
    monkeypatch.setattr(chem.requests, "post", lambda *a, **k: replies.pop(0))
    monkeypatch.setattr(chem.time, "sleep", lambda *_: None)
    assert chem.call("nace", {"model": "m"}, "key") == {"answers": {}}


def test_call_stops_on_a_bad_request(monkeypatch):
    monkeypatch.setattr(chem.requests, "post", lambda *a, **k: FakeResponse(422, {"error": "bad model"}))
    monkeypatch.setattr(chem.time, "sleep", lambda *_: None)
    with pytest.raises(RuntimeError, match="422"):
        chem.call("nace", {"model": "m"}, "key")


def test_load_env_reads_and_never_overwrites(tmp_path, monkeypatch):
    env = tmp_path / ".env"
    env.write_text("# comment\nNACE_API_KEY='abc'\nOTHER=1\n")
    monkeypatch.setenv("OTHER", "kept")
    monkeypatch.delenv("NACE_API_KEY", raising=False)
    chem.load_env(str(env))
    import os
    assert os.environ["NACE_API_KEY"] == "abc" and os.environ["OTHER"] == "kept"
