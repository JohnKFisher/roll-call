# Roll Call — Project Instructions

Follow the global Codex instructions and conditional rules from the active `$CODEX_HOME`.

## Identity and North Star

Roll Call is the public App Store app `Roll Call: Walk-Up Music`.

Keep the existing bundle identifier. Do not propose or perform a bundle-ID migration unless the owner explicitly requests it.

**Game Day is the product. Everything else supports Game Day.**

Product priorities, in order:

1. Easy
2. Personal
3. Cool
4. Professional

Preparation is for decisions. Game Day is for execution. Protect reliability in the live moment above configurability, feature count, monetization, or architectural cleverness.

## Core product invariants

- A coach should be able to tap a player during Game Day and have something appropriate happen immediately.
- Preserve the graceful playback fallback chain. Game Day must never fail silently because ideal media is unavailable.
- Team state is durable; Game Day/session state is temporary. Restore useful context rather than inventing a formal game-session model.
- Lineup order is distinct from roster/player ordering.
- Preserve player/team setup, saved media choices, and source-backed repair information rather than discarding unavailable content.
- Preserve backward compatibility for existing user data and `.rollcall` packages unless an intentional migration is approved.
- User teams belong to the user. Manual `.rollcall` import/export is a core ownership, sharing, and backup mechanism.
- Imports must not overwrite existing teams unexpectedly.
- Support/purchase state must never travel with team exports or backups.

## Media and live-use reliability

Apple Music authorization, Music Library access, local/generated clips, player songs, Announcement Cues, Custom Clips, readiness, playback, and fallback behavior are protected product areas.

When ideal playback cannot execute, preserve the established intent:

1. intro + song;
2. song only;
3. intro only;
4. generic cheering fallback.

Do not silently discard a saved song/source merely because it is unavailable on the current device. Preserve enough source truth to explain, repair, or regenerate it where possible.

Live playback takes priority over background preparation or maintenance work.

## Readiness

Readiness answers: **If the user opens Game Day right now, will this feel good in front of people?**

It is not a completion score.

- Never use percentage-complete or Bronze/Silver/Gold-style readiness.
- Never turn optional polish into setup debt.
- Missing photos, announcer intros, themes, or similar enhancements do not make a player incomplete.
- Be honest about portable versus device-dependent playback.
- Readiness may warn and offer repair actions, but must not block Game Day.
- Encourage rather than shame; reveal enhancements after success rather than forcing them during onboarding.

## Product boundaries

All app features remain free. Optional support contributions may support development but must never unlock features, affect readiness, improve reliability, alter exports, or interrupt live use.

Do not add or expand required accounts, cloud sync, social/network features, ads, analytics, generalized sports-management/statistics/scoreboard systems, remote-control infrastructure, heavy DAW-style audio editing, or required cloud backup unless the owner explicitly chooses a new product direction.

Future ideas in `PRODUCT_OPPORTUNITIES.md` are exploratory opportunities, not an approved roadmap. Prefer improvements driven by real field use and observed friction over feature accumulation.

## UX and appearance

- Keep setup approachable; avoid tutorial overload, permission barrages, and setup-as-homework.
- Ask for permissions after the user expresses intent, not preemptively.
- Confirm irreversible actions; prefer recovery over repeated defensive confirmations.
- Never interrupt Game Day with ratings, support solicitation, or unrelated prompts.
- `Game Day` and `Clips` are the live screens. Preserve their deliberate live-use behavior.
- Do not force a global color scheme merely to make live screens dark.
- Preserve semantic warning, destructive, readiness, disabled, and playback colors independently from team identity/accent colors.

## Recovery and destructive operations

Prefer recoverability over immediate destruction.

Recently Deleted is the normal recovery path for supported deleted teams, players, and Custom Clips. Permanent deletion is secondary and explicit.

When recovery is incomplete because media is missing, explain the limitation rather than silently presenting a partial restore as complete.

## Documentation authority

Current implementation and current product decisions win over historical plans.

Use:

- `docs/WHERE_WE_STAND.md` for current status and known limitations;
- `docs/DECISIONS.md` for approved, reversed, and superseded decisions;
- `docs/product/NORTH_STAR.md` for product purpose and non-negotiables;
- `docs/product/APP_OVERVIEW.md` for current flows and vocabulary;
- `docs/product/PRODUCT_SCOPE.md` for durable scope boundaries;
- `docs/product/UX_RULEBOOK.md` for interaction/live-use rules;
- `docs/product/READINESS_MODEL.md` for readiness semantics;
- `docs/product/APPEARANCE_RULES.md` for appearance behavior;
- `docs/product/ARCHITECTURE_GUARDRAILS.md` for data, ownership, sharing, and reliability constraints;
- `docs/product/PRODUCT_OPPORTUNITIES.md` for exploratory ideas only.

Read historical documentation only when historical context is actually needed.

If implementation, current documentation, and an established product invariant conflict, surface the conflict rather than silently reinterpreting product intent.

`docs/product/PUBLIC_CHANGELOG.md` is human-curated. Do not edit it unless explicitly asked.