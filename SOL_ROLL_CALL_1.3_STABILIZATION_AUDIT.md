# Roll Call 1.3 — Stabilization & Forensic Audit

## Executive Summary

Roll Call 1.3 is fundamentally sound, not structurally unstable. Its product model is unusually explicit: durable team/player/media state is separate from temporary live state; Game Day has a deliberate intro → song → cheer fallback chain; package transfer preserves unavailable choices; and persistence, generated-asset cleanup, telemetry policy, and recent-deletion recovery have substantial unit coverage. A generic-device Debug build and the complete XCTest bundle compile successfully at build 111 with Swift 6, the iOS 17 app, iOS 18 control extension, and App Intent metadata.

The release candidate is nevertheless not ready to freeze. All three reported 1.3 failures were real in the first 1.3 commit (`e0595ba`). The current checkout contains targeted source repairs, and owner verification has closed the Player Card, profile-photo, metadata-refresh, unreadable-state, low-volume-warning, Volume Automation baseline, Announcement Cue verdict, and telemetry defects. Remaining live-use risks include the open audio-session interruption/media-reset gap; persistence still needs the hostile-package boundary and Recovery presentation gates below. These are stabilization defects, not reasons for a rewrite.

The three known failures share a release-process weakness: tests stop below UIKit resource decoding, SwiftUI presentation timing, and WidgetKit/App Intent process handoff. Player Cards and Quick Game Day are coherent designs, but their integration was inferred rather than exercised. Telemetry's semantic model is generally strong and trustworthy, but synchronous atomic persistence on the main actor is an avoidable Game Day risk.

The greatest immediate value is to:

1. complete the remaining physical system-control matrix and add audio-session interruption handling with a live-device interruption matrix;
2. harden ownership/recovery edges, beginning with bounded team-package archive extraction and then the Recovery presentation gate;
3. complete runtime validation of the bounded recorder-cancellation state machine and address the remaining missing-media grammar issue.

## Repository / Product Model

`RollCallApp` owns one main-actor `AppModel`. `AppState` is JSON-persisted in Application Support; it owns teams, players, lineup/session choices, settings, onboarding state, backup records, Recently Deleted records, and media references. Assets live under app-owned `Assets` and `GeneratedClips` directories. State writes are serialized through `StatePersistenceWriter`; team packages are ZIP archives with a JSON manifest and referenced assets.

Game Day resolves each player into a `PlayerPlaybackPlan` based on the team's live announcer mode and current media availability. `CuePlaybackEngine` then attempts an Announcement Cue and/or primary cue, reports confirmed component starts, and degrades through song-only, intro-only, or the built-in Small Cheer. The same team/player media model feeds readiness, the Player Editor, Custom Clips, packages, backups, Recently Deleted, and Player Cards.

Quick Game Day stores the team most recently entered intentionally, resolves an optional explicit team or that remembered team, and routes to Game Day without starting playback. Shortcuts use an app-target `AppIntent`; Control Center/Lock Screen use an iOS 18 WidgetKit control extension. Telemetry is a typed, allowlisted main-actor coordinator backed by a separate versioned local JSON store; it is intentionally excluded from team packages and app-state restoration.

# Fix First — Known 1.3 Failures

## [P0] Player Card preview crashed while decoding the app-icon catalog

**Area:** Player Cards

**Confidence:** Confirmed

**Status (2026-09-09):** Implemented in the working tree after owner approval. The recorder now uses one lock-protected recording/stopping lifecycle with per-session identity, cancellation claims the pending stop exactly once, and Player Editor dismissal cancels both recording and saving phases. Engineering verification is pending; owner/device acceptance remains open.

**Status (2026-09-09):** Closed for stabilization; owner verified the repaired Player Card appearance and flow. A drawable-resource regression test was added. Future visual cleanup, including the missing-photo placeholder, remains outside this stabilization fix.

**Problem**

In the initial 1.3 candidate, tapping Preview & Share immediately terminated the app during card rendering. HEAD contains a focused repair, but the repaired full presentation/share flow has not been run on a representative device and therefore is not release-accepted.

**Evidence**

- `PlayerEditorSheet` sets `playerCardPreviewPresented`; `PlayerCardPreviewSheet.render()` invokes `PlayerCardRenderer.render()`.
- In commit `e0595ba`, `PlayerCardRenderer.drawAttribution` evaluated `UIImage(named: "AppIcon")`.
- The current comment in `PlayerCards.swift` at `PlayerCardRenderer.bundledBrandIcon` records the observed `_UIImageCGImageContent` `NSInternalInconsistencyException` (“Need an imageRef”). The Icon Composer/app-icon entry is not an ordinary drawable asset; the Objective-C exception bypasses Swift error handling.
- HEAD instead loads `AppIcon-iOS-Default-1024@1x.png`, verifies nonzero dimensions, and omits the decorative icon safely if unavailable. The PNG is in the app target's resources.
- `PlayerCardTests.testDefaultBrandIconRendersWithoutRaising` covers the renderer. Generic-device app and test-bundle builds succeed.
- `docs/WHERE_WE_STAND.md` explicitly says Player Card preview/share still needs device validation and runtime XCTest is blocked on this Mac.

**Root cause**

UIKit special-resource behavior was assumed to be failable. `UIImage(named:)` did not return `nil` for the app-icon catalog; drawing raised an Objective-C consistency exception that Swift could not catch.

**Why it matters**

This was a normal-path crash in a headline 1.3 feature. A renderer-only unit test cannot establish that the shipped resource, async render, SwiftUI sheet, and activity controller work together.

**Recommended change**

Keep the current loose bitmap (or another guaranteed drawable ordinary resource) and never load the app-icon catalog by name. Do not make further source changes unless device validation exposes a defect. Add bundle-resource and end-to-end presentation protection around the existing repair.

**Scope / guardrails**

- Preserve the approved single Broadcast composition, 1200×1500 output, on-demand rendering, system share sheet, graceful photo/song fallbacks, and “Made with Roll Call” attribution.
- The icon is decorative; failure to load it must never block or indent the attribution incorrectly.
- Verify Release target membership, not merely test-host availability.

**Acceptance criteria**

- Preview opens without termination for new 1.3 photos, legacy profile-only photos, missing photos, missing songs, and each supported source family.
- The output is 1200×1500 and the Release bundle displays the icon and attribution.
- Share presents, completes, and cancels normally; repeated open/dismiss/share cycles remain stable.
- A deliberately unavailable/zero-size supplied icon still produces a complete card without a crash or empty icon gap.

**Tests / verification**

- Retain the renderer regression and add a Release-bundle resource decode assertion.
- Add one UI/integration test for Player Editor → Preview & Share → rendered image → Share sheet.
- Perform the photo/source matrix above on at least one physical iPhone in both light and dark app appearance.

---

## [P1] Profile-photo adjustment could present an empty full-screen cover

**Area:** Player Cards

**Confidence:** Strong evidence

**Status (2026-09-09):** Closed for stabilization; owner verified the repaired photo-adjustment flow. Further design refinement remains optional follow-up work.

**Problem**

The initial 1.3 implementation could open Adjust Profile Photo as an indefinitely black full-screen cover. HEAD replaces the faulty state model, but the actual modal lifecycle has no UI test or completed device check.

**Evidence**

- In `e0595ba`, presentation readiness was split between `photoFramingTarget` (the `.fullScreenCover(item:)` trigger) and `photoFramingImage` (conditionally required inside the destination closure). SwiftUI could begin presenting after the target change while the closure still observed no image, producing an already-presented cover with empty content.
- HEAD defines `PlayerEditorSheet.PhotoFramingPresentation`, an atomic payload containing target, image, and framing options. `presentPhotoFraming` loads and analyzes the image before assigning that item; `.fullScreenCover(item:)` builds directly from it.
- The same repair corrects `PlayerPhotoFramingGeometry.centeredCrop`, whose old zero-area anchor produced a 1% sliver for legacy images. `PlayerPhotoTests.testCenteredCropCoversMostOfAnOrdinaryPhoto` is the explicit regression guard, while `testCenteredCropHandlesExtremeAspectRatios` broadens the geometry coverage; neither tests presentation.
- There is no UI test target or test covering rapid presentation/dismissal, parent dismissal during Vision analysis, or a legacy-photo cover.

