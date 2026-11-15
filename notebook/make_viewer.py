"""Builds docs/demo/index.html: an offline map of the model's daily scores, for judges and the demo video.

It pastes data/roads.geojson and every real data/scores_YYYY.json into viewer_template.html, so the page opens with a
double-click: no server, no internet, no libraries. It holds only what the app files already hold (rounded scores,
averaged road shapes, a 0-4 level for the 5 busiest roads), never crash records.

Run it after the notebook rewrites the data files:
    cd notebook && .venv/bin/python make_viewer.py
tests/test_viewer.py fails if the page and the data files ever disagree.
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = ROOT / "data"
TEMPLATE = HERE / "viewer_template.html"
OUT = ROOT / "docs" / "demo" / "index.html"
MARK = "/*__VIEWER_DATA__*/"


def payload():
    """Everything the page needs, as one JSON object: the road shapes and each real year of scores."""
    roads = json.loads((DATA / "roads.geojson").read_text())
    years = {}
    for path in sorted(DATA.glob("scores_*.json")):
        scores = json.loads(path.read_text())
        if scores.get("made_up"):
            continue                                   # sample.json-style files are never shown as real
        years[str(scores["year"])] = scores
    if not years:
        raise SystemExit("No real scores file in data/. Run the notebook first.")
    return {"roads": roads, "years": years}


def build(out=OUT):
    html = TEMPLATE.read_text()
    if html.count(MARK) != 1:
        raise SystemExit(f"{TEMPLATE.name} must contain {MARK} exactly once")
    data = payload()
    blob = json.dumps(data, separators=(",", ":"), ensure_ascii=False).replace("</", "<\\/")   # can't close the tag early
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html.replace(MARK, blob))
    return out, sorted(data["years"])


if __name__ == "__main__":
    path, years = build()
    print(f"Wrote {path.relative_to(ROOT)} ({path.stat().st_size / 1e6:.1f} MB) with scores for {', '.join(years)}")
