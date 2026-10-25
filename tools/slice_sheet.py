"""Turn a Gemini sprite sheet (character frames on flat green or magenta) into a clean,
aligned animation strip for the game.

Usage:
  python -I tools/slice_sheet.py SHEET.png OUT.png --grid 4x2 [--frames 8] [--height 260]
         [--key green|magenta] [--anchor head|mass] [--ref-height PX]

Steps per cell: chroma-key with despill, keep the biggest blob plus blobs touching it
(drops stray specks, grid lines and floor lines), crop. Frames are aligned so the feet
sit on one baseline and the head (or body mass) on one vertical line, then scaled so the
character's standing height is --height px. Writes OUT.png (frames side by side) and
OUT.json (frame size, count, foot anchor).
"""
import argparse
import json
import pathlib

import numpy as np
from PIL import Image, ImageFilter


def key_out(img: np.ndarray, key: str) -> np.ndarray:
    rgb = img[..., :3].astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    if key == "green":
        spill = g - np.maximum(r, b)
    else:  # magenta
        spill = np.minimum(r, b) - g
    # Fully keyed above 90, fully kept below 30, soft in between.
    alpha = np.clip(1.0 - (spill - 30.0) / 60.0, 0.0, 1.0)
    # Despill: pull the key channel down to the others on edge pixels.
    if key == "green":
        rgb[..., 1] = np.minimum(g, np.maximum(r, b) + 4.0)
    else:
        lim = g + 4.0
        rgb[..., 0] = np.where(spill > 0, np.minimum(r, lim + (r - b).clip(0)), r)
        rgb[..., 2] = np.where(spill > 0, np.minimum(b, lim + (b - r).clip(0)), b)
    out = np.dstack([rgb, alpha * 255.0]).clip(0, 255).astype(np.uint8)
    return out


def components(mask: np.ndarray):
    """Label 4-connected components without scipy. Returns label array and sizes."""
    h, w = mask.shape
    labels = np.zeros((h, w), np.int32)
    sizes = [0]
    cur = 0
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if labels[y0, x0]:
            continue
        cur += 1
        stack = [(y0, x0)]
        labels[y0, x0] = cur
        n = 0
        while stack:
            y, x = stack.pop()
            n += 1
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not labels[yy, xx]:
                    labels[yy, xx] = cur
                    stack.append((yy, xx))
        sizes.append(n)
    return labels, sizes


def strip_lines(cell: np.ndarray) -> None:
    """Remove drawn grid/floor lines: rows or columns mostly made of dark opaque pixels."""
    dark = (cell[..., 3] > 100) & (cell[..., :3].max(axis=2) < 70)
    h, w = dark.shape
    for y in np.nonzero(dark.sum(axis=1) > w * 0.35)[0]:
        cell[max(0, y - 2):y + 3, :, 3] = np.where(dark[max(0, y - 2):y + 3], 0, cell[max(0, y - 2):y + 3, :, 3])
    for x in np.nonzero(dark.sum(axis=0) > h * 0.35)[0]:
        cell[:, max(0, x - 2):x + 3, 3] = np.where(dark[:, max(0, x - 2):x + 3], 0, cell[:, max(0, x - 2):x + 3, 3])


