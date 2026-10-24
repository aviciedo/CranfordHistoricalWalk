# Tour expansion and state ownership

Build 47 is an incremental extension of the existing app, not a replacement.

| Owner | Responsibility | Must not do |
|---|---|---|
| AppNavigation / SwiftUI | Tabs, sheets, selected photos, Back/Home | Change itinerary or invent physical visits |
| TourViewModel | Active catalog identity, walk UUID, guarded progression/Continue/Undo, shared live location | Start audio or require a story/bonus to advance |
| TourCore policies | Arrival eligibility, routing refresh, progress, catalog validation, phone-down decisions | Access camera, GPS managers, defaults or network |
| Platform services | One GPS source, one shared player, provider adapters, resource integrity | Implicitly advance a walk |
| Stores | Per-tour activities and visit compatibility history; per-revision walk resume | Erase another tour or narration bookmarks on walk reset |

Catalog contract:
- HistoricalTourDocument adds optional tourID, catalogVersion and recordings. Missing
  identity maps to the legacy Cranford catalog for backwards compatibility.
- TourCatalog validates documents and rejects duplicate tour IDs or globally duplicated
  stop IDs. Stop IDs MUST be globally unique across a registered multi-tour catalog;
  narration and photo bookmarks intentionally continue using stable stop IDs.
- Validate the complete TourCatalog before exposing a future tour selector. The current
  build ships only the existing Cranford tour; it adds no invented tours or selector UI.
- AppDependencies.live accepts a bundled tourResourceName with the current name as its
  default. Use this startup/composition boundary for another catalog; do not construct
  multiple live dependency roots/camera sessions at once or switch catalogs mid-walk.
- A future selector must explicitly end/pause its session and preserve the single audio
  service rather than mutating an active session's identity underneath ongoing tasks.

Persistence and migration:
- Original Cranford activity/visit/walk keys remain readable in place; no destructive
  migration, key deletion or fabricated activity occurs. Existing records lacking catalog
  metadata are accepted only for the original catalog/version and matching stop order.
- New tours use encoded tour IDs as key namespaces. Activities survive catalog revisions;
  walk resume is revision-specific. Sessions persist a UUID across resume and get a new
  UUID on explicit restart. A changed catalog cannot resume an unrelated itinerary.
- The activity ledger is the accomplishment state. Legacy visit history remains a
  compatibility adapter and is idempotently imported without inventing story completion.
  Its eventual retirement requires a separately tested, approved migration.
- Test full resets and corruption/reload before changing schemas or stop identifiers.

Media:
- The selected document owns its recording manifest: stop ID, safe bundled filename,
  duration, audio digest, and transcript digest. No other tour is required to contain the
  mill or Greystone. Approved files are verified before being assigned to a stop.
- Missing/outdated audio disables that recording without disabling walking or its approved
  reading text, and without falling back to synthesized speech. Other stops still work.
- Verified audio hashes identify bookmarks, so replacing audio invalidates an old position.
  The existing shipped-Cranford lookup remains only for legacy preview/playback compatibility.
- Keep narration pending for stops 3–5 until approved recordings/text are supplied.

Selective consolidation provenance:
- aef5300: strengthen malformed/truncated polyline assertions; no old routing code imported.
- 3d4dcce: extract phone-down policy, now using Core Motion monotonic timestamps, interruption
  reset, finite-input checks and continuity checks. Old auto-advance behavior is NOT imported.
- New catalog and store regressions cover legacy compatibility, revision changes, identifier
  collisions, cross-tour isolation and session resume/restart.

Acceptance gates: portable tests and syntax checks supplement, not replace, native simulator
CI and the real-device evidence checklist in AR-FIELD-TEST.md. Coordinates and physical plaque
scales remain unverified. Publication to main and xcode-download was explicitly approved by the product owner.
Native/device verification remains pending; branch retirement is not authorized.

Build 47 walking interaction:
- WalkingProgressionPolicy owns fresh-fix/dwell/uncertainty decisions. TourViewModel
  applies its effects only, then routes through the existing destination-change command.
- Foreground Map eligibility and token-based exploration holds are presentation inputs;
  they do not become visit/learning/bonus evidence. Audio never holds routing.
- Stay here is an optional backward-compatible field in WalkResumeRecord. It affects
  progression only; persisted visits and narration identity remain independent.
- See UX-IMPLEMENTATION.md for the approved behavior, tests and native/field limits.
