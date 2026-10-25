Audit stabilization review — build 45

Baseline: main and xcode-download at 6d6f427 (build 44). This review branch preserves
explicit Continue, independent walk/story/bonus/audio state, both map providers,
and existing AR entry/exit behavior. No branches have been merged or deleted.

Changes:
- Failed directions retry after 30 seconds, at most five times per destination.
  Fresh, sufficiently accurate GPS is required; a delayed fix can resume recovery.
  Retry directions explicitly renews the budget. Destination changes cancel recovery.
- ARCore update errors invalidate quality, pose, altitude and heading, allowing the
  existing localization timeout/fallback to respond instead of retaining good quality.
- GPS warnings use the same 25 m accuracy ceiling as visit eligibility; visible Map
  status rechecks age every five seconds, including when no GPS events arrive.
- A new walk clears the old route-summary cache; saved stories and bookmarks survive.
- CI now executes host-app tests on an available iPhone simulator, builds Release,
  and preserves xcresult/logs/resolved dependency information. This review branch
  triggers CI independently of main.
- Added the app-owned UserDefaults required-reason privacy declaration (CA92.1),
  including a resource entry in the shipped Xcode project.

Verification and remaining gates:
- Existing TourCore suite: 198 passed during the baseline audit; core unchanged.
- Updated portable application model suite: 55 passed (four new regressions).
  Debug/Release parsing passed; privacy plist parses; git diff whitespace checks pass.
- Native tests, SDK type-checking, generated-project comparison, privacy archive
  validation and physical-device reproduction remain pending on macOS/iPhone.
- No resolved dependency lockfile was fabricated: Apple SDK package resolution is
  unavailable on Linux. CI captures its real resolution for review and later pinning.
- The reported Stop 1 failure after Continue has not been reproduced on hardware.
  Existing all-stop explicit-Continue and independent-state regression tests remain.
- Do not merge or call this a release until native CI and device acceptance pass.

Steps 4–6 — review build 46:
- Field acceptance guide corrected for current product behavior, all five approximate
  locations, providers, permissions, AR tracking and calibration. Physical execution
  is NOT RUN: on-site iPhone access is unavailable in this environment.
- Extracted/tested a monotonic phone-down policy and selectively ported parser tests
  from old branch work without merging any branch or restoring automatic advancement.
- Added catalog/version/session identities, catalog validation, per-tour persistence,
  legacy-key compatibility and revision-specific walk resume. No saved visits or
  narration bookmarks are deleted; reset changes only the active walk session.
- Recording metadata now lives in the selected catalog. Both existing audio/transcript
  hashes were checked successfully against bundled bytes. Missing recordings no longer
  prevent navigation; pending audio never silently falls back to synthesized speech.
- Native media tests updated to cover degraded availability. Native CI/device checks,
  generated-project comparison and the Apple-resolved lockfile remain pending.
- Final build 46 verification: 206 TourCore tests and 57 portable application-model
  tests passed; Debug/Release app/test syntax checks passed. Two narration files and
  their transcripts match the catalog SHA-256 manifest. These are not device results.

Publication:
The product owner explicitly approved publishing all changes to main and xcode-download.
This approval supersedes the earlier review-only publication gate; it does not establish
native CI success, on-site acceptance, App Store readiness, or permission to retire branches.
Build 46 retains the verification limitations documented above.

UX implementation — review build 47:
- Owner approved UX audit items 1–7, 9 and 10, including replacing manual-only
  progression with a fresh-fix/dwell departure policy and durable Stay here/Undo.
- Existing recording, GPS/bonus/learning independence, maps and AR architecture retained.
- 214 core and 66 portable actual-model tests pass. New host-app audio regression
  awaits Apple execution. Debug/Release parsing passes; no native build is claimed.
- See UX-IMPLEMENTATION.md and revised AR-FIELD-TEST.md for scope and acceptance.
- This task does not publish, merge or retire any branch.

AR refinement — review build 48:
- Entire arrow pose is pinned, including facing angle, direction and street label.
  Removed per-frame billboarding/animation and polyline-segment force placement.
- About 5 m AR translation or a 1.5 s settled instruction changes the sign. Transient
  hide/recovery preserves the pin; session/destination/provider resets discard it.
- Larger 3D green bodies/white faces, 32 cm local extrusion, route-derived label and
  orientation-specific ground clearance. Both native map providers retained.
- 219 core and 66 portable actual-model tests pass; Debug/Release parsing passes.
  Native RealityKit build/rendering and real street stability remain unverified.
- See AR-ARROWS.md and the build-48 field checklist. No publication in this task.

