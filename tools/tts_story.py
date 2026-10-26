"""Voice every story line in config/story.json with Gemini TTS emotion tags.

For each beat with a `voice` id that has no audio/voice/<id>.ogg yet:
  1. synthesize "[tag] text" with the speaker's voice (config/voice_lines.json "story_voices"),
  2. trim leading/trailing silence, convert to OGG Vorbis (q4) in audio/voice/,
  3. ask Gemini to listen (tools/voice_check.py) and retry up to twice when the take
     reads a tag aloud, whispers, sounds like the wrong age, or drops words.
Work files live in ../voice_work (outside the repo). Writes a report to ../voice_work/report.jsonl.

Usage: python -I tools/tts_story.py [--only st_c1_02,st_c1_03a] [--force]
"""
import argparse
import json
import pathlib
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from tts import synth  # noqa: E402
from voice_check import check  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
FFMPEG = ROOT.parent / "_tools" / "ffmpeg" / "ffmpeg.exe"
WORK = ROOT.parent / "voice_work"
OUT = ROOT / "audio" / "voice"
TRIM = ("silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse,"
        "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,areverse")


def beats(story: dict):
    for sid, panels in story.items():
        if sid.startswith("_"):
            continue
        for panel in panels:
            for b in panel.get("beats", []):
                if "choice" in b:
                    for opt in b["options"]:
                        for r in opt.get("reply", []):
                            yield r
                else:
                    yield b


def wav_write(path: pathlib.Path, pcm: bytes) -> None:
    import wave
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(24000)
        w.writeframes(pcm)


def bad(review: dict, speaker: str, cfg: dict) -> str:
    if "error" in review:
        return ""
    if review.get("spoke_tags_or_directions"):
        return "read a tag aloud"
    if review.get("whispering") and not cfg.get("whisper_ok"):
        return "whispering"
    if review.get("repeated_or_doubled"):
        return "doubled"
    want_age = cfg.get("age")
    if want_age and review.get("apparent_age") not in want_age:
        return "age " + str(review.get("apparent_age"))
    if str(review.get("accent", "")).lower().startswith("foreign"):
        return "foreign accent"
    return ""


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--model", default="gemini-3.1-flash-tts-preview")
    a = ap.parse_args()
    only = set(filter(None, a.only.split(",")))
    story = json.loads((ROOT / "config" / "story.json").read_text(encoding="utf-8"))
    voices = json.loads((ROOT / "config" / "voice_lines.json").read_text(encoding="utf-8"))["story_voices"]
    WORK.mkdir(exist_ok=True)
    report = open(WORK / "report.jsonl", "a", encoding="utf-8")
    for b in beats(story):
        vid = b.get("voice", b.get("voice_pending", ""))
        if not vid or (only and vid not in only):
            continue
        ogg = OUT / f"{vid}.ogg"
        if ogg.exists() and not a.force and not only:
            continue
        cfg = voices[b["speaker"]]
        text = b["hi"]
        tag = b.get("tag", "")
        prompt = f"[{tag}] {text}" if tag else text
        if cfg.get("prefix"):
            prompt = f"{cfg['prefix']} {prompt}"
        best, why = None, ""
        for attempt in range(3):
            raw = WORK / f"{vid}.raw.wav"
            wav = WORK / f"{vid}.wav"
            wav_write(raw, synth(prompt, cfg["voice"], a.model))
            af = TRIM
            if cfg.get("pitch", 1.0) != 1.0:
                p = cfg["pitch"]
                af = f"asetrate={int(24000 * p)},aresample=24000,atempo={1 / p:.4f}," + TRIM
            subprocess.run([str(FFMPEG), "-y", "-loglevel", "error", "-i", str(raw), "-af", af, str(wav)], check=True)
            review = check(wav, text, "gemini-3.8-flash")
            why = bad(review, b["speaker"], cfg)
            best = wav
            print(vid, b["speaker"], f"try{attempt + 1}", review.get("emotion"), review.get("apparent_age"),
                  "OK" if not why else "RETRY: " + why, flush=True)
            report.write(json.dumps({"id": vid, "try": attempt + 1, "why": why, "review": review}, ensure_ascii=False) + "\n")
            if not why:
                break
            time.sleep(2)
        OUT.mkdir(parents=True, exist_ok=True)
        subprocess.run([str(FFMPEG), "-y", "-loglevel", "error", "-i", str(best), "-c:a", "libvorbis", "-q:a", "4", str(ogg)], check=True)
        time.sleep(1.5)
    report.close()


if __name__ == "__main__":
    main()
