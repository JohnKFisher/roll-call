# Roll Call 1.3 Code Audit


### M1. `Player.cue`'s setter silently destroys a prepared local clip

`RollCall/Models.swift:315`

```swift
var cue: Cue? {
    get { songAssignment?.privateClip?.playbackCue }
    set { songAssignment = newValue.map { .privateClip(SongClip(cue: $0)) } }
}
```

The setter builds a **brand-new** `SongClip`: `generatedAsset` reset to `.none`, `readinessInputs`/`portabilityInputs` back to defaults, `retryMetadata` cleared, `sourceLineageClipID` dropped. That is correct for a fresh assignment, but it is also the path used by `refreshAppleMusicCueMetadata` (`AppModel.swift:2013`), which is a *metadata refresh*, not a re-assignment:

```swift
state.teams[teamIndex].players[playerIndex].cue = currentCue
```

A player with a generated portable clip who happens to hit the metadata refresh loses it and has to regenerate. The refresh is narrowly gated (`source.duration == nil`), so the blast radius today is small — but the setter is a trapdoor that any future caller will fall through.

**Recommendation.** Have `refreshAppleMusicCueMetadata` mutate `songAssignment` in place (update `originalSource` only) rather than round-tripping through `cue`. Consider renaming the setter or making it `private(set)` with an explicit `assignNewSong(_:)` so the destructive semantics are visible at call sites.

### M2. A missing Announcement Cue is counted as a *song audio* repair in the Readiness overview

`ReadinessOverviewCard.playerChecks` (`RootView.swift:3346`) selects checks by **id prefix**, not by category:

```swift
check.id.hasPrefix("player-")
    && !check.id.contains("announcement-upgrade")
    && !check.id.contains("photo-upgrade")
```

`ReadinessService.playerReadinessCheck` (`Services.swift:2054`) emits `player-<uuid>-custom-announcer-issue` when a recorded Announcement Cue file has gone missing. That id starts with `player-` and matches neither exclusion, so it lands in `playerChecks` and increments `issueCount`. Two consequences:

- The overview flips to **"Some Audio Needs Repair"** with a destructive chip because of a missing *announcement*, even when every present player's song is fine and the team is in `songOnly` mode. `hasLiveGameDayWarning` gets this right (it gates `.playerAnnouncement` on `gameDayAnnouncerMode.usesAnnouncer`); the Readiness overview does not.
- The same check is *also* rendered by `ReadinessEnhancementsCard`, which filters on `category == .playerAnnouncement`, so it is double-counted across two cards while being absent from `ReadinessPlayerAudioCard` (which filters `category == .playerAudio`).

Note the deeper cause: `playerReadinessCheck` returns the announcement-issue check *instead of* the audio-ready check, so a player with perfect song audio and a missing intro file produces **no** playerAudio check at all — they are neither "ready" nor accounted for in the audio tally.

**Recommendation.** Filter `playerChecks` on `category == .playerAudio` (the `category` field exists precisely for this; the id-prefix filter predates it), and have `playerReadinessCheck` emit the announcement issue as a *second* check rather than a substitute for the audio verdict.

### M3. Low-volume warning is suppressed exactly when Volume Automation is on

`RootView.swift:1972` (`hasLiveGameDayWarning`) and `RootView.swift:5855` (`isLiveReadinessIssue`), both:

```swift
if check.category == .volume {
    return !appModel.state.settings.fadeOutVolumeAutomationEnabled
}
```

Volume Automation captures the *current system volume* as its baseline (`captureSystemVolumeBaseline`, `Services.swift:1135`) and fades relative to it. A system volume below 30% still produces a quiet cue with automation on. Suppressing the warning in that configuration hides a real live-use problem.

**Recommendation.** Show the volume warning regardless of the automation setting, or reword it rather than dropping it.

### M4. `playerMissingSummaryText` drops a missing-media type when all four are missing

`RollCall/AppModel.swift:3382`. `missingMediaTypes` can return four values (`.photo`, `.photoSource`, `.announcementCue`, `.song`) but the formatter only handles counts 1–3 and falls through to the three-item form, so a fully-degraded player is described as missing three of four things. The same shape exists in `MissingMediaSummary.warningText` (which caps at three segments but only ever builds four).

**Recommendation.** Use a generic list formatter (`ListFormatter` or a small join helper) rather than hand-rolled 1/2/3 cases.

### M5. `RecoveryCenterView` recomputes restore eligibility inside every row body

`RootView.swift:7063` — `let restorePreparation = appModel.restorePreparation(for: item)` sits at the top of `recentlyDeletedRow(for:)`. For a deleted team that walks every player's photo, photo-source, announcement, and local-audio path plus every team clip, doing a `FileManager.fileExists` for each, on every list render.

