# Authoritative Church artwork — build 127

The owner approved the watercolor reference refinements after reviewing before/after
comparisons for all three stops, and requested implementation and publication.
The five canonical layers in this folder define the current registered pair.
`manifest.json` freezes their hashes and canvas; no ink override is active.

Verify or reproduce the four app asset slots:

```sh
python3 scripts/build-mill-artwork.py --landmark church
python3 scripts/build-mill-artwork.py --landmark church --write
```

Keep INK_MASTER, SUBJECT_BASE, WHITE_RESERVES and ARTWORK_MASK stationary for future
paint reveal work. Reveal only WATERCOLOR_UNDERLAY underneath the locked ink. Both
original-size exports use identical alpha. Home adds transparent square padding only,
without scaling or cropping. Never independently transform registered exports.

The fixed ink, base, reserves and mask remain byte-identical to the preceding approved version. Only the watercolor underlay changes.

Church remains without a recognition target. Home/Stops show ink; the map shows watercolor. The watercolor is also bundled for future sketchbook use, without adding collection eligibility.

The original owner-selected red-mill illustration is the sole style authority. Actual
subject photographs supply architecture/material colors. The critique, accepted
methods and generation prompts are in `docs/design/watercolor-reference-refinement`.
Any `loose-ink/` snapshot is historical provenance, not the active pair. Previous
versions remain in Git history for rollback. Recognition targets, saved progress,
provider modes, navigation, collection and animation behavior remain unchanged.

The local artwork checks pass. Native Apple checks must pass on the exact candidate
before main promotion, under docs/engineering/release-policy.md. Publication status
must be established from the release record, not this artwork approval.
