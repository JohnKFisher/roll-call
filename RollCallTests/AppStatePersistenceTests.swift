import XCTest
@testable import RollCall

@MainActor
private final class DeferredAppleMusicCatalogResolver {
    private var requestContinuation: CheckedContinuation<Void, Never>?
    private var resultContinuation: CheckedContinuation<MusicSearchResult, Error>?

    func resolve(_ result: MusicSearchResult) async throws -> MusicSearchResult {
        requestContinuation?.resume()
        requestContinuation = nil
        return try await withCheckedThrowingContinuation { continuation in
            resultContinuation = continuation
        }
    }

    func waitForRequest() async {
        guard resultContinuation == nil else { return }
        await withCheckedContinuation { continuation in
            requestContinuation = continuation
        }
    }

    func complete(with result: MusicSearchResult) {
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }
}

@MainActor
private final class ControlledAppleMusicResultResolver {
    private var continuations: [String: CheckedContinuation<MusicSearchResult, Error>] = [:]
    private var requestCountContinuation: CheckedContinuation<Void, Never>?
    private var requestedSongIDs: [String] = []

    func resolve(_ result: MusicSearchResult) async throws -> MusicSearchResult {
        requestedSongIDs.append(result.songID)
        if requestedSongIDs.count >= 2 {
            requestCountContinuation?.resume()
            requestCountContinuation = nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            continuations[result.songID] = continuation
        }
    }

    func waitForTwoRequests() async {
        guard requestedSongIDs.count < 2 else { return }
        await withCheckedContinuation { continuation in
            requestCountContinuation = continuation
        }
    }

    func complete(songID: String, with result: MusicSearchResult) {
        continuations.removeValue(forKey: songID)?.resume(returning: result)
    }
}

@MainActor
private final class RecordedPreviewPlayback {
    private(set) var playedSongIDs: [String] = []

    func play(_ cue: Cue) async {
        guard case .appleMusic(let source) = cue.source else { return }
        playedSongIDs.append(source.songID)
    }
}

final class AppStatePersistenceTests: XCTestCase {
    private var temp: RollCallTemporaryDirectory!

    override func setUpWithError() throws {
        temp = try RollCallTemporaryDirectory()
        AppPaths.testBaseDirectoryOverride = temp.fileURL("AppSupport")
    }

    override func tearDownWithError() throws {
        AppPaths.testBaseDirectoryOverride = nil
        temp = nil
    }

    func testPersistenceFailureTelemetryOnlyReflectsLatestRequestedSnapshot() {
        XCTAssertFalse(StatePersistenceFailureSemantics.shouldReportFailure(
            failedSequence: 4,
            latestRequestedSequence: 5
        ))
        XCTAssertTrue(StatePersistenceFailureSemantics.shouldReportFailure(
            failedSequence: 5,
            latestRequestedSequence: 5
        ))
    }

    func testWhatsNewReleaseIdentityStaysWithinMajorMinorFamily() {
        XCTAssertEqual(AppMetadata.releaseFamily(for: "1.2.1"), "1.2")
        XCTAssertTrue(AppMetadata.hasSeenWhatsNewRelease("1.2 (76)", for: "1.2.1"))
        XCTAssertTrue(AppMetadata.hasSeenWhatsNewRelease("1.2.1 (77)", for: "1.2.2"))
        XCTAssertFalse(AppMetadata.hasSeenWhatsNewRelease("1.1 (73)", for: "1.2.1"))
        XCTAssertFalse(AppMetadata.hasSeenWhatsNewRelease(nil, for: "1.2.1"))
    }

