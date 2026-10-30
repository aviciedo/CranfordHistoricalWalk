## Build 102 — approved Map primary-action journey

Reference: docs/design/map-walk-actions-approved.png, with the user’s explicit removal of the Begin your five-stop walk and Your progress is saved helper sentences. Shared NextStopCard now renders the first destination before starting and the current guided destination during walking. One 56-point hunter-green action appears above secondary View stop / AR directions pills: Start walk, Continue walk, or Stop walk. The old duplicate text Stop walk action and competing next-leg green action are consolidated; explicit next-leg/Finish remain available in More. Destination typography, safe-area navigation, existing turn card, GPS/route state and visited progression are preserved.

120 actual-model portable tests passed. Debug/Release Swift parsing passed. No UI snapshot or native build was run.

Final result: blocked — rendered iPhone comparison and accessibility-size visual checks require Xcode/Simulator, unavailable on this Linux host. The approved mockup is a design source, not a capture of the implementation.

## Build 101 — AR engineering verification

Implemented route-relative world placement, stable WGS84/ENU conversion, sensor timestamp matching, confidence hysteresis, conservative corner handling, shared route projection and blue/white chamfered meshes. No generated image is used as a substitute for 3D arrows.

256 TourCore + 118 actual-model portable tests passed. Full native Debug/Release Swift syntax parsing and diff whitespace checks passed. Native tests added for unlocalized fail-closed behavior, mesh rendering and phone-rotation stability.

Final result: blocked — native compilation/rendering, device motion/sensors, outdoor alignment, target screenshot comparison and frame-rate measurement require Xcode/iPhone, unavailable on this host. The complete engineering handoff and field acceptance procedure are in docs/engineering/ar-navigation-101.md and ar-navigation-field-test.md.

## Build 100 — visit progression behavior

No visual redesign. Added a three-minute accumulated on-site GPS dwell before automatic Visited, with plaque recognition, active narration completion from anywhere, and departure toward the next stop as early-completion triggers. Physical visit history is recorded only with physical evidence; narration alone changes session progress. Existing presentation holds prevent destination changes beneath plaque/sketchbook/story screens.

Validation: 239 core tests + 118 model tests passed. Coverage includes 179/180-second boundary, excluded away/weak/gap/paused intervals, passive physical visits, all early triggers, wrong-way movement, off-site narration, repeated callbacks, Stop walk, Previous/Undo and all-stop Home progression. Full native Swift Debug/Release syntax checks passed.

Native field verification remains pending: real-device GPS accuracy and departure thresholds require an outdoor walk. This Linux host cannot run Xcode or the iOS app.

## Build 99 — broad 3D AR chevrons

Source: docs/design/ar-wide-chevrons-approved.png. The shared native mesh has wider arms, larger scale, thicker extrusion, broad white front faces, hunter-green sides and a 16-degree depth-revealing angle. Projected bounds cap each freshly placed group at 76% viewport width / 29% height. Every direction retains the same rotation mapping, fixed anchor behavior, ground clearance and fallback notices; plaque scanning and UI cards are unchanged.

235 TourCore + 113 model tests passed, including closed mesh/winding/normals, fit limits across device orientations and invalid inputs, route placement and navigation flows. Debug/Release native files passed syntax parsing.

Final result: blocked — native RealityKit screenshots, Apple typechecking and outdoor camera validation require Xcode/iPhone, unavailable on this Linux host. The approved mockup is not evidence of on-device rendering.

## Build 98 — approved pencil-and-ink Home circles

Source: docs/design/home-pencil-ink-approved.png. Replace only Home circle artwork, keeping existing native layout, colors, river edges and actions. Individual unpainted circular pencil-and-ink assets cover all five stops; Mill and Greystone derive from their sketchbook illustrations, River/Church from existing landmark art, Hotel preserves its simplified existing fallback silhouette. Sketchbook watercolor resources and other map/stops illustrations are unchanged.

113 portable model tests passed, including every confirmed visit previewing the next Home destination without silently changing routing. Swift syntax parse passed. Native bundle tests now require every configured stop to have square Home artwork.

Final result: blocked — iOS rendering, bundle tests and pixel comparison require Xcode/Simulator, unavailable on this Linux host. Individual generated artwork is inspected directly; this is not native screenshot verification.

## Build 97 — Stop walk

Added a visible 44-point Stop walk action beneath the Map exploration buttons. Stops active guidance, cancels route tasks, clears destination geometry and instructions, and preserves itinerary/activity/trail state. Resume uses the existing startTour flow.

Validation: 112 portable model-flow tests passed, including stop/clear/resume/progress preservation and rejection of late route geometry while paused; Swift syntax parse passed. Native iOS typechecking and visual layout verification require Xcode and remain pending. No unrelated Home mockup changes implemented.