AR clarification — review build 49:
- Confirmed hunter-green/white styling and about 5 m repositioning.
- Removed the world-space street-label mesh/plate. Street names remain only in the
  unchanged bottom direction card; route street identity still protects turn stability.
- Shared logic is unchanged from the passing 219-core/66-model suite. Debug/Release
  syntax checks repeated after renderer removal. Native iPhone acceptance is pending.

Map artwork color — review build 50:
- No intentional gray filter was found in the marker code; bundled art is full color.
- Explicit original-color rendering for landmark assets and cached marker snapshots.
  The shared Google/Apple image view opts out of inherited UIKit tint dimming.
- Snapshot rendering stays enabled, non-linear and transparent. No asset color edits,
  saturation filters, marker sizing, navigation or visibility changes were introduced.
- Debug/Release syntax checks repeated. Actual SDK snapshot/color reproduction and
  return-from-menu behavior require iPhone verification; no native visual result claimed.

Stop detail alignment — review build 51:
- Moved date, address and Show on map directly beneath the shared stop title before
  Listen/Read. The long description stays in the body below the story controls.
- Debug/Release Swift parsing repeated; no logic/storage changes or new tests.
  Native layout verification remains pending.

Home map preview — review build 52:
- A marker tap now selects a preview only; an explicit View stop action opens the
  matching stop page. X dismisses the preview without returning Home or changing audio.
- Shared SwiftUI popup on both providers, with short-map zoom-control clearance,
  scrolling metadata and whole-card accessibility overflow fallback.
- Home suppresses only Google's SDK popup so it cannot duplicate the shared preview.
  Other Map popup behavior is unchanged. Show on map/Back restoration is retained.
- Debug/Release syntax checks passed. Manually verify all five markers on both
  providers, switching selected markers, X, View stop, zoom and return from details,
  including small phones, Dynamic Type and VoiceOver; native runtime is unavailable here.

Previous-stop navigation — review build 53:
- Map adds Previous stop for an in-progress destination after the first. It uses
  itinerary order, preserves accomplishments/distance and reuses destination routing.
- Clears stale automatic Undo/AR subject, latches the existing durable departure hold,
  and leaves paused walks paused. Continue releases the hold; first-stop return does
  not imply a new walk. Distance/time remain visible while returning to visited sites.
- View/Undo and Previous/Continue use separate rows, with accessibility wrapping.
- 72 portable actual-model tests passed, including 6 new previous-stop regressions.
  Debug/Release syntax checks pass. Added a native audio-identity regression; it has
  not run here. Google/Apple UI layout, device routing and audio remain native checks.

Stops list simplification — review build 54:
- Shows Visited only for saved/current-walk visits and On-site bonus unlocked only
  when the saved bonus exists. Both can appear independently, matching the ledger.
- Removes unvisited, current/next, reading/listening and media-availability copy from
  this screen and its VoiceOver descriptions. Stops without earned status have none.
- View-only change: no progress or saved activity is cleared; detail pages retain
  their controls/content. Debug/Release parsing passed; native visual check pending.

Developer GPS field tools — review build 55:
- Removed simulation/movement UI and developer-controller entry points, mill viewing
  point editor/arrival override, and both alignment editors. Existing bonus settings
  still load read-only; reusable simulated sources remain for automated test coverage.
- Manual labeled GPS readings persist per stop/tour with accuracy, actual fix time,
  saved time and permission metadata. Copy and native CSV sharing are explicit.
- Invalid/stale/simulated/repeated fixes are rejected. Weak but valid readings can be
  stored with honest accuracy metadata. Corrupt/future archives are preserved, not overwritten.
- Legacy mill coordinates import once with unknown fix time; visit/story resets do
  not clear GPS readings. Deleted imports do not reappear. Saved readings never apply
  themselves to production stop coordinates, routing, arrival, visits or calibration.
- 227 TourCore + 82 portable actual-model tests passed; Debug/Release syntax parsing
  passed. The actual developer controller now runs in the portable model harness.
- Native CSV share sheet, clipboard, keyboard/form layout and on-device GPS capture
  remain pending. See GPS-CAPTURE-TEST.md. This task does not publish changes.

Build 55 publication and illustration export — 2026-10-25:
- Owner authorized publication of pending changes and the Figma-ready illustration
  package. The authoritative main and Xcode download snapshots advance together
  without merging or deleting branches. App version remains 0.2.0 (55); this
  publication adds documentation and exported artwork, not further app changes.
- docs/design/exports/Cranford-Tour-Illustrations-Figma.zip contains the three original
  transparent PNG assets, two SVG translations of the current Canvas artwork, PNG
  alternatives, provenance/import instructions and checksums. PNG originals were
  checked byte-for-byte; SVG exports were rendered and visually inspected.
