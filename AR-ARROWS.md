# AR street arrows — review build 48

Defaults used while clarification is pending: hunter-green sides/white faces, about
five metres before repositioning, and street name both beside the 3D arrows and in
the bottom turn card. These retain the app's approved palette and navigation card.

What changed:
- Three chunky solids: scale 1.1 instead of 0.5, wider spacing, 0.32 m local extrusion
  instead of 0.18 m, larger white faces. Sideways glyphs are about 2.1 m tall in world
  space. Preview normally starts 8 m along the current route segment, without cutting
  corners. Physical size remains fixed between placements; perspective changes normally.
- Complete world pose is frozen: location, facing yaw, direction and street label.
  Turning/tilting the phone no longer rotates the signs. No repeatedly restarted
  move animation and no re-anchoring for each GPS/polyline-segment refinement.
- Reposition after horizontal AR camera translation reaches about 5 m from the last
  placement. Changes in phone height do not count. This uses AR tracking rather
  than noisy GPS displacement; it is an initial field-tunable setting, not calibrated.
- An actual route direction/street change must stay consistent for 1.5 seconds before
  replacing the sign. Briefly missing route/ground hides it and preserves the pin;
  new sessions, interruptions, providers and destinations reset its world reference.
- Arrows show the next routed left/right/diagonal instruction without switching to a
  camera-relative compass glyph. Straight sections use up chevrons. The bottom card
  continues to show live distance and turn text, so an upcoming turn is not an instruction
  to leave the sidewalk immediately at the sign's preview location.
- All orientations get ground clearance from their rendered bounds. The street label
  sits above those bounds, has a solid hunter-green backing, and is built only when
  the street changes. Unknown street names produce no fabricated street label.
- No semantic street detection is claimed. Existing GPS/map providers select the
  route; ARKit supplies the world frame and detected ground. Actual street alignment
  remains approximate, especially without geospatial localization.

Quality check:
- 219 TourCore and 66 portable actual application-model tests passed (285 total).
- Expanded anchor tests cover full-pose stability under candidate/GPS noise, 5 m
  translation, height changes, turn flutter/settling, missing/invalid positions,
  repeated/out-of-order frames, tracking gaps, label changes and session reset.
- Geometry tests cover depth, solid extrusion, valid triangle indices and direction
  mapping. Existing route-corner/estimated-route tests remain passing.
- Debug/Release Swift syntax parsing and git whitespace checks passed.
- Native Apple SDK type checking, RealityKit meshes/text rendering, pixel size,
  outdoor AR tracking and camera/provider lifecycle were NOT run on this Linux host.
  No claim of zero ARKit drift or completed iPhone acceptance is made.

Follow the build-48 cases in AR-FIELD-TEST.md before distributing the change. No
branch was merged/deleted and this implementation task does not publish to GitHub.
