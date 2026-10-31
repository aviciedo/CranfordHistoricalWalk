# AR walking and plaque evaluation — 31 October 2026

Baseline: published build 115, `d91859f4b75d910febe7ce5771b24fe3a510fe3e`.
This assessment was recorded before changing either AR pipeline. Repository snapshots,
source commit dates, release tags and all 41 open issue listings are preserved in
[the evidence inventory](ar-repository-evidence-2026-10-31.json). The external libraries
were inspected, not added to the app or certified as compiling on the current toolchain.

## Decision

Use **Option 1, targeted native improvements, for both capabilities**. Keep RealityKit,
ARKit world/image tracking, the existing location stream, Google walking routes, the
optional existing ARCore provider and one tour state. No new third-party dependency,
SceneKit scene, Vision recognition pipeline or replacement camera owner is justified.

Option 2 has useful reference techniques (image registration and geometric path creation),
but these are already present in native form. Option 3 would replace tested navigation,
permission, unlock and exit behavior without demonstrating better localization.

## Current architecture and complete journeys

### Walking

Home/Map starts or resumes `TourViewModel`. `CoreLocationService` owns the only native
`CLLocationManager`; it publishes location/true-heading samples to the tour. The existing
Google Routes walking service (with configured legacy/MapKit fallback) returns pedestrian
polylines and steps. `RouteProgressCalculator` projects onto that route; its progress and
destination feed **both Map and AR**. The walking AR cover creates `ARViewModel`, which
copies the active route preview into `GeoAnchorManager.NavigationTarget`.

`ARRoutePlacementEngine` samples forward geometry, stops before sharp corners and rejects
estimated/simulated routes and poor route alignment. `CoreLocationGeoSpatialProvider`
uses a stable WGS84 ECEF → ENU → east/up/south frame, timestamp-matched AR translation,
bounded GPS corrections, true-heading validity and course/trajectory consistency. The
optional ARCore provider consumes the same ARSession's camera frames; it does not start
another location manager. Consent, configuration, network/support and localization timeout
govern its use/fallback. Google Maps SDK itself supplies no Live View API here.

`ARSpatialConfidence` requires reliable location, heading, tracking, route offset and
preview, with two-second acquisition and immediate hard loss. `ARWorldPlacementState`
pins the world pose. `ARAnchorManager` owns one world root, reusable arrows and sign.
`ARNavigationArrowEntity` creates three closed, extruded, chamfered meshes with white
faces and hunter-green sides. Camera yaw is absent from the placement policy; the camera
changes perspective rather than billboarding the arrows. Small accepted relocations animate.
Ground planes/raycasts refine height, not latitude/longitude or sidewalk semantics.

`ARExperienceView` retains Back/Close, map return and the existing raised-then-face-up
two-second phone-down gesture. Foreground/background forwarding pauses/resumes the session.
Tour arrival/dwell, narration/plaque bypasses, departure and automatic advancement remain
owned by the tour and its tested policies, not by AR entities.

### Plaques

Stop details → `PlaqueScannerView` → the same `ARViewContainer`/delegate/model infrastructure,
with a **fixed scanner purpose**. It uses `.gravity`, reference-image detection and no
walking geospatial dependency or GPS permission request. Walking mode deliberately registers
no plaque images, so passing a plaque cannot silently switch modes or award a sketch.

The `PlaqueAnchors.arresourcegroup` contains the Mill and Cranford Park/Greystone references.
An ARKit `ARImageAnchor` name must uniquely match configured catalog metadata, be tracked,
and have normal camera tracking. `TourViewModel.recognizeSketchPlaque` selects the recognized
AR subject without retargeting the walking destination. The ledger saves the physical
evidence/sketch and queues the existing celebration and corresponding sketchbook page.
GPS arrival and listening never count as image recognition. Existing unlocks survive loss,
retry, new walks and app relaunch; practice evidence is not persisted as a real discovery.

The two experiences share implementation infrastructure but intentionally do not share a
simultaneously running camera. A fixed-purpose session prevents competing delegates,
configuration and award rules. On-screen AR mode changes are not currently necessary:
walking and scanner have separate entry/exit contracts. Ordinary foreground recovery should
preserve the world origin; explicit Retry/new sessions reset it. ARCore → compass fallback
changes world alignment and legitimately requires reinitialization. Avoid introducing an
always-running global camera or pretending those alignments are interchangeable.

## Verified code gaps and bounded changes

1. **Camera/GPS timestamp mismatch:** the native provider records camera translation with
   callback `Date()`, ignoring the capture timestamp already passed to it. Delayed delivery
   pairs GPS with the wrong AR position or rejects an otherwise matching sample. Convert
   AR media time to wall time explicitly and test delayed/future/invalid samples.
2. **Old pose during a turn:** `ARWorldPlacementState` returns the preceding pose during
   its maneuver debounce, even after the user passes it or route yaw changes sharply.
   The renderer also retains visible geometry when no replacement is returned. Retain
   debouncing, but hide an unsafe old pose until the new route direction stabilizes.
