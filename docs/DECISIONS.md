# Decisions

Use this file as a concise decision log for project-specific architectural, behavioral, tooling, and scope decisions.

## 2026-09-07

- Approved: Player photos use one metadata-stripped, orientation-normalized working master bounded to 3000 pixels, plus an independent compact profile derivative and normalized Player Card crop. One on-device Vision pass seeds both framings; manual adjustments remain optional and follow Player Editor Save/Cancel. Existing cropped-only photos remain valid as the available source until replaced.
  Rationale: share graphics need pixels outside the compact crop, but exact original file bytes and metadata add privacy/storage cost without product value. A single analysis pass and nondestructive geometry preserve quality while avoiding repetitive setup.
  Status: approved for 1.3

- Approved: `.rollcall` packages include the new photo master and crop fields additively without raising package schema 9. Older 1.2 importers receive the existing compact profile asset and ignore the new data; a subsequent 1.2 re-export is an accepted lossy downgrade that cannot preserve the 1.3 master or crop geometry.
  Rationale: team ownership and cross-device reframing require the master to travel, while keeping the established manifest contract preserves useful backward import compatibility instead of rejecting a whole team over additive photo capability.
  Status: approved for 1.3

- Approved: 1.3 ships one Player Card composition, the owner-selected Broadcast design, at 1200 by 1500 pixels with on-demand preview/rendering and system sharing. Alternative design studies are review artifacts only; there is no template picker, cache, gallery, or Game Day entry.
  Rationale: one polished design makes the feature visible and shareable without turning Roll Call into a design tool or adding persistent generated-file management.
  Status: approved for 1.3

- Approved: Quick Game Day is a shared navigation request that never starts playback. The default target is updated only by intentional Game Day entry, not ordinary team browsing; an optional App Intent team overrides it. The app remains iOS 17, while an isolated iOS 18 control extension supplies supported Control Center/Lock Screen surfaces and delegates to the same app-owned resolver and existing Game Day state/readiness path.
  Rationale: system access should reduce field friction without creating a second game/playback authority, changing older-device behavior, or arbitrarily choosing teams. Separating the extension keeps modern API availability out of the core app.
  Status: approved for 1.3

## 2026-09-06

- Approved: add privacy-bounded, default-enabled anonymous product telemetry using the official TelemetryDeck Swift SDK pinned initially to 2.14.2 behind a Roll Call-owned typed event/property allowlist. Provide an independent Settings opt-out; do not add an onboarding consent or ATT prompt solely for telemetry; retain the SDK's default IDFV-derived identity, salt, standard metadata, batching, and cache behavior; disclose that a final opt-out transition and already queued events may arrive after opt-out; never transmit team/player/media content or Roll Call-defined identifiers; and separate TestFlight/developer signals with TelemetryDeck Test Mode.
  Rationale: sparse adoption, probable-game, reliability, and retention signals can answer actionable Roll Call product questions that App Store Connect cannot, while the allowlist, content boundary, honest opt-out semantics, conservative local persistence, and explicit privacy disclosures constrain collection.
  Status: approved; detailed schema and firing semantics live in `docs/telemetry/ROLL_CALL_TELEMETRY_SPEC.md`

- Approved: replace the 10/20 qualifying-Game-Day-visit rating policy with probable-game-date eligibility. A probable game requires four confirmed player-cue starts across three distinct players over at least 15 minutes with a three-minute inter-cue gap; automatic rating opportunities require two distinct probable-game dates plus seven days since policy enrollment, then five dates plus 30 days since the first sheet was actually shown, with no more than two automatic asks and the documented conservative legacy migration/two-phase crash recovery.
  Rationale: confirmed probable-game use is stronger evidence of delivered value than entering/leaving Game Day, while distinct dates and elapsed-time safeguards prevent tournaments or compressed testing from making the prompt more eager.
  Status: approved; supersedes the 2026-06-07 10/20-session threshold decision

## 2026-06-21

- Approved: add optional StoreKit support contributions in Settings/About, with one-time consumable support and monthly/yearly auto-renewable support, while keeping every Roll Call feature free and excluding support state from team exports and app backups.
  Rationale: users who want to support maintenance can do so without creating a paywall, account, backend, analytics, or live-use interruption.
  Status: approved

## 2026-06-19

