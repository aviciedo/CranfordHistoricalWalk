# Stop 01 audio production

Status: **not generated**. This environment's network policy blocked `api.openai.com` before
authentication or speech submission. No API charges were incurred. The iPhone app still uses
its existing narration; there is no placeholder MP3 and no OpenAI key in the app or repository.

The exact approved master text is `stops/stop_01_droeschers_mill.txt`. Its first paragraph is
the metadata title, which the generator excludes from spoken input. The remaining 353 words
are preserved, including their original spelling and punctuation.

`narrator_profile.json` records the requested `gpt-4o-mini-tts` / `cedar` profile, provisional
pronunciations and output settings. These are planned settings, not a claim of a completed
recording. Droescher, Severin and Alleum Yoga pronunciation still need local review.

## Resume securely

1. Review, save and publish the environment draft permitting `api.openai.com` and
   `developers.openai.com`. The existing package-manager network preset is preserved.
2. Bind the private key as **CRANFORD_NARRATION_API_KEY**, scoped to `api.openai.com`.
   `OPENAI_` names are reserved in this workspace. Never put the value in tracked files.
3. Install the pinned official SDK from `requirements.txt`; provide ffmpeg and ffprobe.
   A restricted key needs Audio/Speech write access; Models read access is not required.
4. Run `python3 assets/audio/generate_narration.py --check` for local-only validation, then
   run the same command without `--check` to authorize the speech request.
5. The generator uses one request, a lossless temporary WAV, mono 44.1 kHz conversion,
   modest pitch-preserving pace correction when needed, static loudness gain when needed,
   and a final 128 kbps MP3. It never automatically retries a speech or billing error.

The output is `stops/stop_01_droeschers_mill.mp3`, accompanied by an actual production report
with duration, file size and measured encoding/loudness. An existing recording is protected
against accidental regeneration; `--force` explicitly authorizes a new billable generation.

After generation, listen through the entire recording and verify every paragraph against the
approved text. Encoding checks alone do not establish natural delivery, correct pronunciation
or complete speech. Do not claim acceptance until that review is completed. If acceptable,
add the MP3 as a bundled Xcode resource, update only stop 1's audio source, and verify the
recorded-player completion event still enables optional plaque discovery. Leave all other
stops and the approved historical text unchanged. The key is needed only for production,
never for playback on an iPhone.