# Build 95 — approved vintage river Home

final result: blocked

Source visual truth: docs/design/home-river-approved.jpg (590×1280 px user attachment).
The owner explicitly chose the attachment's CURVED lower blue edge over the earlier
straight-edge revision, and chose next-stop-dependent circular artwork. This is the
reference used for implementation. Native safe areas and the shared navigation/player
remain runtime UI rather than imagery. Target phone reference is approximately 390×846.
Implementation screenshot: unavailable. This Linux host has no Xcode/Simulator, so native
viewport/density normalization, full-view and focused visual comparison remain pending.

Implemented:
- Existing 48-point scaled serif two-line title, medium native tagline, 24-point margins.
- Separate circular green engravings for Mill/Greystone/River/Church, a fine ivory rim,
  normalized visible circle sizing, next-stop identity binding and existing Hotel fallback.
- Scalloped upper river mask, native #527784 blue band, hunter-green 56-point-minimum walk
  action, 22-point semibold serif white destination. Large titles wrap instead of clipping.
- Curved lower river mask below destination, ivory menu area, regular-weight shared rows,
  no divider above first row. House/folded-map/two-signpost bottom navigation on ivory.
- Separate text/control layers, preserved Start/Continue/Finish/restart and collection
  behavior, loading/error/retry, developer access and Dynamic Type/short-height scrolling.

Required fidelity surfaces: font family/weight and hierarchy use existing native fonts;
layout measures text/actions first and gives artwork remaining space; colors use native
brand tokens and readable white-on-blue/green; imagery uses RGBA assets with no rasterized
text or controls. Copy is unchanged. These are source/asset findings, not a rendered pass.

Validation completed: 111 portable state-flow tests pass; full Debug/Release app/test
syntax passes; six asset manifests and RGBA dimensions/alpha checked. New native bundle/
signpost and width/height layout tests are written but cannot run on this host. No native
visual pass, GPU rendering or Apple typecheck is inferred from those checks.

Native review checklist:
1. Capture the selected Mill/Continue state, compare the approved attachment and native
   content at matched safe-area viewport/density, then inspect title/circle/river boundaries
   and 22-point destination/menu spacing in focused crops.
2. Check fresh Start, next-leg Greystone, River/Church/Hotel, last stop, completed restart,
   loading and failure/retry. Confirm emblem/destination/action stay in agreement.
3. Check short phone, active narration player, narrow width and accessibility text sizes.
   All controls must scroll/reflow without clipping or compressing touch targets.
4. Verify arrow/navigation/sketchbook actions and confirm existing data stays intact.

# Build 94 — active walking panel consistency

final result: blocked

Source: user-provided active walking screenshot and the previously approved paused-panel
mockup at /workspace/generated_images/exec-fe43b471-73bc-4c96-8f23-76678d0be5a4.png,
with the already-requested removal of Walk paused. Target is the red-marked bottom section.
Implementation screenshot: unavailable (Linux, no Xcode/Simulator); no native density
normalization or full/focused visual comparison is claimed.

Shared destination/header/menu/button implementation from build 93 covers both active
and paused states. Build 94 refines the active route summary: native title3 medium-weight
20-point metrics in secondary ink, 8 points below the title, retained monospaced digits,
left alignment, one-line summary or two intact stacked values when width is insufficient.
VoiceOver now names remaining distance and walking time. Shared 24-point side margins,
14-point action gaps and 44-point circular menu target remain. Destination stays the
largest serif heading. Imagery, top turn card, route geometry, map/GPS and navigation
logic remain unchanged. Active directions never show Resume walk.

Typography, spacing and color are source-reviewed only. Debug/Release syntax and diff
checks passed. Existing native status-height/layout tests remain; they require Xcode
and were not run here. Native acceptance must compare active and paused panels and check
standard/narrow/large-text widths, route loading/error states, menu/title alignment,
metrics wrapping, secondary-action adaptation and remaining map height.

# Build 93 — Map walking section

final result: blocked

Source visual truth: /workspace/generated_images/exec-fe43b471-73bc-4c96-8f23-76678d0be5a4.png
User approved implementation with exactly one change: remove Walk paused.
Implementation screenshot: unavailable; no Xcode/Simulator on this Linux host. Native
viewport/density normalization and full/focused visual comparison remain pending.

Implemented in NextStopCard: unchanged prominent large-title serif destination; 15-point
native semibold Next stop label at 80% forest; 6-point heading grouping, 14-point action
gaps and shared 24-point horizontal margins. Ellipsis uses 44×44-point pale circular
target, title-row top alignment and 12-point separation. Primary actions have 56-point
minimum height, 14-point corners, forest fill and white native headline icon/text.
Equal white outlined secondary actions retain the horizontal/vertical adaptive fallback.
Pause caption is removed; paused routing remains paused until Resume is tapped.

