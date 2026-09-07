# Codex `/grill-me` Prompt — Roll Call Telemetry Design and Implementation Review

/grill-me

We are preparing a privacy-preserving telemetry implementation for Roll Call.

Before doing anything else, read these two repository documents in full:

1. `TELEMETRY_PRODUCT_INVENTORY.md`
2. `ROLL_CALL_TELEMETRY_SPEC.md`

`TELEMETRY_PRODUCT_INVENTORY.md` is the implementation-grounded inventory of what Roll Call currently does.

`ROLL_CALL_TELEMETRY_SPEC.md` is the current living design/source of truth for the telemetry system we intend to build. It contains every currently planned telemetry signal, its meaning, firing granularity, properties, privacy constraints, the probable-game heuristic, rating-policy changes, and interpretation guidance.

## Your task

Do **not** begin implementation yet.

I want a rigorous `/grill-me` review of the telemetry plan against the actual current codebase.

Your job is to challenge the plan, find assumptions we missed, identify misleading or redundant signals, expose privacy risks, test whether proposed signals can actually be derived reliably from the existing architecture, and force us to make any remaining owner/product decisions before code changes begin.

Be opinionated when the evidence supports it. Do not preserve a bad idea merely because it appears in the spec.

At the same time, do not expand telemetry just because more data is technically available. The governing principle is:

> Collect a signal only when it answers a product/reliability question we could plausibly act on, and collect the minimum data necessary to answer it.

## Important product/privacy intent

The intended model is:

- Apple App Store Connect remains the source for downloads, installations, deletions, crashes, acquisition, and Apple-provided usage/retention.
- TelemetryDeck is intended for anonymous Roll Call-specific product telemetry.
- There should be no onboarding analytics consent dialog.
- There should be no ATT prompt solely for this telemetry.
- Roll Call will provide a clear Settings opt-out for anonymous usage analytics.
- Analytics are enabled by default.
- Turning analytics off stops transmission.
- Turning analytics back on does not backfill historical events.
- Reinstall is a new anonymous installation.
- Team/player/media/user-created content must never be sent.
- Feature code should not call TelemetryDeck directly; Roll Call should own a narrow telemetry abstraction with an explicit event/property allowlist.
- We prefer sparse milestones and per-probable-game aggregates over raw tap streams.

Do not weaken these privacy constraints for convenience.

## Areas I specifically want challenged

### 1. Signal-by-signal validity

For every signal in `ROLL_CALL_TELEMETRY_SPEC.md`, determine:

- Can current Roll Call code reliably know when this happened?
- Is the proposed granularity correct?
- Can it double-fire or fail to fire due to lifecycle/backgrounding/navigation?
- Does backup/restore or team duplication make the semantics misleading?
- Is it redundant with another planned signal or Apple-provided analytics?
- Would we actually act on the result?
- Does any property risk leaking user-generated or unnecessarily identifying information?
- Is there a cheaper/simpler signal that answers the same product question?

Do not mechanically recommend keeping all signals.

### 2. Probable-game heuristic

Current proposed v1:

- 4 successful player cues
- 3 distinct players
- 15+ minutes between first and latest qualifying cue
- at least one 3+ minute inter-cue gap
- Game Day and Clips are one live analytics context
- Clips alone cannot qualify
- repeated-game milestones require different calendar dates

Challenge this aggressively.

Inspect actual Game Day/Clips navigation, foreground/background behavior, playback code, lineup behavior, and any existing session-like state.

I specifically want to know:

- How should the local live analytics session start/end?
- What inactivity timeout is safest?
- What happens when the phone locks, the app backgrounds, or the user switches tabs?
- Can duplicate playback/debounce behavior distort cue counts?
- Should successful intentional Small Cheer playback count as a qualifying cue?
- Can direct-player tile use versus lineup progression affect the heuristic?
- Is 4 cues / 3 players / 15 minutes / one 3-minute gap conservative enough without becoming useless?
- Are there obvious common real-game patterns it would miss?
- Are there obvious setup/test patterns it would falsely classify?
- Can we improve it without location, calendar, user identity, or invasive telemetry?

Do not optimize for perfect certainty; privacy matters more.

### 3. Intentional safety fallback vs reliability failure

This distinction is critical.

If a user has not configured the media needed by the selected playback mode and Roll Call intentionally plays Small Cheer to avoid silence, that is expected behavior.

If configured/intended media was supposed to play but fails/unavailable and Roll Call substitutes Small Cheer, that is a recovery fallback/reliability problem.

Confirm that current playback resolution can reliably distinguish these cases.

Also challenge whether `builtinIntentional` needs subcategories or whether one category is sufficient.

### 4. Music Library vs Apple Music catalog

We want to distinguish actual live use of:

- Music Library
- Apple Music catalog
- imported local media
- intentional built-in safety playback

Verify whether current source/playback state lets us classify Music Library versus catalog reliably at **actual successful playback time**, not merely assignment time.

If preview playback or fallback paths make this ambiguous, explain exactly where and propose the least misleading representation.

