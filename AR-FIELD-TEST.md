# Test the guided AR walk on your iPhone

This update has passed its Linux logic checks. A real iOS build and outdoor AR test still need to
be completed on your Mac and iPhone. The screenshots/mockups are design references, not test results.

## 1. Install this version from the Mac

1. Download the ZIP linked in the Codex response and double-click it in **Finder > Downloads**.
2. Open the newly extracted folder. Double-click **CranfordHistoricalAR.xcodeproj**, beside
   **README.md**, **Config** and **Packages**. Keep those folders together.
3. If your previous working download has `Config/Secrets.xcconfig`, copy that file into the new
   download's **Config** folder using Finder. Keep its values private. It contains your own Maps,
   Routes and signing settings; this download intentionally does not include it.
4. Wait for Xcode's package downloads to finish. Connect your iPhone, unlock it and trust the Mac
   if asked. At the top of Xcode, select the **CranfordHistoricalAR** scheme and your iPhone.
5. If signing needs a team: click the blue project icon at the top of the left sidebar. In the
   center editor, under **TARGETS**, click **CranfordHistoricalAR**, then **Signing & Capabilities**.
   Turn on **Automatically manage signing** and choose your Apple account's team beside **Team**.
6. Choose **Product > Build**. Expect **Build Succeeded** before continuing. If it fails, open the
   Issue navigator with **Command–5** and report the first red error, including its filename/line.
7. Choose **Product > Run** (or click the triangle at the top left). Expect the new app to open
   on your iPhone. Installing over the same app/bundle ID preserves locally recorded visits;
   deleting the app erases its local records.
8. For host-app regression tests, select an installed iPhone Simulator at the top of Xcode and
   choose **Product > Test**. These tests exercise the view-model flow and local visit storage.
   They do not test an actual camera or physical plaque. Select your physical iPhone again for AR.

## 2. Practice before going outside

1. In a Debug build, long-press the home title or **Your walk** to open **Developer Controls**.
2. Turn on **Simulated location**. To practice walking arrows, tap **Walk toward next stop**,
   then **Pause walking** after a few seconds. This supplies a practice heading. Tap **Jump to
   next stop** to test arrival. **Ready to discover** should appear with no saved visit date;
   merely arriving must not complete a stop. An idle practice GPS fix can become stale after
   30 seconds; jump again if activation asks for a fresh position.
3. On a physical iPhone, enter **View in AR**, let tracking settle, and activate the marker.
   The historical card should appear; narration should start. Expect **Practice visit · Not saved**.
4. Tap **Hide AR card**. The destination should remain the mill. Tap **Continue to next stop**.
   Expect Greystone to become the destination; the AR arrows should guide toward its route.
5. Jump to Greystone, activate that marker and continue. This flow does not require a Greystone
   plaque photo. Practice must not create saved visit dates or replace existing real ones.
6. Turn off simulated walking and reset the walk before real testing. An iOS Simulator can test
   the map and logic, but cannot run this AR camera experience.

## 3. Walk to stop 1: Droescher's Mill

1. Allow **Location While Using the App**, **Precise Location** and camera access.
2. Tap **Start walking tour**, then **View in AR**. While standing still, slowly turn your phone
   left and right. The ivory arrows with forest rims should point along the walking route. The
   panel should say **Walk ahead**, **Bear left/right**, **Turn left/right** or **Turn around** as
   the camera turns. If a direction is unknown, the app should say so rather than invent one.
3. Walk toward the mill. Distance/time should update along the route when Google Routes is
   configured. A straight-line fallback must be labeled approximate; it is not a street route.
4. At the mill, frame the whole door plaque in good light and move the phone slowly. On a match,
   expect **Plaque found** and a floating stop marker above the plaque. Recognition alone must
   not record a visit or start audio.
5. Tap that marker, or **Activate stop marker**. Expect the historical card, narration and
   **Visit recorded on this iPhone**. A second tap must not restart the recording.
6. If image recognition does not lock, an approximate GPS marker can appear after about eight
   seconds near the stop. Activation still needs normal AR tracking and an accurate, fresh
   on-site GPS fix. A currently tracked matching plaque can bypass an incorrect GPS geocode.
7. Tap the card for readable details, or close it. The walking destination must stay at the mill
   until you choose **Continue to next stop**. Browsing/listening alone must never record a visit.

## 4. Continue to stop 2: Greystone

1. Tap **Continue to next stop**. Expect the destination to become **Greystone**, with a new
   route, distance/time and AR direction. The mill's plaque must no longer control the arrows.
2. Remain in AR, or tap **Map** at the top left for the in-app walking map. The map's **Directions**
   button opens Google Maps walking directions. Return to this app for marker activation;
   Google Maps itself does not record visits in Cranford Historical AR.
3. At Greystone, expect a floating AR marker based on GPS. No physical plaque recognition
   is configured for this stop yet. Tap the marker and expect the card, recording and saved visit.
