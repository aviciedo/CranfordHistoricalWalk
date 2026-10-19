#!/usr/bin/env python3
"""Generate the narrator reference or approved stop-1 recording using environment credentials.

Requires requirements.txt, ffmpeg and ffprobe. --check never contacts OpenAI.
App bundling is a separate step after audio quality review.
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


def loudness(path, target=-19):
    result = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af",
                             f"loudnorm=I={target}:TP=-2:LRA=11:print_format=json",
                             "-f", "null", "-"], check=True, capture_output=True, text=True)
    return json.loads(re.findall(r'\{\s*"input_i".*?\}', result.stderr, re.S)[-1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate local inputs without API requests")
    parser.add_argument("--force", action="store_true", help="Explicitly authorize replacing an existing recording")
    parser.add_argument("--recording", choices=["reference", "stop01"], default="stop01")
    args = parser.parse_args()
    profile = json.loads((ROOT / "narrator_profile.json").read_text())
    recording = profile["reference_recording"] if args.recording == "reference" else profile["approved_recording"]
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
    fingerprint = hashlib.sha256(json.dumps([profile["model"], profile["voice"], profile["instructions"], body],
                                           ensure_ascii=False).encode()).hexdigest()
    cache = ROOT / ".work" / args.recording
    cache.mkdir(parents=True, exist_ok=True)
    raw = cache / f"{fingerprint}.wav"
    generated_this_run = False
    previous_report = output.with_suffix(".production.json")
    request_id = json.loads(previous_report.read_text()).get("request_id") if previous_report.exists() else None
    stage = "generating speech"
    try:
        # A key restricted to Audio/Speech need not have Models/Read permission.
        # Submit only the authorized speech request; authentication, model-access and
        # billing failures from that endpoint are never retried automatically.
        with tempfile.TemporaryDirectory(prefix="cranford-narration-") as tmp:
            mono = Path(tmp) / "mono.wav"
            stage = "generating speech"
            if not raw.exists():
                with client.audio.speech.with_streaming_response.create(
                    model=profile["model"], voice=profile["voice"], input=body,
                    instructions=profile["instructions"], response_format="wav", speed=1.0,
                ) as response:
                    partial = raw.with_suffix(".partial")
                    response.stream_to_file(partial)
                    request_id = response.headers.get("x-request-id")
                    partial.replace(raw)
                    generated_this_run = True
            stage = "processing audio"
            run(["ffmpeg", "-v", "error", "-y", "-i", str(raw), "-ac", "1", "-ar", "44100", str(mono)])
            seconds = float(probe(mono)["format"]["duration"])
            wpm = len(body.split()) * 60 / seconds
            tempo = 1.0 if 135 <= wpm <= 145 else 140 / wpm
            if not 0.8 <= tempo <= 1.2:
                raise SystemExit("Delivery pace needs manual review; no aggressive time stretching was applied.")
            paced = Path(tmp) / "paced.wav"
            run(["ffmpeg", "-v", "error", "-y", "-i", str(mono), "-af", f"atempo={tempo:.8f}", str(paced)])
            target_lufs = profile["audio"]["loudness_target_lufs"]
            levels = loudness(paced, target_lufs)
            integrated, peak = float(levels["input_i"]), float(levels["input_tp"])
            assert math.isfinite(integrated) and math.isfinite(peak), "Empty or invalid generated audio"
            needs_normalization = abs(integrated - target_lufs) > 1 or peak > -2
            audio_filter = "anull"
            if needs_normalization:
                audio_filter = (f"loudnorm=I={target_lufs}:TP=-2:LRA=11:"
                                f"measured_I={levels['input_i']}:measured_TP={levels['input_tp']}:"
                                f"measured_LRA={levels['input_lra']}:measured_thresh={levels['input_thresh']}:"
                                f"offset={levels['target_offset']}:linear=true")
            temporary_mp3 = Path(tmp) / "final.mp3"
            run(["ffmpeg", "-v", "error", "-y", "-i", str(paced), "-af", audio_filter,
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
                "speech_requests_this_run": int(generated_this_run), "segments": 1,
                "request_id": request_id, "generation_fingerprint": fingerprint,
                "tempo_factor": tempo, "normalization_applied": needs_normalization,
                "normalization_target_lufs": target_lufs,
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
