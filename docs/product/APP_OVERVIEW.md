# Roll Call — Application Overview

This document gives a non-code AI everything it needs to discuss the Roll Call app at a product level: what it is, who it's for, how the screens fit together, what the user can do on each one, and the principles that constrain future change. It is current as of build 111 / version 1.3.0 candidate.

---

## 1. What Roll Call Is

Roll Call is an iPhone app for **youth-sports walk-up cues**. The coach (or a parent, sibling, helper) sets up a roster ahead of time. When a player comes to bat (or step onto the field, or up to the line — it is sport-agnostic), the user taps the player's tile and the app plays that player's chosen audio cue: usually a short trimmed clip of their walk-up song, optionally introduced by a recorded "Now batting, number 17, Ellie..." announcement.

It is iPhone-first, all app features are free, optional in-app support contributions are available in Settings/About, and it has no required account, no ads, no social features, and no cloud backend. All team data lives on device. Teams can be exported as `.rollcall` packages and imported on another device, but that is a manual sharing model, not automated sync.

### The product priorities, in order

1. **Easy** — a coach should be ready in about five minutes
2. **Personal** — it should feel like *their* team, not a generic app
3. **Cool** — walkups should feel exciting in front of kids and parents
4. **Professional** — polish matters, but never at the cost of the above

### The single most important promise

> If the coach opens the app and taps Start Game right now, it should feel good in front of players, parents, and teammates.

Every product decision is filtered through that promise. Reliability of the live moment is sacred. Setup is allowed to be imperfect; Game Day is not.

---

## 2. Core Vocabulary

These words have specific meaning in Roll Call. Use them precisely when discussing changes.

- **Team** — the durable container. Has a name, accent color, roster of players, batting order, session state, announcer profile, and a small library of built-in crowd clips. A device can have many teams. One team is "selected" at a time.
- **Player** — belongs to a team. Has display name, optional uniform number, optional photo, optional cue (audio assignment), optional custom announcer recording, and an `isPresent` flag for today's lineup.
- **Player Song / Cue** — the playable audio assignment for a player. Has a source (Music Library, Apple Music catalog, local audio/video file, generated Roll Call clip, or built-in fallback), a selected start time, a duration, a fade-out duration, and a pause-after-announcer value. A player without player-specific audio falls back to a generic crowd cheer at Game Day.
- **Song Clip** — the durable saved source-and-timing truth behind a Player Song or Custom Clip. Generated local media may make it portable, but the original source-backed recipe is preserved so the user can repair or regenerate it later.
- **Announcer / Announcement Cue** — an optional recorded voice clip ("Now batting, number 17, Ellie!") that the user records into the app. Separate from the song cue. Lives at the player level.
- **Lineup / Batting Order** — the ordered list of present players for today's game. Game Day plays in this order. The user can sort A-Z, sort by number, or drag manually. Manual order is preserved across launches.
- **Game Day** — the live screen where the actual walkups happen. The product's reason for existing.
- **Quick Game Day** — the zero-playback system entry that opens the existing Game Day screen for the team most recently used there, or an explicitly supplied Shortcut team. It is navigation, never a playback remote.
- **Player Card** — an on-demand 4:5 share graphic centered on one player and their walk-up music. It is previewed and shared from Player Editor and is not a Game Day surface or stored gallery item.
- **Game Day Announcer Mode** — how cues play. Three values: `Announcer Only`, `Announcer+Song`, `Song Only`. Set per-team in session state, toggled from the live screen.
- **Sound Effect** — a bundled crowd reaction in the Clips tab, such as a small cheer, rhythmic clap, chant, or stadium swell.
- **Custom Clip** — a team-specific live clip in the Clips tab. Custom Clips can be copied from Player Songs or created directly, then reordered, edited, deleted, restored, and exported with the team. After copying, Custom Clips and Player Songs are independent.
- **Readiness** — Roll Call's confidence model. Answers "if I opened Game Day right now, would it feel good?" Current song states include `Ready on Any Device`, `Ready on This Device`, `Preparing`, `Needs Apple Music`, and `Needs Repair`, with announcer intros treated as `Enhanced` and photos/polish treated as optional. Never a percentage. Never blocks Game Day.
- **Support Contribution** — an optional StoreKit purchase path for users who want to support maintenance. Includes repeatable one-time support and monthly/yearly recurring support. It never unlocks features, changes Game Day behavior, affects readiness, or travels with exported teams.

