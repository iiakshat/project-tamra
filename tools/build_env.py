"""Prepare the Gemini environment paintings in art_src/env for the game (assets/env).

For each palette (ember, marsh, palace):
  far   - opaque sky painting, made seamless left-right by cross-fading the ends
  mid   - chroma-keyed silhouette band, seamless left-right
  rock  - square ground texture, made seamless on both axes
  edge  - chroma-keyed ledge-top strip, cropped to the band, seamless left-right
Run: python -I tools/build_env.py
"""
import pathlib
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from slice_sheet import key_out  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art_src" / "env"
OUT = ROOT / "assets" / "env"
EDGE_MAX_H = {"ember": 0.09}  # the ash strip is a thick slab; keep its top crust only
EDGE_FIRST = {"palace"}  # two cornice bands were painted; use the top one
SETS = {"ember": ("c1", "green", "magenta"), "marsh": ("marsh", "magenta", "magenta"), "palace": ("palace", "green", "green")}


def seam_x(a: np.ndarray, frac: float = 0.08) -> np.ndarray:
    """Cross-fade the right end into the left so the image wraps without a seam."""
    w = int(a.shape[1] * frac)
    out = a[:, : a.shape[1] - w].astype(np.float32).copy()
    t = np.linspace(0.0, 1.0, w)[None, :, None]
    out[:, :w] = a[:, :w] * t + a[:, -w:] * (1.0 - t)
    return out.clip(0, 255).astype(np.uint8)


def seam_y(a: np.ndarray, frac: float = 0.08) -> np.ndarray:
    return seam_x(a.transpose(1, 0, 2), frac).transpose(1, 0, 2)


def save(a: np.ndarray, name: str, size=None) -> None:
    im = Image.fromarray(a)
    if size:
        im = im.resize(size, Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / name, optimize=True)
    print(name, im.size)


def main() -> None:
    for pal, (prefix, mid_key, edge_key) in SETS.items():
        far_p = SRC / f"{prefix}_far.png"
        if not far_p.exists():
            continue
        far = np.array(Image.open(far_p).convert("RGB"))
        far = seam_x(far)
        save(far, f"{pal}_far.png", (int(far.shape[1] * 900 / far.shape[0]), 900))

        mid = key_out(np.array(Image.open(SRC / f"{prefix}_mid.png").convert("RGBA")), mid_key)
        mid = seam_x(mid)
        ys = np.nonzero(mid[..., 3].max(axis=1) > 40)[0]
        mid = mid[ys.min():]
        save(mid, f"{pal}_mid.png", (int(mid.shape[1] * 520 / mid.shape[0]), 520))

        rock = np.array(Image.open(SRC / f"{prefix}_rock.png").convert("RGB"))
        rock = seam_y(seam_x(rock))
        save(rock, f"{pal}_rock.png", (512, 512))

        edge_p = SRC / f"{prefix}_edge.png"
        if edge_p.exists():
            edge = key_out(np.array(Image.open(edge_p).convert("RGBA")), edge_key)
            # Take the tallest unbroken run of painted rows (one band, not two).
            filled = edge[..., 3].mean(axis=1) > 25
            best, start = (0, 0), None
            for y, f in enumerate(list(filled) + [False]):
                if f and start is None:
                    start = y
                elif not f and start is not None:
                    if y - start > 20 and (best == (0, 0) or (pal not in EDGE_FIRST and y - start > best[1] - best[0])):
                        best = (start, y)
                    start = None
            top, bot = best
            bot = min(bot, top + int(edge.shape[1] * EDGE_MAX_H.get(pal, 1.0)))
            edge = edge[max(top - 4, 0): bot + 4]
            edge = seam_x(edge)
            save(edge, f"{pal}_edge.png", (int(edge.shape[1] * 96 / edge.shape[0]), 96))


if __name__ == "__main__":
    main()
