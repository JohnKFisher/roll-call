# Where We Stand

Use this file as the concise status snapshot for the current checked-in app. Detailed decisions belong in [DECISIONS.md](./DECISIONS.md); public release wording belongs in [product/PUBLIC_CHANGELOG.md](./product/PUBLIC_CHANGELOG.md).

## Current working candidate

- Version: `1.3.0`
- Build: `111`
- The currently released App Store family remains `1.2.x`; this checkout is the 1.3 feature candidate and has not yet cleared the release/audit gates below.
- The app is an iPhone-first, on-device walk-up cue app. The full feature set remains free, with optional support contributions in Settings/About.

## What is in place

- Game Day remains the protected live workflow: choose a player, play the cue, and fall back safely when player-specific audio or an announcement is unavailable.
- Music Library is the primary song path. Apple Music search and file import remain explicit alternatives, and all paths use the shared draft clip editor.
- Readiness distinguishes `Ready on Any Device`, `Ready on This Device`, `Preparing`, `Needs Apple Music`, and `Needs Repair`. Readiness informs setup but never blocks Game Day.
- Local clip generation is limited to media that public APIs expose as genuinely readable. Source-backed Apple Music or Music Library playback remains a supported, honest device-dependent path.
- Custom Clips are team-specific live clips independent from Player Songs after copying. They support explicit edit mode, ordering, Recently Deleted recovery, and package export/import.
- Team packages and backups preserve team ownership and saved media choices. Missing or unavailable media is reported for repair rather than silently discarded.
- Teams support roster editing, lineup order/presence, CSV import, package sharing/import, and managed Apple Music playlist creation.
- Player Editor now keeps a metadata-stripped, bounded working photo master plus independent profile and Player Card framings. On-device Vision seeds both framings once; either can be corrected manually without replacing the source. Legacy cropped-only photos continue to work.
- Player Cards use the selected Broadcast composition as one 1200-by-1500 share graphic, with a full preview, system Share Sheet, graceful missing-data/photo fallbacks, and a small `Made with Roll Call` attribution. Cards live only on Player Editor, not Game Day.
- Quick Game Day remembers the team most recently entered intentionally in Game Day, resolves every system request through one app-owned route, and never starts playback. The app intent supports an optional explicit team; the iOS 18 control extension supplies Control Center and Lock Screen surfaces without raising the iOS 17 app floor or adding a Home Screen widget.
- Settings includes recovery, readiness-related preferences, What's New, Anonymous Usage Analytics opt-out, rating/support surfaces, Attributions & Licenses, and non-Release Developer Tools.
- Approved telemetry is implemented behind a typed allowlist with a separate versioned local telemetry/rating store; developer and TestFlight signals use TelemetryDeck Test Mode, and the approved production app ID is configured in the app target's `Info.plist`.
- Automatic rating eligibility now uses confirmed probable-game dates (2 dates/7 days, then 5 dates/30 days) with App Store-only two-phase presentation consumption; legacy 10/20 visit state remains decodeable for migration.
- Support purchases are optional StoreKit contributions. They do not unlock features, affect readiness or Game Day, or travel with teams and backups. Transaction updates are observed from app launch.
- Build environments are separated into Debug, Internal, and Release configurations with centralized feature-flag safety. See [Build Environments](./development/BUILD_ENVIRONMENTS.md).

## Known limitations and remaining proof

- Build 111 compiles the iOS 17 app, iOS 18 control extension, App Intent metadata, and complete XCTest bundle for a generic iOS device. Runtime XCTest and Simulator validation are currently blocked because this Mac's CoreSimulator service (`1169.1`) is older than the installed Xcode beta requirement (`1171.6`); compile success is not recorded as a test pass.
- Player Card preview/framing/share, VoiceOver operation, warm and cold Quick Game Day routing, Control Center/Lock Screen installation, Action Button/Shortcuts behavior, and appearance/layout across supported iPhone sizes still need representative device checks before feature freeze.
- Final release confidence still needs physical-device checks for Music Library selection, Apple Music authorization/subscription states, audible source-backed versus generated playback, package transfer, and repair behavior.
- The current iOS 17 deployment floor and the known iPad/Game Day playback path still deserve a representative device smoke pass before a future release claim treats them as fully field-proven.
- Full-song Apple Music trimming, source-backed fade behavior, hook suggestions, and Apple Music playlist mutation remain device/account-sensitive and should not be treated as simulator-proven.
- Waveforms and per-cue gain remain intentionally deferred.
- Recovery and support-bundle surfaces have automated coverage, but manual checks should use disposable data and confirm that user names, filenames, song metadata, and purchase state stay out of exported support/team artifacts.

## Immediate priorities

1. Restore a compatible Simulator/CoreSimulator runtime and execute the full XCTest suite.
2. Complete the bounded 1.3 device matrix for Player Cards, Quick Game Day system surfaces, accessibility, package downgrade/import behavior, and existing Game Day/audio regression checks.
3. Freeze 1.3 only after those gates pass, then begin the separate Astra release-candidate audit.

## Current references

- [Application Overview](./product/APP_OVERVIEW.md)
- [Product Opportunities](./product/PRODUCT_OPPORTUNITIES.md)
- [Decisions](./DECISIONS.md)
- [Working Changelog](./WORKING_CHANGELOG.md)
- [Historical Archive](./historical/README.md)
