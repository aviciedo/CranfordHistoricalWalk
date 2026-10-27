## Paused map copy — build 68

Removed Resume when you’re ready from the paused map. The paused panel omits the
status row entirely, so its reserved line height does not leave an empty gap.
Walk paused, destination, Resume walk and exploration actions remain available.

## Simplified Home actions — build 67

Removed the Home Maps shortcut and the numeric passport count. Explore the stops
and Your passport remain as matching full-width rows. During a walk the destination
now reads Next Stop: followed by the current destination's canonical name, in larger
semibold serif title3 type. The existing Begin at wording remains before a walk.
The walking action and destination use a 12-point gap, with 24 points before the
browse rows; the adaptive illustration receives the released space. Large text and
the shared player still use the existing measured layout and scrolling behavior.
Debug/Release syntax checks passed. Native visual verification remains pending.

## Matching story menu rows — build 66

Stop details and Read the story now share Home's full-width menu row component:
regular body text, title2 icons in a 28-point column, 14-point label gap, matching
chevrons, 8-point vertical padding and a 56-point minimum touch height. Their dividers
now sit directly against the rows, matching Home's Maps and Explore the stops.
The shared stop screen applies this consistently to available actions. Details stay
expanded by default and retain collapse/expand; reading still opens separately.
Debug/Release syntax checks passed. Native compilation and screenshot comparison
for this UI change remain pending; the earlier green CI run verifies build 65.

## Apple CI repair

