# AR walking arrows repair — build 77

## Evidence and diagnosis

The supplied outdoor screenshots show plaque-search controls and no arrows. They
confirm the wrong experience for a visitor expecting walking directions; they do
not identify a GPU/mesh error or prove a particular sensor reading.

Verified in the code before this change:

1. `TourViewModel.shouldSuppressWalkingAR` returned true on broad GPS arrival.
   `ARViewModel.pushTourStateToAnchors` then removed the navigation target and hid
   the arrows. The walking HUD selected plaque controls on GPS arrival, saved
   discovery state, or an ordinary saved visit. The arrival radius is not physical
   plaque recognition. This matches the screenshot state, though its live inputs
   were not recorded.
2. `GeoAnchorManager.placeContent` required `hasDetectedGround` and a detected
   ground-height placement even though an estimated height was already available.
   Outdoor pavement with weak plane detection could therefore hide every arrow.
3. The same method required usable geographic localization (including reliable
   compass heading), plus a geographic world position. A valid route and normal
   visual tracking alone could not show a direction sign. Initial route points
   outside the view could also place the complete sign behind the phone.

The chunky closed-extrusion geometry remains unchanged. Earlier native mesh smoke
checks passed; there is no verified geometry-generation failure in this evidence.

## Implementation

- GPS arrival at a plaque stop keeps walking guidance active until current-session
  plaque confirmation. Explicit scanner entry still hides navigation as intended.
  Saved visits/bonuses do not replace the walking HUD. Removed automatic story-sheet
  presentation on GPS arrival. Near arrival, an explicit Find on-site plaque with AR
  button opens the existing scanner. Physical plaque recognition, award persistence,
  passport reveal, visit rules and automatic tour progression remain separate.
- `ARStreetGuidance.visibleCandidate` chooses a nearby, forward-facing route point
  when usable. Otherwise it supplies an approximately eight-metre-ahead local
  maneuver sign using the tracked camera orientation and a stable estimated height.
  No ground plane, geographic localization, compass or geographic world projection
  is required for this fallback. It is a world-space 3D sign, not a screen overlay.
  The HUD explicitly labels the local sign as not street-aligned. Its maneuver comes
  from the walking route; it does not invent a street, a shortcut or a real surface.
- Ground geometry refines height only. It no longer shifts the bounded lateral
  placement out of renderer range. The existing AnchorState pins full position/yaw/
  instruction: rotating the phone or GPS noise does not move it. About five metres
  of tracked camera translation, or a settled new maneuver, permits a new placement.
- Normal AR tracking and an actual route with fresh location are still required.
  Tracking loss, stale location, missing route and mesh failure have explicit notices.
  A placed sign dismisses the ground-scanning coach even without a plane.
- `updateNavigationPose` is shared by the real frame callback and native regression
  fixtures, so tests cover actual placement orchestration rather than only artwork.

## Validation

Passed on Linux: 235 TourCore tests plus 101 actual-model portable-harness tests,
336 total, including new first-placement/fallback/rotation/movement tests and updated
GPS-arrival-versus-plaque-confirmation regression. Debug and Release Swift syntax
checks passed. No tests were disabled.

Added two native tests in GeoSpatialProviderFactoryTests for normal tracking with
no plane/compass/localization, visible mesh bounds, pinned camera turns, transient
tracking loss/recovery, confirmed activation, missing route and stale location.
These native tests are NOT executed here: Xcode, ARKit and RealityKit runtime are
unavailable. Source parsing does not establish native compilation or visible pixels.

## Required iPhone acceptance

1. Enter AR directions with a fresh GPS fix and a real route while away from a stop.
   With normal tracking, confirm a large green/white 3D maneuver sign appears without
   first scanning pavement. Check the fallback notice if compass/ground is unavailable.
2. Stand still and rotate the phone: sign stays at its world position; when off-camera,
   turn-back guidance appears. Walk approximately five metres: it can reposition.
3. Approach within the Mill arrival radius: walking guidance remains. Enter the
   scanner explicitly, recognize the plaque, verify passport stamp/reveal and correct
   stop return. Existing collected stamps must not be awarded again.
4. Confirm left/right and ahead maneuvers, long street labels in the bottom card,
   non-plaque arrival, Stop 2 progression, repeat walks and previous-stop navigation.
5. Interrupt AR, cover the camera, revoke GPS or deny permissions: clear status and
   recovery must appear, with no invented geographic directions or awards.

Not published by this task. Native compilation and outdoor field acceptance remain
pending; this document does not claim the camera-rendered defect is field-verified.