4. Open **Stops** and confirm visit dates for both stops. Close/reopen the app and check again.
   A new walk starts at stop 1 even though saved visit dates remain visible.

## 5. Check the boundaries

- Open/listen to a different stop: the walking destination and visit history must stay unchanged.
- Hide a marker or leave before activation: no visit should be recorded, and no stop skipped.
- Interrupt AR or turn off camera permission: activation must be blocked; the map should remain usable.
- With poor/stale GPS, activation should explain why it cannot record a visit. GPS-only activation
  needs accuracy of 25 m or better, a fix under 30 seconds old, and distance plus accuracy inside
  the arrival radius. A previously seen/lost plaque must not bypass that rule.
- With no Maps/Routes key or no network, check the labeled fallback and return-to-map controls.
- Check a smaller iPhone and the phone's larger text settings: controls should scroll, all actions
  should remain reachable, and the marker/card should not be hidden by the HUD.

The bundled coordinates are still unverified geocodes. In particular, a misplaced Hall coordinate
can block its GPS activation even when you are at the real building; report that discrepancy rather
than weakening the visit rule. The mill plaque's assumed 18 cm width is also unmeasured. Please
measure its outer width next visit so its AR scale can be calibrated. No need to share API keys.


## 6. Check the updated mill story and voice

1. Open the mill from **Home**, a map marker and **Stops**. Confirm the same name and full address:
   **Droescher’s Mill — 347 Lincoln Avenue East, Cranford, NJ**.
2. The short AR/location card should say **Construction: After 1821**, date the mill site to at least
   1779 and describe it as the last surviving historic mill on the Rahway River. The physical plaque
   still reads **c. 1737**; that inscription is now under **About this stop**, separate from construction.
3. Tap the photo/stop details. Read the expanded history, then expand **Read narration**. Confirm
   the full supplied story includes the healthcare tenants, **Alleum Yoga**, 1974 listing and 2014
   landmark designation. Close the enlarged photo with X; browsing must not record a visit.
4. Tap Play. Expect an English male voice with a gentle pace reading **Droescher’s Mill: A River
   That Built a Town** and the full supplied script. Listen for natural pronunciation of Droescher,
   Severin, Cranford, Rahway and Alleum Yoga. Exact duration varies with the installed voice; the
   app does not claim a measured 2:35 duration in advance.
5. If no suitable male voice is available, the app should explain what is missing. On the iPhone,
   open **Settings > Accessibility > Read & Speak** (called **Spoken Content** on some iOS versions),
   then **Voices > English**. Choose/download an English male voice, return to the app and tap Play
   again. Enhanced/premium voices are preferred when available. No API key or voice subscription
   is needed. Voice inventory and Settings wording vary by iOS version.
6. Pause and resume, change tabs, then play Greystone while the mill is speaking. Expect only
   one narrator at a time. Return to the mill and retry its narration. Speech has a progress bar;
   recorded audio retains its scrubbing and skip controls.
7. In AR, activate the mill marker. Expect this same new voice and script to start, with the short
   historical card. **Stop details** opens the longer description/transcript. Continue to Greystone and confirm its new script uses the same male-voice preference.

The Linux tests check script selection and male-voice metadata policy. They cannot listen to the
voice, evaluate pronunciation, compile AVFoundation/SwiftUI, or verify this on a real iPhone.

## 7. Greystone content and slideshow

The actual photo import is pending the original image files. Run the gallery steps below
after the approved images have been added; the current stop has no substitute gallery assets.

1. Open stop 2 from **Stops** and confirm its name is **Greystone**, address is **600 Lincoln
   Park East**, and construction date begins in **1920**. Check the short map popup and AR card.
2. Read the longer description and expand **Read narration**. Tap Play: expect the full
   **Greystone: The Castle on the River** story in the same on-device male voice as stop 1.
   It should replace the old recording. Check pronunciation and pause/resume; duration varies.
3. After photo import, expect the image titled Greystone first. Watch for a page change after
   six seconds. Swipe both ways; Previous/Next buttons pause rotation so you can read the caption.
   Pause/Play should work. Enlarge each image, pinch to zoom, then close with X. The gallery
   should return to the same image without advancing the tour or recording a visit.
4. Check the 1912 Lincoln Park footbridge caption and Historical Society credit. Portraits
   should be fully visible rather than cropping faces. Test the smaller iPhone, larger text,
   light/dark appearance, VoiceOver and Reduce Motion. The last two use manual paging.
5. While a photo is enlarged, while AR is open, while the app is inactive, and after leaving
   details, confirm the slideshow pauses. Returning should not create multiple timers.
6. Activate the Greystone AR marker on site; expect its new narration and short card. Opening
   or swiping gallery photos alone must not record a visit. Continue should move to stop 3.

These native interactions and the iOS build remain unverified on Linux.
