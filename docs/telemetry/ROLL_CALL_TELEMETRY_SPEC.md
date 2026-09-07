# Roll Call Telemetry Signal Reference

**Status:** Owner-approved design / pre-implementation  
**Telemetry provider:** The official TelemetryDeck Swift SDK, behind a Roll Call-owned analytics abstraction  
**Companion data source:** Apple App Store Connect analytics  
**Purpose:** Durable source of truth for what Roll Call telemetry means so future analysis does not depend on memory or implementation archaeology.

---

## 1. Core principles

### 1.1 What telemetry is for

Roll Call telemetry exists to answer product questions that Apple App Store Connect cannot answer well enough on its own:

- Do people get through setup?
- Do they create a meaningfully personalized team?
- Do they actually use Roll Call during probable real games?
- Do they come back and use it repeatedly?
- Which live features are used during probable games?
- Which media paths are actually used?
- Are rating prompts shown too early or too often?
- Which defaults do users reject?
- Which import/export/recovery features matter?
- Where does live playback fail or recover?

Apple App Store Connect remains the preferred source for platform-level metrics such as downloads, installations, deletions, crashes, App Store acquisition, and Apple-provided retention/usage metrics.

### 1.2 Privacy boundary

Telemetry may describe **what happened**, but never **what the user put into Roll Call**.

Never transmit:

- Team names
- Player names
- Player numbers
- Song titles
- Artist names
- Apple Music song/catalog/library IDs
- Filenames or file paths
- Photos
- Recordings
- CSV contents
- `.rollcall` package contents
- Free-form user text
- Device label
- Exact location
- Exact timestamps when a bucket/milestone is sufficient
- Any Roll Call-defined identifier intended to recognize the same person across unrelated apps or devices

Only predefined Roll Call event names and predefined Roll Call property values may be emitted. The official TelemetryDeck SDK's standard automatic metadata is also permitted and must be documented in the privacy inventory and reviewed when the pinned SDK version changes.

### 1.3 Adoption commit boundary

Unless an individual signal defines a stricter boundary, setup and adoption telemetry fires only after the user confirms the action, required synchronous/awaited asset work succeeds, the canonical in-memory `AppState` mutation occurs, and Roll Call schedules persistence. Do not wait for the current asynchronous persistence writer to confirm the disk write; telemetry must not introduce cross-cutting pending-event bookkeeping tied to persistence sequence acknowledgements.

Picker presentation, draft edits, crop/trim previews, recording start, temporary asset creation, cancelled work, and failed operations do not count. This rule applies to photo and announcement adoption, media assignment/import, Custom Clip creation, team duplication, accent and announcer-mode changes, normal settings, and roster/team thresholds. A later asynchronous state-write failure may therefore make an adoption event overstate retained state; that rare failure is handled as a separate reliability condition rather than redefining every product action around disk acknowledgement.

### 1.4 Analytics user experience

- Anonymous usage analytics are enabled by default.
- No first-launch consent dialog.
- No ATT prompt solely for this telemetry design.
- Settings contains a clear **Anonymous Usage Analytics** switch.
- The switch is a dedicated app preference outside both `AppState` and the telemetry/rating-history store. An absent preference means enabled. Once the user changes it, persist the explicit value independently so app-state recovery, Roll Call backup restore, team import, telemetry-store recovery, and team duplication cannot alter it.
- Do not include this preference in `.rollcall` packages, Roll Call-owned backup snapshots, Recently Deleted, support bundles, or team duplication. Ordinary iOS device backup may preserve it; deleting/reinstalling the app may reset it to the default-enabled state under the accepted reinstall policy.
- Turning analytics off prevents Roll Call from recording new telemetry events except for the single allowlisted preference-transition event described below.
- Events already handed to the TelemetryDeck SDK may still finish sending from its memory or disk cache after the switch is turned off.
- Turning analytics back on does **not** cause Roll Call to reconstruct or submit activity that occurred while analytics was disabled. The SDK may still deliver events that were recorded before analytics was disabled.
- Serialize preference transitions through the telemetry layer. When turning analytics off, close the ordinary in-memory recording gate and persist the opt-out first, then use a dedicated narrow path to enqueue `analytics.preferenceChanged` with `newValue = off`, and finally put the SDK into disabled mode. No other event may pass the closed gate. The final preference event may remain in the SDK cache and transmit later under the accepted cache limitation.
- When turning analytics on, persist the choice, enable the SDK, enqueue `analytics.preferenceChanged` with `newValue = on` as the first event, and then reopen the ordinary recording gate. Do not backfill disabled-period events.
- On launch, read the preference before configuring the SDK. If disabled, configure or place the SDK in disabled mode before feature code can record anything.
- Anonymous identity uses TelemetryDeck's default IDFV-derived identifier behavior with its default salt configuration.
- The anonymous identifier may persist across a Roll Call reinstall while another app from the same vendor remains installed, and the same vendor/device identifier may be used by other Sidelark apps that also retain TelemetryDeck's defaults.
- TelemetryDeck distinct-user counts must therefore be interpreted as anonymous vendor/device identities, not people or Roll Call installations. Apple App Store Connect remains authoritative for installation counts.
- Local counters required for product behavior continue while telemetry is disabled. Any telemetry milestone crossed during that period is marked suppressed/consumed without transmission so Roll Call does not later emit a misleading old milestone.

### 1.5 Architecture

Feature code must not call TelemetryDeck directly.

Use the official TelemetryDeck Swift SDK for ingestion, batching, retry, lifecycle integration, and its standard automatic metadata. Do not replace it with a Roll Call-owned HTTP ingestion client merely to suppress SDK-provided metadata or caching behavior.

For the initial implementation, pin the Swift package to exact version `2.14.2`. Do not adopt the 3.x prerelease line or an automatically advancing compatible-version range. Any SDK update is a deliberate dependency change that requires release-note review, an exact automatic-metadata/privacy inventory comparison, and focused identity, opt-out, caching, Test Mode, and signal-shape regression tests before the pin moves.

Use one Roll Call-owned telemetry layer with:

- A predefined event enum
- A predefined property allowlist
- Central privacy validation
- Analytics-enabled gating
- Roll Call-defined app/build/schema metadata
- Local milestone de-duplication
- Local per-game aggregation where required

The provider must be replaceable without rewriting feature code.

Configure the SDK to avoid telemetry that duplicates Roll Call's product model:

- Disable the SDK's automatic session-start signal.
- Disable the SDK's automatic session statistics; Roll Call's probable-game model is authoritative for product telemetry.
- Route every Roll Call-defined event through the central typed abstraction.
- Apply the Settings opt-out through the SDK's analytics-disabled configuration.

Retain the SDK's default IDFV-derived anonymous identifier and default salt configuration. Do not add a Roll Call-generated installation identifier or a Roll Call-specific identifier salt. This intentionally favors the standard SDK integration over install-scoped identity semantics.

### 1.6 Build and distribution environments

Use one TelemetryDeck app ID and the SDK's standard environment metadata rather than creating Roll Call-defined distribution properties or separate TelemetryDeck projects.

- App Store builds send non-test production signals.
- TestFlight and developer builds send signals in TelemetryDeck Test Mode so their data remains available for validation without entering production insights.
- Automated tests and SwiftUI previews use a non-networking telemetry provider. Tests may inspect captured typed events locally but must not contact TelemetryDeck.
- Preserve the SDK's standard `isTestMode`, debug, simulator, TestFlight, App Store, and target-environment metadata; do not duplicate those fields under Roll Call-defined names.

---

## 2. Versioning and automatic metadata

Every transmitted signal should automatically carry:

- `appVersion`
- `buildNumber`
- `telemetrySchemaVersion`

The official SDK also attaches its standard metadata. This may include TelemetryDeck-owned fields describing app and SDK versions, operating system and device characteristics, run context, session/ingest context, language and region preferences, appearance preferences, and accessibility settings. Roll Call does not need to suppress those standard fields, but must:

- inventory the exact fields added by the pinned SDK version before release;
- reflect applicable collection accurately in the privacy manifest, App Store Connect privacy answers, and privacy policy;
- review material metadata changes before updating the SDK.

Signals affected by heuristic/policy logic should also carry:

