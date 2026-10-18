# Ready-to-open Xcode project download

This branch includes the generated `CranfordHistoricalAR.xcodeproj` together with the app source.
It includes the Field Guide interface, guided AR marker activation and the existing build fixes.

On a Mac with Xcode installed:

1. Click **Code > Download ZIP** on this branch and extract the ZIP in Finder.
2. Open the extracted folder and double-click **CranfordHistoricalAR.xcodeproj**.
3. Wait for Xcode to download its package dependencies.
4. Select your signing team and connected iPhone in Xcode, then click Run.

Keep all extracted folders together. Homebrew and XcodeGen are not required to open this snapshot.
The source includes a subfolder also named CranfordHistoricalAR; the project file is beside that subfolder.
The saved project structure and source syntax were checked on Linux; a full iOS build and device installation have not been verified.
Use Xcode's **Product > Build** directly; the optional verification script still requires XcodeGen.

The original project documentation follows.

---

# Cranford Historical AR

A SwiftUI + ARKit/RealityKit + Core Location + Google Maps walking-tour MVP for Cranford, New Jersey.
Follow AR walking arrows, activate a stop marker on site, and discover its historical sign and narration.

> The bundled walking tour is **five** HPAB audio-tour stops (Droescher's Mill, Cranford Hall, Rahway River,
> First Baptist Church, Cranford Hotel). Names, addresses, and recordings come from the HPAB May 2020 brochure.
> Coordinates are **unverified geocodes**, not surveyed site positions. No historical narrative is invented —
> play the recording for each stop from anywhere; you do not need to be at the GPS location.

## Field Guide interface

The selected earthy design uses ivory, forest, sage, sand and terracotta, with a dark version
that follows the device setting. The native bottom tabs are **Home**, **Map** and **Stops**.
A single compact audio player remains above the tabs after starting a walk or playing a stop.
The Map tab has one destination panel; the arrival state replaces its heading rather than
adding a second card. Tap the count beside **Your walk** for the tour summary and whole-route view.
Long-press the home title or **Your walk** in Debug builds for Developer Controls.

Browse any stop and play its recording without changing the guided tour order. **Show on map**
centers that stop without changing the walking destination. **View in AR** is offered for the
current guided stop. The shared details page provides the photo, address, recording and available
historical text; source and coordinate notes are under **About this stop**.

Tap a stop photograph on the map panel, stop list or details page to enlarge it. Pinch to zoom,
drag while zoomed, double-tap or use **Reset zoom**, and tap the visible **X** to return. Closing
a photograph does not mark a stop visited or advance the tour.

The mill landmark illustration is decorative artwork based on the bundled mill photograph.
It is a noninteractive overlay beside stop 1 on the live Google map at neighborhood zoom, and
also appears in the offline illustrated overview. It does not supply street data, route geometry,
precise building boundaries, or AR image-tracking references. The real photo and plaque reference
remain separate and unchanged. Google Maps still requires the private Maps key described below.

Validation in Linux: TourCore build/tests and Swift syntax checks are available. The saved Xcode
project includes the new files. SwiftUI rendering, image-viewer gestures, tab/player placement,
Google Maps overlays, dark mode and AR still require Xcode and a physical iPhone. See
[design-qa.md](design-qa.md) for the remaining device checks; no iOS build success is claimed.

## Guided AR walk and recorded visits

**Start walking tour → View in AR → activate stop marker → listen/read → Continue to next stop.**
The guided order stays fixed while visitors browse or listen to other stops.

The reused RealityKit arrows follow the next walking-route vertex, then point to the visible marker
on arrival. A camera-relative arrow with plain instructions remains visible when the 3D arrows are
outside the camera view. Ivory arrows with forest rims match the Field Guide interface. They stop
at the marker and disappear while its story is active. GPS movement direction is not treated as
the direction the camera is facing. When tracking/heading is unusable, guidance becomes unavailable
and the **Map** control remains available.

Arrival reveals a marker; it does **not** record a visit. Tap the AR marker or **Activate stop marker**
to show the historical information card in AR and start the shared narration player. Repeated taps
do not restart playback or duplicate the visit. Stop 1 can use its currently tracked physical plaque
even if the bundled geocode is wrong. Cranford Hall and other stops without a reference photograph
use an on-site GPS marker, as selected for this MVP.