---

## 3. First Run & Setup Guide

The very first time the user opens the app, they see a **full-screen welcome screen**: a softball image, large title "Welcome to Roll Call.", subtitle "Generate Walk-Up Music Cues for Youth Sports", and a single "Let's Get Started" button. This is the entire welcome — no tutorial carousel, no slideshow.

Tapping the button enters the **Setup Guide**, a guided onboarding sheet that walks the user through creating their first team. The Setup Guide is also reachable later from Settings → "Open Setup Guide" if the user wants to add another team via the guided flow.

### Setup Guide structure

The guide has four numbered milestones rendered as a breadcrumb at the top: **Team → Player → Audio → Lineup**. The active step is highlighted; completed steps show checkmarks. On the final "You're ready to try Roll Call" screen, all four are checkmarked.

Setup Guide steps:

1. **Team** — name the team, pick an accent color from eight presets (Roll Call Orange, Red, Gold, Green, Blue, Purple, Gray, Black). Or "Add Team from Another User's .rollcall File" instead.
2. **Player** — add a first player (name required, uniform number optional). On returning to this step later, this screen becomes "Review your first/second/third player." for editing.
3. **Audio** — assign walkup audio through the same Music Library-first song flow used by Player Editor. Music Library is primary, Apple Music catalog search is an explicit secondary path, and Import Audio or Video is the file fallback. A "Try with a Crowd Cheering" option lets the user defer audio entirely and use the built-in cheer fallback. Song and file selections open the draft Make Your Clip editor before saving to the player.
4. **Lineup** — two variants:
    - With fewer than 3 players: title reads "Three players make lineup click." The primary action is "Add One More Player to Reach Three." A secondary "Open Lineup Anyway" is available. "Got It" is hidden until the user opens the lineup at least once.
    - With 3+ players: title reads "Now check the lineup." Primary action is "Open Today's Lineup." "Got It" still requires the user to actually open the lineup first.

Opening the lineup (during the guide or later) shows the **Lineup Editor sheet** described in §5. After dismissing it, "Got It" becomes available. Pressing "Got It" advances to the final handoff screen: **"You're ready to try Roll Call."** with a single "Open Game Day" button. That tap completes onboarding and routes the user to the Game Day tab.

### Setup Guide can also be entered for additional teams later

From Settings, "Open Setup Guide" launches a **manual chooser** variant first: "What would you like to set up?" with two choices: "Create New Team" (re-runs the guide) or "Add Team from .rollcall File" (jumps to file picker). The first run skips this chooser and goes straight into team creation.

Back navigation in the guide is bidirectional — there is a Back chevron in the toolbar, and Close is available once at least one team exists (with a confirmation: "Close Setup Guide?").

---

## 4. Main Navigation — The Six Tabs

Once onboarding is complete, the app's main UI is a six-tab `TabView`. The order is:

1. **Game Day** (`play.rectangle.fill`)
2. **Clips** (`music.note.list`)
3. **Players** (`person.3.fill`)
4. **Teams** (`list.number`)
5. **Readiness** (`checklist`)
6. **Settings** (`gearshape.fill`)

Every tab (except the live ones) shows a **team banner** at the top with the selected team's name, accent color, and a small status line (e.g. "12 players • 9 present"). The banner is consistent across tabs so the user always knows which team is active. On Game Day, the banner shows a "Warnings" badge if anything live needs attention.

