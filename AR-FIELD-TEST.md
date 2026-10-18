# Test the mill story and optional AR discovery

The portable logic checks passed. The iOS build, actual narration, recognition, overlay fit and
window anchoring still need Xcode/iPhone testing. Use a Debug build to access Developer Controls.

## Prepare

1. Download the current GitHub ZIP, copy your existing `Config/Secrets.xcconfig` into its Config
   folder, open `CranfordHistoricalAR.xcodeproj`, select your signing team and run on the iPhone.
2. On Home, open **Developer**. Leave **Simulated location** off for field testing.
3. Tap **Clear visits & restart at stop 1**. To avoid saving repeated test visits, turn **Save visit
   history** off. This leaves story completion and AR discovery usable; confirmation says the visit
   was not saved. Saving defaults to on after relaunch.
4. At the permitted public viewing position, wait for a fresh GPS fix with good reported accuracy.
   Tap **Save this location as the viewing point**. Copy/screenshot its coordinates and accuracy.
   The existing Google-search coordinate is approximate, not a verified public viewing area.
   Capture changes story arrival on this device; it does not replace the building/map coordinates.

## Story first

1. Start the walk and approach the viewing position. Confirm the detail screen appears once with
   the mill photograph and description. It must not start audio or record a plaque verification.
2. Tap Play. Confirm the warm male narration plays only after this action and the map/AR player
   does not start a second copy. Pause/resume; browse another stop without changing the guided order.
3. After the mill narration actually ends, confirm **Find the plaque in AR** appears. Repeat with
   **I've read the story** to test the reading route. Developer's **Mark story read for testing**
   avoids waiting through the recording during repeated placement tests.
4. Choose Continue without scanning. Confirm Greystone becomes the destination, its walking route
   updates, and the mill has no newly saved plaque verification or unlocked bonus.
5. Reset the walk and repeat with optional discovery. Closing details must not reopen them on
   every GPS update; resetting the walk must re-arm the arrival offer.

## Plaque and two-door-pane overlay

1. From a permitted place outside, choose **Find the plaque in AR** and point at the plaque beside
   the red double doors. Keep the entrance clear. The camera must not show the old giant marker
   above the plaque or automatically replay the full narration.
2. A matching, currently tracked plaque with normal AR tracking should trigger one short
   translucent confirmation and save one plaque-verified visit (unless saving is off/simulated).
   GPS alone and story playback alone must never unlock the extra.
3. The translucent bonus placeholder should cover the TWO glass panes in the red double doors,
   immediately right of the plaque. Initial position/size are approximate and require calibration.
4. Tap **Align bonus**. Keep the plaque within the camera's view; adjust right/up/width/height,
   close the controls and inspect. Repeat as necessary. Values are multiples of plaque width and
   saved only on this device. Copy/screenshot the final values for the developer. Reset visits
   must preserve calibration; **Reset approximate placement** removes the custom bounds.
5. Pan from plaque to windows; gently move sideways/back. The overlay should stay on the facade,
   not follow the camera or vanish just because the plaque leaves view. Test the X and Open extra
   controls. Extra content is explicitly a placeholder, not a supplied historical photo/video.
6. Move more than 12 meters away or interrupt AR. The extra must become inaccessible. Reopening
   AR must require seeing the plaque again to establish its pose. Existing saved verification
   must not unlock a remote bonus from Home/Stops.
7. Try poor light, oblique angles and tracking loss. Verify no duplicate recording/celebration,
   no GPS-only fallback unlock, and Continue remains available after the story. Capture failures
   with the Developer coordinate/accuracy readout, plus overlay alignment values.

## Accessibility and continuation

- Test larger text, VoiceOver, smaller phones and Reduce Motion. The Map control and Continue
  must remain reachable. The confirmation must not require tapping or recognizing animation.
- Continue to Greystone. Confirm all mill overlays disappear, normal street-turn guidance returns,
  and the next stop uses its existing GPS marker flow. Camera denial must still allow the map,
  stop story and optional continuation.
- Run Product > Test on the Mac. The native suite also covers map state, the shared narration
  player and a mill activation action that opens the story without starting playback.

Exact alignment cannot be certified by a photograph alone. The plaque width is still unmeasured;
the overlay uses a plaque-derived world pose with calibrated bounds, not separate window tracking.

## Walking arrows and street turns

- Enter AR facing left, right and backward relative to the route. Check the large initial
  direction cue, route street name and feet distance; face the route and let the cue settle.
- Walk toward an actual left/right turn. Check the translucent ground arrow and floating
  street sign; after turning, the ground arrow must follow the new leg, without pointing back
  at the corner. Stand near a corner for several GPS updates to check stability.
- Leave the route by more than 35 meters. Old walking arrows must disappear while a fresh
  route is requested. Use Map until routing and heading are available again.
- Interrupt/resume AR near a turn several times, including with Reduce Motion enabled.
  The floating sign must return visibly rather than remain transparent after a canceled fade.
- Repeat after Continue to Greystone. The mill arrival/story flow must still stop walking
  guidance and must not record plaque verification from GPS alone.

Latest portable verification: 151 core tests and 20 production tour-logic integration tests
passed. Both Debug/Release Swift syntax and saved project/asset checks passed. These do not
substitute for an Xcode iPhone build or the physical-device checks above.

## Greystone Cranford Park discovery

1. Continue to Greystone. Confirm its story opens on arrival, or open it from Map/Stops. Read or
   listen, then choose **Find the plaque in AR**. Also test Continue without scanning: this must
   advance to the Rahway River without recording a plaque-verified visit or unlocking an extra.
2. Aim at the black **Cranford Park** sign. Include the stone surround shown in the reference
   photograph, keep the camera steady and use good light. The mill plaque must not unlock this stop.
3. A currently tracked match with normal AR tracking should show one translucent confirmation,
   record one Greystone plaque verification (unless saving is off/simulated), and display the
   translucent placeholder above the plaque. It must not use the mill's door-pane position.
4. Tap the placeholder/Open on-site extra, close it, pan away, interrupt AR, restart AR and move
   more than 12 meters away. The session/distance restrictions must match the mill's bonus.
5. Verify mill viewing-point capture and door alignment do not alter Greystone's arrival/overlay.
   GPS arrival, a nonmatching plaque, saved visits alone and interrupted tracking must not unlock.
6. Reference scale is unmeasured: 0.75 m describes the entire supplied image frame including stone,
   not just the black plaque. Report recognition failures, screenshots and the measured sign width
   when available. Validate ARKit reference-image quality during the Xcode asset build.

## Fine-tune the Greystone pillar extra

- Use the new default card above the black Cranford Park sign. It should fit inside the pillar's
  visible edges and leave the plaque readable. This is a photo-based starting point, not a
  measured physical fit; the close-up reference still uses its estimated full-frame width.
- In the AR camera, tap **Align bonus** and scroll to **Greystone plaque bonus alignment**.
  Keep the plaque visible and adjust Move right, Move up, Width and Height. Even with the phone
  held still, changes should update the card. Close the controls to inspect it on the pillar.
- Relaunch to verify saved settings. Reset visits and verify alignment survives. Reset Greystone
  placement and verify the photo-based defaults return while the mill's alignment stays unchanged.
- Send a screenshot of the final four values and the overlay, plus any measured plaque width.
  The photo by itself cannot establish scale in feet/meters or certify a public viewing position.
