## Current ink revision — build 124 candidate

The owner approved the new loose broken pen-work and requested implementation, followed
by watercolor review. `loose-ink/` preserves the approved new ink, base, reserves, mask,
composite and frozen hashes. `manifest.json` selects this as an `ink_override` for Home
and Stops. Home adds the same transparent square padding without scaling.

The prior approved watercolor still supplies the map and sketchbook. The older source
layers below remain immutable for reproduction and rollback. The app currently displays
two separately approved revisions; they are **not** a registered animation pair.
The new registered watercolor proposal is outside the app pending visual approval.
Do not use the prior watercolor with the new ink for a paint-reveal transition.
Revert this revision's Git commit to restore build 123 artwork selection.

# Authoritative Greystone artwork

The owner approved the latest roof-repair review and requested app implementation.
These five frozen source layers are the authoritative Greystone artwork. Prior
Greystone illustrations and review variants are historical, not style authorities.
The original owner-selected red-mill watercolor remains the sole style reference;
the supplied Greystone photograph provided the subject architecture and colors.

## Approved features

- Rounded bushes partially obscure the lower-right arch window.
- The arch contains a divided-pane window based on neighboring windows.
- The original draped American flag and its pole are retained.
- Marked incidental roof features, the right-side pipe and isolated twigs are removed.
- Left roof coverage and right gable joins follow the approved repaired drawing.

`manifest.json` records approval context, source hashes, full-canvas pixel hashes
and the approved composite file hashes. Do not regenerate the ink or independently
trim, resize or reposition any source layer.

## Existing app slots

| Slot | Approved content |
| --- | --- |
| `home-sketch-greystone` | Ink, centered with transparent padding to 1536 × 1536 |
| `stop-ink-greystone` | Registered ink at 1536 × 1024 |
| `sketchbook-greystone` | Registered watercolor at 1536 × 1024 |
| `greystone-map-landmark` | The identical watercolor composite |

Home's derivative is not a paint-reveal master. Use the original-size pair or the
unchanged `INK_MASTER`, `WHITE_RESERVES`, `SUBJECT_BASE`, `WATERCOLOR_UNDERLAY` and
shared `ARTWORK_MASK` for any future reveal work. No animation behavior is changed
by this asset replacement. Light subject reserves remain distinct from transparency.

Existing plaque-unlock rules, saved progress and image names are retained; photographs
and AR recognition reference images are untouched. All other tour artwork is preserved.

## Rebuild or verify

With the Python dependencies in `requirements.txt` installed:

```sh
python3 scripts/build-mill-artwork.py --landmark greystone
python3 scripts/build-mill-artwork.py --landmark greystone --write
python3 scripts/build-mill-artwork.py # Verify the retained Mill assets
```

Default mode verifies without writing. Source hashes, exact composite pixels,
matching alpha, sRGB interpretation, square Home padding and catalog registration
are checked. Transparent RGB is preserved to match the approved exported files.

The parent commit retains the previous app artwork for rollback. This candidate
requires native build checks before publication and visual verification on iPhone.
