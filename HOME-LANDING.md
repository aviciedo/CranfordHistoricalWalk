# Illustration-led Home — build 60

## Approved direction

The owner selected the illustration-led field-guide reference and confirmed:
- Maps with a map icon above Explore the stops. No embedded Home map.
- Hero matches the active walking destination and changes when that destination
  changes, rather than previewing a later stop on arrival.
- Completion shows Tour complete and Start another walk.

## Implementation

HomeView now uses the existing ivory/forest tokens, 48-point scalable semibold serif
two-line heading, supplied subtitle, original transparent landmark illustrations,
walking CTA, helper and two native icon rows. The three raster assets retain 4:3
proportions; church Canvas is square; hotel Canvas keeps 100:90. No generated mockup
artwork is substituted into production. Header and actions are measured first; the
hero receives the remaining 96–340 points. If content needs more height the screen
scrolls, preserving actual control sizes. Root still reserves the real player and
bottom-navigation height. No font shrinking or truncation is used to force a fit.

Presentation properties homeFeaturedStop and homeWalkActionTitle depend only on
walk phase/destination. Not started features the first stop with Start walk / Begin
at the stop. In progress features currentStop, the active destination, with Continue
walk / Next: name, including paused walks and Previous selections. Completion uses
the original mill welcome image with Tour complete and Start another walk, without
claiming every stop was visited. The restart action reuses existing reset/start,
which preserves saved independent learning/bonus activity.

Maps and Explore the stops change selectedTab only. They never call startTour,
resetTour or prepareForAR; paused walks stay paused. The existing Home location
subscription resumes only an already active, authorized walk. No new location
manager/permission, route, automatic progression, narration or persistence is added.
Developer Controls remain behind the existing developer-build long press on title;
the visible Developer row is removed to keep the selected production layout clean.
Existing HomeMapView and fallback/stylized map source remain for compatibility.

## Verification

90 portable actual-model tests passed. Three new regressions cover welcome without
GPS requests, walking-destination versus browsed story/Previous, and completion/
restart without losing saved learning. Full Debug/Release app/test syntax parsing
and whitespace checks passed. Prior core count is 227 and was not rerun: no core
logic changed. Native visual QA remains blocked in design-qa.md; parsing does not
prove Apple compilation, rendering, gestures, VoiceOver or accessibility compliance.

## Native acceptance pending

1. Build on macOS. Match reference on an iPhone; check 320/375/393/430-point widths,
   portrait/landscape and large/accessibility text. Title, hero, labels and symbols
   must stay aligned and readable; scroll when needed rather than clipping actions.
2. Verify first mill image, Start walk and helper. Maps and Explore the stops open
   the expected tabs without requesting permission or starting a fresh walk.
3. Continue the walk through all five destinations, including Previous. Hero and
   helper must match the Map destination; browsing another story or playing audio
   must not retarget the hero. Check both original raster and Canvas proportions.
4. Show/close the player and verify actions remain reachable and the hero contracts.
   Returning Home preserves current audio and navigation state.
5. Relaunch a paused walk: Continue walk/active destination, no autoplay or automatic
   walking resumption. Maps browse must keep the paused state.
6. Finish with and without skipped stops: Tour complete appears without invented
   visit credit. Start another walk returns to mill without erasing saved stories/bonuses.
7. Check loading/failure/retry, VoiceOver names/order, 56-point browse rows, and the
   retained developer title long-press. No new Home map/zoom controls should appear.
