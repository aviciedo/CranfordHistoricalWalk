# AR walking arrow investigation — 2026-11-01

## Findings and repair

The screenshots correspond exactly to `ARSpatialConfidence` rejecting GPS quality
(`location`) and distance from the route (`offRoute`). This identifies code paths,
not the exact sensor values on that iPhone; the screenshots do not contain them.

Street-registered arrows require GPS accuracy ≤5 m to acquire (≤8 m to retain),
route offset ≤3 m (≤5 m to retain), yaw accuracy ≤10° (≤15° to retain), fresh
sensor data, normal tracking, usable geographic alignment, a 3–16 m projected
preview and two continuous seconds of acceptable input. A sidewalk can be more
than 3 m from a routing polyline. These combined requirements can plausibly prevent
acquisition throughout a walk. Relaxing them silently would create false precision.

**Verified implementation defect:** `CoreLocationGeoSpatialProvider` discarded a
GPS sample when camera-position history did not yet cover its timestamp. A later
AR frame did not retry it, and replaying the same GPS coordinate/timestamp was
intentionally ignored. The provider now retains the unmatched sample and retries
against capture-time history until matched, superseded or stale. It never substitutes
an unrelated current camera pose or repeatedly binds an already matched sample.

**Verified product behavior gap:** every confidence rejection hid the 3D artwork;
there was no usable intermediate experience. Walking now has two explicit outputs:

- Street-aligned arrows retain the existing strict confidence policy, route-derived
  orientation, ground refinement and pinned world pose.
- A labelled **maneuver preview** uses the same chunky RealityKit geometry when
  GPS is fresh (≤5 s), accuracy ≤20 m, route offset ≤15 m, tracking is normal and
  an actual route instruction exists. It is an informational virtual sign in front
  of the camera, not a verified street position. It needs neither compass precision
  nor detected ground. It can relocate when out of view and is labelled accordingly.

The preview may show an upcoming turn before reaching it; distance and street remain
in the card. It must not be interpreted as “turn at this virtual object.” Poorer
signals, no route instruction, stale GPS and tracking failures hide it. Street mode
and maneuver mode reset their incompatible anchor state when switching. Placement
status is refreshed on every frame so hidden content is not reported as placed.

Sensor-quality transition logs use subsystem `com.cranford.walk`, category `ARWalking`.
They report GPS accuracy, route offset, yaw accuracy and preview availability, without
coordinates, images or persistent location history. Use Xcode's console or macOS Console
with the connected iPhone to capture the gate transitions during a failed attempt.

## Source-based technology assessment

Inspected source checkouts, not popularity metrics. All three projects use MIT licenses;
copying source would require retaining the notices. No source was copied or dependency added.

