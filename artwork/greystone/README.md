# Authoritative Greystone loose ink and watercolor

The owner approved the looser pen-and-ink drawing, then approved the new watercolor
after reviewing the previous and new versions side by side. These five source layers
now define the authoritative registered pair. The original owner-selected red-mill
watercolor remains the sole style reference. Greystone photographs establish the
subject architecture and colors.

The pair retains broken contours, uneven strokes, sparse surface description and
loose foliage; the draped flag/pole and partially obscured divided-pane arch window
remain. Earlier incidental roof details and side pipe removals remain in effect.

## App assets

| Asset | Approved content |
| --- | --- |
| `home-sketch-greystone` | Ink, transparent padding to 1536 × 1536 |
| `stop-ink-greystone` | Registered ink, 1536 × 1024 |
| `sketchbook-greystone` | Registered watercolor, 1536 × 1024 |
| `greystone-map-landmark` | Identical watercolor |

Both originals share the same final alpha and unchanged pen layer. Home padding
adds no scaling or cropping. `manifest.json` records source, raw ink/mask and approved
composite hashes. Do not regenerate ink or independently trim, scale or reposition
exports. For any future paint reveal, keep INK_MASTER, SUBJECT_BASE, WHITE_RESERVES
and ARTWORK_MASK stationary; reveal only WATERCOLOR_UNDERLAY. WHITE_RESERVES is a
frozen empty layer for this revision; light paint details are reserved in the underlay.

## Reproduction and rollback

```sh
python3 scripts/build-mill-artwork.py --landmark greystone
python3 scripts/build-mill-artwork.py --landmark greystone --write
```

The default verifies without writing. All four app slots must match reconstructed
pixels, dimensions, sRGB and catalog registrations. `loose-ink/` preserves the prior
ink-only implementation snapshot for provenance; there is no active ink override.
Earlier complete pairs remain in Git history. Reverting this implementation commit
restores the prior watercolor while retaining the already approved loose ink.

Build 125 candidate includes asset replacements only, with existing collection,
recognition, animation, provider and navigation behavior preserved. Native Xcode
compilation and iPhone visual checks remain pending before publication.
