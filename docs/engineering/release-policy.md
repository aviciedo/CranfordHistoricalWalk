# Release authority and verification

`main` is the authoritative release history. At the start of consolidation the published
baseline is build 110, `41053f10e661130b53ded2e5de32a444b1381f83`.
The approved unpublished starting point is build 114,
`ab88ae5b16d2185a3d1f287659e362790ffd29ce`.

## Required gate

1. Keep changes in small committed increments. Use `validation/**` for the exact candidate.
2. Apple compiler checks must succeed on that exact commit: TourCore, actual model flows,
   Simulator build/native tests, and iPhone Release build. Linux parsing is not this gate.
3. Preserve the approved field-test checklist; record untested device behavior honestly.
4. Promote the same verified commit to main by fast-forward only. No force pushes.
5. The existing stabilization and xcode-download release aliases may follow that commit;
   do not independently develop or merge conflicting features on those aliases.
6. Record an immutable release tag/archive. Do not delete old branches as part of release.

Recommended repository setting: protect main, require the `apple-toolchain` check,
require review and disallow force pushes/deletions. GitHub API/connector settings access
is not available in this environment; this document does not claim those server-side
settings have been applied.

## Proposal branches

The audit found 22 Cursor heads. Their complete inventory is in
`branch-audit-2026-10-31.json`. Most are old one-commit proposals, sometimes production
refactors disguised by a coverage title. Review changes individually against current
requirements. In particular PR #23's empty drawn-route policy is obsolete: retain the
approved river-blue dotted route and solid hunter-green walked trail.

Do not merge a branch simply to get a green check. Keep the original five stops, narration,
plaque unlock history, phone-down exit, and all declined UX proposals unchanged.
