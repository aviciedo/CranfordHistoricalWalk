# Build 101 — route-relative AR navigation implementation

## Original problem and choice

See [the pre-implementation audit and decision](ar-navigation-audit.md). This is a targeted refactor, not a rewrite of the app or its tour workflow. The old production pipeline could substitute a camera-forward position and generate a camera-facing sign, while GPS reference rebinding and interruption resets destabilized the world frame. Rendering alone could not fix those decisions.

Further lifecycle review found that sessionInterruptionEnded explicitly reset ARKit; that reset is removed for ordinary recovery. Heading updates now provide a bounded five-Hz heartbeat rather than relying on a two-degree change filter, so a stationary phone can retain fresh compass confidence.

## Pipeline

1. The existing Core Location source feeds TourViewModel. The existing Google Routes WALK / fallback services provide WalkingRoute; Map and AR share that route, its destination and RouteProgress.
2. RouteProgressCalculator still projects onto actual geometry. With previous progress, ambiguous crossing ties prefer continuity instead of skipping a loop; clear nearest-segment selection is retained.
3. ARRoutePlacementEngine walks real polyline segments 5–10 metres ahead according to speed. It can traverse small curve vertices, stops before >25-degree corners, and suppresses previews with less than three metres of safe approach. It never creates an across-corner chord or converts a straight-line estimate/practice route into street geometry.
4. WGS84LocalFrame uses WGS84 ellipsoidal ECEF → ENU → AR east/up/south axes. ARCameraPositionHistory matches delayed GPS timestamps to AR translation without retaining frames. ARGeographicAlignment retains one origin, caps GPS corrections at 0.25 m/fix, rejects jumps, and checks walking-course intervals against VIO translation. Instantaneous course at a corner is not compared with a longer trajectory.
5. Core Location uses ARKit gravityAndHeading plus fresh true-north readings; magnetic-only/no-compass states do not claim spatial alignment. Optional existing ARCore derives direction from two geographic transforms in its EUS/world basis, not camera-facing heading arithmetic. GARSession receives every AR frame; route/ground calculations remain throttled to ten Hz.
6. ARSpatialConfidence acquires after two seconds of good tracking, ≤5 m location accuracy, ≤10° yaw uncertainty and ≤3 m route offset. Retention allows ≤8 m / ≤15° / ≤5 m to reduce flicker. Stale location, bad tracking or invalid geometry immediately hide arrows. Reacquisition settles again. Estimated alignment residual increases the advertised positional uncertainty.
7. ARWorldPlacementState pins world position, route yaw and maneuver. Camera yaw is absent from its API. Route normal faces back along the walking segment, while the glyph indicates ahead or a turn within 18 m. The card can anticipate a more distant maneuver without rotating world arrows off the current walking segment. A new placement requires movement/approach or a settled segment/maneuver change; small corrections ease over 0.25 s. There is no continuous screen-size compensation.
8. Ground raycasts can refine Y only; they cannot move X/Z off the route. Detected ground under the phone is distinct from verified geometry at the sign. Unverified target height remains explicitly approximate.
9. Ordinary foreground/interruption recovery preserves ARKit’s world origin. Explicit Retry/backend changes may still restart tracking appropriately. Plaque scanning, phone-horizontal exit, camera/location permissions, Back/Close, three-minute visits and early progress remain integrated with the original owners.

## Chevron rendering

Original reusable RealityKit meshes: three closed extrusions, broad unlit #FFFFFF front faces, lit #1765C1 blue sides, consistent spacing and chamfered corners. Depth is 0.25 model metres (about 20% of visible width). Normals, triangulation, closed edges and depth are tested. Physical size is fixed, so approach and camera perspective change apparent size naturally. No images, text glyphs, BillboardComponent or camera-facing world pose are used in the production walking path. Hunter-green HUD cards and existing controls are retained.

Legacy local-sign helpers remain for compatibility/reference tests until native field validation; production walking calls updateSpatial and does not invoke their camera-forward/camera-facing path. No files were removed.

## File inventory

