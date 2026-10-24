# Field acceptance — review build 46

Status: NOT EXECUTED ON SITE. Linux unit tests do not verify iPhone GPS, street
safety, compass alignment, camera recognition, real plaque dimensions or battery use.
Do not mark this checklist passed until a tester records the evidence below.

Install the complete review ZIP on a real iPhone using Xcode. Confirm build 46 in
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
   Check the inside/outside boundaries without expecting uncertain fixes to count.
2. Verify “You’re here” and one saved physical visit. Arrival must NOT change the
   destination, complete a story, unlock a bonus, or start audio.
3. Tap Continue ONCE: next stop and route endpoint change together. Stop 1 must
   become Greystone. Capture the entire sequence if it stays at the mill.
4. Skip before arriving: destination changes, skipped stop receives no visit credit.
5. Play mill narration while walking to Greystone. Open/close details, photos and
   AR; neither playback identity nor walking destination may be changed by browsing.
6. Deny camera/location separately; browsing must work. Test reduced accuracy,
   stale/weak GPS, lost connectivity, and recovery while stationary. Expect at most
   five automatic routing retries; Retry directions renews the budget explicitly.
7. In AR, wait for normal tracking and ground detection. Inspect upright chevrons,
   route alignment and GPS approximation labels. GPS-only fallback is approximate.
8. Match each supported physical plaque in good and poor light, from oblique angles,
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
13. Run a 20-minute walk with Instruments Energy/Memory and record observed thermal,
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