Fidelity surfaces: typography and colors use existing native app tokens; spacing follows
approved hierarchy; map imagery/assets and action labels are retained. No new artwork or
features were introduced. Debug/Release Swift syntax and diff checks passed. No model
logic changed, so previous state-flow results are not represented as newly run tests.

Native acceptance: check paused/resumed/confirmed/final-stop panels on standard phone
and narrow/large-text sizes; inspect first-line menu placement, title wrap, main-button
height, secondary-action alignment and remaining map height. Verify existing menu and
walking actions. No visual pass is inferred from source inspection.

# Build 91 — selected Sunday Fieldbook design

final result: blocked

Source visual truth: /workspace/generated_images/exec-2c09a3a2-d952-48fc-8871-f79b4ee56994.png
First displayed page concept from the latest ideation set, explicitly selected as option 1.
Source: 853×1844 pixels, approximately 390×844 logical viewport. Native target is the
app-owned SwiftUI sketchbook content, with system safe areas retained.
Implementation screenshot: unavailable (Linux host, no Xcode/Simulator). No density
normalization, full-view or focused native visual comparison can be completed here.

Implemented components: SketchbookView, SketchbookLeaf, SketchbookPaper, SketchArtwork,
SketchCollectionRow and SketchUnlockCelebration. User-facing passport/stamp copy is
replaced throughout Home, tour stops, scanner, accessibility and developer controls.
Both approved original Mill watercolor and the matching Greystone watercolor are placed
unframed directly on the cream cloth-bound page. Gray ghosted previews remain locked.
The recognition ledger, v1 wire format and one-shot reveal event remain compatible.

Fidelity surfaces pending native comparison:
- Typography: existing native serif title and sans controls/status are retained.
- Spacing: 24-point header sides, near-edge page, 16-point artwork margins, centered
  stop/status, arrows and collection count outside leaf. Dynamic Type uses scroll fallback.
- Colors: forest/ivory app tokens, dedicated cream paper asset, grayscale locked artwork,
  dark gray recognition overlay. No stamp outlines or perforations remain in the UI.
- Imagery: original transparent 1536×1024 Mill sketch copied unchanged; matching Greystone
  also 1536×1024 RGBA; 1024×1536 paper texture fills the page. Full art uses scaledToFit.
- Copy: Your sketchbook, Sketch unlocked, Sketch added, Added to your sketchbook,
  Not discovered, and sketches found. No imaginary notes, dates or extra index controls.

Checks: 111 portable model + 233 core tests passed; both Debug/Release Swift syntax checks
passed, as did whitespace/asset checks. A new native bundle regression test checks all
configured sketch asset names and alpha-capable artwork; native execution is pending.

Implementation checklist for native acceptance:
1. Capture unlocked Mill and Greystone, locked leaf, tour-stop row and recognition overlay.
2. Compare against the selected mock at matched phone viewport/density and inspect imagery
   at full page and 88-point row size, title wrapping and the gutter/corner treatment.
3. Verify arrow/swipe page curl, Reduced Motion and large text, recognition/reveal/close,
   app interruption, old saved collection restoration and developer visit-only/full resets.
No P0/P1/P2 visual findings or visual pass are inferred from source inspection alone.

# Build 90 — selected scalloped stamp design

final result: blocked

Source visual truth: /workspace/generated_images/exec-6af2e7e3-f3c9-4782-8d06-a633089b883a.png
(first displayed option, selected by the user). Source board: 1484×1060 pixels.
Implementation target: native PassportStampArtwork on passport pages, tour-stop rows
and scanner celebration, including locked grayscale/35% opacity state.
Implementation screenshot: unavailable. Native viewport/density normalization and
full-view/focused comparisons are pending; no visual fidelity pass is claimed.

Implementation uses the generated transparent ivory scalloped frame with hunter-green
inset rule. Original Mill and Greystone art assets match HEAD checksums exactly. The
runtime windows omit only old postage borders, and each illustration keeps its aspect
ratio. All surfaces share the same frame rather than separate stamp images. Typography
and app copy remain unchanged. Shared overall aspect ratio changes from 1.4 to 1.5.

Checks completed: Debug/Release syntax parsing, diff whitespace, 1561×1008 RGBA frame
with transparent center, exact original-illustration checksum preservation, source
window dimensions within each 1484×1060 asset. UI tests are not warranted for this
reversible decorative change; visual acceptance still requires native rendering.

Blocker: this Linux workspace has no Xcode/Simulator for native screen captures. A
supplementary HTML asset-composition check in headless Chromium also failed to complete;
there is no substitute screenshot and no pass inferred from source or asset inspection.

Implementation checklist for native review: inspect full passport at phone width,
88-point tour-stop thumbnail, locked states, page curl and animated unlock. Check fine
edge detail, transparency seams, inset rule, scene preservation and clipping at all sizes.