**Recommendation.** Compute the preparations once per `body` into a dictionary keyed by item id, or cache with `refreshRecoveryState()`.

### M6. Three legacy `.alert(item:)` modifiers stacked on one view in Recovery

`RootView.swift:7028`, `:7038`, `:7048` — backup restore, permanent delete, and partial restore all use the `Alert`-returning `alert(item:content:)` API, deprecated since iOS 15, on the same `List`. Stacking that API has historically been unreliable (last one wins). This is the destructive-recovery path, so it deserves an explicit device check.

**Recommendation.** Migrate to the modern `alert(_:isPresented:presenting:actions:message:)` form used elsewhere in the file, and verify all three paths on device.

### M7. `SongPickerFlow`'s files-mode Cancel button is attached to the wrong view

`RollCall/SongPickerFlow.swift:50` — the `.toolbar { ... Cancel ... }` is applied to the `NavigationStack` itself, outside its content closure. A toolbar attached to the container rather than to a view inside it will not appear in the navigation bar. In `.files` mode the user has no way to back out of "Preparing audio…" if the import stalls.

**Recommendation.** Move the toolbar inside `sourceView` (or attach it to the content the stack renders).

### M8. Window-level swipe recognizer is fragile as new sheets are added

`RootView.swift:377` — `LiveSurfaceSwipeGestureInstaller.Coordinator.install(on:)` adds a `UIPanGestureRecognizer` with `cancelsTouchesInView = true` directly to the **`UIWindow`**. It is therefore live over presented sheets and full-screen covers too.

It is currently safe only because `isLiveSurfaceSwipeAvailable` enumerates a fixed list of RootView presentation flags (`hasBlockingWhatsNewPresentation` + `showTeamClips` + `customClipRepairPrompt`). Any *new* sheet presentable from Game Day or Clips that is not added to that list will let a horizontal drag inside the sheet switch tabs behind it. The recognizer is also never removed when the installer view goes away.

**Recommendation.** Attach the recognizer to the tab content's own view rather than the window, or derive the enabled state from a single source of truth (e.g. count of active presentations) instead of a hand-maintained list.

### M9. `CustomAnnouncerRecorder.cancelRecording` is a no-op during the save phase

`RollCall/AppModel.swift:462`

```swift
func cancelRecording() {
    guard !stopState.hasPendingStop() else { return }
    ...
    finishPendingStopAsCancelled()   // unreachable: guard above proved no pending stop
}
```

Cancelling while the recording is being saved does nothing at all — not even a UI reset — and `finishPendingStopAsCancelled()` is dead code because the guard has already established there is no pending stop. `AppModel.cancelRecordingCustomAnnouncer` then sets `customAnnouncerRecordingPhase = .idle` anyway, so the UI and the recorder can disagree.

**Recommendation.** Either make cancel wait for / resolve the pending stop, or drop the unreachable branch and make the UI disable Cancel during `.stopping`.

### M10. Smaller correctness and hygiene items

| Item | Location | Note |
| --- | --- | --- |
| Player Card re-implements contrast picking, worse than the design system | `PlayerCards.swift:163` | `readableForeground(over:)` thresholds raw (non-linearised) sRGB luminance at 0.58; `UIColor.rollCallReadableForeground` in `RollCallColors.swift:102` does a proper WCAG linearised contrast comparison. The uniform-number badge on a gold or yellow accent can pick a different foreground than the rest of the app |
| On Deck card's song icon ignores playability | `RootView.swift:6348` | `onDeckCueIcons` uses `resolvedCue(for:) != nil`, while the hero and grid use `willUseFallback`. A player whose audio file is missing shows a green music note On Deck and a slashed note in the grid, in the same frame |
| `importRemotePreview` copies instead of moves the download temp file | `Services.swift:481` | leaves a temp file behind on every preview import |
| `appModel.exportURL` is never cleared after sharing | `AppModel.swift:505` | stale temp URL persists in the model; a second share can point at a purged file |
| `Team.init(from:)` decodes `announcerProfile` twice | `Models.swift:637`, `:646` | harmless, but doubles decode work per team |
| `Team.orderedPlayers(by:)` is O(n²) | `Models.swift:1438` | `ids.contains` inside a `filter`; called on every Game Day render (see C3) |
| `recordPreparationFailure` retry task checks `Task.isCancelled` on a task nothing cancels | `AppModel.swift:3970` | keeps a 120 s sleeping task alive; the intent (cancel on teardown) is not implemented |
| Telemetry store writes are synchronous main-thread atomic file writes | `Telemetry.swift:720` | `store.save` runs on every recorded event, including `handlePlayerPlayback` during live cues |
| `PlayerCardPreviewSheet.renderIdentity` omits team name/accent and song metadata | `PlayerCards.swift:311` | card won't re-render if those change while the sheet is open |
| `editableCue!` force unwrap in the `AdvancedTrimSheet` binding | `RootView.swift:8455` | latent crash if that sheet is ever re-enabled (see M11) |
| Rating sheet dismissal by swipe or "Done" records nothing | `RootView.swift:7811` | only the explicit "Not Now" button emits `ratingNotNowSelected` |
| `PackageImportAudit.summary` ignores `.photoSourceMissing` items | `SongClipModels.swift:413` | the Import Check sheet's "Clip Portability" counts exclude attachment issues it lists below |