- `gameHeuristicVersion`
- `ratingPolicyVersion` when relevant

### Planned initial versions

- `telemetrySchemaVersion = 1`
- `gameHeuristicVersion = 1`
- `ratingPolicyVersion = 1`

Version numbers must change when the meaning of the corresponding signals changes materially.

---

## 3. Local-only telemetry state

Store telemetry history and automatic-rating anti-nag state in a small, versioned app-local store that is separate from `AppState`.

- Do not include this store in `.rollcall` packages, Roll Call in-app backup snapshots, Recently Deleted payloads, support bundles, or team duplication.
- Restoring an older Roll Call snapshot must not rewind emitted milestones, probable-game/date counters, per-team de-duplication, retention enrollment, or automatic-rating attempts and eligibility history.
- Team import, duplication, restoration, and deletion may change the current product state evaluated by future actions, but must not copy or restore telemetry history from the team data.
- The dedicated Anonymous Usage Analytics preference is independent of this store and of `AppState`; neither telemetry-store migration/recovery nor AppState restore may change an explicit opt-out.
- Do not add special exclusion from ordinary iOS device backup solely for this store. This boundary concerns Roll Call-owned package, snapshot, and recovery formats.
- Do not use Keychain, iCloud, or another durable cross-install mechanism solely to preserve this store across deletion and reinstallation. A fresh reinstall may therefore restart one-time milestones, probable-game/rating history, and automatic-rating eligibility. If ordinary iOS device-backup restoration happens to restore the app-local store, preserve the restored history; Roll Call does not need to force either continuity or reset across reinstall.
- Because TelemetryDeck's default IDFV-derived identity can survive a Roll Call reinstall while another app from the same vendor remains installed, repeated first-use or milestone events after a local-store reset may appear under the same anonymous vendor/device identity. Analysis must treat this as an accepted limitation rather than attempting stronger recognition.
- The store requires its own schema version, fail-safe decoding defaults, and focused migration/restore tests.

### Existing-install enrollment baseline

When the telemetry store is first created for an `existingInstall` cohort, report adoption that can be proven from current persisted state instead of treating telemetry enrollment as a clean slate. Every signal eligible for this baseline carries:

`observationOrigin = enrollmentBaseline | observedAction`

Use `enrollmentBaseline` only during the one-time existing-install scan. Use `observedAction` when the same signal is earned from an action or state transition observed after enrollment. Emit every satisfied threshold needed to preserve funnel shape; for example, a current 15-player roster emits the 3, 5, 10, and 15 milestones. Record the corresponding local de-duplication flags atomically with the scan so launch retries cannot duplicate the baseline.

For an `enrollmentBaseline` event, action-shaped names such as `playerPhoto.firstAdded`, `announcement.firstRecorded`, or `media.firstAssigned.*` mean only that current persisted state proves adoption at enrollment. They do not claim that this installation performed the original add/record/assignment action; the content may have arrived through an earlier package import or device-backup restore. Analysis must filter or group by `observationOrigin` whenever historical action completion matters.

The baseline may emit only signals whose meaning is defensibly supported by current state:

- `onboarding.started`, `onboarding.completed`, `onboarding.importPathUsed`, and `onboarding.cheerFallbackChosen` when their persisted onboarding fields currently prove the condition;
- `roster.playerCount.3`, `.5`, `.10`, and `.15`;
- `teams.activeCount.2` and `.3`;
- `team.personalized`;
- `playerPhoto.firstAdded` and `announcement.firstRecorded` when at least one current player has the corresponding persisted asset reference;
- the `media.firstAssigned.*` signals classifiable from a current private clip's persisted original source, and `media.clipReuse.firstUsed` when persisted clip lineage proves reuse;
- `clips.firstCustomCreated`;
- `trim.preferredLengthFirstChanged` when the current remembered value differs from 12 seconds;
- `teamAccent.firstChanged` and `announcerMode.firstChanged` for current nondefault team values; and
- the four `setting.*.firstChanged` signals when the current value differs from that setting's default.

Do not inspect or transmit filenames, media titles, player/team identity, exact counts, exact dates, or other content while deriving the baseline. Source classification must use only the persisted enum/lineage fields already needed by the product.

Do not infer historical events that current state cannot prove, including prior probable games, player-playback counts, `live.entered`, package/CSV imports or exports, playlist-sync use, backup/restore actions, Recently Deleted restores, Readiness openings, repair attempts, failures, permission denials, rating-sheet actions, or support actions. Those begin with post-enrollment observation. A historical action that left no current provable state remains intentionally unreported.

If analytics is disabled during enrollment, perform the same baseline evaluation but mark the eligible signals suppressed/consumed under the analytics-disabled rule below. Do not transmit the old baseline after re-enablement.

### Telemetry/rating-store recovery

The telemetry/rating store is nonessential to core app operation, but unsafe default reconstruction could duplicate lifetime signals or recreate automatic rating eligibility.

- If the file has a newer unsupported schema, leave it untouched. Disable ordinary Roll Call telemetry emission and automatic rating presentation for that run. Do not overwrite, migrate backward, or pretend its history is empty; the manual rating path remains available.
- If the file is corrupt or unreadable, quarantine it and first save a conservative replacement before resuming any ordinary telemetry. Set the cohort to `existingInstall`; skip the enrollment-baseline scan; treat all historical one-time, retention, playback-depth, and probable-game-date milestones as consumed; and permanently suppress automatic rating asks while leaving the manual path available.
- After a conservative replacement is successfully saved, emit one property-free `telemetryState.recovered`, then allow new raw action events and newly qualified `game.probable` sessions. Do not resume historical threshold ladders or reconstruct old events.
- If the conservative replacement cannot be saved, keep ordinary telemetry and automatic rating presentation disabled. The separate Anonymous Usage Analytics preference remains authoritative and unchanged throughout recovery.
- Never transmit or retain the corrupt file's contents, decode error text, replayable event payloads, or any recovered app content.

For a runtime telemetry/rating-store write failure, immediately suspend ordinary telemetry emission and automatic rating presentation while leaving core Roll Call behavior and the separate analytics preference unchanged. Keep the current telemetry/rating state in memory and retry only through the normal store path; resume only after that current state is successfully saved. Do not queue or later reconstruct product events observed while emission was suspended.

When analytics was enabled, emit one property-free `telemetryState.persistenceFailed` at most once per process run through a narrow reliability path that does not depend on the failed store. This in-memory cap intentionally resets on a later process launch. Do not emit it when the user has opted out, and do not attach error text, paths, counters, or failed store contents.

### In-progress live-session checkpoint

Persist a minimal in-progress live-session checkpoint in this separate store so ordinary process termination does not split or lose a game. The checkpoint may contain only:

- selected team UUID;
- first and latest qualifying-cue times;
- the local set of distinct player UUIDs involved;
- qualifying-cue count and whether the three-minute-gap condition has occurred;
- latest meaningful-live-activity time;
- buffered feature, recovery-path, and complete-failure combinations; and
- the set of per-game events already emitted so resume cannot duplicate them.

Resume the checkpoint only when the same team still exists and remains selected, the latest activity is no more than 60 minutes old, the checkpoint schema is valid, and the saved time is not in the future. Use monotonic time for in-process expiry and wall-clock time only for conservative cross-launch validation.

Clear the in-progress checkpoint on timeout, selected-team change, manual app-state restore, missing team, invalid checkpoint data, or suspicious clock movement. Clearing an in-progress checkpoint must not erase historical milestones, rating attempts, or prior probable-game dates. Temporary team/player UUIDs in the checkpoint are local-only and must never be transmitted or included in Roll Call-owned exports, backups, Recently Deleted, or support bundles.

### Analytics-disabled behavior

The telemetry/rating store continues local state needed for product behavior while analytics is disabled, especially probable-game and rating eligibility state. It must not enqueue Roll Call-defined telemetry during that period.

When a one-time or threshold milestone is crossed while analytics is disabled, record it locally as suppressed/consumed without transmission. Re-enabling analytics does not make it eligible again. Future thresholds not crossed during the disabled period may still emit when crossed after re-enabling.