# Build 89 — map illustration flicker repair

Native visual result: pending iPhone validation.

Source investigation found unconditional live Google marker snapshotting and geometry
rewrites on every camera/GPS update. The repair retains cached artwork and pixel-rounded
layout for no-op updates, snapshots only changed image/size, and disables implicit marker
position/visibility animation. Puck updates remain independent. The Apple fallback shares
the no-op-safe artwork view. No visual layout or illustration assets changed.

Focused native tests cover 120 subpixel camera-size updates without layout/image changes,
intentional zoom, the 44-point target and replacing Mill with Greystone artwork. These
UIKit tests cannot execute on the Linux host. Debug/Release syntax parsing and diff checks
pass. Field acceptance: verify on Google Maps at overview and close zoom, with live GPS,
stationary phone, panning, pinch zoom, recenter and automatic destination advancement.

# Build 86 — one plaque/passport flow for every configured stop

Native visual result: pending iPhone validation.

The supplied Greystone screenshots show the retired bonus HUD and placeholder viewer.
Those views were already removed in local builds 83–84, which have not been published.
Build 86 consolidates the camera callback into the same catalog-driven model operation
for all supported references and removes the remaining unused Mill-specific instruction.
The UI remains the shared scanner header → gray stamp celebration → matching animated
passport leaf → tour-stop page. No separate reward viewer or per-site unlock branch.

111 portable actual-model tests pass. New coverage loops through all configured plaque
stops, verifies durable award identity/date and one pending reveal, duplicate callbacks,
scanner teardown, event consumption and repeat scans. Invalid tracking/reference inputs
cannot award a stamp. Debug/Release app/test syntax parsing passes. No native rendering,
ARKit camera or physical field result is claimed on this Linux environment.

# Build 85 — next-stop illustration, route and walked trail

final result: blocked

Target: after a logged visit, previous site becomes a number and next site becomes
the single illustrated destination. Bottom panel names that next stop with distance
and walking time. Retain a hunter-green walked trail plus a shortening remaining
route. Both Google/Apple implementations consume the same trace and route model.
Trail uses a 4-point forest line; remaining route is 5 points (Google retains white
route casing). Puck remains real GPS and above route overlays. Camera framing keeps
user/departure/destination rather than zooming out to the entire walked trace.
Undo moves into More, preserving a simple destination card. Final completion and
paused/restored behavior retain explicit Finish/Resume where appropriate.

109 portable model tests and Debug/Release syntax checks passed. No native rendered
screens can be captured here. Verify marker reversion, line layering, live updates,
correct next-leg metrics, empty route/loading and GPS-gap handling on iPhone with
both providers before marking visual acceptance passed.

---

# Build 84 — uncluttered scanner and stamp celebration

final result: blocked

Reference: owner screenshot with top Frame this plaque card and unwanted bottom
status/action card. Searching preserves the top directions/reference picture and
removes the entire bottom card. Compact failure-only retry and unsaved/practice
recognition feedback appear below the header, not at the bottom. A real saved new
stamp uses a gray camera overlay with matching artwork, spring stamp-in, expanding
ring and unlocked wording. Reduce Motion fades only. The passport follows after a
readable pause, with a manual Open passport action. Short viewports scale stamp art
and large content can scroll. No bonus or placeholder screen is reintroduced.

Syntax/reference checks passed. Native same-viewport comparison, animation timing,
modal handoff after interruption, VoiceOver reading and outdoor camera tests remain
blocked in this Linux environment. Verify these on iPhone before visual acceptance.

---

# Build 83 — passport-only plaque discovery

final result: blocked

The owner requested removal of the test bonus screen. Removed the screen, all
presentation links, tappable bonus action on passport art, and calibrated window/
pillar AR overlays. Scanner retains the plaque reference photograph and finding
instructions. A saved new recognition dismisses the scanner and opens the correct
passport leaf; Passport stamp unlocked text accompanies the existing animation,
haptic and VoiceOver announcement. Collected stop CTA now reads View passport stamp.
Practice/recording-disabled feedback states that no stamp was saved.

339 portable tests passed, including legacy saved-stamp date migration. Native
camera recognition, scanner dismissal/presentation timing, page curl and accessible
stamp animation cannot be rendered here and remain pending iPhone acceptance.

---

# Build 79 — closer stop-page buttons and final passport section

final result: blocked

Reference: owner-supplied stop page showing Resume narration and View the bonus.
Implementation groups these actions at 12 points instead of the previous outer
24-point section gap. Their full-width bounds, minimum 56-point heights, typography,
wrapping and corners are retained. Other sections remain 24 points apart. Confirmed
that PassportStampRow follows the details/story group and is the final scroll section
for both collected and locked states; it is not duplicated near the AR button.

