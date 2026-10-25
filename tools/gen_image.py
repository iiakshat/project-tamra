"""Generate one image with Gemini (Nano Banana) and save it as PNG.

Usage:
  python -I tools/gen_image.py OUT.png "prompt" [--ref a.png --ref b.png] [--aspect 16:9] [--size 2K]
                               [--model gemini-3-pro-image]

Reads GOOGLE_API_KEY from .env (never printed). Reference images keep characters
consistent across sheets. Record every prompt used for shipped art in ASSETS.md.
"""
import argparse
import base64
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent


def api_key() -> str:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.startswith("GOOGLE_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"')
    sys.exit("GOOGLE_API_KEY missing in .env")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("prompt")
    ap.add_argument("--ref", action="append", default=[])
    ap.add_argument("--aspect", default="1:1")
    ap.add_argument("--size", default="2K")
    ap.add_argument("--model", default="gemini-3-pro-image")
    a = ap.parse_args()

    parts = []
    for r in a.ref:
        data = pathlib.Path(r).read_bytes()
        parts.append({"inline_data": {"mime_type": "image/png", "data": base64.b64encode(data).decode()}})
    parts.append({"text": a.prompt})
    body = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {
            "responseModalities": ["IMAGE"],
            "imageConfig": {"aspectRatio": a.aspect, "imageSize": a.size},
        },
    }
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{a.model}:generateContent"
    req = urllib.request.Request(url, json.dumps(body).encode(), {
        "Content-Type": "application/json", "x-goog-api-key": api_key()})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                out = json.load(resp)
            break
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")[:400]
            if e.code in (429, 500, 503) and attempt < 2:
                print(f"HTTP {e.code}, retrying in 20 s", file=sys.stderr)
                time.sleep(20)
                continue
            sys.exit(f"HTTP {e.code}: {msg}")
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            if attempt < 2:
                print(f"network error ({e}), retrying in 20 s", file=sys.stderr)
                time.sleep(20)
                continue
            sys.exit(f"network error: {e}")
    for cand in out.get("candidates", []):
        for p in cand.get("content", {}).get("parts", []):
            blob = p.get("inline_data") or p.get("inlineData")
            if blob:
                pathlib.Path(a.out).parent.mkdir(parents=True, exist_ok=True)
                pathlib.Path(a.out).write_bytes(base64.b64decode(blob["data"]))
                print("saved", a.out)
                return
    sys.exit("no image in response: " + json.dumps(out)[:400])


if __name__ == "__main__":
    main()