- The existing 227-core/82-model passing results and Debug/Release syntax checks
  remain the latest verification. Publication does not establish native compiler,
  device, outdoor AR or GPS acceptance. These checks remain pending.

Player refinement — review build 56:
- Artwork grows from 64 points to 96–128, proportional to available screen height.
  Title moves from headline to the shared title2 semibold serif typography.
- White circular 64-point play/pause control with 36-point scaled symbol; the glyph
  caps at 48 points. Close retains a separate 44-point top-right target.
- Two-column layout removes the old 44-point blank strip. Accessibility sizes place
  the wrapping title above the controls. Seek target grows from 36 to 44 points.
- Layout minimum is 180–220 points, with content-driven growth rather than clipping
  for large text or failures. Existing actual-height footer reservation is retained.
- Debug and Release app/test syntax parsing and whitespace checks passed. This is
  a view-only refinement: no player service, routing or persistence logic changes.
  Native Apple compilation, rendered layout, VoiceOver and touch checks remain pending.
- No GitHub publication in this task.

Collapsible stop history — review build 57:
- Added a native Stop details DisclosureGroup immediately above longDescription.
  State starts expanded and resets when the displayed stop ID changes.
- Preserves the original history text; metadata, Listen/Read, narration, bonus and
  visit/progression state are independent of the disclosure. Empty histories omit it.
- Document icon, minimum 44-point label and native expand/collapse semantics; text
  wraps naturally. No custom animation or navigation action is introduced.
- Debug and Release parsing plus whitespace/source checks passed. No new tests for
  this local view-only change. Native build, small/large text, tap and VoiceOver
  acceptance remain pending: verify collapse/reopen, fresh-stop default and audio
  continuity on both mill and Greystone. No publication in this task.

Simplified plaque action — review build 58:
- Full-width forest/white camera button above Stop details, matching the supplied
  reference. Unfound action reads Find on-site plaque with AR; unlocked state keeps
  View the bonus, the earned Bonus found label and the original bonus-opening action.
- Removed the optional/on-site subtitle and divider. Native scaling/wrapping,
  16-point horizontal inset, 14-point vertical inset, 56-point minimum height.
- Source/whitespace and Debug/Release syntax checks passed; no service, scanner,
  saved activity or eligibility logic changed. Native layout/VoiceOver/touch checks
  remain pending. No publication in this task.

Active walking map — review build 59:
- Owner chose user + departure stop + destination framing. Added navigation camera
  mode and self-contained walking-leg camera bounds for both Google and Apple maps.
- Camera follows meaningful GPS displacement (15 m) and late route changes; normal
  small movements update the dot without refitting. Manual gestures pause framing.
- Destination changes retain the outgoing destination, including Previous backtracking.
  Mid-walk first appearance uses the preceding itinerary stop; new sessions discard
  old departure context. Before GPS, destination framing still works.
- Route geometry is valid, destination-matched and excludes straight-line estimates.
  Dot remains actual GPS, with uncertainty, never path-snapped or automatically marched.
  Added short interpolation on Apple like the existing Google position update.
- Apple camera padding reduced for short maps; minimum extent is 250 m. Google
  walking bounds have a small minimum geographic extent to avoid extreme close zoom.
- 87 actual-model tests pass, including 5 new map regressions. Debug/Release app/test
  syntax parsing and source/whitespace checks pass. Core logic is unchanged; its prior
  227-test result was not rerun. Native Apple build, both SDK layouts/rendering and
  field GPS movement remain pending. See MAP-TRACKING.md. No publication in this task.

Illustration-led Home — review build 60:
- Owner selected the ivory field-guide image and requested Maps above Explore the
  stops. Home no longer instantiates HomeMapView. Existing map/fallback code remains.
- Confirmed destination-matched hero and Tour complete / Start another walk state.
  Native original artwork, serif two-line title, walking CTA and icon browse rows.
- Home-only labels Start walk / Continue walk / Start another walk; Map's destination
  wording is retained. Restart uses existing reset/start with saved learning preserved.
- HomeLandingLayout measures heading/actions before allocating 96–340 points to art.
  Artwork keeps its native raster or Canvas aspect ratio. Real footer reservation,
  Dynamic Type, scrolling and error/retry/loading states are retained.
- Developer Controls move to the existing long-press title entry, without the
  previous visible developer row. No player, GPS, visit or progression logic changed.
- 90 actual-model tests pass, including 3 Home regressions. Debug/Release syntax and
  whitespace checks pass. Native rendering/SDK type-check/VoiceOver/touch remain
  pending. Product Design visual comparison is blocked, not passed. No publication.