3. **Ground confidence wording:** a horizontal raycast currently sets `verified = true`
   even for unclassified surfaces. Only classified floor evidence should earn that flag;
   other horizontal surfaces/estimated camera height remain approximate, never verified sidewalks.
4. **Disconnected plaque presentation:** `PlaqueAnchorController.bind` and `.plaqueCard`
   rendering exist, but the supported-plaque branch always dismisses the sign. Successful
   recognition only calls `observe`. Connect the existing image-anchor presentation rather
   than replacing the recognition engine or adopting a second AR view.
5. **Single-callback evidence:** an initial tracked match immediately reaches the award
   path. Add a short, continuous, identity-specific stability gate before invoking the
   unchanged ledger policy. Unknown/ambiguous images, tracking loss, stale observations,
   interruptions and target motion must break pending confirmation. No GPS input belongs
   in this gate. A screen/photo of a real reference remains a limitation of image matching;
   this is not physical-site authenticity verification.
6. **Scanner lifecycle gap:** walking forwards scene phase, while the direct scanner does
   not. Forward lifecycle consistently, clear pending visual evidence, hide anchored content
   on tracking loss, and reacquire without deleting saved unlocks or repeatedly resetting AR.

The current three-minute near-stop policy and all approved progression bypasses are preserved.
The previous Stop 1 field report is not diagnosed by examining an AR library; use the existing
bounded progression trace and real GPS field script.

## Technical evaluation matrix

“Adapter” means code must be supplied; “unverified” is not a claim of incompatibility.

| Criterion | ARKit-CoreLocation | ARKit-SCNPath | Mirador | Existing/native Apple approach |
|---|---|---|---|---|
| AR walking navigation | Geo nodes and MapKit polyline support; no complete walking state | Local path rendering only | Viewpoint POIs; no route progression | Existing route projection, maneuvers, confidence and tour integration |
| GPS-based AR anchoring | Yes, experimental location/VIO estimates | None | Image-registered coordinates, not GPS fusion | Existing ENU/AR alignment; optional existing ARCore |
| Stable 3D arrows | Custom SceneKit geometry required | Flat path strips; custom extrusion required | Custom entities possible; default POIs billboard/scale | Existing true extruded, route-oriented meshes |
| Google Maps routes | Convert polyline to own/MapKit representations | Convert to local SCNVector3 points | Custom route/provider integration | Already shared Google walking geometry |
| Plaque image recognition | Not implemented in library source | None | Yes, ARReferenceImage/ARImageAnchor | ARKit reference images already configured |
| Visual target anchoring | Custom ARKit integration needed | None | Yes, with developer-supplied location, altitude, bearing, size | Existing image anchor controller; reconnect presentation |
| RealityKit compatibility | SceneKit architecture; port required | Explicitly unsupported | Yes; SwiftUI UIViewRepresentable | Already native RealityKit/SwiftUI |
| iOS SDK compatibility | Swift 5 manifest says iOS 9; ARKit needs 11+; current build unverified | Swift 5; manifest 9.3 vs pod/README 11; current build unverified | Swift tools 5.8, iOS 16+; current build unverified | Baseline verified Xcode 26.3; candidate must pass same native gate |
| Maintenance risk | High; source changes date to 2019, later docs changes | High; core source 2019, master example update 2020 | Moderate/high; core source May 2023, later docs/banner changes | App-owned code and tests; Apple/SDK upgrades still need verification |
| Recommendation | Reference only; do not add second location/SceneKit stack | Reference geometry ideas only | Useful image-registration example; no package integration justified | Targeted improvements for both capabilities |

### ARKit-CoreLocation evidence

