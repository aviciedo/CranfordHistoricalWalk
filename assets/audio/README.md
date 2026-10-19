# Cranford narration production

Two real recordings are included, generated in this order with the same OpenAI model, cedar
voice and version-2 narrator instructions. The first take was superseded after automated
listening flagged inconsistent Droescher pronunciation. The final reference and stop were
both regenerated with stronger consistent short-EH pronunciation guidance.

| Deliverable | Location | Duration | Size |
| --- | --- | --- | --- |
| Standard narrator reference | `reference/narrator_reference.mp3` | 42.24 seconds | 676,401 bytes |
| Stop 01 final recording | `stops/stop_01_droeschers_mill.mp3` | 151.30 seconds | 2,421,378 bytes |
| Exact approved source | `stops/stop_01_droeschers_mill.txt` | 353 spoken words | UTF-8 |
| Frozen reusable voice configuration | `narrator_profile.json` | Profile version 2 | No credentials |
| Generation script | `generate_narration.py` | Official SDK | `requirements.txt` |
| Automated transcript check | `verify_narration.py` | Optional billable ASR | Saved JSON results |

Both MP3s are mono, 44.1 kHz, constant 128 kbps. Stop 1 is about 140 words per minute, at
approximately -19.5 LUFS with -2.4 dB true peak. No music, effects or intro logo were added.
Each recording was generated as a single continuous take, with gentle loudness normalization
and pitch-preserving pace adjustment when needed. A lossless source cache prevents paying
again merely to re-encode a take; `.work/` is deliberately excluded from Git and the app.

## What is verified

The exact approved master text is preserved, including its spelling and punctuation. Its first
paragraph is title metadata and is never sent as spoken narration. The app's readable transcript
matches the master. The reference contains exact excerpts from that approved narration.

FFmpeg/ffprobe checks verify decoding, bitrate, channels, sample rate, duration and peak level.
No silences of two seconds or longer were detected in stop 1. ASR checks found no missing or
repeated passages; their JSON reports retain numeric/spelling differences. A targeted listening check confirmed
the final consonant of “landscaped,” resolving the remaining ASR inflection discrepancy.
Automated audio listening found the revised narrator warm and conversational, with consistent
DRESH-er, stable volume, smooth transitions and no detected music, clipping or repetitions.
This is automated review, not human acceptance. Local preferred Droescher/Severin pronunciation
and especially the business's preferred Alleum Yoga pronunciation remain unconfirmed. Listen
before approving the voice as final for the whole tour; full acceptance is not certified yet.

## Standardize future recordings

Keep the model, voice, instructions, pronunciation notes and processing settings in
`narrator_profile.json` fixed. Compare new recordings with the saved reference. The API does
not take this sample as a voice-cloning input, so a saved profile alone cannot guarantee
identical timbre after service/model updates. Store per-stop source text and production reports;
change historical wording only with the tour creator's approval.

Install the official SDK from `requirements.txt`; ffmpeg and ffprobe must be available. Set the
private **CRANFORD_NARRATION_API_KEY** environment secret for `api.openai.com`. Generation needs
Audio/Speech write access; optional transcript and listening checks need their respective API
permissions. No Models read permission is required. Never put a key in the app or GitHub.

Generate a new baseline first with:

    python3 assets/audio/generate_narration.py --recording reference

Then generate stop 1 with:

    python3 assets/audio/generate_narration.py

`--check` validates local inputs without API requests. Existing outputs are protected; `--force`
replaces one only deliberately, reusing the matching cached lossless master when available.
Changing delivery/input invalidates the cache and makes generation billable. Speech and billing
errors are not retried automatically. `verify_narration.py` performs a separate billable ASR
check and reuses its result when the audio hash is unchanged. Exact API charges are not returned
by the speech endpoint; request IDs and verification usage are retained for project accounting.

## App integration

The stop-1 MP3 is included once as an Xcode app resource and registered in `project.yml`.
Stop 1 resolves its bundled recording before on-device speech, supports the existing shared
player/seek controls and displays an AI-narration disclosure. The reference sample is a production
asset, not an extra app resource. Other stops' audio is unchanged. The iPhone needs no OpenAI key
or OpenAI network connection to play this recording. Google Maps configuration remains separate.

154 core tests and 2 checks of actual production Swift preview data passed. Debug/Release Swift
syntax and resource registration passed. A native test now loads the bundled MP3 duration and
checks that preparing it does not auto-play, but this needs Xcode and has not run on Linux.
Actual iPhone playback, seeking, interruption handling and the narration-finish discovery prompt
still require the Mac/iPhone check. Existing AVPlayer completion handling remains unchanged.
