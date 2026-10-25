# Shared player refinement — build 56

Applies to the same shared player on Home, Map, Stops and stop details. The existing
hunter-green surface, white foreground, original-color artwork, saved playback
position, loading/failure handling and independent story identity remain.

## Layout review

- Artwork: 14% of the host height, clamped to 96–128 points (formerly 64).
  Existing scaled-to-fit rendering preserves the illustration silhouette and alpha.
- Title: AppTheme.Fonts.title, title2 semibold serif (normally 22 points, formerly
  headline 17), matching the stop-name type family and weight. A scaled 34-point
  line box provides room for the title. Existing overflow marquee remains at
  standard sizes; Reduce Motion and accessibility sizes use static wrapping.
- Controls: 64-point white circular playback target (formerly 48), green symbol
  scaled from 36 points, optical play-triangle offset; loading uses the same target.
  Close remains 44 points at top right, with 44 points reserved beside the title.
- Spacing: 16-point horizontal/top insets, 16 between artwork and controls, 12
  between title and transport. Seek target 44 points with a centered 3-point rail.
- Footer: minimum 180–220 points according to host height; it can grow for content.
  The root and detail hosts already reserve the actual footer height. At accessibility
  sizes the title moves above the artwork/control row to avoid a narrow text column.

## Verification performed

- Debug + DEVELOPER_MENU and Release Swift syntax parsing of app/test sources passed.
- Source diff/whitespace reviewed; loading, failed, play/pause, close, seeking, long
  title, Reduce Motion and accessibility layout branches inspected in code.
- Playback actions continue through the existing prepare/toggle/dismiss/seek methods.
  No player service, route, stored progress, bookmarks or tour selection changed.
- Prior 309 logic tests belong to build 55 and were not rerun for this UI-only change.
- No Apple SDK, iOS simulator or device is available here. Syntax parsing does not
  establish native type-checking, rendering, interaction or accessibility success.

## Native acceptance still required

1. Build Debug/Release in Xcode. Show the player on Home, Map, Stops and details at
   320, 375, 393 and 430-point widths, plus supported landscape/iPad configurations.
2. Play both available stories; check title/artwork/control alignment, top-right
   Close clearance, seeking and no overlap with bottom navigation or story content.
3. Check the longest catalog title using a local preview fixture without adding
   unapproved audio; it must remain fully available through marquee/VoiceOver.
4. Check default, largest standard and accessibility text sizes, Reduce Motion,
   VoiceOver focus/adjustable seek, loading and multiline failure messages.
5. Pause/resume/seek, close/reopen and browse between destinations. Confirm saved
   position and story identity remain correct, with no navigation-driven autoplay.
6. Check the larger playback target is comfortable with one hand outdoors, then
   adjust only if observed device evidence shows a layout or interaction issue.