Reviewed head [`c74634d`](https://github.com/AndrewHartAR/ARKit-CoreLocation/tree/c74634de4313183e281b323941a5d51fcd165533).
`SceneLocationView.swift` subclasses ARSCNView; `addRoutes` accepts MKRoute/MKPolyline.
`Location Manager/SceneLocationManager.swift` sorts estimates by GPS accuracy/time and uses
a 0.5-second update timer. `LocationManager.swift` creates its own CLLocationManager and
starts best-for-navigation location and heading in initialization. Pausing the estimate
timer does not itself stop that manager. Adding it wholesale duplicates location ownership
and complicates battery/session lifecycle. README calls improved positioning experimental
and documents true-north calibration; it is not survey-grade localization or image recognition.

Package/pod contain no additional external runtime dependency; repository also vendors an old
Pods tree. Podspec says 1.3.1, whereas GitHub's latest published Release is 1.2.1 (2019-08-23).
All 38 open issue listings were inspected, including reports about magnetic heading (#312),
pause/resume (#298/#257), nodes moving with the phone (#270/#223), RealityKit (#189),
SwiftUI (#187/#292) and a reported iOS 27 crash (#316). These are reports, not reproduced
defects or certification that every supported OS fails. No package integration/build is claimed.

### ARKit-SCNPath evidence

Reviewed head [`a186243`](https://github.com/maxxfrazer/ARKit-SCNPath/tree/a1862431cdfd31d780f602483cf39746deaa5068).
`Sources/SCNPath/SCNGeometry+Extensions.swift` triangulates a path strip from local coordinates
and rounds corners; `SCNPathNode` rebuilds geometry as inputs change. It contains no GPS,
heading alignment, navigation progress, image recognition or spatial localization system.
README explicitly lists RealityKit as unsupported. Tests contain a TODO placeholder.
Tag/pod version 1.2.0 exists; GitHub has no published Releases. The sole open issue #13
concerns materials across curves; the maintainer described limited implementation capacity.
Geometry cost increases with input vertices/curve subdivisions; no battery/FPS measurements
were performed. It cannot repair geographic drift by drawing a more attractive path.

### Mirador evidence

Reviewed head [`87e0a6a`](https://github.com/AndrewHartAR/Mirador/tree/87e0a6a6bcfd08654de3840348d595148e6e916e).
`Sources/Mirador/MiradorView.swift` constructs an ARReferenceImage, handles ARImageAnchor
add/update, and positions geographic POIs relative to a supplied LocationAnchor. Thus it
**does recognize a designated 2D target**, not a general architectural landmark or remote
visual-positioning map. A surveyed anchor coordinate, altitude, physical width, orientation
and geographic bearing must be supplied before it can calibrate geographic content.
Those measurements are not established for the Cranford plaques. README's broad accuracy
claims do not substitute for measurement, correct references or outdoor testing.

Default POI entities deliberately face the camera and stay screen-sized. `addLocationEntity`
can omit those behaviors, but does not add a pedestrian route engine. Source performs POI
updates and screen-scale/billboard loops each frame, lacks a didRemove image-anchor cleanup
path and does not gate updates on imageAnchor.isTracked. The retained scene subscription
captures self strongly (a retention risk, not a measured leak). `KalmanFilter.swift` is a
linear scalar filter: averaging +179° and -179° gives 0°, so copying it for circular yaw
would introduce an angular wrap defect. The existing app already uses wrapped-angle math.

Manifest has no external package dependencies and no test target. No published Releases or
tags are present in the inspected repository. Of two open issues, #6 asks about Vision Pro;
#7 contains unrelated HTML rather than useful AR compatibility evidence. Neither proves
modern iPhone reliability. Current SDK compilation and performance remain unverified.

### Licenses

All three inspected LICENSE files are MIT: Project Dent (2017), Max Cobb (2018), Hyper AR
Ltd (2023), respectively. Copying substantial source requires preserving the copyright and
MIT permission/warranty notice. Documentation requests/marketing language are not additional
terms in those LICENSE files. No source or assets are being copied into this app, so no new
third-party runtime attribution/dependency is required by this implementation decision.

## Recognition alternatives and geographic coverage

ARKit image detection is the strongest existing fit for planar, distinctive plaques:
reference assets + physical size + world tracking provide a six-degree-of-freedom image
anchor. Maintain reference identity checks and tracked/camera confidence independently of
GPS. Avoid a competing ARImageTrackingConfiguration/session; image detection inside the
existing ARWorldTrackingConfiguration supports scene/world continuity.

Vision can supply OCR or feature-print/similarity classification, but classification alone
does not provide a metric 3D plaque pose. It needs confidence calibration, negative examples,
camera-to-world ray/depth/plane evidence and additional per-frame processing. It is not a
justified fallback that can award a sketch or invent an anchor when ARKit cannot match.
Non-planar architecture would require a separately authored/tested target approach, not an
assumption that these repositories recognize arbitrary buildings.

ARGeoTrackingConfiguration is a separate possible provider, not a drop-in guarantee for
Cranford. It requires supported hardware/configuration, precise location/permissions,
network and actual geographic availability. Apple's runtime
`ARGeoTrackingConfiguration.checkAvailability(at:completionHandler:)` must be checked at
the intended public viewing location, and localization status still governs rendering.
No successful Cranford availability probe was performed. Do not enable it unconditionally
or stack it with ARCore/ordinary world tracking. Keep the current optional ARCore support,
test its actual VPS coverage separately, and degrade to the map when alignment is unreliable.
See Apple's [geotracking configuration](https://developer.apple.com/documentation/arkit/argeotrackingconfiguration)
and [reference images](https://developer.apple.com/documentation/arkit/arreferenceimage).

## Physical evidence still needed

Both image widths are explicitly estimates: Mill 0.18 m; Cranford Park photograph (including
surrounding stone) 0.75 m. Reference image width means the entire reference crop, not only
its text. Keep automatic image-scale estimation and existing assets until measured values
are supplied; never invent a surveyed plaque bearing/location from these widths.

Unit tests can verify gates, transforms, routes, temporal behavior and callback orchestration.
They cannot establish real plaque recognition rates under glare, oblique views/occlusion,
sidewalk alignment, outdoor compass accuracy, battery usage or 60 FPS. The implementation
report and field checklist must state those remaining device-only checks explicitly.
