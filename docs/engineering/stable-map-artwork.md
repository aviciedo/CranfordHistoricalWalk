# Stable illustrated map — build 132 candidate

The supplied recording demonstrated manual pan, pinch and rotation. Stateless screen-space
collision solving and whole-tour size reduction made artwork pulse and jump. The fixes apply
to both Google Maps and the Apple fallback.

- Native numbered pins stay at their canonical coordinates with 44pt targets. Active visible
  numbers are 32pt; inactive numbers are 26pt. Artwork is a separate cached overlay. It is touch-transparent; a simultaneous, non-cancelling
  tap recognizer on the map selects artwork without intercepting native pan/pinch/rotation.
- Active artwork is 96pt wide and inactive artwork 64pt, independent of zoom, selection and visits.
- A shared layout state retains per-stop offsets during camera motion. After 200ms idle, valid
  placements remain; only conflicts are reconciled. Active artwork has priority. Ordinary
  corrections animate for 180ms; Reduce Motion applies them immediately.
- In exceptionally dense clusters, choose the least obstructed local slot at full size instead
  of shrinking/hiding the entire tour. Badge cutouts and tap exclusions protect canonical pins.
  Coincident pins remain geographically truthful; clustering is a separate product decision.
- Manual gestures invalidate pending camera fits, including initial zero-bounds retries.
  Stop selection no longer automatically pans the Google camera.
- GPS-driven follow uses the inner 70% of the visible viewport as a dead zone and preserves
  bearing and zoom. Explicit recenter bypasses it. Route arrival/replacement and explicit
  navigation can still fit the walking leg; ordinary position changes no longer refit the leg.

## Checks before release

Replay the supplied gestures on physical iPhone with Google and Apple: fast zoom reversals,
rotation, dragging at edges, and close downtown clusters. Verify every active stop, all five
hunter-green drawings, number/art taps, popup dismissal, recenter, stationary GPS jitter,
narration-footer resizing, background/foreground return, VoiceOver and Reduce Motion.
Native CI is a compiler/test gate, not proof of on-device frame rate or gesture fidelity.

Do not promote this candidate or change release aliases without a publication request.