Debug/Release syntax passed. Native iOS capture and same-viewport visual comparison
cannot be performed in this Linux environment. Check default/large type, active
player, learned status text and expanded/collapsed details on iPhone before visual
acceptance. No new field behavior or stamp award logic was changed.

---

# Build 72 — bottom passport row, locked and collected states

final result: blocked

Reference: owner-supplied Passport stamped row with perforated engraved mill art,
serif heading, stop/count subtitle, chevron and top/bottom lines. Reuses the approved
detailed mill/Greystone stamp PNGs from the passport. Collected heading is title2
serif semibold; row artwork is 88 points wide at default type size and scales up
to 112 points. Text wraps and scales; the full row is tappable. Locked artwork is
desaturated at 35% opacity; text uses readable secondary ink and explicitly says
Stamp your passport. VoiceOver announces Collected/Not collected and the action.
Both states open the correct passport page. Row is last in the scroll content;
duplicate divider after Read the story is removed for plaque-enabled stops.

Checks: Debug/Release syntax passed; four existing passport-flow tests passed in
the portable model harness. Initial cache-path mismatch was resolved with a fresh
container build directory. These checks do not run SwiftUI or ARKit.

Native iOS rendering, exact reference comparison, VoiceOver, large-text layout and
physical AR recognition need device/Simulator acceptance. This Linux environment
cannot capture or run SwiftUI/ARKit. Source checks do not establish pixel fidelity.

---

# Build 70 — First Baptist Church photo-informed illustration

final result: blocked

Reference: owner's contemporary church photograph and the existing original-color
Mill/Greystone cutouts. Created a painterly transparent PNG with white clapboard,
open square belfry, slate roof, rose/arched stained glass, wood doors, brick steps,
black railings, right brick chimney and natural foliage. The obstructing freestanding
message board, sky, wires and neighbors are omitted for a clear landmark silhouette.
A second asset pass restores transparent safety margins above the finial and around
all edges. Final RGBA dimensions: 1122 × 1402; alpha bounds (14,24)-(1109,1384).

Asset inspected: /workspace/generated_images/exec-9adb262a-8b08-449b-8996-74f27b9663ba.png.
App asset: first-baptist-church-illustration.imageset. Stops replaces the previous
church-only Canvas with original-color scaledToFit artwork, in a 104 × 104 area;
other stop thumbnail sizes remain unchanged. Shared illustration consumers also use
that asset. App photos and AR image-reference assets were not replaced.

Verified alpha transparency/margins, manifest filename, SwiftUI reference and both
Swift syntax configurations. No native rendered screen is available here. Verify
thumbnail legibility, proportions, ivory edge integration, large Home artwork and
Google/Apple marker rendering on iOS before marking visual QA passed. Original Mill,
Greystone and River images are preserved. Prior reports follow.

---

# Build 69 — Map destination and instruction hierarchy

final result: blocked

Visual source: owner's current annotated Map screenshot, with the destination
name and distance/time panel boxed in red. Requested refinement preserves the
existing ivory/hunter-green layout while making the stop the strongest text and
navigation information easier to read.

Implemented: current-stop name uses scalable largeTitle serif semibold (34-point
default versus 22); distance/time and arrival use title3 (20 versus 15). The name
and status share a leading-aligned vertical group with a 6-point gap. This removes
the artificial distance gap caused by the More menu's 44-point frame. More stays
44 points at the top right. Turn text grows 17 -> 20 points; turn distance 15 -> 17.
Route/loading/location text remains secondary. Names/status wrap without shrinking;
DestinationFirstMapLayout still reserves actual top-card/footer height before the
map receives space. No route, GPS, progression or AR behavior was edited.

Debug/Release Swift syntax and a scoped diff review passed. The existing native
status-height regression was updated to compare against title3 at normal and
accessibility text sizes. It has not been executed here. No rendered implementation
screenshot, matched density comparison or native visual evidence is available on
this Linux host, so this is not a visual QA pass. Verify short and long stop names,
long street names, loading/arrival/paused states, compact phones, larger Dynamic
Type and a visible narration player in iOS before closing the visual check.

---

# Build 67 — Simplified and rebalanced Home

final result: blocked

Source: owner's annotated Home screenshot. Removed the crossed-out Maps row and
passport count; retained the passport action and bottom Map tab. The active walking
destination now reads Next Stop: plus the actual stop name in semibold serif title3
instead of subheadline. Start/continue/finish behavior and featured-stop selection
are unchanged. Both remaining rows share AppMenuRowLabel. The action group has a
12-point internal gap and 24 points before the browse menu. The existing measured
HomeLandingLayout gives released space to the illustration within its existing
96–340-point bounds, and permits overflow scrolling for large text or a player.