This applies to playback-depth and probable-game milestones, retention milestones, per-team and per-install first-use flags, first-setting-change flags, rating events, and other de-duplicated telemetry. Events already handed to the official SDK before opt-out remain governed by the accepted SDK cache behavior in section 1.4.

The following state exists only to decide when/what to emit and should not itself be transmitted as raw data:

- First telemetry-observed launch date/time and enrollment cohort
- Analytics enabled/disabled state
- Which once-per-install milestones have already been emitted
- Which once-per-team milestones have already been emitted
- Local total successful player-playback count
- Local probable-game count
- Local set/history sufficient to enforce distinct-calendar-date probable-game milestones
- Current live analytics-session state
- Current live analytics-session first/last qualifying cue times
- Current live analytics-session distinct-player count
- Current live analytics-session cue count
- Current live analytics-session inter-cue gap information
- Current live analytics-session feature-use flags
- Current live analytics-session recovery-path counts by failed component, source family, outcome, and fixed reason
- Current live analytics-session complete-failure counts by source family and fixed reason
- Local retention milestones already emitted
- Local rating telemetry/policy state needed to avoid duplicate events or repeated automatic prompts
- Local setting-first-change flags

### Crash-consistent event ordering

For every one-time, threshold, per-team, per-game, or otherwise de-duplicated signal, update and successfully persist the consumed/emitted state before enqueueing the event with the SDK. A termination between persistence and SDK enqueue may lose the signal, but must not allow it to emit twice after restart. This explicit false-negative bias does not apply to raw, intentionally repeatable action/failure signals that have no de-duplication state.

The existing-install baseline follows the same ordering: persist the complete baseline de-duplication result before enqueueing baseline events. If termination occurs after that persistence but before every baseline event is enqueued, do not reconstruct the missing events on the next launch.

Automatic rating presentation uses a durable two-phase reservation rather than consuming an attempt when presentation is merely scheduled:

1. Persist a `pendingPresentation` record before assigning the custom rating sheet.
2. The reservation alone does not increment the automatic attempt count or emit `rating.sheetShown`.
3. When the sheet content actually appears, durably convert the reservation into the consumed attempt and cooldown anchor, then emit `rating.sheetShown`.
4. If presentation is cleanly cancelled before appearance, durably clear the reservation without consuming the opportunity.
5. If the app later launches with an unresolved reservation, conservatively convert it to a consumed automatic opportunity and cooldown anchored to the reservation time, but do not emit `rating.sheetShown` because appearance was never confirmed.

This recovery rule may consume an automatic opportunity that was never visible if termination occurred between reservation and appearance. That accepted false negative is preferable to presenting an extra automatic rating ask. Apply an equivalent durable shown/cooldown transition to a manual sheet, without consuming an automatic attempt; analytics-disabled behavior may suppress its signal but must not suppress its local cooldown effect.

Exact timestamps should stay local unless required for ordinary TelemetryDeck transport metadata.

---

# 4. Live analytics session and probable-game heuristic

## 4.1 Live analytics session

For telemetry purposes, **Game Day and Clips are one live-use context**.

Moving between Game Day and Clips does not create a new live session.

The analytics session is deliberately separate from Roll Call's existing team-session, playback-session, and rating-visit concepts.

A live analytics session survives ordinary movement between Game Day and Clips and temporary backgrounding or device locking. Backgrounding or locking alone does not end the session.

The session expires after **60 consecutive minutes without meaningful live activity**. The timeout is measured from the latest qualifying live activity, including time spent in the background. Implementation should use monotonic elapsed time rather than wall-clock subtraction for this inactivity decision.

If the process terminates, apply the checkpoint policy in section 3 and resume only after its conservative cross-launch checks pass.

Only these actions start or refresh the inactivity clock:

- a qualifying player cue;
- a confirmed audio start from Clips; or
- an actual lineup-position change through next, previous, or direct selection.

Merely entering Game Day or Clips, selecting a team, opening controls, changing ordinary settings, and failed, cancelled, stopped, or debounced playback do not start or refresh the session. Clip playback and lineup movement can maintain a live session but cannot satisfy the qualifying-player-cue requirements for probable-game qualification.

A live analytics session belongs to exactly one selected team. Selecting a different team immediately ends the current analytics session. Returning to the prior team does not resume its ended session. Merely selecting a team does not begin a new session; a new session begins only when meaningful live activity occurs for that team.

This hard boundary prevents cue counts, distinct-player counts, feature-use flags, and team properties from being combined across teams. An accidental team change may therefore cause a false negative, which is preferable to qualifying a mixed-team session.

### Qualifying player cue

A **qualifying player cue** is one user-initiated player request from Game Day for which the playback engine confirms that at least one requested audio component started playback.

- The Game Day hero action and direct player-tile actions count equally.
- A confirmed recorded-announcement start qualifies even if a subsequent song component fails. The later failure is recorded separately when applicable.
- A confirmed intentional Small Cheer and a confirmed recovery Small Cheer both qualify once, while retaining distinct playback-outcome classifications.
- Re-tap-to-stop, debounce rejection, cancellation, a stale playback request, and merely scheduling asynchronous playback do not qualify.
- Clip playback never creates a qualifying player cue.
- "Started playback" is an engine-observable execution result. It does not claim that sound was audible to the user.

The playback layer must return or publish a structured, request-correlated result rather than treating every non-throwing playback call as success. Adapter-specific confirmation must honor synchronous start results such as `AVAudioPlayer.play()` returning `false` and must not report an asynchronous component as started before the relevant playback adapter confirms it.

## 4.2 Probable game v1

Roll Call cannot know with certainty whether the user is physically at a real game without collecting information we do not want. Therefore, the product uses a conservative local heuristic.

A live analytics session becomes a **probable game** when all of the following are true:

1. At least **4 successful player cues** have occurred.
2. At least **3 distinct players** were involved.
3. At least **15 minutes** elapsed between the first and latest qualifying player cue.
4. At least one gap between qualifying player cues was **3 minutes or longer**.

Use inclusive boundaries: the elapsed-span requirement is satisfied at `>= 15 minutes`, and the inter-cue-gap requirement is satisfied at `>= 3 minutes`.

The 15-minute span is intentional. Ten minutes would recognize some real games sooner, but it would also be easier to satisfy during a deliberate rehearsal involving three players, a short adjustment pause, and one repeated cue. Because probable-game dates also govern automatic rating eligibility, avoiding false qualification is more important than recognizing a real game five minutes earlier. A fast real game can still qualify on a later cue after the 15-minute boundary.

Important interpretation rules:

- Game Day and Clips activity belong to the same live session.
- Qualifying cues and distinct-player counts never combine across selected teams.
- Clips activity alone cannot qualify a probable game.
- A player cue that starts either the intentional Small Cheer no-media safety behavior or the recovery Small Cheer fallback counts as a successful player cue.
- Qualification is calculated locally.
- Player identity, cue timing details, and the cue sequence are never transmitted.
- False negatives are preferable to false positives.
- Emit `game.probable` for every qualified probable-game session, including multiple qualified sessions on the same date.
- Repeat-game milestones and automatic-rating eligibility count at most one probable-game date per local calendar date. A doubleheader or tournament day may therefore produce multiple `game.probable` events while advancing those date-based counters only once.
- Freeze a session's probable-game date to the device's local calendar date when the session first qualifies. Later timezone or clock changes must not reclassify that qualified session.

---

# 5. Signal dictionary

## 5.1 Retention

The first launch observed after telemetry support is available establishes a local telemetry-enrollment baseline for every installation. It does not emit a retention milestone immediately. This includes installations that already used Roll Call before telemetry shipped.

A retention milestone emits on the first later app activation at or beyond its elapsed-day threshold. A qualifying activation may be a fresh process launch or the app becoming active after being inactive/backgrounded; iOS process termination is not required. Do not emit merely because a timer crosses the threshold while Roll Call remains continuously active. A brief genuine foreground activation qualifies even if no later feature action occurs.

Every retention milestone carries `enrollmentCohort = newInstall | existingInstall`, determined once when the telemetry store is created. A launch with existing or recovered prior Roll Call state uses `existingInstall`; a genuinely fresh state uses `newInstall`.