The repeated emails came from native test failures, not failed compilation. A diagnostic
run verified both simulator Debug and iPhone Release builds. Three old tests expected
behavior that had intentionally changed: routing without Google keys now uses Apple's
walking network; loaded stops carry verified narration checksums; a previously saved
plaque bonus must not be awarded again. Tests now validate those behaviors. Routing
selection uses an injected offline Apple-provider fixture while production defaults
remain unchanged. CI runs once on main per publication, retains PR/manual checks,
checks audio changes, and publishes actionable failure summaries. Node action
versions are updated. [Final verification passed](https://github.com/aviciedo/CranfordHistoricalWalk/actions/runs/40261422454):
232 core tests, 145 native iOS tests, simulator Debug compilation and iPhone Release
compilation. See [CI-REPAIR.md](CI-REPAIR.md) for evidence and the specific corrections.

## On-site passport — build 65

Added the selected ivory passport with engraved hunter-green stamp artwork, native
page-curl browsing, and an earned Passport stamped row on tour-stop pages. A first
saved real AR plaque discovery closes AR and opens the corresponding passport leaf
with a stamp animation, then closes back to that stop. Existing bonuses become
collected stamps automatically; new walks retain the collection. Home includes a
secondary passport entry. No stamp is awarded for GPS arrival, story completion or
practice scans. 232 core + 98 actual-model tests and both Swift syntax configurations
passed. Subsequent GitHub CI passed both native builds and 145 host-app tests.
Visual comparison and iPhone AR/animation acceptance remain pending. See [PASSPORT.md](PASSPORT.md).

## AR arrow visibility repair — build 64

Fixed two verified code paths that could suppress every arrow: old visit/bonus
records hiding guidance on a return walk, and projected route previews being rejected
by the renderer's 3–14 m placement range. Out-of-range previews now use an approximate
nearby directional sign along the route bearing, retaining real ground detection and
the existing fixed-world/five-metre policy. This is not exact street registration.
The HUD now explains missing route/location, renderer failure, placement failure or
when the arrow is outside the camera view. Recorded visits/bonuses are preserved.
232 core + 94 actual-model tests and Debug/Release syntax checks passed. Native
RealityKit rendering and a repeat of the owner's failed outdoor test remain pending.
See [AR-VISIBILITY-FIX.md](AR-VISIBILITY-FIX.md).

## Photo-led stop details and reading — build 63

The slideshow stays first, with captions and uncropped original photographs. The
stop name/date/address follow; the Show on map link and Listen/Read tabs are removed.
A full-width hunter-green Play narration action uses Resume narration when a matching
saved bookmark exists; completed recordings clear that bookmark. Once opened, the
shared player remains the sole transport, with the existing inline instruction.
Plaque discovery is now an outlined secondary button; unlocked bonus access is kept.
Stop details remains expanded by default, with a smaller serif heading matching the
stop title and unchanged body text. Read the story at the bottom opens a separate
reading page with the approved transcript and explicit reading-complete action.
92 portable model regressions and Debug/Release syntax checks passed. Native visual,
audio and navigation checks remain pending; see [STOP-DETAIL-REDESIGN.md](STOP-DETAIL-REDESIGN.md).

## Refined Stops rows — build 62

Removed repeated visible Stop 1 / Stop 2 labels. Original illustrations grow from
82 × 76 to a 104 × 88-point area while preserving their native aspect ratios.
The artwork aligns toward the names with a 10-point gap instead of 14. Names share
a consistent leading edge, wrap naturally, and use the existing serif typography.
Earned status, full-row taps and spoken stop numbers are retained. Native visual
verification remains pending; Debug/Release Swift syntax checks passed.

## Simplified Map — build 61

Direction 1 is implemented with the requested green next-turn card directly beneath
the Map heading and above the map. The destination summary, View stop and AR directions
are below. Previous stop, Continue/Finish, route framing and location follow are in
More; Resume, arrival hold, immediate Undo and route recovery remain discoverable.
The map has one recenter control. Its full illustration emphasizes only the active
or selected stop; other stops retain numbered 44-point targets at their true locations.
Google cartography uses quieter ivory, sage and river-blue colors; Apple uses its
native muted map. Real geography, route geometry, GPS and attribution are preserved.
92 actual-model tests, Debug/Release syntax and map JSON checks passed. Native build,
visual comparison and touch/accessibility testing remain pending. See MAP-REDESIGN.md.

## Illustration-led Home — build 60

Home now follows the selected ivory field-guide reference: a two-line serif app name,
Discover the stories along the river, original transparent landmark artwork, and a
primary walking button. The Maps row with map icon sits above Explore the stops.
There is no embedded map on Home. Both browse rows switch tabs without starting or
resuming a walk. The existing Google/Apple walking map remains on the Map tab.

Before starting, Home features the first stop and Start walk. During a walk it shows
the active walking destination's illustration, Continue walk and Next: destination.
Browsing or playing another story never changes this image. When finished it shows
Tour complete and Start another walk; saved story/bonus accomplishments are retained.
The hero yields space to the measured heading and actions, including when the shared
player is visible; larger text and short screens can scroll without clipping controls.
Developer Controls remain available by long-pressing the app title in developer builds.
90 actual-model tests and Debug/Release syntax checks passed. Native visual QA is
blocked on Linux; see [HOME-LANDING.md](HOME-LANDING.md) and design-qa.md.

## Active walking map — build 59

Map automatically frames your GPS position, the departure stop and active destination,
along with the real walking route. A late route refresh now updates the camera. The
blue dot follows accepted GPS readings, including off-route movement, with its reported
accuracy circle; it is never animated along a fabricated journey or snapped to streets.
The camera reframes after about 15 metres; manual pan/zoom pauses framing until the
route control is tapped. Center on my location remains a separate close-follow view.
Without GPS the map focuses the destination without inventing a dot or walking path.
Real directions still require a fresh, sufficiently accurate fix and provider success.
87 actual-model tests and Debug/Release syntax checks passed; native map rendering
and outdoor GPS acceptance remain pending. See [MAP-TRACKING.md](MAP-TRACKING.md).

## Simplified plaque action — build 58

Stop pages with a plaque now show a full-width hunter-green button above Stop details,
with a white camera icon, “Find on-site plaque with AR” and a disclosure chevron.
The optional/on-site subtitle and separator were removed. The button wraps for large
text and retains a minimum 56-point height. Already unlocked discoveries retain
View the bonus and their existing bonus access. Debug/Release syntax checks passed;
native visual and touch verification remains pending.

## Collapsible stop history — build 57

Stop details appears directly above each available historical description, including
the mill text beginning “Standing along the Rahway River.” The native disclosure
opens by default for each newly opened stop and toggles without leaving the page.
Only the history collapses; metadata, narration and optional bonus controls retain
their positions in the page flow. Stops without history have no empty disclosure.
Debug/Release syntax parsing passed; native layout and VoiceOver checks remain pending.

## Current narration player — build 56

The shared player now uses a screen-proportional 96–128 point illustration, a larger
semibold serif title matching the stop headings, and a white 64-point play/pause button.
Title and playback occupy one column beside the artwork, leaving Close at top right.
The seek target is 44 points tall. Accessibility text sizes use a full-width wrapping
title above the artwork and transport; Reduce Motion also wraps instead of scrolling.
The footer reserves its real height, including error messages. Audio and navigation
behavior are unchanged. Debug/Release syntax parsing passed; native layout, controls,
and VoiceOver verification remain pending. See [PLAYER-REFINEMENT.md](PLAYER-REFINEMENT.md).

## Figma illustration download

[Download all five tour stop illustrations](docs/design/exports/Cranford-Tour-Illustrations-Figma.zip?raw=true).
Unzip and drag the five numbered files onto a Figma canvas. The mill, Greystone and
river are the original transparent 1448 × 1086 PNGs. Church and hotel are scalable
SVG exports of the current app drawings, with transparent 1440-pixel-wide PNG alternatives.
The package includes import instructions and a checksum manifest. It has not been
uploaded to a Figma file; no Figma connector was available for direct import.

## Current Developer Controls — build 55

Removed the simulated-location and movement panels, mill viewing-point shortcut, and
both bonus-alignment editors. Existing saved bonus placements load read-only so the
bonuses retain their positions. The former mill arrival override is retired; its saved
coordinate imports once into the new GPS capture log with original time marked unknown.

Choose a stop, enter an optional label, then Save GPS reading. Multiple fresh device
readings can be stored per stop with coordinates, accuracy, fix/save times and Precise
Location status. Copy individual/all readings or Share all readings as CSV. These local
test records never change map markers, navigation, visits or arrival thresholds.
See [GPS-CAPTURE-TEST.md](GPS-CAPTURE-TEST.md) for verification and device acceptance.

## Current Stops list — build 54

The Stops list shows only earned Visited and On-site bonus unlocked labels. Unvisited
stops have no status line. Reading/listening, current-destination and media-availability
labels are removed from this list, including its VoiceOver row descriptions. Detail
pages and saved activities are retained. Swift syntax checks passed; device layout
verification is pending.

## Current Map controls — build 53

Previous stop routes to the preceding stop in the tour order, including skipped stops.
It preserves visits, stories, bonuses, elapsed time, distance and the current audio.
Automatic progression holds the chosen destination until Continue now (or explicitly
releasing Stay here after arrival). The selection/hold survives relaunch; paused walks
remain paused. Previous is hidden at the first stop and outside an in-progress walk.
View stop and Previous/Continue use two rows; returning to a visited site still shows
route distance/time. Six new model regressions passed; native checks remain pending.

## Current Home map interaction — build 52

Tap any Home map landmark to preview its name, address, date and short history.
View stop opens that specific stop's full page; X dismisses only the popup. The
same preview is used by Google Maps and the Apple fallback. Browsing does not
start or retarget the walk. Syntax checks passed; native tap/layout checks remain.

## Current stop details — build 51

The construction date, address and Show on map action now sit directly beneath the
stop title, above Listen/Read. The shared layout applies to all stops. The history
text remains below the story controls. Swift syntax was checked; native layout
verification remains pending.

## Current map artwork — build 50

Landmark illustrations explicitly use their original colors and transparent backgrounds.
The shared Google/Apple image view opts out of inherited UIKit tint dimming, and marker
snapshots use an enabled, standard-color rendering environment. Original artwork, marker
sizes, bottom-left numbers and collision behavior are retained. Native color verification
on iPhone remains pending.

## Current AR arrows — build 49

AR directions use large, deeply extruded hunter-green/white chevrons. The street
name appears only in the bottom direction card. Their world pose stays fixed while the phone
turns or GPS fluctuates. Repositioning requires about five metres of AR camera
translation or a stable changed turn instruction. See [AR-ARROWS.md](AR-ARROWS.md).
Native rendering and outdoor stability still require iPhone verification.

## Current UX behavior — build 47

This implementation follows UX audit recommendations 1–7, 9 and 10. Map shares AR's
next-turn cues, stable arrival holds the place for exploration, and confirmed departure
on foreground Map guides onward with Undo/Stay here. Browsing, photos, AR and background
hold automatic progression; narration continues independently. Final arrival can finish
truthfully without crediting skipped places. Manual Continue remains available.

See [UX-IMPLEMENTATION.md](UX-IMPLEMENTATION.md) for scope, regression results and remaining
native/field checks. Older release notes below describe earlier behavior and are superseded
by this current interaction contract. This is a review build; native/device checks remain.

# Ready-to-open Xcode project download

This branch includes the generated `CranfordHistoricalAR.xcodeproj` together with the app source.
It includes the Field Guide interface, guided AR marker activation and the existing build fixes.

On a Mac with Xcode installed:

1. Click **Code > Download ZIP** on this branch and extract the ZIP in Finder.
2. Open the extracted folder and double-click **CranfordHistoricalAR.xcodeproj**.
3. Wait for Xcode to download its package dependencies.
4. Select your signing team and connected iPhone in Xcode, then click Run.

Keep all extracted folders together. Homebrew and XcodeGen are not required to open this snapshot.
The source includes a subfolder also named CranfordHistoricalAR; the project file is beside that subfolder.
The saved project structure and source syntax were checked on Linux; a full iOS build and device installation have not been verified.
Use Xcode's **Product > Build** directly; the optional verification script still requires XcodeGen.

If Xcode says **Signing requires a development team**, this is your local Apple account setup:

1. Choose **Xcode > Settings > Accounts**. Add your Apple Account if none is listed, then close Settings.
2. Choose **View > Navigators > Project** (or press **Command–1**). Click the top blue
   **CranfordHistoricalAR** project icon in the left sidebar.
3. In the center project editor, click **CranfordHistoricalAR** under **TARGETS**, then
   **Signing & Capabilities**. If TARGETS is hidden, expand the project/target list at the left
   edge of that editor.
4. Check **Automatically manage signing**. Open **Team** and choose your own team or
   **Personal Team**. Leave the bundle identifier unchanged if it is available to your account,
   so it keeps matching your Google key restrictions.
5. Choose your connected iPhone, then **Product > Clean Build Folder**, followed by **Product > Build**.
   Expect **Build Succeeded** before choosing **Product > Run**.

Google API keys do not select an Apple signing team. A new ZIP includes the compiler fixes but
does not include your private Google settings or Apple signing identity. Copy your working
`Config/Secrets.xcconfig` from the previous download into this download before building.

The original project documentation follows.

---

# Cranford Historical AR

A SwiftUI + ARKit/RealityKit + Core Location + Google Maps walking-tour MVP for Cranford, New Jersey.
Follow AR walking arrows, activate a stop marker on site, and discover its historical sign and narration.

> The bundled walking tour is **five** HPAB audio-tour stops (Droescher's Mill, Greystone, Rahway River,
> First Baptist Church, Cranford Hotel). The tour began with the HPAB May 2020 brochure; stop 1 now uses
> the tour creator’s supplied descriptions and narration script. Stops 2–5 keep their HPAB recordings.
> Stops 1, 2 and 4 use creator-supplied coordinates; stops 3 and 5 retain unverified geocodes.
> None of these positions is surveyed. Read or listen to any stop from
> anywhere; AR visit recording has separate on-site checks.

## Field Guide interface

The selected earthy design uses ivory, forest, sage, sand and terracotta, with a dark version
that follows the device setting. The native bottom tabs are **Home**, **Map** and **Stops**.
A single compact audio player remains above the tabs after starting a walk or playing a stop.
The Map tab has one destination panel; the arrival state replaces its heading rather than
adding a second card. Tap the count beside **Your walk** for the tour summary and whole-route view.
Tap **Developer** on Home (or long-press the home title or **Your walk**) in Debug builds for Developer Controls.

Browse any stop and play its recording without changing the guided tour order. **Show on map**
centers that stop without changing the walking destination. The details page always offers
**View in AR** (or **Walk to Stop N in AR** when browsing another stop). This explicitly starts
the first destination or resumes the current guided destination; it never skips ahead merely
because another detail is open. After a completed tour, **Start new walk in AR** restarts it. The shared details page provides the photo, address, recording and available
historical text; source and coordinate notes are under **About this stop**.

Tap a stop photograph on the map panel, stop list or details page to enlarge it. Pinch to zoom,
drag while zoomed, double-tap or use **Reset zoom**, and tap the visible **X** to return. Closing
a photograph does not mark a stop visited or advance the tour.

The Stops list places a transparent illustration to the left of every stop name. It reuses the
mill and Greystone artwork; the river, church and hotel use symbolic drawings pending their own
reference photographs. Tapping any part of a row opens its details and photo slideshow.

The mill and Greystone landmark illustrations are decorative artwork based on their photographs.
They are noninteractive overlays beside stops 1 and 2 on the live Google map at neighborhood zoom,
and also appear in the offline illustrated overview. It does not supply street data, route geometry,
precise building boundaries, or AR image-tracking references. The real photo and plaque reference
remain separate and unchanged. Google Maps still requires the private Maps key described below.

Validation in Linux: TourCore build/tests and Swift syntax checks are available. The saved Xcode
project includes the new files. SwiftUI rendering, image-viewer gestures, tab/player placement,
Google Maps overlays, dark mode and AR still require Xcode and a physical iPhone. See
[design-qa.md](design-qa.md) for the remaining device checks; no iOS build success is claimed.

## Selected walking-screen reference

The app-owned walking interface follows [the selected reference](docs/design/walk-reference.jpg).
A custom SwiftUI Home / Map / Stops bar replaces the system bar visually so its full-width
warm-white surface, evenly spaced icons and labels remain consistent across iOS versions.
The selected icon/label is forest green; inactive labels use a darker neutral gray for legibility.
The bar stays light in dark appearance; other content keeps its earthy dark appearance.
The native TabView retains screen state, one tour and one shared narration player.

The destination panel uses a larger landscape photo, serif stop title, coral walking icon,
distance/time divider, a full-width View in AR button and a Stop details disclosure row.
The map's two circular white controls sit at its lower right. Google Maps street/park/water
colors are muted to match the reference palette, while live cartography and routes remain real.
Google attribution remains the map provider's attribution; the mockup's OpenStreetMap footer
is not copied into the Google map. The existing mill illustration and real photographs are reused.

The audio strip has a terracotta play/pause circle and thin progress rail. Tap its title/progress
area to open stop details and the full player; recorded audio retains its seek slider there.
**Walking directions in Google Maps** and the current written turn instruction are in Stop details.
Route failures, estimated distances, permission notices, AR activation and Continue remain available.

Linux checks cannot render this native interface or prove an exact visual match.
See [design-qa.md](design-qa.md) for the pending Mac/iPhone comparison checklist.

## Guided AR walk and recorded visits

**Walk to the mill → read/listen → optional plaque discovery → Continue to Greystone.**
The guided order stays fixed while visitors browse or listen to other stops.

AR walking uses one broad **semi-transparent ivory ground arrow**, with a fine forest edge,
instead of four opaque breadcrumbs. It follows the next walking-route vertex, retaining the approach direction within 3 meters
to avoid reversals from a noisy GPS fix, then points to
the visible stop marker on arrival. Horizontal plane detection refines its height when a nearby
ground surface is available; otherwise it uses a stable height estimate beneath the camera.

On entering AR, a large camera-relative **left/right/ahead** cue helps the visitor face the walk,
with the route's current street (or "Toward [street]") and distance in **feet** to the next turn.
It fades after sustained alignment and returns if the visitor looks away. Near a real route turn
(about 150 feet), an upright **floating turn arrow and street name** appears in the scene. It
shows the turn's walking distance in feet, says "Turn … now" at the corner, and retires once
route progress passes the turn. This turn arrow is distinct from the camera-orientation cue.

Ground/sign transforms ease between positions, heading filtering takes the shortest angular
path, and visibility uses hysteresis to reduce flicker. There is no continuous pulsing. Reduce
Motion disables movement/scale animation. The ordinary GPS accuracy notice moves to a small
walking-footer line; tracking failures still show an explicit message. Meshes/entities are
reused, and a turn texture rebuilds only when its street, direction or rounded distance changes.

Street names and maneuvers come from Google walking steps, never a stop's address or a hard-coded
"Davis St". Missing/off-route step data does not produce a fictional turn sign. When only a
straight-line estimate is available, street-walking arrows are withheld and the visitor is
directed to the map. Marker guidance, activation and the explicit Continue flow remain shared.
GPS positioning is approximate; floating signs are clamped to a legible viewing range rather
than claiming surveyed intersection alignment. Ground arrows stop before the marker and disappear
while its story is active. GPS movement direction is not treated as the camera's facing.
When tracking/heading is unusable, arrows hide and the **Map** control remains available.

AR walking refresh validation: **151 TourCore XCTest tests passed**, including upcoming-turn
selection, route-based feet distances, street parsing, entry/orientation hysteresis and angular
smoothing, near-corner GPS drift and suppression of off-route arrows. **20 production tour-logic
integration tests passed** using an offline directions fixture. Debug/Release source syntax and saved Xcode source references also passed. These checks
do not build the iOS application or verify RealityKit rendering, outdoor surface detection,
intersection alignment, native animation or Google authorization. Those require the Mac/iPhone
checks in [design-qa.md](design-qa.md); rendered visual QA remains pending.

At Droescher’s Mill, arrival offers the **normal detail screen** with its photograph and story.
Narration starts only when the visitor presses Play. When the shared player finishes, the detail
screen offers **Find the plaque in AR**. **I've read the story** offers an equivalent accessible
path. Discovery is optional: Continue works after reading/listening without saving a verified
visit or unlocking the extra. Completion in the walking tour is distinct from plaque verification.

Choosing discovery starts the search. A currently tracked, matching plaque with normal AR world
tracking records the visit once and displays a brief translucent confirmation. No extra activation
tap is needed. GPS arrival, the Play button, story completion and an old visit record cannot unlock
the bonus. The generic marker above the plaque and the mill's large AR playback panel are removed.

The **test bonus placeholder** covers the **two glass panes in the red double doors**, immediately
right of the plaque. Its pose comes from the plaque plus configurable relative bounds, then stays
in the AR world when the camera turns toward the glass. It is not independent window recognition.
The initial ratios and 18 cm plaque width are unmeasured estimates; exact pane alignment is not
claimed. The placeholder is translucent and tappable, with an X to close; it opens a clearly labeled
placeholder for future photographs, video or extra narration. It remains accessible only in the
active AR session, within 12 meters of its established pose and while world tracking is normal.
Leaving/restarting AR requires seeing the plaque again to re-establish the pose; saved plaque
verification remains on the device. A previously saved record alone never exposes the extra remotely.

The current site coordinate came from the user's Google search; it is **not a surveyed public viewing
point or evidence of access permission**. Until field capture, arrival uses that approximate site
coordinate with fresh GPS, accuracy ≤25 m and distance plus uncertainty within the arrival radius.
In Debug **Developer → Mill viewing point → Save this location as the viewing point** captures a
fresh, real-device fix at the mill (simulated/stale/poor fixes are rejected). It stores coordinates
and reported accuracy locally and changes the story-arrival test only; it does not silently move
the building marker or Google route. Send the readout back for a subsequent verified catalog update.

For placement testing, use **Align bonus** inside the AR camera, or **Developer → Mill window bonus
alignment**. Keep the plaque in view while changing right/up/width/height, then close the page to
inspect the overlay on both panes. Values are multiples of the assumed plaque width and persist
locally; resetting visits preserves them. **Mark story read for testing** bypasses audio playback
without pretending a plaque was found. Reset tour re-arms the story and clears the session unlock.

Greystone and other stops without a plaque retain their GPS marker activation and narration flow.
Their repeated activation taps do not duplicate visits or restart playback.

GPS activation requires a fresh location (under 30 seconds old), reported accuracy of 25 m or better,
and distance plus that uncertainty inside the stop's arrival radius (35 m by default). AR world
tracking must also be normal. This is an **on-site estimate**, not visual proof or an anti-fraud
system. A previously seen plaque is insufficient to override poor GPS after image tracking is lost.
The AR session must currently track the matching plaque for that override. Unverified stop
coordinates and the unmeasured plaque width remain field-test limitations.

Only real activations are saved locally on the iPhone, with stop ID, date and activation method.
The app keeps the latest real activation per stop; no location trail, camera photo, account or
cloud synchronization is added. Visit dates appear in **Stops** and stop details and remain after
relaunch. Starting a fresh walk still begins at stop 1. Developer walking and Xcode-simulated GPS
activations are practice and never overwrite real visit records.

Closing a card, viewing a photo, browsing a stop or walking away never advances the destination.
After the mill story (with or without discovery), **Continue to next stop** updates the route and AR target from Droescher's Mill
to Greystone, then onward through the remaining stops. Stay in AR or tap **Map**. The map's
**Directions** action opens Google Maps walking directions in the installed app or browser;
embedded Google Maps/Routes still require their existing API-key configuration.

Validation for the earlier AR-guidance update: **109 XCTest tests passed**, plus 21 isolated checks executing the
production proximity extension and visit store in a Foundation-only host. Debug/Release source
syntax and all 48 app source references in the saved Xcode project were checked. The isolated host
does not validate iOS location delivery, route services, RealityKit, camera recognition, audio, or
SwiftUI rendering. Host-app XCTest changes are supplied but require Xcode to run. A full iOS build
and physical-device AR test have **not** succeeded here. Follow [AR-FIELD-TEST.md](AR-FIELD-TEST.md)
on the Mac/iPhone for those checks.

Current mill-content validation: **118 TourCore XCTest tests passed**, including the dedicated
script, backward-compatible JSON and voice-selection policy. Xcode-only tests also cover the
preview/bundle content match and AVFoundation voice settings; they have not been executed here.
The iOS build, actual voice sound/pronunciation, map popup rendering and AR card layout still
require the Mac/iPhone checks in [AR-FIELD-TEST.md](AR-FIELD-TEST.md).

## Requirements

- macOS with **Xcode 16.0+** (Google Maps SDK 11.x requires it), iOS 17.0+ device for AR (the Simulator runs the map and Developer Controls but not ARKit).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.40+ — `brew install xcodegen`.
- A Google Cloud project with billing enabled and these APIs turned on: **Maps SDK for iOS**, **Routes API** (the legacy Directions API is not available to new projects; see below). **ARCore API** is required only if you turn on Geospatial.

## Open, build, run (Mac)

```bash
git clone <this repo> && cd CranfordHistoricalAR
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # then edit the keys
xcodegen generate                                             # creates CranfordHistoricalAR.xcodeproj
open CranfordHistoricalAR.xcodeproj
```

Select the `CranfordHistoricalAR` scheme, pick your iPhone, and run. Xcode resolves the Swift packages
(`GoogleMaps` 11.1.0 from `https://github.com/googlemaps/ios-maps-sdk`, `ARCoreGeospatial` from
`https://github.com/google-ar/arcore-ios-sdk` up to next minor of 1.56.0, and the local `Packages/TourCore`).

### Run the platform-independent tests anywhere

```bash
cd Packages/TourCore
swift test          # macOS or Linux; no Xcode needed
```

### Verify the iOS build on a Mac

With Xcode (including iOS and Simulator SDKs) and XcodeGen installed, run from the repository folder:

```bash
bash scripts/verify-ios-build.sh
```

This regenerates the included Xcode project, builds the app for an iPhone without signing,
and compiles the app and host-app tests for the Simulator. It stops on failure and records
logs and Xcode result bundles under the ignored `.build/ios-verification/` directory.
It does not run the tests or install the app. A Linux test pass does not verify the iOS build.

`TourCore` contains the models, JSON decoding, geo math, polyline codec, Routes API wire types,
route-progress math, route-refresh policy, proximity state machine (hysteresis), tour progress and the
walking simulator.

## Narration and historical photographs

Each stop resolves narration in this order: `audioURL` (remote HTTP(S) or a bundled file),
`narrationText` (a dedicated on-device script), then `longDescription` / `shortDescription` as a
fallback. `NarrationPlayer` is created once in `AppDependencies`; Home, Stops, Map and AR share it.
Playback is available anywhere. Playing or reading a stop does not record a visit or retarget the walk.

Droescher’s Mill now uses the creator’s supplied short marker copy, 95-word expanded description,
and the exact approved 353-word spoken narration, including the supplied healthcare/Alleum Yoga
paragraph. The title is metadata and is not spoken. The approved wording and punctuation are preserved. The name/address are shared across map
markers, AR, photos, details, Stops and the player. The expanded page has an optional **Read narration**
section, so the long script does not crowd the short AR card.

The current building is labeled **Construction: After 1821**, and the short copy dates the mill site
to at least 1779. The physical plaque still reads **c. 1737**. Its image, transcription, assumed scale
and AR recognition name are retained; the inscription appears under **About this stop**, separate
from the supplied construction history. This is user-supplied historical copy, not independently
verified research. Stop IDs, coordinates and visit records are unchanged.

The mill’s `audioURL` now selects the bundled `stop_01_droeschers_mill.mp3`: a 2:31 AI-generated
OpenAI cedar recording produced with `gpt-4o-mini-tts`. The shared player retains manual Play,
15-second skipping/scrubbing and its existing completion event for optional plaque discovery.
The controls disclose that the voice is AI-generated. Playback is offline and uses no OpenAI key.

The reusable narrator profile and 42-second reference sample are under [assets/audio](assets/audio/README.md).
Generation uses a private environment secret outside the iPhone app. Stop 2 now uses the bundled
`stop_02_greystone.mp3`: a measured 2:23 cedar recording of the exact supplied script, using the
same narrator instructions and processing as stop 1. Both recordings play offline without an
installed speech voice. Stops 3–5 keep their original recordings.

The Droescher's Mill photograph lives in `Assets.xcassets/droeschers-mill` (`imageName: "droeschers-mill"`
on stop 1). Stop 1 also has an ARKit image-tracking reference (`Assets.xcassets/PlaqueAnchors.arresourcegroup`)
using the visitor's real 1280×960 plaque photograph, unchanged. This replaces the old synthetic
bronze date-only stand-in, which did not match the physical plaque. The plate quote is the date line
on the door (`c. 1737`), not 1797 and not extra narrative.

