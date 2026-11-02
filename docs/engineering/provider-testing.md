# Developer provider testing — build 120 candidate

Use a **Debug/Xcode build**. In Home → Developer → Map, route & AR testing, select:

| Mode | Map | Routes | Walking AR positioning |
| --- | --- | --- | --- |
| Google + Apple fallback (default) | Configured Google map; Apple when Google is not initialized | Configured Google service, with Apple fallback on routing errors; Apple directly without Google configuration | Existing ARCore enable flag and consent apply; native positioning remains the fallback |
| Google only | Google, or an unavailable state without an Apple map | Google only; failures are surfaced, with no Apple request | ARCore explicitly requested, including when the ordinary enable flag is off. Missing prerequisites create an unavailable Google provider; runtime failures do not switch to native positioning. Native maneuver/geo-sign positioning fallback is disabled. |
| Apple only | MapKit | MKDirections only | Core Location + ARKit. Google map initialization is skipped, ARCore is disabled and no Google routing provider is invoked. |

The setting is saved immediately but takes effect **only on the next app launch**.
Close the app from the iPhone app switcher, then reopen it. Do not merely close the
Developer sheet. “Active this launch” remains unchanged until relaunch; a pending
selection shows “Restart required.” Restoring the default follows the same rule.

No programmatic app termination or hot provider swap is used. This creates fresh
routing caches, map instances and AR sessions while preserving saved walk progress,
visits, stories and sketches. Existing route geometry is not persisted in the walk
resume record. Historical completion summaries remain historical records.

Release builds never read the Developer override and keep the existing configured
behavior. The selector and its storage UI are absent from Release. Google packages
remain linked in every test build: Apple-only is a **functional provider test**, not
proof of a dependency-free binary, reduced package size or absence of every possible
SDK initialization side effect. A future clean dependency-removal build needs its own
build, privacy and network inspection.

All modes retain Apple's device GPS, camera/RealityKit rendering, image-based plaque
recognition, visit detection, narration, AR phone-down exit, tour progression and saved
activity. “Google only” selects strict Google map/routing/geospatial services; it does
not replace native iOS frameworks. It may intentionally show no walking AR when ARCore
cannot localize. It must never bypass ARCore consent to make that test succeed.

## Read the results

The section shows active mode, selected map backend, current route source/error, and
last walking AR provider/notice. The last AR fields are in-memory and update when the
walking AR provider changes, including a runtime fallback. They are not a recording of
coordinates or camera images. Open AR once, return to Developer Controls and inspect
these fields; before the first AR opening, the provider reads “Not started this launch.”

A distance estimate on routing failure is the existing explicitly labelled local
estimate, not an Apple route or successful Google route. AR walking geometry is not
created from that estimate. Missing credentials in strict Google mode produce an
explicit Google-only routing error. Google Maps SDK initialization does not verify
server authorization or that all tiles loaded; Google SDK tile/authentication failures
may require its Xcode console diagnostics. Strict mode never silently changes to an
Apple map when those failures occur.

This tool deliberately exposes the current Apple route adapter as it exists. It does
not improve localized turn parsing, route selection or map interaction parity as a
side effect. Compare these before deciding to remove Google dependencies.

## iPhone acceptance checklist

1. With default selected, relaunch and confirm existing Google/Apple fallback behavior,
   saved progress, illustrations, dotted guidance and solid walked trail remain intact.
2. Select Apple only while a walk is active. Before relaunch, confirm active mode and
   running providers remain unchanged. Relaunch; active mode must now be Apple only.
3. Resume/start a walk. Verify Apple map tiles, numbered circles, recenter/zoom, route,
   distance, ETA and upcoming turns. Developer route source must read Apple Maps.
4. Open walking AR, then return to Developer Controls. Last AR provider must be native
   GPS/compass (Core Location), with no ARCore consent prompt or Google initialization.
   Check arrows, tracking interruption/recovery and phone-down exit outdoors.
5. Test native plaque recognition and sketch unlock in Apple-only and Google-only modes.
   Their recognition requirements and saved activity must remain unchanged.
6. Select Google only and relaunch. With valid credentials, verify Google map/routes.
   Walking AR requires enabled ARCore API access, supported device, precise location,
   network and consent. Without those prerequisites, verify an explicit unavailable
   state and no Apple positioning fallback. Declining consent must send no ARCore data.
7. With a test configuration that lacks Google keys, verify strict Google errors and
   zero Apple provider substitution. Compare default mode's Apple fallback.
8. Restore default, relaunch and confirm original behavior returns. Install a Release
   build with an Apple-only preference saved: it must ignore that preference.

Automated tests cover map policy boundaries, persisted selection/invalid values,
Release override rejection, Apple-only routing with Google configured, strict Google
routing failures/missing credentials, configured routing fallback, forced native AR
selection, strict unavailable Google AR and prevention of runtime native AR fallback.
Native compilation and field tests are required; portable policy tests do not establish
Apple route quality or outdoor AR accuracy.