- Approved: explicit music filtering is selection-time only. Roll Call hides explicit Apple Music search results by default and confirms explicit Music Library selections after pick because the native library picker cannot be pre-filtered. The filter does not alter saved cues, playlist creation, or imported files.
  Rationale: coaches need a safer default while preserving existing team setup and avoiding unsupported control over Apple's Music Library picker.
  Status: approved

## 2026-06-18

- Approved: Game Day and Clips support a quiet live-surface-only horizontal swipe shortcut, with Game Day swiping left to Clips and Clips swiping right to Game Day. The gesture is deliberate, disabled while modal/edit/import/prompt flows are active, preserves playback and screen state, gives a small horizontal nudge only after clear swipe intent, uses a light haptic on successful swipes, and remains separate from full-tab swipe navigation.
  Rationale: coaches need fast movement between the two live surfaces without accidentally entering setup/admin areas or interrupting active audio.
  Status: approved

## 2026-06-16

- Approved: cue preparation may continue during Game Day and Clips, but live use throttles the one-job-at-a-time queue so a job starts only after playback has been idle for a short quiet window. Low Power Mode remains paused except for explicit `Try Now`.
  Rationale: Custom Clips should not sit in `Preparing` unnecessarily on the live Clips screen, but user-triggered sounds must stay more important than background rendering work.
  Status: approved; supersedes the live-use pause portion of the 2026-06-14 cue preparation decision

## 2026-06-15

- Approved: replace user-facing shared Team Clips with team-specific Custom Clips on the live Clips page. Player Songs and Custom Clips are independent after copying; creation and editing require explicit Clips Edit mode; Custom Clip order travels in team exports/backups; deletion uses the existing 60-day Recently Deleted system.
  Rationale: coaches should choose whether they are setting a Player Song or adding a live soundboard clip, without understanding shared masters, references, or cross-player edit effects. Independent copies preserve Game Day simplicity and user investment while keeping generated/local portability honest.
  Status: approved; supersedes the 2026-06-14 Phase 4 shared Team Clips decision and the shared-assignment portion of Phase 5

## 2026-06-14

- Approved: Phase 5 playback always prefers a valid generated Roll Call clip and otherwise preserves the original source-backed recipe. Team Clips and private player clips use the same bounded preparation queue, with shared Team Clips prepared once for every assigned player.
  Rationale: playback should gain portability when public APIs make it possible without weakening the normal Apple Music path or duplicating work for shared clips.
  Status: superseded in part by the 2026-06-15 independent Custom Clips decision; generated-first playback and the bounded queue remain approved

- Approved: 1.2 team-package export previews portable, device-dependent, preparing, and repair-needed clips before creating the package. Import preserves identifiable assignments, copies valid generated and local assets, audits what is actually ready on the receiving device, and routes unresolved player or Team Clip items toward repair.
  Rationale: team ownership requires honest portability and recovery; a missing file or unavailable Apple Music account should not erase carefully configured song choices or reject an otherwise useful team.
  Status: approved

- Approved: generated-clip cleanup is automatic but fail-closed. It may remove only regular files in Roll Call's generated-clips directory that are unreferenced by active teams, Team Clips, private assignments, Recently Deleted records, or readable backup snapshots; active preparation, unreadable backups, or unexpected filesystem items block deletion.
  Rationale: reclaiming storage must never outrank preserving user setup, recovery paths, or uncertain files.
  Status: approved

- Approved: support bundles contain aggregate cue-generation, readiness, portability, retry, policy, storage, cleanup, and boolean playback-state diagnostics only. They exclude audio, song metadata, team/player names, filenames, and source or model identifiers.
  Rationale: diagnostics should be useful without exporting user content or unnecessarily identifying roster and music data.
  Status: approved

- Approved: Phase 4 Team Clips are team-scoped reusable `SongClip`s; players may explicitly reference a shared clip, while editing from Player Editor requires a private copy so one player's changes cannot silently alter teammates. Deleting a shared clip must offer to preserve assigned players as private copies, and exact creative duplicates are reused.
  Rationale: reusable songs should reduce repeated setup without making player-specific edits or deletion surprising, destructive, or difficult to recover from.
  Status: superseded by the 2026-06-15 independent Custom Clips decision

