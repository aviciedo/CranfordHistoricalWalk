# Simplified Map — build 61

The owner selected concept direction 1, with the one green turn card moved under the
Map title, above cartography. The reference is a design concept, not a geographically
valid street map. This native implementation preserves Google Maps/MapKit, real GPS,
walking routes, provider attribution and the approved active-leg framing.

## Page hierarchy and states

ScreenPageHeader remains shared with Stops. DestinationFirstMapLayout measures the
optional maneuver and destination footer before allocating map height. Two-subview
legacy callers retain their layout. With no cue, on arrival or while paused, no
empty green card space is reserved. Large text/error states can scroll rather than
clip the measured card, footer or player. The shared persistent player is unchanged.

The green card uses the existing route cue: arrow, feet distance and turn/street
text (toward versus onto preserved). Unknown streets retain a truthful direction;
no distance or maneuver is invented. AR's existing maneuver card remains separate.

Below the map: serif destination name, status/distance/time, white View stop and AR
directions buttons. More contains Previous, Continue/Finish, Show walking route and
Center on my location. Paused walks keep an explicit Resume action. Arrival Stay here,
automatic-transition Undo and route/location failure/retry notices stay visible.
AR still uses prepareForARFromDetails; pre-start Map retains an AR action that starts
the walk, as the former floating AR control did. Completed walks keep summary/Undo.

## Cartography and marker policy

Google light style uses ivory land #F0EDE6, sage parks #D9E1CE and river #B2CED8. Roads
and useful street labels remain; transit, parcel detail and standard map icons are
quieted. Style JSON is syntactically validated, not native-GMS-validated. Apple uses
MKStandardMapConfiguration with flat elevation/muted emphasis and no POI clutter;
Apple cannot reproduce Google's custom palette exactly. No painted trees, custom
tiles or altered roads are introduced to imitate the generated concept.

MapViewModel.markers adds an opt-in destination-only illustration policy. Other
consumers default to their prior artwork behavior. The active destination remains
illustrated even if visited; browsing emphasizes the viewed stop without retargeting
the walk. Remaining markers show their tour number in a 28-point circle within a
44-point hit target. They stay at the true coordinate. The illustrated marker retains
existing layout offsets/bottom-left badge/leader logic; compact targets and recenter
are reserved in its collision layout. Apple caches compact marker snapshots.

The only on-map button restores active-leg framing. More retains close user-follow
and route framing. GPS dot, accuracy circle, real walking polylines, off-route
updates and manual pan ownership are unchanged.

## Verification and remaining work

92 portable tests of actual models passed, including new checks for first-stop
emphasis, advancing, visited-active appearance, viewing another site without changing
the walking destination, and default full-art compatibility. Both map JSON definitions
parse; final Debug/Release full app/test syntax and whitespace checks pass. Core logic
is unchanged; its prior 227 tests were not rerun. These are not native SDK build results.

Native visual QA is blocked in design-qa.md. On a Mac/iPhone:
1. Build Debug/Release with the shipped project and real map credentials. Check style
   parsing and muted Apple configuration on their respective SDKs.
2. Compare 393-point portrait screenshots with reference, excluding image-viewer
   chrome. Check compact phones, landscape, accessibility text and player visible.
3. Confirm exactly one turn card above the map and none below it; check long/unknown
   street text, arrival, pause, loading, weak GPS, offline and provider recovery.
4. Verify all five numbered markers stay tappable; only current/viewed uses artwork.
   Check selection, visited target, no overlap with recenter or attribution, pan/zoom,
   GPS dot and departure/destination framing after 15 m and late route responses.
5. Exercise More: Previous, Continue/Finish, follow and route. Verify Resume and Undo
   remain visible in their states, no false visit credit, saved stories/audio unaffected.
6. Open View stop and AR from walking/pre-start Map. Back and X retain their context
   rules; arrival holds and phone-down AR return continue working.
