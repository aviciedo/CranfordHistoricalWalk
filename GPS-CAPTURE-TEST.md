# GPS capture tools — review build 55

Confirmed scope: multiple labeled readings per stop; copy and CSV sharing. Only the
marked developer tools were retired. Real GPS, narration, tour testing/resets,
diagnostics, historical content and the AR bonuses remain available.

Removed:
- Simulated location toggle, speed/accuracy controls and dependent fake movement buttons.
- Mill viewing-point save/clear shortcut and its special story-arrival override.
- Mill and Greystone bonus-alignment sliders and reset actions. Existing valid stored
  placements remain read-only to preserve working bonus positions; no alignment editor remains.
- Reusable simulation services stay in the test infrastructure so practice isolation
  can still be tested. Xcode-simulated readings are detected and rejected for capture.

New flow:
1. Open Developer Controls, allow GPS if needed, and use Refresh GPS now.
2. Under Capture GPS location, choose the relevant stop and enter an optional label.
3. Save GPS reading. An empty label receives a local Capture number. The record stores
   a UUID, tour/version, stop ID/name, label, latitude/longitude, reported accuracy,
   GPS-fix timestamp, saved timestamp and Precise Location status.
4. Repeat with new fixes/labels. Stored GPS captures lists readings for the chosen stop.
5. Copy reading includes its context/accuracy/times. Copy all and Share all readings as
   CSV include this tour's records across its stops. The native share sheet exports a
   real UTF-8 CSV file named Cranford-GPS-captures.csv. Nothing is sent automatically.
6. Swipe a reading to reveal Delete; full-swipe deletion is disabled. Tour activity
   resets retain these readings. Deleting a capture changes only this log.

Capture rules:
- Authorized device GPS, valid coordinates, nonnegative finite accuracy and an actual
  fix younger than 30 seconds are required. Simulated sources/fixes are rejected.
- One fix cannot be repeatedly saved against the same stop; Refresh GPS gets a new fix.
- Weak valid accuracy and reduced precision can be recorded for testing. Their actual
  metadata is kept; the feature does not pretend the GPS is more accurate than reported.
- Capture location is not constrained to the stop geofence: readings can document
  public approaches, entrances or suspected coordinate errors. Tagging a stop is not a visit.
- Captures are independent test data. They never change catalog coordinates, routing,
  visit/story/bonus state or live arrival thresholds. No continuous GPS trail is stored.
- The old mill coordinate imports once as Legacy viewing point. Its original fix time
  and permission were not stored, so they remain unknown; import time is labeled saved time.
- Existing storage is kept if decoding/version validation fails; new writes are blocked
  rather than overwriting unreadable data. Tour resets do not erase the capture archive.

Verification performed:
- 227 TourCore tests pass, including 8 new record/archive/CSV tests.
- 82 actual application-model tests pass, including 10 new capture-controller tests:
  multiple saves/reload, duplicate/stale/invalid/simulated rejection, weak accuracy,
  corruption/future schemas, one-time legacy import/deletion, reset independence,
  CSV file/error handling, tour isolation, permission denial and fresh-fix refresh requests.
- Debug and Release Swift syntax parsing passes. Source checks confirm removed editors
  and simulation-controller entry points are gone. The actual Foundation-only developer
  controller is included in the portable test harness, rather than replaced with a mock.

Native acceptance — NOT RUN on this Linux host:
- Build/test with the Apple SDK; verify both Debug and Release configurations.
- Capture multiple real fixes at two stops; verify actual accuracy/times, relaunch and
  selected-stop filtering. Test stale/weak/reduced-precision/denied/Xcode-simulated cases.
- Confirm no removed section or movement shortcut remains and both bonuses retain
  existing placement. The old mill override must not control story arrival.
- Copy a reading into Notes and share CSV to Files. Check Unicode, commas/quotes in
  labels, negative longitude, UTC timestamps and explicit unknown legacy metadata.
- Check labels, selection, scrolling, deletion and Share/Cancel/Back/Home behavior on
  a small iPhone, large Dynamic Type and VoiceOver. Confirm an export error keeps the log.
- Clear visits, then clear all activities: captures must survive both operations and
  relaunch. Navigation/audio must remain independent. Do not mark these cases passed
  without physical-device evidence.
