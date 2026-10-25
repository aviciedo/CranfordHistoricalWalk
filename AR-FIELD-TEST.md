# Field acceptance — review build 53

Status: NOT EXECUTED ON SITE. Linux unit tests do not verify iPhone GPS, street
safety, compass alignment, camera recognition, real plaque dimensions or battery use.
Do not mark this checklist passed until a tester records the evidence below.

Install the complete review ZIP on a real iPhone using Xcode. Confirm build 53 in
Developer and narration release cedar-2. Keep Simulated location OFF. Use the full
“Clear visits, stories & bonuses” test reset only when you want a clean activity run;
ordinary visit-only reset intentionally retains reading/listening/bonus progress.

Current approximate reference points (not surveyed or certified public entrances):

| Stop | Latitude | Longitude | Plaque width metadata |
|---|---:|---:|---|
| Droescher’s Mill | 40.650249 | -74.301047 | 0.18 m, measure on site |
| Greystone | 40.6524 | -74.2990 | 0.75 m full-frame testing estimate |
| Rahway River | 40.6659731 | -74.3108614 | No image reference |
| First Baptist Church | 40.653165 | -74.302768 | No image reference |
| Cranford Hotel | 40.65513 | -74.304765 | No image reference |

Stand only in permitted pedestrian areas. Do not follow an AR arrow into a roadway
or private property. Coordinates and ground-plane detection do not establish safe access.
Record proposed coordinate/scale changes; do not silently change production data.

For EVERY stop, record: build/commit, device/iOS, time, provider (Google/Apple),
permission/Precise Location settings, actual public viewing point, GPS fix age and
accuracy, distance to stop, destination before/after, result, and screenshot/video.
No keys, unrelated bystanders, or raw continuous location trail are needed.

1. Arrive from outside the 50 m departure boundary. A real GPS visit needs a fix
   younger than 30 seconds, accuracy <=25 m, and distance + accuracy <=35 m.
   Current-destination arrival additionally needs two distinct fixes spanning >=3 s.
   Check boundaries without expecting uncertain or repeated cached fixes to count.
2. Verify “You’re here” and one saved physical visit. Arrival must NOT complete a
   story, unlock a bonus or start audio. Hold the current destination for exploring.
   The last verified arrival may finish the itinerary on foreground Map only.
3. Without tapping Continue, leave the current site with foreground Map visible.
   Distance minus accuracy must stay outside the departure boundary (at least 50 m)
   over distinct fresh fixes spanning >=5 s. Mill must become Greystone once.
   Undo must return to Mill and latch Stay here; relaunch/Resume preserves the hold.
   Release it or use Continue now. A single fix must never advance several sites.
   Repeat while in details, photos, AR, Home and background: no automatic retargeting;
   new fixes after returning to Map must reestablish departure dwell.
   Also tap Continue ONCE to verify the manual alternative and route endpoint.
4. Skip before arriving: destination changes, skipped stop receives no visit credit.
5. Play mill narration while walking to Greystone. Open/close details, photos and
   AR; neither playback identity nor walking destination may be changed by browsing.
6. Deny camera/location separately; browsing must work. Test reduced accuracy,
   stale/weak GPS, lost connectivity, and recovery while stationary. Expect at most
   five automatic routing retries; Retry directions renews the budget explicitly.
7. Enter AR: scanning starts without Start exploring. Confirm the ground coach and
   gray scrim disappear after ground detection, with Back/Home/Retry unobscured.
   Wait for normal tracking and ground detection. Inspect upright chevrons,
   route alignment and GPS approximation labels. GPS-only fallback is approximate.
8. Verify the scanner shows the correct real target thumbnail and actual phase.
   After 12 seconds without recognition, help, Retry and Return to story must work.
   Match each supported physical plaque in good and poor light, from oblique angles,
   then lose tracking. GPS and story completion must never claim plaque recognition.
   Measure plaque/reference widths and capture calibration ratios before proposing changes.
