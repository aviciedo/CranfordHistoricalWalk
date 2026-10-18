# Field Guide native iOS design review

final result: blocked

The selected visual target is the first displayed Field Guide concept, reattached by the user.
The approved additions are tap-to-enlarge photos with an X, and the mill map illustration.
This is the actual SwiftUI app, not a web prototype. Linux cannot render SwiftUI, compile against
Apple SDKs, launch Xcode, or exercise the iPhone camera. Visual comparison and native interaction
verification remain blocked by that platform limitation. No design QA pass or iOS build is claimed.

Implemented source scope:
- Native Home / Map / Stops tabs, one shared audio service and player strip.
- Ivory/forest/sage/sand/terracotta roles with a device-following dark palette.
- One map destination panel; details and AR actions for the guided stop.
- Shared stop details, available photos, recording controls, source notes.
- Full-screen photo viewer with X, pinch zoom, bounded pan and reset.
- Generated mill landmark illustration on live/illustrated maps; original photo and plaque unchanged.

Required Mac/iPhone checks:
1. Build the included CranfordHistoricalAR.xcodeproj with Xcode 16+ and run the app on an iPhone.
2. Compare the active Map tab with the selected reference at a normal iPhone size.
3. Confirm the map remains pannable/zoomable and its attribution is not covered.
4. Confirm the bottom tabs, player and destination panel fit on a smaller screen and at larger text sizes.
5. Play the mill recording, switch all tabs, inspect a different stop, and confirm the guided stop is unchanged.
6. Open the photo from the map panel, Stops and details. Zoom, pan, reset and close with X. Confirm no tour advance.
7. In light/dark appearance, check essential labels, selected tabs, controls and visited markers for contrast.
8. Verify Show on map centers a browsed stop without changing the guided destination.
9. Follow [AR-FIELD-TEST.md](AR-FIELD-TEST.md): arrival reveals a marker without a visit; activation starts the story and records a visit; only Continue changes the destination. Confirm the second-stop map/AR handoff.
10. Test missing Maps/Routes configuration: clearly labeled illustrated/estimated fallback, no developer setup prose in the main flow.

The host-app navigation regression test must be run through Xcode Product > Test. Linux TourCore
checks do not execute it. On-device visual review and any resulting fixes remain a required follow-up.

AR guidance update: the camera-relative bearing and activation policy have portable XCTest coverage.
An isolated Foundation host also checks the production proximity extension and visit store. These
checks do not render SwiftUI or RealityKit, recognize the plaque, or compile the iOS application.
On-device arrow alignment, marker taps, audio startup, sign readability and saved visit dates still
need the Mac/iPhone field test. The visual/native QA result above remains blocked.

Mill content update: marker/AR copy, full-address detail page, separate expandable narration,
and spoken-versus-recorded player controls now share the updated stop data. Physical plaque
recognition assets remain unchanged. The on-device male voice, pronunciation, read-aloud progress,
short AR card fit and map popups need the additional checks in AR-FIELD-TEST.md. No new native
visual/audio QA pass is claimed.

Greystone update: the second stop now uses the creator-supplied name, marker text, description
and full on-device narration while retaining its stable tour ID. A shared multi-photo detail
gallery supports rotation, manual paging, credits, pause and full-screen zoom. All five original photos from Greystone.zip
are now bundled, with the selected cover and creator-supplied captions/bridge credit. Native gallery behavior, voice playback and build status still
require Mac/iPhone verification using AR-FIELD-TEST.md.