**Root cause**

The modal trigger and the data required to construct its content were independent state variables. Their transiently inconsistent state was valid to the compiler but invalid for presentation.

**Why it matters**

An indefinite black screen traps the user in a new photo workflow and undermines both Player Cards and the longstanding profile-photo experience.

**Recommended change**

Keep the atomic presentation payload. Harden it with visible bounded preparation and cancellation/supersession behavior if device testing shows Vision analysis is perceptibly slow. Never trigger a cover whose destination can resolve to empty content.

**Scope / guardrails**

- Profile and Player Card crops must remain independent and draft-scoped until Player Editor Save.
- Player Editor Cancel must discard derived draft assets; Save must persist both framings.
- Legacy profile-only photos remain supported without requiring replacement.

**Acceptance criteria**

- Adjust Profile Photo always shows navigation, photo, controls, Cancel, and Use Framing.
- New, legacy-only, square, portrait, landscape, and orientation-tagged photos work.
- Cancel is lossless; Use Framing changes only the draft; editor Cancel discards and Save persists.
- Rapid repeat taps, dismiss/reopen, and closing the editor during analysis never show a blank/late cover.

**Tests / verification**

- Add a presentation-state test asserting that every nonnil presentation item contains usable content.
- Add UI coverage for open/cancel/apply and parent dismissal during preparation.
- Device-check Dynamic Type, VoiceOver adjustment actions, and both appearances.

---

## [P1] Control Center launch path still lacks proof across the extension/app boundary

**Area:** App Intents

**Confidence:** Needs validation

**Status (2026-09-09):** Parked for pending verification. Owner reports the iOS 27 path works, with the supplied Control Center icon still displaying incorrectly; no further changes are being made in this issue until that verification gate is revisited.

**Problem**

The initial Control Center control was a confirmed no-op. HEAD replaces it with a plausible two-stage intent handoff and compiles valid target metadata, but the implementation still differs from Apple's documented direct `OpenIntent` pattern and its only test executes the destination intent inside the app test process.

**Evidence**

- In `e0595ba`, the extension-only control intent returned `OpenURLIntent(rollcall://game-day)`. The reported system action never reached the app's `.onOpenURL` route.
- HEAD compiles `QuickGameDayControlIntent.swift` into both app and extension targets. `OpenGameDayControlIntent.perform()` returns `OpenGameDayFromControlIntent`; the latter uses `openAppWhenRun = true` and submits to `OpenGameDayRequestCenter.shared`.
- `RootView.finishLaunchingTask` preserves pending requests through app initialization; `processPendingOpenGameDayRequestIfPossible` resolves the app-owned route, defers for blocking UI, selects Game Day, and never starts playback.
- The generic-device build embeds and validates `RollCallControls.appex`; App Intent metadata extraction succeeds.
- `QuickGameDayTests.testControlDestinationIntentQueuesSystemControlRequest` calls `OpenGameDayFromControlIntent.perform()` in-process. It does not invoke the `ControlWidgetButton`, extension, first intent, system handoff, cold launch, or `RootView`.
- Apple documents that an app-opening control should use an intent conforming to `OpenIntent`, with membership in both targets: <https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system>.

**Root cause**

The original implementation assumed a custom URL returned by an extension control would reliably launch its containing app. The current repair removes that route but still assumes the returned second intent will execute in the app process, where its in-memory singleton is observable.

**Why it matters**

The control is publicly installable yet may remain inert. Compile-time registration is not evidence of process routing, locked-device behavior, or cold-launch delivery.

**Recommended change**

First run the physical-device matrix against HEAD. If any system surface still fails, replace the two-stage `AppIntent → OpensIntent → AppIntent(openAppWhenRun:)` chain with one documented shared `OpenIntent` carrying a static Game Day destination value, and route that value in the app scene. Keep all team resolution in `AppModel`.

**Scope / guardrails**

- Preserve the iOS 17 app floor and iOS 18 extension floor, existing bundle identifiers, optional explicit-team Shortcut behavior, remembered-team policy, safe fallbacks, and no-autoplay invariant.
- Do not introduce an app group or duplicate team-state store unless concrete runtime evidence requires it.
- Preserve one invocation and one terminal resolution/fallback telemetry event.

**Acceptance criteria**

- Control Center, Lock Screen, and Action Button open Roll Call cold and warm, select the remembered team, and land on Game Day without playback.
- No remembered team, missing remembered team, and no-team states land on their documented safe destinations.
- Automatic rating/What's New yields; a user-controlled editor defers and the request executes after dismissal.
- The Release extension is embedded/signed and the control icon renders while locked and unlocked.

**Tests / verification**

- Keep resolver unit tests but add a test around the public control action rather than invoking only its destination.
- Add app-level request lifecycle tests for pre-launch queuing, blocking presentation deferral, and exactly-once consumption.
- A physical iOS 18+ device matrix is mandatory; system controls cannot be accepted from unit tests alone.

# All Other Priority Findings

## [P1] Apple Music metadata refresh destroys a prepared portable clip

**Area:** State

**Confidence:** Confirmed

**Status (2026-09-09):** Closed; refresh now preserves the existing private clip and its prepared fields, and the focused regression tests passed on the iOS 27 simulator.

**Problem**

Refreshing incomplete Apple Music metadata round-trips the cue through `Player.cue`'s destructive setter. That setter creates a brand-new `SongClip`, discarding the existing generated asset and its readiness, portability, retry, and lineage state.

**Evidence**

- `Models.swift`, `Player.cue`: the setter assigns `.privateClip(SongClip(cue: newValue))`.
- `AppModel.refreshAppleMusicCueMetadata` resolves title/artist/duration, mutates `currentCue.source`, then assigns `state.teams[teamIndex].players[playerIndex].cue = currentCue`.
- `SongClip(cue:)` initializes fresh generation/readiness/portability/retry/lineage fields; it does not preserve the prior private clip.
- `AppStatePersistenceTests.testAppleMusicMetadataRefreshDoesNotOverwriteNewerSavedCue` checks stale-result protection but does not start with a generated portable asset or assert preservation of clip metadata.

**Root cause**

`Player.cue` conflates “assign a new song” with “edit the playback cue inside the current assignment.” A compatibility convenience property became a hidden destructive write API.

**Why it matters**

A harmless metadata repair can silently demote Ready on Any Device media, force regeneration, lose retry/lineage context, and make package portability change without user intent.

**Recommended change**

In `refreshAppleMusicCueMetadata`, mutate the existing private `SongClip` in place: update its Apple Music `originalSource`, preserve clip identity and unrelated fields, and deliberately re-evaluate generation-key validity. `playbackCue` is computed from the clip rather than stored separately. The current key depends on song identity, timing, and generation policy, so descriptive metadata such as title, artist, duration, and preview URL should not invalidate an otherwise current generated asset. Make destructive new assignment explicit (`assignNewSong`) and restrict or remove the public setter where practical.

**Scope / guardrails**

- Preserve stale async-result guards and do not overwrite a newer user selection.
- If metadata that participates in the generation key changes, recompute validity deliberately; do not blindly retain an actually stale render.
- Maintain decoding compatibility for legacy `cue` payloads.

**Acceptance criteria**

- Refresh updates missing metadata without changing clip identity or unrelated clip fields.
- A current generated portable asset remains current when only descriptive/source metadata changes.
- A user replacement still creates an independent assignment with correct invalidation.

**Tests / verification**

- Extend the metadata-refresh test with a fully populated private clip and field-by-field preservation assertions.
- Add separate tests for descriptive-only refresh, generation-key-changing refresh, stale resolver completion, and user replacement.

---

## [P1] Unreadable app state is preserved as bytes but is not recoverable in the app

**Area:** Persistence

**Confidence:** Strong evidence

**Status (2026-09-09):** Closed; fail-closed recovery and snapshot discovery were implemented, the focused persistence/cleanup tests passed, and the decision was recorded in `docs/DECISIONS.md`.

**Problem**

When `state.json` is corrupt or from a newer schema, launch copies it to a random `state-unreadable-*.json`, starts with `AppState.empty`, and `AppModel.init` immediately calls `persist()`. The primary state is therefore replaced by an empty state, while the preserved copy and orphaned snapshot files have no in-app discovery/restore route.

**Evidence**

