# AR chevron sidewall refinement

Appearance-only follow-up to build 118's field-confirmed working arrows. The owner
confirmed deeper hunter-green sidewalls, preserved white-face shape and approximately
the current display size, with navigation and placement behavior unchanged.

- Extrusion grows from 0.25 m to 0.72 m in the existing artwork's model units.
- A fixed 30-degree artwork yaw exposes the sides on initial presentation. It is a
  child transform inside the arrow entity; route yaw and world anchor pose are unchanged.
- Spacing grows from 1.36 to 1.75 model units so the deeper silhouettes remain distinct
  at the presentation angle. Existing uniform viewport fitting constrains display size.
- A cached 16 × 256 hunter-green gradient provides consistent visible depth in outdoor
  shade. Unlit material preserves the authored green; the white faces remain unlit white.
  A texture-generation failure falls back to a solid hunter-green material.
- Existing chamfered outline, white front geometry, direction mapping, copy, placement,
  confidence gates, fallback behavior, tracking, plaque recognition and progression remain.

The engineering projection in `.build/design-review/ar-chevron-depth.png` compares
geometry, not a native iPhone capture. Do not treat it as proof of final AR rendering.
Native tests check mesh creation and three textured green bodies plus three white faces;
portable tests check extrusion, face geometry, separation, direction and viewport fitting.

On iPhone, check right/left/ahead/diagonal arrows in sunlight and shade, confirm broad
sidewalls and white faces remain legible, and rotate/walk around them to verify true
extrusion. Verify the group fits between the existing header and maneuver card and that
its anchor, recovery behavior and navigation remain consistent with build 118. Final
visual appearance and texture orientation require this native-device inspection.

No dependency or navigation framework is added. No Google artwork or proprietary
positioning implementation is copied.