These signals measure return after telemetry enrollment, not necessarily time since App Store installation. The existing-install cohort has survivorship bias because it includes only prior users who launched after the telemetry update; it must not be compared directly with new-install retention. Apple App Store Connect remains authoritative for platform install-retention reporting.

### `retention.day1`
**Granularity:** Once per installation  
**Meaning:** Roll Call was launched again at least 1 day after its first telemetry-observed launch.  
**Question answered:** Did the enrolled app state return at all?  
**Properties:** `enrollmentCohort = newInstall | existingInstall`  
**Caveat:** Does not prove continuous installation and is not necessarily measured from App Store installation.

### `retention.day7`
Same semantics as above at 7 days.

### `retention.day30`
Same semantics as above at 30 days.

### `retention.day90`
Same semantics as above at 90 days.

### `retention.day180`
Same semantics as above at 180 days. Important because Roll Call use may be seasonal.

### `retention.day365`
Same semantics as above at 365 days. Important for year-over-year/seasonal return.

---

## 5.2 Onboarding and initial activation

### `onboarding.started`
**Granularity:** Once per installation  
**Meaning:** User moved past the initial welcome/start action into setup.  
**Question answered:** How many installs meaningfully begin setup?

### `onboarding.completed`
**Granularity:** Once per installation  
**Meaning:** Roll Call's existing onboarding completion state was reached.  
**Question answered:** How many users make it through guided setup?  
**Caveat:** Completion does not mean the team is fully personalized or fully media-ready.

### `onboarding.importPathUsed`
**Granularity:** Once per installation  
**Meaning:** Initial onboarding used the `.rollcall` import path.  
**Question answered:** Is package-based setup a meaningful onboarding path?

### `onboarding.cheerFallbackChosen`
**Granularity:** Once per installation  
**Meaning:** User explicitly chose the onboarding option to proceed using the built-in crowd-cheer/no-media path.  
**Question answered:** How often do users intentionally defer media setup?  
**Caveat:** This does not mean Small Cheer was permanently assigned to the player.

---

## 5.3 Roster/team activation milestones

### `roster.playerCount.3`
**Granularity:** Once per installation  
**Meaning:** At least one active team reached 3 players.  
**Question answered:** Did the user move beyond a minimal one-player/test roster?

### `roster.playerCount.5`
Same semantics at 5 players.

### `roster.playerCount.10`
Same semantics at 10 players.

### `roster.playerCount.15`
Same semantics at 15 players.

Exact roster size is not transmitted.

### `teams.activeCount.2`
**Granularity:** Once per installation  
**Meaning:** Roll Call reached 2 active teams through creation, duplication, import, or restore.  
**Question answered:** Is Roll Call used as a multi-team product?

### `teams.activeCount.3`
Same semantics at 3 active teams.

### `team.duplicated`
**Granularity:** First use per installation  
**Meaning:** User duplicated a team using Roll Call's duplication workflow.  
**Question answered:** Is team duplication a meaningful season/team workflow?

### `team.personalized`
**Granularity:** Once per installation  
**V1 definition:** At least one team has at least 3 present players and at least 75% of those present players have personalized audio, where personalized audio means a user-selected song and/or recorded announcement. Use ceiling arithmetic for the required personalized-player count: 3 present requires 3 personalized, 4 requires 3, 5 requires 4, and 9 requires 7. Automatic Small Cheer fallback does not count. Players marked out are excluded from both numerator and denominator.  
**Question answered:** Did the user move from basic setup to a meaningfully personalized team?  
**Caveat:** Temporarily marking unpersonalized players out can allow the active lineup to qualify. This is intentional because the milestone describes the lineup the coach is preparing to use rather than requiring inactive players to suppress activation.

---

## 5.4 Player personalization

### `playerPhoto.firstAdded`
**Granularity:** Once per installation  
**Meaning:** A player photo was added for the first time.  
**Question answered:** Is player-photo personalization used?

### `announcement.firstRecorded`
**Granularity:** Once per installation  
**Meaning:** A recorded Announcement Cue was saved for the first time.  
**Question answered:** Is the recorded-announcement feature adopted?

Pronunciation overrides are not planned telemetry.

---

## 5.5 Media assignment/import adoption

### `media.firstAssigned.musicLibrary`
**Granularity:** Once per installation  
**Meaning:** First player/media assignment whose source is the user's Music Library.  
**Question answered:** Is Music Library assignment used?

### `media.firstAssigned.appleMusicCatalog`
**Granularity:** Once per installation  
**Meaning:** First player/media assignment sourced from Apple Music catalog/search rather than the local Music Library path.  
**Question answered:** Is catalog search/assignment used?

### `media.firstAssigned.importedLocal`
**Granularity:** Once per installation  
**Meaning:** First player/media assignment from imported local audio/video.  
**Question answered:** Is local imported media part of real setup workflows?

### `media.clipReuse.firstUsed`
**Granularity:** Once per installation  
**Meaning:** User first assigned an existing Roll Call clip to a player through the clip-reuse workflow.  
**Question answered:** Is clip reuse as a player source meaningful?

### `media.import.firstAudio`
**Granularity:** Once per installation  
**Meaning:** First imported audio file.  
**Question answered:** Is direct audio import used?

### `media.import.firstVideo`
**Granularity:** Once per installation  
**Meaning:** First imported video file from which Roll Call extracts audio.  
**Question answered:** Is video-import support worth its additional complexity?

---

## 5.6 Trim/default behavior

### `trim.preferredLengthFirstChanged`
**Granularity:** Once per installation  
**Meaning:** User first changed the remembered preferred clip length away from the default 12 seconds.  
**Properties:** `newLength = 6 | 8 | 10 | 15 | customShorterThan12 | customLongerThan12`  
**Question answered:** Is the 12-second default appropriate?

Do not emit every trim edit or exact trim start position.

---

## 5.7 Team accent

### `teamAccent.firstChanged`
**Granularity:** Once per team  
**Meaning:** The team accent was first changed from its initial/default value.  
**Properties:** `newAccent = orange | red | gold | green | blue | purple | gray | black`  
**Question answered:** Do users actively customize team identity, and where do they go from the default?

Do not emit every picker interaction.

The current accent is also attached to the probable-game event so live-use accent prevalence can be analyzed separately from initial customization.

---

## 5.8 Player Cards and smart framing

### `playerCard.opened`
**Granularity:** Raw preview entry  
**Meaning:** The user opened the full Player Card preview from a player screen.  
**Properties:** None in schema v1.  
**Does not mean:** The card finished rendering, was shared, or was saved anywhere.

### `playerCard.generated`
**Granularity:** Raw successful on-demand render  
**Meaning:** Roll Call produced the complete 1200-by-1500 card image needed by the preview. It may fire again when a framing or draft-content change causes another render.  
**Properties:** None in schema v1.  
**Does not mean:** The user shared or saved the result.

### `playerCard.generationFailed`
**Granularity:** Raw unexpected render failure  
**Properties:** `reason = missingAsset | unreadableImage | encodingFailed | unknown`  
**Meaning:** The complete card image could not be produced. Missing optional player data and the intentional no-photo fallback are successful renders, not failures. Never attach paths, filenames, image details, player/team/music content, or underlying error text.

### `playerCard.shareInitiated`
**Granularity:** Raw action  
**Meaning:** Roll Call presented the system Share Sheet for a generated card.  
**Properties:** None in schema v1.  
**Does not mean:** The user selected a destination, completed a share, or saved the image. Roll Call does not inspect the destination.

### `playerPhoto.profileFramingAdjusted`
**Granularity:** Raw committed adjustment  
**Meaning:** A manual profile-framing change was included in the player's successful Save transaction.  
**Properties:** None in schema v1.  
**Does not mean:** The automatic framing was objectively wrong. A cancelled draft does not fire this event.

### `playerPhoto.cardFramingAdjusted`
**Granularity:** Raw committed adjustment  
**Meaning:** A manual Player Card framing change was included in the player's successful Save transaction.  
**Properties:** None in schema v1.  
**Does not mean:** The card was shared. A cancelled draft does not fire this event.