- `AppModel.loadInitialState` calls `preserveUnreadableStateFile` and returns `freshEmptyState()` for decode failure or unsupported schema.
- `preserveUnreadableStateFile` copies the primary file to `AppPaths.unreadableStateRecoveryURL()`.
- `AppModel.init` normalizes the empty state and calls `persist()` unconditionally.
- `RecoveryCenterView` lists only `state.snapshots`; those records were inside the unreadable state and are absent from the new empty state even if snapshot files still exist.
- Repository-wide search finds no reader, importer, listing, support export, or cleanup path for `state-unreadable-*.json`.
- With no teams, `RootView` forces onboarding, so ordinary Settings → Recovery is not immediately reachable.

**Root cause**

Recovery was implemented as file preservation, not a product recovery workflow. Backup discoverability is stored in the same state whose failure is supposed to be recoverable.

**Why it matters**

A single malformed or future-version state file makes all teams appear gone. The app truthfully says it saved a copy, but a normal user cannot use that copy, and reinstalling an older build after opening a newer schema cannot restore it automatically.

**Recommended change**

Do not overwrite the primary state until a recoverable decision has been recorded. Add a bounded recovery launch state that can: retry, inspect compatible backup snapshot files independently of state metadata, export/share the preserved raw state for support, or intentionally start fresh after explicit confirmation. Future-schema files must remain untouched for forward-version recovery.

**Scope / guardrails**

- Never attempt lossy best-effort decoding or silently downgrade a future schema.
- Preserve media assets, telemetry preference/store, purchase state, and raw recovery files.
- Avoid exposing personal state contents in routine telemetry or support bundles.
- Existing valid-state launch must remain fast.

**Acceptance criteria**

- Corrupt and future-schema state never gets overwritten merely by launch.
- The user can reach a recovery screen without creating a replacement team.
- Independently valid snapshots can be discovered and restored even when primary state metadata is unreadable.
- Starting fresh is explicit, and the preserved original remains exportable until the user intentionally removes it.

**Tests / verification**

- Add launch-level tests with corrupt, future-schema, and valid legacy state files, verifying the exact bytes at the primary and recovery URLs before and after user choice.
- Add orphan-snapshot discovery tests and a UI test for the recovery launch route.
- Manually verify upgrade → newer schema → older build behavior with disposable data.

---

## [P1] Audio-session interruptions have no state or reactivation recovery

**Area:** Playback

**Confidence:** Needs validation

**Status (2026-09-09):** Rollback applied as the accepted immediate mitigation after the attempted integration stopped Game Day songs while announcements still worked. The original recovery finding remains open for a redesigned, device-tested implementation.

**Problem**

Roll Call observes audio-route changes only to refresh readiness. It does not observe `AVAudioSession.interruptionNotification` or media-service reset, and it activates the playback session at launch/after recording rather than before recovery playback. An interruption can therefore leave `CuePlaybackEngine.activeCueID` claiming a cue is active after the system stopped it and can leave later playback dependent on implicit session reactivation.

**Evidence**

- `AppModel.observeReadinessInputs` listens only for `AVAudioSession.routeChangeNotification` and output-volume KVO.
- No application code references `AVAudioSession.interruptionNotification`, interruption type/options, or `mediaServicesWereResetNotification`.
- `CuePlaybackEngine` owns `activeCueID` and clears it through its own scheduled stop/begin/explicit stop paths, not actual audio-session interruption callbacks.
- `CuePlaybackEngine.play` treats a tap on the same active cue as Stop and returns a cancelled result. If interruption leaves stale state, the first recovery tap can stop stale state instead of replaying.
- There are no interruption/route-loss tests, while the audit brief and Game Day north star make live recovery material.

**Root cause**

The engine models expected cue timing but not external audio-session lifecycle events.

**Why it matters**

Calls, Siri, alarms, route loss, or media-service reset happen during real games. Stale UI, a two-tap restart, or failure to reactivate is a direct Game Day reliability defect.

**Recommended change**

Add one app-owned interruption coordinator. On interruption begin, cancel timers/progress, clear or explicitly mark active playback, and preserve only the minimum intent needed for an honest UI. On interruption end, reactivate the session when permitted but do not unexpectedly auto-resume a walk-up cue; the next player tap should start immediately. Handle media-service reset by rebuilding affected playback controllers.

**Scope / guardrails**

- Do not auto-play after a phone/Siri interruption without explicit product approval.
- Preserve the current tap-to-stop behavior for genuinely active cues and the established fallback chain.
- Route changes should refresh readiness and safely reconcile active playback without showing unrelated modal UI in Game Day.

**Acceptance criteria**

- After interruption begins, the UI does not show a stopped cue as playing.
- After interruption ends, one tap starts the intended cue and normal fallback remains available.
- Headphone/Bluetooth route removal and media-service reset do not leave unrecoverable playback state.
- No rating, support, repair, or permission presentation interrupts live use.

**Tests / verification**

- Extract a testable interruption state reducer and cover begin/end, should-resume/no-resume, stale callback, route loss, and media reset.
- On device, test a call/Siri interruption during intro, local song, Apple Music song, preview, and fade; verify the next tap and volume restoration.

---

## [P2] Low-volume warning is hidden when Volume Automation is enabled

**Area:** Game Day

**Confidence:** Confirmed

**Status (2026-09-09):** Closed for the warning-visibility defect; owner verified the warning appears with Volume Automation on and off. A separate Volume Automation playback-baseline regression was discovered during that verification and is tracked immediately below.

**Problem**

Both live-warning filters suppress the volume issue when `fadeOutVolumeAutomationEnabled` is true, even though automation captures the current system volume as its baseline and scales relative to it. A 10% system volume remains quiet.

**Evidence**

- Before the fix, `RootView.hasLiveGameDayWarning` and `GameDayView.isLiveReadinessIssue` returned `!fadeOutVolumeAutomationEnabled` for `.volume` checks.
- `ReadinessService.snapshot` creates an issue strictly below 0.30, and the shared warning policy now surfaces it for both automation states.
- `MediaPlayerCatalogPlaybackController.captureSystemVolumeBaseline` reads `AVAudioSession.shared.outputVolume`; this warning fix does not change playback volume behavior.
- Regression tests cover the 0.29/0.30 boundary and both Volume Automation states; owner device verification confirmed the warning presentation.

**Root cause**

The UI equates fade/restore automation with loudness normalization. The playback implementation does not provide normalization.

**Why it matters**

Roll Call can tell a coach Game Day has no warnings while the speaker is too quiet, exactly where a preflight warning is most useful.

**Recommended change**

Always surface the low-system-volume warning. If wording needs to differ when automation is on, explain that automation manages fade/restore but cannot raise the system output volume.

**Scope / guardrails**

- Do not change playback volume behavior or use private system-volume APIs as part of this UI fix.
- Preserve the 30% threshold unless field evidence supports a separate product decision.

**Acceptance criteria**

- Below 30%, Game Day and its banner show a volume warning with automation on or off.
- At/above 30%, no low-volume warning appears.
- Toggling automation does not imply a louder cue.

**Tests / verification**

- Move live-warning classification into a testable helper shared by banner and Game Day.
- Add threshold tests at 0.29/0.30 with both setting values and manually verify wording on device.

**Change log**

- 2026-09-09: Added a shared live-warning policy for the Game Day banner and readiness screen. Low-volume warnings now remain visible regardless of Volume Automation because automation fades/restores playback but does not raise the device output baseline.
- 2026-09-09: Centralized the 30% threshold in `ReadinessService` and added regression tests for the strict threshold and both Volume Automation states.
- 2026-09-09: `ReadinessServiceTests` passed on the iOS 27 simulator, including the 0.29/0.30 threshold checks and Volume Automation on/off warning checks. Owner then verified the warning on a physical device with automation on and off.

---

## [P1] Volume Automation jumps to the wrong playback baseline at fade and restore

**Area:** Playback / Apple Music Volume Automation

**Confidence:** Confirmed physical reproduction; candidate root-cause instrumentation is now in place

**Status (2026-09-09):** Closed for the reproduced regression; owner verified that the candidate removes the volume jump in physical-device testing. The candidate captures both the system-output and MediaPlayer playback baselines, fades/restores in the MediaPlayer domain, and restores the outgoing playback baseline during cue handoff. The broader device/route matrix below remains release evidence to collect, but is no longer blocking this reported issue.