Debug/Release syntax and scoped diff review passed. Native screenshots and visual
comparison are unavailable here. Verify small/large phones, long destination names,
Dynamic Type, visible player, pre-start, active and completed walk states on iOS.
No claim is made that the new screen has passed native visual QA.

---

# Build 66 — Match stop actions to Home menu rows

final result: blocked

Source: the owner's current stop and Home screenshots in this conversation. The
confirmed target is Home's full-width Maps / Explore the stops / Your passport rows.
The two stop actions now use the exact shared AppMenuRowLabel as Home's Maps and
Explore rows. Both use regular body text, title2 icons, 28-point icon columns,
14-point gaps, matching chevron weight and 56-point minimum row height. A zero-gap
section removes the previous extra 24-point spaces around utility-row dividers.
The detail disclosure retains its default-open binding and content, using the same
row with a down chevron when expanded. Long text wraps; actions absent from a stop
remain absent. The reading route and narration/passport behavior are unchanged.

Debug/Release syntax checks and source diff review passed. No native rendered
screenshot is available on this Linux host. Compare collapsed and expanded rows
with Home at default and large Dynamic Type, and check VoiceOver disclosure state
and reader Back behavior on an iPhone before claiming visual QA passed. Previous
377-test native CI success applies to the preceding build, not this unrun UI change.

---

# Build 65 — On-site passport

final result: blocked

Source visual truth: owner-approved detailed rectangular stamp passport mockup,
`/workspace/generated_images/exec-f814cfce-8496-49cf-8a72-0b8941d95d9c.png`, and
attached Passport stamped integration-row crop. Source is a portrait conceptual
render, not a pixel-perfect native screenshot. Target: native portrait iPhone
390 × 844 points with system safe areas; also compact screens and Dynamic Type.

Implementation screenshot: unavailable. This Linux environment has no Xcode,
Simulator or iPhone capture surface. No rendered native dimensions/density or
combined source/implementation comparison exist. Browser screenshots would not
verify the SwiftUI/UIKit/RealityKit implementation. Full-view and focused-region
comparison, touch tests, console/presentation-warning inspection, device camera,
stamp animation and page-curl QA are blocked. No visual pass is claimed.

Implemented source: `Views/PassportView.swift`, stop row and AR-dismissal handoff.
New generated mill/Greystone stamp and paper assets were opened and inspected.
Code review: native serif title/name/row heading; existing forest/ivory tokens;
scalable unclipped text and scrollable paper leaf; persistent 48-point page controls;
48-point-or-larger navigation targets; real transparent perforated stamp images;
collected versus uncollected copy; Reduce Motion and VoiceOver announcement.
These are implementation facts, not rendered fidelity findings.

Required fidelity surfaces remain unverified: typography/wrapping, layout rhythm
and curl, palette/contrast outdoors, actual rendered image crop/sharpness, and
app-specific copy placement. Native UI intentionally uses system sans-serif Back
and small labels consistent with existing screens. The static curled corner is
replaced by the interactive native curl; motion cannot be assessed from source.

Automated evidence: 232 core + 98 actual-model/provider tests passed. Debug with
DEVELOPER_MENU and Release syntax passed. Subsequent GitHub CI run 40261422454
passed native Debug/Release compilation and 145 iOS host-app tests (plus 232 core
tests). Native screenshot comparison, page-curl interaction and field AR acceptance
remain blocked here; the visual result is still blocked.
The first new test run had one incorrect expectation that resetTour leaves the walk
notStarted; corrected it to the established explicit-restart inProgress behavior.
No production restart behavior was changed to satisfy that test.

Implementation checklist: perform the seven native acceptance sequences in
`PASSPORT.md`, capture the passport and earned stop-row at matching viewport/state,
compare both images together against references, fix any P0/P1/P2 mismatches and
repeat. No visual comparison iteration has been fabricated. Previous reports follow.

---

# Build 63 — Photo-led stop details and separate reading

final result: blocked

Visual target: the owner's two annotated direction-1/journal screenshots, with
explicit changes: slideshow first; remove crossed-out map controls and Listen/Read
tabs; green Play/Resume narration; Read the story at bottom; smaller serif Stop
details heading. Confirmed separate reading page, saved-progress button wording,
and serif heading only (body remains unchanged).

Implemented source: original uncropped gallery and captions, stop metadata, green
narration launcher, outlined AR action, default-expanded history and final reading
link. Reader has native Back/X, approved transcript, explicit read completion and
the same shared footer. Missing media is not fabricated. Existing gallery fit is
retained rather than stretching/cropping portrait photos to imitate generated art.

92 model regressions and Debug/Release parsing passed. Native fresh/closed/completed
bookmark assertions were extended but not run here. Apple SDK build, reading-page
nav/Back/X, dynamic playback, gestures, accessibility and rendered comparison are
blocked on this Linux host. Syntax/model results are not a visual QA pass.

