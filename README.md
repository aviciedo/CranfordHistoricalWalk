# Cranford Historical AR

A SwiftUI + ARKit/RealityKit + Core Location + Google Maps walking-tour MVP for Cranford, New Jersey.
Walk toward a historical site, follow AR arrows, and a large AR historical sign appears when you arrive.

> All stops shipped in this repository are **SAMPLE LOCATIONS** with **SAMPLE HISTORICAL DESCRIPTIONS**.
> Nothing in the app is a historical claim until verified content replaces `Resources/historical_stops.json`.

## Requirements

- macOS with **Xcode 16.0+** (Google Maps SDK 11.x requires it), iOS 17.0+ device for AR (the Simulator runs the map and Developer Controls but not ARKit).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.40+ — `brew install xcodegen`.
- A Google Cloud project with billing enabled and these APIs turned on: **Maps SDK for iOS**, **Routes API** (the legacy Directions API is not available to new projects; see below).

## Open, build, run (Mac)

```bash
git clone <this repo> && cd CranfordHistoricalAR
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # then edit the keys
xcodegen generate                                             # creates CranfordHistoricalAR.xcodeproj
open CranfordHistoricalAR.xcodeproj
```

Select the `CranfordHistoricalAR` scheme, pick your iPhone, and run. Xcode resolves the Swift packages
(`GoogleMaps` 11.1.0 from `https://github.com/googlemaps/ios-maps-sdk`, and the local `Packages/TourCore`).

### Run the platform-independent tests anywhere

```bash
cd Packages/TourCore
swift test          # macOS or Linux; no Xcode needed
```

`TourCore` contains the models, JSON decoding, geo math, polyline codec, Routes API wire types,
route-progress math, route-refresh policy, proximity state machine (hysteresis), tour progress and the
walking simulator.

## Narration and historical photographs

Each stop can play narration from `audioURL` (remote HTTP(S) or a bundled file name) or, if none is
set, from speech synthesis of `longDescription` / `shortDescription`. `NarrationPlayer` is created
once in `AppDependencies` so the map sheet and the AR screen share one player.

The Droescher's Mill photograph lives in `Assets.xcassets/droeschers-mill`. It is referenced from
the HPAB catalog (`imageName: "droeschers-mill"`), not from the sample tour.

`Resources/hpab_audio_tour.json` is a 25-stop catalog extracted from the HPAB *Historic Cranford QR
Code Audio Tour* brochure (May 2020): names and addresses from the brochure, `audioURL` values from
the QR codes (probed `HTTP 200` / `audio/mpeg` on preservecranford.com), mill photo on stop 1.
Coordinates are **unverified Nominatim geocodes** (`coordinatesUnverified: true`) and must not be
treated as surveyed site positions. The app still ships `Resources/historical_stops.json` as the
labeled SAMPLE walking tour. To try the HPAB catalog, copy it over that file after verifying
coordinates — do not invent historical text; the recordings are the description.