**Problem**

With Volume Automation enabled and the device set to about 40%, an Apple Music song begins at the expected 40%. At the fade boundary it jumps to roughly 90%, fades from that louder level to zero, and then restores to roughly 90% instead of the user's original 40% level.

**Evidence**

- `MediaPlayerCatalogPlaybackController.play` captures `AVAudioSession.sharedInstance().outputVolume`, then stops/configures/starts the `MPMusicPlayerApplicationController` without setting its own volume before or after `player.play()`.
- `setVolume` and `restoreVolume` write through the deprecated public `MPMusicPlayerController.volume` setter via KVC, using the captured audio-session value as the multiplier/restore value.
- `CuePlaybackEngine.fadeCatalog` begins the fade by writing `setVolume(1.0)` and ends it at `setVolume(0.0)`. Therefore the first fade write reasserts the captured baseline; the observed jump means the captured session baseline and the MediaPlayer volume actually heard before the fade are not equivalent on the reporting device/route.
- The `setsInitialVolumeToMax` parameter is passed into the controller but is currently ignored. Announcement-to-song playback passes it as `false`, so restoring historical conditional writes would not cover all Game Day paths consistently.
- The parent of historical commit `79245b0` did set the MediaPlayer volume to its anchor before and after `player.play()`. Commit `79245b0` removed those writes while changing the anchor to `AVAudioSession.outputVolume`; this is a strong historical correlation, not proof that the old writes are safe today.
- The approved decision in `docs/DECISIONS.md` requires no volume change before fade-out and exact post-stop restoration. The new 2026-09-09 qualification keeps that contract while making the MediaPlayer playback value, rather than the audio-session reading, the fade/restore anchor.

**Root cause**

The implementation conflates two volume domains: the audio-session output-volume reading and the MediaPlayer's playback-volume state. Their numeric ranges look compatible, but the device result shows that they cannot currently be treated as interchangeable. The decisive missing evidence is the existing captured-baseline log alongside the MediaPlayer KVC volume immediately before playback, after start, at the first fade write, and after restore.

**Why it matters**

This can produce an unexpected loud burst in front of a crowd and leave the user's playback volume changed after the cue. It directly violates the live-use requirement that automation fade from and return to the user's chosen level.

**Recommended change**

Use the implemented candidate for device verification. It captures both volume domains for evidence, uses the MediaPlayer playback value as the testable fade/restore anchor, leaves the device output untouched before fade-out, restores the outgoing playback baseline during replacement, and fail-closes automation writes if the public MediaPlayer getter is unavailable. Do not reintroduce the historical pre/post-play writes or combine this work with the open audio-session interruption redesign without new device evidence.

**Scope / guardrails**

- Do not raise the device volume, auto-boost quiet playback, or use private system-volume APIs.
- Preserve the approved no-change-before-fade contract unless a new explicit product decision replaces it.
- Cover direct songs and announcement-to-song handoff; preserve rapid cue replacement and exact restore behavior.
- Keep local/generated/Announcement Cue playback unchanged unless evidence shows the shared audio session requires a coordinated change.
- Do not combine this work with the open audio-session interruption redesign.

**Acceptance criteria**

- At 20%, 40%, and 80% baselines, catalog and Music Library songs start and sustain at the selected audible level without an upward jump.
- The fade is monotonically downward from that level to zero, and natural stop restores the exact pre-cue level.
- Announcement → song handoff causes no volume jump, including when the saved announcement path passes `setsInitialVolumeToMax: false`.
- Manual stop, rapid replacement, route changes, and start failure do not leave attenuation or a changed user volume.
- Volume Automation off causes no programmatic volume movement at cue start, fade boundary, stop, or restore.

**Tests / verification**

- `PlaybackVolumeBaseline` has deterministic tests for dual-domain baseline mapping, player-domain fade/restore, clamping, and invalid inputs; the focused `SongClipGenerationTests` and all focused `ReadinessServiceTests` passed on the iOS 27 simulator. Build-for-testing passed at build 133 (marketing version remains 1.3.0).
- The controller's deprecated KVC getter/setter semantics, capture timing, pre-fade write absence, restore ordering, announcement handoff, and rapid replacement are not established by unit tests; the physical matrix is the acceptance gate for those behaviors.
- The full `SongClipGenerationTests` run was started but did not complete because the simulator harness hung in `simctl diagnose`; no assertion failure was shown before the run was stopped, so it is not counted as a pass.
- Owner verified the reported physical-device case after implementation and reported that the volume behavior now works as expected.
- For broader release evidence, test catalog and Music Library songs on the reporting device and one additional supported device at 20/40/80% using the built-in speaker and a Bluetooth/PA route.
- Test direct song and Announcement → song playback, natural stop, manual stop during sustain/mid-fade/tail guard, rapid replacement before/mid-fade, background/foreground volume changes, route removal, and playback start timeout.
- Record the visible device volume plus the captured-system and MediaPlayer-volume logs before playback, at fade start, and after restore. Listening alone is insufficient to establish the baseline mapping.

**Change log**

- 2026-09-09: Replaced the audio-session-only automation anchor with a dual-domain diagnostic capture and MediaPlayer playback-domain fade/restore candidate. Cue handoff now restores the outgoing playback baseline before the next cue captures its baseline; unavailable/non-finite getter values fail closed for automation writes.
- 2026-09-09: Build 132 exposed only an incorrect expectation in the new invalid-input test; the expectation was corrected and the candidate was rebuilt as build 133. Focused tests then passed on the iOS 27 simulator; marketing version remains 1.3.0.
- 2026-09-09: Full `SongClipGenerationTests` execution was inconclusive because the simulator test harness stalled in diagnostics; this does not invalidate the focused tests or owner’s physical verification of the reported case.
- 2026-09-09: Owner accepted the physical-device result as working for the reproduced volume-jump case. The P1 is closed, with the broader matrix retained as release evidence.

---

## [P2] Missing Announcement Cue replaces the player's audio verdict and is double-counted

**Area:** State

**Confidence:** Confirmed

**Status (2026-09-09):** Closed for this stabilization pass; owner accepted the implementation and requested the next issue. Focused verification passed on the iOS 27 simulator at build 135. The UI smoke check remains release evidence.

**Problem**

Before the fix, a player whose song was ready but whose saved Announcement Cue file was missing received the announcement issue instead of the audio result. `ReadinessOverviewCard` then classified checks by ID prefix rather than category, counting that announcement as broken song audio; `ReadinessEnhancementsCard` also rendered it by `.playerAnnouncement` category.

**Evidence**

- Before the fix, `ReadinessService.playerReadinessCheck` returned `player-<id>-custom-announcer-issue`, category `.playerAnnouncement`, before returning `.playerAudio` ready/enhanced.
- Before the fix, `ReadinessOverviewCard.playerChecks` selected any `player-` ID except two string exclusions, not `category == .playerAudio`.
- The same issue is eligible for the enhancements card; live warning logic correctly gates it on `gameDayAnnouncerMode.usesAnnouncer`.
- Before the fix, the overview could say “Some Audio Needs Repair” in song-only mode despite a playable song.

**Root cause**

One function attempts to return both primary audio readiness and an orthogonal enhancement issue as a single check, while older UI filtering still infers meaning from identifiers.

**Why it matters**

Readiness becomes misleading and shaming, contradicting the rule that optional announcements do not make a player incomplete and that song-only live use should not warn about an unused intro.

**Recommended change**

Use the implemented category-based seam: emit one `.playerAudio` verdict per present player, emit a separate `.playerAnnouncement` issue/upgrade only when the player’s audio is ready, and filter UI cards by category rather than ID naming conventions.

**Scope / guardrails**

- Missing announcements may warn in announcer modes but must not block Game Day.
- Preserve honest missing-file repair actions and ready/enhanced meanings.

**Acceptance criteria**

- Every present player has exactly one player-audio verdict.
- A missing announcement is shown once in the appropriate section and affects live warnings only when announcer use is enabled.
- Audio ready/needs-audio/repair counts remain correct across all announcer modes.

**Tests / verification**

