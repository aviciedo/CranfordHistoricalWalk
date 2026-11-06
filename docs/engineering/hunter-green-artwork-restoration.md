# Hunter-green artwork restoration

Home and Stops use the ten original `home-sketch-*` and `stop-ink-*` PNGs
from `build-120`, restored byte for byte. Home's original artwork already
includes the green circle, so it does not receive a second outline.

The main map now requests every stop's illustration on both providers.
`StopMapArtwork` renders the same list-ink resources. Other uses of the shared
landmark component and the sketchbook watercolor resources are preserved.
Stops retains ink after a plaque unlock; the sketchbook still reveals color.

The active tour destination's map artwork is 15% larger than inactive artwork.
Apple and Google use the same scale function for drawing and collision layout.
Number badges keep their existing fixed screen sizes. Site coordinates,
leader anchors, route geometry, visit state and walking destination are unchanged.
Stops outside the visible geographic viewport remain offscreen until panned into
view; the change removes destination-only artwork suppression, not map panning.

Validation: 303 TourCore tests and 132 portable model tests passed. Core coverage
checks each of the five destinations with enlarged art, all five illustrations
visible, separate collision bounds and unchanged geographic anchors. Native
regressions now expect green Stops art after unlock while the sketchbook retains
its watercolor. Changed native sources parse in release/developer configurations.
All ten restored PNGs match build 120; sketchbook watercolors match HEAD.

Apple compilation and device visual acceptance remain pending. On Apple and
Google maps, check all five stops at overview and close zoom, rotate/pan near
map controls, advance/pause the tour, and verify only the actual destination's
artwork receives the modest enlargement. Check Home's single circle and all
Stops thumbnails before and after unlock. This work has not been published.
