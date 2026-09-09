import Foundation
import XCTest
@testable import RollCall

private final class TelemetryWriteProbe: @unchecked Sendable {
    let lock = NSLock()
    var writeCount = 0
    var wasMainThread = false
    var lastData: Data?

    func snapshot() -> (writeCount: Int, wasMainThread: Bool, lastData: Data?) {
        lock.lock()
        defer { lock.unlock() }
        return (writeCount, wasMainThread, lastData)
    }
}

@MainActor
final class TelemetryTests: XCTestCase {
    private var temporaryDirectory: RollCallTemporaryDirectory!

    override func setUpWithError() throws {
        temporaryDirectory = try RollCallTemporaryDirectory()
    }

    override func tearDownWithError() throws {
        temporaryDirectory = nil
    }

    private func makeCoordinator(
        now: Date = RollCallTestFixtures.now,
        context: TelemetryBuildContext = TelemetryBuildContext(
            isAppStoreBuild: false,
            isTestFlightBuild: false,
            isDeveloperBuild: true,
            isSwiftUIPreview: false
        ),
        legacyAutomaticAttemptCount: Int = 0
    ) -> (RollCallTelemetryCoordinator, RecordingTelemetryProvider, TelemetryStore) {
        let provider = RecordingTelemetryProvider()
        let store = TelemetryStore(
            url: temporaryDirectory.fileURL("telemetry-state.json"),
            now: now,
            legacyAutomaticAttemptCount: legacyAutomaticAttemptCount
        )
        let defaults = UserDefaults(suiteName: "RollCallTelemetryTests.\(UUID().uuidString)")!
        let preference = AnonymousUsageAnalyticsPreference(defaults: defaults)
        let coordinator = RollCallTelemetryCoordinator(
            provider: provider,
            store: store,
            preference: preference,
            buildContext: context
        )
        return (coordinator, provider, store)
    }

    func testAllowlistRejectsUnknownNamesIdentifiersAndArbitraryStrings() {
        XCTAssertThrowsError(try RollCallTelemetryValidator.shared.validate(eventName: "madeUp.event"))
        XCTAssertThrowsError(try RollCallTelemetryValidator.shared.validate(eventName: RollCallTelemetryEvent.liveEntered.rawValue, properties: ["freeText": "anything"]))
        XCTAssertThrowsError(try RollCallTelemetryValidator.shared.validate(eventName: RollCallTelemetryEvent.gamePlaybackModeUsed.rawValue, properties: ["mode": "coach-custom-mode"]))
        XCTAssertThrowsError(try RollCallTelemetryValidator.shared.validate(eventName: RollCallTelemetryEvent.liveEntered.rawValue, properties: ["appVersion": "1.2.3"]))
        XCTAssertThrowsError(try RollCallTelemetryValidator.shared.validate(eventName: RollCallTelemetryEvent.liveEntered.rawValue, properties: ["buildNumber": "82"]))
        XCTAssertThrowsError(try RollCallTelemetryValidator.shared.validate(event: .gameRecoveryPathUsed, properties: [.sourceFamily: "builtinIntentional"]))
    }

    func testEveryEventStartsWithAnExplicitAllowlistEntry() throws {
        for event in RollCallTelemetryEvent.allCases {
            XCTAssertNoThrow(try RollCallTelemetryValidator.shared.validate(event: event), "Missing event allowlist entry for \(event.rawValue)")
        }
        XCTAssertNoThrow(try RollCallTelemetryValidator.shared.validate(
            event: .liveEntered,
            properties: [.telemetrySchemaVersion: "1"]
        ))
        XCTAssertThrowsError(try RollCallTelemetryValidator.shared.validate(
            event: .liveEntered,
            properties: [.telemetrySchemaVersion: "2"]
        ))
        XCTAssertNoThrow(try RollCallTelemetryValidator.shared.validate(
            event: .stateRecoveryTriggered,
            properties: [.reason: "unsupportedSchema"]
        ))
        XCTAssertNoThrow(try RollCallTelemetryValidator.shared.validate(
            event: .stateRecoveryTriggered,
            properties: [.reason: "loadFailure"]
        ))
    }

    func testPlayerCardAndQuickGameDayPropertiesAreCoarseAndAllowlisted() throws {
        XCTAssertNoThrow(try RollCallTelemetryValidator.shared.validate(
            event: .playerPhotoDetectionCompleted,
            properties: [.detection: "faceAndPerson"]
        ))
        XCTAssertNoThrow(try RollCallTelemetryValidator.shared.validate(
            event: .quickGameDayInvoked,
            properties: [.source: "systemControl"]
        ))
        XCTAssertNoThrow(try RollCallTelemetryValidator.shared.validate(
            event: .quickGameDayTargetResolved,
            properties: [.target: "rememberedTeam"]
        ))
        XCTAssertNoThrow(try RollCallTelemetryValidator.shared.validate(
            event: .quickGameDayFallback,
            properties: [.reason: "rememberedTeamMissing"]
        ))

        XCTAssertThrowsError(try RollCallTelemetryValidator.shared.validate(
            event: .playerPhotoDetectionCompleted,
            properties: [.detection: "Taylor Smith"]
        ))
        XCTAssertThrowsError(try RollCallTelemetryValidator.shared.validate(
            event: .quickGameDayInvoked,
            properties: [.source: "Northside Falcons"]
        ))
        XCTAssertThrowsError(try RollCallTelemetryValidator.shared.validate(
            event: .quickGameDayTargetResolved,
            properties: [.target: UUID().uuidString]
        ))
    }

    func testBuildContextsExplicitlySelectTestMode() {
        let developer = TelemetryBuildContext(isAppStoreBuild: false, isTestFlightBuild: false, isDeveloperBuild: true, isSwiftUIPreview: false)
        let testFlight = TelemetryBuildContext(isAppStoreBuild: false, isTestFlightBuild: true, isDeveloperBuild: false, isSwiftUIPreview: false)
        let appStore = TelemetryBuildContext(isAppStoreBuild: true, isTestFlightBuild: false, isDeveloperBuild: false, isSwiftUIPreview: false)

        XCTAssertTrue(developer.testMode)
        XCTAssertTrue(testFlight.testMode)
        XCTAssertFalse(appStore.testMode)
    }

