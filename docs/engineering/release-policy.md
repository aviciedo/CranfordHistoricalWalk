# Release authority and verification

`main` is the authoritative release history. At the start of consolidation the published
baseline is build 110, `41053f10e661130b53ded2e5de32a444b1381f83`.
The approved unpublished starting point is build 114,
`ab88ae5b16d2185a3d1f287659e362790ffd29ce`.

## Current development and release policy

The owner's 2026-11-08 [testing policy](testing-policy.md) supersedes the previous
blanket Apple/SwiftLint gate. Comprehensive testing runs only when explicitly
requested with **perform comprehensive testing**. Publication alone does not request it.

1. Keep changes in small committed increments; use a candidate branch for review.
2. Perform quick, relevant checks by default and report verification accurately.
   Do not run Apple builds/native tests, SwiftLint or broad suites automatically.
3. Strongly recommend comprehensive testing before public release or for changes to
   AR, permissions, routing, persistence, audio/concurrency, dependencies or build
   configuration. Do not run it until explicitly requested. When requested, verify
   the exact candidate commit with both manual workflows and the relevant suites.
4. Preserve approved field-test checklists; record untested device behavior honestly.
5. Publish only with user authorization. Promote the candidate to main by fast-forward
   only. No force pushes. State whether comprehensive testing was performed or skipped.
6. Existing stabilization and xcode-download aliases may follow that same commit;
   do not independently develop or merge conflicting features on those aliases.
7. Record an immutable release tag/archive. Do not delete old branches as part of release.

Keep main protected against force pushes/deletions. Mandatory comprehensive status
checks are no longer the default recommendation under this opt-in policy. Server-side
branch settings are separate; this change does not claim to have updated them. Report
any actual protection blocker rather than bypassing it.

## Proposal branches

The audit found 22 Cursor heads. Their complete inventory is in
`branch-audit-2026-10-31.json`. Most are old one-commit proposals, sometimes production
refactors disguised by a coverage title. Review changes individually against current
requirements. In particular PR #23's empty drawn-route policy is obsolete: retain the
approved river-blue dotted route and solid hunter-green walked trail.

Do not merge a branch simply to get a green check. Keep the original five stops, narration,
plaque unlock history, phone-down exit, and all declined UX proposals unchanged.