### `playerPhoto.detectionCompleted`
**Granularity:** Raw result for a newly selected photo after the player is saved  
**Properties:** `detection = faceAndPerson | multiplePeople | faceOnly | personOnly | noUsableDetection`  
**Meaning:** The single on-device Vision analysis used to seed both framings produced the indicated coarse observation class.  
**Does not mean:** Identity recognition, biometric processing, recognition quality, or that the selected subject was correct. Roll Call transmits no photo, observation geometry, confidence, person count, face traits, or content-derived identifier. A cancelled photo draft does not fire this event.

---

# 6. Live-use signals

## 6.1 First live use

### `live.entered`
**Granularity:** Once per installation  
**Meaning:** User entered Game Day or Clips for the first time.  
**Question answered:** Did setup ever reach the live surfaces?

### `playerPlayback.firstSuccessful`
**Granularity:** Once per installation  
**Meaning:** First successful player-cue playback, including intentional no-media Small Cheer safety behavior.  
**Question answered:** Did the user actually trigger a player cue?

---

## 6.2 Probable-game event

### `game.probable`
**Granularity:** Once per qualified probable-game session  
**Meaning:** The local session satisfied Probable Game v1.  
**Question answered:** Approximately how many real-game-like sessions are happening?  
**Properties:**
- `accent = orange | red | gold | green | blue | purple | gray | black`
- `volumeAutomation = on | off`
- `keepScreenAwake = on | off`
- `darkLiveScreens = on | off`
- `gameHeuristicVersion`

Do not transmit player identities, exact cue count, exact timestamps, or exact session duration.

These three setting properties describe consequential live audio, screen-reliability, and visibility behavior at the moment a session qualifies. Do not attach explicit-filter, haptics, or lineup-hint state to probable-game events.

---

## 6.3 Probable-game milestones

Each milestone is once per installation and requires distinct-calendar-date probable games.

### `gameMilestone.second`
Reached second probable-game date.

### `gameMilestone.fifth`
Reached fifth probable-game date.

### `gameMilestone.tenth`
Reached tenth probable-game date.

### `gameMilestone.twentyFifth`
Reached 25 probable-game dates.

### `gameMilestone.fiftieth`
Reached 50 probable-game dates.

**Question answered:** How many installs become repeat real-game users, and how deep does real usage go?

---

## 6.4 Player-playback depth milestones

Maintain a local cumulative count of successful player-cue playbacks.

Retain all six thresholds. Although probable-game dates are the stronger measure of recurring live use, this finer lifetime ladder provides a low-volume depth curve independent of the probable-game heuristic; each threshold can emit only once per installation.

### `playerPlayback.count.10`
Once per installation at 10 successful player playbacks.

### `playerPlayback.count.50`

### `playerPlayback.count.100`

### `playerPlayback.count.250`

### `playerPlayback.count.500`

### `playerPlayback.count.1000`

**Question answered:** How deep does player-cue usage become, independently of the probable-game heuristic?

Do not emit every player playback.

---

## 6.5 Lineup use during probable games

### `lineup.progressionUsedInProbableGame`
**Granularity:** At most once per probable game  
**Meaning:** User used lineup progression controls (Next, Prev, or On Deck advancement) during that session.  
**Question answered:** Is Roll Call actually being used to manage batting order/live progression?

### `lineup.editedInProbableGame`
**Granularity:** At most once per probable game  
**Meaning:** The live lineup was actually changed during the session. Merely opening the editor does not count.  
**Question answered:** Do users alter lineup/presence/order during games?

No sub-event is planned for individual reorder/sort/presence actions.

---

## 6.6 Announcer/playback modes

### `game.playbackModeUsed`
**Granularity:** At most once per distinct mode per probable game  
**Meaning:** A Game Day playback mode was actually used during the probable game.  
**Properties:** `mode = announcerOnly | announcerAndSong | songOnly`  
**Question answered:** Which central playback modes are actually used during games?

A single probable game may emit this once for more than one mode if the user genuinely uses multiple modes.

### `announcerMode.firstChanged`
**Granularity:** Once per team  
**Meaning:** User first changed the per-team announcer mode away from its initial/default value.  
**Properties:** `newMode = announcerOnly | announcerAndSong | songOnly`  
**Question answered:** Is the default Announcer+Song mode routinely rejected?

### `announcement.playedInProbableGame`
**Granularity:** At most once per probable game  
**Meaning:** A recorded Announcement Cue actually played during the probable game.  
**Question answered:** Do recorded announcements survive from setup into real live use?

---

## 6.7 Live media source use

### `media.sourceUsedInProbableGame`
**Granularity:** At most once per source family per probable game  
**Meaning:** At least one successful live player playback used that source family during the probable game.  
**Properties:** `sourceFamily = musicLibrary | appleMusicCatalog | appleMusicPreview | generatedLocal | importedLocal | builtinIntentional`  
**Question answered:** Which media paths matter in actual game use?

Definitions:

- `musicLibrary`: the playback engine actually started the user's Music Library item path.
- `appleMusicCatalog`: the playback engine actually started full-song Apple Music catalog playback.
- `appleMusicPreview`: the playback engine actually started the remote preview path.
- `generatedLocal`: the playback engine used a prepared app-owned local clip generated from source-backed media.
- `importedLocal`: the playback engine used app-owned audio derived directly from a user import.
- `builtinIntentional`: built-in Small Cheer used because the selected mode/player had no configured required media and Roll Call intentionally avoided silence.

`builtinIntentional` is **not a reliability failure**.

Transmit no reason subcategory for `builtinIntentional` in telemetry schema v1. The playback plan/result may retain fixed local reasons such as no song assigned or no announcement available for the selected mode so behavior can be tested and diagnosed, but those reasons are not telemetry properties. Add a transmitted reason only in a later schema if a concrete product decision requires it.

Classify the source from the structured playback-engine result at the moment the relevant adapter confirms playback start, not from assignment metadata. A Music Library-origin assignment that cannot resolve its library item and instead plays through catalog or preview is classified by the actual route used. Assignment telemetry separately describes how media entered the app.

---

## 6.8 Clips

### `clips.builtinUsedInProbableGame`
**Granularity:** At most once per probable game  
**Meaning:** At least one built-in Clips sound effect was intentionally played during the probable game.  
**Question answered:** Is the built-in live soundboard used?

### `clips.customUsedInProbableGame`
**Granularity:** At most once per probable game  
**Meaning:** At least one user-created Custom Clip was played during the probable game.  
**Question answered:** Are custom clips used live?

### `clips.firstCustomCreated`
**Granularity:** Once per installation  
**Meaning:** First Custom Clip was created.  
**Question answered:** Is custom-clip creation adopted?

Do not track which built-in sound effect was used.

---

## 6.9 Quick Game Day

Quick Game Day telemetry forms a coarse `invoked -> targetResolved or fallback -> reached` funnel. It does not create a second authority for Game Day readiness, playback, or probable-game telemetry.

### `quickGameDay.invoked`
**Granularity:** Raw invocation received by the app  
**Properties:** `source = systemControl | appIntent | unknownSystem | inApp`  
**Meaning:** A Quick Game Day request reached Roll Call. `systemControl` covers the shared WidgetKit control architecture and does not distinguish Control Center, Lock Screen, or Action Button. `appIntent` covers the shared App Intent path and does not distinguish Shortcuts, Siri, Spotlight, or Action Button when the system supplies no reliable origin. Use `unknownSystem` rather than guessing.  
**Does not mean:** A target existed or Game Day was reached.

### `quickGameDay.targetResolved`
**Granularity:** Raw successful target resolution  
**Properties:** `target = explicitTeam | rememberedTeam`  
**Meaning:** The request resolved either an optional team selected in Shortcuts or the locally remembered team most recently entered intentionally in Game Day.  
**Does not mean:** The team is ready or that playback began.

### `quickGameDay.reached`
**Granularity:** Raw completed app navigation  
**Properties:** None in schema v1.  
**Meaning:** Roll Call applied the resolved team and routed to its existing Game Day surface.  
**Does not mean:** Readiness passed, audio played, or a probable game occurred.

