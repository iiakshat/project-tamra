"""Split a story panel into an empty background plate and character cut-outs, offline.

The panels in art_src/story are single paintings. To animate the cast (move, breathe,
change pose) each figure must be its own layer. This uses rembg (local segmentation
model) to find the figures, splits the mask into separate figures (largest blobs, left
to right), and OpenCV inpainting to fill the plate where they stood.

Usage:
  python -I tools/story_cutout.py p01_fire --names maa,tamra [--min 0.01] [--erase-light]
Writes assets/story/plates/<panel>.jpg and assets/story/cast/<panel>_<name>.png, and
prints each cut-out's feet position and height as fractions of the panel (for story.json).
"""
import argparse
import json
import pathlib

import cv2
import numpy as np
from PIL import Image
from rembg import new_session, remove

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art_src" / "story"
PLATES = ROOT / "assets" / "story" / "plates"
CAST = ROOT / "assets" / "story" / "cast"
W, H = 1600, 900


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("panel")
    ap.add_argument("--names", default="")
    ap.add_argument("--min", type=float, default=0.012, help="smallest figure, fraction of the image area")
    ap.add_argument("--model", default="isnet-general-use")
    ap.add_argument("--erase-light", action="store_true", help="also inpaint thin bright light strokes (drawn signs)")
    ap.add_argument("--keep", default="", help="comma list of figure indices to keep (after left-to-right sort)")
    ap.add_argument("--split", default="", help="x fractions where touching figures are cut apart, e.g. 0.42")
    ap.add_argument("--inpaint", action="store_true", help="fill the plate where figures stood (else the plate keeps them; cut-outs overlay their painted selves)")
    a = ap.parse_args()

    img = Image.open(SRC / f"{a.panel}.png").convert("RGB").resize((W, H), Image.LANCZOS)
    rgb = np.array(img)
    cut = np.array(remove(img, session=new_session(a.model)))  # RGBA
    alpha = cut[..., 3]
    mask = (alpha > 110).astype(np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    for fx in [float(v) for v in a.split.split(",") if v]:
        x = int(fx * W)
        mask[:, x - 1:x + 1] = 0
    n, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    figs = [i for i in range(1, n) if stats[i, cv2.CC_STAT_AREA] >= a.min * W * H]
    figs.sort(key=lambda i: stats[i, cv2.CC_STAT_LEFT])
    if a.keep:
        figs = [figs[int(k)] for k in a.keep.split(",")]
    names = [s for s in a.names.split(",") if s] or [f"fig{k}" for k in range(len(figs))]

    hole = np.zeros((H, W), np.uint8)
    out = {}
    CAST.mkdir(parents=True, exist_ok=True)
    PLATES.mkdir(parents=True, exist_ok=True)
    for name, i in zip(names, figs):
        m = (labels == i).astype(np.uint8)
        x, y, w, h = stats[i, :4]
        soft = np.where(m > 0, alpha, 0).astype(np.uint8)
        rgba = np.dstack([rgb, soft])[y:y + h, x:x + w]
        Image.fromarray(rgba).save(CAST / f"{a.panel}_{name}.png", optimize=True)
        if a.inpaint:
            hole |= cv2.dilate(m, np.ones((17, 17), np.uint8))
        out[name] = {"art": f"{a.panel}_{name}", "at": [round((x + w / 2) / W, 4), round((y + h) / H, 4)],
                     "h": round(h / H, 4), "box": [int(x), int(y), int(w), int(h)]}
    if a.erase_light:
        hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
        bright = ((hsv[..., 2] > 200) & (hsv[..., 1] < 120)).astype(np.uint8)
        # Thin strokes only: remove what survives an opening by a wide kernel (moon, fire).
        big = cv2.morphologyEx(bright, cv2.MORPH_OPEN, np.ones((15, 15), np.uint8))
        thin = cv2.dilate(bright & (1 - big), np.ones((11, 11), np.uint8))
        hole |= thin
    plate = cv2.inpaint(rgb, hole * 255, 9, cv2.INPAINT_TELEA) if hole.any() else rgb
    Image.fromarray(plate).save(PLATES / f"{a.panel}.jpg", quality=88, optimize=True)
    print(json.dumps(out))


if __name__ == "__main__":
    main()