- `ReadinessServiceTests` now verify that a ready song plus a missing Announcement Cue produces exactly one `.playerAudio` ready check and one `.playerAnnouncement` issue, that announcement warnings surface only in announcer-enabled modes, that a missing announcement is not replaced by an optional upgrade, and that category filtering excludes the announcement from audio counts. The focused suite passed on the iOS 27 simulator at build 135 (marketing version remains 1.3.0).
- UI smoke verification remains: confirm the overview says the song is ready, the announcement appears once under Announcements, and Song Only suppresses the announcement warning while Announcer Only and Announcer + Song surface it.

**Change log**

- 2026-09-09: Split primary player-audio readiness from Announcement Cue readiness. Missing saved announcement files now remain `.playerAnnouncement` issues, while the player retains its `.playerAudio` ready/needs-audio/repair verdict. Removed the duplicate announcement-check producer and changed overview membership to category-based filtering.
- 2026-09-09: Added focused snapshot, warning-policy, and category-filtering tests; build 134 and all `ReadinessServiceTests` passed on the iOS 27 simulator.
- 2026-09-09: Added coverage for the optional Announcement Cue upgrade path and rebuilt as build 135; all `ReadinessServiceTests` passed on the iOS 27 simulator.
- 2026-09-09: Owner accepted the readiness-verdict implementation and requested the next audit issue; UI smoke verification remains release evidence.

---

## [P2] Telemetry performs atomic JSON writes synchronously on the main actor during live use

**Area:** Telemetry

**Confidence:** Strong evidence

**Problem**

`RollCallTelemetryCoordinator` is `@MainActor`, and `TelemetryStore.save` synchronously encodes the growing store, creates a directory, and atomically writes a file. Confirmed player/clip playback, continuations, recovery paths, failures, lineup changes, and thresholds call this path on the main actor.

**Evidence**

- `Telemetry.swift`: `RollCallTelemetryCoordinator` is `@MainActor`; `TelemetryStore.save` calls `JSONEncoder.encode` and `Data.write(options: .atomic)` synchronously.
- `AppModel.play(player:)` calls `beginLiveSessionIfNeeded`, `handlePlayerPlayback`, and possibly `recordRecovery` immediately after confirmed playback. The live methods now admit the updated checkpoint/count for ordered background persistence and hold dependent signals until the write succeeds.
- The store accumulates UUID sets/date histories and checkpoint state, so write cost is not constant forever.
- Existing telemetry tests validate ordering/failure semantics using tiny temporary files; none measures main-thread time or rapid Game Day taps.

**Root cause**

The required persist-before-enqueue semantics were implemented by making policy mutation and physical persistence one synchronous main-actor operation.

**Why it matters**

Audio is started before most telemetry writes, but the UI actor and subsequent taps can still stall. Telemetry must never degrade live control responsiveness, particularly on older devices or large long-lived stores.

**Recommended change**

Move encoding/writing to a serial actor or dedicated queue while preserving strict ordering and the conservative false-negative rule. Apply immutable candidates in sequence, persist before provider enqueue, coalesce only events whose semantics permit it, and suspend telemetry—not Game Day—on failure. Measure before/after tap responsiveness.

**Scope / guardrails**

- Do not weaken opt-out, crash consistency, de-duplication, conservative recovery, or rating-policy durability.
- Do not let asynchronous writes reorder candidates or enqueue a signal before its consumed state is durable.
- Core playback must proceed even if telemetry is suspended.

**Acceptance criteria**

- No telemetry file encoding/write occurs on the main thread.
- Event ordering, exactly-once consumption bias, disabled behavior, and persistence-failure suspension remain unchanged.
- Rapid live taps remain responsive with a realistically large telemetry store and injected slow writes.

**Tests / verification**

- Retain current semantic tests and add delayed-writer ordering, cancellation, backpressure, failure, and main-thread assertions.
- Add an instrumented performance test using a large synthetic store and a live-tap latency budget.

**Current status**

Implementation is complete in build 144; the telemetry schema is unchanged. `TelemetryStore` performs synchronous compatibility saves through a serial background writer, while live-session snapshots are admitted without waiting for disk and their signals are released only after the ordered write succeeds. Synchronous and asynchronous saves share the same failure barrier; ordered revisions preserve the newest durable rollback baseline; the live queue and pending signal list are bounded; failed persistence restores the last durable snapshot, closes telemetry conservatively, and requires an explicit retry. Queued signals carry a generation so opt-out/re-enable cannot release stale work. Owner accepted the physical live-use check; the broader slow-writer and route matrix remains non-blocking release evidence.

**Verification performed**

- Build-for-testing succeeded on the iOS 27 simulator with Swift 6 at build 144.
- The focused `TelemetryTests` suite reported 36 tests, 0 failures on the iOS 27 simulator. Coverage includes off-main file work, delayed persist-before-send, FIFO live writes, the shared sync/async failure barrier, newest-durable-state rollback, bounded pending signals, retry behavior, and opt-out generation invalidation. Xcode remained in test-log cleanup after emitting the passing suite result, so the final `xcodebuild` process exit was not used as evidence.
- Sol acceptance review accepted the implementation. Xcode's Thread Performance Checker reports expected warnings for synchronous non-live/rating durability calls waiting on the utility writer; protected Game Day/Clips paths use asynchronous ordered persistence.

**Additional release evidence**

- If a diagnostic build with an injected slow/blocked telemetry writer is available, exercise Game Day and confirm a second player tap and its fallback/audio path remain responsive; telemetry may suspend, but playback must continue.

**Change log**

- 2026-09-09: Owner approved the telemetry blocker fixes. Unified synchronous and asynchronous failure barriers, tracked the newest durable state by persistence revision, bounded pending signals, and routed unavailable Custom Clip repair telemetry through the asynchronous live path. Build-for-testing passed at build 144; focused `TelemetryTests` reported 36/36 on the iOS 27 simulator, including automated opt-out invalidation coverage. Physical live-responsiveness verification remains owner verification.
- 2026-09-09: Owner approved the telemetry blocker fixes. Unified synchronous and asynchronous failure barriers, tracked the newest durable state by persistence revision, bounded pending signals, and routed unavailable Custom Clip repair telemetry through the asynchronous live path. Build-for-testing passed at build 144; focused `TelemetryTests` reported 36/36 on the iOS 27 simulator, including automated opt-out invalidation coverage.
- 2026-09-09: Owner accepted the physical live-use result; telemetry is closed for this stabilization pass. Broader slow-writer and route-matrix checks remain release evidence.

---

## [P2] Team-package archives are extracted before size and entry validation

**Area:** Persistence

**Confidence:** Strong evidence

**Problem**

Every file-form `.rollcall` package is fully unzipped into a temporary directory before app-owned manifest/schema/path and resource-bound validation. Roll Call imposes no cap on archive size, entry count, total uncompressed bytes, compression ratio, or individual asset dimensions/duration before extraction.

**Evidence**

- `PackageService.extractedDirectoryIfNeeded` calls `FileManager.default.unzipItem` directly.
- `previewDetails` and `importWithAudit` decode and validate the manifest only after extraction.
- `validateImportableTeam` checks duplicate IDs/lineup membership but not roster/clip counts or archive resource bounds.
- Package path tests cover manifest path traversal, not malicious archive entries or resource exhaustion.

**Root cause**

The importer delegates the extraction boundary to ZIPFoundation without adding Roll Call-specific resource limits or explicitly verifying the dependency's handling of hostile entry types.

**Why it matters**

Manual package sharing is a core ownership feature. A corrupt or hostile shared package can consume disk/memory or hang/fail the app before Roll Call can reject it cleanly.

**Recommended change**

Inspect archive entries before extraction and enforce conservative entry-count, per-file, and total-uncompressed limits sized above legitimate team exports. Verify ZIPFoundation's absolute/traversal/symlink handling with adversarial fixtures and add app-owned rejection where its guarantees are insufficient. Stream/copy only expected manifest/assets into the app-owned temp root, validate media before permanent copy, and clean on every exit.

**Scope / guardrails**

- Preserve schema-9 backward compatibility and valid large real-world photos/audio.
- Do not alter package contents or break older valid exports without measured limits and fixtures.
- All cleanup must remain confined to the unique app-owned temp directory.

**Acceptance criteria**