### `quickGameDay.fallback`
**Granularity:** Raw expected fallback  
**Properties:** `reason = noTeams | noRememberedTeam | rememberedTeamMissing | explicitTeamMissing`  
**Meaning:** Roll Call could not resolve the requested target and returned to its normal onboarding/team-selection flow. A missing remembered team is cleared from local app state.  
**Does not mean:** A technical failure or data loss.

### `quickGameDay.failed`
**Granularity:** Raw unexpected technical failure  
**Properties:** `reason = operationFailed | unknown`  
**Meaning:** Quick Game Day could not complete for an unexpected technical reason after expected target fallbacks were excluded. Never attach errors, identifiers, team names, URLs, or route payloads.

---

# 7. Import/export/sharing/recovery adoption

## 7.1 CSV import

### `csvImport.firstUsed`
**Granularity:** Once per installation  
**Meaning:** First successful roster CSV import.  
**Properties:** `rowCountBucket = 1-5 | 6-10 | 11-20 | 21+`  
**Question answered:** Is CSV import used for real rosters or mostly tiny/test imports?

---

## 7.2 `.rollcall` packages

### `package.firstExport`
**Granularity:** Once per installation  
**Meaning:** First `.rollcall` package export for which the system share activity reports `completed == true`.  
**Question answered:** Is team package sharing/backup used?

Creating the temporary package archive is preparation, not a successful export. Add a completion coordinator to the `UIActivityViewController` wrapper and count only a completed activity. Cancellation does not count. Do not transmit the chosen activity type, destination, filename, recipient, or any share-sheet metadata. A completed activity does not prove that another device received or imported the package.

### `package.firstImport`
**Granularity:** Once per installation  
**Meaning:** First successful `.rollcall` import.  
**Properties:** `hadMissingMedia = true | false`  
**Question answered:** Is package import used, and how often does it arrive partially degraded?

### `package.exportCount.5`
Once per installation at the fifth system-share activity that reports completion for a `.rollcall` package.

### `package.importCount.5`
Once per installation at fifth successful import.

No package contents, team counts, names, device labels, or asset metadata are transmitted.

---

## 7.3 Apple Music playlist sync

The current app exposes managed Apple Music playlist creation as a normal Teams feature. Do not gate these telemetry events on the retained `appleMusicTeamPlaylistSyncEnabled` experimental-state field; current source and the approved product decision supersede that stale field. Developer/testing controls are not production telemetry.

### `playlistSync.firstUsed`
**Granularity:** Once per installation  
**Meaning:** First successful use of the team Apple Music playlist sync/convenience feature.  
**Question answered:** Is this feature worth maintaining?

### `playlistSync.usedInMultipleTeams`
**Granularity:** Once per installation  
**Meaning:** Playlist sync has been successfully used for more than one team.  
**Question answered:** Is playlist sync a repeat/multi-team workflow?

---

## 7.4 Backup and recovery

### `backup.manualCreated`
**Granularity:** First successful manual action per installation  
**Meaning:** User successfully created a manual backup snapshot for the first time.  
**Question answered:** Is manual backup used?

Automatic defensive/pre-operation backups are not transmitted as adoption events.

### `backup.restored`
**Granularity:** First successful restore per installation  
**Meaning:** User successfully restored a snapshot for the first time.

### `recentlyDeleted.restored`
**Granularity:** First successful restore per installation  
**Meaning:** User successfully restored an item from Recently Deleted for the first time.

Do not transmit repeated backup/recovery actions, permanent deletion, item type, item name, or item content in schema v1. Failed recovery attempts belong in fixed reliability telemetry rather than adoption counts.

---

# 8. Readiness and repair adoption

### `readiness.firstOpened`
**Granularity:** Once per installation  
**Meaning:** User opened Readiness for the first time.  
**Question answered:** Is the Readiness feature actually used?

### `repair.firstNeeded`
**Granularity:** Once per category per installation  
**Meaning:** Roll Call presented a repair-needed condition to the user in Readiness or during an attempted action that exposed a repair path. Passive/background detection alone does not qualify.  
**Properties:** `category = playerMedia | announcement | customClip | appleMusicAccess | importedPackageMedia`  
**Question answered:** Which recoverable broken states real users encounter?

### `repair.firstCompleted`
**Granularity:** Once per category per installation  
**Meaning:** After an explicit repair attempt, Roll Call revalidated that the same coarse repair category was resolved. Deletion, replacement import, or incidental disappearance of the condition does not qualify.  
**Question answered:** Are users able to recover from those states?

Do not transmit every Readiness check or warning. Do not transmit affected item identity, filename, song information, or exact category counts.

---

# 9. Settings/default telemetry

For each normal global setting, emit only the first committed change from its initial default for that installation.

### `setting.explicitFilter.firstChanged`
**Default:** On  
**Properties:** `newValue = on | off`

### `setting.volumeAutomation.firstChanged`
**Default:** Off  
**Properties:** `newValue = on | off`

### `setting.darkLiveScreens.firstChanged`
**Default:** On  
**Properties:** `newValue = on | off`

### `setting.keepScreenAwake.firstChanged`
**Default:** Off  
**Properties:** `newValue = on | off`

**Question answered for all:** Are Roll Call's defaults aligned with what users want?

Do not emit every toggle or a periodic full settings snapshot.

### `analytics.preferenceChanged`
**Granularity:** Every committed user change of the Anonymous Usage Analytics switch  
**Properties:** `newValue = on | off`  
**Meaning:** The user explicitly enabled or disabled anonymous usage analytics. The `off` transition is the only event permitted through the dedicated shutdown path after the ordinary recording gate closes.  
**Question answered:** How many preference transitions occur, and what share of observed anonymous vendor/device identities explicitly opts out or later opts back in?

Do not divide these events by Apple installation counts or describe the result as a share of installations; TelemetryDeck identity and Apple installation metrics cannot be joined reliably.

Do not attach any prior event history, reason, screen path, or other property to this signal.

---

# 10. Rating flow

## 10.1 Planned rating policy v1

Replace the existing 10/20 qualifying-Game-Day-visit policy with probable-game-based eligibility:

- First automatic rating sheet opportunity after **2 probable games on different dates** and at least **7 days since enrollment in this policy**
- Second automatic opportunity after **5 probable games on different dates** and at least **30 days since the first rating sheet was actually shown**
- Maximum **2 automatic asks**
- Never ask after the first probable game
- Preserve existing UI-safety gating so the sheet is not presented during onboarding, Game Day/Clips, blocking/risky UI, etc.
- Eligibility may become pending before every condition is satisfied, but presentation waits until the game-count threshold, elapsed-time threshold, and safe-UI conditions are all satisfied.
- Measure the inter-prompt cooldown from confirmed `rating.sheetShown`, not from when eligibility was earned or presentation was scheduled.
- Any actual display of the custom rating sheet, including a manual display, resets the 30-day presentation cooldown. A manual display does not consume an automatic attempt.
- Selecting Rate Roll Call, Email Me Instead, or the support/contribution path permanently suppresses all future automatic rating sheets for that installation. The manual Rate Roll Call path may remain available.
- Selecting Not Now, tapping Done, or dismissing the sheet interactively does not permanently suppress the remaining automatic opportunity.
- Present and consume automatic rating opportunities only when the app is running as an App Store build. TestFlight and developer builds still calculate eligibility and may emit test-mode `rating.becameEligible`, but ordinary use must not present the automatic sheet or consume an attempt.
- Exercise non-App-Store automatic presentation through deterministic tests or an explicit development-only hook that does not mutate the user's production anti-nag history. The manual production rating path is a separate user-initiated action and is not reclassified as an automatic opportunity.

The elapsed-time safeguards are intentional. Two qualified game dates provide meaningful evidence of value, while the seven-day minimum avoids an unusually compressed first ask. Five game dates can occur quickly during a tournament or dense schedule; the 30-day presentation cooldown prevents both automatic asks from appearing within the same short burst of use.

### Migration from the legacy 10/20 visit policy

Migrate the existing rating state once into the separate versioned telemetry/rating store:

- Preserve the legacy `automaticPromptAttemptCount` exactly; every prior automatic attempt remains consumed.
- Do not translate `successfulGameDaySessionCount` into probable games. The legacy counter represented qualifying Game Day visits, not the probable-game v1 heuristic.
- Discard legacy in-progress Game Day visit flags and start the new distinct-date probable-game count at zero.
- With zero prior attempts, the first opportunity requires 2 new probable-game dates and 7 days from policy migration.
- With one prior attempt, only the second opportunity remains; it requires 5 new probable-game dates and 30 days from policy migration. The migration date is the conservative cooldown anchor because legacy state has no reliable sheet-presentation timestamp.
- With two prior attempts, no further automatic rating sheets are permitted.
- Crossing a legacy 10/20 threshold must never cause an immediate post-update rating sheet.

This intentionally makes some experienced users wait longer rather than inventing historical probable games or increasing prompt pressure after an update.

This policy is a planned product change and must be validated by Codex against current behavior/tests before implementation.

## 10.2 Rating signals

### `rating.becameEligible`
**Granularity:** Raw policy transition, normally at most twice automatically  
**Meaning:** Both the distinct-probable-game-date threshold and the elapsed-time threshold for an automatic opportunity became satisfied. Safe-UI presentation conditions are not part of this transition.  
**Properties:**
- `qualifiedGameBucket = 0 | 1 | 2-4 | 5-9 | 10+`
- `daysSincePolicyEnrollmentBucket = <7 | 7-13 | 14-29 | 30-89 | 90+`
- `enrollmentCohort = newInstall | existingInstall`
- `automaticAttemptNumber = 1 | 2`
- `ratingPolicyVersion`

Emit once for an opportunity when the second of its two non-UI requirements becomes true: either a qualifying probable-game date satisfies the count after the time requirement was already met, or a later app activation satisfies the time requirement after the game-date count was already met. Do not emit merely when one requirement becomes pending, and do not wait for a safe presentation surface.

### `rating.sheetShown`
**Granularity:** Every actual display of Roll Call's custom rating sheet  
**Meaning:** The user definitely saw Roll Call's “Enjoying Roll Call?” sheet.  
**Properties:**
- `source = automatic | manual`
- `qualifiedGameBucket`
- `daysSincePolicyEnrollmentBucket`
- `enrollmentCohort = newInstall | existingInstall`
- `automaticAttemptNumber` when applicable
- `ratingPolicyVersion`

Record `rating.sheetShown` and consume an automatic attempt from one idempotent presentation callback when the sheet content actually appears. Scheduling or assigning the sheet presentation state does not count. This requires changing the current ordering, which marks an automatic attempt before assigning the sheet presentation.

### `rating.rateSelected`
**Granularity:** Raw user action  
**Meaning:** User selected the action that opens the App Store review page. This permanently suppresses future automatic rating sheets.

### `rating.feedbackSelected`
**Granularity:** Raw user action  
**Meaning:** User chose the email-feedback path from the rating sheet. This permanently suppresses future automatic rating sheets.

### `rating.supportSelected`
**Granularity:** Raw user action  
**Meaning:** User chose the support/contribution path from the rating sheet. This permanently suppresses future automatic rating sheets.

### `rating.notNowSelected`
**Granularity:** Raw user action  
**Meaning:** User explicitly dismissed the rating sheet with Not Now. This leaves the later automatic opportunity available subject to the full game-count, cooldown, and safe-presentation policy.

Done and interactive sheet dismissal are intentionally not separate telemetry events. They have the same policy effect as Not Now but do not claim that the explicit Not Now button was selected.

Important: Roll Call's production rating UI is currently a custom sheet that opens the App Store review page. Do not describe `rating.sheetShown` as Apple's native StoreKit review prompt unless implementation changes.

---

# 11. Support telemetry

Support payment/contribution telemetry is deliberately minimal because App Store/StoreKit financial reporting already tells the developer whether money was received. `rating.supportSelected` records the only current production path into Support Roll Call; do not emit a duplicate support-screen-opened event.

No planned TelemetryDeck signals for:

- Product/tier selected
- Purchase started
- Purchase completed
- Purchase cancelled
- Purchase pending
- Purchase failure
- Dollar amount
- One-time vs recurring purchase result

---

# 12. Reliability/error telemetry

## 12.1 Intentional safety vs actual recovery

This distinction is mandatory:

### Intentional built-in safety behavior
If the user has not configured the media required by the selected playback mode and Roll Call intentionally uses Small Cheer to avoid silence, this is expected product behavior.

It may contribute to `media.sourceUsedInProbableGame` with `sourceFamily = builtinIntentional`.

It must **not** count as a reliability failure.

Unconfigured optional media that causes Roll Call to execute a supported lower fallback level is also intentional behavior, not a failure. For example, an unconfigured announcement in Announcer+Song mode does not make successful song-only playback a recovery failure.

### Recovery
If Roll Call had configured media/source it intended to use but that component could not actually play and Roll Call successfully started another supported fallback level, that is a recovery and a reliability problem. This includes song-only recovery, intro-only recovery, and built-in-cheer recovery.

---

## 12.2 Recovery-path aggregate

### `game.recoveryPathUsed`
**Granularity:** At most once per failed-component/source-family/recovery-outcome/reason combination per probable game  
**Meaning:** A configured/intended playback component failed and Roll Call recovered by successfully starting another supported fallback level.  
**Properties:**
- `recoveryOutcome = songOnly | introOnly | builtinCheer`
- `failedComponent = announcement | primaryCue`
- `sourceFamily = recordedAnnouncement | musicLibrary | appleMusicCatalog | appleMusicPreview | generatedLocal | importedLocal | builtin | unknown`
- `reason = missingAsset | unreadableAsset | authorization | subscription | sourceUnavailable | startRejected | startTimedOut | playbackError | unknown` where reliably classifiable

**Question answered:** How often does Roll Call have to recover from broken intended playback during real-game-like use, which component/path failed, and which graceful fallback level actually worked?

Do not emit a raw event for every recovery occurrence. Treat this as a binary affected-probable-game signal for each fixed combination. Buffer combinations observed before qualification and emit them when the session qualifies; after qualification, emit a newly observed combination immediately. The structured playback result must correlate asynchronous announcement and primary-cue component outcomes so a delayed primary failure after a successful announcement is classified as `introOnly` rather than swallowed or mislabeled as complete success.

---

## 12.3 Complete playback failure

### `playback.failedCompletely`
**Granularity:** Raw occurrence  
**Meaning:** Intended playback failed and Roll Call could not produce the expected recovery audio.  
**Properties:**
- `sourceFamily = recordedAnnouncement | musicLibrary | appleMusicCatalog | appleMusicPreview | generatedLocal | importedLocal | builtin | unknown`
- `liveContext = gameDay | clips`
- `fallbackAttempted = true | false`
- `reason = missingAsset | unreadableAsset | authorization | subscription | sourceUnavailable | startRejected | startTimedOut | playbackError | unknown`

No raw error strings.

Do not attach `probableGame = true | false` to the immediate event. A live session can qualify later, so `false` at failure time would not mean the session ultimately remained non-probable.

### `game.completePlaybackFailureObserved`
**Granularity:** At most once per source-family/reason combination per probable game  
**Meaning:** The live session contained at least one complete playback failure before or after it satisfied probable-game v1.  
**Properties:**
- `sourceFamily = recordedAnnouncement | musicLibrary | appleMusicCatalog | appleMusicPreview | generatedLocal | importedLocal | builtin | unknown`
- `reason = missingAsset | unreadableAsset | authorization | subscription | sourceUnavailable | startRejected | startTimedOut | playbackError | unknown`

Treat this as a binary affected-probable-game signal for each fixed source/reason combination. Buffer combinations observed before qualification and emit them when the session qualifies; after qualification, emit a newly observed combination immediately.

The immediate and probable-game aggregate events answer different questions. Do not add their counts together: `playback.failedCompletely` counts failure occurrences, while `game.completePlaybackFailureObserved` counts affected probable-game sessions.

---

## 12.4 Import/data failures

### `packageImport.failed`
**Granularity:** Raw failed user action  
**Properties:** `reason = unsupportedVersion | invalidPackage | operationFailed`

The current code can identify `unsupportedImportVersion` and `invalidImport`. It cannot reliably separate corrupt structure, unreadable content, ZIP validation, path-safety rejection, and every underlying I/O error without more typed boundaries; do not infer those finer reasons from localized error text.