| Candidate / inspected commit | Actual role | Recommendation |
| --- | --- | --- |
| [ARKit-CoreLocation](https://github.com/AndrewHartAR/ARKit-CoreLocation/tree/c74634de4313183e281b323941a5d51fcd165533) | SceneKit geographic nodes; GPS/AR estimates. `readme.md` True North Calibration explicitly describes compass error; `Sources/ARKit-CoreLocation/Location Manager/SceneLocationManager.swift` estimates locations. | Useful reference for bounded location estimates, not a cure for compass/GPS uncertainty. Do not replace RealityKit or add another location manager. Latest checkout commit is a 2025-12-30 author-credit edit, not evidence of a modern positioning upgrade. |
| [SCNPath](https://github.com/maxxfrazer/ARKit-SCNPath/tree/a1862431cdfd31d780f602483cf39746deaa5068) | `Sources/SCNPath/SCNGeometry+Extensions.swift` builds geometry from supplied 3D points. README explicitly lists SceneKit support and no RealityKit support. | Does not locate the route or fix alignment. Keep the existing tested native mesh. Checkout head dated 2020-01-27; do not introduce this dependency for the failure. |
| [Mirador](https://github.com/AndrewHartAR/Mirador/tree/87e0a6a6bcfd08654de3840348d595148e6e916e) | `Sources/Mirador/MiradorView.swift` constructs ARReferenceImage targets and handles ARImageAnchor detections. Anchor setup requires known size, geographic position and bearing. | Useful visual-calibration reference near a surveyed plaque, not continuous visual positioning along an arbitrary street. Latest checkout commit is a 2025-12-30 README edit. Preserve the app's separate plaque system. |
| Native ARKit / RealityKit + existing Google Maps routes | Already supplies mesh rendering, camera tracking, detected surfaces and actual walking geometry. GPS/compass alignment is approximate. | Selected for incremental repair. No proprietary Live View equivalence is claimed. |
| Existing ARCore Geospatial integration | Current provider already supports GARSession and checks VPS availability with `checkVPSAvailability`. Requires configuration, consent, supported device, network and usable localization. | Best next experiment for true geographic alignment. Check availability **at the actual Cranford test locations** before enabling or investing further. Coverage and sidewalk accuracy are not verified by this investigation. |

Apple geographic tracking is another coverage-dependent option, not a guaranteed fallback.
Check `ARGeoTrackingConfiguration.isSupported` and `checkAvailability(at:completionHandler:)`
on a supported iPhone outdoors before selecting it. Apple/Google documentation endpoints
were blocked (403) in this environment; no claim of locally verified geographic coverage
or current documentation review is made. Source inspection above succeeded.

## Tools worth using

1. **Xcode Instruments + ARKit recording/replay:** highest immediate value. Capture
   a consenting physical-device test, replay tracking conditions where supported,
   inspect rendering/energy with Instruments, and correlate sensor gate logs. A replay
   does not automatically replay the app's Core Location stream; inject a separately
   captured test fixture when reproducing sensor synchronization.
2. **XCTest + existing SwiftLint:** retain the new ordering, quality-gate and mode-switch
   regressions. No additional test framework is needed to debug these decisions.
3. **ARCore Geospatial sample app:** compare the official
   [geospatial sample](https://github.com/google-ar/arcore-ios-sdk/tree/master/Examples/GeospatialExample)
   on the same phone/location before changing app configuration. This is a proposed
   experiment, not a sample executed here.
4. **Codex Security plugin:** optional later security review of camera/location handling;
   it cannot diagnose physical AR registration. No plugin installation is needed for
   this fix, and a design plugin would not address the sensor rejection paths.

Inspecting open-source implementations and public SDK interfaces is useful. Reverse
engineering Google's proprietary Live View service is unnecessary and would not provide
its visual-positioning infrastructure or coverage.

## Validation and field acceptance

Automated regressions cover ordinary 9 m GPS / 8 m route offset yielding a maneuver
preview, rejection of stale/invalid/severely inaccurate/off-route inputs, GPS arriving
before its matching AR frame, recovery into strict spatial mode, tracking loss and
removal of navigation. Existing spatial placement, compass/world transforms, corners,
GPS jumps and plaque/progression tests remain required. See the task completion report
for actual run results; tests cannot establish outdoor accuracy.

Physical iPhone checklist (Precise Location on, camera permitted):

1. Start a real walk outside, confirm Google Maps has a walking route, open AR. Record
   installed build, phone/iOS and sensor-quality console transitions.
2. With GPS accuracy 6–20 m or offset 4–15 m, confirm a large white/green extruded
   maneuver preview appears once normal tracking is established. Verify its explicit
   non-street-aligned label and that the displayed street/distance match the map.
3. Rotate 90°/180°, walk 5–10 m, tilt toward the ground. The maneuver preview should
   remain readable, never become an unlabeled street-position claim, and stay clear
   of the bottom card. Verify portrait directions fit within the camera view.
4. Under good GPS/heading/offset, hold alignment for ≥2 s. Confirm transition to a
   route-oriented world arrow without an old maneuver pose flashing. Rotate the phone:
   a street arrow must remain pinned rather than follow the camera.
5. Approach both left/right turns, cross dense polyline vertices, and continue to the
   next stop. No diagonal shortcut or stale turn should appear. Compare with map.
6. Background/foreground, lock/unlock and re-enter AR. Tracking loss must hide arrows;
   reacquisition must recover. Poor GPS (>20 m), substantial route offset (>15 m),
   stale fixes or missing routes must retain map fallback instead of invented arrows.
7. Test Mill and Greystone plaque discovery separately; verify sketch unlock, phone-down
   exit, visit persistence and automatic next-stop behavior remain intact.

Keep street positioning marked unverified until this checklist succeeds outdoors.
If genuine alignment still never acquires, use the new logs to decide between a
calibration repair and a coverage-verified visual-positioning experiment.