On iPhone compare the supplied target with native default and large-text captures,
player shown/hidden, both approved stories, all photo aspects, recording completion,
reader return/Home, explicit read credit, AR/bonus, and no automatic walk/audio
changes from browsing. See STOP-DETAIL-REDESIGN.md.

---

# Build 62 — Stops row refinement

final result: blocked

Target: owner's current Stops screenshot and explicit narrow request to remove
repeated Stop N labels, emphasize illustrations and tighten artwork/name spacing.
No gallery redesign or regenerated illustration assets were requested.

Implemented source: existing original art in 104 × 88-point frames (formerly 82 × 76),
native aspect ratios, artwork aligned toward names, 10-point gap (formerly 14),
flexible aligned serif name column, no visible Stop N line. Spoken stop numbers and
earned Visited/On-site bonus unlocked labels remain. Full-row taps and scrolling
are unchanged. No replacement art or number badges were introduced.

Swift syntax and whitespace checks passed. No native SDK or simulator is available
on Linux, so rendered comparison, Apple build and accessibility acceptance remain
blocked. Verify all five rows on compact/large phones, Dynamic Type, earned states
and with the player visible. Check art is undistorted, long names wrap, all controls
remain reachable and VoiceOver retains stop order/name/status.

---

# Build 61 — Simplified Map, turn card above cartography

final result: blocked

Selected visual target: direction 1, reattached by the owner (590 × 1278 screenshot),
with explicit request to move the green next-turn card immediately beneath the Map
heading, above the live map. Image-viewer X/download chrome is not application UI.

Source implementation: ivory/forest page, measured optional top maneuver, rounded
real map, destination/title/distance below, two white View stop/AR direction actions,
one recenter circle, More for secondary navigation. Original active/selected landmark
artwork stays vibrant; other sites have small numbered markers. Google supports the
quieter ivory/sage/river-blue styling; MapKit provides its own muted cartography.
Decorative tree paintings and generated geography are not fabricated as navigation.

92 model tests passed; final Debug/Release syntax and JSON validation passed. Native
SDK compilation, rendered capture and same-viewport visual comparison are unavailable
on this Linux host. No pixel-fidelity, interaction or accessibility pass is claimed.

Required native checks: turn first with/without player and at larger text; long/unknown
street names; active, visited and selected markers on both providers; single recenter;
More/Previous/Continue/Finish/follow/route; pause/Resume, Undo, arrival hold, offline
retry; View stop/AR/Back/X and unchanged audio. Compare native screenshots against the
selected concept and verify real attribution stays visible. See MAP-REDESIGN.md.

---

# Build 60 — Illustration-led Home

final result: blocked

Source visual target: the owner's attached 592 × 1280 ivory field-guide Home image,
with large two-line serif app name, river-story subtitle, transparent mill artwork,
walking CTA, destination helper, browse row and existing bottom tabs. Requested
variation: Maps row with icon above Explore the stops; hero follows active walking
destination; completion reads Tour complete with Start another walk.

Implementation is native SwiftUI, using the existing illustration assets and Canvas
views, not a new web prototype or a raster screenshot as UI. Native SF Symbols and
semantic text remain editable controls. No image regeneration or production data
changes were needed. Source reviewed for heading/image/action hierarchy, 24-point
insets, icon alignment, full-row hit areas, correct stop identity, loading/errors,
completion and measured space above the shared player/navigation.

90 portable actual-model tests passed, including 3 Home state regressions. Debug
and Release Swift syntax parsing passed. These results are not a rendered design
comparison, Apple SDK build or native interaction/accessibility verification.

Implementation capture: unavailable on Linux without Xcode/iOS simulator. No visual
fidelity or pixel alignment pass is claimed; screenshot comparison remains blocked.
Required: capture 393 × 852-point iPhone Home at matching scale, then small/large
phones, accessibility text and player visible. Compare title, hero proportions,
CTA/helper, Maps/Stops rows and bottom navigation with the supplied reference.
Verify all five destination illustrations, Previous, paused/relaunch, completion,
Maps browse without walk start, Stops browse, developer title long-press, loading
failure retry and continuing audio. See HOME-LANDING.md.

---

# Build 44 — Map/Stops header alignment

final result: blocked

Source evidence: StopsContent used 22-point horizontal header insets; TourView
used 24 points. Both used the same ScreenReturnBar buttons and an 8-point top inset.
The user's requested visual truth is exact matching Back/X positions on both tabs.

Implementation: both pages now render the same ScreenPageHeader component, which
owns 24-point horizontal insets, 8-point top inset, zero vertical stack spacing,
identical Back/X controls and the serif largeTitle heading with 12-point vertical
padding. Map's title-only developer long press remains attached to its title.

