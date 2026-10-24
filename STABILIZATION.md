Audit stabilization review — build 45

Baseline: main and xcode-download at 6d6f427 (build 44). This review branch preserves
explicit Continue, independent walk/story/bonus/audio state, both map providers,
and existing AR entry/exit behavior. No branches have been merged or deleted.

Changes:
- Failed directions retry after 30 seconds, at most five times per destination.
  Fresh, sufficiently accurate GPS is required; a delayed fix can resume recovery.
  Retry directions explicitly renews the budget. Destination changes cancel recovery.
- ARCore update errors invalidate quality, pose, altitude and heading, allowing the
  existing localization timeout/fallback to respond instead of retaining good quality.
- GPS warnings use the same 25 m accuracy ceiling as visit eligibility; visible Map
  status rechecks age every five seconds, including when no GPS events arrive.
- A new walk clears the old route-summary cache; saved stories and bookmarks survive.
- CI now executes host-app tests on an available iPhone simulator, builds Release,
  and preserves xcresult/logs/resolved dependency information. This review branch
  triggers CI independently of main.
- Added the app-owned UserDefaults required-reason privacy declaration (CA92.1),
  including a resource entry in the shipped Xcode project.

Verification and remaining gates:
- Existing TourCore suite: 198 passed during the baseline audit; core unchanged.
- Updated portable application model suite: 55 passed (four new regressions).
  Debug/Release parsing passed; privacy plist parses; git diff whitespace checks pass.
- Native tests, SDK type-checking, generated-project comparison, privacy archive
  validation and physical-device reproduction remain pending on macOS/iPhone.
- No resolved dependency lockfile was fabricated: Apple SDK package resolution is
  unavailable on Linux. CI captures its real resolution for review and later pinning.
- The reported Stop 1 failure after Continue has not been reproduced on hardware.
  Existing all-stop explicit-Continue and independent-state regression tests remain.
- Do not merge or call this a release until native CI and device acceptance pass.

Steps 4–6 — review build 46:
- Field acceptance guide corrected for current product behavior, all five approximate
  locations, providers, permissions, AR tracking and calibration. Physical execution
  is NOT RUN: on-site iPhone access is unavailable in this environment.
- Extracted/tested a monotonic phone-down policy and selectively ported parser tests
  from old branch work without merging any branch or restoring automatic advancement.
- Added catalog/version/session identities, catalog validation, per-tour persistence,
  legacy-key compatibility and revision-specific walk resume. No saved visits or
  narration bookmarks are deleted; reset changes only the active walk session.
- Recording metadata now lives in the selected catalog. Both existing audio/transcript
  hashes were checked successfully against bundled bytes. Missing recordings no longer
  prevent navigation; pending audio never silently falls back to synthesized speech.
- Native media tests updated to cover degraded availability. Native CI/device checks,
  generated-project comparison and the Apple-resolved lockfile remain pending.
- Final build 46 verification: 206 TourCore tests and 57 portable application-model
  tests passed; Debug/Release app/test syntax checks passed. Two narration files and
  their transcripts match the catalog SHA-256 manifest. These are not device results.

Publication:
The product owner explicitly approved publishing all changes to main and xcode-download.
This approval supersedes the earlier review-only publication gate; it does not establish
native CI success, on-site acceptance, App Store readiness, or permission to retire branches.
Build 46 retains the verification limitations documented above.
