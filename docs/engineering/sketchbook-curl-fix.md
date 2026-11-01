# Sketchbook curl repair

Scope: reverse-arrow crash and pale strips exposed by the turning sheet. No changes to tour progression, artwork, unlock rules, or other screens.

## Cause and changes

The coordinator enabled `UIPageViewController.isDoubleSided` but passed only one controller to `setViewControllers`. Apple's UIKit header explicitly requires two controllers for a double-sided minimum/maximum spine (front and reverse). Prior regression tests checked nonanimated opening only and incorrectly asserted a one-controller contract.

- Load the page-controller view before configuring double-sided rendering; supply both physical faces for opening and animated turns, retaining one logical sketch per stop.
- Keep the minimum spine across rotations.
- Defer queued turns until UIKit has returned from its animation completion. Do not replace hosting controllers or refresh their content during a curl. Honor unsuccessful programmatic completions and reconcile completed/cancelled swipes without dropping a queued arrow request.
- Remove the front sheet's external vertical padding/shadow and disable hosting safe-area margins. Both faces use full-bleed parchment; the existing artwork and native curl shading remain.

Reference: public UIKit `UIPageViewController.h`, `setViewControllers:direction:animated:completion:` comment. A minimum spine normally displays one front, but `doubleSided == YES` additionally requires its back in the supplied array.

## Regression coverage

Native UIKit tests cover initial opening at every page in one-, two-, and six-stop books; both paper faces; animated forward/reverse turns including Greystone → Mill; repeated turns; rapid reverse taps; queued content changes after a cancelled interactive transition; and safe-area suppression. The cancellation test invokes the real coordinator's delegate callbacks; it does not synthesize a physical finger gesture.

The shared TourCore suite remains unchanged apart from correcting its layout documentation. Apple CI runs Simulator compilation/native tests and unsigned iPhone Release compilation. See the linked validation run in the delivery message for the exact tested revision and results.

## iPhone acceptance checklist

1. Open the sketchbook at Mill, turn to Greystone, wait for it to settle, then use the back arrow. Repeat ten times.
2. Reverse direction rapidly using the arrows. Start and cancel swipes in both directions, then use each arrow.
3. Slowly drag the top and bottom page corners in both directions. Inspect the entire curl at several angles: parchment must reach every sheet edge without a blank white strip. Native highlights/shadows are expected.
4. Repeat with both sketches locked, one unlocked, and both unlocked. Open each stop's sketch directly and verify the matching page.
5. Rotate during/after a turn, background/return, dismiss/reopen, test larger text and Reduce Motion. Confirm page count and controls match the settled sketch.

Simulator animation tests exercise UIKit's controller contract, but cannot certify real-device curl textures or gesture timing. Physical iPhone acceptance remains required.
