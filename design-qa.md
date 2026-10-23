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


## Produced Greystone narration

Stop 2 now selects its bundled, manually started 2:23 cedar recording. Its transcript is the
exact supplied text, its measured duration replaces the estimate, and its controls disclose AI
narration. The profile instructions and existing stop-1/reference MP3s remain unchanged. Full
ASR and automated reference comparison passed; only healthcare/health care spelling differs.
Encoding, decoding, loudness, absence of long silence and source/resource registration were
checked. Core tests (154), actual Swift preview checks (2) and Debug/Release syntax checks passed.
Native AVPlayer resource/duration and manual-start tests cover both stops but remain unrun here;
Xcode and iPhone playback/seek/completion-to-optional-discovery checks are still required.


## Narration-source correction and restored detail AR entry

The AR action had been excluded for all plaque stops; it is now independent of plaque/current
status, with destination-specific text. Entry starts/resumes the walk, preserves ordering and
story-first bonus eligibility, and reuses an existing camera session from its details. Build
0.2.0 (2)/cedar-2 diagnostics identify the installed release and actual prepared audio source.
Produced MP3s and transcripts are validated against known hashes; source/voice changes invalidate
the player's same-ID cache. No audio was regenerated or visits reset.

154 core tests, six portable preview/release checks and Debug/Release syntax checks passed.
Portable release checks use system SHA-256 in place of unavailable Apple CryptoKit. New native
regressions for playback/source refresh and AR entry require Xcode and remain unrun. Native
SwiftUI sheet transitions, device playback and field AR behavior still require device QA.


## Larger numbers and full landmark tap targets

Build 0.2.0 (3) increases numbered circles from 24 to 40 points, selected circles to 44,
and interaction bounds to 56 points. Landmark icon views use their full bounds as targets,
with matching stop IDs and popup data. The fallback map matches artwork targets to painted
bounds and projects them with zoom/pan. Debug/Release syntax passed; native rendering and
physical touch-target behavior remain unverified without Xcode/iPhone.


## Home scrolling and shared player resizing

Build 0.2.0 (4) uses actual Home content offset to collapse the player after an upward scroll,
so panning inside the map alone does not trigger it. A capsule handle, tap/drag affordances,
compact play/pause, and an expandable title keep the player discoverable. Layout uses the
existing safe-area inset, preserving the bottom navigation and playback instance. Browse the
stops moved to the summary row above the walking CTA. Debug/Release syntax passed; native
scroll behavior, sheet interactions, dynamic type and device visual QA remain unverified.


## Stop-detail disclosure layout

Build 0.2.0 (5) removes both directions rows. Two actions sit directly below the address,
then an initially expanded Narration player disclosure. Stop description is initially collapsed,
matching Read narration. The redundant lower plaque button is replaced by an invitation to
use Start AR; the existing entry logic is preserved. Disclosure state is presentation-only
and never stops/re-prepares audio. Debug/Release Swift parsing passed. Native visual, large-text,
VoiceOver and playback-while-collapsing checks remain unrun here.


## Developer Refresh GPS now

Build 0.2.0 (6) adds a live-coordinates button with pending/success/timeout feedback, using
the same location manager and tour event stream. Cached timestamps cannot satisfy a refresh.
Duplicate requests and developer simulation are blocked. Core Location continuous updates
resume after the one-shot callback, including errors/invalid samples. Native regression added;
Debug/Release syntax passed. Actual one-shot acquisition and native test execution are unrun
here without Xcode/iPhone.


## White stop-detail close control

Build 0.2.0 (7) uses a fixed 46-point white circle, forest X and the same subtle shadow
as the map controls. A custom top safe-area row replaces the system toolbar presentation
so dark appearance and newer OS glass styling cannot change the button surface. Dismissal
and its accessibility label remain intact. Debug/Release syntax passed; native screenshots
and touch/layout verification require Xcode/iPhone.


## Home spacing review and refinement

Scope: the user-provided Home screenshot and current implementation. The screenshot shows
large header/developer gaps ahead of the map and actions low in the viewport. Its existing
serif heading, restrained palette and clear map/CTA hierarchy are retained. This is a supplied-
screenshot review, not a completed live Product Design audit: the Linux workspace cannot run
or capture the native iPhone screen. No new screenshot or native visual pass is claimed.

