# Authoritative First Baptist Church artwork

The owner approved the loose, broken pen-and-ink composition, then the registered watercolor pair, and requested implementation. The original approved red-mill watercolor is the sole artistic style reference. The church photograph supplies architecture and material colors. Earlier church review variants are historical.

## App assets

| Asset | Content |
| --- | --- |
| `home-sketch-church` | Approved ink, transparent padding to 1536 × 1536 |
| `stop-ink-church` | Original registered ink, 1024 × 1536 |
| `first-baptist-church-illustration` | Original registered watercolor, 1024 × 1536 |
| `sketchbook-church` | Identical watercolor, reserved for future sketchbook integration |

The church has no approved plaque recognition target. Its existing catalog mappings and unlock rules are preserved: Home and Stops show ink, the map shows watercolor, and the church is not a collectible sketchbook page. Merely bundling watercolor must not grant collection or invent a recognition target. No animation behavior changes are included.

## Frozen layers and reproduction

`manifest.json` records approved source hashes, raw ink/mask hashes and final composite hashes. All five canonical source layers retain their original 1024 × 1536 canvas and pixel data. Both registered outputs use unchanged ink and the same alpha mask. Home adds transparent padding at (256, 0), without resizing or cropping. White subject reserves remain opaque, distinct from the exterior transparency.

```sh
python3 scripts/build-mill-artwork.py --landmark church
# Deliberately rebuild the existing slots:
python3 scripts/build-mill-artwork.py --landmark church --write
```

Keep ink, reserves, base and mask stationary during any future paint reveal. Reveal only WATERCOLOR_UNDERLAY underneath the locked ink. Do not independently crop, scale or regenerate either composite. The removed chimney, entrance light and both side spouts remain absent.

The preceding Git commit retains previous artwork for rollback. Mill/Greystone assets, photos, AR targets, provider behavior and saved progress are unchanged. Native compilation and iPhone visual checks remain required before publication.
