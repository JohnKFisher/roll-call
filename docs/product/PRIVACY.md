# Roll Call Privacy

Roll Call is an on-device app. Teams, players, saved media choices, photos,
recordings, packages, backups, Recently Deleted items, and support bundles are
not sent as analytics and the Anonymous Usage Analytics preference is not part
of those Roll Call-owned transfer or recovery formats.

## Anonymous Usage Analytics

Anonymous Usage Analytics is on by default. Roll Call sends a small set of
predefined product-use and reliability signals to TelemetryDeck, the analytics
provider. The signals describe coarse actions such as opening a feature, a
confirmed playback route, or a fixed playback failure category. They do not
contain team names, player information, song or media identifiers, filenames,
paths, photos, recordings, free-form text, exact content, or Roll Call-defined
cross-app or cross-device identifiers.

You can turn Anonymous Usage Analytics off in Settings. The opt-out itself is
the only analytics signal allowed during shutdown. Signals already handed to
the TelemetryDeck SDK may still be delivered from its memory or disk cache after
opt-out. Turning analytics back on does not backfill activity that happened
while it was disabled. Roll Call continues the local counters needed for its
product policy while analytics is off, but milestones crossed during that time
are consumed locally and are not sent later.

TelemetryDeck's official SDK uses its default anonymous IDFV-derived identity
and default salt. This identity is not a Roll Call account or a person. It may
survive a Roll Call reinstall while another app from the same vendor remains
installed, so a new local Roll Call store can appear under an existing
anonymous vendor/device identity. The SDK also supplies standard metadata such
as app and SDK version, operating-system and device characteristics, and run or
ingest context. Roll Call does not replace that SDK behavior with a custom
network client.

The SDK batches, retries, and caches signals according to its standard behavior.
TelemetryDeck's current documentation says active query retention depends on
the provider plan and that cold-storage events currently have no guaranteed
deletion schedule; it expects deletion after seven to ten years but does not
guarantee that period. See [TelemetryDeck's privacy FAQ](https://telemetrydeck.com/docs/guides/privacy-faq/)
and [privacy policy](https://telemetrydeck.com/privacy/) for the provider's
current terms.

The local telemetry and rating-policy store is separate from AppState. It is
not included in `.rollcall` packages, Roll Call backups, Recently Deleted,
support bundles, or team duplication. Ordinary iOS device backup may preserve
app-local state, but Roll Call does not use Keychain or iCloud solely to extend
telemetry history across deletion and reinstall.

## Player photos and sharing

When a user selects a new player photo, Roll Call normalizes its orientation,
removes embedded metadata, bounds it to a high-resolution working master, and
uses Apple's on-device Vision framework to suggest profile and Player Card
framings. The photo and Vision observations are not sent to Roll Call,
TelemetryDeck, or another recognition service. Only a coarse allowlisted
detection outcome may be included in Anonymous Usage Analytics after the player
is saved.

New `.rollcall` team packages include the clean working master as well as the
compact profile rendition so the receiving user can adjust both framings. The
master can show more of the scene than the visible profile crop. Sharing a team
package or Player Card is always initiated by the user through the system Share
Sheet.

## Release disclosure checklist

The app privacy manifest declares unlinked, non-tracking Analytics collection
for Product Interaction and Device ID, plus unlinked, non-tracking Other
Diagnostic Data for the fixed reliability signals. The existing UserDefaults
required-reason declaration remains in place for the app's local preferences and
state.

Before an App Store submission, the owner must update App Store Connect privacy
answers and the hosted/public privacy policy to match this implementation and
the provider's then-current terms. The production TelemetryDeck app ID is an
approved release configuration value supplied through the app target's
`Info.plist`.
