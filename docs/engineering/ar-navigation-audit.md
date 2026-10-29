# AR walking navigation audit and decision — build 101

## Findings recorded before implementation

Entry: TourView.enterWalkingAR → TourViewModel.prepareForARFromDetails → ARTourView → ARViewModel → ARViewContainer. Walking and plaque sessions are explicitly separate. The host owns camera permission, ARWorldTrackingConfiguration, lifecycle delegates and teardown. ARTourView owns the Core Motion phone-horizontal return gesture; preserve it.

Data: one CoreLocationService → TourViewModel.userLocation/heading → existing Google Routes WALK (legacy/MapKit fallback) → WalkingRoute → RouteProgressCalculator projection → ARWalkingGuidance maneuver → ARViewModel.pushTourStateToAnchors → GeoAnchorManager.NavigationTarget → GeoSpatialProvider → ARNavigationArrowEntity. Map and AR consume the same TourViewModel. Off-route refresh/recovery already exists. Google Maps is a map renderer, not Live View. Optional existing ARCore is a separate public Geospatial adapter, with consent and Core Location fallback; no new dependency is needed.

Root causes:
- visibleCandidate replaces unavailable/out-of-view geospatial points with camera-forward positions. This intentionally produces a local sign, not route registration.
- AnchorState computes yaw from camera-to-sign position; direction is a rotated front-facing icon, not a route-tangent world pose. It pins for five metres but still installs a user-facing orientation at each replacement.
- Core Location reference is rebound to each GPS/camera pair, so coordinate noise changes translation. Its gravity fallback derives north repeatedly from phone heading plus camera forward. Magnetic fallback lacks a declination guarantee; heading freshness is not enforced.
- ARCore worldDirection similarly derives a north offset from camera yaw and pose heading, rather than using the provider's geographic transform basis.
- Route preview stops at one vertex and uses a fixed eight-metre lookahead. Small vertices and corners can prevent sensible placement. Usable localization thresholds are broad GPS-class thresholds, not sufficient for sidewalk-scale geometry.
- Meshes are real reusable closed extrusions, but sharp six-point shapes and hunter-green sides differ from the requested blue beveled design. Projection-size fitting can make each replacement look screen-sized.
- Ground detection excludes tables/seats/ceilings and smooths height, but raycasting can change X/Z away from the route. A plane is not proof of a safe sidewalk.

Working pieces to retain: Google WALK route decoding, projection and maneuvers, rerouting/backoff, Map providers, one GPS source (best accuracy/no distance filter), tour arrival/180-second visit and early progression, sketchbook recognition, fixed-purpose sessions, Back/Close, motion exit, permission flows and reusable RealityKit entities. ARKit renders independently of throttled ten-Hz geospatial updates. Existing 0/360 angle smoothing and ground-height estimation are useful.

## Decision

Choose targeted refactor (Option A) with replacement of the spatial placement pipeline. A whole subsystem rewrite would unnecessarily duplicate functioning route/state/lifecycle and plaque systems. Add deterministic WGS84/ENU alignment, a route-relative preview engine, confidence hysteresis and a world-pose placement state. Retain old helpers until replacement tests pass; production walking must no longer invoke camera-forward fallback or camera-facing pose generation. Use explicit non-spatial/map degradation instead.

No supported public API guarantees Google Live View's proprietary localization. GPS/compass cannot certify sidewalk geometry. Spatial rendering must require tight location/yaw/route confidence, avoid projecting across sharp corners, and hide immediately on unsafe/stale inputs. No outdoor alignment or 60-FPS claim can be made on the Linux execution host.