### 5. Rating policy change

Current source uses the older 10/20 qualifying Game Day visit model.

The proposed new policy is:

- first automatic Roll Call rating sheet after 2 probable games on different dates
- second opportunity after 5 probable games on different dates
- maximum two automatic asks
- never after the first probable game
- preserve existing safe-presentation gating

The current production UI is Roll Call's custom “Enjoying Roll Call?” sheet; its Rate action opens the App Store review page. Do not confuse this with Apple's native StoreKit review prompt.

Challenge:

- Is 2 then 5 reasonable?
- How should existing users' persisted old-policy counters/attempts migrate?
- How do we ensure an existing user is not suddenly nagged because the policy changed?
- Should previous automatic attempts remain consumed?
- Should old earned-state map into the new policy in any way?
- Can `rating.sheetShown` be emitted only when the sheet actually appears?
- Are the proposed prompt-context buckets sufficient?

There is a known current source/test mismatch around old rating thresholds. Account for it.

### 6. Team personalized milestone

Current proposed v1:

- at least 3 players
- at least 75% of present players have a user-selected song and/or recorded announcement
- automatic Small Cheer does not count

Challenge whether this milestone is semantically useful and whether 75% is the right threshold.

Remember that Roll Call intentionally allows fallback-only/incomplete teams to be usable, so do not call this general “readiness.”

### 7. Settings/default telemetry

We currently plan first-change-from-default telemetry for six global settings plus per-team accent and announcer mode.

Challenge whether:

- first change is the right semantic,
- per-team versus per-install granularity is correct,
- users who change away and later return to default create interpretation problems,
- any setting should instead be measured at probable-game use,
- any of these signals are not worth collecting.

Accent should also be recorded on `game.probable` so we can see what colors actually reach live use, while remembering that the default will naturally be overrepresented.

### 8. Retention

Planned app-return milestones:

- Day 1
- Day 7
- Day 30
- Day 90
- Day 180
- Day 365

Planned product-retention milestones:

- probable game 1
- 2
- 5
- 10
- 25
- 50 distinct dates

Challenge local timestamp/state requirements, restore behavior, clock changes, and whether these milestones remain interpretable.

### 9. Failure telemetry

Review the proposed sparse failure set:

- recovery fallback aggregate per probable game/source family
- complete playback failure
- package import failure
- CSV import failure
- manual backup failure
- restore failure
- state recovery triggered
- first repair needed/completed by coarse category
- Music permission denial
- microphone permission denial

Look for:

- failures that are too implementation-specific,
- failures that will be noisy,
- missing severe user-impacting failures,
- cases where reason classification would require unsafe/raw error data,
- duplicate coverage with Apple's crash analytics or the existing manual support bundle.

We do **not** currently plan broad background media-preparation retry telemetry.

### 10. TelemetryDeck/privacy implementation

Inspect the current `PrivacyInfo.xcprivacy` and app privacy surface.

Before implementation, identify:

- exactly what TelemetryDeck SDK integration would add,
- required App Store privacy disclosure changes,
- whether the privacy manifest needs modification,
- whether TelemetryDeck automatically sends fields that are not reflected in our signal document,
- how to implement an allowlist so arbitrary parameters cannot leak into events,
- how to ensure disabled analytics truly sends nothing,
- how to avoid accidental historical backfill,
- how anonymous installation/session identity behaves,
- whether any SDK defaults conflict with our reinstall/privacy intent.

Use current authoritative TelemetryDeck/Apple documentation if repository knowledge is insufficient or potentially stale.

## Deliverable from this `/grill-me`

Do not write implementation code yet.

Work through the issues interactively with me as `/grill-me` normally would. Ask owner/product questions only where a real decision is needed; do not ask me to decide implementation details you can resolve by inspecting the code.

As decisions are made during the discussion:

### KEEP `ROLL_CALL_TELEMETRY_SPEC.md` UP TO DATE

This is mandatory.

Whenever our discussion changes:

- a signal,
- event name,
- firing rule,
- granularity,
- property,
- bucket,
- privacy rule,
- heuristic,
- rating rule,
- interpretation note,
- or local-only state requirement,

update `ROLL_CALL_TELEMETRY_SPEC.md` in the same working session.

Do not leave the Markdown spec reflecting an older decision while the conversation moves on.

At the end of `/grill-me`, provide:

1. A concise list of decisions changed from the initial spec.
2. Any remaining unresolved owner decisions.
3. A proposed implementation plan, but **do not implement until explicitly told to proceed**.
4. Confirmation that `ROLL_CALL_TELEMETRY_SPEC.md` matches the final agreed design.
5. Any tests/migrations/privacy-document changes that will be required.

## Guardrail

Telemetry is not the user-facing feature for this release.

We intend to ship this telemetry work alongside a meaningful user-facing Roll Call improvement so users are not asked to install an update whose value is only for the developer. Do not let telemetry implementation silently balloon into an unrelated feature project, but keep this release constraint visible when planning.