- Oversized, high-ratio, traversal, absolute, symlink, duplicate-path, and excessive-entry archives fail quickly with `invalidImport`-class user messaging.
- Valid 1.2/1.3 packages preview/import unchanged and leave no temp directories.

**Current status**

Implementation is complete in build 146, and the owner has verified that import/export behaves normally on a physical device. File-form `.rollcall` imports and previews now inspect ZIP central-directory metadata before extraction, cap archive size, entry count, per-entry and total uncompressed bytes, and compression ratio, and reject traversal, absolute, duplicate, and symlink entries. Valid directory-style packages and the existing schema-9 package format remain unchanged. This P2 is closed for the stabilization pass; the broader package/device matrix remains release evidence.

**Verification performed**

- Build-for-testing succeeded on the iOS 27 simulator with Swift 6 at build 146; marketing version remains 1.3.0.
- The focused `PackageServiceTests` suite executed 20 tests with 0 failures. It includes valid schema-9/photo/audio/Apple Music round trips plus generated traversal, absolute-path, duplicate-entry, symlink, high-ratio, excessive-entry, and oversized-entry fixtures.

**Owner verification**

- Owner verified that physical-device import/export behaves normally after the hardening change.
- Automated fixtures verify quick `invalidImport` rejection for traversal, absolute, duplicate-path, symlink, high-ratio, excessive-entry, and oversized-entry archives without extraction.
- The full 1.2/1.3 media matrix, malformed-archive UX, and injected copy-failure cleanup remain broader release evidence rather than blockers for this closed finding.

**Additional release evidence**

- Measure peak disk/memory and validate cleanup after success, rejection, and injected copy failure.

**Change log**

- 2026-09-09: Owner approved archive-boundary hardening. Added ZIPFoundation central-directory preflight before file-form package extraction, conservative archive/entry/resource limits, and rejection for traversal, absolute, duplicate, and symlink entries. Build-for-testing passed at build 146; focused `PackageServiceTests` passed 20/20 on the iOS 27 simulator.
- 2026-09-09: Owner verified that physical-device import/export behaves normally. The Team-package archive finding is closed for this stabilization pass; broader package/device coverage remains release evidence.

---

## [P2] Three legacy item alerts compete on the Recovery screen

**Area:** UI

**Confidence:** Implemented; needs runtime validation

**Problem**

`RecoveryCenterView` stacks three deprecated `alert(item:content:)` modifiers on the same `List` for backup restore, permanent deletion, and partial restore. SwiftUI alert modifier precedence has historically made stacked legacy presenters unreliable; this is the app's destructive/recovery surface.

**Evidence**

- Before the fix, `RootView.swift`, `RecoveryCenterView.body`, consecutively applied `.alert(item:)` for `backupPendingRestore`, `recentlyDeletedPendingPermanentDelete`, and `pendingPartialRestorePrompt`.
- The current body uses one `pendingRecoveryAlert` enum and one modern `alert(_:isPresented:presenting:actions:message:)` presenter.
- The rest of the app commonly uses the modern `alert(_:isPresented:presenting:actions:message:)` form.
- There are state/service tests for backup and Recently Deleted operations, but no UI presentation test proving that all three confirmations appear and execute their intended action.

**Root cause**

Independent modal states were layered onto one view using an obsolete presenter API rather than one explicit recovery alert route. The approved fix replaces those states with one identifiable `RecoveryAlert` route and one modern `alert(_:isPresented:presenting:actions:message:)` presenter.

**Why it matters**

A missing confirmation can make restore or permanent delete appear dead, or can undermine an irreversible-action guard.

**Recommended change**

Completed in the working tree: replaced the three modifiers with one identifiable recovery-alert route and one modern alert presenter. Each action's role, message, and async behavior remains explicit.

**Scope / guardrails**

- Permanent delete remains destructive and explicitly confirmed.
- Partial restore must continue to explain missing media; backup restore must create its safety backup.

**Acceptance criteria**

- Each row action presents the correct confirmation every time; cancel is lossless; confirm runs only the selected action.
- Switching quickly between candidate actions cannot present stale content.

**Tests / verification**

- Add UI tests for backup restore, full item restore, partial restore, and permanent delete confirmation/cancel paths using disposable fixtures.

**Implementation / verification update (2026-09-09)**

- `RecoveryCenterView` now uses one `RecoveryAlert` state and one modern alert presenter. Backup restore, partial restore, and permanent deletion retain their previous actions and messages; full restores remain direct actions.
- Focused source inspection confirms that the old stacked `.alert(item:)` modifiers and their independent state are gone.
- Build-for-testing passed for the iOS simulator, and the focused `BackupRestoreTests`, `RecentlyDeletedTests`, and `AppStatePersistenceTests` command exited 0 on the iOS 27 simulator. These suites verify the underlying recovery/backup state operations, not SwiftUI alert presentation.

**Exact verification still needed**

- On a device or simulator, exercise backup restore, full item restore, partial restore, and permanent deletion; confirm each alert title/message, cancel path, and confirm action.
- Trigger candidate actions in quick succession and confirm no stale or cross-wired alert content.
- Confirm backup restore still creates its safety backup and permanent deletion remains explicitly confirmed.

**Change log**

- 2026-09-09: Owner approved the single-route Recovery alert fix. Replaced three stacked legacy alert presenters with one identifiable modern alert route; runtime presentation verification remains open.

---

## [P2] Announcement recording cancel is a no-op during the save phase

**Area:** State

**Confidence:** Confirmed; implementation pending runtime validation

**Status (2026-09-09):** Implemented in the working tree after owner approval. The recorder now uses one lock-protected recording/stopping lifecycle with per-session identity, cancellation claims the pending stop exactly once, and Player Editor dismissal cancels starting, recording, and saving phases. Engineering verification passed; owner/device acceptance remains open.

**Problem**

`CustomAnnouncerRecorder.cancelRecording` immediately returns when a stop/save continuation is pending. Its later `finishPendingStopAsCancelled()` call is unreachable for that pending case, while `AppModel.cancelRecordingCustomAnnouncer` still sets UI phase to idle. Recorder and UI state can diverge during dismissal/cancel.

**Evidence**

- Before the fix, `AppModel.swift`, `CustomAnnouncerRecorder.cancelRecording` returned while `stopRecording()` had a pending delegate continuation; its later cancellation-resume path was unreachable for that case.
- `PlayerEditorSheet.onDisappear` called `appModel.cancelRecordingCustomAnnouncer`, but the model could set `.idle` while recorder work remained pending.
- No recorder state-transition test covered cancel while `stopRecording()` awaited the encoder callback.

**Root cause**

Cancellation semantics were added around an async delegate continuation without one authoritative recording state machine.

**Why it matters**

Closing the editor during save can leave pending work/state behind, produce a late callback after UI reset, or retain/delete the wrong temporary recording.

**Recommended change**

Make cancellation atomically take either the active recording or pending stop continuation, synchronize in-memory recorder-field clearing with that claim, then stop/delete/resume outside the lock. Match delegate callbacks to the active recorder/session so stale callbacks cannot affect a later recording. Keep the model's UI phase guarded by the same session token and treat expected cancellation as non-error.

**Scope / guardrails**

- Never delete a successfully committed Announcement Cue.
- Preserve immediate playback-session restoration after recording and microphone-denial behavior.

**Acceptance criteria**

- Cancel during recording and during stopping reaches a single terminal state with no continuation leak or late UI mutation.
- Saved recordings remain; cancelled temporary files are removed; subsequent recording works immediately.

**Tests / verification**

- Added `CustomAnnouncerRecorderTests` for active-recording cancellation, callback-first completion, cancel-first completion, duplicate terminal handling, stale session callbacks, and immediate subsequent recording. Build/test verification and runtime owner checks remain to be recorded below.

**Verification performed**

- Build-for-testing succeeded at build 146 on the iOS 27 simulator after the final race fixes.
- The focused `CustomAnnouncerRecorderTests` run completed successfully with 4/4 passed. The selected `AppStatePersistenceTests` all reported passed before Xcode stalled finalizing simulator diagnostics; that separate command was stopped after its test cases completed, so its overall harness exit was inconclusive.
- `git diff --check` passed.

**Exact verification still needed**