Build 0.2.0 (8) moves content upward with top padding 24→8, section gaps 24→12 and header gaps
8→4; the brand text uses smaller scalable system styles. The map grows from 290 to 310–350
points, with viewport-aware space reserved for the existing controls. This balances a larger
map against bringing actions higher. Colors, typefaces, artwork, horizontal margins, control
styles/order and navigation are unchanged. The latest inline Browse action stays above Start.

Debug/Release syntax passed. Approximate default-text height budgets were checked for usable
heights 568/620/680/740; the shortest needs scrolling, while the larger budgets fit. Dynamic
Type continues scaling and scrolling; actual text wrapping, map framing, VoiceOver order,
player-expanded/minimized layouts and device screenshots require Xcode/iPhone verification.


## Stops heading and row distribution

Build 0.2.0 (9) addresses the supplied screenshot's empty top region with a compact Home-style
app title and a hidden native navigation bar. The list begins immediately below the title.
Rows distribute the remaining viewport evenly, using a 100-point minimum and full-row hit
areas; illustration sizes, visit labels and disclosure actions are unchanged. Available row
height reacts to the shared player and actual brand-header size. Dynamic text may grow/scroll.
Debug/Release syntax passed. Native screen captures, large-text wrapping and device UI behavior
remain unverified without Xcode/iPhone.


## Home tour-focused initial map

Build 0.2.0 (10) excludes user GPS from Home's stop-overview bounds and removes initial fit
animation. This addresses zooming out for a distant visitor. Home keeps landmark images visible
at the overview zoom, with padding for the images and numbered markers. Defaults for the
guided map are unchanged. Debug/Release syntax passed. Actual Google Maps fitting, artwork
overlap and native map screenshots remain unverified without Xcode/iPhone.


## Rahway River photo-based menu illustration

Build 0.2.0 (11) replaces stop 3's generic river drawing with a detailed transparent waterfall
vignette generated from the supplied photo using existing mill/Greystone art as style references.
The generated PNG was visually inspected and has real alpha transparency. Asset catalog
registration and row source mapping were checked; existing row dimensions/actions are preserved.
Debug/Release syntax passed. Native asset compilation, small-icon legibility and device visual
QA remain unverified without Xcode/iPhone.


## Church on-site coordinate update

Build 0.2.0 (12) replaces stop 4’s geocode with the supplied field GPS reading 40.653165,
-74.302768 (reported ±6.3 m). Catalog, fixture and previews match; provenance retains the
previous value and snapshot limitations. Coordinates remain approximate. Actual outdoor
route/arrival alignment still requires field confirmation.

Validation for this update: 154 TourCore tests passed, Debug/Release Swift syntax passed,
and a data comparison confirmed all other stop records and church non-coordinate fields
are unchanged. Native field-route/arrival behavior is not exercised by these portable checks.


## Map AR button

Build 0.2.0 (13) adds the supplied camera/viewfinder affordance as a 46-point white circular
control at the top of the existing right-side map controls. It enters the single existing
ARTourView presentation through the shared tour start/resume path. Existing current/next-stop
routing and story/recognition rules are preserved. The AR control also appears on the fallback
map. Swift Debug/Release syntax and callback wiring passed; real device sizing, camera entry,
permission prompts and route guidance remain unverified without Xcode/iPhone.


## White/hunter-green AR chevron update

Build 0.2.0 (14) follows the supplied three-chevron reference using actual extruded geometry,
white inset faces and shaded hunter-green sides. Waypoint guidance is upright, placed along
the route and camera-facing; its chevrons rotate with smoothed relative bearing. The near-turn
entity uses the same geometry with maneuver direction and a retained street/distance label.
Initial orientation uses a matching silhouette and the directions panel uses hunter green.
Motion thresholds, short eased transitions and Reduce Motion handling remain; meshes are reused.

158 core tests and Debug/Release Swift syntax passed. New geometry tests cover winding,
concave outline coverage, watertight body edges, unit normals, depth and all direction mappings.
Native RealityKit compilation, actual green shading, photo-reference resemblance, outdoor
contrast, perceived scale and smoothness are unverified without Xcode/iPhone rendering.
No new native screenshot or device verification is claimed.


## Greystone plaque recovery — 0.2.0 (15)