GPS activation requires a fresh location (under 30 seconds old), reported accuracy of 25 m or better,
and distance plus that uncertainty inside the stop's arrival radius (35 m by default). AR world
tracking must also be normal. This is an **on-site estimate**, not visual proof or an anti-fraud
system. A previously seen plaque is insufficient to override poor GPS after image tracking is lost.
The AR session must currently track the matching plaque for that override. Unverified stop
coordinates and the unmeasured plaque width remain field-test limitations.

Only real activations are saved locally on the iPhone, with stop ID, date and activation method.
The app keeps the latest real activation per stop; no location trail, camera photo, account or
cloud synchronization is added. Visit dates appear in **Stops** and stop details and remain after
relaunch. Starting a fresh walk still begins at stop 1. Developer walking and Xcode-simulated GPS
activations are practice and never overwrite real visit records.

Closing a card, viewing a photo, browsing a stop or walking away never advances the destination.
After activation, **Continue to next stop** updates the route and AR target from Droescher's Mill
to Cranford Hall, then onward through the remaining stops. Stay in AR or tap **Map**. The map's
**Directions** action opens Google Maps walking directions in the installed app or browser;
embedded Google Maps/Routes still require their existing API-key configuration.

Linux validation for this update: **109 XCTest tests passed**, plus 21 isolated checks executing the
production proximity extension and visit store in a Foundation-only host. Debug/Release source
syntax and all 48 app source references in the saved Xcode project were checked. The isolated host
does not validate iOS location delivery, route services, RealityKit, camera recognition, audio, or
SwiftUI rendering. Host-app XCTest changes are supplied but require Xcode to run. A full iOS build
and physical-device AR test have **not** succeeded here. Follow [AR-FIELD-TEST.md](AR-FIELD-TEST.md)
on the Mac/iPhone for those checks.

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

### Verify the iOS build on a Mac

With Xcode (including iOS and Simulator SDKs) and XcodeGen installed, run from the repository folder:

```bash
bash scripts/verify-ios-build.sh
```

This regenerates the included Xcode project, builds the app for an iPhone without signing,
and compiles the app and host-app tests for the Simulator. It stops on failure and records
logs and Xcode result bundles under the ignored `.build/ios-verification/` directory.
It does not run the tests or install the app. A Linux test pass does not verify the iOS build.

`TourCore` contains the models, JSON decoding, geo math, polyline codec, Routes API wire types,
route-progress math, route-refresh policy, proximity state machine (hysteresis), tour progress and the
walking simulator.

## Narration and historical photographs

Each stop can play narration from `audioURL` (remote HTTP(S) or a bundled file name) or, if none is
set, from speech synthesis of `longDescription` / `shortDescription`. `NarrationPlayer` is created
once in `AppDependencies` so home, the stop list, the map sheet, and AR share one player.

The in-stop control is a Spotify-like bar: play/pause, skip back/forward 15 seconds, a scrubber
with elapsed/remaining time, and the stop title. Playback is **not** gated on GPS — open **Listen
to a stop** on the home screen, tap a home-map marker, open **Stops** during the walk, or tap a
tour-map pin. You can start and stop any of the five recordings from the living room.

The Droescher's Mill photograph lives in `Assets.xcassets/droeschers-mill` (`imageName: "droeschers-mill"`
on stop 1). Stop 1 also has an ARKit image-tracking reference (`Assets.xcassets/PlaqueAnchors.arresourcegroup`)
using the visitor's real 1280×960 plaque photograph, unchanged. This replaces the old synthetic
bronze date-only stand-in, which did not match the physical plaque. The plate quote is the date line
on the door (`c. 1737`), not 1797 and not extra narrative.

Plaque recognition is Apple ARKit image tracking and does **not** require Google ARCore or an API key.
Image tracking uses stable anchor identifiers, handles tracking loss, and enables automatic image-scale
estimation. The physical width is still **unmeasured**: the legacy 18 cm reference width is only an
initial scale, not a verified measurement. Measure the plaque's outer width on the next site visit
before treating the placement scale as calibrated.