- Approved: the Setup Guide audio step uses the same Music Library-first source choices and draft `Make Your Clip` editor as Player Editor, rather than maintaining a separate inline onboarding trimmer.
  Rationale: one consistent selection and waveform-trimming experience is easier to learn, preserves explicit Save behavior, and prevents the simpler onboarding controls from drifting away from the real editor.
  Status: approved

## 2026-06-10

- Approved: Volume Automation applies only to source-backed Apple Music playback. Local, built-in, generated, and Announcement Cue files never receive runtime volume normalization, fading, or restoration, regardless of the setting, because generated local clips already carry their fade envelope.
  Rationale: applying playback-time volume changes to local files can duplicate baked fades and alter user-authored audio; the setting remains useful only for source-backed playback where Roll Call cannot bake the fade into a portable file.
  Status: approved

- Approved: player song readiness uses `Ready on Any Device` for a Roll Call-owned portable local clip and `Ready on This Device` for source-backed playback that currently works here but may not travel; tapping the status explains its playback and portability implications.
  Rationale: the earlier `Ready` and `Ready Here` labels required users to infer the device boundary, while explicit device language keeps Apple Music reliability and export portability honest without turning the main Player Editor into documentation.
  Status: approved

- Approved: replace the custom 1.2 Music Library browser with Apple's `MPMediaPickerController` as the primary player song-selection surface. Keep Apple Music catalog search and Files as separate secondary actions that feed the same draft clip editor.
  Rationale: the system picker provides the familiar Music library hierarchy, search, cloud-item handling, accessibility, and interaction behavior users already understand; catalog search cannot use that controller, so its custom surface should stay visually restrained and follow standard Apple list/search conventions.
  Status: approved

- Approved: the 1.2 player song flow uses one Music Library-first `Choose Song` picker followed by a draft `Make Your Clip` editor; selecting or importing a source does not change the player until the editor's explicit Save action.
  Rationale: coaches should be able to browse, preview, drag the selected window, and change its length without accidentally replacing a working Game Day cue. Apple Music catalog search remains an explicit Search scope and Files remains an optional fallback.
  Status: approved

- Approved: Roll Call 1.2 will not attempt to request Apple Music offline downloads because the public iOS SDK exposes library addition but no supported API to request or control a Music download; `MPMediaLibrary.addItem(withProductID:)` will not be used as a misleading substitute.
  Rationale: adding a song to the Music Library does not guarantee that iOS downloads it, does not expose download progress or completion, and would silently mutate the user's library without delivering the promised reliability behavior. Roll Call may detect existing device-library/download state and use a readable `MPMediaItem.assetURL` when one is legitimately available.
  Status: approved

- Approved: cue preparation runs through a one-job-at-a-time queue, stores job truth on `SongClip`, uses deterministic generation keys to reject stale results, preserves an older working generated asset when regeneration fails, pauses during Game Day/Clips and Low Power Mode, and permits explicit `Try Now` to bypass only the Low Power pause.
  Rationale: derived audio work must remain bounded, cancellable by replacement, safe around live use, and unable to overwrite a known-good clip with a late or failed result.
  Status: superseded in part by the 2026-06-16 live-use throttling decision; Low Power behavior remains approved

- Approved: Roll Call 1.2 will generate local song clips only when public APIs expose a genuinely readable local source; Apple Music-linked songs remain a normal source-backed playback path, downloaded availability may improve readiness on the current device without implying portability, and no remote policy switch or unsupported capture/extraction behavior will be added.
  Rationale: the Phase 0 probe successfully narrowed the public-API reality and did not support the earlier assumption that Apple Music songs could generally be localized, so the product must preserve the easy Apple Music path while reporting readiness and portability honestly.
  Status: approved

- Approved: Roll Call 1.2 persists player songs as private `SongAssignment`s backed by durable `SongClip` creative truth, keeps `Cue` as the internal playback recipe, migrates legacy `Player.cue` values to private assignments while decoding, and writes resolved assignments in the new model on subsequent saves. Legacy shared assignments are decode-only compatibility data; unresolved references remain preserved until they can be migrated or repaired.
  Rationale: source metadata, selected timing, generated assets, readiness, portability, and retry policy need independent durable state without breaking existing teams, playback, or older `.rollcall` imports.
  Migration ownership: `Team.init(from:)` resolves legacy shared assignments when the team and its `teamClips` are available. `AppModel` separately resolves the same compatibility payload inside `RecentlyDeleted` player records because those records require the owning team lookup; unresolved references remain untouched in both paths.
  Status: approved; legacy shared assignments are compatibility-only