    func testDefaultTrimLengthIsTwelveSeconds() throws {
        XCTAssertEqual(AppState.empty.trimDefaults.preferredLength, 12)

        let json = """
        {
          "schemaVersion": 8,
          "appVersion": "1.2",
          "deviceIdentity": { "label": "This iPhone" },
          "selectedTeamID": null,
          "teams": [],
          "recentlyDeleted": [],
          "snapshots": [],
          "experimental": {},
          "settings": {},
          "recentAppleMusicSelections": []
        }
        """

        let decoded = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.trimDefaults.preferredLength, 12)
        XCTAssertTrue(decoded.trimDefaults.hasAppliedTwelveSecondDefaultReset)
        XCTAssertTrue(decoded.settings.explicitAppleMusicSearchFilteringEnabled)
    }

    func testSavedTrimLengthResetsToTwelveSecondsOnce() throws {
        let legacyJSON = #"{"preferredLength":8}"#
        let legacyDefaults = try JSONDecoder().decode(TrimDefaults.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(legacyDefaults.preferredLength, 12)
        XCTAssertTrue(legacyDefaults.hasAppliedTwelveSecondDefaultReset)

        let currentJSON = #"{"preferredLength":15,"hasAppliedTwelveSecondDefaultReset":true}"#
        let currentDefaults = try JSONDecoder().decode(TrimDefaults.self, from: Data(currentJSON.utf8))
        XCTAssertEqual(currentDefaults.preferredLength, 15)
        XCTAssertTrue(currentDefaults.hasAppliedTwelveSecondDefaultReset)
    }

    func testAppStateRoundTripsTeamRosterAndSelection() throws {
        let team = RollCallTestFixtures.team()
        var state = RollCallTestFixtures.appState(team: team)
        state.recentlyDeleted = [
            RecentlyDeletedItem(
                id: UUID(),
                deletedAt: .now,
                payload: .player(
                    DeletedPlayerRecord(
                        player: RollCallTestFixtures.player(id: UUID(), name: "Deleted Player", number: "7"),
                        originalTeamID: team.id,
                        originalTeamName: team.name,
                        previousBattingOrder: []
                    )
                )
            )
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(AppState.self, from: try encoder.encode(state))

        XCTAssertEqual(decoded.selectedTeamID, team.id)
        XCTAssertEqual(decoded.teams.first?.players.map(\.displayName), ["Alex Ramirez", "Jordan Lee", "Casey Morgan"])
        XCTAssertEqual(decoded.recentlyDeleted.count, 1)
        if case .player(let deletedPlayer)? = decoded.recentlyDeleted.first?.payload {
            XCTAssertEqual(deletedPlayer.player.displayName, "Deleted Player")
            XCTAssertEqual(deletedPlayer.originalTeamID, team.id)
            XCTAssertEqual(deletedPlayer.originalTeamName, team.name)
        } else {
            XCTFail("Expected a deleted player payload.")
        }
        XCTAssertEqual(decoded.settings, .default)
        XCTAssertEqual(decoded.ratingRequest, .default)
    }

    @MainActor
    func testViewingTeamDoesNotReplaceLastIntentionalGameDayTeam() throws {
        var viewedTeam = RollCallTestFixtures.team()
        viewedTeam.id = UUID()
        viewedTeam.name = "Viewed Team"
        var gameDayTeam = RollCallTestFixtures.team()
        gameDayTeam.id = UUID()
        gameDayTeam.name = "Game Day Team"
        var state = RollCallTestFixtures.appState(teams: [viewedTeam, gameDayTeam], selectedTeamID: gameDayTeam.id)
        state.lastGameDayTeamID = gameDayTeam.id
        try writeState(state)

        let model = AppModel()
        model.selectTeam(viewedTeam)

        XCTAssertEqual(model.state.selectedTeamID, viewedTeam.id)
        XCTAssertEqual(model.state.lastGameDayTeamID, gameDayTeam.id)
        model.recordIntentionalGameDayEntry()
        XCTAssertEqual(model.state.lastGameDayTeamID, viewedTeam.id)
    }

    @MainActor
    func testDeletingRememberedGameDayTeamClearsStaleTarget() throws {
        let team = RollCallTestFixtures.team()
        var state = RollCallTestFixtures.appState(team: team)
        state.lastGameDayTeamID = team.id
        try writeState(state)

        let model = AppModel()
        model.removeSelectedTeam()

        XCTAssertNil(model.state.lastGameDayTeamID)
    }

    @MainActor
    func testQuickGameDayExplicitTargetSelectsAndRemembersTeam() throws {
        var selected = RollCallTestFixtures.team()
        selected.id = UUID()
        var explicit = RollCallTestFixtures.team()
        explicit.id = UUID()
        let state = RollCallTestFixtures.appState(teams: [selected, explicit], selectedTeamID: selected.id)
        try writeState(state)
        let model = AppModel()

        let resolution = model.resolveOpenGameDay(
            OpenGameDayRequest(explicitTeamID: explicit.id, source: .appIntent)
        )

        XCTAssertEqual(resolution, .gameDay(teamID: explicit.id, targetKind: .explicitTeam))
        XCTAssertEqual(model.state.selectedTeamID, explicit.id)
        XCTAssertEqual(model.state.lastGameDayTeamID, explicit.id)
    }

    @MainActor
    func testQuickGameDayClearsMissingRememberedTarget() throws {
        let team = RollCallTestFixtures.team()
        var state = RollCallTestFixtures.appState(team: team)
        state.lastGameDayTeamID = UUID()
        try writeState(state)
        let model = AppModel()

        XCTAssertEqual(
            model.resolveOpenGameDay(OpenGameDayRequest(source: .systemControl)),
            .fallback(.rememberedTeamMissing)
        )
        XCTAssertNil(model.state.lastGameDayTeamID)
        XCTAssertEqual(model.state.selectedTeamID, team.id)
    }

    @MainActor
    func testPlayerEditorCommitPersistsBothPhotoFramings() throws {
        let team = RollCallTestFixtures.team()
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()
        var draft = try XCTUnwrap(model.selectedTeam?.players.first)
        draft.photoRelativePath = "profile.jpg"
        draft.photoSourceRelativePath = "master.jpg"
        draft.profilePhotoCrop = NormalizedPhotoCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.5)
        draft.playerCardPhotoCrop = NormalizedPhotoCrop(x: 0.1, y: 0.05, width: 0.75, height: 0.84)

        model.commitPlayerEditorDraft(draft)

        let saved = try XCTUnwrap(model.selectedTeam?.players.first)
        XCTAssertEqual(saved.photoRelativePath, "profile.jpg")
        XCTAssertEqual(saved.photoSourceRelativePath, "master.jpg")
        XCTAssertEqual(saved.profilePhotoCrop, draft.profilePhotoCrop)
        XCTAssertEqual(saved.playerCardPhotoCrop, draft.playerCardPhotoCrop)
    }

    func testPlayerDecodeDefaultsMissingPresenceToPresent() throws {
        let json = """
        {
          "id": "\(RollCallTestFixtures.alexID.uuidString)",
          "displayName": "Alex Ramirez",
          "uniformNumber": "12",
          "pronunciationOverride": ""
        }
        """

        let player = try JSONDecoder().decode(Player.self, from: Data(json.utf8))

        XCTAssertTrue(player.isPresent)
        XCTAssertNil(player.cue)
        XCTAssertNil(player.photoRelativePath)
    }

    @MainActor
    func testAppleMusicMetadataRefreshDoesNotOverwriteNewerSavedCue() async throws {
        var originalCue = RollCallTestFixtures.appleMusicCue(
            songID: "catalog.old",
            title: "Old Song",
            artistName: "Old Artist"
        )
        guard case .appleMusic(var originalSource) = originalCue.source else {
            return XCTFail("Expected an Apple Music source.")
        }
        originalSource.duration = nil
        originalCue.source = .appleMusic(originalSource)

        let originalPlayer = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: originalCue
        )
        try writeState(RollCallTestFixtures.appState(
            team: RollCallTestFixtures.team(players: [originalPlayer])
        ))

        let resolver = DeferredAppleMusicCatalogResolver()
        let model = AppModel(
            appleMusicPlaybackCapabilityResolver: { .fullSong },
            catalogBackedResultResolver: { result in
                try await resolver.resolve(result)
            }
        )
        let refreshTask = Task { @MainActor in
            await model.refreshAppleMusicCueMetadata(for: originalPlayer.id)
        }
        await resolver.waitForRequest()

        let replacementCue = RollCallTestFixtures.appleMusicCue(
            songID: "catalog.new",
            title: "New Song",
            artistName: "New Artist"
        )
        model.saveSongCue(replacementCue, to: originalPlayer.id)

        resolver.complete(with: MusicSearchResult(
            songID: "catalog.old",
            title: "Old Song Resolved",
            artistName: "Old Artist Resolved",
            duration: 210,
            previewURL: nil,
            isCatalogBacked: true
        ))

        let didRefresh = await refreshTask.value
        XCTAssertFalse(didRefresh)
        guard case .appleMusic(let currentSource)? = model.selectedTeam?.players.first?.cue?.source else {
            return XCTFail("Expected the replacement Apple Music cue to remain saved.")
        }
        XCTAssertEqual(currentSource.songID, "catalog.new")
        XCTAssertEqual(currentSource.title, "New Song")
        XCTAssertEqual(currentSource.artistName, "New Artist")
    }

    @MainActor
    func testAppleMusicPreviewIgnoresOlderResultWhenNewerPreviewFinishesFirst() async throws {
        try writeState(RollCallTestFixtures.appState())

        let resolver = ControlledAppleMusicResultResolver()
        let playback = RecordedPreviewPlayback()
        let model = AppModel(
            appleMusicPlaybackCapabilityResolver: { .fullSong },
            catalogBackedResultResolver: { result in
                try await resolver.resolve(result)
            },
            previewPlaybackResolver: { cue in
                await playback.play(cue)
            }
        )
        let first = MusicSearchResult(
            songID: "catalog.first",
            title: "First Song",
            artistName: "First Artist",
            duration: nil,
            previewURL: nil,
            isCatalogBacked: true
        )
        let second = MusicSearchResult(
            songID: "catalog.second",
            title: "Second Song",
            artistName: "Second Artist",
            duration: nil,
            previewURL: nil,
            isCatalogBacked: true
        )

        let firstTask = Task { @MainActor in
            await model.previewAppleMusicSearchResult(first)
        }
        let secondTask = Task { @MainActor in
            await model.previewAppleMusicSearchResult(second)
        }
        await resolver.waitForTwoRequests()

        resolver.complete(songID: second.songID, with: second)
        await secondTask.value
        XCTAssertEqual(playback.playedSongIDs, [second.songID])

        resolver.complete(songID: first.songID, with: first)
        await firstTask.value
        XCTAssertEqual(playback.playedSongIDs, [second.songID])
    }

    @MainActor
    func testFlushLatestStateWritesTheMostRecentSnapshot() async throws {
        let team = RollCallTestFixtures.team()
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()
        model.state.teams[0].name = "Updated Thunder"

        await model.flushLatestState()

        let data = try Data(contentsOf: AppPaths.stateURL())
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let savedState = try decoder.decode(AppState.self, from: data)
        XCTAssertEqual(savedState.teams.first?.name, "Updated Thunder")
    }

    private func writeState(_ state: AppState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: AppPaths.stateURL(), options: .atomic)
    }

    func testLegacyPlayerCueDecodesAsPrivateSongAssignment() throws {
        let cueData = try JSONEncoder().encode(RollCallTestFixtures.localCue())
        let cueObject = try XCTUnwrap(JSONSerialization.jsonObject(with: cueData) as? [String: Any])
        let playerObject: [String: Any] = [
            "id": RollCallTestFixtures.alexID.uuidString,
            "displayName": "Alex Ramirez",
            "uniformNumber": "12",
            "pronunciationOverride": "",
            "cue": cueObject
        ]
        let playerData = try JSONSerialization.data(withJSONObject: playerObject)

        let player = try JSONDecoder().decode(Player.self, from: playerData)

        guard case .privateClip(let clip)? = player.songAssignment else {
            return XCTFail("Expected the legacy cue to migrate to a private song assignment.")
        }
        XCTAssertEqual(clip.playbackCue, RollCallTestFixtures.localCue())
    }

    func testPlayerEncodingWritesSongAssignmentWithoutLegacyCue() throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        player.cue = RollCallTestFixtures.localCue()

        let data = try JSONEncoder().encode(player)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNotNil(object["songAssignment"])
        XCTAssertNil(object["cue"])
    }

    func testPlayerDecodesExplicitlyNullSongAssignment() throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        player.songAssignment = nil

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(player)) as? [String: Any]
        )
        object["songAssignment"] = NSNull()

        let decoded = try JSONDecoder().decode(
            Player.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertNil(decoded.songAssignment)
    }

    func testMigratedAppleMusicClipIsSourceBackedAndNotPortable() {
        let clip = SongClip(
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "song.alex",
                title: "Thunder",
                artistName: "The Bats"
            )
        )

        XCTAssertEqual(clip.readinessInputs.playback, .sourceBackedReady)
        XCTAssertFalse(clip.readinessInputs.downloadedOnDevice)
        XCTAssertEqual(clip.portabilityInputs.portability, .sourceReferenceOnly)
        XCTAssertFalse(clip.portabilityInputs.generatedAssetCanBeExported)
        XCTAssertEqual(clip.policy.appleMusicHandlingPolicy, .readableLocalOnly)
    }

    func testSongAssignmentRoundTripsPrivateClipAndPreservesUnresolvedLegacySharedPayload() throws {
        let privateAssignment = SongAssignment.privateClip(
            SongClip(cue: RollCallTestFixtures.localCue())
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        XCTAssertEqual(
            try decoder.decode(SongAssignment.self, from: encoder.encode(privateAssignment)),
            privateAssignment
        )

        let legacyPayload = """
        {"type":"sharedTeamClip","sharedTeamClipID":"\(UUID().uuidString)"}
        """
        let unresolved = try decoder.decode(
            SongAssignment.self,
            from: Data(legacyPayload.utf8)
        )
        guard case .unresolvedLegacySharedTeamClip(let sharedID) = unresolved else {
            return XCTFail("Expected unresolved legacy shared assignment.")
        }
        let encoded = try encoder.encode(unresolved)
        let encodedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        XCTAssertEqual(encodedObject["type"] as? String, "sharedTeamClip")
        XCTAssertEqual(encodedObject["sharedTeamClipID"] as? String, sharedID.uuidString)
    }

    func testTeamDecodeDefaultsMissingTeamClipsToEmpty() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let teamData = try encoder.encode(RollCallTestFixtures.team())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: teamData) as? [String: Any])
        object.removeValue(forKey: "teamClips")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let team = try decoder.decode(Team.self, from: legacyData)

        XCTAssertTrue(team.teamClips.isEmpty)
    }

    func testFutureSavedStateSchemaCanBeDetectedByCallers() throws {
        var state = RollCallTestFixtures.appState(team: RollCallTestFixtures.team())
        state.schemaVersion = AppState.currentSchemaVersion + 1
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let decoded = try decoder.decode(AppState.self, from: try encoder.encode(state))

        XCTAssertGreaterThan(decoded.schemaVersion, AppState.currentSchemaVersion)
    }

    func testAppStateDecodeDefaultsMissingRatingRequestState() throws {
        let json = """
        {
          "schemaVersion": 6,
          "appVersion": "1.1.0",
          "deviceIdentity": { "label": "This iPhone" },
          "teams": [],
          "recentlyDeleted": [],
          "snapshots": [],
          "experimental": {
            "showExperimentalFeatures": false,
            "appleMusicTeamPlaylistSyncEnabled": false
          },
          "settings": {
            "hapticsEnabled": true,
            "fadeOutVolumeAutomationEnabled": false,
            "alwaysUseDarkLiveMode": true,
            "keepScreenAwakeDuringLiveUse": false
          },
          "recentAppleMusicSelections": [],
          "trimDefaults": { "preferredLength": 8 }
        }
        """

        let decoded = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.ratingRequest, .default)
        XCTAssertFalse(decoded.settings.showLineupProgressHints)
    }

    func testAppStateDecodeMigratesLegacySingleAttemptRatingState() throws {
        let json = """
        {
          "schemaVersion": 7,
          "appVersion": "1.1.0",
          "deviceIdentity": { "label": "This iPhone" },
          "teams": [],
          "recentlyDeleted": [],
          "snapshots": [],
          "experimental": {
            "showExperimentalFeatures": false,
            "appleMusicTeamPlaylistSyncEnabled": false
          },
          "settings": {
            "hapticsEnabled": true,
            "fadeOutVolumeAutomationEnabled": false,
            "alwaysUseDarkLiveMode": true,
            "keepScreenAwakeDuringLiveUse": false
          },
          "recentAppleMusicSelections": [],
          "trimDefaults": { "preferredLength": 8 },
          "ratingRequest": {
            "successfulGameDaySessionCount": 5,
            "hasPlayedQualifyingCueInCurrentGameDayVisit": false,
            "hasCountedCurrentGameDayVisit": true,
            "hasAttemptedAutomaticPrompt": true
          }
        }
        """

        let decoded = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.ratingRequest.automaticPromptAttemptCount, 1)
        XCTAssertEqual(decoded.ratingRequest.nextAutomaticPromptSessionThreshold, 10)
        XCTAssertFalse(decoded.settings.showLineupProgressHints)
    }

    func testAppStateDecodeDefaultsMissingLineupProgressHintsSettingToDisabled() throws {
        let json = """
        {
          "schemaVersion": 8,
          "appVersion": "1.1.0",
          "deviceIdentity": { "label": "This iPhone" },
          "teams": [],
          "recentlyDeleted": [],
          "snapshots": [],
          "experimental": {
            "showExperimentalFeatures": false,
            "appleMusicTeamPlaylistSyncEnabled": false
          },
          "settings": {
            "hapticsEnabled": true,
            "fadeOutVolumeAutomationEnabled": false,
            "alwaysUseDarkLiveMode": true,
            "keepScreenAwakeDuringLiveUse": false
          },
          "recentAppleMusicSelections": [],
          "trimDefaults": { "preferredLength": 8 },
          "ratingRequest": {
            "successfulGameDaySessionCount": 0,
            "hasPlayedQualifyingCueInCurrentGameDayVisit": false,
            "hasCountedCurrentGameDayVisit": false,
            "automaticPromptAttemptCount": 0,
            "nextAutomaticPromptSessionThreshold": 10
          }
        }
        """

        let decoded = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))

        XCTAssertFalse(decoded.settings.showLineupProgressHints)
    }
}
