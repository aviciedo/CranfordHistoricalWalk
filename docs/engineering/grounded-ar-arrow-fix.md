# Grounded AR arrows — build 131 candidate

## Field evidence and causes

The reported screenshots show (1) an upright stack of arrows with approximate
ground height and (2) a camera-relative fallback explicitly labelled "Maneuver
preview · Not aligned to the street", over a lawn. The renderer deliberately
authored a vertical XY sign, with an additional 30-degree presentation tilt,
and placed its bottom above the estimated surface. Only its front cap was white.
The fallback placed a new sign along the phone's viewing direction and reset
that placement when looking elsewhere. It was not a registered street anchor.

## Changes

- Ground markers use route yaw and a fixed -90-degree floor rotation. The artwork
  has no presentation tilt or camera-facing orientation. Its bottom rests 1.5 cm
  above the measured surface to avoid z-fighting.
- Both caps use opaque white material with outward winding. Hunter-green sidewalls
  retain the existing extrusion depth, with sampled corner curves and quarter-circle
  top/bottom bevels rather than only clipped 2D corners.
- A close approach or lateral walk around the marker retains its pose. Looking
  behind it does not hide or turn it upright. Progressing more than three metres
  beyond the marker, or a settled route change, can place the next marker.
- Removed the camera-relative 3D fallback. Missing alignment keeps the existing
  on-screen maneuver card and map guidance; it does not create a lawn/sky anchor.
- Geographic confidence and measured horizontal ground are both required before
  rendering route markers. Estimated phone height no longer supplies a route surface.
- Re-entry, session stop and relocalization discard world poses and measured ground.
  Ground must be acquired again; provider GPS/compass/VPS confidence gates remain.
  The upstream default ARCore/consent/Apple-fallback configuration is preserved.

## Validation and limits

Portable tests cover mesh closure, unit normals, cap winding, intermediate bevel
normals, fixed poses through a full 360-degree walk around, close approach and
advancement after passing. Native regressions cover horizontal cap orientation
for all directions, ground clearance, two white caps per arrow, no unregistered
fallback, measured-ground gating, session reset and relocalization.

Native checks run on the exact validation candidate before any release promotion.
This candidate also contains the already approved three-stop artwork changes.
It is not a publication of main or an immutable release tag.

ARKit horizontal planes do not identify streets, and GPS/compass/VPS can still
have positional error. Grounded rendering and withholding unaligned previews
address the observed failures; they do not establish survey-grade street placement.

## Required physical iPhone retest

1. Enter AR while facing the street; acquire alignment and scan the ground. Arrows
   should rest flat with green rounded sidewalls and a white upper face.
2. Approach from the left and right, walk beside and behind the marker, and look
   around it. The marker should remain fixed and horizontal; advancing beyond it
   should produce a new route marker rather than a camera-following sign.
3. Dismiss/reopen while facing a lawn, then the street. Withhold world arrows
   until route alignment and measured ground are valid; keep the maneuver card.
4. Repeat after interruption/backgrounding and lost tracking, at a turn, and with
   Apple only, Google only and Google with Apple fallback. Confirm the known
   phone-down map return, plaque recognition and tour progression still work.

Physical placement/appearance remains unverified until this field retest.