Native rendered evidence: unavailable on this Linux host (no Xcode/Apple SDK or
simulator). No pixel comparison or native build pass is claimed. Verify matching
portrait viewport, device scale, text size and safe areas on Map/Stops, with player
visible/hidden. Compare button outer bounds and glyph centers in overlaid captures.
Debug/Release syntax checks passed; code review confirmed a single shared layout.

---

# Build 43 — Photo detail refinement

final result: blocked

Source visual truth: the user's attached 590 × 1280-pixel photo-detail screenshot
(the mill's upper doors and pulley), with requested ivory background, a Photo
heading matching Map/Stops, and caption/credit below the image.
Implementation screenshot: unavailable. The Linux workspace has no Xcode, Apple
SDK or iPhone simulator. Native capture, visual comparison and gesture testing
are blocked; syntax validation is not a visual QA pass.
Target viewport/state: portrait iPhone, fullscreen photo, light appearance, with
unzoomed and zoomed states. Implementation pixels/points and density normalization:
not available. No full-view or focused-region rendered comparison is claimed.

Required fidelity surfaces (implementation intent; unverified visually):
- Typography: exact native largeTitle/serif/semibold expression used by Map/Stops;
  Photo is marked as a heading. Caption is multiline headline, credit is caption.
- Spacing/layout: 24-point shared left/right alignment, caption below the fitted
  image with 16-point separation. Caption gets layout priority over image space.
- Colors/tokens: shared ivory through all safe areas, forest foreground, secondaryInk
  credit, light appearance. Back/X use the existing shared white control design.
- Image quality: existing real image remains scaledToFit; no replacement or default
  crop. Pinch/pan/double-tap reset and Reset zoom implementations are preserved.
- Copy/content: Photo is the page heading; existing caption and optional credit are
  retained below the image. Navigation and audio behavior are unchanged.

Comparison history: no rendered iteration possible. Debug and Release Swift syntax
checks passed. No native build success or visual/interaction pass is claimed.

Acceptance checklist for Xcode/iPhone:
- Open portrait and landscape photographs from multiple stops; check full image,
  ivory notch/bottom areas, matching heading, caption/credit order and alignment.
- Check larger accessibility text and compact devices for wrapping and control fit.
- Pinch/pan, double-tap and Reset zoom; Back returns to the stop, X returns Home.
- Confirm narration continues while fullscreen photo remains free of player overlays.

---

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


## Build 19 — Map is a complete walking entry

Passed 168 core tests and 24 actual-model/provider policy tests plus both syntax configurations.
Native build and device rendering have not been run on this Linux host. Device acceptance:
- Walk all five stops without opening the camera; arrival stays on Map with You’re here.
- View stop returns with playback and destination intact; Continue requires no learning/bonus.
- Recenter, route framing, then optional circular camera / AR appear in that order.
- With Google keys absent, Apple geography/illustrations/GPS and real walking routes appear.
- Test Google route failure with Apple fallback, and both providers offline. No straight-line
  estimate should render as a walkable path. Check Apple attribution stays clear of controls.
- Pan/zoom, rotate device, use larger text, tap every icon, and verify geographic route alignment.


## Build 20 — optional plaque scanner

Passed 168 core and 28 actual-model/provider tests plus Debug/Release syntax checks.
Mac compilation and camera/device verification remain pending. On iPhone:
- Open Greystone from Stops without a walk or location permission; scan immediately.
- Verify correct name, single instruction, Retry and white top-right Back in every state.
- Confirm no walking CTA, arrows, introductory scrim or geospatial consent appears.
- Point at another supported plaque: scanner name/bonus change, walking destination does not.
- With no match or interrupted tracking, Retry reloads references and Back still returns.
- Play a story, change photos/Read, scan/return: recording, photo and mode stay intact.
- Saved View the bonus opens without using camera; no learning completion is manufactured.
- Discover after finishing the walk: phase remains complete.


## Build 21 — stable Map and paused relaunch resume

Automated: 172 core tests and 36 actual-model/store/provider tests passed. Native AVFoundation
resume cases are present but not executed on Linux. Debug/Release syntax passed.

Device acceptance:
- Finish itinerary > Stops > Greystone > Show on map: geographic map focuses Greystone;
  completed phase stays complete and AR walking remains disabled.
- View summary / Back or Done returns to the map. Walk it again is an explicit restart.
- View mill while walking to Greystone: both identities are labeled, route unchanged.
- Listen to mill at a saved position, kill/relaunch while walking toward Greystone: Home
  independently offers paused audio and walking destination. No autoplay or permission prompt.
- Tap Resume story: seek completes before playback; no GPS starts. Tap Resume walk: destination
  stays Greystone; audio remains at its own position.
- Test VoiceOver, larger text, shorter screens, paused Map, background interruption, completed
  narration cleanup, summary reopening and both Apple/Google geographic maps.
