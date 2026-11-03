# Cranford Hotel plaque unlock — build 129

The owner supplied the oval plaque photo and requested it as the Hotel unlock target,
then requested committing all changes and publishing. The owner does not know its
physical width. No historical narration or additional recognition subjects are invented.

## Recognition resource and size

- Stop: hpab-005, retaining its existing identity, coordinates and itinerary order.
- AR resource: PlaqueAnchors / cranford-hotel-plaque.
- Actual source: docs/field-references/cranford-hotel-plaque-original.jpg.
- Crop: (24, 359) to (951, 990), yielding 927 × 631 pixels without resampling.
- The natural source colors/text/texture are retained; no image generation is used.
- Full crop reference width: 0.30 m, an explicitly unmeasured initial testing estimate.
- Production catalog, fallback preview, test fixture and AR asset use the same width.
- Existing automaticImageScaleEstimationEnabled remains enabled with detection images.

The field-reference JSON records original/cropped hashes and dimensions. After measuring
on site, update the catalog width, fixture width, asset Contents.json width and
SignPlacementPolicy.assumedHotelReferenceWidthMeters together. If only the oval plate
is measured, account for the small surrounding margin in the reference crop.

## Existing shared unlock behavior

The resource group now contains Mill, Greystone and Hotel. The catalog and preview
stop declare the Hotel plaque; its watercolor points to sketchbook-hotel. Collection
eligibility comes from the real plaque configuration. The existing recognition path
requires both tracked image identity and ready tracking. It awards the matched stop
once, persists the award, queues one reveal, supports camera-only scanning without
GPS or Hotel narration, and preserves the walking destination. Repeat detections
must not duplicate awards or replay the reveal. Ordinary visits do not paint the stop.
First Baptist and Rahway River remain non-plaque stops. Existing provider modes retain
the same native image-recognition path; no provider-specific scanner is added.

The existing Hotel Home ink and map watercolor remain. Stops paints the approved
watercolor only after the Hotel plaque is unlocked. No new renderer or animation is
introduced. The AR asset group is loaded by its existing directory reference in the
included Xcode project.

## Automated checks

The new core test checks Hotel-only identity resolution and rejects untracked/limited
input while preserving pending narration. The new actual-model regression checks
unlock without GPS/narration, unchanged walk destination, one pending reveal, no
repeated award, and reload persistence. Existing shared lifecycle/rejection tests
also run across all three targets. The explicit expected collection order is updated
to Mill, Greystone, Hotel. Existing native tests check AR resources against every
catalog reference/width and verify ink/watercolor asset selection and availability.

Local portable test results and exact-commit Apple/SwiftLint results are recorded in
the release evidence. Portable tests do not certify ARKit optical recognition.

## iPhone acceptance

1. Open the Hotel plaque scanner: the hint identifies the oval Established 1882 plaque.
2. Opening the scanner alone must not award a sketch or start/change a walk.
3. Scan the real plaque in daylight and shade, allowing tracking to settle. Confirm
   the correct Hotel sign appears and the watercolor is awarded once.
4. Check scale/card placement using the provisional width; replace it with a physical
   measurement if necessary. Test at a few practical viewing angles and distances.
5. Rescan and relaunch: keep the award without an unsolicited repeat celebration.
6. Confirm Stops paints the Hotel, sketchbook includes it, and prior Mill/Greystone
   awards remain. A normal visit without recognition must not grant the Hotel sketch.
7. Repeat the scanner check in each existing Developer provider mode on the next
   launch. This native recognition flow should remain available in all three modes.

The hosted checks verify compilation, resources and logic; actual optical recognition,
scale and outdoor provider behavior require this physical iPhone check. No publication
or field success is implied solely by the implementation notes. Use the immutable tag
and exact-commit workflow evidence for the actual release outcome.
