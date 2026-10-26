# Apple build/test email repair

The email's "Apple compiler checks" name covers both builds and tests. The initial
[diagnostic run](https://github.com/aviciedo/CranfordHistoricalWalk/actions/runs/40260051243)
compiled the shipped simulator Debug project and the iPhone Release app successfully.
Its simulator test execution failed on four assertions in three outdated tests:

1. `AppConfigurationTests.testDirectionsFactoryFallsBackWhenKeyMissing` expected a
   missing Google key to throw. The factory intentionally uses Apple's real walking
   directions in that situation. The test now injects an offline Apple-provider
   fixture and verifies route source, endpoints and caching. Production callers
   still default to `AppleWalkingDirectionsService`; routing behavior is unchanged.
2. `NarrationPlayerTests.testPreviewCreatorStopsMatchTheBundledContent` compared raw
   preview stops to stops decorated by the recording installer. The loaded stops
   carry validated recording checksums; previews did not. Both inputs now undergo
   the same audio/transcript validation before full equality is asserted. This does
   not ignore checksum differences or weaken transcript validation.
3. `StopVisitStoreTests.testDeveloperClearResetsSavedVisitsAndProgressAndPausesSimulator`
   seeded an old recognized-plaque record, then expected a fresh award. Saved plaque
   evidence is deliberately migrated into a collected bonus; recognition correctly
   returns `alreadyActivated`. The renamed test asserts this and explicitly checks
   that visit-only reset preserves reading and bonus/stamp progress while clearing
   visits, itinerary counters and simulated movement.

No test was skipped or removed to obtain a passing run. Existing visit, story,
bonus, playback and route behavior is preserved. The test seam is one optional
factory parameter, with the original real Apple provider as its default.

## Workflow improvements

- Publications had pushed identical commits to main and stabilization, triggering
  the same macOS check twice. Push CI now runs once on main; PR and manual checks
  remain enabled. No branch was deleted, merged or force-pushed.
- `actions/checkout@v5` and `actions/upload-artifact@v6` replace Node 20 actions.
- Release compilation runs even after a native test failure, if simulator compilation
  succeeded, so one failing test cannot hide a Release build problem.
- `scripts/summarize-apple-checks.py` extracts xcresult test errors into the run
  summary/public annotations and retains original logs and result bundles for seven
  days. Original build/test exit codes determine the job result; reporting does not
  mask failures. Simulator launch telemetry is not treated as a test assertion.
- Changes to bundled audio now trigger checks too.

## Verification

Final source verification run:
https://github.com/aviciedo/CranfordHistoricalWalk/actions/runs/40261422454

Result: succeeded on source commit `fec99fd78456be270b95dbe285c69fec7b0d6d79`.
- 232 TourCore tests on Apple Foundation/CoreGraphics: passed, zero failures.
- 145 native iOS host-app tests on iPhone Simulator: passed, zero failures.
- Shipped Xcode project simulator Debug build-for-testing: passed.
- iPhone device Release build with signing disabled: passed.
- Diagnostic summary and artifact upload: passed; no errors or deprecation warnings.
  The remaining hosted-runner capacity notice is informational.

Debug/Release Swift syntax checks, diagnostic extraction/annotation escaping checks,
and shipped recording/transcript checksum checks also passed locally. Documentation
updates after that run do not change the verified app, tests or workflow.

A green workflow validates the compiled project and automated tests. It does not
replace real-device outdoor AR, GPS or screenshot acceptance. Future genuine test
failures should continue to produce GitHub notifications.
