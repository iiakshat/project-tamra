"""Gemini TTS: one line of speech to a WAV file.

Usage:
  python -I tools/tts.py OUT.wav "text with [emotion] tags" --voice Puck
         [--model gemini-3.1-flash-tts-preview] [--style "Speak as ..."] [--pitch 1.18]

--style is prepended as a short director's note ("Say ...:" form, which the models act
on instead of reading aloud). --pitch > 1 raises pitch (and keeps tempo) with ffmpeg,
used to make a young boy's voice from an adult one. Reads GOOGLE_API_KEY from .env.
"""
import argparse
import base64
import json
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.request
import wave

ROOT = pathlib.Path(__file__).resolve().parent.parent
FFMPEG = ROOT.parent / "_tools" / "ffmpeg" / "ffmpeg.exe"


def api_key() -> str:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.startswith("GOOGLE_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"')
    sys.exit("GOOGLE_API_KEY missing in .env")


def synth(text: str, voice: str, model: str) -> bytes:
    body = {
        "contents": [{"role": "user", "parts": [{"text": text}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voice}}},
        },
    }
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    req = urllib.request.Request(url, json.dumps(body).encode(), {
        "Content-Type": "application/json", "x-goog-api-key": api_key()})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                out = json.load(resp)
            for p in out["candidates"][0]["content"]["parts"]:
                blob = p.get("inlineData") or p.get("inline_data")
                if blob:
                    return base64.b64decode(blob["data"])
            raise RuntimeError("no audio: " + json.dumps(out)[:300])
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")[:300]
            if e.code in (429, 500, 503) and attempt < 3:
                time.sleep(25 * (attempt + 1))
                continue
            sys.exit(f"HTTP {e.code}: {msg}")
        except (urllib.error.URLError, TimeoutError, ConnectionError, KeyError) as e:
            if attempt < 3:
                time.sleep(15)
                continue
            sys.exit(f"failed: {e}")
    sys.exit("failed")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("text")
    ap.add_argument("--voice", default="Puck")
    ap.add_argument("--model", default="gemini-3.1-flash-tts-preview")
    ap.add_argument("--style", default="")
    ap.add_argument("--pitch", type=float, default=1.0)
    a = ap.parse_args()
    text = f"{a.style}: {a.text}" if a.style else a.text
    pcm = synth(text, a.voice, a.model)
    out = pathlib.Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    raw = out.with_suffix(".raw.wav") if a.pitch != 1.0 else out
    with wave.open(str(raw), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(24000)
        w.writeframes(pcm)
    if a.pitch != 1.0:
        # Raise pitch, keep duration: resample up, then slow back down.
        af = f"asetrate={int(24000 * a.pitch)},aresample=24000,atempo={1.0 / a.pitch:.4f}"
        subprocess.run([str(FFMPEG), "-y", "-loglevel", "error", "-i", str(raw), "-af", af, str(out)], check=True)
        raw.unlink()
    print("saved", out)


if __name__ == "__main__":
    main()