- On a physical device, start an Announcement Cue, tap Stop Recording, then dismiss the editor while the button says `Saving Recording...`; confirm the pending save cancels cleanly, no error appears, no partial temporary file remains, and an existing saved cue is unchanged.
- Repeat cancel during active recording, then record again immediately; confirm microphone permission denial behavior, playback audio-session restoration, and successful save behavior are unchanged.

**Change log**

- 2026-09-09: Owner approved the cancellation fix. Replaced the pending-stop no-op with an atomic recording/stopping arbiter, added session and recorder identity protection with atomic in-memory cleanup, cleaned failed temporary files, suppressed expected cancellation errors, and made Player Editor dismissal cover starting, recording, and saving phases. Focused simulator tests and build verification passed; runtime/device verification remains open.

---

## [P2] Large unreachable feature remnants remain in the Release target and test surface

**Area:** Architecture

**Confidence:** Confirmed

**Problem**

The Release target still compiles substantial unreachable implementations and AppModel surface from removed or relocated features, particularly Music Render Probe, the old Player Editor trim UI, and built-in announcer speech generation.

**Evidence**

- `MusicRenderProbeView.swift` has no UI reference; `MusicRenderProbeService`, `MusicRenderProbeModels`, numerous `AppModel` properties/methods, and `MusicRenderProbeTests` remain.
- `RootView.cueTrimSection(for:)` has no call site, leaving `showAdvancedTrim`, `AdvancedTrimSheet`, scrub controls/tasks, trim helpers, and a latent `editableCue!` force unwrap unreachable.
- `AnnouncerSpeechRenderer` and associated regeneration types/methods remain even though `previewBuiltInAnnouncer` and `saveSelectedTeamAnnouncerProfile` only report that Built-in Voice was removed.
- Persisted `ExperimentalSettings` playlist flags are encoded/decoded but not read, while playlist UI ships ungated.

**Root cause**

Iterative feature removal and consolidation disconnected entry points without deleting their implementations, tests, and persistent compatibility surface.

**Why it matters**

Dead code increases compile/review surface, leaves tests aimed at behavior the product cannot reach, preserves unsafe code such as a force unwrap, and makes future maintainers unsure which behavior is authoritative. This is exactly the kind of AI-assisted drift that can resurrect obsolete behavior accidentally.

**Recommended change**

Confirm the already-documented product decisions, then delete unreachable UI/services/AppModel APIs and their implementation-detail tests in one bounded cleanup. Retain only decode shims required for existing stored data and package compatibility; document those as compatibility-only.

**Scope / guardrails**

- Do not remove the current Song Clip editor, playlist feature, legacy data decoding, or Announcement Cue recordings.
- Do not reinterpret `PRODUCT_OPPORTUNITIES.md` as approval to restore removed features.
- Verify Release and test target membership after deletion.

**Acceptance criteria**

- Repository search shows no unreachable Music Render Probe/old trim/built-in speech entry points or stale model fields except explicitly documented decode compatibility.
- Current player editing, clip creation, playlist, playback, and old-state decoding remain unchanged.

**Tests / verification**

- Remove tests that only keep dead code alive; retain/add tests around the surviving product behavior and legacy decode fixtures.
- Compile all configurations and run the full suite after the cleanup.

---

## [P3] Four missing player-media types are formatted as only three

**Area:** UI

**Confidence:** Confirmed

**Problem**

`playerMissingSummaryText` supports only one, two, or three names. `missingMediaTypes` can return four (`photo`, `photoSource`, `announcementCue`, `song`), so a maximally degraded player silently omits one item. `MissingMediaSummary.warningText` has the same three-segment cap for team-level media categories.

**Evidence**

- `AppModel.missingMediaTypes` appends four independent cases.
- `playerMissingSummaryText` falls through to indexes 0...2 for every count above two.
- `MissingMediaSummary.warningText` likewise joins only its first three segments.

**Root cause**

User-visible list grammar was hand-coded for a fixed maximum that the data model later exceeded.

**Why it matters**

Recovery confirmation understates what will be missing, weakening informed consent for partial restore.

**Recommended change**

Use one generic locale-aware list formatter/helper for all counts and singular/plural lead-ins.

**Scope / guardrails**

- Preserve existing terminology and the distinction between compact photo and full photo source.

**Acceptance criteria**

- Zero through four player types and one through four team segments are all represented exactly once with correct grammar.

**Tests / verification**

- Add table-driven formatter tests for every count/order and a partial-restore message containing all four player types.

---

# 1.3 Feature Health

## App Intents

**Needs stabilization.** The resolver, remembered-team semantics, explicit-team handling, safe fallbacks, target membership, extension embedding, and cold-launch request queue are coherent. The original Control Center integration was wrong, and the current nonstandard two-intent handoff is still unproven across the system boundary. Shortcuts are broadly sound; system controls require the physical-device gate in the first finding.

## Telemetry

**Mostly healthy with isolated defects.** The typed event/property allowlist, privacy gate, independent versioned store, conservative recovery, persist-before-enqueue rule, source-family distinctions, correlated confirmed-start logic, probable-game model, opt-out consumption, and extensive policy tests make the data model substantially trustworthy for product decisions. Do not use production data to judge Control Center success until the actual system route is accepted, and remove main-actor persistence risk before calling telemetry operationally invisible in Game Day.

## Player Cards

**Needs stabilization.** The approved renderer/data model, 1.3 photo master, independent crops, package compatibility, legacy fallback, and rendering tests are coherent. The two known failures were localized framework/presentation defects with credible repairs, not evidence that the entire feature should be redesigned. The feature remains below release confidence until preview, profile/card adjustment, Share sheet, legacy photos, resource packaging, memory behavior, accessibility, and repeated lifecycle transitions pass on device.

# Core App Health

## Game Day / Playback

**Mostly healthy with a significant lifecycle gap.** The fallback plan is centralized, confirmed component starts are modeled explicitly, selected-media failure is distinguished from intentional built-in fallback, rapid taps are guarded, live progress republishing was removed, and focused fallback tests exist. The missing audio-session interruption/media-reset handling and the newly reproduced Volume Automation baseline regression are the main playback risks. Device/account validation remains necessary for Music Library, Apple Music catalog/preview, fade/volume restoration, Bluetooth/route changes, and interruption recovery.

## Player / Team / Lineup State

**Mostly healthy.** Team selection, remembered Game Day team, presence, lineup ordering, customization, duplication, and legacy private-song migration have focused tests and largely clear ownership. The destructive `Player.cue` compatibility setter is the largest source-of-truth defect; readiness's announcement/audio conflation is a smaller example of orthogonal state being forced into one result.

## Persistence / Restoration

**Mostly healthy in ordinary operation, needs stabilization in disaster recovery and Recovery presentation.** Normal state writes are serialized, background flush waits for durability, asset cleanup is conservative around backups/Recently Deleted, imports do not overwrite existing teams, and package compatibility now includes bounded archive preflight plus physical import/export acceptance. Primary-state decode failure is not recoverable through the product, and recovery confirmations lack presentation proof.

## Onboarding / Settings / General UI

**Broadly sound.** Setup remains progressive, permission requests follow intent, support/rating surfaces are kept out of live tabs, and current appearance rules are consistently represented. The major UI weakness is testing: there is no UI test target, so presentation host, modal timing, cancellation, destructive alerts, VoiceOver, and system-surface behavior are mostly manual assumptions.

# Cross-Cutting Root Causes

1. **Framework boundaries are unit-tested below the failure point.** UIKit asset decoding, SwiftUI sheet/cover transitions, Share sheet presentation, and WidgetKit/App Intent launch routing all compiled and had nearby tests while real behavior failed.
2. **Atomic state invariants are sometimes split across convenience APIs.** The old photo cover split trigger/content; `Player.cue` splits the concept of cue mutation from `SongClip` ownership; readiness returns one check for two independent dimensions.
3. **Recovery metadata depends on the state being recovered.** Snapshot files can survive while their discoverability disappears with corrupt `state.json`.
4. **Live subsystems are modeled around expected internal timing.** Playback has strong internal sequencing but no external audio-session interruption reducer; telemetry honors durable semantics but performs its storage work on the live UI actor.
5. **Old identifier/string conventions remain after typed models were added.** Readiness UI filters IDs instead of categories, and import aggregation predates the photo-source state.

# Test-Suite Blind Spots

