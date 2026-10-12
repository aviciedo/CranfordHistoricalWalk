# Cranford Historical AR

A SwiftUI + ARKit/RealityKit + Core Location + Google Maps walking-tour MVP for Cranford, New Jersey.
Walk toward a historical site, follow AR arrows, and a large AR historical sign appears when you arrive.

> The bundled walking tour is **three** HPAB audio-tour stops (Droescher's Mill, Cranford Hall, Rahway River).
> Names, addresses, and recordings come from the HPAB May 2020 brochure. Coordinates are **unverified geocodes**,
> not surveyed site positions. No historical narrative is invented — play the recording for each stop.

## Requirements

- macOS with **Xcode 16.0+** (Google Maps SDK 11.x requires it), iOS 17.0+ device for AR (the Simulator runs the map and Developer Controls but not ARKit).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.40+ — `brew install xcodegen`.
- A Google Cloud project with billing enabled and these APIs turned on: **Maps SDK for iOS**, **Routes API** (the legacy Directions API is not available to new projects; see below). **ARCore API** is required only if you turn on Geospatial.

## Open, build, run (Mac)

```bash
git clone <this repo> && cd CranfordHistoricalAR
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # then edit the keys
xcodegen generate                                             # creates CranfordHistoricalAR.xcodeproj
open CranfordHistoricalAR.xcodeproj
```

Select the `CranfordHistoricalAR` scheme, pick your iPhone, and run. Xcode resolves the Swift packages
(`GoogleMaps` 11.1.0 from `https://github.com/googlemaps/ios-maps-sdk`, `ARCoreGeospatial` from
`https://github.com/google-ar/arcore-ios-sdk` up to next minor of 1.56.0, and the local `Packages/TourCore`).

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

The Droescher's Mill photograph lives in `Assets.xcassets/droeschers-mill` (`imageName: "droeschers-mill"`
on stop 1).

`Resources/historical_stops.json` is the three-stop walking tour the app loads: HPAB brochure stops 1–3
(Droescher's Mill, Cranford Hall, Rahway River). `audioURL` values are the QR destinations (probed
`HTTP 200` / `audio/mpeg`). Coordinates are **unverified Nominatim geocodes** (`coordinatesUnverified: true`).
A three-stop SAMPLE fixture remains in TourCore tests only (`sample_historical_stops.json`).

