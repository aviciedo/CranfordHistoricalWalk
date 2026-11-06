# Compact narration player

Visual target: [owner-selected attachment](narration-player-approved.jpg).
This latest attachment takes precedence over the earlier circular-art mockup:
it uses a rounded-square hunter-green illustration, play at right, quiet 15-second
controls and elapsed/total recording time. No rendered controls are baked into images.

`SharedNarrationBar` retains the existing persistent-footer placement, recording
identity and saved-position behavior on Home, Map and stop details. It uses the
existing green list art on an ivory tile, a 64-point play/pause control, a larger
23-point close glyph, 24-point panel corners and a more compact natural height.
Skip controls have 20-point symbols with 44-point hit areas. Closing still pauses
and saves position; skipping and scrubbing call the existing engine and preserve
the playing story independently of the walking destination.

Titles wrap instead of scrolling. Accessibility text sizes place the title above
the art/play row, and time labels can stack with a scaled timeline height.
Loading/error states remain supported. Unknown duration shows `--:--` rather than
an invented total; unseekable speech/loading disables both skip controls.

## Verification

Release/developer source syntax and whitespace checks passed. The actual time
formatter and its regression method ran in an offline Swift harness, covering
unknown/nonfinite durations, negative time, subsecond truncation and hour boundaries.
The native recording regression checks both 15-second directions, beginning/end
clamping and paused-story identity. It has not been executed on this Linux host.

Native visual comparison: **blocked** (Xcode/iOS runtime unavailable).
The attached image is the target, not a screenshot of this implementation.

Before release, check all stop titles at 320/390-point widths and accessibility
text sizes; compare the selected attachment; play/pause, scrub and skip at both
ends of a recording; close/reopen and confirm resume position; switch story while
walking to another stop; verify loading/error/speech states and VoiceOver targets.
Confirm play and close hit areas remain separate and the player leaves room for
the map and bottom menu. Not published.
