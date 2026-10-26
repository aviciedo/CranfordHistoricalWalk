# Photo-led stop details — build 63

## Confirmed brief

Direction 1 with slideshow first, remove Show on map and Listen/Read tabs, green
Play narration then Resume narration according to saved progress, outlined AR,
expanded Stop details with a smaller serif heading, and Read the story at bottom.
User confirmed separate reading page, completed recordings return to Play, and
serif styling applies to the Stop details heading only.

## Implementation and preserved behavior

StopDetailView uses the original slideshow with 44-point manual arrows, caption,
photo enlargement and uncropped image fitting. Title/date/address follow the gallery.
Only map links on this page and the segmented story-mode picker are removed. The
main Map page/other map navigation remain. No production artwork or historical
copy is regenerated. Stop details uses title2/serif/semibold (normally22 points),
versus the largeTitle/serif/semibold stop name (normally34 points). History keeps
body typography. Expanded state starts true and resets for a changed stop ID.

NarrationControls uses the existing prepare/play path and hasSavedResume predicate.
A fresh/prepared recording without a bookmark says Play narration. Saved matching
recording progress says Resume narration; the engine clears bookmarks on completion.
When this story's shared footer is visible, the existing Use the player below line
avoids a duplicate transport. Closing the footer pauses/saves, exposing the launch
button again. Once a finished recording's footer is dismissed, Play appears again.
No speech fallback, new audio, autoplay or playback engine/storage change is added.

AR action is forest text/icon on outlined ivory. Original discovery eligibility,
on-site scanner, already-unlocked View the bonus and Bonus found status are retained.

The final Read the story row appears only for a nonempty approved transcript. It
pushes StopStoryReader in the existing NavigationStack, with its own scrollable
text, Back, X and shared player reserved as a layout sibling. Back pops to details;
Home clears the destination/presentations. Nested exploration holds protect against
automatic navigation while reading. The explicit I've read the narration action
reuses finishStory; opening the reader alone does not complete it or record a visit.
The reader never calls play/startTour, changes the destination or changes GPS.
Only one footer is visible in the navigation stack; existing audio can continue.
Stops without approved recordings/transcripts do not gain unavailable media controls.

## Verification

92 portable actual-model regressions passed, including existing reading/listening,
visit independence, bookmarks, exploration holds, Previous and automatic progression
coverage. Full Debug/Release syntax and whitespace checks passed. Core is unchanged;
its prior227-test result was not rerun. Native audio tests now explicitly assert the
resume predicate at fresh/prepared, saved/closed and finished states, but those native
assertions and AVFoundation were not executed on Linux.

Native visual QA is blocked in design-qa.md. On macOS/iPhone:
1. Build with Apple SDK; capture gallery-first layout and compare with reference.
   Check portrait/landscape photos fit uncropped, arrows/captions and enlargement.
2. Fresh recording: Play; start, pause/close: Resume; restore app: Resume at saved
   position; finish/close: Play. Shared footer must be the only active transport.
3. Ensure no map action or Listen/Read tabs on stop details. Check the serif heading
   size, original body, expanded default, collapse/reopen and AR outline/access.
4. Read the story appears last and opens only the full approved transcript. Back
   returns with selected slide/disclosure intact; X returns Home; no playback/walk
   starts or stops merely by reading. Reader must display current audio independently.
5. Explicit reading completion affects that story only; no GPS visit or bonus credit.
   All stops lacking approved media remain truthful.
6. Check compact/large phones, Dynamic Type, VoiceOver, player visible, interruption
   and background/resume, restored narration, scanner/bonus and navigation holds.
