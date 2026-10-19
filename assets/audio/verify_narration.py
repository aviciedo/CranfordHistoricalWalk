#!/usr/bin/env python3
"""Transcribe generated audio to flag missing/repeated words. This verification API call is billable.

ASR checks text completeness; it does not certify accent, emotion or exact pronunciation.
"""
import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import unicodedata


def tokens(text):
    return re.findall(r"[a-z0-9]+", unicodedata.normalize("NFKC", text).lower())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--recording", choices=["reference", "stop01", "stop02"], default="stop01")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    profile = json.loads((root / "narrator_profile.json").read_text())
    recording = profile[{"reference": "reference_recording", "stop01": "approved_recording",
                         "stop02": "stop_02_recording"}[args.recording]]
    path = root / recording["target_output"]
    expected = (root / recording["transcript"]).read_text().rstrip("\n").split("\n\n", 1)[1]
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    report_path = path.with_suffix(".transcript-check.json")
    if report_path.exists() and json.loads(report_path.read_text())["audio_sha256"] == digest:
        print(report_path.read_text())
        return
    key = os.environ.get(profile["api_key_environment_variable"])
    if not key:
        raise SystemExit("Missing secure API key; no transcription request sent")
    from openai import OpenAI, OpenAIError
    client = OpenAI(api_key=key, base_url="https://api.openai.com/v1", timeout=180, max_retries=0)
    try:
        with path.open("rb") as file:
            result = client.audio.transcriptions.create(
                model="gpt-4o-transcribe", file=file, language="en", response_format="json",
                prompt="Proper names: Cranford, Rahway River, Droescher’s Mill, Severin Droescher, Alleum Yoga, Lincoln Park, Greystone, Charles E. Kaltenbach, Gloria Swanson, William Randolph Hearst, Cranford Hall, Cranford Park Care.",
            )
    except OpenAIError as error:
        raise SystemExit(f"Transcription unavailable: HTTP {getattr(error, 'status_code', 'unknown')}. No retry.") from None
    data = result.model_dump(exclude_none=True)
    actual = result.text
    expected_words, actual_words = tokens(expected), tokens(actual)
    matcher = difflib.SequenceMatcher(None, expected_words, actual_words, autojunk=False)
    differences = [{"kind": tag, "expected": " ".join(expected_words[a:b]), "transcribed": " ".join(actual_words[c:d])}
                   for tag, a, b, c, d in matcher.get_opcodes() if tag != "equal"]
    report = {
        "audio_sha256": digest, "model": "gpt-4o-transcribe", "speech_model": profile["model"],
        "voice": profile["voice"], "normalized_word_match": expected_words == actual_words,
        "word_match_ratio": matcher.ratio(), "differences": differences, "transcription": actual,
        "usage": data.get("usage"),
        "limitations": "ASR spelling/dates can differ from the actual speech. Listening review is still needed for delivery and local pronunciation.",
    }
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "transcription"}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
