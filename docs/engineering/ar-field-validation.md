# Cranford AR field acceptance — candidate 116

Status: **not performed in this cloud environment**. Automated tests validate math,
state and configuration, not outdoor recognition or sidewalk accuracy. Use a physical
supported iPhone and the actual plaques at public viewing positions. Keep build 115
available as the rollback baseline.

## Record each session

Record device/iOS/build, time/light, network, precise-location permission, route provider,
GPS/heading accuracy, whether the ground was classified, recognition latency and outcome.
Record 10 recognition attempts per target/lighting condition, including failures. Take an
Instruments trace separately for frame rate, memory and energy; do not infer 60 FPS from
smooth-looking Simulator tests. Capture actual problems before relaxing confidence limits.
The Debug build's Home-title long press opens Developer Controls → Walking progression;
its bounded export explains tour holds without including coordinates.

## Walking navigation

| Scenario | Procedure | Required result |
|---|---|---|
| Start/resume | Start the Mill leg from Home/Map; enter AR after the provider returns a walking route | Same destination/route in Map and AR; three substantial white/green chevrons when alignment is credible |
| Stationary perspective | Stand still, rotate the phone 180°, then return to the original view | Objects remain at their world location/orientation; they may leave the field of view, but never follow the screen |
| Straight walking | Walk toward the first group, then pass its location | Natural perspective/size change, followed by new forward placement; no stale group underfoot/behind after passing |
| Right/left turns | Follow both kinds of real maneuver in provider geometry | Upcoming cue stays synchronized; near sharp corners use the card/map while no safe preview exists; old direction hides while the next leg settles |
| Curved street | Walk a gentle curve/dense polyline | Forward geometry stays on the route; no destination-bearing shortcut through a bend |
| GPS/compass uncertainty | Test reduced location accuracy and naturally poor heading, then restore precise/reliable readings | Spatial arrows hide promptly; compact map/directional fallback remains; reacquisition is delayed rather than flickering |
| Off-route | Take a short different public path and allow rerouting | Wrong-route spatial guidance hides; only an actual new walking route restores it; no invented line into a building |
| Network loss | Interrupt connectivity while walking, then reconnect | Existing honest cached/map behavior continues; an estimated route never creates precise-looking spatial arrows |
| Phone down | Raise phone first, then hold it face-up horizontally for two seconds | Exit to Map once; destination, saved activities and walked trail survive |
| Background/interruption | App switcher, lock/unlock, camera interruption, foreground | Camera pauses appropriately; no confident arrows during loss; ordinary recovery preserves origin and reacquires confidence |
| Inactive first entry | Open AR around a permission/cover transition, then foreground it | Initial provider/world anchors attach correctly; it cannot become a permanently unaligned “resumed” session |
| Arrival/progression | On Map, remain reliably near Mill for three minutes; separately exercise narration, plaque and departure bypasses | Existing rules advance Mill → Greystone exactly once after presentation holds release; AR cannot become a second progression owner |

Route polylines, GPS and planes do not establish a sidewalk's safety or exact curb position.
An unclassified horizontal surface is approximate height evidence; only classified floor
raycasts earn the ground-verification flag. Neither means a road crossing has been verified.
If coordinates/route alignment are questionable, record the map and suppress spatial guidance.

## Plaque recognition and anchored content

Run the following at **both** the Mill plaque and the Cranford Park/Greystone plaque.
The Mill asset width is currently estimated at 0.18 m; the Park reference (including its
surrounding stone crop) is estimated at 0.75 m. Measure the entire reference-image area
before replacing either value. Update asset and catalog widths together; a consistency
unit test is not evidence that either estimate equals the actual site.

1. Enter from stop details with no active walk and with GPS unavailable/denied. Camera
   permission and reference-image recognition must work independently of arrival/routing.
2. Frame the correct target. The header should change from Frame this plaque to Hold steady.
   A fresh, stable half-second lock with distinct frames may qualify; initial target search
   can take longer. Do not award on one transient callback or a stale cached frame.
3. First discovery: confirm the saved sketch, correct site name, existing celebration and
   automatic opening of that site's sketchbook page. Closing early must not lose the award.
   This preserves the current automatic flow; it is separate from inspecting a returning AR card.
4. Re-enter for an already unlocked plaque. No new celebration/award should occur. The
   historical card should attach above the correct image, with no GPS substitute. Move the
   phone sideways/up/down and view it obliquely: its perspective changes while it stays on
   the plaque. Verify out-of-wall/front orientation, scale and approximately 0.25 m upward offset.
5. Close the card using its close control. It stays hidden while that same lock continues.
   Look away and reframe (or Retry): it can reopen after fresh qualification, without another award.
6. Lose target tracking, cover the camera briefly, then reacquire. The spatial card hides
   when evidence is lost; the saved sketch remains. A different/new anchor ID cannot reuse
   the previous target's confirmation time or scene binding.
7. Try roughly frontal, 30° and 60° views; multiple comfortable distances; shade, sunlight
   and glare; partial occlusion of about 25% and 50%. Record detection time, rejection and
   stability. Do not treat these suggested angles as guaranteed operating specifications.
8. Point at unrelated plaques, text, buildings and similar colors. Test while standing
   inside the GPS arrival radius too: none may unlock a sketch without the configured visual match.
9. Test a photograph/screen copy separately and record the limitation: ordinary reference-image
   tracking can recognize a copy. This implementation does not establish physical-site authenticity.
10. If scanning switches between the two configured references, verify the card/site follows
    the recognized image while the walking itinerary keeps its independent destination.
11. Background while searching, confirming and after unlock; then foreground. Clear pending
    evidence, preserve awards, require fresh tracking and avoid unnecessary origin resets.
12. Exit during confirmation and re-enter repeatedly. Late callbacks must not award after
    exit. Retry clears camera evidence, not visits/sketches/audio or the walking destination.
13. Deny/restrict camera permission, test unsupported hardware and missing references in a
    development catalog. Show recovery/unavailability; stories and Map remain usable. Never
    fall back from missing visual proof to GPS-based plaque success.

## Optional localization investigation

The existing ARCore provider needs its existing consent/configuration and actual supported
VPS coverage. Record availability and resulting localization quality at the viewing position;
do not infer coverage from the presence of Google Maps street imagery.

Before any future Apple geotracking integration, a developer should perform the supported
runtime availability probe on the actual iPhone at each public viewing coordinate:

```swift
guard ARGeoTrackingConfiguration.isSupported else { return }
ARGeoTrackingConfiguration.checkAvailability(at: coordinate) { available, error in
    // Record availability/error without publishing credentials or personal location history.
}
```

This diagnostic is not enabled as an application provider in candidate 116. An available
region still needs successful localization and appropriate permissions/network. A surveyed
visual anchor's geographic bearing/position would also be required before using a plaque
to calibrate street navigation; its image dimensions alone cannot establish north.

## Acceptance and release record

For each scenario record pass/fail, evidence, reproducibility and remaining uncertainty.
Block shipment on false visual awards, persistent misleading arrows, card/anchor mismatch,
crashes, broken Map return or lost history. Keep failures associated with the exact build
and sensor conditions. Outdoor alignment, measured recognition rate and Instruments results
remain pending until this checklist is executed; do not describe automated tests as field acceptance.