The recognized card is 45 cm wide, positioned 25 cm above the reference-image center and 8 cm off
the wall, rather than 3.8 m above the plaque. A recognition banner and "At plaque / Arrived" HUD
confirm visual arrival. Tap its AR marker to activate the story and record the visit. Once the matching plaque is recognized, erroneous GPS/geocode distances
cannot immediately dismiss the sign or point arrows away; the visitor uses **Continue** to advance.
GPS-only arrivals keep the existing 35 m / 50 m hysteresis. Tracking loss can return placement to the
existing geo fallback without marking a different stop visited.

To retest: install the new build on a physical iPhone, start the tour, enter AR at the mill,
and hold the whole plaque in view with good light. Move the phone slowly to give ARKit parallax
for scale estimation. Look for **Plaque recognized**, then slightly tilt up to see the card;
**Read** opens its 2D contents. A real on-site recognition test and Xcode asset compilation are
still required; Linux tests cannot validate ARKit recognition quality.

`Resources/historical_stops.json` is the five-stop walking tour the app loads: HPAB brochure stops 1–5
(Droescher's Mill, Cranford Hall, Rahway River, First Baptist Church, Cranford Hotel). `audioURL`
values are the QR destinations (probed `HTTP 200` / `audio/mpeg`). First Baptist uses the QR file
`First Baptist.mp3` (not `First Baptist Church.mp3`). Cranford Hall uses `Greystone.mp3`. Coordinates
are **unverified Nominatim geocodes** (`coordinatesUnverified: true`). A three-stop SAMPLE fixture
remains in TourCore tests only (`sample_historical_stops.json`).

The HPAB QR codes use `http://` (the host's HTTPS certificate is self-signed). `Info.plist` allows
insecure HTTP only for `preservecranford.com`.

## API keys (never committed)

### Home screen shows an illustrated map instead of Google Maps

The beige illustration is an offline fallback, not a Google map. It appears when a Maps SDK key
is missing/placeholder or SDK registration fails. It supports pinch zoom (1–4×), dragging while
zoomed, a reset button, and numbered buttons that display the stop name. Its streets and sepia
landmark sketches are decorative and schematic, not surveyed street or architectural data.
The real Google map enables pinch, double-tap zoom, and dragging. Moving outdoors or allowing GPS
does not switch the illustration to Google Maps.

On the Mac:

1. Open [Google Cloud Console](https://console.cloud.google.com/). Select or create your app's
   project, attach billing, and enable **Maps SDK for iOS** under **APIs & Services > Library**.
2. Under **APIs & Services > Credentials**, create or select an API key. Under **Application
   restrictions**, select **iOS apps** and add `com.cranford.historicalar` (or the actual identifier
   shown in Xcode if you changed it). Under **API restrictions**, allow **Maps SDK for iOS**.
   A Routes-only key cannot load map tiles.
3. In Finder, open the **Config** folder inside the particular downloaded project you are building.
   If `Secrets.xcconfig` already exists, edit it. Otherwise duplicate `Secrets.example.xcconfig`
   and rename the duplicate exactly `Secrets.xcconfig`.
4. Open `Secrets.xcconfig` with Xcode or a plain-text editor. Replace the placeholder after
   `GOOGLE_MAPS_API_KEY =` with your key, without quotes. Keep the other keys/team settings
   already configured, or clear their example placeholders if you are starting from the template.
   Never paste a real key in chat or commit this private file.
5. In Xcode choose **Product > Clean Build Folder**, then **Product > Run** to rebuild and
   reinstall. These keys are embedded at build time; relaunching an old installation is insufficient.
6. On the home map, pinch with two fingers, double-tap to zoom in, and drag to pan. It should show
   Google street-map tiles and Google attribution, rather than the beige illustration.

Each newly downloaded ZIP excludes `Secrets.xcconfig`. Copy your private settings from the older
project's **Config** folder into the new project's **Config** folder before rebuilding; do not
overwrite an already configured file. Without that step, a new download returns to the preview map.

In a Debug build, long-press the home title to open **Developer Controls**. **Configuration** shows
whether the Maps SDK key is present, whether SDK registration succeeded, and the bundle identifier.
Registration success does not verify Google authorization: blank/missing map tiles with a present
key still require checking billing, enabled APIs, key restrictions, connectivity, and the Xcode console.
The Routes API key is separately required for walking routes; it is not required just to zoom the map.

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

### Cloud Console checks (walking distance / time)

The tour header and Next Stop card show **walking-route** miles and minutes from the current GPS
fix to the current stop (`GoogleRoutesDirectionsService` → `RouteProgress` → `DistanceFormatter`).
If you see **“Requests from this iOS client application \<empty\> are blocked”** and dashes for
distance/time, Google received no iOS bundle id.

1. This app’s bundle id is **`com.cranford.historicalar`** (`Info.plist` `CFBundleIdentifier` and
   `PRODUCT_BUNDLE_IDENTIFIER`). Every Routes/Maps request sends `X-Ios-Bundle-Identifier` with that
   value — never an empty string.
2. Google Cloud → APIs & Services → **enable Routes API** (not only Maps SDK for iOS; the legacy
   Directions API is not available to new projects).
3. Credentials → your key → Application restrictions = **iOS apps**, add bundle id
   `com.cranford.historicalar` (do not leave the iOS-app list blank). API restrictions should include
   **Routes API** (and **Maps SDK for iOS** if the same key serves the map).
4. Rebuild after changing the key. The app does not crash on a 403; it keeps the last known route
   and otherwise shows a labeled straight-line estimate.

Do not put API keys in source control. `Config/Secrets.example.xcconfig` is the template only.

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
   → https://support.google.com/ar?p=how-google-play-services-for-ar-handles-your-data). The consent screen includes the Google Play Services for AR / Google Privacy Policy notice.
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
| `CranfordHistoricalARTests` | Host-app flows: arrival → marker activation → visit → explicit Continue, practice isolation, saved visits, hysteresis, configuration fallbacks | Xcode **Product ▸ Test** (iOS Simulator is fine) |

## Project layout

```
project.yml                 XcodeGen definition (the generated .xcodeproj is included for downloads)
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
  Resources/                historical_stops.json (5-stop HPAB walking tour)
CranfordHistoricalARTests/  Host-app unit tests (Mac/Xcode)
```

## Behaviour notes

- **Narration** is a Spotify-like player on every stop (play/pause, ±15 s, scrubber). It is not
  gated on GPS: **Listen to a stop** on the home screen, a home-map callout, the **Stops** list,
  a tour-map pin, the next-stop card, the arrival card, and the AR/sign sheet all share one player.
- **First screen map** is a live Google map of all stops (dots; numbered once zoomed past level 16;
  tap a numbered or plain dot for an in-map name popup plus a callout with the player, tap the map to dismiss).
  Without a Maps key it falls back to the stylized sketch map.

- **Distances and times** on the panel always come from the walking route (Routes API `computeRoutes`,
  `travelMode: WALK`), refreshed on a policy (moved ≥ 25 m, off-route > 30 m, stale > 90 s, destination
  change, ≥ 8 s apart) and interpolated locally between refreshes. If routing fails the last known route is
  kept; with no route at all a clearly labeled straight-line estimate is shown.
- **Arrival** reveals the marker at 35 m and hides an unactivated marker beyond 50 m (hysteresis).
  Only an explicit AR activation with the location/tracking checks above counts as a visit.
  **Continue** then advances the tour; hiding the story card or walking away does not skip stops.
- **AR placement** uses ARCore Geospatial when it is requested and actually localizing; otherwise ARKit
  `gravityAndHeading` plus GPS/compass. Distances to the sign are clamped (2.4–9 m). The HUD says
  "AR positioning is temporarily unavailable…" when tracking is poor, and names GPS/compass when Geospatial
  is unavailable. `ENABLE_ARCORE_GEOSPATIAL=1` requests the upgrade; it still falls back instead of blocking the tour.

## Status

All seven implementation stages are in place, plus narration/HPAB catalog work and an ARCore Geospatial
provider behind `GeoSpatialProvider`. The pure logic is tested on Linux; the iOS app and Geospatial itself
need a Mac + device (see `docs/arcore-geospatial-report.md` in the project store).
