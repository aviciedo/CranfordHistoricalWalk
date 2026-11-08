# Developer sketch and ARCore controls — build 136

Developer Controls now provides an individual unlock action for every configured
sketchbook stop, a sketch-only reset, and a persisted Use ARCore switch. These
controls are compiled only with DEVELOPER_MENU, alongside the existing developer menu.

Sketch actions use the tour-scoped activity ledger. They do not invent visits,
complete stories, change the walking destination, or present the production reward.
Reset clears pending rewards and in-memory plaque-discovery caches so a new scan can
collect a sketch again. It preserves visits, story progress and walking progress.
An optional, backwards-compatible ledger field prevents recognized legacy visits
from re-awarding a reset sketch on the next launch. A fresh collection clears that
stop's suppression and preserves normal idempotent award timestamps.

The ARCore switch defaults to the configured launch behavior and is saved locally.
It applies when the next walking AR session creates its provider, not by replacing
an active session's coordinate frame. Off explicitly selects Apple positioning,
including when the separate provider mode is Google only. Maps and routes are not
changed. Apple only mode disables the switch and continues to skip Google services.
On still requires normal SDK, key, consent, permission, device and network checks.
The walking-AR consent screen uses the same effective request as provider creation.
Release builds do not read the saved developer override.

Checks include old-ledger decoding, reset/legacy migration/persistence/recollection,
actual model preservation of visits/stories/progress, ARCore setting persistence,
and native provider selection with off/on, consent, and Apple-only restrictions.
Physical-device AR localization and developer-menu interaction remain field checks.
