# AR reliability implementation and validation — candidate 116

## Selected approaches

Both capabilities retain the existing native architecture, following the source-based
[evaluation and comparison matrix](ar-capability-evaluation.md). The three requested
libraries are research references only. No package, license-bearing source, asset,
recognition service, competing location manager or separate camera/session owner was added.

Walking retains shared Google route geometry, ENU alignment, reusable original 3D chevrons
and conservative fallback. Camera positions now use frame exposure time rather than
callback receipt time. Unsafe old turn poses hide until the replacement stabilizes;
ordinary world pinning, perspective and gentle-curve continuity remain. Horizontal surface
evidence is no longer labeled ground-verified unless ARKit classifies a floor.

Plaques retain ARKit reference images, world tracking, ARImageAnchor and the existing
RealityKit card. A camera-only gate now requires 0.5 seconds of continuous fresh matching
frames (at least three), rejects excessive pose changes/gaps and resets on loss/interruption.
Once qualified, the original tour ledger owns the same exactly-once award. Card presentation
is connected to the real image anchor; unsupported/failed binding does not create a geographic
plaque card. Binding identity is stored separately from the most recently observed image,
so changing targets cannot leave the card on the preceding anchor.

Scene phase is forwarded consistently in both entry points. Initial startup is distinguished
from resuming an attached paused session; only explicit retry/new entry/alignment-provider
changes reset tracking. Session errors hide all spatial content and expose recovery. The
scanner's existing instruction card now displays its hold/retry/reacquisition instructions.

The current new-unlock celebration and automatic matching sketchbook opening are preserved.
An already unlocked target has a separate **View plaque in AR** action to inspect its
anchored card; existing View sketch and Sketch unlocked actions still open the sketchbook.
Closing the card
uses the tour's presentation state, not a new competing navigation state; a qualified later
rescan may reopen it. The Close regression also covers a plaque recognized without GPS.

## Significant file inventory

| File | Significant change |
|---|---|
| `Packages/TourCore/Sources/TourCore/ARSpatialNavigation.swift` | Media/wall sensor clock conversion; safe retention and stable-yaw turn debounce |
| `Packages/TourCore/Sources/TourCore/PlaqueRecognitionEvidence.swift` | New bounded camera-evidence policy; no GPS/story input |
| `CranfordHistoricalAR/Services/GeoSpatialProvider.swift` | Timestamp-matched capture positions and injectable clocks; existing provider ownership retained |
| `CranfordHistoricalAR/AR/ARNavigationArrow.swift` | Hide rejected/stale placements; retain the same white/green mesh/material design |
| `CranfordHistoricalAR/AR/ARHistoricalSign.swift`, `ARAnchorManager.swift` | Immediate trust-loss hiding; preserve normal animated user dismissal |
| `CranfordHistoricalAR/AR/GeoAnchorManager.swift` | Honest floor confidence, failed-session cleanup and successful-binding requirement for plaque cards |
| `CranfordHistoricalAR/AR/PlaqueAnchorController.swift` | Filter configured references, clear empty configurations, separate bound identity and report binding success |
| `CranfordHistoricalAR/ViewModels/ARViewModel.swift` | Live evidence → existing award → image card; deduplicated award calls; lifecycle and instruction recovery |
| `CranfordHistoricalAR/ViewModels/TourViewModel+Proximity.swift` | Close a camera-presented plaque independently of GPS state; no arrival/progression policy change |
| `CranfordHistoricalAR/Views/ARView.swift` | Forward scanner lifecycle; pause on exit; show concise scanner guidance inside its existing card |
| `CranfordHistoricalAR/Views/StopDetailView.swift` | Separate AR re-entry for unlocked targets; existing sketchbook navigation retained |
| `Packages/TourCore/Tests/TourCoreTests/ARSpatialNavigationTests.swift` | Delayed-frame clocks, passed/turning poses, jitter, yaw stability and wrap regressions |
| `Packages/TourCore/Tests/TourCoreTests/PlaqueRecognitionEvidenceTests.swift` | Seven visual-evidence qualification/loss/reacquisition tests |
| `CranfordHistoricalARTests/GeoSpatialProviderFactoryTests.swift` | Native provider/renderer, reference dimensions/filtering, inactive/error recovery tests |
| `CranfordHistoricalARTests/TourCompletionFlowTests.swift` | GPS-independent card closing preserves award/destination and supports a later rescan |
| `project.yml`, `CranfordHistoricalAR.xcodeproj/project.pbxproj` | Candidate build number 116 only; no API keys or SDK settings changed |
| `README.md` | Candidate summary and evidence/field report links |
| `docs/engineering/ar-capability-evaluation.md` | Before-implementation audit, options, matrix, source/license/maintenance evidence |
| `docs/engineering/ar-repository-evidence-2026-10-31.json` | Immutable inspected heads/history, release and all open-issue listings |
| `docs/engineering/ar-field-validation.md` | Device-only walking, recognition and lifecycle acceptance script |
| This document | Implementation inventory, executed checks and limitations |