    func testProviderAndPreviewTestDoublesNeverNeedNetworking() {
        let provider = NullTelemetryProvider()
        provider.configure(enabled: true, context: TelemetryBuildContext(isAppStoreBuild: false, isTestFlightBuild: false, isDeveloperBuild: true, isSwiftUIPreview: true))
        provider.send(RollCallTelemetrySignal(event: .liveEntered, properties: [:]))
        XCTAssertTrue(true, "The null provider is intentionally a no-network test/preview seam.")
    }

    #if canImport(TelemetryDeck)
    func testTelemetryDeckConfigurationIsCompleteBeforeInitialization() {
        let provider = TelemetryDeckProvider(appID: "test-app-id")
        provider.configure(
            enabled: false,
            context: TelemetryBuildContext(isAppStoreBuild: false, isTestFlightBuild: false, isDeveloperBuild: true, isSwiftUIPreview: true)
        )
        XCTAssertEqual(provider.configurationSnapshot?.appID, "test-app-id")
        XCTAssertEqual(provider.configurationSnapshot?.analyticsDisabled, true)
        XCTAssertEqual(provider.configurationSnapshot?.testMode, true)
        XCTAssertEqual(provider.configurationSnapshot?.sendNewSessionBeganSignal, false)
        XCTAssertEqual(provider.configurationSnapshot?.sessionStatsEnabled, false)
    }
    #endif

    func testDisabledLaunchAndTransitionsPreserveCachedSemanticsWithoutBackfill() {
        let defaults = UserDefaults(suiteName: "RollCallTelemetryTests.Disabled.\(UUID().uuidString)")!
        defaults.set(false, forKey: AnonymousUsageAnalyticsPreference.key)
        let preference = AnonymousUsageAnalyticsPreference(defaults: defaults)
        let provider = RecordingTelemetryProvider()
        let store = TelemetryStore(url: temporaryDirectory.fileURL("disabled.json"), now: RollCallTestFixtures.now)
        let coordinator = RollCallTelemetryCoordinator(
            provider: provider,
            store: store,
            preference: preference,
            buildContext: TelemetryBuildContext(isAppStoreBuild: false, isTestFlightBuild: false, isDeveloperBuild: true, isSwiftUIPreview: false)
        )

        XCTAssertEqual(provider.configurationSnapshots.first?.analyticsDisabled, true)
        coordinator.record(.onboardingStarted)
        coordinator.recordOnce(.playerPlaybackFirstSuccessful)
        XCTAssertFalse(provider.signals.contains { $0.event == .onboardingStarted })
        XCTAssertTrue(store.state.suppressedEvents.contains(RollCallTelemetryEvent.playerPlaybackFirstSuccessful.rawValue))

        coordinator.setAnalyticsEnabled(true)
        XCTAssertEqual(provider.signals.map(\.event), [.analyticsPreferenceChanged])
        coordinator.recordOnce(.playerPlaybackCount10)
        XCTAssertEqual(provider.signals.map(\.event), [.analyticsPreferenceChanged, .playerPlaybackCount10])
        XCTAssertFalse(provider.signals.contains { $0.event == .onboardingStarted })
        XCTAssertEqual(provider.configurationSnapshots.map(\.analyticsDisabled), [true, false])
    }

    func testExistingInstallEnrollmentInfersOnlyCurrentStateAndIsIdempotent() {
        let (coordinator, provider, store) = makeCoordinator()
        coordinator.enroll(currentState: RollCallTestFixtures.appState(team: RollCallTestFixtures.team()))

        XCTAssertEqual(store.state.enrollmentCohort, "existingInstall")
        XCTAssertTrue(store.state.baselineCompleted)
        XCTAssertFalse(provider.signals.isEmpty)
        XCTAssertTrue(provider.signals.allSatisfy { $0.properties[RollCallTelemetryProperty.observationOrigin.rawValue] == "enrollmentBaseline" })
        let firstSignalCount = provider.signals.count
        coordinator.enroll(currentState: RollCallTestFixtures.appState(team: RollCallTestFixtures.team()))
        XCTAssertEqual(provider.signals.count, firstSignalCount)
    }

