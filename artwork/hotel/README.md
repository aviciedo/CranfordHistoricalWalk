# Authoritative Cranford Hotel artwork — build 129 candidate

The owner explicitly selected the earlier refined ink image, then approved its watercolor
and requested app implementation. The subsequently generated looser impressionistic
variant is historical and is not this pair. The original red-mill-and-river illustration
remains the sole style authority; hotel photographs provide subject colors and facts.

## App slots

| Asset | Approved content |
| --- | --- |
| home-sketch-hotel | Ink, transparent padding to 1536 × 1536 |
| stop-ink-hotel | Registered ink, 1536 × 1024 |
| hotel-map-landmark | Registered watercolor, 1536 × 1024 |
| sketchbook-hotel | Identical watercolor, collected through Hotel plaque recognition |

The owner subsequently supplied and approved the oval Established 1882 plaque as the
Hotel recognition target. Home keeps ink; Stops switches to watercolor after a valid
plaque unlock, and the Hotel becomes a collectible sketchbook page. Visits, narration
and opening the scanner alone do not award it. The existing reveal and persistence
behavior is reused; no new animation is introduced. The map keeps the watercolor.

The real supplied photo is cropped without resampling or generative processing. Its
original, crop coordinates, hashes and unmeasured 0.30 m reference-frame width are
recorded under docs/field-references/cranford-hotel-plaque.*. This is an initial testing
estimate, not a physical measurement; ARKit image-scale estimation remains enabled.

## Frozen sources and verification

The five full-canvas layers and manifest reproduce the approved exports. INK_MASTER
retains the selected draft's raw RGBA pixels unchanged. White subject base, selective
white structural reserves and final mask are separate layers. Both composites use
identical final alpha; Home adds transparent padding at (0, 256) without scaling/cropping.
No source layer is independently resized, translated, rotated or warped.

```sh
python3 scripts/build-mill-artwork.py --landmark hotel
python3 scripts/build-mill-artwork.py --landmark hotel --write
```

Only reveal WATERCOLOR_UNDERLAY beneath stationary ink, reserves, base and mask in any
future paint reveal. Keep the original registered pair unchanged. The manifest records
source hashes, raw ink/mask hashes and approved composite hashes. Prior artwork remains
in the parent Git commit for rollback. Photos, AR reference images, coordinates, saved
progress, narration, provider modes and navigation behavior remain unchanged.

Local pixel, alpha, sRGB, padding and catalog checks pass. Native Xcode compilation and
iPhone visual checks remain pending before publication. This candidate is not published.
