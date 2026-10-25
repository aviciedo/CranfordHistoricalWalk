# Active walking map — build 59

## Behavior

The owner selected framing of the user, departure stop and destination. The app's
currentStop is the active destination; nextStop is the subsequent itinerary entry.
The new camera does not skip to nextStop or mark any stop visited. On first appearance
mid-tour it uses the preceding itinerary entry as departure context; after a destination
change it remembers the outgoing destination, including when using Previous stop.
This is tour-leg context, not a claim that the user physically visited the departure site.
New walk-session identity clears stale context. Completed walks retain overview access.

Previously showUserAndDestination switched to free camera mode and required a GPS
fix; late route responses did not refit their geometry. It now enters navigation mode
and frames the destination even before GPS. A full walking-leg request carries its own
coordinates to Google/Apple, including route bends and the valid received GPS position.
A changed route refits in navigation mode; a location update refits only after about
15 m displacement. Manual gestures suspend camera updates, while the dot continues
updating. Route control resumes this mode; location control retains closer user follow.

The existing single location pipeline supplies the blue dot and accuracy circle. Apple
now interpolates between received readings over 0.35 s, matching the existing short
Google animation. Neither provider moves the dot without a fix or snaps it to the path.
If a fix grows stale, the existing location notice remains the source of status; the
last received position is not proof of live tracking. Invalid coordinate/accuracy
samples cannot produce a puck. Poor but valid readings retain their uncertainty circle.

The displayed walking polyline must match the active destination, contain valid
coordinates and come from a non-estimate route. The route layer and camera use the
same geometry. The existing routing accuracy/freshness policy is unchanged: waiting
for a clearer location is not bypassed by drawing a straight line. Offline/provider
failure messages and Retry remain; this change cannot manufacture GPS indoors.

## Verified here

- 87 portable actual-model tests passed (5 new map tests).
- Regression coverage: first destination without GPS; departure/destination framing;
  Previous backtracking; first mid-tour framing; new-walk context reset; late curved
  routes; manual pan ownership and route-control recovery; estimate/invalid/old-route
  suppression; real shared-pipeline GPS dot movement, off-route honesty and jitter gate.
- Debug/Release syntax parsing of app and test sources passed.
- No core routing, arrival thresholds, persistence, audio or visit logic changed.
- Prior core result was 227 tests; it was not rerun for this app-model change.

## Native and field checks not yet run

1. Build in Xcode; start with permission denied, then authorize Precise Location.
   Before a fix, show destination only; once received, show the real dot and uncertainty.
2. Outdoors, walk from a permitted location to stop 1. Check both Google and Apple,
   route bends, control/attribution clearance, dot updates and 15 m camera framing.
3. Advance to stop 2 and confirm mill/departure, user and Greystone/destination fit.
   Use Previous and confirm return-leg framing without changing saved accomplishments.
4. Pan/pinch, keep walking, and confirm the dot moves while the camera stays manual.
   Tap route to resume the active-leg view; location should use the closer follow view.
5. Check route delay, off-route reroute, network failure, stale/weak GPS and Retry.
   No old-destination path or straight-line estimate may appear as walking directions.
6. Check small/large phones, player visible, accessibility text, Return from AR and
   background/resume. Native rendering, map SDK behavior and GPS are unverified here.
