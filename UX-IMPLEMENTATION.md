# UX implementation — review build 47

Scope: items **1–7, 9 and 10** from the UX review's **Essential improvements** table.
Item 8 (new visit haptic/VoiceOver event announcements) is intentionally excluded.
The numbered journey and concept screens in that review are not separate work lists.

| Item | Result | Verification / remaining check |
|---|---|---|
| 1 · Next manoeuvre | Map uses the same real route cue and hunter-green instruction component as AR. Estimated straight lines never become street instructions. | Existing route-cue regressions and actual-model routing tests; native/outdoor legibility pending. |
| 2 · Automatic journey | Repeated accurate GPS confirms arrival without retargeting. Confirmed departure on foreground Map advances once. Stay here, Continue now and Undo remain explicit. Place status is separate from Listened/Read/Bonus found. | New policy and model tests, including the actual location-event pipeline from Mill to Greystone. Outdoor thresholds pending. |
| 3 · Contextual AR coach | Ground-finding instructions automatically appear over a gray scrim while the walking session scans. No Start exploring gate. Plaque scanning shows the exact bundled target photograph. | Source/syntax/asset checks. Camera behavior and novice comprehension pending on iPhone. |
| 4 · Scan recovery | Real session phases: Camera starting, Looking for plaque, Plaque found, unavailable/stopped. Timed help suggests framing/light/glare changes; Retry and Return to story remain accessible. | Source/syntax checks; live tracking, denial and recovery pending. No invented progress percentages. |
| 5 · Honest story availability | Stops list discloses missing narration before entry. Detail shows available history/photos and a clear pending state. Approved media remains unchanged. | Catalog/media unchanged. Stops 3–5 still need creator-approved full stories/audio; no invented scripts or speech fallback. |
| 6 · Protected content | Actual shared player remains a reserved layout sibling. Destination is measured before map height; compact map floor reduces to 120 pt, horizontal map controls retained. Long/large-text content can scroll. AR/scanner have overflow alternatives. | Portable layout-policy tests pass. Native small-phone/Dynamic Type pixel/layout checks remain pending. |
| 7 · Story first | Prominent fitted gallery, title, default Listen/Read and narration action precede secondary description/date/address/map link. One shared footer remains. | Source/syntax checks; native reachability with player pending. |
| 9 · Predictable exits | Shared Back/Home geometry retained. X announces Return Home and clarifies that the walk and playing narration continue. AR and photos stay free of a player overlay. | Existing navigation-model regressions pass; native dismissal/focus pending. |
| 10 · Truthful finish | Stable final arrival on Map finishes the itinerary automatically, with Undo. Summary says Walk finished and explicitly distinguishes places visited on this walk from places not visited. Map and independent playback survive. | New skipped-site/final-arrival/Undo model regressions; native summary/audio tests pending. |

## Progression contract

- Current-destination GPS arrival: two distinct, eligible fixes spanning at least **3 seconds**; reported accuracy <=25 m, age <30 s, distance + uncertainty within the stop's arrival boundary. Single/repeated cached fixes do not count.
- Non-current physical-site recording retains its existing independent GPS behavior; visiting another site never advances this itinerary. Recognized matching plaques retain independent physical-visit evidence.
- Departure: after confirmed arrival, distance minus uncertainty outside **at least 50 m** (or the catalog's larger effective departure boundary), with distinct fixes spanning **5 seconds**. Gaps over 10 seconds, weak fixes, reentry and presentation/background interruption break the dwell.
- Only active foreground Map without an exploration/AR hold can change the destination automatically. Returning from a held context requires new fixes; no camera, sheet or story is opened automatically.
- Narration is never changed, stopped or started by arrival, departure, Undo or completion. A native media regression was added for automatic Mill → Greystone progression while Mill audio plays.
- Undo returns to the previous destination and latches Stay here without deleting visits, stories, bonuses or playback. Stay here persists across relaunch; restored walks remain paused until Resume. Continue now overrides it.
- Each destination change creates a fresh policy. The fix causing that change is never recursively fed to the next policy. No one-fix cascade through nearby sites.
- Final arrival can finish only when Map is active, no context is held and Stay here is off. Returning from a sheet with the same cached fix cannot finish the walk. Skips receive no visit/story/bonus credit.
- These dwell/boundary values are conservative initial implementation values, **not field-validated settings**. Validate pedestrian viewing points and both providers before release.

## Quality review

The implementation was checked against each requested item above. Review corrections included:
1. Cached final-stop fixes could have finished on presentation dismissal; require a newly accepted fix.
2. Stay here now persists and survives final-stop reacquisition after relaunch.
3. Moving-on copy/Undo shares the active destination card instead of adding a tall duplicate banner.
4. Ground coaching lives in normal HUD flow so it cannot cover Back, Home or a tracking-error Retry.
5. Nested exploration tokens prevent dismissing a nested view from releasing its parent's hold.
6. Undo retains visits and walking distance accumulated after the transition instead of rolling back the full progress snapshot.
7. Plaque recognition alone cannot arm GPS departure: an inaccurate catalog geocode must not look like leaving while the visitor is still at the plaque. Continue now remains available.

Portable verification: **214 TourCore tests + 66 actual application-model tests passed**, including 8 new policy and 9 new model regressions. Debug and Release Swift syntax parsing passed. Both target-preview assets are byte-identical to their AR reference images. Project build number is 47 in XcodeGen and the tracked Xcode project.

**Not verified here:** native Apple SDK type checking/build, simulator UI/audio tests, current-screen screenshots, VoiceOver navigation, outdoor GPS/AR, battery and daylight visibility. Linux cannot run the native app. The new AVFoundation regression is added to host-app tests but is not included in the portable test count. Existing Apple CI is configured to build/test; no new CI result is claimed.

Use `AR-FIELD-TEST.md` for on-device acceptance before distributing this build. No branch was merged/deleted and no production publication was performed as part of this implementation task.