    /// A Music Library pick is recorded with `libraryPersistentID` set *and*
    /// `isCatalogBacked == true` — the song really is in the catalog. The classifiers
    /// used to require `isCatalogBacked == false` for `.musicLibrary`, a combination
    /// the app never produces, so `mediaFirstAssignedMusicLibrary` was unreachable
    /// and every Music Library assignment was counted as a catalog assignment.
    func testMusicLibraryAssignmentEmitsItsOwnMilestoneNotTheCatalogOne() {
        let (coordinator, provider, store) = makeCoordinator()
        var player = RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex", number: "1")
        player.songAssignment = .privateClip(SongClip(cue: musicLibraryCue()))

        coordinator.enroll(currentState: RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [player])))

        XCTAssertTrue(
            provider.signals.contains { $0.event == .mediaFirstAssignedMusicLibrary },
            "Music Library is the primary song path and must report as itself."
        )
        XCTAssertFalse(
            provider.signals.contains { $0.event == .mediaFirstAssignedAppleMusicCatalog },
            "A Music Library pick must not be counted as an Apple Music catalog assignment."
        )
        XCTAssertTrue(store.state.baselineCompleted)
    }

    /// A catalog-only pick (no library id) must still report as catalog, so the fix
    /// above cannot have simply relabelled everything.
    func testAppleMusicCatalogAssignmentStillEmitsTheCatalogMilestone() {
        let (coordinator, provider, _) = makeCoordinator()
        var player = RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex", number: "1")
        player.songAssignment = .privateClip(SongClip(cue: RollCallTestFixtures.appleMusicCue(
            songID: "catalog-song",
            title: "Catalog Song",
            artistName: "Artist"
        )))

        coordinator.enroll(currentState: RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [player])))

        XCTAssertTrue(provider.signals.contains { $0.event == .mediaFirstAssignedAppleMusicCatalog })
        XCTAssertFalse(provider.signals.contains { $0.event == .mediaFirstAssignedMusicLibrary })
    }

    /// The classifier is shared by playback, recovery and assignment reporting. These
    /// are the exact shapes the app constructs: `SongPickerFlow` sets a library id
    /// with `isCatalogBacked: true` for a library pick, leaves the id nil for a
    /// catalog search hit, and sets `isCatalogBacked: false` for an iTunes preview.
    func testPlaybackSourceFamilyDistinguishesLibraryCatalogAndPreview() {
        XCTAssertEqual(musicLibraryCue().source.playbackSourceFamily, .musicLibrary)

        XCTAssertEqual(
            RollCallTestFixtures.appleMusicCue(songID: "c", title: "C", artistName: "A").source.playbackSourceFamily,
            .appleMusicCatalog
        )

        let preview = Cue(
            id: UUID(),
            label: "Preview",
            source: .appleMusic(AppleMusicSource(
                songID: "12345",
                title: "Preview",
                artistName: "Artist",
                duration: 30,
                previewURL: URL(string: "https://example.com/p.m4a"),
                isCatalogBacked: false,
                libraryPersistentID: nil
            )),
            startTime: 0,
            duration: 12,
            fadeOutDuration: 0.35,
            pauseAfterAnnouncer: 0.2
        )
        XCTAssertEqual(preview.source.playbackSourceFamily, .appleMusicPreview)

        XCTAssertEqual(RollCallTestFixtures.localCue().source.playbackSourceFamily, .importedLocal)
    }

    /// Mirrors `SongPickerFlow.openEditorForLibrarySelection`: a library item that
    /// exposes a `playbackStoreID` is catalog-backed *and* carries a library id.
    private func musicLibraryCue() -> Cue {
        Cue(
            id: UUID(),
            label: "Library Song",
            source: .appleMusic(AppleMusicSource(
                songID: "store-id-1",
                title: "Library Song",
                artistName: "Artist",
                duration: 210,
                previewURL: nil,
                isCatalogBacked: true,
                libraryPersistentID: 987_654_321
            )),
            startTime: 0,
            duration: 12,
            fadeOutDuration: 0.35,
            pauseAfterAnnouncer: 0.2
        )
    }

    func testExistingInstallBaselineKeepsTeamScopedMilestonesDistinct() {
        var firstTeam = RollCallTestFixtures.team()
        firstTeam.accentPreset = .blue
        var secondTeam = RollCallTestFixtures.team()
        secondTeam.id = UUID()
        secondTeam.accentPreset = .red
        secondTeam.session.gameDayAnnouncerMode = .songOnly

        let (coordinator, provider, store) = makeCoordinator()
        coordinator.enroll(currentState: RollCallTestFixtures.appState(
            teams: [firstTeam, secondTeam],
            selectedTeamID: firstTeam.id
        ))

        let accentSignals = provider.signals.filter { $0.event == .teamAccentFirstChanged }
        XCTAssertEqual(accentSignals.count, 2)
        XCTAssertEqual(Set(accentSignals.compactMap { $0.properties[RollCallTelemetryProperty.newAccent.rawValue] }), Set(["blue", "red"]))
        XCTAssertTrue(store.state.consumedTeamEvents.contains("\(firstTeam.id.uuidString)|\(RollCallTelemetryEvent.teamAccentFirstChanged.rawValue)"))
        XCTAssertTrue(store.state.consumedTeamEvents.contains("\(secondTeam.id.uuidString)|\(RollCallTelemetryEvent.teamAccentFirstChanged.rawValue)"))
        XCTAssertTrue(store.state.consumedTeamEvents.contains("\(secondTeam.id.uuidString)|\(RollCallTelemetryEvent.announcerModeFirstChanged.rawValue)"))

        coordinator.recordOnce(
            .teamAccentFirstChanged,
            properties: [.newAccent: "red"],
            teamID: secondTeam.id
        )
        XCTAssertEqual(provider.signals.filter { $0.event == .teamAccentFirstChanged }.count, 2)
    }

    func testLegacyRatingAttemptMigrationPreservesZeroOneAndTwo() {
        for attempts in 0...2 {
            let provider = RecordingTelemetryProvider()
            let store = TelemetryStore(
                url: temporaryDirectory.fileURL("legacy-\(attempts).json"),
                now: RollCallTestFixtures.now,
                legacyAutomaticAttemptCount: attempts
            )
            let defaults = UserDefaults(suiteName: "RollCallTelemetryTests.Legacy.\(attempts).\(UUID().uuidString)")!
            let coordinator = RollCallTelemetryCoordinator(
                provider: provider,
                store: store,
                preference: AnonymousUsageAnalyticsPreference(defaults: defaults),
                buildContext: TelemetryBuildContext(isAppStoreBuild: true, isTestFlightBuild: false, isDeveloperBuild: false, isSwiftUIPreview: false)
            )
            coordinator.enroll(currentState: .empty)
            XCTAssertEqual(store.state.rating.automaticAttemptsConsumed, attempts)
            XCTAssertNil(RollCallRatingPolicy.automaticOpportunity(for: store.state.rating, now: RollCallTestFixtures.now))
        }
    }

    func testUnsupportedSchemaIsUntouchedAndDisablesOrdinaryPolicy() throws {
        let url = temporaryDirectory.fileURL("future.json")
        try #"{"schemaVersion":2,"sentinel":"preserve"}"#.data(using: .utf8)!.write(to: url)
        let original = try Data(contentsOf: url)
        let store = TelemetryStore(url: url, now: RollCallTestFixtures.now)
        let provider = RecordingTelemetryProvider()
        let defaults = UserDefaults(suiteName: "RollCallTelemetryTests.Future.\(UUID().uuidString)")!
        let coordinator = RollCallTelemetryCoordinator(provider: provider, store: store, preference: AnonymousUsageAnalyticsPreference(defaults: defaults))

        XCTAssertEqual(store.status, .unsupported)
        XCTAssertFalse(coordinator.isAvailableForProductPolicy)
        coordinator.recordOnce(.liveEntered)
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertNotNil(coordinator.reserveRatingPresentation(source: .manual))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testCorruptStoreIsQuarantinedAndRecoveryIsPersistedBeforeRecoverySignal() throws {
        let url = temporaryDirectory.fileURL("corrupt.json")
        try Data("not-json".utf8).write(to: url)
        let store = TelemetryStore(url: url, now: RollCallTestFixtures.now)
        XCTAssertEqual(store.status, .recovered)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "The corrupt source is quarantined before replacement persistence.")

        let provider = RecordingTelemetryProvider()
        let defaults = UserDefaults(suiteName: "RollCallTelemetryTests.Corrupt.\(UUID().uuidString)")!
        let coordinator = RollCallTelemetryCoordinator(provider: provider, store: store, preference: AnonymousUsageAnalyticsPreference(defaults: defaults))
        coordinator.enroll(currentState: .empty)

        XCTAssertTrue(provider.signals.contains { $0.event == .telemetryStateRecovered })
        XCTAssertEqual(store.state.enrollmentCohort, "existingInstall")
        XCTAssertTrue(store.state.rating.permanentlySuppressed)
        let quarantined = try FileManager.default.contentsOfDirectory(at: temporaryDirectory.url, includingPropertiesForKeys: nil)
        XCTAssertTrue(quarantined.contains { $0.lastPathComponent.hasPrefix("corrupt.corrupt-") })
    }

    func testRuntimeStoreSaveFailureSuspendsAndUsesNarrowReliabilitySignal() {
        let (coordinator, provider, store) = makeCoordinator()
        store.writeOverride = { _, _ in throw NSError(domain: "test", code: 1) }
        coordinator.recordOnce(.liveEntered)

        XCTAssertTrue(store.state.suspended)
        XCTAssertFalse(coordinator.isAvailableForProductPolicy)
        XCTAssertEqual(provider.signals.filter { $0.event == .telemetryStatePersistenceFailed }.count, 1)

        coordinator.recordOnce(.playerPlaybackFirstSuccessful)
        XCTAssertFalse(store.state.consumedInstallEvents.contains(RollCallTelemetryEvent.playerPlaybackFirstSuccessful.rawValue))
        store.writeOverride = nil
        XCTAssertTrue(coordinator.retryPersistence())
        coordinator.recordOnce(.playerPlaybackFirstSuccessful)
        XCTAssertTrue(store.state.consumedInstallEvents.contains(RollCallTelemetryEvent.playerPlaybackFirstSuccessful.rawValue))
    }

    func testPersistBeforeEnqueueAllowsAcceptedFalseNegative() {
        let (coordinator, provider, store) = makeCoordinator()
        coordinator.recordOnce(.liveEntered)
        XCTAssertTrue(store.state.consumedInstallEvents.contains(RollCallTelemetryEvent.liveEntered.rawValue))
        XCTAssertEqual(provider.signals.map(\.event), [.liveEntered])

        store.writeOverride = { _, _ in throw NSError(domain: "test", code: 2) }
        coordinator.recordOnce(.playerPlaybackFirstSuccessful)
        XCTAssertFalse(provider.signals.contains { $0.event == .playerPlaybackFirstSuccessful })
        XCTAssertFalse(store.state.consumedInstallEvents.contains(RollCallTelemetryEvent.playerPlaybackFirstSuccessful.rawValue))
    }

    func testProbableGameBoundariesAndDoubleheaderDateDeduplication() {
        let teamID = RollCallTestFixtures.teamID
        let playerIDs = [RollCallTestFixtures.alexID, RollCallTestFixtures.jordanID, RollCallTestFixtures.caseyID]
        let start = RollCallTestFixtures.now
        var checkpoint: LiveAnalyticsCheckpoint?
        XCTAssertFalse(LiveAnalyticsSessionReducer.playerCue(checkpoint: &checkpoint, teamID: teamID, playerID: playerIDs[0], now: start, sourceFamily: .importedLocal))
        XCTAssertFalse(LiveAnalyticsSessionReducer.playerCue(checkpoint: &checkpoint, teamID: teamID, playerID: playerIDs[1], now: start.addingTimeInterval(180), sourceFamily: .importedLocal))
        XCTAssertFalse(LiveAnalyticsSessionReducer.playerCue(checkpoint: &checkpoint, teamID: teamID, playerID: playerIDs[2], now: start.addingTimeInterval(900), sourceFamily: .importedLocal))
        XCTAssertTrue(LiveAnalyticsSessionReducer.playerCue(checkpoint: &checkpoint, teamID: teamID, playerID: playerIDs[0], now: start.addingTimeInterval(900), sourceFamily: .importedLocal))
        XCTAssertEqual(checkpoint?.qualifyingCueCount, 4)
        XCTAssertEqual(checkpoint?.distinctPlayerIDs.count, 3)
        XCTAssertTrue(checkpoint?.hasThreeMinuteGap == true)

        let dates = RollCallRatingPolicy.distinctLocalDates([start, start.addingTimeInterval(60), start.addingTimeInterval(86_400)])
        XCTAssertEqual(dates.count, 2)

        var justBelowSpan: LiveAnalyticsCheckpoint?
        XCTAssertFalse(LiveAnalyticsSessionReducer.playerCue(checkpoint: &justBelowSpan, teamID: teamID, playerID: playerIDs[0], now: start, sourceFamily: .importedLocal))
        XCTAssertFalse(LiveAnalyticsSessionReducer.playerCue(checkpoint: &justBelowSpan, teamID: teamID, playerID: playerIDs[1], now: start.addingTimeInterval(180), sourceFamily: .importedLocal))
        XCTAssertFalse(LiveAnalyticsSessionReducer.playerCue(checkpoint: &justBelowSpan, teamID: teamID, playerID: playerIDs[2], now: start.addingTimeInterval(899), sourceFamily: .importedLocal))
        XCTAssertFalse(LiveAnalyticsSessionReducer.playerCue(checkpoint: &justBelowSpan, teamID: teamID, playerID: playerIDs[0], now: start.addingTimeInterval(899), sourceFamily: .importedLocal))

        var justBelowGap: LiveAnalyticsCheckpoint?
        XCTAssertFalse(LiveAnalyticsSessionReducer.playerCue(checkpoint: &justBelowGap, teamID: teamID, playerID: playerIDs[0], now: start, sourceFamily: .importedLocal))
        XCTAssertFalse(LiveAnalyticsSessionReducer.playerCue(checkpoint: &justBelowGap, teamID: teamID, playerID: playerIDs[1], now: start.addingTimeInterval(179), sourceFamily: .importedLocal))
        XCTAssertFalse(LiveAnalyticsSessionReducer.playerCue(checkpoint: &justBelowGap, teamID: teamID, playerID: playerIDs[2], now: start.addingTimeInterval(358), sourceFamily: .importedLocal))
        XCTAssertFalse(LiveAnalyticsSessionReducer.playerCue(checkpoint: &justBelowGap, teamID: teamID, playerID: playerIDs[0], now: start.addingTimeInterval(537), sourceFamily: .importedLocal))
        XCTAssertFalse(justBelowGap?.hasThreeMinuteGap == true)
    }

    func testDoubleheaderCreatesTwoRawGamesButOneDateMilestone() async {
        let (coordinator, provider, store) = makeCoordinator()
        let teamID = RollCallTestFixtures.teamID
        let playerIDs = [RollCallTestFixtures.alexID, RollCallTestFixtures.jordanID, RollCallTestFixtures.caseyID]
        let base = store.state.enrollmentDate

        // Cue offsets 0s / 180s / 900s / 900s across three distinct players. Per
        // spec section 4.2 the session qualifies only on the fourth cue, when all
        // four conditions hold together: >= 4 cues, >= 3 distinct players,
        // >= 15 minutes of span (900s, inclusive), and a >= 3 minute gap (the 180s
        // step, inclusive).
        //
        // Qualification is asserted through the emitted `game.probable` signal, not
        // through `handlePlayerPlayback`'s return value. That return value means
        // "this cue was accepted and recorded" — a single confirmed cue returns
        // `true`, as `testStructuredPlaybackRequiresCorrelatedConfirmedStart` pins
        // down. This test previously read it as a qualification flag and so expected
        // `false` for the first three cues.
        func playGame(start: Date) async {
            let probableGamesBefore = provider.signals.filter { $0.event == .gameProbable }.count
            for (index, playerID) in [playerIDs[0], playerIDs[1], playerIDs[2], playerIDs[0]].enumerated() {
                let requestID = UUID()
                let result = PlaybackRequestResult(
                    requestID: requestID,
                    confirmations: [PlaybackStartConfirmation(requestID: requestID, component: .primaryCue, sourceFamily: .importedLocal, outcome: .started)],
                    wasDebounced: false
                )
                XCTAssertTrue(
                    coordinator.handlePlayerPlayback(
                        teamID: teamID,
                        playerID: playerID,
                        result: result,
                        now: start.addingTimeInterval(TimeInterval([0, 180, 900, 900][index]) )
                    ),
                    "Every confirmed cue must be recorded (cue \(index))."
                )
                await coordinator.waitForPendingPersistenceForTesting()

                // The boundary: nothing qualifies until the fourth cue.
                let probableGamesNow = provider.signals.filter { $0.event == .gameProbable }.count
                XCTAssertEqual(
                    probableGamesNow - probableGamesBefore,
                    index == 3 ? 1 : 0,
                    "Session must qualify on the fourth cue and no earlier (cue \(index))."
                )
            }
        }

        await playGame(start: base)
        coordinator.handleTeamBoundaryChange()
        await coordinator.waitForPendingPersistenceForTesting()
        await playGame(start: base.addingTimeInterval(1_800))
        await coordinator.waitForPendingPersistenceForTesting()

        XCTAssertEqual(store.state.probableGameDates.count, 2)
        XCTAssertEqual(store.state.rating.probableGameDateKeys.count, 1)
        XCTAssertEqual(provider.signals.filter { $0.event == .gameProbable }.count, 2)
    }

    func testProbableGameDateIsFrozenAtQualificationAndOldDatesRemainCompatible() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var changedCalendar = calendar
        changedCalendar.timeZone = TimeZone(secondsFromGMT: 14 * 3_600)!

        let frozenKey = RollCallRatingPolicy.localDateKey(for: date, calendar: calendar)
        var rating = TelemetryRatingState(enrollmentDate: date, distinctProbableGameDates: [date], probableGameDateKeys: [frozenKey])
        XCTAssertEqual(RollCallRatingPolicy.distinctProbableGameDateCount(for: rating, calendar: changedCalendar), 1)

        rating.probableGameDateKeys.append(frozenKey)
        XCTAssertEqual(RollCallRatingPolicy.distinctProbableGameDateCount(for: rating, calendar: changedCalendar), 1)
    }

    func testSchemaMigrationInvalidCheckpointAndRetryRecovery() throws {
        let url = temporaryDirectory.fileURL("migration.json")
        let oldState = #"{"schemaVersion":0,"enrollmentDate":"2023-11-14T22:13:20Z","enrollmentCohort":"existingInstall","baselineCompleted":true,"rating":{"enrollmentDate":"2023-11-14T22:13:20Z","distinctProbableGameDates":["2023-11-14T22:13:20Z"]}}"#
        try Data(oldState.utf8).write(to: url)
        let migrated = TelemetryStore(url: url, now: RollCallTestFixtures.now)
        XCTAssertEqual(migrated.status, .loaded)
        XCTAssertEqual(migrated.state.schemaVersion, TelemetryStoreState.currentSchemaVersion)
        XCTAssertNil(migrated.state.liveCheckpoint)
        XCTAssertEqual(migrated.state.rating.probableGameDateKeys.count, 1)

        let invalidCheckpointURL = temporaryDirectory.fileURL("invalid-checkpoint.json")
        var state = TelemetryStoreState.new(cohort: "existingInstall", now: RollCallTestFixtures.now)
        state.liveCheckpoint = nil
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var json = try JSONSerialization.jsonObject(with: encoder.encode(state)) as! [String: Any]
        json["liveCheckpoint"] = ["selectedTeamID": "not-a-uuid"]
        try JSONSerialization.data(withJSONObject: json).write(to: invalidCheckpointURL)
        let invalid = TelemetryStore(url: invalidCheckpointURL, now: RollCallTestFixtures.now)
        XCTAssertEqual(invalid.status, .loaded)
        XCTAssertNil(invalid.state.liveCheckpoint)

        let (coordinator, provider, failingStore) = makeCoordinator()
        failingStore.state.suspended = true
        failingStore.writeOverride = { _, _ in throw NSError(domain: "test", code: 3) }
        XCTAssertFalse(coordinator.retryPersistence())
        XCTAssertTrue(failingStore.state.suspended)
        failingStore.writeOverride = nil
        XCTAssertTrue(coordinator.retryPersistence())
        XCTAssertFalse(failingStore.state.suspended)
        coordinator.recordOnce(.liveEntered)
        XCTAssertTrue(provider.signals.contains { $0.event == .liveEntered })
    }

    func testRetentionActivationRecordsEachCrossedMilestoneOnce() {
        let (coordinator, provider, store) = makeCoordinator()
        let now = store.state.enrollmentDate.addingTimeInterval(30 * 86_400)
        coordinator.observeRetentionActivation(at: now, wasAlreadyActive: false)
        let expected: Set<RollCallTelemetryEvent> = [.retentionDay1, .retentionDay7, .retentionDay30]
        XCTAssertEqual(Set(provider.signals.map(\.event)), expected)
        coordinator.observeRetentionActivation(at: now, wasAlreadyActive: true)
        XCTAssertEqual(Set(provider.signals.map(\.event)), expected)
    }

    func testStructuredPlaybackRequiresCorrelatedConfirmedStart() {
        let (coordinator, _, store) = makeCoordinator()
        let requestID = UUID()
        let mismatched = PlaybackRequestResult(
            requestID: requestID,
            confirmations: [PlaybackStartConfirmation(requestID: UUID(), component: .primaryCue, sourceFamily: .importedLocal, outcome: .started)],
            wasDebounced: false
        )
        XCTAssertFalse(coordinator.handlePlayerPlayback(teamID: RollCallTestFixtures.teamID, playerID: RollCallTestFixtures.alexID, result: mismatched))
        XCTAssertEqual(store.state.successfulPlayerPlaybackCount, 0)

        let cancelled = PlaybackRequestResult(
            requestID: requestID,
            confirmations: [PlaybackStartConfirmation(requestID: requestID, component: .primaryCue, sourceFamily: .importedLocal, outcome: .cancelled)],
            wasDebounced: false
        )
        XCTAssertFalse(coordinator.handlePlayerPlayback(teamID: RollCallTestFixtures.teamID, playerID: RollCallTestFixtures.alexID, result: cancelled))

        let debounced = PlaybackRequestResult(requestID: requestID, confirmations: [], wasDebounced: true)
        XCTAssertFalse(coordinator.handlePlayerPlayback(teamID: RollCallTestFixtures.teamID, playerID: RollCallTestFixtures.alexID, result: debounced))

        let confirmed = PlaybackRequestResult(
            requestID: requestID,
            confirmations: [PlaybackStartConfirmation(requestID: requestID, component: .primaryCue, sourceFamily: .importedLocal, outcome: .started)],
            wasDebounced: false
        )
        XCTAssertTrue(coordinator.handlePlayerPlayback(teamID: RollCallTestFixtures.teamID, playerID: RollCallTestFixtures.alexID, result: confirmed))
        XCTAssertEqual(store.state.successfulPlayerPlaybackCount, 1)
    }

    func testPackageMilestonesFollowCompletedCallsAndPersistBeforeEnqueue() {
        let (coordinator, provider, store) = makeCoordinator()
        for _ in 0..<5 { coordinator.recordPackageExportCompleted() }
        XCTAssertEqual(store.state.packageExportCount, 5)
        XCTAssertEqual(provider.signals.filter { $0.event == .packageFirstExport }.count, 1)
        XCTAssertEqual(provider.signals.filter { $0.event == .packageExportCount5 }.count, 1)
        coordinator.recordPackageExportCompleted()
        XCTAssertEqual(provider.signals.filter { $0.event == .packageExportCount5 }.count, 1)
    }

    func testLiveTimeoutIsInclusiveAndMissingTeamClearsCheckpoint() {
        let teamID = RollCallTestFixtures.teamID
        let now = RollCallTestFixtures.now
        let checkpoint = LiveAnalyticsCheckpoint(
            selectedTeamID: teamID,
            firstQualifyingCueAt: now,
            latestQualifyingCueAt: now,
            distinctPlayerIDs: [],
            qualifyingCueCount: 0,
            hasThreeMinuteGap: false,
            latestMeaningfulActivityAt: now,
            bufferedRecoveryKeys: [],
            bufferedCompleteFailureKeys: [],
            emittedFeatureKeys: [],
            didQualify: false,
            probableGameDate: nil
        )
        XCTAssertNotNil(LiveAnalyticsSessionReducer.accepting(checkpoint: checkpoint, selectedTeamID: teamID, now: now.addingTimeInterval(3600)))
        XCTAssertNil(LiveAnalyticsSessionReducer.accepting(checkpoint: checkpoint, selectedTeamID: teamID, now: now.addingTimeInterval(3601)))

        let (coordinator, _, store) = makeCoordinator()
        store.state.liveCheckpoint = checkpoint
        XCTAssertTrue(store.save())
        coordinator.validateLiveCheckpoint(availableTeamIDs: [], selectedTeamID: nil)
        XCTAssertNil(store.state.liveCheckpoint)
    }

    func testLiveCheckpointRejectsFutureStaleAndWrongTeamActivity() {
        let teamID = RollCallTestFixtures.teamID
        let otherTeamID = UUID()
        let now = RollCallTestFixtures.now
        let checkpoint = LiveAnalyticsCheckpoint(
            selectedTeamID: teamID,
            firstQualifyingCueAt: now,
            latestQualifyingCueAt: now,
            distinctPlayerIDs: [],
            qualifyingCueCount: 0,
            hasThreeMinuteGap: false,
            latestMeaningfulActivityAt: now,
            bufferedRecoveryKeys: [],
            bufferedCompleteFailureKeys: [],
            emittedFeatureKeys: [],
            didQualify: false,
            probableGameDate: nil
        )
        XCTAssertNil(LiveAnalyticsSessionReducer.accepting(checkpoint: checkpoint, selectedTeamID: otherTeamID, now: now))
        XCTAssertNil(LiveAnalyticsSessionReducer.accepting(checkpoint: checkpoint, selectedTeamID: teamID, now: now.addingTimeInterval(3600 + 1)))
        XCTAssertNil(LiveAnalyticsSessionReducer.accepting(checkpoint: checkpoint, selectedTeamID: teamID, now: now.addingTimeInterval(-1)))
    }

    func testAllSixPlaybackDepthThresholdsRemainDistinct() async {
        let (coordinator, provider, store) = makeCoordinator()
        let thresholds: [(Int, RollCallTelemetryEvent)] = [
            (10, .playerPlaybackCount10), (50, .playerPlaybackCount50), (100, .playerPlaybackCount100),
            (250, .playerPlaybackCount250), (500, .playerPlaybackCount500), (1000, .playerPlaybackCount1000)
        ]
        for (threshold, event) in thresholds {
            store.state.successfulPlayerPlaybackCount = threshold - 1
            store.state.liveCheckpoint = nil
            store.state.consumedInstallEvents.remove(event.rawValue)
            XCTAssertTrue(store.save())
            let requestID = UUID()
            let result = PlaybackRequestResult(
                requestID: requestID,
                confirmations: [PlaybackStartConfirmation(requestID: requestID, component: .primaryCue, sourceFamily: .importedLocal, outcome: .started)],
                wasDebounced: false
            )
            XCTAssertTrue(coordinator.handlePlayerPlayback(teamID: RollCallTestFixtures.teamID, playerID: RollCallTestFixtures.alexID, result: result, now: RollCallTestFixtures.now))
            await coordinator.waitForPendingPersistenceForTesting()
            XCTAssertTrue(provider.signals.contains { $0.event == event })
        }
    }

    func testRatingBoundariesReservationAndAppStoreOnlyPresentation() {
        let enrollment = RollCallTestFixtures.now
        var rating = TelemetryRatingState(enrollmentDate: enrollment)
        rating.distinctProbableGameDates = [enrollment, enrollment.addingTimeInterval(86_400)]
        XCTAssertNil(RollCallRatingPolicy.automaticOpportunity(for: rating, now: enrollment.addingTimeInterval(7 * 86_400 - 1)))
        XCTAssertEqual(RollCallRatingPolicy.automaticOpportunity(for: rating, now: enrollment.addingTimeInterval(7 * 86_400)), 1)

        rating.automaticAttemptsConsumed = 1
        rating.firstSheetShownAt = enrollment
        rating.presentationCooldownAnchor = enrollment
        rating.distinctProbableGameDates += [enrollment.addingTimeInterval(2 * 86_400), enrollment.addingTimeInterval(3 * 86_400), enrollment.addingTimeInterval(4 * 86_400)]
        XCTAssertNil(RollCallRatingPolicy.automaticOpportunity(for: rating, now: enrollment.addingTimeInterval(30 * 86_400 - 1)))
        XCTAssertEqual(RollCallRatingPolicy.automaticOpportunity(for: rating, now: enrollment.addingTimeInterval(30 * 86_400)), 2)

        let (developerCoordinator, _, _) = makeCoordinator(context: TelemetryBuildContext(isAppStoreBuild: false, isTestFlightBuild: false, isDeveloperBuild: true, isSwiftUIPreview: false))
        XCTAssertNil(developerCoordinator.reserveRatingPresentation(source: .automatic))

        let (storeCoordinator, provider, store) = makeCoordinator(context: TelemetryBuildContext(isAppStoreBuild: true, isTestFlightBuild: false, isDeveloperBuild: false, isSwiftUIPreview: false))
        store.state.rating = rating
        XCTAssertTrue(store.save())
        let token = try! XCTUnwrap(storeCoordinator.reserveRatingPresentation(source: .automatic, now: enrollment.addingTimeInterval(30 * 86_400)))
        XCTAssertEqual(store.state.rating.automaticAttemptsConsumed, 1)
        XCTAssertTrue(provider.signals.isEmpty)
        storeCoordinator.confirmRatingPresentation(token: token, now: enrollment.addingTimeInterval(30 * 86_400))
        XCTAssertEqual(store.state.rating.automaticAttemptsConsumed, 2)
        XCTAssertTrue(provider.signals.contains { $0.event == .ratingSheetShown })

        let manualToken = try! XCTUnwrap(storeCoordinator.reserveRatingPresentation(source: .manual, now: enrollment.addingTimeInterval(31 * 86_400)))
        storeCoordinator.confirmRatingPresentation(token: manualToken, now: enrollment.addingTimeInterval(31 * 86_400))
        XCTAssertEqual(store.state.rating.automaticAttemptsConsumed, 2)
    }

    func testUnresolvedRatingReservationConservativelyConsumesWithoutShownSignal() throws {
        let url = temporaryDirectory.fileURL("rating-recovery.json")
        let state = TelemetryStoreState.new(cohort: "newInstall", now: RollCallTestFixtures.now)
        let store = TelemetryStore(url: url, now: RollCallTestFixtures.now)
        var pendingState = state
        pendingState.rating.pendingPresentation = PendingRatingPresentation(token: UUID(), source: .automatic, automaticAttemptNumber: 1, reservedAt: RollCallTestFixtures.now)
        XCTAssertTrue(store.save(pendingState))

        let provider = RecordingTelemetryProvider()
        let defaults = UserDefaults(suiteName: "RollCallTelemetryTests.RatingRecovery.\(UUID().uuidString)")!
        let coordinator = RollCallTelemetryCoordinator(provider: provider, store: TelemetryStore(url: url, now: RollCallTestFixtures.now), preference: AnonymousUsageAnalyticsPreference(defaults: defaults), buildContext: TelemetryBuildContext(isAppStoreBuild: true, isTestFlightBuild: false, isDeveloperBuild: false, isSwiftUIPreview: false))
        XCTAssertEqual(coordinator.store.state.rating.automaticAttemptsConsumed, 1)
        XCTAssertNil(coordinator.store.state.rating.pendingPresentation)
        XCTAssertFalse(provider.signals.contains { $0.event == .ratingSheetShown })
    }

    func testTelemetryStoreSaveRunsFileWorkOffMainThread() {
        let probe = TelemetryWriteProbe()
        let store = TelemetryStore(url: temporaryDirectory.fileURL("off-main.json"), now: RollCallTestFixtures.now)
        store.writeOverride = { data, _ in
            probe.lock.lock()
            probe.writeCount += 1
            probe.wasMainThread = Thread.isMainThread
            probe.lastData = data
            probe.lock.unlock()
        }

        XCTAssertTrue(store.save())
        let snapshot = probe.snapshot()
        XCTAssertEqual(snapshot.writeCount, 1)
        XCTAssertFalse(snapshot.wasMainThread)
    }

    func testLiveTelemetryWaitsForDurableWriteBeforeSending() async {
        let (coordinator, provider, store) = makeCoordinator()
        let probe = TelemetryWriteProbe()
        let writerStarted = DispatchSemaphore(value: 0)
        let releaseWriter = DispatchSemaphore(value: 0)
        store.writeOverride = { data, _ in
            probe.lock.lock()
            probe.writeCount += 1
            probe.wasMainThread = Thread.isMainThread
            probe.lastData = data
            probe.lock.unlock()
            writerStarted.signal()
            _ = releaseWriter.wait(timeout: .now() + 2)
        }

        coordinator.recordOnce(.liveEntered, asynchronousPersistence: true)
        XCTAssertEqual(writerStarted.wait(timeout: .now() + 2), .success)
        XCTAssertTrue(provider.signals.isEmpty)

        releaseWriter.signal()
        await coordinator.waitForPendingPersistenceForTesting()

        let snapshot = probe.snapshot()
        XCTAssertFalse(snapshot.wasMainThread)
        XCTAssertNotNil(snapshot.lastData)
        XCTAssertTrue(provider.signals.contains { $0.event == .liveEntered })
    }

    func testLiveTelemetryWritesRemainFIFOAndStopAfterFailure() async {
        let (coordinator, provider, store) = makeCoordinator()
        let firstWriteStarted = DispatchSemaphore(value: 0)
        let releaseFirstWrite = DispatchSemaphore(value: 0)
        let probe = TelemetryWriteProbe()
        store.writeOverride = { data, _ in
            probe.lock.lock()
            probe.writeCount += 1
            let writeNumber = probe.writeCount
            probe.lastData = data
            probe.lock.unlock()
            if writeNumber == 1 {
                firstWriteStarted.signal()
                _ = releaseFirstWrite.wait(timeout: .now() + 2)
            }
        }

        coordinator.recordOnce(.liveEntered, asynchronousPersistence: true)
        coordinator.recordOnce(.playerPlaybackFirstSuccessful, asynchronousPersistence: true)
        XCTAssertEqual(firstWriteStarted.wait(timeout: .now() + 2), .success)
        XCTAssertTrue(provider.signals.isEmpty)
        releaseFirstWrite.signal()
        await coordinator.waitForPendingPersistenceForTesting()
        XCTAssertEqual(provider.signals.map(\.event), [.liveEntered, .playerPlaybackFirstSuccessful])

        store.writeOverride = { _, _ in throw NSError(domain: "test", code: 99) }
        coordinator.recordOnce(.playerPlaybackCount10, asynchronousPersistence: true)
        await coordinator.waitForPendingPersistenceForTesting()
        XCTAssertTrue(store.state.suspended)
        XCTAssertFalse(provider.signals.contains { $0.event == .playerPlaybackCount10 })
        let writesAfterFailure = probe.writeCount

        coordinator.recordOnce(.playerPlaybackCount50, asynchronousPersistence: true)
        await coordinator.waitForPendingPersistenceForTesting()
        XCTAssertEqual(probe.snapshot().writeCount, writesAfterFailure)
    }

    func testSynchronousStoreSaveHonorsAsyncFailureBarrier() async {
        let store = TelemetryStore(url: temporaryDirectory.fileURL("shared-barrier.json"), now: RollCallTestFixtures.now)
        store.writeOverride = { _, _ in throw NSError(domain: "test", code: 101) }

        store.saveAsync(store.state) { _ in }
        await store.waitForPendingWrites()

        XCTAssertFalse(store.save(), "A synchronous compatibility save must not bypass a failed async revision.")
    }

    func testMixedSyncAndAsyncWritesKeepNewestDurableRollbackBaseline() async {
        let (coordinator, _, store) = makeCoordinator()
        let firstWriteStarted = DispatchSemaphore(value: 0)
        let releaseFirstWrite = DispatchSemaphore(value: 0)
        let probe = TelemetryWriteProbe()
        store.writeOverride = { _, _ in
            probe.lock.lock()
            probe.writeCount += 1
            let currentWrite = probe.writeCount
            probe.lock.unlock()
            if currentWrite == 1 {
                firstWriteStarted.signal()
                _ = releaseFirstWrite.wait(timeout: .now() + 2)
            }
        }

        coordinator.recordOnce(.liveEntered, asynchronousPersistence: true)
        XCTAssertEqual(firstWriteStarted.wait(timeout: .now() + 2), .success)
        releaseFirstWrite.signal()

        // This compatibility path is submitted after the async snapshot but
        // before its main-actor completion can run. It must become the newer
        // durable rollback baseline.
        coordinator.recordOnce(.playerPlaybackFirstSuccessful)
        await coordinator.waitForPendingPersistenceForTesting()
        XCTAssertTrue(store.state.consumedInstallEvents.contains(RollCallTelemetryEvent.playerPlaybackFirstSuccessful.rawValue))

        store.writeOverride = { _, _ in throw NSError(domain: "test", code: 102) }
        coordinator.recordOnce(.playerPlaybackCount10, asynchronousPersistence: true)
        await coordinator.waitForPendingPersistenceForTesting()

        XCTAssertTrue(store.state.suspended)
        XCTAssertTrue(
            store.state.consumedInstallEvents.contains(RollCallTelemetryEvent.playerPlaybackFirstSuccessful.rawValue),
            "A failed later revision must restore the newest successful synchronous state, not the older async snapshot."
        )
    }

    func testPendingLiveSignalsAreBoundedAndSuspendFailClosed() async {
        let (coordinator, provider, store) = makeCoordinator()
        let writerStarted = DispatchSemaphore(value: 0)
        let releaseWriter = DispatchSemaphore(value: 0)
        store.writeOverride = { _, _ in
            writerStarted.signal()
            _ = releaseWriter.wait(timeout: .now() + 2)
        }

        coordinator.recordOnce(.liveEntered, asynchronousPersistence: true)
        XCTAssertEqual(writerStarted.wait(timeout: .now() + 2), .success)
        for _ in 0..<257 {
            coordinator.record(.playerPlaybackFirstSuccessful)
        }

        XCTAssertTrue(store.state.suspended)
        XCTAssertTrue(provider.signals.contains { $0.event == .telemetryStatePersistenceFailed })

        releaseWriter.signal()
        await coordinator.waitForPendingPersistenceForTesting()
        XCTAssertFalse(provider.signals.contains { $0.event == .liveEntered })
        XCTAssertFalse(provider.signals.contains { $0.event == .playerPlaybackFirstSuccessful })
    }

    func testOptOutInvalidatesSignalsQueuedBehindPendingWrite() async {
        let (coordinator, provider, store) = makeCoordinator()
        let writerStarted = DispatchSemaphore(value: 0)
        let releaseWriter = DispatchSemaphore(value: 0)
        store.writeOverride = { _, _ in
            writerStarted.signal()
            _ = releaseWriter.wait(timeout: .now() + 2)
        }

        coordinator.recordOnce(.liveEntered, asynchronousPersistence: true)
        XCTAssertEqual(writerStarted.wait(timeout: .now() + 2), .success)
        coordinator.record(.playerPlaybackFirstSuccessful)
        coordinator.setAnalyticsEnabled(false)
        coordinator.setAnalyticsEnabled(true)

        releaseWriter.signal()
        await coordinator.waitForPendingPersistenceForTesting()

        XCTAssertEqual(
            provider.signals.filter { $0.event == .analyticsPreferenceChanged }.map { $0.properties["newValue"] },
            ["off", "on"]
        )
        XCTAssertFalse(provider.signals.contains { $0.event == .liveEntered })
        XCTAssertFalse(provider.signals.contains { $0.event == .playerPlaybackFirstSuccessful })
    }
}
