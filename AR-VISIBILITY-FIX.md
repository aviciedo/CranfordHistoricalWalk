# AR arrows never appeared — build 64

## Evidence and limits

The owner reports no arrows at all after several seconds scanning pavement outdoors.
The supplied screenshot shows a camera, destination and Alden St left-turn cue at
380 ft, but no 3D arrows. No frame/provider/pose trace accompanies it. Two code defects
are reproducible in logic tests; neither is claimed proven as that exact field cause.

## Verified defects corrected

1. ARViewModel assigned geoAnchors.hasActivatedStop from isARStopVisited, which includes
   previously saved visits. GeoAnchorManager then unconditionally hid walking arrows.
   A restored bonus also made discovery.hasArrived true, independently blocking the
   target. A return walk now uses shouldSuppressWalkingAR: this session's actual
   arrival/plaque confirmation, preserving all historical visit and bonus records.

2. ARStreetGuidance.routePoint accepts up to35 m lateral route error and stops at the
   next polyline vertex, but AnchorState refused a first placement outside3–14 m.
   Thus GPS offsets or very short segments could yield no first arrow forever.
   readableCandidate retains valid nearby projections; otherwise it places an
   approximate directional sign8 m along the route-bearing vector. It still requires
   a valid route coordinate, usable localization and real detected ground. It does
   not claim the fallback point is the street or the actual upcoming intersection.
   Image-tracked plaque positions bypass this fallback. Invalid input remains hidden.

The entire pose still pins between five-metre camera translations or settled new
turn instructions. No per-frame billboarding, path simulation, camera-follow sign or
route/arrival-threshold change was introduced. GPS/compass registration remains
approximate; no semantic street recognition or zero ARKit drift is claimed.

## Recovery feedback

Native mesh generation, route/location/compass readiness, placement rejection and
off-camera anchors now have explicit HUD messages. The camera-forward dot product
checks that a sign is in front before accepting its projected point as in view.
Off-screen placement suggests left/right or tilt guidance without moving the anchor.
Missing ground retains the existing scanning coach. Actual current-session arrival
continues to suppress walking arrows intentionally.

## Verification

- 232 TourCore tests passed, including5 new nearby-candidate/invalid-input/pinning tests.
- 94 actual-model tests passed, including2 new historical-visit/bonus/Previous regressions.
- Full Debug/Release app/test syntax parsing and whitespace checks passed.
- Added a native RealityKit body/face mesh and initial-placement/visibility/reset
  smoke test in GeoSpatialProviderFactoryTests; not executed on Linux.
- No native Apple SDK build, scene rendering, projection/notice UI or field test ran.

## Repeat field acceptance on build64

1. Build Debug/Release with Xcode and verify installed version0.2.0(64). First run
   native testNavigationArrowMeshesAndInitialGroundedPlacementAreRenderable.
2. Repeat the same outdoor route and position. Use fresh accurate GPS, allow compass
   alignment and scan the pavement. Photograph any remaining HUD blocker message.
3. Test with both an unvisited destination and previously visited/unlocked mill.
   Confirm real ground, arrows visible when facing them, and no old visit suppression.
4. Turn the camera away: anchor stays fixed and HUD explains how to find it. Rotate
   back without walking: same pose. Walk5 m: sign may reposition, then pins again.
5. Check near polyline vertices and lateral GPS offsets; these must not produce a
   permanently blank view solely because candidate range is below3 m or above14 m.
6. Interrupt/background, reenter AR, change destination, use Previous, lose/recover
   ground/compass and retry a failed route. Never invent an on-street pose without
   the prerequisites. Arrow failure must offer a truthful notice and working Map exit.
7. Verify GPS visit, plaque/bonus recognition, street name only in the bottom card,
   narration independence and phone-down return remain intact.