Game Day and Clips also have a deliberate horizontal swipe shortcut between them. That shortcut preserves playback and screen state, stays live-surface-only, and is disabled during modal, edit, import, prompt, or other flows where a live swipe would be surprising.

The app preserves the last useful context unless first-run or no-team state requires onboarding. The principle is "open to the team, don't trap the user in a flow."

---

## 5. Tab Details

### 5.1 Game Day (the live screen)

The center of the product. Dark by default in Live appearance (toggleable in Settings: "Always Use Dark Live Screens"). Layout, top to bottom:

- **Announcer Mode Picker** — segmented control for the three modes (Announcer Only / Announcer+Song / Song Only). Selection is per-team and persists.
- **Live Warning Strip** (only shown when needed) — e.g. "No present players in the lineup", or a count of live readiness issues. Yellow or red tinted.
- **Now Batting Hero card** — large player tile for the currently-playing or next-up player. Shows photo, name, number, the cue title (song name, or "Announcer Only", or "Fallback: Small Cheer"). Tap to play. A visible playing indicator appears while audio is active. If the coach taps a later player out of sequence, this card temporarily relabels itself as `Lineup Override` and shows that player until playback ends.
- **On Deck card** — smaller tile for the player after the real lineup next batter. Greys out when there is no next batter (one-player roster), and does not temporarily change during a lineup override tap.
- **Control Row** — a "Lineup" button that opens the lineup editor sheet. Plus playback controls when audio is active (stop).
- **Player Grid** — all present players as tappable tiles that continue the visible lineup after `On Deck`, wrapping through the rest of the order so everyone stays available on the board. Tapping any tile still triggers that player's walkup immediately (the grid is sequence-oriented visually, but the coach can still tap whoever is actually at bat).

Tap interactions degrade gracefully. If a player has no cue and announcer mode is "Song Only" or "Announcer+Song", playback falls back to a built-in cheer. If a player has no recorded announcer in "Announcer Only" mode, same. Game Day never fails silently and never errors out — it always plays *something*.

Quick Game Day enters this same screen without playing anything. A normal request uses the team most recently entered intentionally in Game Day; merely viewing or editing another team does not change that target. If no remembered team exists, or it was deleted, Roll Call returns to its normal home/team-selection state rather than choosing a team arbitrarily. An App Intent can optionally receive an explicit team for advanced Shortcuts use. The iOS 18+ WidgetKit control is available to supported Control Center and Lock Screen surfaces; Shortcuts, Siri/Spotlight discovery, and Action Button use fall naturally out of the system intent/control architecture.

### 5.2 Clips (the live Clips tab)

A team's live clip board, separate from the per-player walkup flow. This tab uses the same Live appearance treatment as Game Day so it can be used during a live moment without feeling like setup.

There are two sections:

- **Sound Effects** — bundled crowd reactions focused on a smaller sports-oriented set: a friendly fallback cheer, a rhythmic clap, a general stadium swell, a stronger rally cheer, a bigger cheer, and a simple chant option.
- **Custom Clips** — team-specific live clips that can be copied from Player Songs or created directly. They can be reordered, edited, deleted into Recently Deleted, restored, and included in team packages.

Custom Clip editing is explicit. Adding, editing, reordering, and deletion happen from an Edit Custom Clips sheet, not accidentally during live play. Copies remain independent from Player Songs so editing or deleting one never silently changes the other.

### 5.3 Players (roster management)

A grouped list of the selected team's roster, sorted alphabetically.

- **Top section: Add Player (quick add)** — an inline name/number field with an Add button. Fast roster entry.
- **Roster section** — each row shows photo, name, number, an audio-status icon, a custom-intro-status icon (if applicable), and a "marked out" treatment (dimmed) if the player is not present. Tapping a row opens the **Player Editor sheet** (see §6.1). Swipe left exposes a "Mark Out" / "Mark In" action.

If no team is selected, the tab shows a ContentUnavailable view nudging the user toward Teams.