9. Raise the phone, then hold screen-up/level continuously for two seconds: return
   to the presenting screen. Opening already flat must not immediately close AR.
   A modal, background interruption or gap in motion samples must break the hold.
10. Test call/interruption, camera retry, app background/foreground, and repeated
    entry/exit. No duplicate camera session, narration, visit or unlocked-bonus event.
11. Kill/relaunch: walking resumes paused with its destination; narration resumes only
    after Play. Restart a walk from elsewhere and check the new summary starting leg.
12. Inspect small-phone/large-text/VoiceOver/Reduce Motion layouts, Map/Stops header
    alignment, destination actions with the player visible, and full uncropped photos.
13. At the final stop, confirm automatic finish, truthful skipped-site rows and Undo.
    Map stays available and ongoing audio does not stop. Relaunch remains truthful.
14. Run a 20-minute walk with Instruments Energy/Memory and record observed thermal,
    CPU, frame-rate and battery behavior. No performance threshold is declared passed here.

Acceptance record per case: NOT RUN / PASS / FAIL, tester, evidence file, expected
versus actual behavior, reproduction steps. Confirm Google and Apple separately.

Mill/Greystone bonus acceptance:
- Recognize only the matching supported plaque. Weak tracking, GPS arrival and story
  playback must not unlock its bonus. Test a printed or screen-displayed reproduction
  and record recognition: image tracking alone does not authenticate real-site presence
  and must not be described as spoof-proof.
- At the mill, record right/up/width/height calibration ratios and verify the bonus
  covers both intended panes, stays on the facade when looking away, and responds
  correctly to its close/open controls. Do not claim independent window recognition.
- Move farther than 12 m or interrupt AR: the live on-site extra must become
  inaccessible. Re-entering AR must re-establish its physical pose from the plaque;
  a saved accomplishment is not a fresh world anchor. Saved story/bonus previews
  may remain available independently, as intended by the app.

Build 49 — fixed chunky street signs (NOT RUN on device):
- Stand still for 30 seconds with a reliable route and detected ground. Rotate/tilt
  the phone and move it at arm's length: arrows must not billboard, spin or drift
  with GPS updates. Turning away should take the sign out of the camera view.
- Inspect three deep, hunter-green chevrons with white faces. The routed street name
  must appear only in the bottom direction card, with no floating 3D text. Left/right must match the bottom turn instruction;
  straight/diagonal/U-turn states must remain upright and above detected ground.
- Walk less than five metres: position/yaw/direction remain fixed. Walk roughly five
  metres from the last placement: one new placement appears ahead, then holds again.
  Confirm the jump is understandable; tune only from recorded field evidence.
- At a real route instruction change, allow 1.5 seconds of stable updates before
  replacing the sign. GPS/route-boundary flutter must not repeatedly flip it.
- Temporarily lose ground/tracking and recover while stationary: same-session
  recovery should reuse the pin. A new AR session, interruption, provider switch,
  or destination legitimately creates a fresh pose.
- Check daylight, long street names, both Google/Apple route cues, unknown street
  names, estimated routes, Reduce Motion and return-to-Map. A straight-line estimate
  must never become a street claim. The bottom accessible direction card remains.
- ARKit relocalization drift is a separate device-level limit. A detected plane is
  not proof of a street, pedestrian access, or survey-grade GPS placement.

Build 53 — Previous stop (NOT RUN on device):
- While guiding to stop 4, tap Previous stop: destination/route become stop 3, even
  if it was skipped. Backtrack repeatedly to stop 1; no further Previous control.
- Keep Mill narration playing while walking to another stop, then tap Previous:
  narration identity and position continue. Visits, stories and bonuses remain saved.
- Arrive/leave the manually selected previous stop: it must stay selected until
  Continue now or explicit release of Stay here. No immediate automatic bounce forward.
- Relaunch: selected destination and hold survive; Resume is still explicit. Changing
  Previous on a restored paused walk must not request location permission or resume GPS.
- Check distance/time when returning to an already visited place. Verify both action
  rows and player fit the Map layout on small phones and at large Dynamic Type sizes.
