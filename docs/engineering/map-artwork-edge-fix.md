# Map artwork edge fix — build 133

The owner's 5.39-second recording from November 7, 2026 shows a regional Google map
with nearly coincident stop pins. As the map pans, artwork disappears as a group while
number pins remain visible. It returns in different arrangements after short pauses.

## Causes and fixes

1. Build 132 calculated artwork visibility from the pin's presence inside the inset
   viewport. When the clustered pins crossed its lower edge, all five callouts were hidden
   even though their illustrations were still inside the map. Visibility now follows each
   illustration's rectangle; the overlay clips to exactly the same viewport.
2. The idle solver rejected retained artwork that partly crossed an edge and tried to fit
   it back inside. Retained slots may now clip naturally. A pan ending at an edge does not
   pull artwork back into the map or change its association with its geographic pin.
3. Crowded fallback layouts could try another arrangement on every idle/model update.
   Unchanged settled inputs, allowing half a point of projection jitter, retain the exact
   arrangement. Actual collisions after geometry/control/active-stop changes can still be
   resolved locally after the existing 200ms settling period.
4. Badge cutouts are limited to the artwork clip and protect on-map number pins even when
   their own illustration is offscreen. Nonfinite projection values cannot set UIView frames.

Active/inactive artwork remains 96/64pt wide and number badges remain 32/26pt with 44pt tap
targets. Geographic coordinates, tour progress, artwork assets, GPS policy and manual camera
ownership are unchanged. The shared layout/renderer fix applies to Apple and Google maps.

## Validation

Regression cases cover each viewport edge, a regional cluster crossing the lower inset,
repeat idle updates in a small crowded viewport, and a native overlay mask with an edge pin.
The four new layout regression cases fail against Build 132. Core/model suites run locally;
the exact validation commit must also pass Apple compiler/native tests and SwiftLint.

On-device follow-up: replay the supplied pans, including short pauses at each map edge,
with the weak-GPS banner visible, then repeat at walking zoom and on the Apple fallback.
Illustrations should leave/re-enter individually as their footprints cross the clip. They
must not blank together at the pin boundary or shuffle after an unchanged idle callback.
CI cannot establish real-device frame rate or physical gesture fidelity.

Validation only: do not promote main, release aliases or tags without publication approval.