### 5.4 Teams (team lifecycle)

Primary sections:

- **Selected Team / Manage Team** — active team summary, accent preset grid, rename, duplicate, and remove actions.
- **Team Setup** — Import Roster CSV.
- **Share Team** — Share Team Package, Import Team Package, and Create Apple Music Playlist.
- **Teams** — choose, create, or import the roster Roll Call should use.

This is where team identity and lifecycle live, intentionally separated from everyday roster work in the Players tab.

### 5.5 Readiness

The "are we good to play?" view. Per the Readiness Model (`docs/product/READINESS_MODEL.md`), it is intentionally encouraging, never shaming. Cards, in order:

- **Readiness Overview Card** — overall summary plus "Open Game Day" button.
- **Player Audio Card** — list of players with portability-aware song status such as `Ready on Any Device`, `Ready on This Device`, `Preparing`, `Needs Apple Music`, or `Needs Repair`. Tap to open the player editor.
- **Enhancements Card** — announcer-intro upgrades. Discoverability surface for the announcer feature, not a requirement.
- **Optional Upgrades Card** — photo additions and other cosmetic polish.
- **Game Day Checks Card** — device-level conditions: audio route, network, Apple Music auth, volume automation, lineup configured. These can issue "Request Apple Music Access" or similar action prompts.

There is no percentage score, no Bronze/Silver/Gold, no red player errors. A player without player-specific audio needs attention or repair, but Game Day fallback still protects the live moment.

### 5.6 Settings

A scroll view of grouped sections:

- **Setup Guide & Teams** — Open Setup Guide, plus a row that sends users to Teams for import/export tools.
- **Support Roll Call** — opens the optional support screen with one-time and recurring StoreKit contribution options.
- **Music & Playback** — Hide Explicit Apple Music Results, Volume Automation.
- **Privacy** — Anonymous Usage Analytics is on by default and can be disabled
  independently of teams and app-state recovery; see [Privacy](./PRIVACY.md).
- **Game Day** — permanent Quick Game Day explanation, Always Use Dark Live Screens, Game Day Haptics, Keep Screen Awake, Show Lineup Progress Hints.
- **Recovery** — navigation into Recovery, where `Recently Deleted` handles everyday team/player undelete for 60 days and backups remain available for restoring an earlier app state.
- **About Roll Call** — top doorway row into version, build, environment chip, copyright credit to John Kenneth Fisher, optional Support Roll Call entry, public web/GitHub-style link, Email Feedback link, What's New, earned Rate Roll Call entry, and Attributions & Licenses.
- **Advanced / Developer Tools** (only visible when feature flag is on) — environment gates, runtime testing flags, experimental actions, diagnostics.

---

## 6. Key Sheets & Modals

### 6.1 Player Editor sheet

Opened from any player row (Players tab, Readiness list, Game Day tile long-press). The most feature-rich screen in the app. Sections, top to bottom:

- **Setup Summary** — at-a-glance status card.
- **Identity** — display name, uniform number, and photo. Selecting a new photo creates a metadata-stripped, bounded working master, then one on-device Vision pass suggests independent profile and Player Card framings. Normal selection completes without forcing crop editors; `Adjust Profile Photo` is an optional correction.
- **Player Song** — choose from Music Library, search Apple Music, import audio or video, swap source, clear cue. Shows the assigned song title, source, and current readiness/portability status.
- **Make Your Clip / Fine Tune Clip** (only when a song exists) — waveform or honest placeholder rail, selected-window dragging, length choices, exact start/length/fade controls, preview with playhead, and explicit Save for draft selections.
- **Announcement Cue** — record a custom intro via in-app mic recording. Buttons: Start/Stop Recording, Preview, Clear. A warning is shown if the file reference exists but the audio file is missing.
- **Player Card** — a visible `Preview & Share` action opens the finished Broadcast-style 1200-by-1500 graphic before the system Share Sheet. The preview also offers `Adjust Player Card Photo`; those draft framing changes follow the Player Editor's Save/Cancel transaction.
- **Remove Player** at the bottom, destructive role.

