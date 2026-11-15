"""Runs the whole notebook top to bottom (about two minutes). Off by default; turn on with RUN_SLOW=1.

Run: cd notebook && RUN_SLOW=1 .venv/bin/python -m pytest tests/test_notebook_runs.py -q
"""
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

NOTEBOOK = Path(__file__).resolve().parents[1]


@pytest.mark.skipif(os.environ.get("RUN_SLOW") != "1", reason="slow: set RUN_SLOW=1")
def test_notebook_runs_top_to_bottom_under_ten_minutes():
    t0 = time.time()
    run = subprocess.run([sys.executable, "-I", "same_rain_different_road.py"], cwd=NOTEBOOK,
                         env={**os.environ, "MPLBACKEND": "Agg"}, capture_output=True, text=True, timeout=600)
    took = time.time() - t0
    assert run.returncode == 0, run.stderr[-3000:]
    assert took < 600, f"took {took:.0f} s"
    out = run.stdout
    assert "679,621 crashes" in out
    assert "Dry run of the final exam" in out
    if not (NOTEBOOK / "OPEN_2024.flag").exists():
        assert "2024 is still locked" in out
