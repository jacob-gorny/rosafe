"""The offline score viewer (docs/demo/index.html) must match the data files, stay offline, and respect the 2024 lock.

Run: cd notebook && .venv/bin/python -m pytest tests -q   (rebuild the page with: .venv/bin/python make_viewer.py)
"""
import json
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
PAGE = ROOT / "docs" / "demo" / "index.html"
DATA = ROOT / "data"


@pytest.fixture(scope="module")
def page():
    assert PAGE.exists(), "docs/demo/index.html is missing: run make_viewer.py"
    return PAGE.read_text()


@pytest.fixture(scope="module")
def embedded(page):
    m = re.search(r'<script type="application/json" id="viewer-data">(.*?)</script>', page, re.S)
    assert m, "data block not found"
    return json.loads(m.group(1))


def test_page_matches_data_files(embedded):
    assert embedded["roads"] == json.loads((DATA / "roads.geojson").read_text()), "rebuild: run make_viewer.py"
    real = {}
    for p in DATA.glob("scores_*.json"):
        s = json.loads(p.read_text())
        if not s.get("made_up"):
            real[str(s["year"])] = s
    assert embedded["years"] == real, "rebuild: run make_viewer.py"


def test_no_2024_before_it_opens(embedded):
    if not (ROOT / "notebook" / "OPEN_2024.flag").exists():
        assert "2024" not in embedded["years"]


def test_page_is_offline(page):
    assert not re.search(r"<script[^>]+src=", page), "no external scripts"
    assert "<link" not in page and "@import" not in page and "url(http" not in page
    assert "fetch(" not in page and "XMLHttpRequest" not in page


def test_no_crash_records(page, embedded):
    assert '"actual":' not in page
    for s in embedded["years"].values():
        for d in s["days"]:
            assert set(d.get("actual_level", {})) <= set(s["road_ids"])
            assert all(0 <= v <= 4 for v in d.get("actual_level", {}).values())
