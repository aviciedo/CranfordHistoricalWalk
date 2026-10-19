# Walking screen reference review

final result: blocked

Source visual truth: [docs/design/walk-reference.jpg](docs/design/walk-reference.jpg), the exact
592 × 1280 JPEG reattached by the user for this update. It shows the active Map tab, stop 1 of 5,
a warm-white full-width navigation bar, next-stop panel and a playing narration strip.
The image has no device bezel or status-bar content to reproduce.

Implementation screenshot: unavailable. This environment is Linux; it cannot build with Xcode,
render SwiftUI, launch an iPhone simulator or capture the actual native app. There is no
browser-based replacement of the app. No pixel-for-pixel fidelity, iOS build, gesture test or
visual QA pass is claimed. Source capture is available; implementation capture/comparison is blocked.

Target viewport: an iPhone in portrait, including a 393 × 852-point layout and smaller phones.
Reference pixels: 592 × 1280; implementation pixels/points: not captured. Source-to-point scale
is approximately 1.506, not a known device screenshot density. No density-normalized rendered
comparison has been performed. System safe areas and home indicator remain system-owned.

## Implemented reference specifications

- A full-width SwiftUI bottom bar visually replaces the OS tab bar. Home, Map and Stops have
  equally spaced native SF Symbols, labels underneath, forest selection and neutral inactive
  labels. The Map icon fills when selected. There is no floating capsule, material blur or
  selected-tab pill. A single root safe-area inset contains the shared player and bottom bar.
- The navigation surface remains warm white in dark appearance, with fixed readable foregrounds.
  Reference surface sampled at RGB 247/244/239, primary button at 48/70/57, player at 236/229/219.
  Inactive text is slightly darker than the reference to reach 4.53:1 contrast against that
  navigation surface; selected labels have 9.29:1 contrast. These are token calculations, not
  screenshots or a complete accessibility audit.
- Larger 132 × 106-point tappable stop photo, serif title, uppercase NEXT STOP label, coral
  walking icon, distance/time divider, 54-point minimum-height AR button and Stop details row.
  Accessibility text sizes stack the stop information and permit the walking screen to scroll.
- Two separate white circular map buttons at the lower right, with 46-point hit areas and
  bottom spacing intended to clear the provider attribution. Real map content and gestures remain.
- Compact shared audio transport with a 46-point terracotta button and thin progress rail.
  Tap the title/rail to open full controls; recorded audio seeking remains in stop details.
- External Google walking directions and the current written turn instruction are available
  in Stop details. Route failure/estimate and location-permission states remain visible.

## Required fidelity surfaces

Fonts/typography: native serif display titles, native sans-serif labels and SF Symbols were
selected from the reference. Actual line wrapping, optical sizes and truncation require capture.

Spacing/layout: source proportions informed panel insets, photo size, button height, player
density and tab spacing. Actual safe-area layout and small-phone fit are unverified.

Colors/tokens: reference colors sampled above; native light/dark rendering still needs comparison.
The navigation deliberately stays light, matching the user's explicit priority.

Image quality/assets: the existing real mill photograph, landmark illustration and all Greystone
gallery images are reused. No mockup is rendered as the application. Live Google cartography
and route geometry cannot be identical to the illustrated OpenStreetMap reference; attribution
continues to identify the actual provider. The existing Google route line is retained.

Copy/content: Your walk, Home, Map, Stops, NEXT STOP, View in AR and Stop details match the
reference roles. Stop count, distance, ETA, visited state and playback times are live values;
the reference's 0.2 mi, 5 min and 02:40 are not hard-coded.

## Comparison history

No rendered implementation comparison has been possible. Code/specification changes above are
not substitutes for a visual comparison. No visual P0/P1/P2 findings are marked resolved and no
post-fix screenshot evidence is available. Full-view and focused comparisons remain pending.

## Mac/iPhone verification checklist

1. Build the included project with the Mac's existing private settings and Apple signing team.
2. Start a walk, select Map, play narration and capture the actual screen. Compare the full
   viewport and focused crops of the navigation, destination panel and player with the reference.
3. Confirm only one bottom bar/player appears; no system floating tab bar or empty tab-bar gap.
   Check Home, Map and Stops before, during and after playback, and after closing AR/details.
4. Verify each tab preserves the tour destination, map focus, playback and current stop progress.
5. Inspect standard and larger text sizes, a smaller iPhone, portrait safe areas, and dark mode.
   Confirm the light navigation has readable labels and controls stay visible and tappable.
