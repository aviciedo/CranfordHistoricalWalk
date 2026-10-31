# Stability acceptance on a physical iPhone

These checks are pending until performed outdoors. Do not replace them with syntax parsing.

## Mill → Greystone progression

- Debug build: open Developer Controls → Walking progression. Start a new walk; confirm the
  current destination and blocker list. The local trace is bounded and contains no coordinates.
- Stand in the public Mill viewing area with precise, fresh GPS. Confirm arrival after the
  reliable near fixes, but no early physical visit. Check near-stop seconds over three minutes.
- With noisy/sparse GPS, verify the trace explains incomplete dwell rather than claiming success.
- Open/close stop details, sketchbook, camera/AR and the app switcher. Verify holds release and
  completion advances exactly once when Map is active. Previous/Undo must hold against a cascade.
- Separately verify plaque recognition, narration completion from another location, and walking
  toward Greystone bypass the dwell as approved. Walking away in another direction must not.
- Stop/resume and relaunch. Verify restored walk is paused, collections survive, and session-local
  dwell/trail behavior is clear. No false visits on weak or simulated GPS.

## Routing, map and AR

- Follow all five stops, including a real turn and a deliberate short backtrack. Cues, remaining
  distance, dotted route and AR use the same destination. Upcoming dots are lighter river blue;
  the accepted trail is solid hunter green. Stop hides dots and preserves the recorded trail.
- Rotate the phone 180°, lower it face-up for two seconds after raising, then reenter AR.
  Verify exit/reentry keeps the walking destination and clears AR presentation holds.
- Test network loss/recovery, weak compass/GPS, denied permissions and app backgrounding. AR
  arrows must disappear when alignment is unreliable; map navigation must remain recoverable.
- Open every sketch directly, turn forward/back, stop mid-curl, enable Reduce Motion and large
  text. Confirm matching parchment, no white exposed surfaces and no crash.
- Verify white/green serif badges; only the active destination becomes blue/white. Change legs
  and pause/resume repeatedly to exercise cached marker refresh.

## Performance and release

- Use Instruments on a supported iPhone: repeated AR entry, an extended walk, a long trail,
  memory warnings and foreground Home after stopping. Record frame rate, memory and energy;
  do not claim 60 FPS or acceptable battery usage until measured.
- Run Apple CI for the exact release SHA and inspect all native test results. Check the shipped
  Xcode project, not just a regenerated local copy. Preserve the known-good release tag.
