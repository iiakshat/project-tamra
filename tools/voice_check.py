"""Ask Gemini to listen to voice clips and judge them, since nobody on the team can
listen during generation. For each WAV/OGG prints JSON: transcript, whether any
[bracket tag] or stage direction was spoken aloud, delivered emotion, apparent speaker
age and gender, whispering, accent, and doubled/repeated phrases.

Usage: python -I tools/voice_check.py FILE [FILE ...] [--expect "text"]
"""
import argparse
import base64
import json
import pathlib
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROMPT = """You are a voice director checking a game voice clip (Hindi, sometimes Sanskrit).
Listen carefully and answer ONLY with compact JSON:
{"transcript": "<exact words in Devanagari>",
 "spoke_tags_or_directions": true/false (did the speaker read out any bracketed tag like 'excited', 'panicked', or a direction like 'say this angrily'),
 "emotion": "<the emotion actually heard, e.g. excited, terrified, sobbing, angry, calm, flat>",
 "intensity": 1-5,
 "apparent_age": "<child / teen / adult / elderly>",
 "gender": "<male/female>",
 "whispering": true/false,
 "accent": "<native Hindi / Indian English / foreign>",
 "repeated_or_doubled": true/false,
 "problems": "<short note or empty>"}"""


def api_key() -> str:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.startswith("GOOGLE_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"')
    sys.exit("GOOGLE_API_KEY missing")


def check(path: pathlib.Path, expect: str, model: str) -> dict:
    mime = "audio/wav" if path.suffix == ".wav" else "audio/ogg"
    prompt = PROMPT + (f"\nExpected text: {expect}" if expect else "")
    body = {"contents": [{"role": "user", "parts": [
        {"inline_data": {"mime_type": mime, "data": base64.b64encode(path.read_bytes()).decode()}},
        {"text": prompt}]}],
        "generationConfig": {"responseMimeType": "application/json", "temperature": 0.1}}
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    req = urllib.request.Request(url, json.dumps(body).encode(), {"Content-Type": "application/json", "x-goog-api-key": api_key()})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                out = json.load(r)
            return json.loads(out["candidates"][0]["content"]["parts"][0]["text"])
        except (urllib.error.URLError, TimeoutError, KeyError, json.JSONDecodeError) as e:
            if attempt == 3:
                return {"error": str(e)[:200]}
            time.sleep(15)
    return {}


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--expect", default="")
    ap.add_argument("--model", default="gemini-3.8-flash")
    a = ap.parse_args()
    for f in a.files:
        r = check(pathlib.Path(f), a.expect, a.model)
        print(pathlib.Path(f).name, json.dumps(r, ensure_ascii=False))


if __name__ == "__main__":
    main()
