# Build 127 artwork verification

The owner approved all three watercolor review proposals and explicitly requested
implementation and publication. Build 127 integrates the final reviewed layers.

## Completed locally

- All 12 Mill/Greystone/Church image slots reproduce their authoritative layers.
- All nine original-size app composites equal the reviewed ink/watercolor pixels.
- Each new ink/color pair has zero differing alpha pixels. All five reviewed reveal
  frames (0, 25, 50, 75, 100 percent) share the same final alpha.
- Every reviewed fixed layer file matches its frozen hash. Greystone and Church's
  fixed layers are unchanged from the preceding app version. The Mill now uses the
  new fixed layers separated from the approved cleaned flattened ink before painting.
- Dimensions, RGBA, sRGB, transparent Home padding and catalog registrations pass.
- Tour metadata, recognition targets, collection eligibility, navigation/provider
  logic, saved-progress logic and narration remain unchanged.
- The generated Xcode project and project.yml both specify 0.2.0 (127).
- git diff --check passes.

Reproduce with scripts/build-mill-artwork.py for mill (default), greystone and church.

## Publication gate

The Linux host cannot run Xcode. scripts/verify-ios-build.sh reports that a Mac
with Xcode is required. GitHub access failed through the configured proxy; gh also
reported that its configured authentication was invalid. No remote push, Apple
compiler workflow, SwiftLint workflow or main promotion has been confirmed.

The exact committed candidate must pass the Apple compiler and SwiftLint checks
before fast-forward promotion under release-policy.md. Preserve build-120 as the
published rollback baseline until successful promotion. A prepared Xcode source ZIP
is a candidate download, not evidence of a successful native build or publication.