## 2026-06-07

- Approved: Game Day may show a subtle lineup-progress hint animation only when coaches explicitly advance the batting order from `Next` or `On Deck`, with a default-off Settings toggle and automatic suppression when iOS `Reduce Motion` is enabled.
  Rationale: the live board should help coaches understand how the lineup flows toward `On Deck` and `Now Batting` without turning the screen into a constant animation surface; keeping it opt-in also avoids surprising motion for existing users while still preserving an accessible path for coaches who want the hint.
  Status: approved

## 2026-06-09

- Superseded: remove the non-Release `Music Render Probe` entry from Developer Tools after Phase 0 findings were captured.
  Rationale: the probe served its narrow learning purpose, and keeping it in Developer Tools after the failed local-copy and transition-crossfade experiments creates unnecessary debug-surface clutter without improving the release app.
  Status: approved

- Approved: `release/1.2` Phase 0 uses a non-Release in-app `Music Render Probe` with manual sample assignment, explicit run actions, temporary render files, and redacted summary export rather than guessing Apple Music/local renderability from docs or scripts alone.
  Rationale: the 1.2 cue revamp depends on what public APIs actually expose inside Roll Call's real app context on a real device, and the safest way to learn that is a deliberately scoped probe surface that stays out of Release builds and avoids retaining user media.
  Status: superseded by the 2026-06-18 Developer Tools cleanup

- Approved: until the Phase 0 real-device probe records concrete `Full Source` successes for Apple Music-derived cases, treat Apple Music local-generation policy as provisional and keep `sourceBackedOnly` as the conservative planning default for those cases.
  Rationale: the revamp needs a clear starting point now, but it would be misleading to treat aggressive Apple Music local generation as approved fact before the probe has actually proven any readable full-source paths through public APIs.
  Status: approved

- Approved: Apple Music Volume Automation must capture the phone's pre-cue volume, leave playback volume untouched until fade-out begins, and restore that exact pre-cue level only after playback has fully stopped; cue handoff may discard the old pending restore only when a new cue is replacing the old one.
  Rationale: coaches will notice even brief volume jumps before a song starts or after a fade ends, so the automation contract must be explicit and stable instead of inferred from provisional MediaPlayer behavior.
  Status: approved

- Approved: Roll Call will remain an all-features-free app, with optional in-app donations as the only planned user-payment path instead of a premium or Plus tier.
  Rationale: the product works best when coaches never have to weigh feature access against trust, setup effort, or Game Day success; optional support can exist without turning delight, convenience, or ownership into gated upgrades.
  Status: approved

- Approved: raise the rating-request thresholds from 5/10 successful Game Day sessions to 10/20 before the 1.1 release, while keeping the same safe non-live presentation rules, cooldown, and single retry shape.
  Rationale: the existing prompt cadence felt too eager for a field-use app, so the ask should wait for more repeated proven value before coaches see it.
  Status: superseded by the 2026-09-06 probable-game-date rating policy

- Approved: add an iOS 18+ Developer Tools experiment that swaps subscribed Apple Music catalog playback from the current MediaPlayer volume-automation backend to MusicKit `ApplicationMusicPlayer.transition` crossfade, while preserving the existing backend everywhere else.
  Rationale: the current fade-out workaround is still provisional and uses deprecated volume behavior, so an isolated opt-in backend experiment is the safest way to learn whether newer MusicKit transition APIs feel better without destabilizing iOS 17 or Release builds.
  Status: approved

## 2026-06-05

- Approved: Game Day's fallback player grid should visually continue the lineup after `On Deck`, wrapping through the present order while still keeping every player visible and every tile tap freeform.
  Rationale: the live board should make the expected next-up flow easier to scan without removing the coach's ability to manually trigger any player's walkup out of sequence.
  Status: approved

- Approved: when a coach taps a later player from the Game Day grid, Roll Call should treat it as a temporary lineup override in the hero only, leaving the real `Now Batting` pointer, `On Deck`, and grid order untouched until playback ends.
  Rationale: out-of-sequence walkups happen in real use, but the board should still preserve lineup context instead of visually pretending the lineup itself changed.
  Status: approved