The field screenshot showed the Cranford Park plaque while the HUD still named Droescher’s
Mill. The reference group already contained both plaques, but recognition first filtered
against the guided destination; a park match while the mill was current was discarded.
Start AR in a browsed stop’s detail also resumed that old destination. Separately, automatic
GPS completion could change destinations/reset discovery, and an existing GPS visit could
block later plaque verification.

Start AR in stop details now explicitly selects that site. The Map AR control still resumes
the guided destination; simply browsing remains passive. A currently tracked, uniquely
registered reference under normal tracking resolves its actual site before the destination
comparison. Selection preserves visit history and walked distance and never credits skipped
stops. It offers the correct story; reading/listening and explicitly starting discovery are
still required before the bonus unlocks. Unknown, ambiguous, untracked and limited-tracking
references are rejected. Greystone retains its own pillar bonus layout and mill-only panes
remain isolated.

GPS cannot advance a plaque stop during an active AR session or a pending explicit discovery
entry. Ordinary map-only GPS advancement remains. Finishing/continuing releases the hold;
exiting even an unsupported/permission-denied camera screen releases it too. A previous GPS
visit can be upgraded by a matching plaque. Discovery/story state is retained per stop during
the walk, cleared by Reset. Continue suppresses that old plaque for the remaining camera
session so a still-visible image cannot pull the destination back; an explicit site revisit
re-arms it. Starting discovery also checks the current frame, avoiding dependence on another
ARKit image-add callback when the plaque stayed tracked behind the story sheet.

Validation: 162 TourCore tests pass, including real-catalog park-to-Greystone resolution,
unknown/ambiguous/untracked/limited rejection and selection without lost or invented visits.
Debug/Release Swift syntax checks pass. Five host-app regression flows cover selected-site
entry, stale-destination recovery, GPS holds/advancement, prior-GPS plaque upgrades, Continue
suppression/revisit and camera-exit cleanup. Host-app tests and native ARKit recognition have
not run here: Linux has no Xcode/iOS SDK. Physical image width remains an unmeasured estimate;
this change does not claim calibrated AR placement.

Field check on build 0.2.0 (15):
1. Leave the walk at the mill. Open Stops > Greystone > Start AR. Confirm the HUD says Greystone.
2. Alternatively enter AR from Map while the mill is current, then frame the full Cranford Park
   plaque and stone surround. Confirm recognized-site recovery offers Greystone’s story.
3. Read or listen, choose Find the plaque in AR, and keep the plaque in view. Only Greystone’s
   pillar extra should unlock. GPS updates must not change the destination during this flow.
4. Repeat after Greystone was already marked visited by GPS. The plaque bonus must still work.
5. Continue to the river while still viewing the park plaque. The destination must stay at
   the river. Explicitly reopen Greystone’s Start AR to revisit; saved visits must remain.
6. Leave AR and confirm normal map walking/GPS advancement; test denied camera permission too.


## Build 17 — independent activities and exploration

Automated checks: 168 TourCore tests and 18 tests compiling the actual Foundation app
state, persistence and routing sources passed. Debug/Release app and test Swift syntax
checks passed. Native SwiftUI, AVFoundation and ARKit validation is pending on Mac/iPhone.

Device acceptance checks:
- Fresh install, deny location/camera: Home > Explore the stops opens photos and stories
  without starting the walk. Stops 1–2 can play their bundled recordings.
- Home shows a filled hunter-green Start a walk and a quieter Explore the stops below it.
- Start walking to Greystone while playing the mill. Browse another stop, change tabs,
  choose Read and return: the mill retains its position and Greystone stays the destination.
- The compact player appears above tabs after playback starts, expands, and is hidden
  when that same recording's full inline player is visible. Test scroll and larger text.
- Photos change only via swipe/arrows; wait at least 20 seconds to confirm no auto rotation.
- Listening/explicit reading completes learning only. GPS records a visit only and never
  advances automatically. Only tracked matching plaques unlock Bonus found.
- Inspect another plaque in AR: the camera subject changes but the walking target does not.
  Back returns to the presenting screen without stopping the recording.
- Stops 3–5 show Narration coming soon and pending Read text. No legacy recording or
  synthesized placeholder speech plays; neither pending activity can count as completed.
