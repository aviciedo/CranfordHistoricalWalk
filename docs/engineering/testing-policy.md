# Testing policy

Owner direction, 2026-11-08: optimize routine development for speed. Comprehensive
testing is opt-in when the user requests **perform comprehensive testing**. Mentioning
the phrase while setting this policy does not start a test run.

## Routine development

Review the affected code and diff. Use quick checks appropriate to the change:
whitespace/conflict checks, parsing edited configuration, or a small relevant existing
test when it is inexpensive. Do not launch full suites, install testing dependencies,
start a test container, or wait for remote CI by default. Implementation, commit,
push, publication and Xcode-download requests are not comprehensive-test requests.
State checks performed accurately and disclose material uncertainty.

## Comprehensive testing, on explicit request

Keep existing test code and tools available. Run the appropriate broad suites and
manually dispatch both `.github/workflows/apple-build.yml` and
`.github/workflows/swiftlint.yml` for the exact candidate commit/ref. Each requires
the input `confirmation: perform comprehensive testing`. Their heavy jobs run only
when that input matches. Neither workflow runs on push or pull request.

The Apple workflow covers TourCore, actual app-model flows, Simulator compilation
and native tests, and iPhone Release compilation. SwiftLint retains its pinned tool,
reviewed rules and baseline. Report any skipped/failed checks. CI does not replace
physical iPhone checks for outdoor AR alignment, GPS, camera recognition or touch feel.

## When to recommend it

Comprehensive checks are strongly suggested before public release, after dependency
or Xcode/build configuration changes, and for changes to AR/ARCore, permissions,
maps/routing, persistence/migrations, saved progress, audio/session lifecycle,
concurrency or difficult regressions. Tie the recommendation to the actual change.
Recommend rather than automatically run; wait for the explicit request.

## Release and historical guidance

The owner has removed comprehensive testing as a blanket publication gate. Preserve
explicit publication authorization, honest verification reports, fast-forward-only
release history and immutable release archives. Older build/checklist statements
requiring Apple/SwiftLint for every candidate are historical and superseded here.

GitHub branch-protection settings are separate from workflow triggers. This change
does not claim to modify server-side required checks. If existing protection blocks
a requested publication, report that actual blocker and resolve it with the owner;
do not bypass protection or silently claim those checks passed.