- Approved: add a polite rating request flow that waits for five successful Game Day sessions, counts a session after real player playback when leaving Game Day or backgrounding from it, enforces a four-hour cooldown between counted sessions, never interrupts Game Day/Clips, shows Roll Call's own rating-request sheet before any handoff, sends an explicit `Rate Roll Call` tap straight to the App Store review page, exposes a Settings > About rating entry only after that threshold is earned, and allows one later automatic retry after another five successful sessions if the first ask is dismissed or skipped.
  Rationale: the app should ask only after repeated proven value in the real live-use flow, while still giving heavy Game Day users credit even if they usually close the app straight from Game Day; using Roll Call's own sheet keeps the copy testable and ensures an explicit rating tap is never lost to StoreKit suppression.
  Status: superseded by the 2026-06-07 threshold increase to 10/20 sessions

- Approved: non-Release Developer Tools may include a rating-threshold testing control that flips the threshold between met and not met and resets the automatic prompt attempt state so the flow can be exercised repeatedly during testing.
  Rationale: the rating prompt is intentionally rare in production, so internal testing needs a compact way to re-enter the earned state without waiting through real sessions or getting stuck after prior spent attempts.
  Status: approved

- Approved: non-Release Developer Tools may launch the same rating-request sheet used in the real app, while also keeping separate diagnostics for the native StoreKit prompt and direct App Store review page.
  Rationale: the rating ask needs a trustworthy internal test path that matches production exactly, while still preserving low-level diagnostics for Apple-controlled review surfaces.
  Status: approved

## 2026-06-01

- Approved: promote Apple Music team playlist creation to a free 1.1 team-management feature, with a preview before update, all-team scope, exact-name managed playlist replacement, deduped songs, skipped-cue explanations, and unresolved-song recovery before any partial replacement.
  Rationale: the feature is already useful as a practical convenience, belongs with team-level actions until Team Home exists, and should be honest about overwriting Roll Call's managed Apple Music playlist without presenting itself as sharing, export, or backup.
  Status: approved

- Approved: in-app What's New uses bundled Swift summary content grouped by explicit minor-release family, triggers once per version/build for existing users, waits for a safe non-live tab, and remains reopenable from Settings > About.
  Rationale: release notes should be visible enough for useful updates, quiet during Game Day/Clips/import/onboarding flows, testable by build number, available offline, and backed by a full changelog web link rather than remote-fed app content.
  Status: approved

- Approved: Keep Screen Awake is a global, default-off setting that prevents auto-lock only while Roll Call is active on Game Day or Clips, with no live-screen indicator.
  Rationale: the feature protects field use without silently changing battery behavior across the whole app, and Clips shares the current live-screen treatment until the later Game Day/Clips revamp revisits the boundary.
  Status: approved

## 2026-06-02

- Approved: the built-in General Clips pack should favor distinct real-crowd reactions, avoid negative or mocking sounds, and use plain functional names instead of novelty labels.
  Rationale: the live-use clip board should feel authentic for youth softball and general sporting events, with enough variety to cover mild applause, bigger cheers, rhythm, and atmosphere without padding the set with redundant or negative sounds.
  Status: approved

- Approved: Recovery now leads with a centralized `Recently Deleted` list for deleted teams and players, while backups remain a separate earlier-app-state tool.
  Rationale: accidental deletes are better solved by a simple item-level recovery surface than by asking users to restore whole-app backups for everyday mistakes.
  Status: approved

- Approved: Recently Deleted keeps deleted teams and players for 60 days, shows days remaining, allows item-by-item permanent delete, and excludes deleted-item history from normal exports and backup restores.
  Rationale: the feature should feel recoverable and explicit without turning into permanent hidden storage or leaking deleted-item history into sharing and backup flows.
  Status: approved

- Approved: team restore is full-fidelity, player restore returns to the original team in the best practical prior lineup position as present today, and missing media should trigger an honest `Restore What We Can` fallback instead of silent partial recovery.
  Rationale: recovery should preserve meaningful setup work, stay visible in the restored team context, and tell the truth clearly when some song, photo, or Announcement Cue media can no longer be recovered.
  Status: approved

## 2026-05-31