### `packageExport.failed`
**Granularity:** Raw failure of a confirmed user-visible team-package export attempt  
**Properties:** None in schema v1.

Emit only when the package-generation operation itself throws after the user confirms export. Do not attach the filename, team identity, package contents, raw/localized error text, or an inferred reason.

### `csvImport.failed`
**Granularity:** Raw failed user action  
**Properties:** `reason = invalidCSV | operationFailed`

The current `invalidCSV` error covers both empty and malformed CSV. Do not claim a separate empty/unreadable reason unless implementation first introduces and tests a real typed distinction.

### `backup.failed`
**Granularity:** Raw failure of a user-visible/manual backup action  
**Properties:** None in schema v1.

### `restore.failed`
**Granularity:** Raw restore failure  
**Properties:** None in schema v1.

### `state.recoveryTriggered`
**Granularity:** Raw occurrence  
**Meaning:** Roll Call detected unreadable/corrupt/unsupported persisted state and entered its defensive recovery path.  
**Properties:** `reason = unsupportedSchema | loadFailure`

The current launch path can identify an unsupported saved-state schema separately, but all other read/decode failures converge through one catch path. Do not claim `corrupt` versus `decodeFailure` without a future typed implementation distinction.

This is high priority: even a single real-world occurrence is worth knowing.

### `telemetryState.recovered`
**Granularity:** Once after a corrupt/unreadable telemetry/rating store is quarantined and its conservative replacement is successfully saved  
**Properties:** None in schema v1.  
**Meaning:** Roll Call safely replaced unusable telemetry/rating history without recreating automatic-rating eligibility or historical milestones.

Do not emit for a newer unsupported schema, because that store must remain untouched and ordinary telemetry stays disabled for the run. Do not emit until replacement persistence succeeds, and never attach decode errors, file contents, paths, or prior telemetry payloads.

### `telemetryState.persistenceFailed`
**Granularity:** At most once per process run while analytics is enabled  
**Properties:** None in schema v1.  
**Meaning:** The separate telemetry/rating store failed to save and Roll Call suspended ordinary telemetry plus automatic rating presentation to prevent duplicate history.

This event uses the narrow in-memory reliability path described in section 3 and is never emitted after an analytics opt-out. It does not imply that core `AppState` persistence failed.

### `state.persistenceFailed`
**Granularity:** Once per continuous app-state persistence-failure episode  
**Meaning:** The app-state persistence layer established that the latest requested canonical snapshot was not durably written and may not survive termination.  
**Properties:** None in schema v1.

Do not instrument the current aggregate `.failed` result without first correcting or enriching its semantics: the writer currently retains an earlier drain error even when a later pending snapshot succeeds. Implementation must distinguish “an intermediate attempt failed” from “the latest requested snapshot is not durable,” and emit this signal only for the latter. Emit on the transition from persistence-healthy/unknown to latest-snapshot-failed. Suppress additional failed latest snapshots until a later confirmed latest-snapshot write resets the local episode flag; do not emit a separate recovery event in schema v1. Never transmit the underlying error description, destination path, state contents, pending cleanup paths, or persistence sequence. This is distinct from `state.recoveryTriggered`, which reports a later launch/read recovery rather than the original write failure.

---

## 12.5 Permission friction

### `musicAccess.denied`
**Granularity:** Once per installation  
**Meaning:** The user attempted a workflow requiring Music access and authorization was denied/restricted.  
**Properties:** `result = denied | restricted` when returned by the framework  
**Question answered:** Is Music permission materially blocking feature adoption?

### `microphoneAccess.denied`
**Granularity:** Once per installation  
**Meaning:** The user attempted to record an announcement and microphone access was denied/restricted.
**Properties:** `result = denied | restricted` when returned by the framework

Do not periodically transmit permission state on launch.

---

# 13. Signals explicitly not planned

Unless future product questions justify them, do not add telemetry for:

- Every app launch
- Every screen view
- Every tap
- Every player cue
- Every clip playback
- Every lineup move
- Every settings toggle
- Settings-screen opens
- About-screen opens
- What's New opens
- Team selection
- Team rename/delete
- Player add/delete as raw events
- Exact roster sizes
- Player numbers
- Team accent picker taps
- Which built-in sound effect was played
- Exact clip trim start/duration beyond the explicit preferred-length signal
- Exact timestamps
- Exact session duration
- Exact cue gaps
- Exact donation/payment values
- Apple Music subscription status
- Apple Music IDs or media metadata
- Full readiness snapshots
- Every readiness warning
- Background media-preparation retry attempts
- Generic crash telemetry duplicated from Apple solely for duplication's sake
- Support-bundle contents
- Developer Tools usage in App Store production telemetry

---

# 14. Interpretation guidance for future analysis

## 14.1 Headline product-health metrics

The most meaningful Roll Call metrics are expected to be:

1. Raw installs/downloads from Apple App Store Connect
2. `onboarding.completed`
3. `team.personalized`
4. First `game.probable`
5. `gameMilestone.second`
6. `gameMilestone.fifth`
7. Higher probable-game milestones
8. App-return retention milestones

At low scale, raw counts are likely more useful than percentages. As usage grows, funnel conversion percentages become progressively more meaningful.

## 14.2 Do not equate these concepts

- **Download** is not the same as Apple-reported installation.
- **Onboarding completed** is not the same as team personalized.
- **Live entered** is not the same as probable game.
- **Player playback successful** is not the same as probable game.
- **Intentional Small Cheer** is not a failure.
- **Recovery fallback** means configured/intended media failed.
- **Probable game** is a heuristic, not proof of physical attendance at a sporting event.
- **Retention Day 30** means the app returned at/after that age, not continuous installation.
- **Rating sheet shown** refers to Roll Call's custom sheet, not necessarily Apple's native review prompt.
- **Rate selected** means the user chose the App Store review action; it does not prove a review was submitted.

## 14.3 Defaults analysis

For settings and team accent:

- The default value will naturally be overrepresented among unchanged users.
- First-change telemetry answers whether people reject the default.
- Probable-game properties answer what values survive into actual live use.
- Do not treat most-common default as proof that it is the most-preferred value.

---

# 15. `/grill-me` review conclusion and implementation gates

The owner decision tree for telemetry schema v1 is closed. The review removed or consolidated signals whose semantics were redundant, corrected signals the current code could not support honestly, added only the missing package-export and app-state-persistence reliability coverage, and found no other current product workflow whose telemetry value justifies expanding v1.

The structured playback result, probable-game state machine/checkpoint, separate telemetry/rating store, existing-install baseline, opt-out transition, and rating reservation are intentional implementation costs required for honest semantics. Do not silently simplify them into view-tap inference, nonthrowing-playback inference, app-state backup data, or pre-presentation rating consumption.

Implementation remains gated on:

- adding the exact pinned SDK and verifying its resolved source/version;
- inventorying actual SDK automatic metadata and generated privacy-report output;
- implementing typed event/property allowlists and non-networking test providers;
- implementing and testing structured request-correlated playback outcomes before game/recovery signals ship;
- implementing the versioned telemetry/rating store, enrollment baseline, crash ordering, corrupt/unsupported recovery, and runtime persistence gate;
- migrating the legacy rating state under section 10.1 and implementing two-phase presentation reservation;
- verifying Test Mode/App Store environment handling and pre-initialization opt-out configuration;
- updating the app privacy manifest, App Store Connect privacy answers, public privacy policy, Settings disclosure, and dependency record; and
- completing focused unit/integration/lifecycle tests plus owner/device acceptance of the rating and Settings surfaces.

These are implementation and release-verification gates, not unresolved owner/product decisions.

---

# 16. Maintenance rule

This document is the living source of truth for Roll Call telemetry.

Whenever implementation or product discussion:

- adds a signal,
- removes a signal,
- renames a signal,
- changes when a signal fires,
- changes a property or bucket,
- changes the probable-game heuristic,
- changes rating eligibility,
- changes privacy behavior,
- or changes the interpretation of an existing signal,

**update this file in the same change.**

Do not allow implementation and this reference to drift.

If code and this document disagree, the discrepancy must be called out and resolved rather than silently assuming one is correct.
