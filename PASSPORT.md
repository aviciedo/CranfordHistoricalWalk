# On-site passport — build 65

## Experience

The approved ivory passport uses hunter-green perforated engraved stamps, a large
serif heading, one plaque-enabled stop per paper leaf, and native iOS page curling.
Swipe horizontally or use the 48-point previous/next buttons. Reduce Motion uses
immediate page changes and a short stamp fade. Long names and larger type can scroll
inside a leaf; page controls remain outside the leaf. Back and Close both dismiss
the passport to its presenting screen. They never stop audio or restart the walk.

A first real saved AR plaque recognition closes the scanner/walking AR. The host
waits for dismissal, shows the discovered site's stop page, and opens its passport
leaf. The new stamp settles into place with a spring, success haptic and VoiceOver
announcement. Closing reveals the stop page's new Passport stamped row. That row
reopens the corresponding leaf without replaying the award. Tap a collected stamp
to view the existing on-site bonus. Home also has a quiet Your passport entry.

## Collection rules and preserved behavior

- `StopActivityLedger.bonusFoundAt` is the only saved collection source. Existing
  discoveries appear collected immediately; they do not replay the celebration.
- GPS arrival, visiting, reading, listening, viewing photos and opening a passport
  cannot create stamps. Simulated recognition and disabled developer visit recording
  cannot create stamps either.
- `savePhysicalActivity` emits `pendingPassportStampStopID` only after saving a new
  recognized-plaque bonus. `takePassportStamp` consumes that presentation event once.
  AR teardown preserves it. Returning Home or an explicit developer reset cancels
  the pending presentation without manufacturing or erasing a collection.
- A repeated tracked image cannot award twice. The scanner may recognize another
  supported plaque; the new stamp and returning story use that recognized stop ID,
  not the walking destination. Itinerary, narration and learning remain independent.
- A new walk and visit-only reset retain stamps. The existing full stories/bonuses
  reset clears them. Force quitting retains collection but does not replay an old
  foreground animation on relaunch.
- Pages derive from `hasPlaqueReference`, currently Mill and Greystone. Additional
  plaque-enabled stops get pages automatically. Add custom art in
  `PassportStampArtwork` when their approved assets exist; its native seal fallback
  does not invent historical artwork.
- The passport does not invent bonus content. The existing bonus preview remains
  unchanged, including its placeholder disclosure.

## Main implementation

- `Views/PassportView.swift`: adaptive leaf, stamp row/art, collection UI, spring
  reveal, accessibility, and `UIPageViewController` bridge with `.pageCurl`.
- `Views/StopDetailView.swift`: scanner dismissal sequencing, recognized-site story
  context, passport cover and earned stamp row.
- `Views/ARView.swift`, `Views/TourView.swift`: exit walking AR and restore the
  correct story before the passport is presented.
- `ViewModels/TourViewModel.swift`, `TourViewModel+Proximity.swift`: ledger-derived
  page/count queries and one-shot new-discovery event.
- `Views/HomeView.swift`: secondary collection entry, outside the primary walk CTA.

Generated assets in `Assets.xcassets/passport-*` are decorative stamp illustrations
and ivory paper, not photographs or proof of historical authenticity. Mill and
Greystone drawings were grounded in the existing landmark assets and the owner's
approved stamp design. Transparent perforations and full-resolution raster images
are retained. The Xcode source entry and version match `project.yml` (build 65).

## Verification

232 TourCore tests and 98 portable actual-model/provider tests passed, including four
new passport tests covering saved-history adoption, one-shot recognition, persistence,
repeat scans, practice/disabled recording and independent resets. Existing cross-stop
recognition, GPS, itinerary, narration-model and return-walk regressions also passed.
Debug/DEVELOPER_MENU and Release Swift syntax checks passed. Syntax parsing does not
establish Apple SDK type checking or successful native rendering.

This Linux workspace cannot run Xcode, UIKit page curling, SwiftUI screenshot QA,
AR image recognition, AVFoundation or device haptics. Native build and visual/device
acceptance are pending; `design-qa.md` remains blocked, not passed.

## Required native acceptance

1. Build the tracked Xcode project in Debug and Release; run host-app tests.
2. Mill and Greystone, fresh real discovery: close AR -> correct stop underneath ->
   correct passport page -> stamp animation/haptic exactly once -> Close/Back returns
   to that stop with the stamp row. Verify camera releases after exiting.
3. Enter from Stops without GPS permission or a started walk; then enter via walking
   AR. Recognize the other supported plaque as well. Preserve the destination and
   current audio bookmark throughout; no autoplay or automatic itinerary advance.
4. Existing collection: no award animation; tap row, swipe and arrows in both
   directions, canceled drags and rapid arrow taps. Check page count, collection
   count and bonus opening. Close while animation begins; saved stamp remains.
5. Restart/relaunch, visit-only reset and full reset. Verify expected persistence and
   zero duplicate awards. Try practice scans, recording disabled, wrong image,
   tracking loss, Retry, camera denial and closing without a discovery.
6. Compare against approved mock at compact/large iPhones, largest Dynamic Type,
   VoiceOver, Reduce Motion and darker system appearance. Check stamp crop, ivory
   bleed, leaf/heading proportions, finger targets, page controls and no clipping.
7. Background during scanner dismissal, passport reveal and page turning; foreground
   returns without repeated rewards, stuck page controls or presentation warnings.
