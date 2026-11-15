"""Rerun the Nov 15 checks behind the alert decision (2021 to 2023 only) on a temporary copy of the repo.

From the repo root:
    notebook/.venv/bin/python docs/proposals/dry-day-alerts/analysis/run_checks.py             # day-after-rain check
    notebook/.venv/bin/python docs/proposals/dry-day-alerts/analysis/run_checks.py --variants  # plus 3 retrained models

It takes the notebook as it was at commit 3096948 (before the rain-or-ice change; that commit is in the team's private working repo,
not in the public copy), cuts it right after step 12's
rain/dry split, appends day_after_rain.py (and variant_summary.py), and runs it in a temporary folder with 2024 locked.
It needs the crash file in notebook/ (the notebook's own download step makes it). Nothing in the repo changes, and 2024
never enters a number: the practice frames stop at 2023-12-31, which the notebook asserts. About 90 seconds per run.
"""
import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
COMMIT = "3096948"
CRASH = "dfw_crashes_2020_2024.csv.gz"
OLD = "FEAT_D = FEAT_B + ROAD_FEATURES\n"
TIMING = "assert max(timings.values()) < 240\n"
GATE = 'road["rain_last_7_on_rain"] = road["rain_last_7_mm"] * road["rained"]   # rain history only on rain days\n'
NO_DRY_HIST = '[c for c in FEAT_B if c not in ("days_since_rain", "rain_last_7_mm")] + ["rain_last_7_on_rain"]'
VARIANTS = {  # Model D's inputs in each retrained version
    "V0": OLD,                                                                       # the shipped model
    "V1": GATE + f"FEAT_D = {NO_DRY_HIST} + ROAD_FEATURES\n",                        # no dry-spell inputs
    "V2": 'assert "weekday" in road.columns\nFEAT_D = FEAT_B + ROAD_FEATURES + ["weekday"]\n',  # adds the weekday
    "V3": GATE + 'assert "weekday" in road.columns\n' + f'FEAT_D = {NO_DRY_HIST} + ROAD_FEATURES + ["weekday"]\n',
}


def notebook_cut():
    src = subprocess.run(["git", "-C", str(REPO), "show", f"{COMMIT}:notebook/same_rain_different_road.py"],
                         check=True, capture_output=True, text=True).stdout
    head = src[:src.index("# ### The 2023 file\n")]
    cut = head.rsplit("# %% [markdown]\n", 1)[0]            # end right after step 12's rain/dry split
    assert cut.count(OLD) == 1 and cut.count(TIMING) == 1
    return cut


def copy_repo(dest):
    skip = shutil.ignore_patterns(".git", ".venv", "__pycache__", ".superpowers", ".claude", ".pytest_cache", CRASH)
    shutil.copytree(REPO, dest, ignore=skip)
    (dest / "notebook" / CRASH).symlink_to(REPO / "notebook" / CRASH)
    (dest / "notebook" / "OPEN_2024.flag").unlink(missing_ok=True)   # these checks always run with 2024 locked


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variants", action="store_true", help="also run the three retrained versions of Model D")
    ap.add_argument("--out", default=None, help="folder for outputs (default: a new temporary folder)")
    args = ap.parse_args()
    assert (REPO / "notebook" / CRASH).exists(), "run the notebook once first, so the crash file exists"
    out = Path(args.out or tempfile.mkdtemp(prefix="alert_checks_"))
    out.mkdir(parents=True, exist_ok=True)
    cut = notebook_cut()
    analysis = (HERE / "day_after_rain.py").read_text()
    summary = (HERE / "variant_summary.py").read_text()
    python = REPO / "notebook" / ".venv" / "bin" / "python"
    for v in (["V0", "V1", "V2", "V3"] if args.variants else ["V0"]):
        work = Path(tempfile.mkdtemp(prefix=f"alert_checks_{v}_"))
        copy_repo(work / "repo")
        body = cut.replace(OLD, VARIANTS[v]).replace(TIMING, "print('timings', timings)\n")
        script = work / "repo" / "notebook" / "run_check.py"
        script.write_text(body + analysis + (summary if args.variants else ""))
        env = dict(os.environ, MPLBACKEND="Agg", VARIANT=v, DAYAFTER_OUT=str(out / f"results_{v}.json"))
        with open(out / f"out_{v}.txt", "w") as fh:
            subprocess.run([str(python), script.name], cwd=script.parent, env=env, stdout=fh, stderr=subprocess.STDOUT,
                           check=True)
        shutil.rmtree(work)
        print(f"{v}: done, output in {out / f'out_{v}.txt'}")


if __name__ == "__main__":
    main()