Plaque recognition is Apple ARKit image tracking and does **not** require Google ARCore or an API key.
Image tracking uses stable anchor identifiers, handles tracking loss, and enables automatic image-scale
estimation. The physical width is still **unmeasured**: the legacy 18 cm reference width is only an
initial scale, not a verified measurement. Measure the plaque's outer width on the next site visit
before treating the placement scale as calibrated.

For stops 1 and 2, arrival offers the normal detail screen without automatic narration or saved
verification. After listening or reading, **Find the plaque in AR** starts optional discovery.
A matching tracked plaque with normal AR tracking records verification once and unlocks the
translucent bonus placeholder. The mill uses its calibrated two-door-pane placement; Greystone
uses a separate layout above the Cranford Park plaque. GPS-only arrival cannot unlock either
bonus. Visitors can continue without scanning after reading/listening. On-site ARKit recognition
and Xcode asset compilation remain required checks; Linux tests cannot validate image tracking.


`Resources/historical_stops.json` is the five-stop walking tour the app loads: HPAB brochure stops 1–5
(Droescher's Mill, Greystone, Rahway River, First Baptist Church, Cranford Hotel). `audioURL`
values for stops 3–5 remain the QR destinations. Stops 1 and 2 use bundled cedar recordings of their creator-supplied narration.
First Baptist uses the QR file
`First Baptist.mp3` (not `First Baptist Church.mp3`). Greystone no longer plays the earlier `Greystone.mp3` recording. Stops 1, 2 and 4 use the creator-supplied coordinates documented below; stops 3 and 5 remain
**unverified Nominatim geocodes**. All retain `coordinatesUnverified: true` because they are not surveyed positions. A three-stop SAMPLE fixture
remains in TourCore tests only (`sample_historical_stops.json`).

The retained HPAB audio links use `http://` (the host's HTTPS certificate is self-signed). `Info.plist` allows
insecure HTTP only for `preservecranford.com`.

## API keys (never committed)

### Home screen shows an illustrated map instead of Google Maps

The beige illustration is an offline fallback, not a Google map. It appears when a Maps SDK key
is missing/placeholder or SDK registration fails. It supports pinch zoom (1–4×), dragging while
zoomed, a reset button, and numbered buttons that display the stop name. Its streets and sepia
landmark sketches are decorative and schematic, not surveyed street or architectural data.
The real Google map enables pinch, double-tap zoom, and dragging. Moving outdoors or allowing GPS
does not switch the illustration to Google Maps.

On the Mac:

1. Open [Google Cloud Console](https://console.cloud.google.com/). Select or create your app's
   project, attach billing, and enable **Maps SDK for iOS** under **APIs & Services > Library**.
2. Under **APIs & Services > Credentials**, create or select an API key. Under **Application
   restrictions**, select **iOS apps** and add `com.cranford.historicalar` (or the actual identifier
   shown in Xcode if you changed it). Under **API restrictions**, allow **Maps SDK for iOS**.
   A Routes-only key cannot load map tiles.
3. In Finder, open the **Config** folder inside the particular downloaded project you are building.
   If `Secrets.xcconfig` already exists, edit it. Otherwise duplicate `Secrets.example.xcconfig`
   and rename the duplicate exactly `Secrets.xcconfig`.
4. Open `Secrets.xcconfig` with Xcode or a plain-text editor. Replace the placeholder after
   `GOOGLE_MAPS_API_KEY =` with your key, without quotes. Keep the other keys/team settings
   already configured, or clear their example placeholders if you are starting from the template.
   Never paste a real key in chat or commit this private file.
5. In Xcode choose **Product > Clean Build Folder**, then **Product > Run** to rebuild and
   reinstall. These keys are embedded at build time; relaunching an old installation is insufficient.
6. On the home map, pinch with two fingers, double-tap to zoom in, and drag to pan. It should show
   Google street-map tiles and Google attribution, rather than the beige illustration.

Each newly downloaded ZIP excludes `Secrets.xcconfig`. Copy your private settings from the older
project's **Config** folder into the new project's **Config** folder before rebuilding; do not
overwrite an already configured file. Without that step, a new download returns to the preview map.

In a Debug build, tap **Developer** on Home to open **Developer Controls**. **Configuration** shows
whether the Maps SDK key is present, whether SDK registration succeeded, and the bundle identifier.
Registration success does not verify Google authorization: blank/missing map tiles with a present
key still require checking billing, enabled APIs, key restrictions, connectivity, and the Xcode console.
The Routes API key is separately required for walking routes; it is not required just to zoom the map.

`Config/Secrets.xcconfig` is gitignored. Copy `Config/Secrets.example.xcconfig` to it and set:

| Setting | Purpose |
| --- | --- |
| `GOOGLE_MAPS_API_KEY` | Maps SDK for iOS. Restrict the key to iOS apps with bundle id `com.cranford.historicalar`. |
| `GOOGLE_ROUTES_API_KEY` | Routes API (`computeRoutes`, `travelMode: WALK`). Can be the same key during development. |
| `GOOGLE_ARCORE_API_KEY` | ARCore Geospatial (`GARSession` API-key auth). If empty, the Routes key is reused. Restrict the key to bundle id `com.cranford.historicalar` **and** the ARCore API. |
| `DIRECTIONS_PROVIDER` | `routes` (default) or `legacy` for Cloud projects that still have the Directions API enabled. |
| `ENABLE_ARCORE_GEOSPATIAL` | `0` (default). Set `1` to *request* Geospatial at runtime. Still needs key, precise location, network, device support, and first-run consent. |
| `DEVELOPMENT_TEAM` | Apple Team ID for device signing. |

The xcconfig values flow into `Info.plist` (`GoogleMapsAPIKey`, `GoogleRoutesAPIKey`, `GoogleARCoreAPIKey`, …) and are read by
`AppConfiguration`. If keys are missing the app still runs: the map shows a configuration notice and routes fall
back to clearly labeled straight-line estimates. Geospatial falls back to GPS + compass.

### Cloud Console checks (walking distance / time)

The tour header and Next Stop card show **walking-route** miles and minutes from the current GPS
fix to the current stop (`GoogleRoutesDirectionsService` → `RouteProgress` → `DistanceFormatter`).
If you see **“Requests from this iOS client application \<empty\> are blocked”** and dashes for
distance/time, Google received no iOS bundle id.

1. This app’s bundle id is **`com.cranford.historicalar`** (`Info.plist` `CFBundleIdentifier` and
   `PRODUCT_BUNDLE_IDENTIFIER`). Every Routes/Maps request sends `X-Ios-Bundle-Identifier` with that
   value — never an empty string.
2. Google Cloud → APIs & Services → **enable Routes API** (not only Maps SDK for iOS; the legacy
   Directions API is not available to new projects).
3. Credentials → your key → Application restrictions = **iOS apps**, add bundle id
   `com.cranford.historicalar` (do not leave the iOS-app list blank). API restrictions should include
   **Routes API** (and **Maps SDK for iOS** if the same key serves the map).
4. Rebuild after changing the key. The app does not crash on a 403; it keeps the last known route
   and otherwise shows a labeled straight-line estimate.

Do not put API keys in source control. `Config/Secrets.example.xcconfig` is the template only.

## ARCore Geospatial (Mac + device)

The `ARCoreGeospatial` product is linked via SPM (`project.yml`: `https://github.com/google-ar/arcore-ios-sdk`,
up to next minor from **1.56.0**). Linker flags already include `$(inherited) -ObjC`; bitcode is off; modules
and auto-linking are on.

This does **not** mean Geospatial is on. Runtime still requires all of:

1. Google Cloud: enable **ARCore API**. Create (or extend) an API key. If the key is restricted, allow
   bundle id `com.cranford.historicalar` and the ARCore API. Maps-only restrictions produce
   `GAREarthStateErrorNotAuthorized`.
2. `GOOGLE_ARCORE_API_KEY` in `Secrets.xcconfig` (or a reusable Routes key) and `ENABLE_ARCORE_GEOSPATIAL = 1`.
3. Location When In Use **and** precise location (`PreciseLocationForAR`) **before** the Geospatial session is configured.
4. Network (VPS and Cloud auth).
5. First-run consent with Google’s required text (“To power this session, Google will process sensor data… Learn more”
   → https://support.google.com/ar?p=how-google-play-services-for-ar-handles-your-data). The consent screen includes the Google Play Services for AR / Google Privacy Policy notice.
6. A physical iPhone that reports `isGeospatialModeSupported(.enabled)`. The Simulator cannot run ARKit or Geospatial.

`GARSession` is created with `sessionWithAPIKey:bundleIdentifier:error:`, configured with
`geospatialMode = enabled`, and fed the same `ARSession` frames (`update:error:`). There is no second
camera or `CLLocationManager`. Site placement uses
`transformFromGeospatialCoordinate:altitude:eastUpSouthQTarget:error:` at the stop’s lat/lon and optional
WGS84 ellipsoid `altitude` (otherwise camera geospatial altitude). Heading comes from `eastUpSouthQTarget`
(`heading` is deprecated). VPS coverage is queried with `checkVPSAvailabilityAtCoordinate:completionHandler:`;
missing VPS does **not** by itself fall back (Geospatial can still use GPS) but the HUD says accuracy is reduced.

If Geospatial is unsupported, unauthorized, offline, declined, or does not localize within 12 seconds,
`CoreLocationGeoSpatialProvider` takes over (ARKit `.gravityAndHeading`) and the HUD says positioning is
GPS/compass and less precise. Arrival 35 m / departure 50 m, RealityKit signs, arrows, Maps routes, and
Developer Controls stay as they are.

**This repository’s Linux build cannot compile or run ARCore.** After `xcodegen generate` on a Mac, resolve
packages, run on a device, and confirm Earth tracking in Cranford before treating Geospatial as working.

## Developer Mode (simulate the walk)

Debug builds define `DEVELOPER_MENU` (see `project.yml`), which compiles in **Developer Controls** (spec §19):

- On the tour screen: `⋯` menu → **Developer Controls**.
- On Home: tap the visible **Developer** button. The title's long-press shortcut also works.

For on-site repeat testing:

- Turn **Save visit history** off to avoid saving new visits on this device. AR activation,
  narration, visited status for the current walk, and Continue still work. Existing history is
  unchanged. Saving defaults to on each time the app launches; simulated visits are never saved.
- Tap **Clear visits & restart at stop 1** to delete saved visit history and reset the current
  walk to no stops visited. This also pauses simulated walking and stops narration. It leaves
  the visit-saving switch and location source as selected and does not erase other settings.
  The existing **Reset tour** button restarts only the current walk and keeps saved history.
- **Live coordinates** displays the same latitude/longitude as the map and AR, with six decimal
  places, reported accuracy in meters, fix age updated once per second, and Precise Location
  permission. Old fixes are labeled out of date. The source is explicitly labeled **Device GPS**
  or **Simulated location**. Leave simulation off for field testing. More decimal places do not
  make GPS more accurate. Coordinates are selectable for copying and are not stored as a trail.

Controls: toggle a **simulated location** (replaces Core Location through the same single `LocationService`
the app uses in production), **walk toward the next stop** along the live walking route at 1×/3×/10× pace,
**move 25 m**, **jump to the next stop** (lands inside the arrival radius so the real arrival flow fires),
**trigger the historical sign**, **mark visited & skip**, **reset tour**, simulate weak GPS accuracy, and a
diagnostics panel (proximity state, route source, routing errors, key presence). Release builds contain none
of this code.

In the iOS Simulator the map, routing, panel and Developer Controls all work; ARKit does not run in the
Simulator, so the AR screen shows its "AR isn't available on this device" state there.

## Known console messages (Simulator)

Running in the iOS Simulator floods the Xcode console with lines like these on launch and while
interacting with the UI:

```
cannot add handler to 0 from 0 - dropping
Failed to send CA Event for app launch measurements for ca_event_type: 0 event_name: com.apple.app_launch_measurement.FirstFramePresentationMetric
Failed to send CA Event for app launch measurements for ca_event_type: 1 event_name: com.apple.app_launch_measurement.ExtendedLaunchMetrics
non-launching port is incompatible with service identifier "com.apple.PointerUI.pointeruid.default-service"
```

None of these come from this app, TourCore, the Google Maps SDK or Core Location — the app has no
logging of its own, and the strings do not appear anywhere in the repository or its dependencies. They
are emitted by Apple system frameworks inside the Simulator (`libapp_launch_measurement.dylib` for the
"CA Event" lines, UIKit's event/pointer plumbing for the other two) and show up in an empty SwiftUI
template app as well. They are harmless. You can confirm the origin yourself: in the Xcode console,
select a line and open the metadata (eye icon / ⌥⌘M) — the *Library* and *Subsystem* columns show the
Apple framework, not `CranfordHistoricalAR`.

To hide them:

- **Console filter** (recommended): type `cannot add handler` into the console filter field and
  choose *Hide*, or filter by *Library ≠ UIKitCore*. Nothing from the app is lost.
- **Scheme variable**: the `CranfordHistoricalAR` scheme already carries `OS_ACTIVITY_MODE = disable`
  (unchecked). Tick it in *Edit Scheme ▸ Run ▸ Arguments ▸ Environment Variables*, or set
  `isEnabled: true` in `project.yml` and regenerate. This mutes all unified-logging output, which also
  hides Google Maps SDK key errors and Core Location diagnostics, so leave it off while setting up keys.

Messages that *are* worth reading in the Simulator: anything mentioning `GMSServices`/`Google Maps SDK`
(key problems) or `CLLocationManager` (simulated location not set — use *Features ▸ Location* or
Developer Controls).

## Tests

| Where | What | How |
| --- | --- | --- |
| `Packages/TourCore` | XCTest: models/JSON (including HPAB catalog + narration source), geo math, polyline, Routes API decoding, route progress, refresh policy, proximity hysteresis, tour progress, summary, formatting, walk simulator | `cd Packages/TourCore && swift test` (macOS or Linux) |
| `CranfordHistoricalARTests` | Host-app flows: arrival → marker activation → visit → explicit Continue, practice isolation, saved visits, hysteresis, configuration fallbacks | Xcode **Product ▸ Test** (iOS Simulator is fine) |

## Project layout

```
project.yml                 XcodeGen definition (the generated .xcodeproj is included for downloads)
Config/                     Base/Debug/Release xcconfig + Secrets.example.xcconfig
Packages/TourCore/          Pure Swift package + XCTest (runs on Linux)
CranfordHistoricalAR/
  App/                      @main, AppDependencies (composition root), AppConfiguration, AppTheme
  Models/                   Bridges TourCore models to CoreLocation
  Services/                 HistoricalStopService, LocationService, DirectionsService, GeoSpatialProvider, ImageLoader
  AR/                       ARViewContainer, GeoAnchorManager, ARNavigationArrow, ARHistoricalSign
  Views/                    HomeView, TourView, MapView, ARView, NextStopCard, TourHeaderView, TourCompleteView, …
  ViewModels/               TourViewModel (single source of truth), MapViewModel, ARViewModel
  Developer/                Developer Controls (DEVELOPER_MENU only)
  Resources/                historical_stops.json (5-stop HPAB walking tour)
CranfordHistoricalARTests/  Host-app unit tests (Mac/Xcode)
```

## Behaviour notes

- **Narration** is a Spotify-like player on every stop (play/pause, ±15 s, scrubber). It is not
  gated on GPS: **Listen to a stop** on the home screen, a home-map callout, the **Stops** list,
  a tour-map pin, the next-stop card, the arrival card, and the AR/sign sheet all share one player.
- **First screen map** is a live Google map of all stops (dots; numbered once zoomed past level 16;
  tap a numbered or plain dot for an in-map name popup plus a callout with the player, tap the map to dismiss).
  Without a Maps key it falls back to the stylized sketch map.

- **Distances and times** on the panel always come from the walking route (Routes API `computeRoutes`,
  `travelMode: WALK`), refreshed on a policy (moved ≥ 25 m, off-route > 30 m, stale > 90 s, destination
  change, ≥ 8 s apart) and interpolated locally between refreshes. If routing fails the last known route is
  kept; with no route at all a clearly labeled straight-line estimate is shown.
- **Arrival** reveals the marker at 35 m and hides an unactivated marker beyond 50 m (hysteresis).
  Only an explicit AR activation with the location/tracking checks above counts as a visit.
  **Continue** then advances the tour; hiding the story card or walking away does not skip stops.
- **AR placement** uses ARCore Geospatial when it is requested and actually localizing; otherwise ARKit
  `gravityAndHeading` plus GPS/compass. Distances to the sign are clamped (2.4–9 m). The HUD says
  "AR positioning is temporarily unavailable…" when tracking is poor, and names GPS/compass when Geospatial
  is unavailable. `ENABLE_ARCORE_GEOSPATIAL=1` requests the upgrade; it still falls back instead of blocking the tour.

## Status

All seven implementation stages are in place, plus narration/HPAB catalog work and an ARCore Geospatial
provider behind `GeoSpatialProvider`. The pure logic is tested on Linux; the iOS app and Geospatial itself
need a Mac + device (see `docs/arcore-geospatial-report.md` in the project store).

## Greystone content and photo gallery

Stop 2 is now displayed as **Greystone** throughout Home, Map, Stops, AR and the player.
Its stable `hpab-002` identifier, approximate coordinates and tour position are unchanged.
The creator supplied its marker text, expanded description and full narration, including
references to its later name, Cranford Hall. The exact script is retained as a readable transcript.
Its bundled cedar narration is 142.73 seconds (2:23), replacing the former on-device reading
and editorial duration estimate. The voice preference remains available for fallback only.

Stop details support a `photos` array of local asset names, captions and optional credits.
The first photo is the cover unless the older `imageName` explicitly supplies a different cover.
With multiple photos the gallery rotates every six seconds, supports manual swipes and
Previous/Next buttons, and has a pause control. Rotation pauses while a photo or AR is open,
when leaving the screen, or when the app becomes inactive. VoiceOver and Reduce Motion
use manual paging. Tap any photo to enlarge it, pinch to zoom, and use X to return.
Photo browsing never changes the walking destination or marks a stop visited.

Greystone's current seven-photo gallery starts with the creator's newer entrance photograph,
followed by the additional building view, tower close-up (photo 3), stonework close-up (photo 4),
the Lincoln Park stone footbridge (1912), Gloria Swanson and William Randolph Hearst. Captions
use the tour creator's identifications. The additional building image's filename is
`1923-Greystone.jpg`; no capture date is asserted from that filename.

The bridge retains the creator-supplied caption that it remains today, and this source credit:
Cranford Historical Society, *The Birth and Growth of Cranford*, Part IV, PDF page 6.
The identifications and source were supplied by the creator, not independently verified here.
Original JPEG files were copied without image edits. No additional API key is needed for photos.
Gallery photos do not enable recognition. Greystone now has a separate Cranford Park plaque
reference in the ARKit resource group for optional on-site bonus discovery.

## Stop 1 and 2 on-site coordinate correction

Current destination coordinates include the creator’s October 22, 2026 public viewing-area GPS reading for stop 1 and on-site reading for the church:

| Stop | Latitude | Longitude |
| --- | --- | --- |
| Droescher’s Mill (`hpab-001`) | 40.650249 | -74.301047 |
| Greystone (`hpab-002`) | 40.6524 | -74.2990 |
| First Baptist Church (`hpab-004`) | 40.653165 | -74.302768 |

The previous mill geocode was about 902 m from the supplied mill position; Greystone’s was
about 66 m from its supplied position. These replacements are in the bundled catalog, its
portable test fixture and the preview catalog. Stable stop IDs, visit history, arrival radii,
content, gallery photos and plaque recognition resources are unchanged.

Map markers, the mill illustration, proximity detection, walking route requests, external
Google walking directions and AR geographic targets already read the shared stop coordinate.
The blue dot continues to use the phone’s accepted location fix; it is never snapped to a
stop to conceal a discrepancy. No global GPS offset or larger arrival radius was introduced.
The app loads the catalog from its bundle on launch; the routing cache is in-memory, so
installing and launching this new build does not reuse a route to the previous bundled point.

The two supplied points are about **298 m (979 ft) apart in a straight line**. The actual
street route can be longer; neither distance nor a two-to-three-minute ETA is hard-coded.
The supplied positions are approximate, not independently surveyed, so the coordinate warning
remains. Correct data does not remove ordinary GPS/compass uncertainty or prove AR placement.

Regression checks reproduce arrival rejection with the old catalog, then check the supplied
points, marker availability, on-site activation, cross-stop separation and local route progress
after correction. The native host-app regression additionally checks map marker/user position
agreement and the first-to-second-stop handoff; it must be run in Xcode. A live Google walking
route, physical GPS accuracy and real AR alignment still require an on-site iPhone test.

## Mill story/discovery validation

**147 TourCore tests** passed, including story/discovery separation, optional continuation,
one-time unlock, practice/reset behavior and plaque-relative window layout. **20 isolated app
logic tests** passed using the production tour, proximity, visit-store, developer and routing
logic with an offline directions fixture and Foundation location values. These cover the current
stop changing to Greystone without a verified visit, real plaque evidence, save/reset behavior,
local viewing-point capture, simulation rejection and calibration persistence. Two map-model tests
and the additional native AR/no-auto-play test require the Apple SDK and were not run here.
Debug/Release syntax and project source references pass. Native compilation, sheet transitions,
audio completion, recognition, window fit and AR anchoring still require the Mac/iPhone checks
in [AR-FIELD-TEST.md](AR-FIELD-TEST.md) and [design-qa.md](design-qa.md).

## Greystone Cranford Park plaque discovery

Stop 2 uses the creator-supplied black **Cranford Park** plaque photograph as a separate ARKit
image reference. It is copied unchanged, including surrounding stone; no generated plaque or
retouched image is used for recognition. Aim at the sign and include the stone surround. The
**0.75 m reference width covers the whole photograph** and is an unmeasured testing estimate,
not the measured width of the black sign. Automatic scale estimation is enabled; actual
recognition, scale and placement need physical-device testing.

Greystone follows the story-first optional discovery flow. Recognition must match its reference,
not the mill's, and occur with current tracking during discovery. The one-time confirmation,
plaque-verified record and tappable bonus placeholder use the existing shared mechanism. Its
extra is centered above the plaque; the mill's viewing-point override and door calibration do
not affect Greystone. The extra remains available only in the current AR session with normal
tracking and within 12 meters of its established pose. Leaving AR requires recognizing the plaque
again to restore the bonus pose. No remote unlock follows from saved visit history alone.

Verified here: 153 core tests, 22 production tour-logic integration tests with offline directions,
Debug/Release syntax and resource/source checks. Native build, ARKit reference-image validation
and real recognition remain to be checked on the Mac/iPhone.

## Greystone pillar placement refinement

The additional context photograph is retained at
[docs/field-references/greystone-plaque-pillar.jpg](docs/field-references/greystone-plaque-pillar.jpg).
It shows the black sign attached to a stone pillar with free space above it. The default extra
now fits within the pillar's apparent width and clears the sign, rather than using the earlier
wider floating card. These are photo-relative proportions, not measured dimensions. The original
close-up remains the recognition reference; the wider view includes background at other depths
and is retained for placement guidance rather than registered as another planar image target.

In Debug, open **Align bonus → Greystone plaque bonus alignment** while the plaque remains in
view. Adjust right/up/width/height, then return to inspect. Changes are applied even while the
phone is still, and persist locally across relaunch and visit resets. Greystone and mill settings
have separate storage/reset controls. Units are widths of the original close-up reference frame,
including stone; the 0.75 m reference scale is still unmeasured. Reset Greystone placement restores
the new photo-based defaults. No map coordinate or walking route is altered by these settings.

Validation: 154 core tests, 23 production tour-logic integration tests using offline directions,
Debug/Release source syntax and project/asset checks. Native slider layout, recognition and
actual overlay alignment still need Xcode/iPhone testing.

## Produced stop 1 audio and narrator reference

See [assets/audio/README.md](assets/audio/README.md) for the real MP3s, approved source text,
profile, reproduction commands and quality reports. The 42.24-second reference was generated
before the 151.30-second stop recording using the same voice profile. Technical and automated
listening checks passed with local pronunciation/human acceptance still pending. No API key is
included in source or the app. The reference remains outside the iPhone resource bundle; only
the stop recording is shipped. Native playback and discovery-after-finish checks require Xcode.


## Narration and detail-screen AR correction — 0.2.0 (2)

The previously published archive contained both approved cedar MP3s and their Xcode resource
registrations. The app does not persist narration selections or recordings across launches.
Correct wording with the old voice is consistent with the earlier on-device narration path,
but this workspace cannot inspect the installed iPhone binary to establish which build or
source actually played. All earlier releases also displayed the same 0.1.0 (1) version.

A confirmed player defect reused a prepared source solely by stop ID. Changing a recording or
script for that ID could keep an earlier source for that player instance; it does not explain
persistence across a genuine reinstall by itself. Preparation now compares source and voice
as well as identity. A produced-narration release pins stops 1/2 to the approved local MP3s,
even if legacy metadata requests phone speech or a remote recording. Loading checks their
actual SHA-256 hashes and exact readable transcripts; incomplete/mixed resources fail with an
explicit rebuild message. The approved audio and user visit records are unchanged.

The missing AR action was caused by `isCurrent && !stop.hasPlaqueReference`: it excluded both
mill and Greystone. The primary action is now available from every detail page. It starts or
resumes the guided walk, offers walking directions before story completion, and starts plaque
search for the current stop after listening/reading. It cannot bypass matching image/normal
tracking requirements or award a visit by entering AR. Details already over the camera return
to that session instead of presenting a second camera. The explicit post-story plaque CTA stays.

To install and identify this correction:

1. Close the previous Xcode project and extract this full ZIP into a fresh folder.
2. Copy your existing `Config/Secrets.xcconfig` into this folder's Config folder.
3. Open this folder's `CranfordHistoricalAR.xcodeproj`. Choose your iPhone, then
   **Product → Clean Build Folder**, followed by **Run**.
4. On the iPhone open **Home → Developer → Installed build and narration**. Expect
   **0.2.0 (2)** and **cedar-2**. After tapping Play, Prepared audio must show bundledAudio
   with the stop_01 or stop_02 MP3. Details show cedar and about 2:31 / 2:23 respectively.
   If the version is different, Xcode ran another project/build. Resetting visits is unnecessary.

154 TourCore tests and six portable checks passed. The latter exercise actual preview and
loader/release code with real MP3 bytes, including rejection of altered/missing audio, old
metadata and changed transcripts. Only the SHA-256 implementation is substituted with the Linux
system utility because Apple CryptoKit is unavailable. Debug/Release Swift parsing passed.
Native regression tests cover source replacement, actual bundle hashes/durations, manual start,
AR entry at first/next/completed tour and story/discovery gating. These require Xcode and remain
unrun here; SwiftUI presentation, native playback and outdoor directions/recognition are not
certified by portable or syntax checks.


## Larger map markers — 0.2.0 (3)

Numbered circles are now 40 points across (44 when selected), with larger numerals and a
56-point interaction area. The mill/Greystone landmark images are also tappable across their
full displayed bounds and carry the same stop identifier as their numbered markers, opening
the same popup/details action. Number markers remain above artwork for overlapping taps.
The illustrated fallback map has equivalent illustration targets that follow pan/zoom.
Debug/Release Swift syntax checks passed. Native Google Maps hit testing, small-screen spacing
and actual tap behavior still require Xcode/iPhone testing. Audio release stays cedar-2.


## Collapsible shared player — 0.2.0 (4)

Swiping upward through Home by more than 24 points minimizes the shared player into a compact
play/pause and title row. A visible top handle toggles its size; dragging the player down
minimizes and up expands, and tapping the minimized title expands it. Playback continues
without preparing or restarting audio. Minimized state survives tab changes for the session.
Reduce Motion disables the layout animation. Browse the stops is now beside the stop count,
above Continue/Start, rather than below that button. The bottom navigation stays available.
Debug/Release Swift syntax checks passed. Real device scroll/drag interaction, large-text layout
and continuous playback during resizing remain to be checked in Xcode/iPhone.


## Simplified stop details — 0.2.0 (5)

Stop details now place Show on map and Start AR directly beneath the address, followed by
Narration player. The external Google Maps directions link and current turn instruction have
been removed from this sheet. Narration player uses the same disclosure interaction as Read
narration, starts expanded and can collapse without stopping playback. Stop description starts
collapsed and opens to the existing complete description. The post-story plaque invitation
points to Start AR, which retains the existing story/discovery and current destination rules.
Debug/Release syntax passed; native layout, disclosure gestures and continued playback require
Mac/iPhone testing.


## Developer GPS refresh — 0.2.0 (6)

Developer → Live coordinates includes Refresh GPS now. It requests a best-accuracy one-shot
location using the existing CLLocationManager, pausing continuous location updates while the
one-shot is pending and resuming them after success/failure (heading stays active). Progress
clears only after the shared tour pipeline accepts a non-simulated fix timestamped after the
request, or after a 15-second timeout. Accuracy is reported honestly; a request cannot promise
an instant satellite fix. The button is disabled while pending or using developer simulation.
Permission failures and timeout have inline feedback. Native regressions cover cached-fix
rejection, shared-pipeline updates, repeated-tap prevention and simulation. Swift Debug/Release
syntax passed; those native tests and hardware refresh behavior require Xcode/iPhone testing.


## Home spacing refinement — 0.2.0 (8)

Home keeps the existing typefaces, colors, artwork, navigation, controls and content order.
Vertical padding is now 8 points above/16 below (formerly 24 each), section gaps 12 (formerly
24), and brand-header gaps 4 (formerly 8). The serif title uses title size, the uppercase
subtitle footnote size and the tagline subheadline size. These remain Dynamic Type styles.
The map grows from 290 points to 310–350 based on the usable viewport, reserving room for the
existing actions and developer control. The content reserve scales with text size; smaller
viewports and larger text remain scrollable. Horizontal margins and button touch targets stay
the same. Browse remains beside the stop count above the walking CTA, as in the latest release.
Debug/Release Swift syntax passed. Height-budget calculations cover several viewport sizes but
are estimates, not screenshots or native layout tests; iPhone visual verification remains open.


## Stops title and full-height spacing — 0.2.0 (9)

Stops now has the same Cranford / HISTORICAL AR title typography as Home. The large native
navigation-title area is removed, bringing the first stop directly below the compact brand
header. Row minimums divide the actual remaining list viewport evenly, excluding the header,
shared player and bottom navigation. Illustrations, text styles, visit state and detail actions
are preserved. Rows have a 100-point minimum and can grow with wrapped text; shorter screens
and larger text scroll rather than clip. Debug/Release syntax passed; native screenshots and
physical interaction/layout checks still require Xcode/iPhone.


## Home map opens on the tour — 0.2.0 (10)

Home now fits only the five tour stops when it opens or the catalog finishes loading, without
an initial zoom animation. A distant user location no longer stretches the Home overview.
The blue location marker still reflects the actual GPS reading; pan/zoom and stop taps work
as before. Home retains the numbered markers and keeps mill/Greystone illustrations visible
even below the usual landmark zoom threshold. Fit padding accounts for their full extents.
The main walking map retains its existing user/destination framing and zoom-dependent artwork.
Debug/Release syntax passed; actual map framing and icon overlap need native device verification.


## Rahway River Stops illustration — 0.2.0 (11)

Stop 3 in the Stops menu now uses a transparent, photo-based illustration of the supplied
Rahway River stepped weir, matching the detailed cutout style of the mill and Greystone.
The original generated RGBA PNG is bundled through the existing asset catalog and replaces
the generic river symbol in this row. Its view keeps the existing 82×76-point fit, accessibility
label, full-row detail action and visit states. This is decorative artwork; tour coordinates,
photo gallery, map icons and AR recognition targets are unchanged. Alpha/asset registration
and Debug/Release Swift syntax checks passed; native rendering still needs Xcode/iPhone.


## Church field GPS reading — 0.2.0 (12)

First Baptist Church now uses **40.653165, -74.302768**, from the creator’s Developer Controls
screenshot received October 22, 2026. The displayed fix was three seconds old, Device GPS,
Precise Location On, Simulated location Off, with reported accuracy ±6.3 m. The capture date
is not visible. This replaces the previous geocode about 32 m north; it remains approximate,
so coordinatesUnverified stays true. Provenance is in docs/field-references/church-location.json.
The bundled catalog, test fixture and native previews agree. Map position, walking-route
destination, proximity and AR geographic target use this shared coordinate. Stop identity,
visit records, arrival radii, narration, artwork and other stops are unchanged.


## Map AR entry control — 0.2.0 (13)

The Map screen now includes a white circular camera/viewfinder button above recenter and
route overview, matching the supplied control reference. It starts/resumes the guided tour
and presents the existing AR camera for the current destination (the next uncompleted stop).
It does not skip stops, finish a story or unlock a bonus. The button remains available without
a Google Maps key; existing AR permission/status handling and route estimates apply. The
control has an accessible name/destination hint and is disabled until tour data is loaded.
Debug/Release Swift syntax and callback/presentation wiring checks passed; native camera
presentation and field walking guidance still require iPhone testing.


## Hunter-green AR chevrons — 0.2.0 (14)

AR route guidance now uses three upright 3D chevrons with opaque white inset faces and shaded
hunter-green frames, backs and 18-cm-deep sides. These replace the flat shaft arrow. They sit
above the detected/estimated route ground plane, ahead along the waypoint direction, face the
visitor for legibility and rotate to the existing smoothed camera-relative bearing. White
chevrons on initial orientation guidance use the same silhouette/palette. Upcoming street
signs use the same three-dimensional set above the retained street/distance label, with
route-derived maneuver orientation. Directions panels now use translucent hunter green.

Meshes are created once/reused; position and rotation transitions last about 0.35–0.4 seconds
and Reduce Motion removes those transitions. Existing localization/tracking guards, stop and
plaque behavior, arrow distance suppression near markers, street turn hysteresis and routing
logic remain in place. Appearance/scale are not surveyed physical positions.

158 TourCore tests passed, including concave-face area/winding, closed body topology, normals,
depth bounds, invalid values and direction mapping. Debug/Release Swift syntax passed. These
checks do not compile RealityKit or verify rendering. Native mesh/material compilation,
contrast in sunlight, perspective, placement, turn transitions and camera movement still
require Xcode/iPhone testing before field behavior can be called verified.


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


## Mill public viewing point — 0.2.0 (16)

Stop 1 now routes to the creator-confirmed public viewing area at 40.650249, -74.301047,
replacing 40.6503, -74.3012. The supplied Device GPS screenshot reports ±5.0 m accuracy,
a 2-second fix age, Precise Location on and simulation off. Capture date is unknown; the
reading was received October 22, 2026. Provenance: docs/field-references/mill-public-viewing-location.json.
This is a field GPS reading, so coordinatesUnverified remains true (not a surveyed position).
The shared catalog supplies the map marker, walking destination and AR geographic target;
the preview catalog and independent position expectations use the same supplied point.
Plaque reference images, bonus layout and arrival/departure radii are unchanged. A locally
saved developer viewing-point override still affects story arrival only; clear that override
in Developer Controls to use this bundled point for story arrival too.

## Independent activities and remote exploration — 0.2.0 (17)

Learning, physical visits and plaque bonuses now have separate persisted timestamps in
`StopActivityLedger`. Finishing either listening or reading completes learning; both can
be recorded. GPS arrival records only a physical visit and never automatically advances the
itinerary or changes playback. A matching, tracked plaque records its bonus separately and
can establish physical presence too; it does not finish the story. Practice never persists a
real visit/bonus. Existing saved plaque visits migrate visit + bonus only, without inventing
learning completion. Resetting the walk preserves accomplishments; Developer clear-visits
clears visit activity without deleting learning or bonuses.

Audio completion is attributed by the shared player's completion callback, not the current
walking destination or visible view. The compact player is restored above the main tabs only
after playback starts. It expands into transport controls, uses the playing story's title,
and is not duplicated when that same story's inline player is visible. Read mode and browsing
another stop retain access to the playing recording. Explicitly playing a different recording
keeps per-story in-memory bookmarks; changing tabs, photos or Listen/Read does not prepare,
pause or reset audio. AV callbacks from a replaced item are fenced by item identity.

Stop details preserve the name, photos and historical metadata, add Listen/Read, and use a
white top-right Back control. Reading requires an explicit acknowledgement, not merely opening
the tab. Photo arrows overlay the middle left/right of the image on translucent backgrounds;
manual swipe, caption, count and photo zoom remain. All automatic slideshow timers and slideshow
play/pause controls are removed. Photo selection and Listen/Read choice survive reopening during
the app session. Plaque entry is optional, needs no finished story and does not start/retarget a
walk. AR holds its inspected site separately from the walking destination; exiting returns to
the presenting screen. A bonus badge appears only after saved plaque evidence.

Home keeps Start a walk (or Continue your walk) as the prominent hunter-green action and puts
Explore the stops beneath it. Exploring does not start a tour or request location/camera access.
The Map tab no longer starts location while no walk is active; explicit Allow location, Start a
walk and AR walking entry can request it when needed. The live-map SDK still needs network access,
and permission-free browsing is not an offline claim.

Content readiness: stops 1–2 keep their approved recordings and full narration text. At the
creator's request, stops 3–5 have explicit “Narration coming soon” placeholders, no legacy
remote audio and no synthesized placeholder speech. Photos, maps and stop browsing remain
available. Their empty Read views cannot mark learning complete. When approved audio and
reading text are supplied, add the content and clear `narrationPending` for each stop in both
the bundled catalog and preview catalog. No recordings were generated in this update.

Validation: 168 TourCore tests and 18 tests against the actual Foundation app models/stores/routing
pass on Linux. Prepare the latter with `python3 scripts/prepare-activity-model-tests.py`, then
`swift test --package-path .build/activity-model-harness`. This harness substitutes Apple coordinate
bridges and external service protocols, not the state/proximity/routing implementation. Native
store/calibration tests are retained; two new AVFoundation integration tests exercise real recording
completion attribution and bookmarks on Mac. Debug/Release Swift syntax passes. Xcode compilation,
SwiftUI layout/gestures, AVFoundation tests and live ARKit still require Mac/iPhone validation.

## Photo-led stop page — 0.2.0 (18)

Stop details keep the top-right Back, manual slideshow and captions, full name, quiet
construction date and address, quiet Show on map, one Listen / Read control, and an optional
Find the bonus row where plaque recognition is supported. Read uses approved narration text
only; it never substitutes a description or adds History & sources. Missing narration text
retains the explicit pending message. Reading acknowledgement follows the same transcript-only
rule. Switching modes and Back do not touch the shared player or walking destination.

Continue to next stop is removed from the detail page and remains on Map's destination card;
this keeps learning separate from walking. Existing AR walking controls are retained.

Validation: 168 core tests, 18 app-model flow tests and Debug/Release Swift syntax checks.
Native layout, audio and Back/gesture behavior require Mac/iPhone verification.

## GPS-first walking map — 0.2.0 (19)

Map gives real geographic context the most space. A compact destination panel shows the
stop name, distance and walking time, View stop and explicit Continue. Fresh accurate GPS
presence shows You’re here; historical visits do not. Arrival never opens the story or
automatically advances. The story, visit and bonus records stay independent. Recenter and
route framing precede a circular camera button with a small AR label. The Map camera entry
always uses the existing walking destination, and leaving AR preserves it.

Google remains the configured map provider. Without its key, Map and Home now use MapKit
with real street geography, all five existing tour illustrations, and tappable numbered
markers at their catalog coordinates. MapKit draws GPS from the same location source as
Google and AR; it never creates a second location manager or requests permissions itself.
Home overview excludes GPS and does not start a walk. Artwork is decorative; the map, GPS
and route are geographic data. Route framing includes the routed path, not just endpoints.

Apple walking directions are used without Google map/route keys, or after a Google routing
failure. Both providers use returned street/path polylines, real distances and travel times;
Apple step times are apportioned from the route time because its steps do not provide times.
Canceled requests do not trigger another provider. Cached routing and existing reroute policy
remain in force. Connectivity is still required. If providers fail, existing same-destination
routes remain; distance estimates are labeled and never drawn as navigation paths. The legacy
schematic, if used elsewhere, is explicitly labeled overview only. Location coordinates retain
their existing field-verification status; map alignment does not turn them into surveyed points.

Validation: 168 TourCore tests and 24 portable model/provider-flow tests passed, including all
five stops completed through GPS and explicit Continue with no learning or plaque prerequisite,
saved-visit vs live-arrival distinction, Map/AR target continuity, primary routing, fallback and
cancellation. Debug/Release Swift syntax checks passed. MapKit rendering, live route responses,
Google Maps and iPhone AR still require native Mac/iPhone compilation and field testing.

## Separate optional plaque discovery — 0.2.0 (20)

Supported stop details now show Find the plaque / Optional bonus · On-site only, changing
to View the bonus after saved recognition. The saved bonus opens directly without camera
or GPS access; its existing placeholder content is unchanged. Story and photographs stay
available, and audio is never paused or prepared by entering, retrying or leaving discovery.

A dedicated plaque camera opens the selected stop immediately, with the stop name, one short
instruction, Retry and top-right Back. It has no walking arrows, itinerary Continue, generic
surroundings tutorial or geospatial consent. It uses image-enabled AR world tracking with
gravity alignment and a local provider, without requesting or starting GPS. Retry restarts
camera tracking and reloads references without clearing activities. Failure/unsupported-camera
states retain Back; unsuccessful recognition offers retry guidance after twelve seconds.

Recognition may switch the scanner to any supported tracked plaque, as requested, but never
starts/reorders the walking itinerary. Scanner entry also works after a completed walk without
resetting it. Matching live reference images and ready camera tracking provide the bonus
evidence; story completion is not required. Unknown/untracked images do not unlock anything.
Map's AR entry keeps its walking role. Choosing plaque discovery from an existing walking
AR story switches that camera to the same scanner interface without creating another session.

Validation: 168 core tests, 28 portable model/provider tests, and Debug/Release Swift syntax
checks. The added flows cover camera-only Greystone discovery before starting a walk, another
supported plaque during a walk, completed-walk preservation, retry/return persistence and
unsupported stops. Actual camera permissions, image recognition, AR placement and native
layout still require Mac/iPhone validation; Linux checks do not execute ARKit or SwiftUI.

## Persistent Map and independent relaunch resume — 0.2.0 (21)

Map is now rendered in every walking phase. Completed walks show a quiet Walk complete /
View summary row, and the full summary opens separately. Closing it returns to Map. Showing
any stop on Map retains a Viewing [place] panel, while an active itinerary independently says
Walking to [destination]. Viewing never changes the itinerary. Geographic recenter/route
framing clears the viewed-place panel. After completion the optional AR walking button remains
disabled; it cannot silently restart a walk. Home or the summary's explicit Walk it again
action can start a new itinerary. Existing GPS/route controls remain available.

The live composition root injects separate local audio and walk stores. WalkResumeRecord
keeps the ordered itinerary, destination, actual visit markers, distance and completed summary.
Compatible incomplete walks load paused with no location subscription, routing request or
permission prompt. Map and Home do not restart location for that paused state. Resume walk
or Home's Continue your walk explicitly starts location and routes to the saved destination.
Catalog/order changes, corrupt records and unsupported versions safely discard the itinerary
record without deleting independent learning, visit or bonus accomplishments.

Recorded-story bookmarks include recording identity and position, independently of walking.
They checkpoint every five seconds while playing, plus seek/pause/source-switch/completion
and app lifecycle transitions. Relaunch loads metadata only, without preparing AVPlayer or
activating audio. A quiet Home Resume [story] / Paused at [time] row appears for a valid saved
recording; tapping it explicitly prepares, seeks, then plays. The normal compact player takes
over after playback starts, so there is no duplicate resume transport. Changed produced-audio
SHA256 identities invalidate old positions; completed recordings leave the unfinished-story
offer. Restoring or retrying never manufactures story completion. Exact durable seek applies
to recorded audio (including both approved narrations), not future synthesized speech.

Only the two selected audit recommendations were implemented; content-readiness labeling was
not changed. The original geographic providers, approved illustrations, narration files,
manual photos, Listen / Read and optional plaque scanner are retained. Developer reset also
writes the new walk state; it does not clear the separate audio bookmark or learning/bonus data.

Validation: 172 TourCore tests and 36 portable actual-model/store/provider tests passed,
including fresh-model paused restoration, completed-map focus for every stop, disabled
completed-walk AR entry, separate viewing/walking contexts, persistent-store corruption and
changed catalogs. The portable suite runs three actual Foundation audio-store tests. Native
AVFoundation tests were added for metadata-only restoration, explicit resume and changed
recording identity; these remain unrun on Linux. Debug/Release Swift syntax passed. Native
Xcode compilation, AVPlayer seeking, location/camera prompts and layout require Mac/iPhone QA.
