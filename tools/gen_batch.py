"""Generate many images through the Gemini Batch API (half the price of live calls).

Usage:
  python -I tools/gen_batch.py submit JOBS.json      # creates the batch, saves its name
  python -I tools/gen_batch.py wait JOBS.json        # polls until done, writes the PNGs

JOBS.json: {"model": "gemini-3-pro-image", "jobs": [
  {"key": "p01_plate", "out": "art_src/story/plates/p01_fire.png", "prompt": "...",
   "refs": ["art_src/story/p01_fire.png"], "aspect": "16:9", "size": "2K"}, ...]}
Jobs whose output already exists are skipped. Reference images are sent downscaled
(JPEG, 1024 px) to keep the request small. The batch name is stored next to JOBS.json.
"""
import base64
import io
import json
import pathlib
import sys
import time
import urllib.error
import urllib.request

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
API = "https://generativelanguage.googleapis.com/v1beta"


def api_key() -> str:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.startswith("GOOGLE_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"')
    sys.exit("GOOGLE_API_KEY missing")


def call(method: str, url: str, body=None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data, {"Content-Type": "application/json", "x-goog-api-key": api_key()}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read().decode(errors='replace')[:600]}")


def ref_part(path: str) -> dict:
    im = Image.open(ROOT / path).convert("RGB")
    im.thumbnail((1024, 1024))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=88)
    return {"inline_data": {"mime_type": "image/jpeg", "data": base64.b64encode(buf.getvalue()).decode()}}


def submit(jobs_path: pathlib.Path) -> None:
    spec = json.loads(jobs_path.read_text(encoding="utf-8"))
    reqs = []
    for j in spec["jobs"]:
        if (ROOT / j["out"]).exists():
            continue
        parts = [ref_part(r) for r in j.get("refs", [])] + [{"text": j["prompt"]}]
        reqs.append({"request": {"contents": [{"role": "user", "parts": parts}],
                                 "generationConfig": {"responseModalities": ["IMAGE"],
                                                      "imageConfig": {"aspectRatio": j.get("aspect", "16:9"),
                                                                      "imageSize": j.get("size", "2K")}}},
                     "metadata": {"key": j["key"]}})
    if not reqs:
        print("nothing to do")
        return
    body = {"batch": {"display_name": jobs_path.stem, "input_config": {"requests": {"requests": reqs}}}}
    out = call("POST", f"{API}/models/{spec.get('model', 'gemini-3-pro-image')}:batchGenerateContent", body)
    name = out.get("name") or out.get("metadata", {}).get("name")
    jobs_path.with_suffix(".batch").write_text(name)
    print("submitted", len(reqs), "requests as", name)


def wait(jobs_path: pathlib.Path) -> None:
    spec = json.loads(jobs_path.read_text(encoding="utf-8"))
    outs = {j["key"]: j["out"] for j in spec["jobs"]}
    name = jobs_path.with_suffix(".batch").read_text().strip()
    while True:
        b = call("GET", f"{API}/{name}")
        state = b.get("metadata", {}).get("state") or b.get("state", "")
        if b.get("done") or state in ("BATCH_STATE_SUCCEEDED", "BATCH_STATE_FAILED", "BATCH_STATE_CANCELLED", "BATCH_STATE_EXPIRED"):
            break
        print("state", state, flush=True)
        time.sleep(60)
    if "error" in b:
        sys.exit("batch error: " + json.dumps(b["error"])[:600])
    resp = b.get("response", {})
    items = resp.get("inlinedResponses", {}).get("inlinedResponses", [])
    saved = 0
    for it in items:
        key = it.get("metadata", {}).get("key", "")
        if "error" in it:
            print("FAILED", key, json.dumps(it["error"])[:300])
            continue
        for cand in it.get("response", {}).get("candidates", []):
            for p in cand.get("content", {}).get("parts", []):
                blob = p.get("inlineData") or p.get("inline_data")
                if blob and key in outs:
                    dest = ROOT / outs[key]
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(base64.b64decode(blob["data"]))
                    saved += 1
                    print("saved", outs[key])
                    break
    print("done:", saved, "images, state", state)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    {"submit": submit, "wait": wait}[sys.argv[1]](pathlib.Path(sys.argv[2]))