6. Pan and pinch the live map; test follow/route-fit buttons and confirm provider attribution
   stays visible. Check location denial, missing-key and routing-failure states.
7. Enlarge a stop photo, close it, open Stop details, seek recorded audio, open Google walking
   directions, enter AR, activate a marker and Continue to the next stop.
8. Test VoiceOver: selected navigation buttons, current playback value, photo expansion and AR
   controls. Run Product > Test for the native regression suite.

The remaining blocker is native rendering, interaction and build evidence from macOS/iPhone.

## AR walking-arrow reference update

The additional supplied references show a translucent ground arrow and a large upright arrow
with a street label near an intersection (Davis Street is an example, not Cranford route data).
Implementation is native SwiftUI/RealityKit, not a web recreation. Native capture and visual
comparison remain blocked in this Linux environment; the overall result above remains blocked.

Implemented source specifications: one 1.8 × 1.35-meter ivory arrow at 58% material opacity,
fine translucent forest edging, detected horizontal ground height with a stable estimated
fallback, a large entry/look-around cue, and a reused upright turn sign near a route maneuver.
The turn sign uses a transparent texture containing an SF Symbol, route-supplied street name
and feet distance. The camera footer replaces the prior large ivory direction card. Heading
filtering, eased transforms and visibility hysteresis aim to avoid snapping and flicker;
Reduce Motion disables movement/scale animation.

Additional physical-device checks:

1. Enter AR while facing left, right and away from the first route segment. Confirm the large
   arrow points toward the walk, uses the actual street and feet distance, then fades after
   looking along the route. Look away and confirm it reappears without oscillating.
2. Walk toward a left and right intersection. Confirm the upright arrow names the street
   being entered, counts down the walking distance, says "now" at the corner, and disappears
   after turning. Verify it does not simply repeat the current step's earlier maneuver.
3. Check the ground arrow against gravel, bright pavement, shade and uneven ground. Check its
   legibility through the translucent fill, ground-height refinement, and smooth rotation.
   Actual outdoor plane detection and GPS/compass alignment are unverified here.
4. Test small phones, larger text and Reduce Motion; ensure the entry cue clears the Map
   button, destination, tracking warnings and marker action. Check VoiceOver announcements.
5. Lose GPS/heading, interrupt AR and disable routing. Confirm arrows hide appropriately,
   no street turn is invented from an estimate, and Map remains usable. Activate the mill,
   Continue to Greystone and verify its new route/entry cue uses the same shared tour state.

No screenshot fidelity, outdoor ground-lock result, native build or on-device animation pass
is claimed by the source-level and portable logic checks.

## Mill story-first discovery and door-pane bonus

The latest supplied field screenshots show the old card above the plaque, premature activation,
auto-started narration and a large playback panel. The confirmed target for the new bonus is the
TWO glass panes in the red double doors immediately to the plaque's right. Discovery is optional;
only recognition earns plaque verification and access to the extra. The supplied site coordinate
came from a Google search; the public viewing point will be captured during future field testing.

Implemented source behavior: one arrival offer of the normal detail screen; manual Play or an
explicit read-complete action; optional Find the plaque in AR; a matching tracked plaque records
once and shows a 1.6-second translucent confirmation; a translucent, tappable placeholder over
calibrated pane bounds; compact camera actions without the mill's old playback panel. Continue
works after the story without recording a plaque verification. Non-plaque stops keep their marker
flow. The placeholder is a test for future media, not fabricated historical content.

The window pose is derived from the plaque and held in AR world space when the plaque leaves the
camera. It is not independent window recognition. The initial relative bounds and 18 cm plaque
width are unmeasured. Developer controls capture a fresh real viewing-point fix with accuracy,
and adjust pane right/up/width/height while the plaque remains visible. Settings persist locally.
The extra is accessible only during the AR session, within 12 meters of the established window
pose and with normal tracking. Re-entering AR requires re-establishing that pose from the plaque.

Portable validation: 147 core tests and 20 isolated app-logic tests passed. The latter run actual
tour/proximity/developer/visit-store/routing source with an offline directions fixture and
Foundation location values. Native map-model tests and the AR/no-auto-play case require iOS.
Debug/Release syntax and saved Xcode source references pass. Native compilation, modal sequencing,
narration completion callbacks, recognition, facade fit, animation and outdoor tracking remain
unverified. Follow AR-FIELD-TEST.md for the specific phone checks. No rendered result is marked
passed; `final result: blocked` remains the visual-QA status at the top of this document.

