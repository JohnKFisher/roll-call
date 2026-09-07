# Working Changelog

Internal notes for building public-facing changelogs. Keep entries understandable to non-technical users, but not fully polished.


## Unreleased

### Added

- Create and share a personalized 4:5 Player Card from any player, using the team identity, player photo, name and number, and walk-up song when available. [public candidate]
- New photos keep a clean high-resolution working master and use on-device smart framing for both profile images and Player Cards; each framing can be adjusted independently. [public candidate]
- Open Game Day from Shortcuts or the iOS 18 Control Center and Lock Screen control, with optional team selection for advanced shortcuts and automatic use of the most recently used Game Day team otherwise. [public candidate]
- Added permanent Quick Game Day guidance in Settings and 1.3 feature introductions in What's New. [public candidate]

### Changed

- Team packages now carry the clean player-photo working master and both framings while retaining the existing package schema so 1.2 imports remain possible as a lossy downgrade. [public candidate]


### Fixed


### Reliability / Data Safety
- Support purchases now listen for StoreKit transaction updates from app launch, so delayed completions, pending approvals, and recurring support changes are less likely to be missed. [public candidate]
- Local song clip generation now cancels cleanly through Swift task cancellation and removes incomplete temporary output. [public candidate]

### Internal / Maintenance
