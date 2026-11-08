# Repository working instructions

## Testing policy — owner direction, 2026-11-08

Default to a fast development loop. Do not run Apple compiler/build workflows,
Simulator/native tests, iPhone Release builds, SwiftLint, full TourCore or app-model
suites, broad regression/integration tests, or other expensive verification unless
the user explicitly requests **perform comprehensive testing** as an action.
Quoting the phrase to discuss or define this policy is not a request to run it.
A request to implement, commit, push, publish, or provide an Xcode download does not
implicitly authorize comprehensive testing.

For ordinary changes, inspect the affected code/diff and use only quick, relevant
checks such as `git diff --check`, configuration parsing, or a narrowly targeted
existing test when needed and inexpensive. Do not install tools, start containers,
or run/poll CI solely to perform routine verification. Avoid broad test runs for
small UI, copy, artwork or documentation changes. Report what was actually checked
and any material remaining uncertainty; never label skipped checks as passed.

When the user requests **perform comprehensive testing**, run the appropriate
comprehensive suites and both manual GitHub workflows (Apple compiler checks and
SwiftLint) on the exact candidate commit, passing that phrase as the `confirmation`
workflow input. Report results and distinguish device-only field checks from CI.

Recommend comprehensive testing before a public release or after changes involving
AR/ARCore, camera/location permissions, maps/routing, persistence/migrations, saved
progress, audio lifecycle, concurrency, dependencies, Xcode/build configuration, or
a hard-to-reproduce regression. Explain the specific benefit briefly. A recommendation
alone does not authorize running it; continue the requested work with quick checks.

This policy supersedes older mandatory Apple/SwiftLint gate language in historical
build notes, artwork checklists and validation documents. See
[testing-policy.md](docs/engineering/testing-policy.md) and
[release-policy.md](docs/engineering/release-policy.md).