The suite is broad but almost entirely service/model XCTest. No UI test target exercises the application's real presentation graph. The three known failures escaped because:

- Player Card tests rendered content but did not prove the shipped special app-icon resource, SwiftUI sheet, async task, and share controller together. The new renderer test still stops below presentation.
- Photo tests proved geometry and preparation but not that a presented full-screen cover always has complete content under SwiftUI update timing.
- Quick Game Day tests call the destination intent in the app test host, bypassing the control button, extension process, system handoff, app launch, and root routing.

Additional false-confidence patterns are the metadata-refresh test that omits generated clip state, telemetry persistence tests that use tiny fast files on the main actor, recovery service tests without alert presentation, and passing tests for unreachable Music Render Probe code.

The smallest material improvement is not “more unit tests.” Add one app UI/integration target with stable fixtures and cover: Player Editor → card preview/share; profile/card framing open/cancel/apply; all Recovery alert routes; root handling of queued Quick Game Day requests. Keep a documented physical-device matrix for Control Center/Lock Screen/Action Button, audio interruptions/routes, Apple Music/Music Library, and Share sheet because automation cannot fully emulate those services. Add launch harnesses that supply corrupt/future state and slow/failing telemetry stores, and strengthen existing unit fixtures around complete `SongClip` state.

# Things I Investigated but Do NOT Recommend Changing

- **The Game Day fallback chain.** The plan/engine/telemetry split correctly distinguishes intentional Small Cheer from selected-media failure and supports intro+song, song-only, intro-only, and built-in recovery. Fix lifecycle gaps locally; do not rewrite playback architecture.
- **Team session persistence.** Persisting announcer mode, lineup order, presence, and useful context without inventing a formal game entity matches current decisions.
- **Separate telemetry/rating storage.** Keeping it outside `AppState`, packages, backups, Recently Deleted, and team duplication is intentional and privacy-correct. The needed change is execution isolation, not merging stores.
- **The additive schema-9 photo fields.** Shipping the working master/crops additively while older importers retain the compact profile is an approved, reasonable compatibility tradeoff.
- **Source-backed Apple Music readiness.** “Ready on This Device” is intentionally honest rather than forcing an unreliable local-copy promise. Preserve saved source truth and fallback behavior.
- **The deprecated Music player volume setter.** The implementation probes selector availability before KVC and is covered by a compatibility test. It is a conscious public-API compatibility choice; do not remove it during unrelated cleanup. Still device-test volume restoration.
- **Toolbar placement in `SongPickerFlow`.** The older audit considered the files-mode Cancel toolbar attached to the wrong view. A toolbar modifier on a `NavigationStack` can be valid SwiftUI composition, and static inspection does not prove it is absent. Device-check stalled import cancellation, but do not change this without reproduction.
- **Window-level live-surface swipe recognizer.** It is fragile for future modals, but current root blocking state enumerates the live presentations found in this audit. Treat scoped attachment as future hardening, not a 1.3 fix unless device testing reproduces interaction leakage.
- **O(n²) lineup ordering and per-row recovery checks.** Team sizes are small; no measured field performance evidence justifies prioritizing these over correctness work.
- **Keeping missing photo masters out of the aggregate “Clip Portability” totals.** The earlier audit treated this as an omission, but the aggregate is explicitly clip-scoped and `.photoSourceMissing` is already visible with a repair action in the Import Check detail. Revisit the copy only if device usability testing shows that users miss or misunderstand the detailed degradation.

# Suggested Implementation Order

1. **Accept the three known fixes first.** Run the device matrix for Player Card crash, profile adjustment, and all system-control surfaces. Make only evidence-driven corrections; prefer a direct shared `OpenIntent` if the current control still fails.
2. **Stabilize the live moment.** Device-accept the Volume Automation baseline candidate, add audio interruption/media-reset handling, and run the full local/catalog/preview/announcement/fallback device matrix.
3. **Repair typed readiness semantics.** Emit independent player-audio and Announcement Cue checks, then make all UI classification category-based.
4. **Isolate telemetry persistence.** Introduce serial off-main storage with slow/failure tests while preserving policy semantics exactly.
5. **Harden ownership/recovery edges.** The archive boundary is now bounded and owner-verified; consolidate the Recovery alerts.
7. **Finish bounded state-machine and reporting validation.** Owner-verify recorder cancellation on device, then address the remaining missing-media grammar issue.
8. **Remove confirmed dead code last.** Once behavior is stable and green, delete unreachable probes/trim/voice remnants without mixing cleanup into functional repairs.

# Post-Fix Verification Plan

1. **Automated baseline**
   - Run all unit tests on a compatible simulator/runtime, not only `build-for-testing`.
   - Run new UI/integration tests for card preview/share, both photo framings, Recovery alerts, queued Quick Game Day routing, and recovery launch.
   - Compile Debug, Internal, and Release app + iOS 18 extension; inspect Release embedding/resources/App Intent metadata and feature-flag safety.

2. **Game Day and playback on device**
   - Use a representative lineup with absent/present players, customized order, no song, local/generated song, Music Library song, Apple Music catalog song, preview-backed song, valid/missing Announcement Cue, and missing selected media.
   - Verify intro+song, song-only, intro-only, intentional cheer, failed-selected-media → cheer, stop/toggle, rapid player switching, on-deck/override/advance, haptics, screen-awake behavior, and no live prompts.
   - Interrupt each important route with Siri/call and Bluetooth/headphone removal; verify honest UI, one-tap next playback, fallback, fade, and volume restoration.

3. **State and recovery**
   - Change teams, presence, lineup, announcer mode, media, and settings; background/terminate/relaunch and confirm exact restoration.
   - Refresh incomplete Apple Music metadata on a prepared portable clip and verify all clip fields/assets survive.
   - Launch with valid legacy, corrupt, and future state; confirm primary bytes are preserved, recovery UI is reachable, orphan snapshots are discoverable, and deliberate start-fresh works.
   - Exercise full/partial Recently Deleted restore and backup restore, including missing song/photo master/profile/announcement/custom-clip assets.

4. **Packages and onboarding/settings**
   - Export/import representative 1.2 and 1.3 packages between devices; confirm imports add rather than overwrite, support/purchase/telemetry state does not travel, source truth survives, and profile-only degradation is reported.
   - Reject bounded malicious archive fixtures without residue or resource spikes.
   - Verify first-run create/import paths, permission timing/denial, analytics toggle, readiness repair actions, rating/support non-live presentation, and all Recovery confirmations.

5. **Player Cards/photos**
   - Preview/share new, legacy-only, no-photo, damaged-master/profile-fallback, all aspect ratios/orientations, long names/numbers, all accents, and all song-source metadata.
   - Adjust profile and card framing independently; verify Save/Cancel, repeated presentation, parent dismissal during analysis, output dimensions, attribution resource, activity completion/cancel, VoiceOver, Dynamic Type, appearance, and memory across repeated renders.

6. **Quick Game Day**
   - Test Shortcut with remembered and explicit teams; Control Center, Lock Screen, and Action Button cold/warm/locked/unlocked; no/missing remembered team; blocking/nonblocking modal states; exactly-once routing; and no autoplay.

7. **Telemetry correctness and invisibility**
   - Verify selected-media failure, intentional no-media fallback, intro failure→song, song failure→intro, complete failure, and built-in intentional playback emit distinct approved semantics.
   - Verify disabled analytics sends nothing and does not backfill; re-enable affects only future eligible signals; corrupt/future/write-failed stores remain conservative.
   - Inject slow/failing writes during rapid live taps and confirm audio/UI remain responsive while telemetry ordering/suspension rules hold.

## Audit Limitations

- The app and complete XCTest bundle compiled successfully for a generic iOS device, but tests could not be executed because this Mac's CoreSimulator service/runtime is incompatible with the installed Xcode beta, as already documented in `WHERE_WE_STAND.md`.
- No physical iPhone, Apple Music account/library, Control Center/Lock Screen/Action Button surface, phone/Siri interruption, Bluetooth route, or system Share sheet was available to this audit. Accordingly, the current repairs for all three known failures remain source-supported rather than release-accepted.
- No crash log beyond the root-cause exception recorded in current source/history was available. Findings labeled Needs validation are bounded hypotheses with explicit device checks, not claims of reproduced current-HEAD failure.
