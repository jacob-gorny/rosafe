"""Guards for the project's rules: 2024 stays locked until the flag exists, the raw crash data and keys can never be
committed, no crash counts reach the app files, and the decision model's sheets carry no dates.

Run: cd notebook && .venv/bin/python -m pytest tests -q
"""
import json
import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
NOTEBOOK = ROOT / "notebook"
DATA = ROOT / "data"
OPEN_FLAG = NOTEBOOK / "OPEN_2024.flag"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)


@pytest.mark.skipif(OPEN_FLAG.exists(), reason="2024 has been opened")
def test_2024_still_locked():
    assert not (DATA / "scores_2024.json").exists(), "scores_2024.json exists but 2024 was never opened"
    cache = DATA / "chemistry_cache.jsonl"
    if cache.exists():
        days = {json.loads(line)["day"] for line in cache.read_text().splitlines() if line.strip()}
        assert not any(d.startswith("2024") for d in days), "2024 weather was sent to the decision model before step 14"


def test_raw_crash_data_and_keys_are_ignored():
    for path in ["notebook/dfw_crashes_2020_2024.csv.gz", "notebook/.env", "notebook/raw/anything.csv"]:
        assert git("check-ignore", "-q", path).returncode == 0, f"{path} is not git-ignored"


def test_nothing_raw_is_tracked():
    tracked = git("ls-files").stdout.split()
    assert not [f for f in tracked if f.endswith((".csv", ".csv.gz", ".gz", ".env")) or f.endswith("/.env")]
    assert "notebook/OPEN_2024.flag" not in tracked or OPEN_FLAG.exists()


@pytest.mark.parametrize("name", [p.name for p in DATA.glob("*.json")])
def test_no_crash_counts_in_app_files(name):
    text = (DATA / name).read_text()
    for word in ['"crashes"', '"crash_id"', '"count"', '"actual"', '"tot_injry_cnt"', '"death_cnt"']:
        assert word not in text, f"{name} contains {word}"


def test_geojson_has_no_raw_crash_fields():
    props = {k for f in json.loads((DATA / "roads.geojson").read_text())["features"] for k in f["properties"]}
    assert not props & {"crash_id", "crashes", "crash_date", "crash_time", "latitude", "longitude"}


def test_sheets_have_no_years():
    sheets = [p for p in (ROOT / "docs" / "chemistry_sheets").glob("v*.md") if re.fullmatch(r"v\d+\.md", p.name)]
    assert sheets, "no background sheet found"
    for p in sheets:
        main = p.read_text().split("---SOURCES---")[0]
        assert not re.search(r"\b(19|20)\d\d\b", main), f"{p.name} contains a year in the part the model reads"
