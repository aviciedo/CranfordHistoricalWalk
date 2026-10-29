# Build 101 — physical iPhone field test

Status: NOT EXECUTED. Portable tests and Swift parsing do not validate outdoor alignment or frame rate.

## Setup

1. On a Mac, open CranfordHistoricalAR.xcodeproj. Build Debug, run the host-app test target on an available iPhone simulator, then build Release for a physical iPhone. Existing ignored local API configuration is required for Google services; do not add credentials to source control.
2. Install on an ARKit-capable iPhone. Enable camera permission, When In Use location, Precise Location and compass/location services. Start with GPS/compass; repeat with existing consented ARCore/VPS configuration if supported and available.
3. Begin with Droescher’s Mill → Greystone using the app’s current walking route. Later legs cover Rahway River, First Baptist Church and Cranford Hotel. Use the current catalog route, not assumptions about street or crossing access. Conduct viewing tests from the sidewalk; never step into a road to match an arrow.
4. Record device/iOS/build, provider, approximate conditions and a screen recording. Note whether the small alignment message is present. Confirm blue sides/white faces and no plaque controls in walking AR.

## Scenarios and expected results

| Scenario | Procedure | Expected result |
|---|---|---|
| Straight street | Acquire alignment, stand still for 30 seconds, then walk 10–20 m on the mapped pedestrian path. | Three substantial 3D chevrons remain pinned, grow with approach, then a new group appears ahead. No continual screen-size compensation or camera-facing rotation. No stale-heading drop merely because the phone is still. |
| Right turn | Approach a right turn on the real walking route. | Card shows matching street/distance. World arrows stay on the approach segment; nearby turn is anticipated. No diagonal shortcut into the road. Spatial arrows may hide close to a sharp corner and explicitly defer to Map. |
| Left turn | Repeat at a left turn on a later walking leg. | Same behavior with left maneuver. Sign plane follows the geographic segment, not the phone. |
| Standing rotation | Once aligned, stay at the same location and rotate phone 180°, then back. | The world object does not follow the screen. It leaves view and reappears at the same physical location; depth perspective changes naturally. |
| Passing maneuver | Walk through the turn using the actual pedestrian crossing/path. | Active segment and card update together; new signs align with the outgoing segment after settling. No jumping to another loop at a route crossing. |
| Poor GPS | In a suitable stationary test, turn Precise Location off and back on; repeat where satellite reception is naturally weak. | No confidently placed 3D arrows with weak location. Map/instruction card remain accessible; reacquisition requires stable confidence. |
| Poor heading startup | Enter AR with a phone case/accessory causing interference, then remove interference and scan slowly. | Explicit alignment/map mode, no camera-forward substitute. Fresh true heading and stable tracking are required before spatial arrows appear. |
| Off route | Take a legitimate nearby sidewalk away from the planned path. | Spatial alignment degrades before misleading placement. The shared existing route provider reroutes according to its normal policy. AR and Map use the same resulting route/destination. |
| Tracking interruption | Briefly obscure camera; background/foreground app; lock/unlock; return from a system interruption. | Arrows hide immediately while tracking is untrusted, session does not repeatedly reset, then confidence reacquires. If relocalization fails, exit/re-enter or use explicit Retry; no stale anchor presented as certain. |
| Exit controls | Use Back, Close and the established phone-horizontal gesture (upright first, then lower phone). | Return to Map with the same walk, destination, progress and narration; no stuck camera or extra session. Re-entry uses one AR session. |
| Arrival and progression | At the Mill, confirm no automatic visit before 180 seconds of reliable near-stop time. Separately test plaque recognition, narration completion and leaving toward Greystone before 180 seconds. | Build 100 rules remain: timer or agreed early trigger advances, Home/Map show next stop consistently. Wrong-way departure does not advance; Stop walk remains paused. |
| Plaque isolation | Open the dedicated plaque scanner at Mill and Greystone. | Physical recognition still saves the sketch and opens the sketchbook flow. Walking AR never begins plaque scanning or shows bonus placeholders. |
| Permissions/network | Deny camera/location separately, toggle Precise Location, and test lost routing connectivity. | Existing permission explanations and Map controls work. Cached valid route may remain; an estimate or stale fix never becomes spatial geometry. |
| Performance | Use Xcode Instruments/RealityKit metrics during a 10-minute walk on the oldest supported test iPhone. | Record actual frame time, thermal state, allocations and power. Mesh/entities are reused; no growing scene graph or reset loop. Aim for 60 FPS, but do not mark this passed without measurements. |

## Acceptance and release gate

Record pass/fail and recordings for each row, especially stationary rotation, corners, weak GPS and background recovery. Fail spatial alignment if the sign drifts with phone rotation, jumps across streets, appears on an unrelated surface or remains visible during uncertain localization. Tighten thresholds or keep Map fallback where it fails. Reported GPS accuracy and a detected plane do not prove a sidewalk is safe or traversable. Release confidence requires native compilation, native test execution and this physical walk; these checks have not been completed by the Linux implementation host.