The HPAB QR codes use `http://` (the host's HTTPS certificate is self-signed). `Info.plist` allows
insecure HTTP only for `preservecranford.com`.

## API keys (never committed)

`Config/Secrets.xcconfig` is gitignored. Copy `Config/Secrets.example.xcconfig` to it and set:

| Setting | Purpose |
| --- | --- |
| `GOOGLE_MAPS_API_KEY` | Maps SDK for iOS. Restrict the key to iOS apps with bundle id `com.cranford.historicalar`. |
| `GOOGLE_ROUTES_API_KEY` | Routes API (`computeRoutes`, `travelMode: WALK`). Can be the same key during development. |
| `DIRECTIONS_PROVIDER` | `routes` (default) or `legacy` for Cloud projects that still have the Directions API enabled. |
| `ENABLE_ARCORE_GEOSPATIAL` | `0` (default). Set `1` only after enabling the ARCore package in `project.yml`. |
| `DEVELOPMENT_TEAM` | Apple Team ID for device signing. |

The xcconfig values flow into `Info.plist` (`GoogleMapsAPIKey`, `GoogleRoutesAPIKey`, …) and are read by
`AppConfiguration`. If keys are missing the app still runs: the map shows a configuration notice and routes fall
back to clearly labeled straight-line estimates.

## Developer Mode (simulate the walk)

Debug builds define `DEVELOPER_MENU` (see `project.yml`), which compiles in **Developer Controls** (spec §19):

- On the tour screen: `⋯` menu → **Developer Controls**.
- On the first screen: long-press the *CRANFORD / HISTORICAL AR* title for about a second.

Controls: toggle a **simulated location** (replaces Core Location through the same single `LocationService`
the app uses in production), **walk toward the next stop** along the live walking route at 1×/3×/10× pace,
**move 25 m**, **jump to the next stop** (lands inside the arrival radius so the real arrival flow fires),
**trigger the historical sign**, **mark visited & skip**, **reset tour**, simulate weak GPS accuracy, and a
diagnostics panel (proximity state, route source, routing errors, key presence). Release builds contain none
of this code.

In the iOS Simulator the map, routing, panel and Developer Controls all work; ARKit does not run in the
Simulator, so the AR screen shows its "AR isn't available on this device" state there.

## Known console messages (Simulator)

Running in the iOS Simulator floods the Xcode console with lines like these on launch and while
interacting with the UI:

```
cannot add handler to 0 from 0 - dropping
Failed to send CA Event for app launch measurements for ca_event_type: 0 event_name: com.apple.app_launch_measurement.FirstFramePresentationMetric
Failed to send CA Event for app launch measurements for ca_event_type: 1 event_name: com.apple.app_launch_measurement.ExtendedLaunchMetrics
non-launching port is incompatible with service identifier "com.apple.PointerUI.pointeruid.default-service"
```

None of these come from this app, TourCore, the Google Maps SDK or Core Location — the app has no
logging of its own, and the strings do not appear anywhere in the repository or its dependencies. They
are emitted by Apple system frameworks inside the Simulator (`libapp_launch_measurement.dylib` for the
"CA Event" lines, UIKit's event/pointer plumbing for the other two) and show up in an empty SwiftUI
template app as well. They are harmless. You can confirm the origin yourself: in the Xcode console,
select a line and open the metadata (eye icon / ⌥⌘M) — the *Library* and *Subsystem* columns show the
Apple framework, not `CranfordHistoricalAR`.

To hide them:

- **Console filter** (recommended): type `cannot add handler` into the console filter field and
  choose *Hide*, or filter by *Library ≠ UIKitCore*. Nothing from the app is lost.
- **Scheme variable**: the `CranfordHistoricalAR` scheme already carries `OS_ACTIVITY_MODE = disable`
  (unchecked). Tick it in *Edit Scheme ▸ Run ▸ Arguments ▸ Environment Variables*, or set
  `isEnabled: true` in `project.yml` and regenerate. This mutes all unified-logging output, which also
  hides Google Maps SDK key errors and Core Location diagnostics, so leave it off while setting up keys.

Messages that *are* worth reading in the Simulator: anything mentioning `GMSServices`/`Google Maps SDK`
(key problems) or `CLLocationManager` (simulated location not set — use *Features ▸ Location* or
Developer Controls).

## Tests

| Where | What | How |
| --- | --- | --- |
| `Packages/TourCore` | XCTest: models/JSON (including HPAB catalog + narration source), geo math, polyline, Routes API decoding, route progress, refresh policy, proximity hysteresis, tour progress, summary, formatting, walk simulator | `cd Packages/TourCore && swift test` (macOS or Linux) |
| `CranfordHistoricalARTests` | Host-app flows: arrival → visited → close → advance, hysteresis via the simulated walker, tour completion figures, configuration fallbacks | Xcode **Product ▸ Test** (iOS Simulator is fine) |

## Project layout

```
project.yml                 XcodeGen definition (the .xcodeproj is generated, not committed)
Config/                     Base/Debug/Release xcconfig + Secrets.example.xcconfig
Packages/TourCore/          Pure Swift package + XCTest (runs on Linux)
CranfordHistoricalAR/
  App/                      @main, AppDependencies (composition root), AppConfiguration, AppTheme
  Models/                   Bridges TourCore models to CoreLocation
  Services/                 HistoricalStopService, LocationService, DirectionsService, GeoSpatialProvider, ImageLoader
  AR/                       ARViewContainer, GeoAnchorManager, ARNavigationArrow, ARHistoricalSign
  Views/                    HomeView, TourView, MapView, ARView, NextStopCard, TourHeaderView, TourCompleteView, …
  ViewModels/               TourViewModel (single source of truth), MapViewModel, ARViewModel
  Developer/                Developer Controls (DEVELOPER_MENU only)
  Resources/                historical_stops.json (sample tour), hpab_audio_tour.json (HPAB catalog)
CranfordHistoricalARTests/  Host-app unit tests (Mac/Xcode)
```

## Behaviour notes

- **First screen map** is a live Google map of all stops (dots; numbered once zoomed past level 16;
  tap a dot for a name callout, tap the map to dismiss). Without a Maps key it falls back to the
  stylized sketch map. Both stay legible with 25+ stops because no text labels are drawn on dots.

- **Distances and times** on the panel always come from the walking route (Routes API `computeRoutes`,
  `travelMode: WALK`), refreshed on a policy (moved ≥ 25 m, off-route > 30 m, stale > 90 s, destination
  change, ≥ 8 s apart) and interpolated locally between refreshes. If routing fails the last known route is
  kept; with no route at all a clearly labeled straight-line estimate is shown.
- **Arrival** opens the sign at 35 m and closes it only beyond 50 m (hysteresis), or when the user closes it.
  A stop counts as **visited** once its sign has been displayed; putting the sign away (close, walk away,
  "Continue") advances the tour — route, panel, AR arrows and destination update together.
- **AR placement** uses ARKit `gravityAndHeading` alignment plus GPS/compass; distances to the sign are
  clamped (2.4–9 m) and the HUD says "AR positioning is temporarily unavailable…" when tracking is poor.
  ARCore Geospatial is an optional, off-by-default upgrade (`ENABLE_ARCORE_GEOSPATIAL=1` + package).

## Status

All seven implementation stages are in place (project skeleton → maps → routing → AR arrows → AR sign →
completion/summary → developer mode & polish). The pure logic is tested on Linux; the iOS app itself needs a
Mac build (see `docs/build-report.md` in the project store for exactly what was and was not compiled).