The editor is large and rich because per-player setup is where most setup time is spent. But the Setup Guide deliberately avoids most of this complexity — it only touches identity and song cue, leaving photos, announcer recordings, and advanced trim for later.

### 6.2 Lineup Editor sheet

Opened from Game Day's Lineup button, from the Setup Guide's lineup step, or from anywhere else lineup is editable. Sections:

- A short helper paragraph: "Turn off players who are not here today, then drag players into batting order."
- **Lineup section** — Sort A-Z and Sort by Number buttons, then the drag-reorderable list. Each row shows player photo, name, number, and a Present toggle.
- **Status section** — a footer reminding the user that manual order is preserved across launches until they re-sort.

This sheet uses the system Edit mode for dragging. Closing returns to wherever it was opened from.

### 6.3 Choose Song / Make Your Clip flow

Title "Choose Song." Music Library is primary and uses Apple's native picker when available. Apple Music catalog search is a separate explicit path with a native-style searchable list; files remain available as Import Audio or Video. The app asks for Music access only after the user chooses an Apple Music or Music Library action, and explains why before the system prompt.

Selecting a song or file opens a draft Make Your Clip editor. The user can preview, drag the selected window, adjust length and fade, and save explicitly. Cancelling the draft leaves the existing player song or Custom Clip unchanged.

### 6.4 Advanced Trim / Clip Editor controls

Reachable from Player Editor, Setup Guide audio, and Custom Clip editing. Provides finer controls for start, length, fade, preview, and source-backed readiness. The Setup Guide no longer keeps a separate simplified trimmer; it uses the shared flow.

### 6.5 Roster Preview sheet

Appears when the user imports a roster CSV. Lists the rows about to be imported. Confirm or cancel.

### 6.6 Photo Framing full-screen cover

Opened only when the user chooses to adjust either the profile or Player Card framing. Pan/zoom positioning is independently persisted for the chosen use. The original clean working master is not destructively replaced. VoiceOver users can adjust zoom and invoke named directional actions.

### 6.7 Support Roll Call screen

Opened from Settings, About Roll Call, or the rating prompt's low-pressure support link. This screen explains that Roll Call is free, ad-free, and fully functional for every team, then offers optional StoreKit support contributions.

The support screen uses a segmented control:

- **One-Time** — repeatable consumable support options: `Tip of the Cap`, `Dugout High Five`, `Walk-Up Hero`, and `Grand Slam Legend`.
- **Recurring** — auto-renewable support options: `Season Supporter` monthly and `All-Star Season Supporter` yearly.

StoreKit provides availability and localized prices. The app verifies transactions locally, finishes purchases, shows gratitude after verified support, shows active recurring support only when StoreKit confirms it, and includes Restore Support plus Manage Subscriptions actions for recurring support.

Support state is intentionally comfort UI only. It does not unlock features, remove limitations, rank users, affect Game Day, alter exports, or create account/cloud identity.

### 6.8 Rating Request sheet

The earned rating prompt remains a calm post-success sheet, never a Game Day interruption. It asks satisfied users to rate Roll Call, offers "Email Me Instead" for support problems, and includes a quiet "You can also contribute in Settings." path into Support Roll Call.

---

## 7. Audio, Playback, and Fallbacks

### Audio sources

- **Music Library** — the primary, recommended source. It uses the user's familiar library surface and may expose local readable media when iOS allows it.
- **Apple Music catalog search** — an explicit secondary source. Requires Apple Music authorization. With an active Apple Music subscription and MusicKit App Service entitlement, Roll Call can use source-backed full-song playback; otherwise it may rely on preview snippets where available.
- **Local audio / video** — files imported from the device, including video files (only the audio track is used). Used when the user prefers their own media or when music services are not available.
- **Generated Roll Call clips** — app-owned local `.m4a` clips rendered only when public APIs expose genuinely readable local audio. These are preferred for playback/export when valid.
- **Built-in clips / Sound Effects** — short crowd reactions bundled with the app. Used as the Clips Sound Effects library and as the fallback when a player has no cue.

