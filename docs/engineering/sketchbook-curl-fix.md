# Sketchbook curl repair

## Weathered paper refinement

The reverse now uses `sketchbook-paper-reverse`, an opaque, full-bleed blank
paper texture with restrained handling wear at the edges. It contains no
lettering, binding, illustration or pre-rendered curl; UIKit still creates the
bend, occlusion and shadows. The existing front paper keeps its cloth gutter
and worn corners, with the scan's outermost right/bottom pale margin excluded
(1.5% horizontally, 0.8% vertically). The front no longer has a rounded mask
that exposes its backing at the sheet corners. Artwork and text are not scaled
or cropped by this paper-only adjustment.

No controller, page ordering, gesture, next-page reveal, unlock, pagination or
Reduce Motion logic changes. The prior Home-circle restoration remains a
separate working-tree change.

Native visual acceptance is still required: slowly turn Mill to Greystone from
both corners and in reverse; verify the next sketch is exposed, the moving
reverse stays blank, and no pale seam appears under the book. Check settled
pages, cancelled turns, large text and Reduce Motion as well. The generated
review mockup is a material target, not a recording of UIKit execution.

Scope: reverse-arrow crash and pale strips exposed by the turning sheet. No changes to tour progression, artwork, unlock rules, or other screens.

## Cause and changes

The coordinator passed only one controller to every `setViewControllers` call. That is correct for minimum-spine opening, but animated double-sided turns need the turning sheet's back as well. Native tests reproduced the exact iPhone controller-count exception during a forward turn too. Prior regression tests checked nonanimated opening only. Supplying two faces for every call was also rejected during native validation; controller count must distinguish initial presentation from animation, rather than use a universal one- or two-controller rule.

- Load the page-controller view before configuring double-sided rendering. Preserve one-front opening and supply both physical faces for animated turns in either direction, retaining one logical sketch per stop.
- Keep the minimum spine across rotations.
- Use main-queue callbacks to defer queued turns until UIKit has returned from its animation completion. Do not replace hosting controllers or refresh their content during a curl. Reconcile UIKit’s actual visible page even when an interrupted animation reports `false`; that flag does not prove that the destination was not installed. Preserve pending arrow requests and reconcile completed/cancelled swipes.
- Remove the front sheet's external vertical padding/shadow and disable hosting safe-area margins. Both faces use full-bleed parchment; the existing artwork and native curl shading remain.

Reference: public UIKit `UIPageViewController.h`, `setViewControllers:direction:animated:completion:` discusses the additional back for double-sided turns. Its broad wording does not capture the runtime difference between initial presentation and an animated transition. The native regression tests exercise both paths. CI crash reporting now exports diagnostic bundles whenever the native test run fails, including runtime allocation aborts which do not appear as XCTest failure summaries. A Swift task-allocation abort was observed in the new async live-animation tests; the final tests pump the main run loop synchronously, and UIKit deferrals use the main dispatch queue instead of unstructured Swift tasks.

## Regression coverage

Scene-attached native UIKit tests cover live forward/reverse animations; standalone tests cover initial opening at every page in one-, two-, and six-stop books; both paper faces; animated forward/reverse turns including Greystone → Mill; repeated turns; rapid reverse taps; queued content changes after a cancelled interactive transition; and safe-area suppression. The cancellation test invokes the real coordinator's delegate callbacks; it does not synthesize a physical finger gesture.

The shared TourCore suite remains unchanged apart from correcting its layout documentation. Apple CI runs Simulator compilation/native tests and unsigned iPhone Release compilation. See the linked validation run in the delivery message for the exact tested revision and results.

## iPhone acceptance checklist

1. Open the sketchbook at Mill, turn to Greystone, wait for it to settle, then use the back arrow. Repeat ten times.
2. Reverse direction rapidly using the arrows. Start and cancel swipes in both directions, then use each arrow.
3. Slowly drag the top and bottom page corners in both directions. Inspect the entire curl at several angles: parchment must reach every sheet edge without a blank white strip. Native highlights/shadows are expected.
4. Repeat with both sketches locked, one unlocked, and both unlocked. Open each stop's sketch directly and verify the matching page.
5. Rotate during/after a turn, background/return, dismiss/reopen, test larger text and Reduce Motion. Confirm page count and controls match the settled sketch.

Simulator animation tests exercise UIKit's controller contract, but cannot certify real-device curl textures or gesture timing. Physical iPhone acceptance remains required.
