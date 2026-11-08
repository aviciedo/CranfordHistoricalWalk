# Stop details — selected design, build 137

The owner selected [option 1](stop-details-option-one.png), with the landmark name
above the gallery as in [option 3](stop-details-title-first.png). This implements
that combination in the existing native SwiftUI stop page, shared by every stop.

- One large system-serif stop name appears above the photo. Gallery captions that
  merely repeat the name are omitted. Descriptive captions and credits remain.
- The gallery uses a compact height, based on host width, bounded to 180–280pt.
  Landscape previews fill the rounded frame; portrait photos remain fully visible.
  Opening a photo still uses the uncropped original and existing zoom viewer.
- Date and address follow the gallery. Narration and plaque actions stay stacked,
  with their existing labels, playback/resume states, scanner and collected states.
- Stop details uses a semibold serif heading and down/right disclosure chevron,
  without the document icon. The history body remains sans-serif with 4pt extra
  line spacing. Read the story also uses a serif label; Home menu fonts stay as before.
- Major sections use 20pt gaps, title/gallery/metadata use 12pt gaps, and the
  detail/story/sketch rows retain the zero-gap grouping from the previous spacing fix.
- Existing safe-area controls, Dynamic Type, expandable history, tappable gallery,
  photo credits, narrative reader, audio player and plaque/sketch flows remain in place.
  All text is real native text and all existing production artwork/photos are reused.

Quick checks only: reviewed source/diff, checked updated style references, parsed
project configuration, matched build numbers and ran git diff --check. Apple builds,
SwiftLint, comprehensive suites and native screenshots were not run under the owner's
opt-in testing policy. No pixel-for-pixel or device visual verification is claimed.
Review on iPhone should include long stop names, larger text, portrait photos,
alternate captions/credits, expanded/collapsed details, audio and plaque/sketch states.

This is an implementation candidate, not a published release.
