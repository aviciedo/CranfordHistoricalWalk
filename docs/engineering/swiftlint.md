# SwiftLint setup and policy

Run these commands from the repository root on a Mac with Xcode installed:

```sh
scripts/install-swiftlint.sh
.build/tools/swiftlint/swiftlint version
.build/tools/swiftlint/swiftlint lint --config .swiftlint.yml --strict --cache-path .build/swiftlint-cache
```

The installer pins official SwiftLint 0.65.1 release archives and checks their SHA-256
digests before extraction. Binaries, archives, cache and logs live in ignored `.build`.
No Homebrew upgrade, app package dependency, Xcode Run Script phase or sandbox setting
change is required. The installer also supports Linux; for a Linux environment without
a usable SourceKit runtime, add `--disable-sourcekit` to the lint command. All five
enabled rules are syntax-based and do not require SourceKit. macOS CI remains authoritative.

## Initial scope

Only app production sources in `CranfordHistoricalAR` and package production sources
in `Packages/TourCore/Sources` are checked. Tests are outside the initial policy.

| Rule | Purpose |
| --- | --- |
| `force_cast` | Flag casts that can crash on an unexpected type. |
| `force_try` | Flag forced error handling that can crash on failure. |
| `duplicate_imports` | Catch repeated imports. |
| `unused_closure_parameter` | Flag named closure arguments that are never used. |
| `weak_delegate` | Flag delegates that should avoid strong ownership cycles. |

The first review found zero violations across 90 files. The committed baseline is empty;
it does not hide existing warnings. `--strict` makes new warnings fail the check.
Lint cannot prove lifecycle correctness, memory safety, GPS accuracy or AR stability.

Fix a reported issue in its source and rerun the command. Do not run automatic fixes
across the project or regenerate the baseline just to get a green check. If a legacy
exception is deliberately approved, review the full findings before manually writing
a replacement baseline, then review and commit its diff:

```sh
.build/tools/swiftlint/swiftlint lint --config .swiftlint.yml --no-cache --write-baseline .swiftlint-baseline.json
```

Keep complexity, file-length and formatting rules deferred until a separate reviewed
change; adding rules can expose existing findings and should not trigger a mass rewrite.

## Continuous integration

`.github/workflows/swiftlint.yml` installs the pinned tool on macOS and runs strict lint
with GitHub annotations. It never fixes code or updates the baseline. Both push and
pull-request filters cover sources, policy, baseline, installer and workflow changes.
The existing Apple build/test gate remains separate and also runs for lint setup changes.

The recommended protected-branch checks are `apple-toolchain` and `swiftlint`.
Repository owners must configure protection in GitHub settings; this setup does not
claim those server settings were changed. No Maestro or snapshot-testing setup is added.