## AR walking completion review

Corrected the route-bearing calculation near polyline vertices so a small GPS overshoot does
not reverse the ground arrow. Walking arrows are withheld beyond 35 meters off route instead
of directing the visitor along a stale route. The footer asks the visitor to use Map while
routing updates. Turn-sign reappearance resets opacity and cancels pending hide tasks, including
when Reduce Motion changes during a fade. The mill story/plaque flow remains intact.

Verification: 151 core XCTest tests (including four new route-bearing regressions), 20
production tour-logic integration tests with offline directions, Debug/Release syntax,
project source registration and asset manifests passed. Native compilation, visual comparison,
Google services and outdoor AR remain unverified here; the overall visual QA result is blocked.

## Greystone map illustration

Generated a transparent Greystone landmark from the supplied front-elevation photograph in the
same detailed architectural-cutout style as the mill. It appears beside stop 2 in both the
Google map and Home illustrated overview; numeric stop pins retain their existing interactions.
Both live-map decorations follow the real stop coordinates, hide below zoom 14.5 and are removed
when their stop is absent. Artwork preserves its aspect ratio inside the live-map icon bounds.
The asset is decorative; it is not a new navigation coordinate or AR recognition reference.
PNG alpha and manifests, source references and Swift syntax checked. Native map screenshots
and visual overlap checks still require Xcode/iPhone testing.

## Stops list transparent illustrations

The supplied Stops screenshot requests illustrations left of each stop name. Every row now
has a transparent 82 × 76-point decorative illustration inside the same details button. Stops
1 and 2 reuse their detailed landmark PNGs; river, church and hotel use symbolic native Canvas
drawings, not claimed reconstructions of unprovided building photographs. Existing name,
visit status, narration access and chevron remain. No opaque thumbnail background is added;
the detailed photographs remain in the stop detail slideshow with enlargement controls.
Decorations are hidden from VoiceOver so each row remains one details action. The row can grow
vertically for wrapped text. Project/source and syntax checks passed; native screenshots,
small-screen and larger-text layout checks still require Xcode/iPhone testing.

## Greystone on-site plaque discovery

The supplied black Cranford Park plaque is registered as a distinct ARKit reference at stop 2.
Its original photo, including stone surround, is preserved byte for byte; the full-frame 0.75 m
width is explicitly an unmeasured estimate. Discovery copy identifies this plaque, and a bonus
placeholder is placed above it after a current matching image and normal AR tracking. Reading
or listening permits optional continuation; GPS alone does not unlock. Mill-only viewing-point
and window calibration are isolated. The same one-time confirmation and local visit recording
apply, with no remote unlock from stored history.

Core and production tour-logic checks cover reference mismatch, bonus placement, GPS rejection,
optional continuation, calibration isolation, duplicate activation and advancing to stop 3.
Native reference-image validation, recognition quality, estimated scale and physical overlay
placement remain blocked here pending Xcode/iPhone field testing. Overall visual QA remains blocked.

## Greystone pillar context photo

The supplied wider photo shows the plaque/pillar proportions. Default bonus bounds now fit above
the sign within the pillar's apparent width, keeping close to the texture's natural aspect ratio.
The image is retained unchanged as a field reference; it is not an added AR target containing
non-planar scenery. Physical reference scale remains an estimate. New Debug Greystone sliders
persist independently of mill calibration, support fine increments, and can update placement
without requiring a new image-anchor pose. Each stop's reset is isolated; visit resets preserve
both. Tests exercise the fit constraints and storage/reset independence. Native UI, real image
recognition, and actual pillar fit remain unverified without the Mac/iPhone; visual QA is blocked.

## Produced mill narration and reusable audio reference

Stop 1 now selects a real bundled MP3; its controls disclose the AI voice. Cedar/gpt-4o-mini-tts
reference and full narration share frozen instructions, with the title excluded from spoken input.
The exact approved master is retained. Encoding/levels, ASR coverage and automated listening were
checked. The initial take was superseded to correct inconsistent family-name pronunciation.
Local business/family pronunciation and human acceptance remain unverified. Native AVPlayer
playback, seeking, audio-session interruptions and completion-to-discovery transitions still need
Xcode/iPhone testing. The source and portable checks do not constitute a native build pass.