- Approved: team color drives a protected derived accent palette across selected-team UI, while semantic colors such as warning, destructive, ready, disabled, and live playback remain independent.
  Rationale: team identity should feel present throughout setup and Game Day without making gray, black, gold, or dark-mode surfaces unreadable; Gray and Black behave as adaptive neutral identity themes rather than literal raw colors everywhere.
  Status: approved

- Approved: the selected-team accent wash should apply to app page backgrounds, not only Game Day and Clips.
  Rationale: team identity should feel coherent across setup and utility pages while the wash remains low-opacity and system-background-first so normal iOS readability and appearance rules still hold.
  Status: approved

## 2026-05-28

- Approved: after stored state loads, Roll Call should open populated teams on `Game Day`, empty selected teams on `Players`, and preserve the no-team onboarding path.
  Rationale: a team with players is most likely ready for live use, while an empty team needs the roster-building surface first.
  Status: approved

- Approved: Roll Call uses a native hosted XCTest target named `RollCallTests` for fast core-logic regression coverage before adding UI tests.
  Rationale: the highest-risk seams are package import/export, backups/restores, CSV import validation, persistence, lineup ordering, and readiness logic; those are best protected by small unit tests that avoid real audio playback, network state, device volume, and simulator-specific UI timing.
  Status: approved

## 2026-05-23

- Approved: Apple Music authorization must be requested only from explicit Apple Music actions, not from passive first-launch capability refresh.
  Rationale: first launch should avoid a permission barrage; Roll Call can explain access at song-picking time while still allowing local audio and preview-limited fallback behavior when access is skipped.
  Status: approved

- Approved: Volume Automation now defaults off for new or missing settings, while staying available in Settings and Advanced Trim guidance.
  Rationale: the advanced trim screen already teaches users where the feature matters, and the default should avoid surprising automatic volume changes.
  Status: approved

- Approved: first-run onboarding starts with a full-screen softball welcome image that visually matches the launch screen, then continues into the existing Setup Guide without changing the setup pages.
  Rationale: launch-to-first-run should feel more polished and emotionally tied to youth sports while preserving the current onboarding flow and completion state.
  Status: approved

- Approved: first-run Setup Guide should offer a visible Close button, and the lineup-step Got It action should work even with fewer than the recommended three players.
  Rationale: the three-player recommendation should remain helpful guidance, not a trap or a disabled-looking escape hatch during onboarding.
  Status: approved

- Approved: Roll Call 1.0.0 defaults new and missing-mode teams to `Announcer+Song`, keeps live-screen dark mode, Game Day haptics, and Volume Automation default-on, and keeps the Setup Guide moving from added player #2/#3 into that player's audio step instead of returning to Lineup.
  Rationale: the 1.0 submission should make the expected live experience the default while keeping onboarding focused on getting each real player to a usable walkup quickly.
  Status: approved

## 2026-05-22

- Approved: first-run onboarding starts from a true empty app state, not a seeded sample team, and guides users toward one real team, one player, audio or an explicit cheer fallback, lineup orientation, and Game Day.
  Rationale: Roll Call should make the first real walkup happen quickly without fake roster data, tutorial carousels, accounts, permission barrages, or homework-style setup pressure.
  Status: approved

- Approved: Settings includes a normal user-facing setup guide relaunch path with create-new-team, import `.rollcall`, and review-current-team options.
  Rationale: users may leave setup accidentally, want to create another team with guidance, or need repeatable onboarding for testing without hiding the path in Developer Tools.
  Status: approved

## 2026-05-20

- Approved: license Roll Call as noncommercial source-available software using PolyForm Noncommercial 1.0.0 as the base license, with separate Roll Call-specific attribution, source-sharing, commercial-use, small-snippet, and asset-boundary terms.
  Rationale: the project should remain very free for personal, educational, nonprofit, school, public agency, volunteer, youth, and community sports use while keeping commercial use permission-only and protecting Roll Call branding, personal materials, and third-party assets.
  Status: approved

## 2026-05-21

- Approved: live-screen appearance follows the explicit matrix in `docs/product/APPEARANCE_RULES.md`: setup screens always follow the device, `Game Day` and `Clips` force dark only when the device is dark or `Always Use Dark Live Screens` is enabled, and the Game Day lineup sheet follows the effective live appearance.
  Rationale: the setting is meant to protect live-use readability without turning the whole app dark or leaving live content stuck in a dark-only custom palette when the user intentionally allows Light Mode.
  Status: approved