No existing functional files were removed. Google Maps/Routes, narrator files, all five
stops, reference photos, hunter-green theme, saved keys, dwell/bypass/departure rules,
existing sketchbook behavior and phone-horizontal exit remain in place. No unrelated
Home/Stops/Map design or previously declined progression UI redesign was implemented.

## Executed checks

- Before the pose repair, two focused turn tests reproduced three failed assertions:
  the old pose was returned after passing it or changing to a sharp new direction.
- After repair, all **26 ARSpatialNavigation tests** passed, including delayed exposure
  timestamps, ENU axes, course consistency, real polyline previews, off-route/heading/GPS
  loss, hysteresis, yaw wrap, gentle curves and stale/invalid world poses.
- All **seven plaque-evidence tests** passed: distinct frames/minimum duration, incorrect
  or untracked images, camera tracking, stale/future time, identity changes, pose jumps,
  gaps, interruption/loss, minor jitter and reacquisition. The policy has no proximity input.
- The full portable TourCore suite passed **296 tests, zero failures**.
- The actual portable model/store/provider harness passed **130 tests, zero failures**,
  including the new GPS-independent card-close regression and existing three-minute,
  narration/plaque/departure, next-stop, persistence and route flows.
- Full Debug/Developer and Release native Swift source parsing passed. Parsing does not
  link Apple frameworks, run UIKit/RealityKit or replace native verification.

The final candidate must also pass the existing **Apple compiler checks** workflow on its
exact commit: core/model tests on Apple Foundation, shipped-project Simulator compilation,
native host tests and iPhone Release compilation. The validation branch is
`validation/ar-reliability-116-final`; the matching run's native counts/conclusion are the native
testing record. Do not use build 115's successful run to certify these changes.

## Limitations and device-only work

The [physical field checklist](ar-field-validation.md) remains unexecuted here. Automated
policy inputs do not prove real ARKit detection, image-anchor placement, accuracy at oblique
angles, illumination/occlusion tolerance, terrain selection, stable outdoor heading or battery/FPS.
The current reference widths remain estimates pending physical measurements. Apple
geotracking availability and ARCore VPS coverage at the actual Cranford viewing positions
have not been established by this task.

Reference-image tracking can recognize a printed/screen copy. Neither ARKit, the temporal
gate nor any evaluated library proves a visitor is physically at the historical site by
image recognition alone. GPS remains a separate arrival signal. General building recognition,
surveyed plaque-to-north calibration and a new visual-positioning service are not introduced.

Legacy camera-relative arrow helpers and generic sign-placement rules remain for their
existing callers/tests; they do not drive the live walking placement or verify referenced
plaques. Removing them wholesale would add regression risk without improving localization.

## Rollback and review

Start from `build-115` (`d91859f`), then review the audit, walking and plaque commits in order.
Each capability has its own focused commit. A follow-up integration fix immediately hides
image cards before reparenting: an ordinary 0.25-second dismissal fade would otherwise
render detached content briefly in the wrong coordinate system. Keep this work on its candidate branch until
native verification and field acceptance are assessed. No old branch must be deleted or
merged to run the candidate. A failed native gate must be repaired rather than suppressed.
