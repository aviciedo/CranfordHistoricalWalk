# Build 136 — published source release

Release date: 2026-11-08. This release consolidates the approved development changes
into the authoritative main branch and the existing Xcode-download/release aliases.

## Included changes

- Updated full-page sketchbook layout: a quiet collection-count capsule, larger
  notebook, concise plaque-scanning instruction and minimal pagination. Worn opaque
  paper and native page turns retain their existing behavior.
- Developer Controls: individual sketch unlocks, a sketch-only reset that preserves
  visits/stories/walking progress, and a saved ARCore on/off switch applied on the
  next walking AR session. Reset collections remain empty after relaunch and can
  be collected again by scanning. ARCore still respects normal consent and setup.
- Stable illustrated map markers during gestures, more prominent active-stop art,
  corrected viewport clipping and map touch handling.
- Grounded AR route arrows with rounded green bevels and white caps on both sides;
  reject unaligned camera-relative placements and reacquire ground on re-entry.
- Approved hunter-green tour illustrations, Cranford Hotel artwork/plaque unlock,
  compact narration controls and bottom navigation with more space for page content.
- Comprehensive testing is now opt-in. Apple and SwiftLint workflows are manual only
  and require `perform comprehensive testing`. Routine development/publication uses
  quick, relevant checks. Test suites remain available.

## Verification

The application-code candidate `cac0537acb8394bb74e0d58860a461db58dd206a` passed
308 TourCore tests, 136 actual app-model tests, native tests, Simulator compilation,
iPhone Release compilation and SwiftLint before the opt-in policy was introduced.

- [Apple checks on that application-code candidate](https://github.com/aviciedo/CranfordHistoricalWalk/actions/runs/42496661744)
- [SwiftLint on that application-code candidate](https://github.com/aviciedo/CranfordHistoricalWalk/actions/runs/42496661604)

Subsequent changes are testing policy/workflow configuration, agent guidance and
these release notes. This publication uses quick checks only: diff review,
configuration/YAML parsing, matching build numbers and fast-forward ancestry checks.
Comprehensive tests were not rerun on the final release commit under the owner's
new testing policy. Previous candidate results are not presented as exact-release
commit test results.

Physical iPhone review remains appropriate for outdoor AR/GPS placement, plaque
recognition, page-curl appearance and developer-menu interactions. The Hotel plaque
width remains an estimate until measured.

This publishes the GitHub source/Xcode project, not an App Store or TestFlight binary.
The immutable `build-136` tag identifies the exact released source.