- Approved: add a default-on setting that keeps `Game Day` and `Clips` in dark mode while allowing the rest of the app to follow the user's normal Light/Dark appearance.
  Rationale: the custom light-mode Game Day gradient can become hard to read in sunlight, while the live-use screens are the places where field visibility matters most. `Game Day` and `Clips` should share the same live-side background treatment so the live surfaces read as intentionally related.
  Status: approved

- Approved: Readiness should mean confidence for live Game Day use, with player-specific playable audio as the main Ready state, Announcement Cues as Enhanced, missing player audio as a helpful non-blocking need, and photos/presentation polish as optional upgrades that never reduce readiness.
  Rationale: this aligns the app with `docs/product/READINESS_MODEL.md` by encouraging setup without turning it into a warning-heavy completion checklist; built-in fallback remains live-safe but does not count as a player being Ready.
  Status: approved

## 2026-05-15

- Approved: AirDropped or shared `.rollcall` files should open directly into Roll Call's existing import flow, while preserving the current backup-first import semantics.
  Rationale: the app already treats `.rollcall` as the portable team handoff format, so direct file opening reduces friction without introducing live sync or changing package contents.
  Status: approved

## 2026-05-18

- Approved: Roll Call uses one bundle identifier, `com.jkfisher.rollcall`, across Debug, Internal, and Release build environments while centralizing production-safety gates in `BuildEnvironment` and `FeatureFlags`.
  Rationale: one app identity keeps App Store Connect, MusicKit, signing, and `.rollcall` document ownership aligned; Internal TestFlight replaces the installed app rather than creating a side-by-side build.
  Status: approved

- Approved: Developer Tools may include an experimental Apple Music team playlist sync button that creates or fully replaces the exact-name playlist `Roll Call - <Team Name>` for the selected team.
  Rationale: the feature should stay out of normal app flows while giving coaches a quick Apple Music playlist mirror of the selected team's catalog-backed song cues; local, built-in, missing, preview-only, and duplicate cues are skipped.
  Status: superseded by the 2026-06-01 free 1.1 team-management playlist decision

## 2026-05-16

- Approved: Game Day announcer mode should become a three-way control with `Announcer Only`, `Announcer+Song`, and `Song Only`, plus a centered `Prev / Edit Lineup / Next` row above the player grid.
  Rationale: the live board needs clearer top-down structure and explicit playback intent, while the lower controls should prioritize lineup navigation without making accidental player taps too easy.
  Status: approved

## 2026-05-13

- Approved: remove Built-in Voice from the product for now and center custom recorded intros only, with Game Day using either cue-only playback or custom-intro-plus-cue playback.
  Rationale: Apple speech generation/export has proven too unreliable on-device for this app's core job, so a simpler custom-intro-only model is safer and clearer.
  Status: approved

- Approved: resolve the MusicKit token failure by enabling the MusicKit App Service for App ID `com.jkfisher.rollcall`, not by adding a local entitlement.
  Rationale: Apple's token service rejected the bundle ID as an unregistered client, and Xcode rejected `com.apple.developer.music.user-token` as an invalid entitlement for this target.
  Status: approved

- Approved: subscribed Apple Music mode must use catalog-backed MusicKit selections only, with preview fallback reserved for preview-only devices.
  Rationale: silently using iTunes preview results on a subscribed device makes the trim UI lie about full-song selection; a clear failure is safer than assigning the wrong 20-second window.
  Status: approved

- Approved: keep Apple Music clips capped at 20 seconds, but let subscribed devices trim from the full-song timeline instead of the preview-only window.
  Rationale: the app's core job is still a fast, controlled walk-up clip, but the chosen clip must come from the real song when the user has the playback rights for it.
  Status: approved

- Approved: remove protected/panic Game Day behavior and replace it with lighter Focus guidance plus a plain stop-playback affordance.
  Rationale: the old controls added friction and clutter without delivering true OS-level lock-down behavior, so the simpler game board is a better fit for the current product.
  Status: approved

- Approved: make lineup order persist across days and launches, auto-alphabetize only before the first manual customization, and move manual recovery language from "safety snapshots" to clearer backup terminology.
  Rationale: coaches need the lineup to stay where they left it, while backup/recovery should remain available without feeling like a daily workflow.
  Status: approved

