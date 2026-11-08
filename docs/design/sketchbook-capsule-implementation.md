# Approved sketchbook layout — build 135

Visual target: [sketchbook-capsule-approved.jpg](sketchbook-capsule-approved.jpg), selected by
the owner after the collection-progress explorations. Keep the existing illustration,
physical paper and native curl behavior; use the target for layout and UI hierarchy.

- A compact 30pt serif title shares its header row with a small outlined collection
  capsule, aligned below the close button. It shows `collected of total`, using the same
  plaque-unlock ledger and eligible sketchbook stops as before. VoiceOver identifies it
  as sketches collected, separately from page position. Hide it for an empty collection.
- The notebook uses the full width apart from 4pt side margins. Header and footer measure
  themselves; the notebook receives every remaining point. The bottom clearance uses the
  same compact home-indicator policy as the main navigation. No duplicate bottom counter.
- Replace the locked status/helper pair with one small lock and the approved instruction:
  “Scan this stop’s plaque to collect the sketch.” The visual text balances across two
  lines; VoiceOver receives the full sentence without a forced break.
- Pagination is one quiet footnote-size sans-serif row, with bare chevrons and 44pt touch
  targets. Existing first/last-page rules, swipe/arrow index, and reveal-time disabling stay.
- Reuse the blank reverse-paper texture at low opacity for the soft outer background.
  Asset files and registered watercolor/ink pairs are unchanged. Both curl faces remain
  opaque and the reverse remains blank; reveal timing and collected art are unchanged.
- The display heading scales up to 40pt to leave room for the notebook on compact devices.
  Body instructions and other semantic text still follow Dynamic Type and scroll naturally.

Native checks cover narrow/full windows, standard/accessibility text, page/header/footer
separation, notebook width, compact bottom clearance, readable instructions, and the
existing physical page-curl/unlock tests. Portable core/model suites remain required.
Exact-commit Apple compiler/native tests and SwiftLint must pass before release.

Manual visual/device review still needs portrait/landscape, the actual curl/reveal,
VoiceOver focus order, and iPhone/iPad comparison with the approved image. Automated
geometry and compiler checks do not establish pixel-for-pixel visual fidelity.

This is a validation candidate. Do not update main/release aliases without publication.
