# Adding a tour without adding stop-ID rendering switches

The current five-stop tour remains the default. No public second tour or tour picker is
introduced by the consolidation. A small second catalog exists only in TourCore test fixtures.

1. Give the JSON document a stable `tourID`, positive `catalogVersion`, `schemaVersion: 1`,
   and globally unique stop IDs. Keep Cranford's existing identity and IDs unchanged.
2. Supply coordinates, arrival/departure radii, stop order and factual content. Validate through
   `HistoricalStopDecoder` and `TourCatalog`. Revision numbers invalidate incompatible walk
   resumes; visit/collection storage remains scoped to the tour, across compatible revisions.
3. Add optional per-stop `artwork` metadata:

   ```json
   { "homeInk": "new-home-ink", "listInk": "new-list-ink",
     "mapLandmark": "new-map-cutout", "watercolor": "new-sketch", "listHeight": 88 }
   ```

   Use real bundled asset names, not filenames or remote paths. Empty, control-character or
   path-containing values are rejected. `watercolor` is a resource reference, not permission
   to unlock it. Unlock eligibility still comes from actual plaque recognition and the ledger.
   Omit unavailable artwork rather than inventing historical illustrations. The hotel's
   existing generic map fallback is retained.
4. Add `plaque` reference name, transcription and measured physical width only for a supported
   recognition target. Include the corresponding AR reference image in PlaqueAnchors. Test real
   lighting, tracking loss and scale on an iPhone. GPS visits never award a plaque sketch.
5. Add actual recordings to `recordings`, including their file/transcript hashes and duration.
   Resource verification operates on the selected catalog. Missing/mismatched recordings
   remain pending rather than disabling navigation or substituting unapproved narration.
6. Bundle the JSON/assets/audio and select the service through the existing
   `AppDependencies.live(configuration:tourResourceName:)` composition root. Pass the selected
   stop's metadata to renderers. The ID-only compatibility lookup is for legacy call sites.
7. Run catalog validation, two-tour isolation/migration tests, native resource tests and the
   field checklist before offering the new tour. Do not change the legacy `bonusFoundAt`
   serialized field or reset existing users' history.

Map and image caches include resource identity so a revised catalog cannot silently retain a
previous thumbnail for the same stop. No application database replacement is required.
