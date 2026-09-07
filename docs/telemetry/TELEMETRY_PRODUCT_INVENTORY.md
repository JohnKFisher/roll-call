# Roll Call Product Inventory

**Audit date:** 2026-09-06  
**Repository:** `/Users/jkfisher/Documents/Coding/Projects/Roll Call`  
**Scope:** Dated read-only inventory of the 1.2/telemetry-landing baseline inspected on the audit date.  
**Purpose:** Preserve the implementation-grounded product inventory and its privacy boundaries alongside the approved telemetry implementation.

This document preserves what the repository did at the 2026-09-06 inspection point; it is not a live 1.3 product inventory. The approved current telemetry contract and implementation are defined in [ROLL_CALL_TELEMETRY_SPEC.md](./ROLL_CALL_TELEMETRY_SPEC.md) and `RollCall/Telemetry.swift`, while current product behavior is summarized in [Application Overview](../product/APP_OVERVIEW.md). Source and tests from the audited baseline were treated as separate evidence when they disagreed; those disagreements are called out in [Possible Assumption Mismatches](#possible-assumption-mismatches).

## Audit basis and persistence map

The primary implementation sources inspected were:

- `RollCall/AppModel.swift` — application state transitions, onboarding, teams, players, clips, playback orchestration, rating state, package/recovery flows, and persistence coordination.
- `RollCall/RootView.swift` — tabs, onboarding screens, Game Day, Clips, Players, Teams, Readiness, Settings, support, rating, and recovery UI.
- `RollCall/Models.swift` — `AppState`, `Team`, `Player`, `Cue`, settings, onboarding, rating, readiness, recovery, and package models.
- `RollCall/SongClipModels.swift` — source-backed/generated clip state, readiness, portability, retry state, and preparation triggers.
- `RollCall/Services.swift` — audio assets, MusicKit/iTunes lookup, playback, readiness, package/CSV handling, support StoreKit, and support-bundle diagnostics.
- `RollCall/Telemetry.swift` — the typed TelemetryDeck boundary, privacy allowlist, preference gate, separate state store, live-session reducer, probable-game policy, and rating reservation.
- `RollCall/SongPickerFlow.swift` — Music Library, Apple Music, file import, explicit-content filtering, and trim/editor flows.
- `RollCall/RollCallApp.swift`, `Info.plist`, and `PrivacyInfo.xcprivacy` — app startup, document type, permissions, and privacy manifest.
- The relevant tests under `RollCallTests/`, especially `RatingRequestTests.swift`, `ReadinessServiceTests.swift`, `TeamLineupTests.swift`, `RosterCSVImportTests.swift`, `PackageServiceTests.swift`, `BackupRestoreTests.swift`, `RecentlyDeletedTests.swift`, `AppStatePersistenceTests.swift`, and generated-clip tests.
- `RollCallTests/TelemetryTests.swift` — deterministic telemetry, migration, rating, live-session, and ordering coverage.
- Current product/decision documentation under `docs/product/`, `docs/DECISIONS.md`, and `docs/WHERE_WE_STAND.md`.

The working tree already contained unrelated modifications and deletions before this audit. Those changes remain owner work. The telemetry implementation was added afterward under the approved specification; this inventory does not replace that specification.

### Durable app state

`AppState` is schema-versioned (`currentSchemaVersion = 9`) and is written as pretty-printed JSON with ISO-8601 dates to:

`Application Support/RollCall/state.json`

The storage roots are defined by `AppPaths` in `RollCall/Models.swift`:

- `Assets/` — imported audio, recorded announcements, and player photos.
- `GeneratedClips/` — generated local song clips.
- `Snapshots/` — backup state and manifests.
- `state.json` — the active `AppState`.

Writes are coordinated by `StatePersistenceWriter` in `AppModel.swift`; state is encoded to a temporary file and replaced atomically. Corrupt or unsupported state is copied to a `state-unreadable-<UUID>.json` file before a fresh state is used and an error is surfaced.

`AppState` contains:

- app/schema version and a device label (`DeviceIdentity`, default `This iPhone`);
- selected team ID and all teams;
- Recently Deleted entries and backup snapshot records;
- experimental flags;
- global `AppSettings`;
- last computed `ReadinessStatus`;
- last-seen What's New release ID;
- recent Apple Music selections;
- trim defaults;
- onboarding state;
- legacy rating-request state, retained only for backward decoding and one-time migration; active rating policy state is in the separate telemetry/rating store.

Support purchase state is intentionally outside `AppState`: `SupportLocalCache` is JSON in `UserDefaults.standard` under `rollCall.support.localCache.v1`. Playback progress, active cue, prewarming, busy-operation state, live-tab throttling, and some UI presentations are in memory only.

## 1. Onboarding

### Entry and onboarding completion

The root route shows onboarding when any of these is true (`AppModel.shouldShowOnboarding`):

- there are no teams;
- `OnboardingState.activeFlow` is non-nil;
- `OnboardingState.isComplete` is false (`completedAt == nil`).

First launch starts with a full-screen welcome screen. The welcome screen says “Welcome to Roll Call” and describes generating walk-up music cues for youth sports. “Let’s Get Started” moves into the Setup Guide.

Onboarding is considered complete when `AppModel.completeOnboarding()` sets `OnboardingState` to `.completed()` with a timestamp. In the normal first-run path this happens from the final handoff when the user chooses either:

- **Open Game Day**; or
- **Review Readiness** after importing a team.

There is no readiness threshold, minimum number of players, required song, required announcement, or successful playback requirement for completion. An existing-team setup guide can also be closed and marked complete by `dismissManualSetupGuide()`.

### Flows and branches

`OnboardingFlow` has these values:

- `automatic` — first-run setup when the app has no teams.
- `manualChooser` — the setup guide’s choice screen after reopening it with existing teams.
- `manualCreate` — guided creation of an additional team.
- `manualReview` — guided review of the currently selected team.
- `importHandoff` — post-import onboarding handoff.

The manual chooser offers:

1. **Create New Team**.
2. **Add Team from .rollcall File**.
3. **Review Current Team**, when a selected team exists.

Back navigation is available through most steps. It is not available from the manual chooser or import handoff. A close action is available only when a team exists; closing with incomplete work presents a confirmation. Existing teams are not changed merely by opening the guide.

### Step-by-step inventory

#### Welcome

**User experience:** Full-screen welcome image and a single start action.

**State:** No product data is created by the welcome page. The app’s normal `AppState` load and launch initialization have already occurred.

**Source:** `RootView.swift`, `OnboardingWelcomeView`; `AppModel.init()` and `finishLaunchingIfNeeded()`.

#### Team

**User experience:** Enter a team name and choose a team accent color. The eight current accent choices are Roll Call Orange, Red, Gold, Green, Blue, Purple, Gray, and Black. Tapping **Create Team** creates the team.

**Data created:** `addTeam(named:accentPreset:forOnboarding:)` creates a `Team` with:

- a new UUID, name, created/modified timestamps;
- no players or custom team clips;
- the five default built-in clips;
- an empty batting order and next-batter index `0`;
- `Announcer+Song` mode;
- the selected accent preset;
- the default team announcer profile in the persisted model.

The new team becomes selected. The onboarding flow and active team ID are set when the call is onboarding-related.

**Alternate path:** The create page offers import from another user’s `.rollcall` package instead of creating a new team.

#### Manual team review

**User experience:** Existing selected team name and accent can be reviewed/edited, then the user continues to the next unresolved setup step.

**Data:** Name and accent are persisted through the same team edit methods as the Teams screen. The review flow pre-populates its fallback milestone from whether any existing player already has a cue.

#### Player

**User experience:** Enter a player name and optional uniform number, then tap **Add Player**. On the first player, the flow continues into the audio step. When adding later players, the message tells the user the player was added and moves into that player’s audio step.

**Data created:** `addPlayer(named:number:)` creates a player with a UUID, trimmed display name/number, `isPresent = true`, no photo, no song assignment, no custom announcement, and appends the ID to the batting order. Team state is normalized and persisted.

**Branches:** The first player has a dedicated first-player form. Additional players use an add-more path from the lineup step. The name must be non-empty; number is optional.

#### Audio

**User experience:** For the onboarding player, the user can:

- choose from the iPhone Music Library;
- search Apple Music;
- import Audio or Video;
- choose **Try with a Crowd Cheering**;
- continue if a cue is already present.

If a cue exists, the page shows source and trim information and allows the user to continue. Song selection opens the same `SongPickerFlow` and `SongClipEditorView` used by the Player Editor.

**Data:** Saving a song writes a player-scoped `SongClip`/cue assignment, including source metadata and requested start/duration/fade. Imported media is copied into app storage or converted to an audio file before assignment. Apple Music selections are also added to recent-selection history.

**Fallback branch:** `markOnboardingCheerFallbackChosen()` only sets `OnboardingState.didChooseCheerFallback = true`. It does not assign a `Small Cheer` cue to the player. During Game Day, a player without a cue can still use the built-in fallback. This distinction is recorded again under [Possible Assumption Mismatches](#possible-assumption-mismatches).

#### Lineup

**User experience:** The guide recommends three players but explicitly allows continuing with one. The user can:

- open the lineup anyway;
- open today’s lineup;
- add more players;
- mark players present or out;
- drag the batting order;
- close the lineup editor;
- tap **Got It** after seeing the lineup.

**Data:** The lineup editor updates per-team `session.battingOrder`, `session.nextBatterIndex`, `session.battingOrderIsCustomized`, and each player’s `isPresent`. `didSeeLineup` is set when the editor has been seen.

**Completion:** The final handoff tells the user that more players, photos, announcements, and tuning can be added later. It offers **Open Game Day**. The guide does not require all players to have songs or announcements.

#### Import handoff

**User experience:** After an imported package is accepted, the guide explains that the team was imported and offers **Review Readiness** or **Open Game Day**.

**Data:** The package is imported as a new team with a new team ID and an “Imported” name suffix when necessary. The onboarding state tracks `importHandoffTeamID` and uses the import-handoff flow.

### Onboarding persistence and restart behavior

`OnboardingState` persists:

- `completedAt`;
- `activeFlow`;
- `activeTeamID`;
- `didChooseCheerFallback`;
- `didSeeLineup`;
- `importHandoffTeamID`.

If old state has no onboarding key, decoding treats an empty app as not started and a populated app as completed. On launch, `reconcileOnboardingForExistingTeamIfNeeded()` completes an old/incomplete automatic flow when a team already exists. The persisted flags are milestone state, not a separate event history.

**Relevant sources:** `Models.swift` (`OnboardingFlow`, `OnboardingState`, `AppState`), `AppModel.swift` (`shouldShowOnboarding`, `beginSetupGuide`, `startOnboardingCreateNewTeam`, `startOnboardingReviewCurrentTeam`, `completeOnboarding`, milestone methods), and `RootView.swift` (`OnboardingRootView` and step views).

## 2. Teams and rosters

### Team creation, selection, editing, duplication, and deletion

Teams are managed on the Teams tab and during onboarding.

**Create:** A non-empty trimmed name is required. New teams receive a UUID, timestamps, default built-ins, default session state, default announcer profile, and Roll Call Orange unless another accent is selected.

**Select:** Selecting a team changes `AppState.selectedTeamID`, persists it, prewarms the next batter, and refreshes readiness.

**Rename:** The selected team can be renamed with a non-empty trimmed name.

**Accent:** The selected team can use one of eight `TeamAccentPreset` values. The accent changes identity/background treatment but does not replace semantic warning, destructive, readiness, disabled, or playback colors.

**Duplicate:** `duplicateSelectedTeam()` creates a new team with a new team ID, copied player records with new player IDs, copied player/team clips with new clip IDs and source-lineage IDs, copied presence and batting order, and a reset `activeSessionDate`. The duplicate is named using a “Copy” suffix and becomes selected.

**Delete:** Removing a team creates a Recently Deleted team record, removes it from active state, cancels related preparation, normalizes selection, stops playback, and persists. It does not immediately destroy the recoverable payload.

### Player creation, editing, presence, and deletion

**Create:** `addPlayer(named:number:)` requires a non-empty name. Number is optional. New players are present by default and are appended to the batting order.

**Edit:** The Player Editor can change:

- display name;
- uniform number;
- pronunciation override;
- photo;
- song cue/source and trim;
- custom recorded Announcement Cue.

The editor uses explicit Save/Close behavior. Draft identity/photo changes can be discarded on close. Song and announcement changes are coordinated with the app model and trigger preparation/readiness updates.

**Photo:** Photos are selected through `PhotosPicker`, optionally adjusted in a basic cropper, then copied into `Assets/`. Missing photos remain presentation issues rather than live-use blockers.

**Presence:** Players can be marked In/Out from the Players list, the lineup editor, and relevant setup flows. `isPresent` controls the active Game Day lineup; it does not delete the player or their media.

**Delete:** Removing a player creates a Recently Deleted player record containing the original team/player/order information, cancels preparation, removes the player from the team lineup, normalizes state, and persists. The player can be restored while the team still exists.

### Roster-management features

- Players list sorted by normalized first name, remainder, and full name for display.
- Present/total counts and help text on the Players tab.
- Swipe action to mark a player In/Out.
- Lineup editor with presence toggles and drag ordering.
- **Sort A-Z** and **Sort by Number** actions.
- Manual batting order is persisted across launches.
- Adding/removing/reordering players keeps the player array and batting order normalized.
- Player-specific songs and announcements remain attached to the player when presence changes.

### Practical Game Day usability

The app can open Game Day with an empty or incomplete team. The practical minimum for a useful live flow is a selected team with at least one present player. A player without a playable song can still produce the built-in Small Cheer fallback. The UI can warn about missing song/audio, Apple Music access, network, route, volume, or lineup conditions, but readiness does not block Game Day.

When there is no team or the selected team has no players, the initial tab is Players. When a selected team has players, the initial tab is Game Day. With no present players, Game Day shows an empty hero directing the user to open the lineup and mark players present.

### Readiness/completeness already present

Readiness is a persisted `ReadinessStatus` for a team, not a percentage or completion score. `ReadinessState` values are:

- `ready`;
- `enhanced`;
- `needsAudio`;
- `optional`;
- `gameDayCheck`;
- `issue`.

Checks have categories for player audio, player announcement, player photo, audio route, volume, network, Apple Music access, and lineup. A player with playable song audio can be Ready; a recorded announcement is an enhancement; photos are optional; missing song audio is a helpful need rather than a reason to block Game Day. `lastReadiness` is persisted in `AppState` and recomputed on launch, foreground, authorization/path/audio-route/volume changes, and explicit refresh.

**Relevant sources:** `Models.swift` (`Team`, `Player`, `TeamSessionState`, readiness types), `AppModel.swift` (team/player methods and normalization), `RootView.swift` (Teams, Players, Readiness, and Lineup UI), and `Services.swift` (`ReadinessService`).

## 3. Game Day / live-use workflow

### Entering Game Day

Game Day is a root tab. It can be reached by:

- the initial-tab decision for a populated selected team;
- the main tab bar;
- onboarding’s final handoff;
- the import handoff;
- a leftward horizontal swipe from Clips.

The reverse live-surface gesture is a rightward swipe from Clips to Game Day. The gesture requires a mostly horizontal movement of at least approximately 80 points and is disabled while modal, blocking, import, prompt, or editor routes are active. Successful swipes give a light haptic and a small horizontal nudge. This is a live-surface shortcut, not a separate session or navigation stack.

Entering Game Day:

- begins a rating visit if the persisted per-visit flags need resetting;
- refreshes Game Day warmup/prewarming;
- enables live-use song-preparation throttling.

Leaving Game Day:

- finalizes the rating visit if appropriate;
- changes preparation throttling based on the destination;
- does not create a formal saved game-session record;
- does not inherently stop shared playback merely because the tab changes.

The screen is live-oriented, can force an effective dark appearance according to the global setting, and can disable auto-lock while Game Day or Clips is active if Keep Screen Awake is enabled.

### Team and lineup presentation

Game Day presents:

- selected team banner and accent identity;
- a live warning strip for relevant readiness issues;
- a Now Batting hero;
- an On Deck card;
- an announcer-mode picker;
- Prev / Edit Lineup / Next controls;
- a grid of all present players in the computed Game Day order.

`TeamSessionState` stores the batting order and `nextBatterIndex`. The visible `battingOrderPlayers` is normalized to the current players. `nextBatter` is the present player at the clamped next index. The player grid rotates after On Deck so the live board visually continues the lineup while keeping every present player visible.

If a user taps a later grid player, the hero can show that player as a temporary playback/visual override. The real next-batter pointer, On Deck state, and underlying order remain unchanged until the user uses lineup progression controls or edits the lineup.

### Meaningful user actions

#### Player cue actions

- Tap Now Batting hero to play the current player.
- Tap the active hero again to stop.
- Tap any present-player grid tile to play that player.
- Tap an active tile/hero again to stop the same cue.
- Observe status as Ready, Playing, or Fallback available.
- See cue icons for song and recorded announcer availability.

#### Lineup progression

- **Prev** moves the next-batter index backward circularly through present players.
- **Next** advances the next-batter index circularly.
- **On Deck** card advances the On Deck player to Now Batting.
- **Edit Lineup** opens the lineup sheet.
- Optional progress-hint animation appears only when the default-off hint setting is enabled and the user advances via Next or On Deck; it is suppressed for Reduce Motion.

Advancing uses haptics when enabled, updates the transient `gameDayLineupProgressHintEvent`, prewarms the next cue, and persists the session state.

#### Announcer mode

The per-team live picker has three modes:

- **Announcer Only** — use the player’s recorded Announcement Cue; without one, use Small Cheer fallback.
- **Announcer+Song** — play the recorded announcement when present, then a playable song; without the announcement, play the song; without usable song audio, use fallback.
- **Song Only** — omit announcements and play the song; without usable song audio, use fallback.

The selected mode is stored in `team.session.gameDayAnnouncerMode`, not in a global app setting.

#### Lineup editor actions

The lineup sheet lets the user:

- toggle each player present/out;
- drag batting order;
- sort A-Z;
- sort by uniform number;
- close the sheet.

Edits persist immediately through the app model and affect the live board’s present set and next/on-deck calculations.

### Playback behavior in Game Day

`AppModel.play(player:teamID:)` resolves a playback plan, starts the shared `CuePlaybackEngine`, and marks a qualifying rating cue after successful primary playback or successful fallback playback. A successful live tap can therefore count toward rating eligibility even when the ideal media was unavailable but fallback audio played.

Playback plan behavior is:

1. recorded custom announcement when the selected mode uses it and the asset exists;
2. optional pause after the announcement;
3. primary song/built-in cue when the mode includes a song;
4. built-in Small Cheer fallback when no usable cue exists or the Apple Music attempt fails.

The engine tracks a playback session ID, active cue ID, progress, last started cue, and prewarmed cue in memory. Re-tapping the same active cue stops it. A debounce window prevents rapid duplicate starts. Apple Music playback is capped at 20 seconds; local and built-in playback follows the cue duration.

If playback fails for an Apple Music cue, `AppModel` records the active fallback player ID and tries Small Cheer. If fallback also fails, an error and warning haptic are surfaced. The player remains usable as a source-backed record even when the current device cannot play it.

### State/session behavior when moving elsewhere

There are three different concepts that should not be conflated:

- **Team session state:** durable per-team lineup order, next-batter index, mode, and an `activeSessionDate` field.
- **Playback session:** in-memory engine-level sequence/session identifiers for the current cue sequence.
- **Game Day visit for rating:** persisted flags representing whether the current root-tab visit played a qualifying cue and has been counted.

Game Day and Clips use the same selected team and the same `CuePlaybackEngine`. Moving between them preserves the shared live context rather than starting a separate Clips session. No formal game-session entity, game date workflow, innings, score, or game history was found. `activeSessionDate` is persisted in `TeamSessionState`, but no current user-facing behavior was found that sets or consumes it as a game-session boundary.

**Relevant sources:** `RootView.swift` (`RootTab`, `GameDayBoard`, `GameDayTeamStack`, `GameDayNowBattingHero`, `GameDayOnDeckCard`, `GameDayControlRow`, `GameDayPlayerGrid`, `LineupEditorSheet`), `AppModel.swift` (playback, lineup, rating-visit, and mode methods), `Models.swift` (`TeamSessionState`), and `Services.swift` (`CuePlaybackEngine`).

## 4. Clips / Clip Pad

### Naming and entry

The current product label is **Clips**. No distinct user-facing “Clip Pad” label or separate Clip Pad model was found. Internally the root tab is `generalClips` and the underlying per-team collection is `teamClips`.

Clips is a live dark surface adjacent to Game Day. It is reachable from the tab bar or by the Game Day-to-Clips horizontal swipe.

### Available content

The Clips screen contains:

- a **Sound Effects** grid of the five built-in clips:
  - Small Cheer;
  - Victory Roar;
  - Stadium Burst;
  - Rhythmic Clap;
  - Whistle Pop.
- a grid of user-created Custom Clips for the selected team.

Built-in assets are bundled MP3 files and are restored/ensured at launch. Custom Clips are independent team-scoped `SongClip` copies, not references that automatically change when a player song changes.

### User actions

- Tap a built-in clip to play it through the shared playback engine.
- Tap a playable custom clip to play it.
- Tap the active clip again/stop through the shared playback affordance.
- Tap **Edit** to open the custom clip manager.
- In the manager, add a clip through Music Library, Apple Music, or imported audio/video; edit name and trim; copy existing clips; move clips; delete clips; and restore/delete through Recovery for supported deleted clips.
- If a custom clip cannot play, the UI presents an unavailable/repair path rather than silently doing nothing.

Custom Clips use `pauseAfterAnnouncer = 0` and have no player assignment. A player song copied into Custom Clips is an independent copy with source-lineage metadata.

### Relationship to Game Day

Clips and Game Day share:

- the selected team;
- all team/player source and generated clip state;
- the same playback engine and audio session;
- the same live dark-surface treatment;
- live-use preparation throttling;
- screen-awake behavior.

They do not share a formal persisted game-session object. The Clip screen is a live soundboard surface, not a second game record. Leaving Clips closes its clip-manager presentation if one is open; it does not imply that team data or playback history has been discarded.

**Relevant sources:** `RootView.swift` (`clipsSurface`, Clips tab content, custom clip manager presentation), `AppModel.swift` (team-clip CRUD/copy/move/delete/play methods), `Models.swift` (`Team.teamClips`, built-in defaults), and `Services.swift` (`CuePlaybackEngine`).

## 5. Media

### Supported sources and stored types

`CueSource` / `SongSource` support three source families:

1. **Apple Music** — song ID, title, artist, optional duration/preview URL, catalog-backed status, optional Music Library persistent ID, and explicit flag.
2. **Local Audio** — an app-owned asset ID, display name, relative path, optional duration, import date, and hidden origin note.
3. **Built-in Clip** — a stable built-in source ID and display name.

Player song assignments are modeled as `SongClip`. A SongClip keeps the original source and requested selection separately from any generated local asset, readiness state, portability state, retry metadata, policy, and source-lineage ID.

### Apple Music behavior

Apple Music and Music Library access is requested after the user expresses intent to choose/search music. The Music permission primer says that Roll Call uses Music access for songs on the iPhone and can search Apple Music for songs not already in the library.

`MusicCatalogService` uses:

- MusicKit catalog/library APIs when authorized;
- an iTunes Search API preview fallback when catalog search cannot complete;
- MusicKit/MediaPlayer playback for full tracks where the current Apple Music authorization/subscription permits it;
- preview URL playback when only a preview is available.

Apple Music playback capability is represented as unknown, preview-only, or full-song. An Apple Music selection may remain source-backed even if the current device cannot provide a full local file. A library persistent ID is preferred when available, then a catalog-backed song ID, then preview playback.

Apple Music-linked clips are not considered portable local audio. The current clip policy has local generation enabled but uses `readableLocalOnly`, with auto-download disabled. The code does not request or control Apple Music downloads.

### Local audio and video behavior

The file importer accepts audio or video. `AudioAssetService.importMedia`:

- uses a security-scoped URL;
- if the asset contains a video track, extracts its audio to M4A using `AVAssetExportSession`;
- otherwise copies the file into app-owned Assets while preserving its extension;
- calculates duration where possible;
- records a hidden origin note for imported previews/assets.

Imported local audio is app-owned and can travel with a team package when the file is available. Local source files and generated clips are addressed by validated relative paths; absolute paths and traversal components are rejected.

### Recorded Announcement Cue

Each player may have a custom recorded Announcement Cue. The Player Editor offers record/re-record, preview, and clear. Recording:

- asks for microphone permission only when recording is started;
- configures an AVAudioSession for play-and-record/default-to-speaker;
- records mono 44.1 kHz linear PCM into a `.caf` asset;
- replaces the prior recording with a new app-owned asset path;
- persists the player’s custom-announcer relative path on save.

Missing recorded-announcement files are identified as repair issues. A present custom recording is treated as an enhancement in readiness and is included in Announcer+Song or Announcer Only according to the team mode.

### Built-in and fallback media

The bundled built-in sounds are the five default clips listed in the Clips section. Small Cheer is the default fallback source ID when a player has no song or a selected Apple Music cue fails during playback. The fallback is intended to preserve live-use intent; it does not convert the player’s missing source into a saved song assignment.

The model still contains `TeamAnnouncerProfile`, `AnnouncerTemplate`, `AnnouncerSpeechRenderer`, generated-announcer paths, and legacy migration code. However, the current `saveSelectedTeamAnnouncerProfile` and `previewBuiltInAnnouncer` paths report that Built-in Voice has been removed and direct users to recorded Announcement Cues. This residual model/renderer surface is an implementation ambiguity, detailed below.

### Playback combinations and timing

Per-team Game Day mode selects:

- announcement only;
- announcement plus song;
- song only.

For a sequence with a custom announcement, the engine plays the announcement asset, waits the clip’s `pauseAfterAnnouncer`, and starts the primary cue. If the announcement file is absent or unreadable, it skips directly to the primary cue. Song clips use a requested start time, duration, and fade-out duration; generated local assets play from time zero because the selected window is already rendered.

Apple Music clips are limited to approximately 20 seconds of playback. When volume automation is enabled, Apple Music volume is raised/managed for the cue, faded near the end, and restored to the captured system baseline afterward. Local and built-in clips do not use that Apple Music volume automation path.

### Assignment, replacement, removal, and copying

Player media actions include:

- choose from Music Library;
- search Apple Music;
- import Audio or Video;
- use an existing player/team clip;
- change/retrim the selected cue;
- clear the song cue;
- record/re-record/clear the custom Announcement Cue;
- copy a player song to a Custom Clip;
- use an existing clip as a new player-scoped independent copy.

Saving a new cue replaces the player’s prior assignment. The app preserves source metadata even when the local/generated representation is unavailable. Asset cleanup is reference-aware and retains assets referenced by active teams, Recently Deleted, or readable backups.

### Preparation, validation, availability, and readiness

SongClip preparation runs through a one-job-at-a-time coordinator. Preparation triggers include assignment saved, app launch, foreground, Player Editor, Readiness, authorization changed, import repair, explicit Try Now, and retry. During Game Day/Clips the queue is throttled so live playback has priority; Low Power Mode pauses ordinary preparation except explicit Try Now.

Generated asset status values are none, pending, ready, failed-retryable, and failed-permanent. Readiness values include local clip ready, source-backed ready, source-backed downloaded, needs Apple Music, and needs repair. Portability values include portable local clip, source-reference-only, and metadata-only.

Preparation failures are classified as source missing, source unreadable, render failed, Music authorization required, or transient system failure. Retry metadata stores attempt count, last attempt, next retry, and the last failure code. The queue uses delayed retries and a maximum retry attempt policy; a previously working generated asset is retained when regeneration fails.

Readiness checks can detect:

- current audio route/output volume;
- missing or unavailable local assets;
- missing custom announcements;
- Apple Music authorization;
- network availability when Apple Music cues are present;
- source-backed/downloaded/generated state;
- empty or absent present lineup.

These checks produce warnings and repair actions but do not block Game Day. The Readiness UI can open the Player Editor, request Music access, retry preparation, or explain why a clip is device-dependent.

**Relevant sources:** `Models.swift` (`CueSource`, source structs, `Cue`, `TeamAnnouncerProfile`, readiness types, settings), `SongClipModels.swift`, `SongPickerFlow.swift`, `AppModel.swift` (assignment/playback/preparation methods), and `Services.swift` (`AudioAssetService`, `MusicCatalogService`, `CuePlaybackEngine`, `ReadinessService`, `SongClipGenerationService`).

## 6. Import, export, sharing, backup, and restore

### Roster CSV import

The Teams screen exposes **Import Roster CSV**. There is no current roster CSV export action found.

The parser accepts UTF-8/ASCII CSV with:

- a header row containing `name` and optional `number`; or
- simple two-column rows where the first column is the name and the second is the optional number.

The parser has quote-aware comma splitting, ignores empty lines, requires non-empty names, and rejects an empty/invalid import. The preview reports row count and duplicate count. Duplicate detection is based on lowercased trimmed name plus number; duplicates are reported rather than silently merged. Applying the import appends players to the selected team, marks them present by default, appends them to the lineup, and creates an automatic backup first.

Import is selected through a file importer and is a team-local operation; it does not replace the team or overwrite existing players unexpectedly.

### `.rollcall` team packages

Roll Call registers `com.jkfisher.rollcall.package` / `.rollcall` as a document type and accepts packages from the file importer, Share, AirDrop, or incoming document URLs. It only supports supported `.rollcall` files/directories with a manifest.

An exported package contains a `TeamPackageManifest` with:

- package schema version;
- app version;
- export timestamp;
- device label;
- a complete team payload;
- copied portable assets under package Assets where available.

The team payload includes team/player names and IDs, presence/order/session state, source-backed song metadata, custom clips, custom announcements, photos, and relevant readiness/portability/source lineage information. Team exports are ownership/sharing/backup artifacts; they do not include global AppSettings, rating state, support purchase state, Recently Deleted, or the app’s backup snapshot list. Support state is explicitly kept out of team exports.

Before export, the user sees a preview with team/player/audio/source counts and whether some clips are still preparing. The user can export while preparation is pending; waiting may allow more portable local clips to be included. Export produces a temporary safe-named `.rollcall` archive and presents it through the system share sheet.

For import, the app:

1. validates package structure/schema and manifest IDs/order;
2. shows a preview with counts and device-dependent statuses;
3. creates an automatic pre-import backup;
4. imports the team as a new team rather than overwriting an existing team;
5. copies included local assets into app storage;
6. retains Apple Music references as source-backed records needing current-device access where applicable;
7. records missing local files as repair-needed imported assets;
8. presents a per-item `PackageImportAudit` and schedules clip preparation.

Imported team names receive an “Imported” suffix where needed. A package with missing media can be partially useful; the UI explains the limitation rather than pretending all media was restored.

### Apple Music playlist sharing/sync

The Teams screen can create/update a convenience playlist named `Roll Call - <team name>` in the user’s Apple Music library. It includes unique catalog-backed Apple Music song sources from the team and skips local/built-in/preview-only sources. It is not a team export, backup, or share package. Unresolved catalog songs produce a recovery choice to continue with available songs or cancel.

### Backups and snapshots

The Recovery screen can create an app-state backup snapshot. Snapshots are local files under `Snapshots/`, retain up to ten records, and prune the oldest snapshot files when over the limit. A snapshot uses `backupSnapshotState`, which excludes Recently Deleted and snapshot metadata itself.

Restoring a snapshot first creates a pre-restore backup. It restores teams and app-level state from the snapshot while retaining current app version/device identity/settings/last-seen What's New/recently-deleted/snapshot metadata according to the restore implementation. Restore is an app-state operation, not an import of a `.rollcall` team.

### Recently Deleted and recovery

Recently Deleted retains supported deleted teams, players, and Custom Clips for 60 days. The Recovery center offers restore or explicit permanent delete. Player/custom-clip restoration can be blocked or become partial if the original team is gone or referenced media is missing. The UI explains missing-media limitations and can restore a player absent/present according to the recovery path.

**Relevant sources:** `Info.plist`, `Models.swift` (`TeamPackageManifest`, pending import/export and recovery models, `AppPaths`), `AppModel.swift` (package/CSV/backup/recovery methods), `Services.swift` (`PackageService`, CSV parser, package audit), and `RootView.swift` (Teams, package preview, CSV preview, Recovery, and share sheets).

## 7. Settings and preferences

### Global user settings

All six normal settings are stored in `AppState.settings`, persisted in `state.json`, and apply app-wide unless noted.

| Setting | Purpose and current user experience | Default | Allowed values | Scope/storage |
|---|---|---:|---|---|
| **Hide Explicit Apple Music Results** (`explicitAppleMusicSearchFilteringEnabled`) | Hides explicit songs from Apple Music search. Music Library songs may still appear, but an explicit selected library song requires a separate confirmation. | On | On/Off | Global; `AppState.settings` in `state.json`. |
| **Volume Automation** (`fadeOutVolumeAutomationEnabled`) | Fades Apple Music down at the end of a clip and restores the captured previous system volume. | Off in current model | On/Off | Global; `AppState.settings`. |
| **Always Use Dark Live Screens** (`alwaysUseDarkLiveMode`) | Keeps Game Day and Clips dark for field visibility while other screens follow device appearance. | On | On/Off | Global; `AppState.settings`. |
| **Game Day Haptics** (`hapticsEnabled`) | Enables subtle haptic feedback for live controls, lineup progression, and fallback/success feedback where implemented. | On | On/Off | Global; `AppState.settings`. |
| **Keep Screen Awake** (`keepScreenAwakeDuringLiveUse`) | Prevents auto-lock only while Roll Call is active on Game Day or Clips. | Off | On/Off | Global; `AppState.settings`; applied through `UIApplication.isIdleTimerDisabled`. |
| **Show Lineup Progress Hints** (`showLineupProgressHints`) | Shows the subtle lineup-flow animation when advancing from Next or On Deck. Reduce Motion suppresses it. | Off | On/Off | Global; `AppState.settings`. |

The explicit-song filter is applied in two places: Apple Music search results filter out `isExplicit == true` while enabled, and recent Apple Music selections are filtered before display. Library songs are not silently hidden; the app presents an explicit confirmation before use. The source metadata preserves the optional explicit flag.

### Per-team configuration

These are user-editable or user-controlled team-level values, stored inside each `Team` in `AppState.teams`:

- team name;
- accent preset: Roll Call Orange, Red, Gold, Green, Blue, Purple, Gray, Black;
- Game Day announcer mode: Announcer Only, Announcer+Song, Song Only;
- batting order and whether it is customized;
- next-batter index;
- team-scoped Custom Clips;
- the persisted `TeamAnnouncerProfile` model.

`activeSessionDate` is also stored per team but no active user-facing setter/consumer was found. `TeamAnnouncerProfile` has phrase template, requested/resolved voice IDs, language, rate, pitch, and volume, with default phrase “Now batting, number <number>, <name>”, en-US, rate 0.46, pitch 1.0, volume 1.0. Current visible Built-in Voice actions report that Built-in Voice has been removed, so this is currently legacy/model state rather than a functioning normal settings surface.

### Per-player configuration

Stored inside each `Player` in the selected team:

- display name — required for creation;
- uniform number — optional string;
- pronunciation override — optional string used by announcement-generation/legacy paths;
- photo relative path — optional, app-owned asset;
- song assignment — optional player-scoped `SongClip`;
- custom Announcement Cue relative path — optional app-owned recording;
- presence — present/out for the current lineup.

Song-editor choices are persisted inside the player’s clip: source, label, trim start, duration, fade, pause after announcer, generated/readiness/portability state, and retry metadata.

### Trim preferences

The Song Clip Editor exposes suggested-hook/start-at-beginning behavior, waveform selection, advanced trim, and length choices. Current visible player-editor choices are 6, 8, 10, 12, and 15 seconds; the general clip editor also includes 20 seconds. `TrimDefaults.preferredLength` is persisted in `AppState`, defaults to 12 seconds, and is updated when the user selects a preferred length. It is a remembered editing preference, not a Settings-tab toggle.

### Experimental/developer preferences

`ExperimentalSettings` is stored in `AppState`:

- `showExperimentalFeatures`, default false;
- `appleMusicTeamPlaylistSyncEnabled`, default false;
- acknowledgment timestamps.

Developer/Internal builds can expose a Developer Tools surface. Debug builds may force experimental visibility. These tools include testing controls for What’s New, rating thresholds/prompts, support-bundle generation, Music render probes, duplicate-player-song utilities, and generated-clip inspection/cleanup. Release builds hide developer settings and unfinished features. These are test/diagnostic controls, not normal product settings.

### Other persisted preference-like state

- `lastSeenWhatsNewReleaseID` controls the automatic What's New presentation.
- `recentAppleMusicSelections` remembers up to eight visible recent selections (with a larger persisted history cap) and selected-at timestamps.
- `deviceIdentity.label` is persisted and defaults to “This iPhone”; no current normal user-facing edit control was found.
- `ratingRequest` stores rating counters/flags described below.

**Relevant sources:** `Models.swift` (`AppSettings`, `ExperimentalSettings`, `TrimDefaults`, `TeamSessionState`, `TeamAnnouncerProfile`, `AppState`), `AppModel.swift` setting methods, and `RootView.swift` Settings/Developer Tools/Player Editor/Song Clip Editor UI.

## 8. Rating/review behavior

### Current source-of-truth policy

The current `AppModel.RatingRequestPolicy` constants are:

- qualifying session threshold: **10** successful Game Day sessions;
- retry increment: **10** additional sessions;
- maximum automatic prompt attempts: **2**;
- cooldown between counted successful sessions: **4 hours**.

`hasEarnedRatingRequest` is true when the persisted successful-session count is at least 10. `canPresentAutomaticRatingRequest` additionally requires the current next threshold and fewer than two automatic attempts.

### What counts as a successful session

Entering Game Day starts a visit-level state. A player cue playback success marks `hasPlayedQualifyingCueInCurrentGameDayVisit`; successful fallback playback also marks it. Leaving Game Day, or backgrounding while Game Day is active, calls `finalizeGameDayVisitForRatingIfNeeded()`.

At finalization:

- if a qualifying cue played and the visit was not counted, the count increments only if at least four hours have elapsed since the last counted session;
- the visit is then marked counted even when the cooldown prevents incrementing;
- the current visit flags are reset when the next Game Day visit begins.

The implementation counts a qualifying live-use visit, not every individual cue or player tap.

### Prompt eligibility and presentation

Automatic presentation is additionally blocked while:

- onboarding is active;
- What's New is unseen;
- Game Day or Clips is the active/safe-excluded tab;
- another sheet, editor, alert, package/CSV import, export share sheet, or playlist flow is active;
- the app is busy/risky operation state is non-zero;
- an active error alert exists.

When eligible, the app increments `automaticPromptAttemptCount` before presenting its own `RatingRequestSheet`. The first attempt moves the next threshold from 10 to 20. The second consumes the automatic budget.

The user-facing sheet says “Enjoying Roll Call?” and offers:

- **Rate Roll Call** — opens the App Store write-review URL directly;
- **Email Me Instead** — opens a feedback email;
- **Not Now** — dismisses;
- a support-development link that opens the support screen.

The Settings > About screen exposes **Rate Roll Call** after the 10-session threshold is earned and opens the same custom sheet. The automatic and manual sheets are the same user-facing sheet type, distinguished by presentation state.

`SKStoreReviewController.requestReview(in:)` is available only through the Developer Tools test action. The production sheet’s explicit Rate action does not call StoreKit’s native in-app prompt; it opens the App Store review page.

### Persistence

`RatingRequestState` in `AppState` stores:

- `successfulGameDaySessionCount`;
- `hasPlayedQualifyingCueInCurrentGameDayVisit`;
- `hasCountedCurrentGameDayVisit`;
- `lastCountedSuccessfulGameDaySessionAt`;
- `automaticPromptAttemptCount`;
- `nextAutomaticPromptSessionThreshold`.

There is no persisted user response outcome for the App Store page, no rating value, and no server-side review confirmation.

### Test/source discrepancy

The current source constants are 10/20, but `RollCallTests/RatingRequestTests.swift` still asserts a threshold of 5 and retry threshold of 10. The current `docs/DECISIONS.md` says the 5/10 policy was superseded by 10/20. The discrepancy is left unresolved and is listed in [Possible Assumption Mismatches](#possible-assumption-mismatches).

**Relevant sources:** `AppModel.swift` (`RatingRequestPolicy`, rating visit methods), `Models.swift` (`RatingRequestState`), `RootView.swift` (`canPresentAutomaticRatingRequest`, rating sheet, About, Developer Tools), `RollCallTests/RatingRequestTests.swift`, and `docs/DECISIONS.md`.

## 9. Donation/support behavior

### Availability and eligibility

Support is optional and does not gate any feature. The support screen states that Roll Call is free, ad-free, and fully functional for every team, and that support never unlocks Game Day, teams, imports, exports, or reliability.

The support screen is opened from the rating-request sheet’s “contribute in Settings” action and from Developer Tools in the current UI. No normal always-visible Support button was found in the primary Settings list; the About/Settings path provides the rating flow and the support handoff.

There are no local usage thresholds, cooldowns, counters, or eligibility requirements for opening support or purchasing. Product availability is determined by StoreKit product loading.

### Products and actions

One-time products:

- Tip of the Cap — small support;
- Dugout High Five — medium support;
- Walk-Up Hero — large support;
- Grand Slam Legend — largest support.

Recurring products:

- Season Supporter — monthly;
- All-Star Season Supporter — yearly.

The UI provides:

- a One-Time/Recurring segmented control;
- product buttons showing StoreKit display prices;
- purchase;
- retry product loading;
- restore support subscription through `AppStore.sync()`;
- manage subscriptions through Apple’s subscription-management UI;
- a thank-you state when verified support has been observed;
- purchase/pending/cancelled/unavailable messaging.

One-time contributions can be made again. Recurring support renews until cancelled in Apple ID subscriptions.

### Detection and persistence

`StoreKitSupportTransactionObserver` starts at app launch and listens to `Transaction.updates`. Verified transactions are recognized and finished. The support store also reads `Transaction.currentEntitlements` when the support screen appears.

Local `SupportLocalCache` stores:

- whether verified support has ever been seen;
- last verified product ID/title/date;
- active subscription product ID/title.

This cache is stored in `UserDefaults.standard` under `rollCall.support.localCache.v1`, not in `AppState`, team packages, or backups. An active subscription is shown only when the verified recurring transaction is not revoked and has not expired.

Therefore, a successful support action **can currently be detected locally** when StoreKit returns a verified transaction or entitlement. The repository has no backend, server receipt store, donation-specific analytics, or durable cross-device support history beyond Apple ID entitlement lookup and this local cache. An unverified, pending, cancelled, failed, or unavailable purchase is not treated as successful.

**Relevant sources:** `Services.swift` (`SupportContributionKind`, `SupportProductDefinition`, `SupportLocalCache`, `StoreKitSupportTransactionObserver`, `StoreKitSupportStore`), `RootView.swift` (`SupportRollCallScreen`, `SupportProductButton`, rating/support handoff), and `RollCallApp.swift` startup.

## 10. Reliability and failure behavior

### Playback fallback chain

The intended fallback behavior in `AppModel.playbackPlan` is:

- **Announcer Only:** recorded custom announcement if present; otherwise Small Cheer.
- **Announcer+Song:** recorded announcement when present, then playable song; missing announcement is skipped; missing/unplayable song uses Small Cheer.
- **Song Only:** playable song; missing/unplayable song uses Small Cheer.

If an Apple Music cue was attempted and playback throws, the app explicitly tries Small Cheer and records the fallback player ID. If the fallback itself fails, the user receives an error alert and warning haptic when enabled. Built-in clips are expected to be locally present and are ensured from the app bundle.

### Playback failures and user-visible errors

The shared `CuePlaybackEngine` handles:

- rapid repeated taps through a debounce window;
- stopping/replacing active cues;
- missing announcement files by skipping to the primary cue;
- Apple Music library/catalog/preview fallback paths;
- Apple Music duration limits;
- volume restoration after automation;
- cancellation without treating ordinary user cancellation as a product error.

`AppModel.lastError` is shown as a Roll Call alert. Failure categories include unavailable media, invalid/import errors, Music authorization, microphone permission/recording, unsupported packages, playlist failure, and playback failure. A busy overlay serializes risky operations such as import/export/restore and reports operation errors.

### Missing or unavailable media

The app preserves source-backed records when the current device cannot play the source. It does not silently delete a saved Apple Music selection or local-media source solely because it is unavailable. Readiness and package audit state explain whether the item needs Apple Music access, needs repair, is source-backed but device-dependent, or has a missing local asset.

For missing imported package files, `PackageService` records a repair-needed imported asset path and an audit item. The user can open the relevant player/clip repair path. For missing player photos, the package audit explains that the photo was referenced but not included; photos remain optional to live readiness.

Custom Clips that cannot currently play show an unavailable state with a Repair Clip action. Player song issues are surfaced through the Player Editor’s readiness explanation and Readiness screen.

### Repair and preparation workflows

Repair/recovery actions include:

- request Apple Music access;
- retry or explicitly **Try Now** for clip preparation;
- open the Player Editor to replace/import a cue;
- re-record or clear a missing custom Announcement Cue;
- re-add a missing photo;
- re-import missing package media where the source can be supplied;
- continue an Apple Music playlist sync with available songs or cancel;
- restore deleted records or backups, with partial-restore explanation.

Generated clips use deterministic source/selection/policy keys to reject stale results. Preparation stores pending/ready/failure state in `SongClip`; it does not replace a working generated asset with a failed result.

### Important live-use checks

Readiness can warn about:

- no selected team or no present players;
- unknown audio route;
- low output volume;
- Apple Music cues without network path;
- missing Music authorization;
- missing song source/local asset;
- missing custom announcement;
- missing audio preparation.

The live Game Day warning strip suppresses optional photo issues and can suppress the volume warning when volume automation is enabled. These warnings are advisory and do not disable live controls.

### Recovery behavior

Deletion uses Recently Deleted first, with 60-day retention and explicit permanent deletion. Risky imports/restores create automatic backups. Restore operations preserve current app-level identity/configuration fields according to the restore policy. State writes are atomic, and unreadable state is preserved as a diagnostic copy before the app starts fresh.

**Relevant sources:** `AppModel.swift` (playback plan, fallback, preparation, repair, recovery, busy/persistence), `Services.swift` (`CuePlaybackEngine`, `ReadinessService`, `PackageService`, asset services), `SongClipModels.swift`, and `RootView.swift` live warning/repair UI.

## 11. Existing diagnostics

### Logging and telemetry

The only explicit OSLog logger found is the `AppleMusicVolumeAutomation` logger in `MediaPlayerCatalogPlaybackController`. It logs system-volume baseline capture, restoration, and discarded pending restores. Logged volume values are marked public in the current source.

Product telemetry is routed through the Roll Call-owned typed boundary in `Telemetry.swift` to the exact TelemetryDeck 2.14.2 SDK pin. The approved production app ID is supplied through the app target's `Info.plist`; tests and previews use non-networking providers. The independent Anonymous Usage Analytics preference defaults on and gates ordinary signals.

### Crash/error reporting and analytics

No Crashlytics, Sentry, App Center, or custom crash uploader was found. Fixed product and reliability signals are now sent only through the approved TelemetryDeck boundary. Errors remain represented locally as `AppError`, `lastError`, status strings, readiness checks, StoreKit messages, package audits, and user-shared support bundles; raw errors and user content are not telemetry properties.

`PrivacyInfo.xcprivacy` declares:

- unlinked, non-tracking Product Interaction, Device ID, and Other Diagnostic Data for Analytics;
- tracking disabled;
- UserDefaults API access with reason `CA92.1`.

The SDK's standard metadata and default IDFV-derived identity are documented in [Privacy](../product/PRIVACY.md). This manifest is a declaration of the current app privacy surface and must be reviewed if the pinned SDK changes.

### Existing support-bundle diagnostics

Developer/Internal builds can generate a local `RollCall-Support-<UUID>.json` support bundle and share it manually. The visible description says it excludes team names, player names, IDs, filenames, song metadata, media, and other user-created content.

The bundle contains aggregate or redacted diagnostics including:

- generated timestamp, app version, schema version;
- selected-team index;
- current AppSettings and experimental flags;
- readiness-state counts;
- boolean playback state and debounce window;
- redacted team summaries with player/present/built-in counts;
- song-clip source, generation-status, readiness, and portability counts;
- retry totals and failure-code counts;
- generated-asset disk usage;
- policy flags/versions;
- generated-clip cleanup totals.

It is generated on demand and shared by the user. It is not automatically uploaded.

### Counters, timestamps, and lifecycle state relevant to later discussion

The repository already persists or maintains the following state, without sending it as analytics:

- onboarding completion and milestone flags;
- selected team ID;
- team/player creation and modification timestamps;
- player presence and batting order/next-batter index;
- `activeSessionDate` field, currently without a resolved active workflow;
- readiness generation timestamp and checks;
- recent Apple Music selection timestamps;
- clip generation retry counts, attempt/next-retry/failure timestamps;
- generated asset creation timestamps;
- app version/schema and What's New seen ID;
- rating successful-session count, cooldown timestamp, visit flags, prompt attempts, and next threshold;
- support verified-purchase/subscription cache timestamps and product identifiers;
- backup snapshot timestamps/reasons;
- Recently Deleted creation/deletion/expiry timestamps;
- in-memory playback session/cue/progress/prewarm identifiers;
- in-memory busy/risky-operation count, active fallback player, cleanup report, and preparation queue count.

Telemetry state is deliberately not part of this inventory's user-content export surfaces. The approved event/property contract, local de-duplication state, and provider behavior are documented in [ROLL_CALL_TELEMETRY_SPEC.md](./ROLL_CALL_TELEMETRY_SPEC.md).

**Relevant sources:** `Services.swift` (logger, support bundle, diagnostics), `AppModel.swift` (published/in-memory state and persisted counters), `Models.swift`, `PrivacyInfo.xcprivacy`, and `Info.plist`.

## 12. Other meaningful user-visible features

### What's New

Roll Call has an offline, app-version-family-based What's New presentation. It can appear automatically after launch when the current release family has not been marked seen, subject to onboarding/live/modal safety rules. The user can also open it manually from About. `lastSeenWhatsNewReleaseID` is persisted. The full public changelog is a separate human-curated document/link; the in-app prompt is not remote-fed analytics content.

### About, feedback, and attribution

About displays app version/build/environment, a website link, email feedback, What's New, the earned rating entry, and credits/attributions. Feedback email includes app version/build/environment information in the subject according to the current implementation. It is user-initiated.

### Photos and player presentation

Player photos can be selected, cropped/adjusted, replaced, or removed from the Player Editor. Photos appear in Players, Game Day hero, On Deck, and player tiles. They are presentation enhancements and are not required for a usable Game Day player.

### Music Library and Apple Music permissions

The app asks for Music authorization only when the user chooses a music source or when readiness detects Apple Music cues requiring access. Denied/restricted access presents Settings guidance or a file-import alternative. Microphone permission is requested only when recording an announcement. Photos use PhotosUI selection. File import uses security-scoped URLs.

### Apple Music playlist convenience tool

Teams includes a user-facing playlist preview and synchronization tool. It resolves current catalog-backed songs, reports duplicate/unresolved songs, and lets the user continue with available songs or cancel. The playlist is not a backup, export, or product account feature.

### Recovery center

Settings includes a Recovery center for Recently Deleted records and local snapshots. It is a substantial ownership/data-safety feature independent of the normal team editing flow.

### Developer and experimental tools

When exposed in non-Release builds, Developer Tools provide:

- build/environment and What's New state;
- experimental visibility toggle;
- rating threshold testing, native StoreKit prompt testing, custom rating sheet testing, and App Store review-page testing;
- support-bundle generation/sharing;
- Music render probes for controlled library/catalog playback scenarios;
- duplicate player songs to Custom Clips;
- generated-clip inspection and cleanup.

These tools are not part of the ordinary App Store user journey but are user-visible in eligible builds and can mutate local test state.

### Product boundaries visible in code

No account creation, cloud sync, required network account, ads, social sharing service, remote-control infrastructure, generalized statistics/scoreboard feature, or paid feature tier was found. Sharing is through system file/activity sharing of local `.rollcall` packages, and support is through StoreKit contributions that do not unlock functionality.

## **Possible Assumption Mismatches**

The following findings should remain explicit for the separate telemetry/product discussion:

1. **“Clip Pad” is not the current product label.** The UI says **Clips**, the root enum is `generalClips`, and the data model uses `teamClips`. No distinct Clip Pad/session model was found.

2. **The onboarding cheer fallback is a completion flag, not a saved cue.** Choosing **Try with a Crowd Cheering** sets `didChooseCheerFallback`, but does not assign Small Cheer to the player. Onboarding can complete with no player song assignment; Game Day then resolves the built-in fallback at playback time.

3. **Current source and tests disagree on rating thresholds.** `AppModel.swift` currently implements 10 sessions, then a retry at 20, while `RollCallTests/RatingRequestTests.swift` expects 5 and 10. `docs/DECISIONS.md` describes 5/10 as superseded by 10/20. The source implementation and the test expectations cannot both describe the same current behavior.

4. **Built-in Voice is partly removed and partly retained in the implementation.** The current visible profile-save/preview methods say Built-in Voice has been removed and direct users to recorded Announcement Cues. At the same time, `TeamAnnouncerProfile`, `AnnouncerTemplate`, speech-rendering code, generated-announcer paths, pronunciation fields, and legacy migration remain in the model/services. The current normal user experience appears to be recorded announcements only, but the retained code makes the exact supported boundary ambiguous.

5. **There is no formal Game Day session despite session-shaped state.** `TeamSessionState.activeSessionDate` is persisted, while the active implementation uses lineup state, the in-memory playback session, and rating visit flags. No current user-facing game-date/session lifecycle was found that sets or consumes `activeSessionDate`.

6. **Rating “successful session” means a qualifying playback visit, not a user-confirmed successful game.** A successful player cue or successful fallback marks the visit; leaving Game Day/backgrounding finalizes it. A user does not explicitly confirm that a game session succeeded.

7. **Apple Music playability is intentionally deferred until runtime in some paths.** `cueIsPlayable` treats Apple Music sources as playable at the source-resolution layer, while readiness tracks authorization/network/device state and actual playback can fail before Small Cheer is used. “Assigned,” “source-backed,” “ready on this device,” and “actually played” are distinct states.

8. **Readiness is not onboarding completion.** The app can complete onboarding and open Game Day with missing songs, missing announcements, missing photos, no Music permission, or a fallback-only player. Readiness warns and offers repair; it does not gate the live surface.

9. **Support success is locally detectable but not externally recorded.** Verified StoreKit transactions and current entitlements can update the local support cache and thank-you UI. There is no backend receipt service or donation telemetry path, and team packages/backups intentionally exclude support state.

10. **The package includes a device label.** Although support bundles redact user-created names/content and support state is excluded from packages, `TeamPackageManifest` includes `deviceLabel` along with the team payload. The privacy meaning of that label depends on its current value and should not be assumed equivalent to an anonymous package identifier.

11. **CSV import exists without CSV export.** The product supports roster import and `.rollcall` team export, but no current roster CSV export path was found. These may be easy to conflate when describing “roster sharing.”

12. **Playlist sync is not backup/sharing.** The Apple Music playlist tool is a convenience synchronization action over catalog-backed sources. It does not carry team state, local media, support state, or package ownership semantics.

13. **Support entry is not a normal top-level Settings item in the inspected UI.** Support is reached from the rating sheet and Developer Tools; the primary Settings list exposes About, setup, playback, Game Day, Recovery, and (when allowed) Developer Tools. Any description of a permanent Settings support entry would not match the current view hierarchy.

14. **Telemetry is now a separate approved pipeline.** Playback/readiness/preparation/rating/support state remains local or manually shareable through redacted support bundles, while only the allowlisted product/reliability signals in `ROLL_CALL_TELEMETRY_SPEC.md` go through TelemetryDeck. The separate telemetry/rating store and analytics preference are excluded from Roll Call-owned packages, backups, Recently Deleted, support bundles, and team duplication.

15. **Some Game Day tile presentation can be less conservative than playback resolution.** The hero uses `AppModel.playerWillUseFallback`, which checks whether a local asset exists, while the `GameDayTeamStack`/grid helper checks only whether a cue exists for some tile-state decisions. A player with a saved but unavailable cue can therefore have a tile presentation that does not fully match the fallback that playback will actually resolve. The hero and the playback path remain the stronger behavior sources.