The HPAB QR codes use `http://` (the host's HTTPS certificate is self-signed). `Info.plist` allows
insecure HTTP only for `preservecranford.com`.

## API keys (never committed)

`Config/Secrets.xcconfig` is gitignored. Copy `Config/Secrets.example.xcconfig` to it and set:

| Setting | Purpose |
| --- | --- |
| `GOOGLE_MAPS_API_KEY` | Maps SDK for iOS. Restrict the key to iOS apps with bundle id `com.cranford.historicalar`. |
| `GOOGLE_ROUTES_API_KEY` | Routes API (`computeRoutes`, `travelMode: WALK`). Can be the same key during development. |
| `GOOGLE_ARCORE_API_KEY` | ARCore Geospatial (`GARSession` API-key auth). If empty, the Routes key is reused. Restrict the key to bundle id `com.cranford.historicalar` **and** the ARCore API. |
| `DIRECTIONS_PROVIDER` | `routes` (default) or `legacy` for Cloud projects that still have the Directions API enabled. |
| `ENABLE_ARCORE_GEOSPATIAL` | `0` (default). Set `1` to *request* Geospatial at runtime. Still needs key, precise location, network, device support, and first-run consent. |
| `DEVELOPMENT_TEAM` | Apple Team ID for device signing. |

The xcconfig values flow into `Info.plist` (`GoogleMapsAPIKey`, `GoogleRoutesAPIKey`, `GoogleARCoreAPIKey`, …) and are read by
`AppConfiguration`. If keys are missing the app still runs: the map shows a configuration notice and routes fall
back to clearly labeled straight-line estimates. Geospatial falls back to GPS + compass.

## ARCore Geospatial (Mac + device)

The `ARCoreGeospatial` product is linked via SPM (`project.yml`: `https://github.com/google-ar/arcore-ios-sdk`,
up to next minor from **1.56.0**). Linker flags already include `$(inherited) -ObjC`; bitcode is off; modules
and auto-linking are on.

This does **not** mean Geospatial is on. Runtime still requires all of:

1. Google Cloud: enable **ARCore API**. Create (or extend) an API key. If the key is restricted, allow
   bundle id `com.cranford.historicalar` and the ARCore API. Maps-only restrictions produce
   `GAREarthStateErrorNotAuthorized`.
2. `GOOGLE_ARCORE_API_KEY` in `Secrets.xcconfig` (or a reusable Routes key) and `ENABLE_ARCORE_GEOSPATIAL = 1`.
3. Location When In Use **and** precise location (`PreciseLocationForAR`) **before** the Geospatial session is configured.
4. Network (VPS and Cloud auth).
5. First-run consent with Google’s required text (“To power this session, Google will process sensor data… Learn more”
   → https://support.google.com/ar?p=how-google-play-services-for-ar-handles-your-data). The home screen also
   discloses Google Play Services for AR / the Google Privacy Policy.
6. A physical iPhone that reports `isGeospatialModeSupported(.enabled)`. The Simulator cannot run ARKit or Geospatial.

`GARSession` is created with `sessionWithAPIKey:bundleIdentifier:error:`, configured with
`geospatialMode = enabled`, and fed the same `ARSession` frames (`update:error:`). There is no second
camera or `CLLocationManager`. Site placement uses
`transformFromGeospatialCoordinate:altitude:eastUpSouthQTarget:error:` at the stop’s lat/lon and optional
WGS84 ellipsoid `altitude` (otherwise camera geospatial altitude). Heading comes from `eastUpSouthQTarget`
(`heading` is deprecated). VPS coverage is queried with `checkVPSAvailabilityAtCoordinate:completionHandler:`;
missing VPS does **not** by itself fall back (Geospatial can still use GPS) but the HUD says accuracy is reduced.

If Geospatial is unsupported, unauthorized, offline, declined, or does not localize within 12 seconds,
`CoreLocationGeoSpatialProvider` takes over (ARKit `.gravityAndHeading`) and the HUD says positioning is
GPS/compass and less precise. Arrival 35 m / departure 50 m, RealityKit signs, arrows, Maps routes, and
Developer Controls stay as they are.

**This repository’s Linux build cannot compile or run ARCore.** After `xcodegen generate` on a Mac, resolve
packages, run on a device, and confirm Earth tracking in Cranford before treating Geospatial as working.

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
  Resources/                historical_stops.json (3-stop HPAB walking tour)
CranfordHistoricalARTests/  Host-app unit tests (Mac/Xcode)
```

## Behaviour notes

- **First screen map** is a live Google map of all stops (dots; numbered once zoomed past level 16;
  tap a dot for a name callout, tap the map to dismiss). Without a Maps key it falls back to the
  stylized sketch map. Dots stay unlabelled so they remain legible if the tour file grows.

- **Distances and times** on the panel always come from the walking route (Routes API `computeRoutes`,
  `travelMode: WALK`), refreshed on a policy (moved ≥ 25 m, off-route > 30 m, stale > 90 s, destination
  change, ≥ 8 s apart) and interpolated locally between refreshes. If routing fails the last known route is
  kept; with no route at all a clearly labeled straight-line estimate is shown.
- **Arrival** opens the sign at 35 m and closes it only beyond 50 m (hysteresis), or when the user closes it.
  A stop counts as **visited** once its sign has been displayed; putting the sign away (close, walk away,
  "Continue") advances the tour — route, panel, AR arrows and destination update together.
- **AR placement** uses ARCore Geospatial when it is requested and actually localizing; otherwise ARKit
  `gravityAndHeading` plus GPS/compass. Distances to the sign are clamped (2.4–9 m). The HUD says
  "AR positioning is temporarily unavailable…" when tracking is poor, and names GPS/compass when Geospatial
  is unavailable. `ENABLE_ARCORE_GEOSPATIAL=1` requests the upgrade; it still falls back instead of blocking the tour.

## Status

All seven implementation stages are in place, plus narration/HPAB catalog work and an ARCore Geospatial
provider behind `GeoSpatialProvider`. The pure logic is tested on Linux; the iOS app and Geospatial itself
need a Mac + device (see `docs/arcore-geospatial-report.md` in the project store).
