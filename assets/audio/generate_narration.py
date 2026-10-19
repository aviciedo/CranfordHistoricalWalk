#!/usr/bin/env python3
"""Generate the approved stop-1 recording. Credentials are read only from the environment.

Requires requirements.txt, ffmpeg and ffprobe. --check never contacts OpenAI.
The recording is intentionally not wired into the app until audio review passes.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent


def run(command):
    return subprocess.run(command, check=True, capture_output=True, text=True).stdout


def probe(path):
    return json.loads(run(["ffprobe", "-v", "error", "-show_format", "-show_streams",
                           "-of", "json", str(path)]))


def loudness(path):
    result = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af",
                             "loudnorm=I=-16:TP=-2:LRA=11:print_format=json",
                             "-f", "null", "-"], check=True, capture_output=True, text=True)
    return json.loads(re.findall(r'\{\s*"input_i".*?\}', result.stderr, re.S)[-1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate local inputs without API requests")
    parser.add_argument("--force", action="store_true", help="Explicitly authorize replacing an existing recording")
    args = parser.parse_args()
    profile = json.loads((ROOT / "narrator_profile.json").read_text())
    recording = profile["approved_recording"]
    master = (ROOT / recording["transcript"]).read_text(encoding="utf-8").rstrip("\n")
    title, body = master.split("\n\n", 1)
    assert title == recording["title"], "Unexpected metadata title"
    assert hashlib.sha256(body.encode()).hexdigest() == recording["spoken_body_sha256"], "Approved words changed"
    assert len(body.split()) == recording["word_count"]
    # This approved script fits a single request, avoiding segment-to-segment voice changes.
    assert len(body) <= 4096, "Review input limits and split only at paragraph boundaries"
    for program in ["ffmpeg", "ffprobe"]:
        if not shutil.which(program):
            raise SystemExit(f"Missing required audio tool: {program}")
    if args.check:
        print(f"PASS: exact approved text ({len(body.split())} spoken words); title excluded; audio tools available")
        return
    output = ROOT / recording["target_output"]
    if output.exists() and not args.force:
        raise SystemExit("Recording already exists. Review it before explicitly using --force; regeneration is billable.")
    key = os.environ.get(profile["api_key_environment_variable"])
    if not key:
        raise SystemExit("Missing secure narration API key binding. No speech request was sent.")
    from openai import OpenAI, OpenAIError
    client = OpenAI(api_key=key, base_url="https://api.openai.com/v1", max_retries=0, timeout=180)
    stage = "generating speech"
    try:
        # A key restricted to Audio/Speech need not have Models/Read permission.
        # Submit only the authorized speech request; authentication, model-access and
        # billing failures from that endpoint are never retried automatically.
        with tempfile.TemporaryDirectory(prefix="cranford-narration-") as tmp:
            raw = Path(tmp) / "generated.wav"
            mono = Path(tmp) / "mono.wav"
            stage = "generating speech"
            with client.audio.speech.with_streaming_response.create(
                model=profile["model"], voice=profile["voice"], input=body,
                instructions=profile["instructions"], response_format="wav", speed=1.0,
            ) as response:
                response.stream_to_file(raw)
            stage = "processing audio"
            run(["ffmpeg", "-v", "error", "-y", "-i", str(raw), "-ac", "1", "-ar", "44100", str(mono)])
            seconds = float(probe(mono)["format"]["duration"])
            wpm = len(body.split()) * 60 / seconds
            tempo = 1.0 if 135 <= wpm <= 145 else 140 / wpm
            if not 0.8 <= tempo <= 1.2:
                raise SystemExit("Delivery pace needs manual review; no aggressive time stretching was applied.")
            paced = Path(tmp) / "paced.wav"
            run(["ffmpeg", "-v", "error", "-y", "-i", str(mono), "-af", f"atempo={tempo:.8f}", str(paced)])
            levels = loudness(paced)
            integrated, peak = float(levels["input_i"]), float(levels["input_tp"])
            assert math.isfinite(integrated) and math.isfinite(peak), "Empty or invalid generated audio"
            # Static gain preserves dynamics; no limiter or dynamic compression is used.
            gain = min(-16 - integrated, -2 - peak) if not (-18 <= integrated <= -14 and peak <= -2) else 0
            temporary_mp3 = Path(tmp) / "final.mp3"
            run(["ffmpeg", "-v", "error", "-y", "-i", str(paced), "-af", f"volume={gain:.4f}dB",
                 "-ac", "1", "-ar", "44100", "-c:a", "libmp3lame", "-b:a", "128k",
                 "-metadata", f"title={title}", "-metadata", "artist=AI narration — OpenAI cedar",
                 str(temporary_mp3)])
            info = probe(temporary_mp3)
            audio = next(stream for stream in info["streams"] if stream["codec_type"] == "audio")
            final_levels = loudness(temporary_mp3)
            assert audio["codec_name"] == "mp3" and audio["channels"] == 1
            assert int(audio["sample_rate"]) == 44100 and int(audio["bit_rate"]) == 128000
            assert float(final_levels["input_tp"]) < -0.5, "Encoded audio peak needs review"
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(temporary_mp3, output)
            report = {
                "model": profile["model"], "voice": profile["voice"], "title_spoken": False,
                "duration_seconds": float(info["format"]["duration"]), "size_bytes": output.stat().st_size,
                "sample_rate_hz": 44100, "channels": 1, "bitrate_kbps": 128,
                "spoken_body_sha256": recording["spoken_body_sha256"], "input_word_count": len(body.split()),
                "requests": 1, "segments": 1, "tempo_factor": tempo, "static_gain_db": gain,
                "integrated_lufs": float(final_levels["input_i"]), "true_peak_dbtp": float(final_levels["input_tp"]),
                "quality_status": "Encoding verified; full listening and transcript/pronunciation review still required",
                "pronunciation_notes": profile["pronunciation_review"],
                "cost": "Actual billed cost is not returned by the speech endpoint; check project usage.",
            }
            output.with_suffix(".production.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
            print(json.dumps(report, ensure_ascii=False, indent=2))
    except OpenAIError as error:
        # Never print exception text: authentication errors can echo fragments of a key.
        status = getattr(error, "status_code", None)
        code = str(getattr(error, "code", None) or "connection_or_service_error")
        code = re.sub(r"[^a-zA-Z0-9_.-]", "", code)[:80]
        raise SystemExit(f"OpenAI failure while {stage}: HTTP {status or 'unavailable'}, code {code}. No automatic retry.") from None


if __name__ == "__main__":
    main()
