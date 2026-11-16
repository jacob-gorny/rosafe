"""Rosafe app icon, drawn from our own shapes (no SF Symbols): a slate cloud with blue rain over a dark road.
Dev tool, needs Pillow: python draw_icon.py AppIcon.png
Same idea and colours as the icon picked from mockups. Drawn at 4096 px and shrunk to 1024 x 1024 RGB, no alpha."""
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

SS = 4                                   # supersample factor: draw at 4096, shrink to 1024
N = 1024 * SS
BG, CLOUD, RAIN, ROAD = "#EAF2FC", "#8FA6C8", "#2D7FF9", "#3A3F47"
s = lambda v: v * SS


def capsule(x0, y0, x1, y1, w, steps=48):
    """One rounded stroke from (x0, y0) to (x1, y1), w wide, as a single polygon (exact round ends)."""
    x0, y0, x1, y1, r = s(x0), s(y0), s(x1), s(y1), s(w) / 2
    a = math.atan2(y1 - y0, x1 - x0)
    pts = []
    for cx, cy, start in ((x1, y1, a - math.pi / 2), (x0, y0, a + math.pi / 2)):
        for k in range(steps + 1):
            t = start + math.pi * k / steps
            pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
    return pts


img = Image.new("RGB", (N, N), BG)
draw = ImageDraw.Draw(img)

# Cloud: puffs on a flat rounded base, drawn as a mask, then blurred and re-thresholded so the outline runs
# smoothly where the shapes meet.
mask = Image.new("L", (N, N), 0)
m = ImageDraw.Draw(mask)
for cx, cy, r in ((420, 330, 92), (540, 285, 128), (650, 345, 82)):
    m.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], fill=255)
m.rounded_rectangle([s(318), s(330), s(722), s(428)], radius=s(49), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(s(9))).point(lambda v: 255 if v >= 128 else 0)
img.paste(CLOUD, (0, 0), mask)

# Rain: four short slanted streaks under the cloud.
for x in (418, 486, 554, 622):
    draw.polygon(capsule(x + 14, 466, x - 10, 518, 22), fill=RAIN)

# Road: two edges that narrow toward the horizon, and a dashed centre line that grows toward the viewer.
draw.polygon(capsule(392, 586, 214, 884, 44), fill=ROAD)
draw.polygon(capsule(632, 586, 810, 884, 44), fill=ROAD)
for y0, y1, w in ((590, 628, 22), (668, 722, 28), (768, 840, 34)):
    draw.polygon(capsule(512, y0, 512, y1, w), fill=ROAD)

out = img.resize((1024, 1024), Image.LANCZOS).convert("RGB")
out.save(sys.argv[1], optimize=True)
print("wrote", sys.argv[1], out.size, out.mode)
