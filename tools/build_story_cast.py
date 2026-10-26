"""Cut the story pose sheets (art_src/story/cast/<name>.png) into single poses:
assets/story/cast/<name>_<n>.png (n = 1.. in reading order), keyed and trimmed with
the feet at the bottom edge. Also converts story plates to JPG (assets/story/plates).
Run: python -I tools/build_story_cast.py
"""
import pathlib
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from slice_sheet import figures, key_out  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHEETS = ROOT / "art_src" / "story" / "cast"
OUT = ROOT / "assets" / "story" / "cast"
KEYS = {"maa": "magenta"}
MAX_H = 720


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for sheet in sorted(SHEETS.glob("*.png")):
        name = sheet.stem
        keyed = key_out(np.array(Image.open(sheet).convert("RGBA")), KEYS.get(name, "green"))
        figs = figures(keyed)
        n = 0
        for f in figs:
            ys, xs = np.nonzero(f[..., 3] > 30)
            f = f[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            if (f[..., 3] > 30).mean() < 0.12:
                continue  # an empty grid cell (thin lines only), not a figure
            n += 1
            i = n
            im = Image.fromarray(f)
            if im.height > MAX_H:
                im = im.resize((round(im.width * MAX_H / im.height), MAX_H), Image.LANCZOS)
            im.save(OUT / f"{name}_{i}.png", optimize=True)
        print(name, n, "poses")
    plates = ROOT / "art_src" / "story" / "plates"
    dest = ROOT / "assets" / "story" / "plates"
    dest.mkdir(parents=True, exist_ok=True)
    for p in sorted(plates.glob("*.png")):
        Image.open(p).convert("RGB").resize((1600, 900), Image.LANCZOS).save(dest / f"{p.stem}.jpg", quality=86, optimize=True)
        print("plate", p.stem)


if __name__ == "__main__":
    main()