### M11. Dead code shipped in the 1.3 binary

None of this is a runtime bug, but for a release-candidate audit it is a meaningful amount of untested, unreachable surface. Grouped by size:

**Music Render Probe — unreachable from the UI (~1,050 lines + AppModel surface).** `MusicRenderProbeView.swift` (367) has no references anywhere; `DeveloperToolsView` no longer links to it. `MusicRenderProbeService.swift` (335) and `MusicRenderProbeModels.swift` (342) remain live-linked only through `AppModel`, which still carries `musicRenderProbeSamples`, `musicRenderProbeLibraryCandidates`, `musicRenderProbeCatalogCandidates`, `isMusicRenderProbeLoadingLibrary`, `isMusicRenderProbeSearchingCatalog`, `musicRenderProbeSummaryURL`, and ~10 methods. `MusicRenderProbeTests` still passes, so coverage will not flag this.

**Player Editor trim UI — unreachable (~200 lines).** `cueTrimSection(for:)` (`RootView.swift:8940`) is never called. Everything it drives is therefore dead: `showAdvancedTrim`, `trimMode`, `isStartTrimEditingEnabled`, `liveScrubTask`, `lengthOptions`, `AdvancedTrimSheet`, `StartScrubControl`, `FlowChipRow`, `applyTrimSuggestion`, `updateCueStart`, `updateCueDuration`, `scheduleLiveScrubPreview`, `normalizeTrimModeForCurrentCue`. **If this removal was intentional** (trim consolidated into `SongClipEditorView` / "Make Your Clip"), delete the remnants. **If it was not**, the Player Editor quietly lost inline start/length editing in 1.3 — worth confirming against intent.

**Built-in announcer voice — removed feature, code retained.** `AnnouncerSpeechRenderer` (`AppModel.swift:4718`+, ~130 lines), `triggerAnnouncerRegeneration`, `regenerateBuiltInAnnouncers`, `generateBuiltInAnnouncerAsset`, `renderBuiltInAnnouncer`, `applyGeneratedBuiltInAnnouncerAsset`, `announcerVoiceOptions`, `announcerPreviewText`, `announcerPreviewPlayer`, `isNoveltyVoice`, `qualityRank`, `AnnouncerRenderCompletionState`, `announcerRegenerationStatus`, `GeneratedAnnouncerAsset`. `previewBuiltInAnnouncer` and `saveSelectedTeamAnnouncerProfile` are stubs whose only behaviour is to set `lastError` to a "removed from Roll Call" string — if anything ever calls them the user sees an error alert.

**Other unreferenced views/helpers.** `BasicPhotoCropperSheet` (`RootView.swift:9166`, ~150 lines), `AppleMusicPickerSheet` (`:9418`, ~170 lines), `refreshPlayerFromModel()` and `refreshPlayerFromModel(enableStartTrimForCueReplacing:)`, `playersTabTitle`, `GameDayNowBattingHero.cueIconRow`, `GameDayOnDeckCard.onDeckCueIconRow`, `GameDayTeamStack.willUseFallback(for:)` (shadowed and unused), `AudioAssetService.ensureDirectoryExists`, `MusicCatalogService.syncTeamPlaylist`.

**Persisted-but-never-read state.** `ExperimentalSettings.appleMusicTeamPlaylistSyncEnabled`, `.acknowledgedAt`, `.appleMusicTeamPlaylistAcknowledgedAt` are encoded/decoded but never consulted — note that the Apple Music playlist feature now ships **ungated** on the Teams tab (`RootView.swift:1859`), which may or may not be intended given it was previously an experiment.

**Compatibility no-ops still on hot paths.** `beginGameDayVisitForRatingIfNeeded` and `finalizeGameDayVisitForRatingIfNeeded` are empty but still called from four places in `RootView` tab/scene-phase handling; `markAutomaticRatingPromptAttempted`, `markGameDayPlayerCuePlayedForRating`, and `normalizeRatingRequestPolicyState` are empty and uncalled.

