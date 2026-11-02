## Current ink revision — build 126 candidate

The approved intermediate-detail ink with broken contours and removed circled fixtures
now supplies Home and Stops. `loose-ink/mill-ink.png` is the unchanged approved PNG;
`manifest.json` selects and hashes this ink override. Home adds transparent padding only.
The prior watercolor and its source layers below remain intact for maps and sketchbook.
The currently displayed ink and watercolor are separate approved revisions, not a
registered paint-reveal pair. Do not animate between them. Existing unlock rules remain.
Reverting this implementation commit restores the previous ink.

## Retained watercolor source pair

# Authoritative Droescher’s Mill artwork

The owner approved this registered ink/watercolor pair as the app's authoritative Mill
illustration. It replaces earlier Mill artwork in all four active asset slots.
Only the owner's selected red-mill watercolor illustration is the style reference;
the actual mill photograph supplies architectural facts and viewpoint.

## Fixed source layers

`INK_MASTER.png`, `SUBJECT_BASE.png`, `WHITE_RESERVES.png`,
`WATERCOLOR_UNDERLAY.png`, and `ARTWORK_MASK.png` retain the exact 1536 × 1024 canvas.
The master ink is reused unchanged in both final composites. The white-reserve layer
protects window details; the final mask defines identical alpha in both versions.
`manifest.json` freezes source hashes and placement. Do not regenerate or independently
trim these layers. `PROMPTS.md` records the reusable generation/assembly workflow.

## App assets

| Existing slot | Authoritative content |
| --- | --- |
| `home-sketch-mill` | Ink with transparent vertical padding to 1536 × 1536; no crop or scaling |
| `stop-ink-mill` | Original-size registered ink composite |
| `sketchbook-mill` | Original-size registered watercolor composite |
| `mill-map-landmark` | The same watercolor composite |

Home retains its existing circle presentation. Stops retains ink until the existing
plaque-unlock state selects watercolor. Sketchbook, maps and shared landmark artwork
keep their existing selection rules. No new paint-reveal animation is introduced.
The inactive legacy passport-stamp asset and historical design/export archives are
not current Mill artwork and are not references for future illustration work.

## Reproduce and verify

Install Pillow and NumPy in your Python environment, then run from the repository:

```sh
python3 scripts/build-mill-artwork.py          # Read-only verification
python3 scripts/build-mill-artwork.py --write  # Rebuild the existing app PNGs
```

Both canonical composites must keep the same dimensions and byte-identical alpha.
The Home derivative is display-only and must not be used as a paint-reveal layer.
Keeping the same asset names preserves catalog mappings, image-cache keys, unlock
history and every other tour stop. Git history before this change is the rollback.