def clean(cell: np.ndarray) -> np.ndarray:
    strip_lines(cell)
    a = cell[..., 3]
    # Work on a downscaled mask for speed, then map back.
    small = Image.fromarray(a).resize((a.shape[1] // 4, a.shape[0] // 4), Image.BILINEAR)
    m = np.array(small) > 100
    labels, sizes = components(m)
    if len(sizes) <= 1:
        return cell
    big = int(np.argmax(sizes[1:])) + 1
    keep = np.zeros_like(m)
    keep[labels == big] = True
    # Keep sizeable blobs whose bbox overlaps the main blob (a detached hand, hair tuft).
    by, bx = np.nonzero(labels == big)
    y0, y1, x0, x1 = by.min(), by.max(), bx.min(), bx.max()
    for i, s in enumerate(sizes[1:], start=1):
        if i == big or s < sizes[big] * 0.03:
            continue
        iy, ix = np.nonzero(labels == i)
        thin = (iy.max() - iy.min() < 4) or (ix.max() - ix.min() < 4)
        if thin:
            continue  # grid or floor line
        if iy.min() <= y1 + 6 and iy.max() >= y0 - 6 and ix.min() <= x1 + 6 and ix.max() >= x0 - 6:
            keep[labels == i] = True
    km = Image.fromarray((keep * 255).astype(np.uint8)).resize((a.shape[1], a.shape[0]), Image.NEAREST)
    km = km.filter(ImageFilter.MaxFilter(9))
    out = cell.copy()
    out[..., 3] = np.minimum(a, np.array(km))
    return out


def figures(keyed: np.ndarray) -> list:
    """Find each drawn figure as a group of blobs (for sheets whose poses ignore the grid).
    Returns full-resolution RGBA crops in reading order (rows top to bottom, then x)."""
    a = keyed[..., 3]
    f = 4
    small = np.array(Image.fromarray(a).resize((a.shape[1] // f, a.shape[0] // f), Image.BILINEAR)) > 100
    labels, sizes = components(small)
    biggest = max(sizes[1:])
    boxes = {}
    for i, n in enumerate(sizes[1:], start=1):
        if n < biggest * 0.004:
            continue
        ys, xs = np.nonzero(labels == i)
        if ys.max() - ys.min() < 4 or xs.max() - xs.min() < 4:
            continue
        boxes[i] = [ys.min(), ys.max(), xs.min(), xs.max(), n]
    mains = [i for i, b in boxes.items() if b[4] >= biggest * 0.15]
    groups = {m: [m] for m in mains}
    for i, b in boxes.items():
        if i in groups:
            continue
        cy, cx = (b[0] + b[1]) / 2, (b[2] + b[3]) / 2
        best, dist = None, 1e9
        for m in mains:
            mb = boxes[m]
            dy = max(mb[0] - cy, 0, cy - mb[1])
            dx = max(mb[2] - cx, 0, cx - mb[3])
            d = (dx * dx + dy * dy) ** 0.5
            if d < dist:
                best, dist = m, d
        if best is not None and dist < 12:
            groups[best].append(i)
    H = small.shape[0]
    order = sorted(mains, key=lambda m: ((boxes[m][0] + boxes[m][1]) / 2, boxes[m][2]))
    rows, cur = [], []
    for m in order:
        cy = (boxes[m][0] + boxes[m][1]) / 2
        if cur and abs(cy - (boxes[cur[0]][0] + boxes[cur[0]][1]) / 2) > H * 0.2:
            rows.append(cur)
            cur = []
        cur.append(m)
    rows.append(cur)
    out = []
    for row in rows:
        for m in sorted(row, key=lambda m: boxes[m][2]):
            mask = np.isin(labels, groups[m])
            big = np.array(Image.fromarray((mask * 255).astype(np.uint8)).resize((a.shape[1], a.shape[0]), Image.NEAREST))
            big = np.array(Image.fromarray(big).filter(ImageFilter.MaxFilter(9)))
            ys, xs = np.nonzero(big)
            y0, y1, x0, x1 = max(ys.min() - 8, 0), ys.max() + 8, max(xs.min() - 8, 0), xs.max() + 8
            crop = keyed[y0:y1, x0:x1].copy()
            crop[..., 3] = np.minimum(crop[..., 3], big[y0:y1, x0:x1])
            pad = np.zeros((crop.shape[0] + 16, crop.shape[1] + 16, 4), np.uint8)
            pad[8:-8, 8:-8] = crop
            out.append(pad)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("out")
    ap.add_argument("--grid", default="4x2")
    ap.add_argument("--frames", type=int, default=0)
    ap.add_argument("--height", type=int, default=260, help="output px for --ref-height source px")
    ap.add_argument("--ref-height", type=float, default=0, help="source px that maps to --height (default: tallest frame)")
    ap.add_argument("--key", default="green")
    ap.add_argument("--anchor", default="head", choices=["head", "mass", "feet", "torso"])
    ap.add_argument("--pad", type=int, default=12)
    ap.add_argument("--flip", action="store_true", help="mirror frames (art drawn facing left)")
    ap.add_argument("--pick", default="", help="1-based cells to output, in order, e.g. 2,3,4")
    ap.add_argument("--calib", type=int, default=0, help="1-based cell of a standing pose whose height maps to --height")
    a = ap.parse_args()

    img = np.array(Image.open(a.sheet).convert("RGBA"))
    keyed = key_out(img, a.key)
    H, W = keyed.shape[:2]
    auto = figures(keyed) if a.grid == "auto" else None
    if auto is not None:
        cols, rows = len(auto), 1
    else:
        cols, rows = (int(v) for v in a.grid.split("x"))
    cw, ch = W // cols, H // rows
    count = a.frames or cols * rows
    picks = [int(v) - 1 for v in a.pick.split(",")] if a.pick else list(range(count))
    cells = sorted(set(picks + ([a.calib - 1] if a.calib else [])))
    found = {}
    for i in cells:
        cx, cy = i % cols, i // cols
        cell = auto[i] if auto is not None else keyed[cy * ch:(cy + 1) * ch, cx * cw:(cx + 1) * cw]
        # Shave the cell border (grid lines live there).
        cell = cell.copy()
        cell[:6, :, 3] = 0
        cell[-6:, :, 3] = 0
        cell[:, :6, 3] = 0
        cell[:, -6:, 3] = 0
        cell = clean(cell)
        ys, xs = np.nonzero(cell[..., 3] > 40)
        if len(ys) == 0:
            raise SystemExit(f"frame {i} is empty")
        y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
        crop = cell[y0:y1 + 1, x0:x1 + 1]
        hgt = y1 - y0 + 1
        al = crop[..., 3] > 40
        if a.anchor == "head":
            top = al[: max(1, int(hgt * 0.3))]
            ax = float(np.nonzero(top)[1].mean())
        elif a.anchor == "feet":
            bot = al[int(hgt * 0.85):]
            ax = float(np.nonzero(bot)[1].mean())
        elif a.anchor == "torso":
            band = al[int(hgt * 0.25):int(hgt * 0.6)]
            ax = float(np.nonzero(band)[1].mean()) if band.any() else float(np.nonzero(al)[1].mean())
        else:
            ax = float(np.nonzero(al)[1].mean())
        found[i] = (crop, ax, hgt)

    crops = [found[i] for i in picks]
    count = len(crops)
    ref = a.ref_height or (found[a.calib - 1][2] if a.calib else max(c[2] for c in crops))
    scale = a.height / ref
    left = max(c[1] for c in crops) * scale
    right = max((c[0].shape[1] - c[1]) for c in crops) * scale
    tallest = max(c[2] for c in crops) * scale
    fw = int(np.ceil(left + right)) + 2 * a.pad
    fh = int(np.ceil(tallest)) + 2 * a.pad
    strip = Image.new("RGBA", (fw * count, fh), (0, 0, 0, 0))
    for i, (crop, ax, hgt) in enumerate(crops):
        im = Image.fromarray(crop)
        nw, nh = max(1, round(im.width * scale)), max(1, round(im.height * scale))
        im = im.resize((nw, nh), Image.LANCZOS)
        x = round(i * fw + a.pad + left - ax * scale)
        y = fh - a.pad - nh  # feet on the baseline
        strip.alpha_composite(im, (x, y))
    if a.flip:
        frames = [strip.crop((i * fw, 0, (i + 1) * fw, fh)).transpose(Image.FLIP_LEFT_RIGHT) for i in range(count)]
        strip = Image.new("RGBA", strip.size, (0, 0, 0, 0))
        for i, f in enumerate(frames):
            strip.alpha_composite(f, (i * fw, 0))
        left = fw - 2 * a.pad - left
    pathlib.Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    strip.save(a.out, optimize=True)
    meta = {"frames": count, "frame_w": fw, "frame_h": fh, "anchor_x": round(a.pad + left), "anchor_y": fh - a.pad,
            "scale": scale}
    pathlib.Path(a.out).with_suffix(".json").write_text(json.dumps(meta, indent=1))
    print(json.dumps(meta))


if __name__ == "__main__":
    main()
