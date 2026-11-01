# Active stop marker hierarchy

The tour's current/next stop has a 40pt numbered circle; other numbered circles are 26pt. This applies before starting, while walking, and when paused. Tapping or browsing another stop does not transfer the larger circle. A previously visited current destination still gets the larger circle. A completed tour has no active destination.

`MapViewModel.markers` derives `isTourDestination` independently of visited status and the walking-only blue color. All stops use the same rule; there are no stop-ID cases. Selection remains a callout interaction. Existing white/hunter-green styling and river-blue walking styling are preserved.

The illustrated marker formerly shrank its number with the entire landmark, while compact numbers stayed fixed. `StopMapIconView` now composes a zooming illustration with a separate 44pt badge image/touch envelope. The badge stays 40pt/26pt at every camera scale. Google and Apple maps share the renderer and reserve the full badge extent during collision layout, preserving canonical stop locations, leader lines, and map-control clearance. Compact markers retain 44pt touch targets. Extreme coincident clusters may shrink illustrations while keeping the circles readable.

Validation includes actual tour-model flows through every stop (walking, paused, visited, selected, completed), existing collision/viewport tests, and native raster checks measuring the rendered circles and verifying badge bounds at multiple zoom scales.

On iPhone, check both Continue walk and active walking screens at wide and close zooms. Tap an inactive stop, advance to each destination, pause/resume, and revisit a visited stop. The destination must remain largest; its predecessor must become small after advancement. Confirm no clipped badge, duplicate number, changed route, or inaccessible tap target. Check the Apple fallback map as well when available.