### Fallback order (per UX Rulebook)

When playback is requested but the configured cue can't fully execute:

1. Intro + Song
2. Song only
3. Intro only
4. Generic cheering (built-in)

Game Day never fails. The user might get a smaller cue than they expected, but never silence or an error dialog.

### Volume Automation

Off by default. When enabled, source-backed Apple Music and Music Library songs use the current device volume as their starting point, then ramp down during the selected fade-out window. Local, generated, built-in, and Announcement Cue files play at their encoded volume because generated local clips already bake in their fade envelope.

---

## 8. Game Day Modes

Set per-team, toggled from the live screen.

- **Announcer Only** — plays only the recorded custom announcer intro. If a player has no custom intro, falls back to a small cheer. Useful for quiet venues or when songs aren't appropriate.
- **Announcer+Song** — plays the announcer intro first, then the song cue after a configurable `pauseAfterAnnouncer` gap. The fullest experience.
- **Song Only** — plays just the song cue, no announcer. Default for users who haven't recorded intros.

The mode is on `Team.session.gameDayAnnouncerMode`, persisted, and survives backgrounding. It is treated as a live decision (it lives in the team's session state, not its setup), and the picker is on the live screen rather than buried in setup, because mode often changes between innings.

---

## 9. Readiness Model — Detailed

Player song states:

- **Ready on Any Device** — has app-owned portable playable audio, such as a valid generated Roll Call clip.
- **Ready on This Device** — playable here, but dependent on the current device, library, subscription, account, network, or source-backed route.
- **Preparing** — Roll Call is trying to prepare a more reliable or portable clip without discarding the saved source truth.
- **Needs Apple Music** — the saved song depends on Music access/subscription/library state that is not currently available.
- **Needs Repair** — Roll Call cannot currently read or play the saved source; the user should choose the song again or import a replacement.
- **Enhanced** — Ready and has a custom announcer recording. Feels celebratory; the app uses this as a discovery surface for the announcer feature.
- **Optional** — anything else (photo missing, theme polish, etc.). Never implies the player is broken.

Team states:

- **Ready for Game Day** — every present player has player-specific playable audio.
- **Some Audio Needs Attention** — one or more players will use fallback, need Apple Music, are preparing without another playable route, or need repair. Offers help; never blocks.

Game Day Checks (device-level, separate from player setup):

- Audio route
- Network reachability
- Apple Music authorization & subscription
- Volume Automation (only flagged if user toggled it on)
- Lineup configured (at least one present player)

The model **rejects**:

- Percentage complete
- Bronze/Silver/Gold tiers
- "Player incomplete" / red error states for incomplete-but-playable players

Discovery is preferred over pressure. Announcer intros are surfaced post-success ("Nice! Want to add announcer intros?") rather than during onboarding.

---

## 10. Data, Sharing, and Recovery

### `.rollcall` packages

A `.rollcall` file is a portable archive of a single team: roster, Player Songs, Custom Clips, generated/local media when available, photos, custom announcer recordings, team identity, and session state. For photos selected under the 1.3 model, it includes the compact profile rendition, clean working master, and both crop geometries; the export disclosure notes that the master can contain more of the scene. Created from Teams -> Share Team Package. Added via Teams -> Import Team Package, Settings -> Import or Export Teams, or by sending the file to the device (Files, AirDrop, etc.).

Import adds the package as a new team and leaves existing teams unchanged. Imports automatically create a recovery backup first. Package preview and import should preserve unavailable items in place and report portability honestly: portable, ready on this device, needs Apple Music, still preparing, or needs repair.

The 1.3 photo additions are additive under the existing package schema. A 1.2 importer can retain the profile rendition while ignoring the master and framing fields; exporting that downgraded team again loses those 1.3-only photo capabilities. Legacy cropped-only photos remain valid in 1.3 and become the best available source until the user selects a replacement.

Support contribution state is not part of `.rollcall` packages. Team sharing should never carry purchase history, gratitude state, subscription status, or anything that suggests one user's support applies to another device/team owner.

### Roster CSV import

Available from Teams -> Team Setup. Imports name + uniform number rows from a CSV; opens a Roster Preview sheet for confirmation before applying. This is a fast way to seed a roster but does not import audio.

### Recovery

Reached from Settings -> Recovery. The screen now leads with **Recently Deleted**, a mixed newest-first list of deleted teams, players, and Custom Clips. Deleted items stay there for 60 days unless restored or permanently deleted. Team restores are full-fidelity; player restores return to the original team and try to rejoin the prior batting-order position while marking the player present today. If a player's original team is still deleted, the row stays visible and explains that the team must be restored first.

Restore is the primary action. Permanent delete is secondary and confirmed item by item. If some saved media is missing, Roll Call explains what could not be recovered and offers a `Restore What We Can` fallback instead of silently restoring a partial result.

The lower part of Recovery still contains manual **Backups**. Automatic backups are taken before package imports and before restoring from a backup. Only the newest 10 are kept. Backups are for returning to an earlier app state, not for everyday deleted-player or deleted-team recovery.

Support contribution state is also outside app backup/restore semantics. StoreKit remains the source of truth for active recurring support; local cached gratitude is only for UI comfort on the current install.

---

## 11. Explicit Constraints & Non-Goals

Be very cautious when proposing features that step on these lines.

**Will not build:**

- Required user accounts
- Cloud sync (manual `.rollcall` sharing is the substitute)
- Social features (no public profiles, no sharing-network)
- Ads of any kind
- Sports management / stats / scoreboard tooling
- Event production software
- Analytics or play-by-play history
- Remote control or multi-device coordination
- Heavy audio engineering tools beyond the current focused clip editor (per-cue gain, detailed mixing, DAW-style editing, etc.)
- Required cloud backups

**Reliability rules:**

- Support contributions must never affect Game Day reliability or feature access.
- Game Day must always do *something* when tapped — fallbacks are mandatory.

**UX rules:**

- No long tutorial carousels.
- No permission barrage (ask only after the user expressed intent).
- No setup-as-homework feel (no percentages, no checklists styled as required).
- No support pressure or guilt prompts after the user has invested setup effort.
- No ratings prompt during Game Day.
- Confirm only irreversible actions; prefer recovery over constant confirmations.

---

## 12. Future direction

The core free experience is established. Future ideas are intentionally exploratory rather than a release commitment. Keep them in [Product Opportunities](./PRODUCT_OPPORTUNITIES.md), where they can be evaluated against real field use, simplicity, and Game Day reliability.

Support contributions remain optional and maintenance-focused; they never create premium tiers or gate the app.

---

## 13. Related current references

- [North Star](./NORTH_STAR.md) — product purpose and non-negotiables.
- [Product Scope](./PRODUCT_SCOPE.md) — durable boundaries and support rules.
- [UX Rulebook](./UX_RULEBOOK.md) — current interaction rules.
- [Readiness Model](./READINESS_MODEL.md) — readiness meanings and tone.
- [Appearance Rules](./APPEARANCE_RULES.md) — Light/Dark and live-screen behavior.
- [Architecture Guardrails](./ARCHITECTURE_GUARDRAILS.md) — data, sharing, and reliability constraints.
- [Product Opportunities](./PRODUCT_OPPORTUNITIES.md) — exploratory future work.
- [Where We Stand](../WHERE_WE_STAND.md) — current implementation status and verification limits.
- [Decisions](../DECISIONS.md) — append-only decision history.