- Approved: replace the placeholder General Clips tones with a bundled licensed crowd clip set tracked in `ATTRIBUTIONS.md`.
  Rationale: the feature now needs to feel polished out of the box, and the licensing trail must live in the repo alongside the shipped assets.
  Status: approved

## 2026-05-14

- Approved: subscribed full-song Apple Music playback may use an internal MediaPlayer application-player backend to preserve the Apple Music-first selection flow while pursuing reliable fade-capable playback.
  Rationale: MusicKit `ApplicationMusicPlayer` keeps the picker and trim model honest, but it still hard-stops subscribed catalog playback; swapping the playback backend internally is safer than unsupported local capture/export experiments.
  Status: approved

- Approved: hide local audio import from the main cue-source section, but keep it available behind a secondary fallback affordance.
  Rationale: Apple Music should stay primary in the product flow, while dependable device-owned media remains available without competing visually as the default setup path.
  Status: approved

- Approved: when a Game Day player is tapped without a selected song cue, play the built-in `Small Cheer` clip as the default fallback.
  Rationale: this keeps tap behavior useful even when player setup is incomplete, while preserving a single implementation point for a future user-selectable default fallback cue.
  Status: approved

- Approved: switch `.rollcall` export/import to a true zipped single-file archive format, while keeping import compatibility with existing directory-style packages.
  Rationale: sharing should produce one expected file instead of a package folder, but prior exports must remain usable.
  Status: approved

- Approved: selected teams can be removed from the Teams panel through an explicit destructive confirmation action.
  Rationale: team management needs a complete lifecycle, but deletion should stay visible, scoped to the current team, and hard to trigger accidentally.
  Status: approved

## 2026-05-12

- Approved: Apple Music cue editing should adapt to subscription capability, using full-song trimming for active playback subscriptions and preview-only trimming otherwise.
  Rationale: the core job is choosing the right 20-second walk-up moment, but the app must still behave honestly and usefully on devices that can search Apple Music without being allowed to play the full catalog.
  Status: approved

- Approved: move announcer behavior to a team-scoped Built-in Voice profile plus optional per-player custom recordings, with Game Day choosing custom intro first, built-in fallback second, and no-intro mode as a team session control.
  Rationale: announcer wording, voice choice, package portability, and custom-recording override behavior need a stable product model instead of per-cue ad hoc intro state.
  Status: superseded

- Approved: move Apple Music song choice into a dedicated recents-plus-search picker and make cue shaping a separate trim-focused step with preset-first controls and opt-in precision.
  Rationale: the old inline search plus raw timing sliders made a common setup path feel awkward; the new flow keeps song choice, clip feel, and fine adjustments separated without rewriting the cue model.
  Status: approved

- Approved: recover the prototype with a reliability-first implementation order before chasing broader polish.
  Rationale: debounce, protected Game Day flow, lineup coherence, readiness depth, and restore/import safety are more important to the app's core job than deferred waveform/gain polish.
  Status: approved

- Approved: ship the General Clips feature using the current generated placeholder sounds for now, with real licensed applause/cheer assets and attributions tracked as follow-up work.
  Rationale: the app needs the feature surface and cue-path behavior now, but asset sourcing should not block the product workflow implementation.
  Status: approved

## 2026-05-11

- Approved: ship an experimental Apple Music local-copy lane behind an advanced off-by-default setting.
  Rationale: keep the supported app behavior App-Store-safe by default while still allowing a removable, isolated power-user conversion path.
  Status: superseded; the experimental local-copy lane was removed and is not part of the supported product.

- Approved: treat successful experimental Apple Music copies as ordinary local audio in the product model.
  Rationale: playback, editing, export, duplication, and restore should not special-case prior Apple Music origin once a local file exists.
  Status: superseded with the removal of the experimental Apple Music local-copy lane.

- Recorded: the working app bootstrap has been moved back onto the intended `RollCall/` and `RollCall.xcodeproj/` names.
  Rationale: the rebuilt tree is now the validated source of truth, and the older broken bootstrap artifacts were removed to keep the repo clean.
  Status: approved

- Approved: `.rollcall` exports are directory-backed packages containing a manifest plus copied app-managed assets.
  Rationale: sharing/import must remain portable for offline local audio, announcer renders, and roster photos instead of depending on paths from the exporting device.
  Status: approved
