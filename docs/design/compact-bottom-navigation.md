# Compact bottom navigation — build 134

The supplied music-app reference establishes a shorter bottom menu close to the display
edge. Keep Cranford's hunter-green selected icons and its existing Home, Map and Stops
symbols. Remove the selected underline entirely.

The menu now has a 48pt minimum button height, 22pt symbols, 11pt Dynamic Type caption
labels and tighter internal spacing. Its normal height drops from 64pt to about 52pt.
Large accessibility text can increase the height rather than clipping labels or targets.

AppContentShell owns the content/player/menu layout for every tab. It extends only into
the container's bottom safe area, reserving a compact gap above the home indicator:
16pt for a 34pt inset, 12pt for a 21pt inset, and no extra gap on a device without that inset.
It keeps the player and navigation as measured siblings, so pages receive the actual
remaining height. The standard iPhone recovers about 30pt overall (12pt menu + 18pt gap).

Home's existing responsive layout gives extra room to the circular artwork. Stops divides
its available height among rows. The map no longer stops growing at an arbitrary 400pt;
it fills the available space after measuring the destination panel. Narration keeps its
approved controls and receives the updated available height for its responsive artwork.
No global font/button scaling, page offsets or independent per-screen footer allowances.

Checks: portable sizing/model suites; native shell measurements with player open/closed
and standard/accessibility text; existing Home/map responsive layout checks; exact-commit
Apple compiler/native test and SwiftLint gates before release. Physical iPhone/iPad visual
review remains necessary for final spacing, home-indicator clearance and touch comfort.
The candidate is not a publication request and must not update main/release aliases.