Added:
- Packages/TourCore/Sources/TourCore/ARSpatialNavigation.swift — WGS84 frame, camera history, alignment, route preview, confidence and pinned pose.
- Packages/TourCore/Tests/TourCoreTests/ARSpatialNavigationTests.swift — deterministic spatial/sensor scenarios.
- docs/engineering/ar-navigation-audit.md — audit/architecture decision recorded before implementation.
- docs/engineering/ar-navigation-101.md — this handoff.
- docs/engineering/ar-navigation-field-test.md — reproducible iPhone acceptance plan.

Modified:
- CranfordHistoricalAR/AR/GeoAnchorManager.swift — confidence-controlled route-relative orchestration and height-only grounding.
- CranfordHistoricalAR/AR/ARNavigationArrow.swift — blue/chamfered mesh presentation and pinned spatial update.
- CranfordHistoricalAR/Services/GeoSpatialProvider.swift — stable ENU adapter, timestamp pairing, true heading, transform-derived ARCore direction and actor-safe VPS callback.
- CranfordHistoricalAR/Services/LocationService.swift — bounded fresh heading publication.
- CranfordHistoricalAR/ViewModels/ARViewModel.swift — shared route preview and non-resetting recovery.
- CranfordHistoricalAR/ViewModels/TourViewModel+Routing.swift — continuity-aware shared projection.
- CranfordHistoricalAR/Views/ARView.swift — lifecycle forwarding and less stacked onboarding.
- CranfordHistoricalAR/Views/ARNavigationArrowView.swift — concise approximate-alignment copy.
- CranfordHistoricalARTests/GeoSpatialProviderFactoryTests.swift — native integration tests for fail-closed startup and phone rotation.
- Packages/TourCore/Sources/TourCore/ARChevronGeometry.swift — chamfered triangulated closed extrusion.
- Packages/TourCore/Sources/TourCore/RouteProgress.swift — optional previous-progress tie-breaking.
- Packages/TourCore/Tests/TourCoreTests/ARChevronGeometryTests.swift — revised depth/shape contract.
- project.yml and CranfordHistoricalAR.xcodeproj/project.pbxproj — build 101 metadata only.
- README.md and design-qa.md — validation status.

## Verification

Passed on the Linux Swift compiler:
- 256 TourCore tests, zero failures (17 new spatial scenarios plus existing bearing, maneuver, snapping, angle-wrap and rerouting coverage).
- 118 tests using actual app models/stores/routing in the portable harness, zero failures; includes visit timing/early progression, Map/Home changes, Stop walk and sketchbook flows.
- Full native Swift source/test syntax parsing in Debug+Developer and Release configurations.
- git diff --check.

Native RealityKit/ARKit integration tests are written but NOT RUN. xcodebuild, iOS SDK, Simulator, code signing and Instruments are unavailable on this Linux host. Swift parsing is NOT Apple typechecking or an iOS build. No screenshot comparison, outdoor alignment, VPS coverage or measured 60-FPS result is claimed. Existing Apple CI can validate this commit when it is published; this task does not publish it.

## Limitations and follow-up

- GPS/compass cannot reproduce Google’s proprietary Live View localization or certify a sidewalk. WALK polylines may be street-centerline or generalized geometry. Tight thresholds deliberately prefer Map when uncertain, especially near corners; no automatic road-crossing/surface semantics are invented.
- Core Location and the ARCore adapter currently require both shared-route GPS confidence and provider confidence. VPS-only progress fusion into the shared tour source is a possible later improvement; a second competing AR itinerary is not introduced.
- Ground planes determine surfaces/height, not public access or traversability. No-VPS/GPS drift and unusual phone/case compass interference require physical validation. Large relocalization changes can require explicit Retry/re-entry.
- Dwell/progression rules from build 100 are preserved. Automatic destination changes remain deferred through active story/AR/sketchbook holds; the current view is not torn away during a reveal.
- Tune physical size, placement thresholds, confidence thresholds and handoff animations from the field recordings, not from generated mockups. Consider dual reusable groups for cross-faded handoffs after correctness/performance are established. Profile oldest supported devices before claiming 60 FPS.

Run the [physical iPhone checklist](ar-navigation-field-test.md) before treating spatial alignment as release-verified.
