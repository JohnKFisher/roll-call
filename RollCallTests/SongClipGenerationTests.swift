import AVFoundation
import MediaPlayer
import UIKit
import XCTest
@testable import RollCall

private actor PreparationProbe {
    private(set) var didStart = false

    func markStarted() {
        didStart = true
    }
}

private actor PreparationWaitProbe {
    private(set) var didStart = false

    func markStarted() {
        didStart = true
    }
}

private actor CancellationStartGate {
    private(set) var isWaiting = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        isWaiting = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

final class SongClipGenerationTests: XCTestCase {
    private var temp: RollCallTemporaryDirectory!

    override func setUpWithError() throws {
        temp = try RollCallTemporaryDirectory()
        AppPaths.testBaseDirectoryOverride = temp.fileURL("AppSupport")
    }

    override func tearDownWithError() throws {
        AppPaths.testBaseDirectoryOverride = nil
        temp = nil
    }

    func testQueueCancellationMarksActiveRequestBeforePreparationStarts() async {
        let queue = SongClipGenerationQueue()
        let request = SongClipPreparationRequest(
            id: UUID(),
            teamID: RollCallTestFixtures.teamID,
            target: .player(RollCallTestFixtures.alexID),
            clipID: UUID(),
            generationKey: "generation-key",
            trigger: .assignmentSaved,
            isExplicit: false
        )

        await queue.enqueue(request)
        let activeRequest = await queue.next()
        XCTAssertEqual(activeRequest, request)

        let cancelled = await queue.cancel(
            teamID: request.teamID,
            target: request.target
        )
        let isCancelled = await queue.isCancelled(request)
        let nextRequestAfterCancellation = await queue.next()
        XCTAssertTrue(cancelled)
        XCTAssertTrue(isCancelled)
        XCTAssertNil(nextRequestAfterCancellation)

        await queue.complete(request)
        let isCancelledAfterCompletion = await queue.isCancelled(request)
        XCTAssertFalse(isCancelledAfterCompletion)
    }

    @MainActor
    func testCoordinatorCancellationDiscardsAndRemovesLateGeneratedOutcome() async throws {
        let probe = PreparationProbe()
        var clip = SongClip(cue: RollCallTestFixtures.localCue())
        clip.id = UUID()
        let generatedRelativePath = "GeneratedClips/cancelled.m4a"
        let generatedURL = try AppPaths.assetURL(relativePath: generatedRelativePath)
        try Data("cancelled-generated-audio".utf8).write(to: generatedURL)
        let generationKey = clip.generationKey
        let request = SongClipPreparationRequest(
            id: UUID(),
            teamID: RollCallTestFixtures.teamID,
            target: .teamClip(clip.id),
            clipID: clip.id,
            generationKey: clip.generationKey,
            trigger: .assignmentSaved,
            isExplicit: false
        )
        let coordinator = SongClipPreparationCoordinator(
            audioAssetService: AudioAssetService(),
            prepare: { _ in
                await probe.markStarted()
                try? await Task.sleep(for: .seconds(30))
                return .generated(
                    GeneratedClipAsset(
                        relativePath: generatedRelativePath,
                        status: .ready,
                        renderedSelection: SongClipSelection(
                            startTime: 0,
                            duration: 1,
                            fadeOutDuration: 0
                        ),
                        generationKey: generationKey,
                        generatedAt: RollCallTestFixtures.now
                    )
                )
            }
        )
        var appliedOutcomes = 0

        await coordinator.enqueue(request)
        let runner = Task { @MainActor in
            await coordinator.runIfNeeded(
                clipFor: { _ in clip },
                waitForSlot: { true },
                applyOutcome: { _, _ in appliedOutcomes += 1 }
            )
        }

        for _ in 0..<200 {
            if await probe.didStart { break }
            try? await Task.sleep(for: .milliseconds(25))
        }
        let didStart = await probe.didStart
        XCTAssertTrue(didStart)

        await coordinator.cancel(teamID: request.teamID, target: request.target)
        await runner.value

        XCTAssertEqual(appliedOutcomes, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: generatedURL.path))
        let pendingCount = await coordinator.pendingCount()
        XCTAssertEqual(pendingCount, 0)
    }

    @MainActor
    func testCoordinatorCancellationStopsLiveUseWait() async {
        let waitProbe = PreparationWaitProbe()
        var mutableClip = SongClip(cue: RollCallTestFixtures.localCue())
        mutableClip.id = UUID()
        let clip = mutableClip
        let request = SongClipPreparationRequest(
            id: UUID(),
            teamID: RollCallTestFixtures.teamID,
            target: .teamClip(clip.id),
            clipID: clip.id,
            generationKey: clip.generationKey,
            trigger: .assignmentSaved,
            isExplicit: false
        )
        let coordinator = SongClipPreparationCoordinator(
            audioAssetService: AudioAssetService(),
            prepare: { _ in .sourceBacked(downloadedOnDevice: true) }
        )

        await coordinator.enqueue(request)
        let runner = Task { @MainActor in
            await coordinator.runIfNeeded(
                clipFor: { _ in clip },
                waitForSlot: {
                    await waitProbe.markStarted()
                    do {
                        try await Task.sleep(for: .seconds(30))
                        return true
                    } catch {
                        return false
                    }
                },
                applyOutcome: { _, _ in
                    XCTFail("Cancelled preparation must not apply an outcome.")
                }
            )
        }

        for _ in 0..<20 {
            if await waitProbe.didStart { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        let didStart = await waitProbe.didStart
        XCTAssertTrue(didStart)

        await coordinator.cancel(teamID: request.teamID, target: request.target)
        await runner.value

        let pendingCount = await coordinator.pendingCount()
        XCTAssertEqual(pendingCount, 0)
    }

    func testGenerationKeyIsStableAndChangesWithCreativeSelection() {
        var clip = SongClip(cue: RollCallTestFixtures.localCue())
        let originalKey = clip.generationKey

        XCTAssertEqual(originalKey, clip.generationKey)

        clip.requestedSelection.startTime += 1
        XCTAssertNotEqual(originalKey, clip.generationKey)
    }

    func testPreparationRequestRejectsStaleCreativeSelection() {
        var clip = SongClip(cue: RollCallTestFixtures.localCue())
        let currentRequest = SongClipPreparationRequest(
            id: UUID(),
            teamID: RollCallTestFixtures.teamID,
            target: .player(RollCallTestFixtures.alexID),
            clipID: clip.id,
            generationKey: clip.generationKey,
            trigger: .assignmentSaved,
            isExplicit: false
        )

        XCTAssertTrue(currentRequest.matches(clip))
        clip.requestedSelection.duration += 1
        XCTAssertFalse(currentRequest.matches(clip))
    }

    func testPlaybackUsesCurrentGeneratedAsset() {
        var clip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "original.caf"))
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: "GeneratedClips/current.m4a",
            status: .ready,
            renderedSelection: clip.requestedSelection,
            generationKey: clip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )

        XCTAssertTrue(clip.hasCurrentGeneratedAsset)
        guard case .localAudio(let source) = clip.playbackCue.source else {
            return XCTFail("Expected current generated audio.")
        }
        XCTAssertEqual(source.relativePath, "GeneratedClips/current.m4a")
        XCTAssertEqual(clip.playbackCue.startTime, 0)
        XCTAssertEqual(clip.playbackCue.fadeOutDuration, 0)
    }

    func testPlaybackRejectsGeneratedAssetAfterCreativeSelectionChanges() {
        var clip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "original.caf"))
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: "GeneratedClips/stale.m4a",
            status: .ready,
            renderedSelection: clip.requestedSelection,
            generationKey: clip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        clip.requestedSelection.startTime += 1
        clip.requestedSelection.duration -= 1

        XCTAssertFalse(clip.hasCurrentGeneratedAsset)
        guard case .localAudio(let source) = clip.playbackCue.source else {
            return XCTFail("Expected source-backed playback while regeneration is pending.")
        }
        XCTAssertEqual(source.relativePath, "original.caf")
        XCTAssertEqual(clip.playbackCue.startTime, clip.requestedSelection.startTime)
        XCTAssertEqual(clip.playbackCue.duration, clip.requestedSelection.duration)
        XCTAssertEqual(clip.playbackCue.fadeOutDuration, clip.requestedSelection.fadeOutDuration)
    }

    func testPlaybackRejectsGeneratedAssetAfterFadeOnlyChanges() {
        var clip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "original.caf"))
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: "GeneratedClips/stale-fade.m4a",
            status: .ready,
            renderedSelection: clip.requestedSelection,
            generationKey: clip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )

        clip.requestedSelection.fadeOutDuration += 0.5

        XCTAssertFalse(clip.hasCurrentGeneratedAsset)
        guard case .localAudio(let source) = clip.playbackCue.source else {
            return XCTFail("Expected original source playback while fade regeneration is pending.")
        }
        XCTAssertEqual(source.relativePath, "original.caf")
        XCTAssertEqual(clip.playbackCue.fadeOutDuration, clip.requestedSelection.fadeOutDuration)
    }

    func testPublicAPICannotRequestAppleMusicOfflineDownload() {
        XCTAssertFalse(SongClipGenerationService.canRequestAppleMusicOfflineDownload)
        XCTAssertFalse(SongClipPolicy.current.autoDownloadEligibleSongsEnabled)
    }

    func testAppleMusicSearchRecognizesCancellationErrors() {
        XCTAssertTrue(MusicCatalogService.isCancellation(CancellationError()))
        XCTAssertTrue(
            MusicCatalogService.isCancellation(
                URLError(.cancelled)
            )
        )
        XCTAssertFalse(
            MusicCatalogService.isCancellation(
                URLError(.notConnectedToInternet)
            )
        )
    }

    func testPlayerEditorDraftStateIgnoresBackgroundSongPreparationChanges() {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7",
            cue: RollCallTestFixtures.localCue()
        )
        var refreshedPlayer = player
        guard case .privateClip(var clip) = refreshedPlayer.songAssignment else {
            return XCTFail("Expected a private song clip.")
        }
        clip.readinessInputs.playback = .localClipReady
        clip.generatedAsset.status = .pending
        clip.retryMetadata.attemptCount = 1
        refreshedPlayer.songAssignment = .privateClip(clip)

        XCTAssertNotEqual(player, refreshedPlayer)
        XCTAssertEqual(
            PlayerEditorDraftState(player: player),
            PlayerEditorDraftState(player: refreshedPlayer)
        )
    }

    func testPlayerEditorDraftStateDetectsDeferredIdentityPhotoAndTimingChanges() {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7",
            cue: RollCallTestFixtures.localCue()
        )

        var renamed = player
        renamed.displayName = "Alex M."
        XCTAssertNotEqual(PlayerEditorDraftState(player: player), PlayerEditorDraftState(player: renamed))

        var renumbered = player
        renumbered.uniformNumber = "17"
        XCTAssertNotEqual(PlayerEditorDraftState(player: player), PlayerEditorDraftState(player: renumbered))

        var rephotographed = player
        rephotographed.photoRelativePath = "new-photo.jpg"
        XCTAssertNotEqual(PlayerEditorDraftState(player: player), PlayerEditorDraftState(player: rephotographed))

        var retrimmed = player
        retrimmed.cue?.startTime += 0.25
        XCTAssertNotEqual(PlayerEditorDraftState(player: player), PlayerEditorDraftState(player: retrimmed))
    }

    @MainActor
    func testLegacySharedAssignmentFlattensToIndependentPlayerCopy() throws {
        var clip = SongClip(cue: RollCallTestFixtures.localCue())
        clip.displayName = "Legacy Shared Clip"
        var unrelatedClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "unrelated.m4a"))
        unrelatedClip.id = UUID()
        unrelatedClip.pauseAfterAnnouncer = 0.75
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        var team = RollCallTestFixtures.team(players: [player])
        team.teamClips = [clip, unrelatedClip]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(team)) as? [String: Any])
        var players = try XCTUnwrap(object["players"] as? [[String: Any]])
        players[0]["songAssignment"] = [
            "type": "sharedTeamClip",
            "sharedTeamClipID": clip.id.uuidString
        ]
        object["players"] = players
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let migratedTeam = try decoder.decode(Team.self, from: legacyData)

        let loadedPlayer = try XCTUnwrap(migratedTeam.players.first)
        guard case .privateClip(let playerClip)? = loadedPlayer.songAssignment else {
            return XCTFail("Expected the legacy shared assignment to flatten.")
        }
        XCTAssertNotEqual(playerClip.id, clip.id)
        XCTAssertEqual(playerClip.sourceLineageClipID, clip.id)
        XCTAssertEqual(migratedTeam.teamClips.first?.pauseAfterAnnouncer, 0)
        XCTAssertEqual(migratedTeam.teamClips.last?.pauseAfterAnnouncer, 0.75)
    }

    func testUnresolvedLegacySharedAssignmentSurvivesTeamSave() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        var team = RollCallTestFixtures.team(players: [player])
        let missingClipID = UUID()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(team)) as? [String: Any])
        var players = try XCTUnwrap(object["players"] as? [[String: Any]])
        players[0]["songAssignment"] = [
            "type": "sharedTeamClip",
            "sharedTeamClipID": missingClipID.uuidString
        ]
        object["players"] = players
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        team = try decoder.decode(
            Team.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        let saved = try encoder.encode(team)
        let reloaded = try decoder.decode(Team.self, from: saved)

        guard case .unresolvedLegacySharedTeamClip(let reloadedID)? = reloaded.players.first?.songAssignment else {
            return XCTFail("Expected unresolved legacy assignment to survive save and reload.")
        }
        XCTAssertEqual(reloadedID, missingClipID)
    }

    @MainActor
    func testCustomClipsAllowIndependentDuplicatesAndImmediatePlayback() throws {
        try writeState(RollCallTestFixtures.appState(team: RollCallTestFixtures.team()))
        let model = AppModel()
        let cue = RollCallTestFixtures.localCue()

        let first = try XCTUnwrap(model.saveCustomClip(cue: cue, named: "Warmup"))
        let second = try XCTUnwrap(model.saveCustomClip(cue: cue, named: "Different Name"))

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(model.selectedTeam?.teamClips.count, 2)
        XCTAssertTrue(model.selectedTeam?.teamClips.allSatisfy { $0.pauseAfterAnnouncer == 0 } == true)
    }

    @MainActor
    func testSavingReadableCustomClipSchedulesPortableGeneration() async throws {
        let sourcePath = "team-source.caf"
        try writeSilentAudio(to: AppPaths.assetURL(relativePath: sourcePath), duration: 2)
        var cue = RollCallTestFixtures.localCue(relativePath: sourcePath)
        cue.duration = 1
        let team = RollCallTestFixtures.team(players: [])
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()

        let clipID = try XCTUnwrap(model.saveCustomClip(cue: cue, named: "Team Intro"))

        let generated = try await waitForTeamClip(in: model, id: clipID) {
            $0.generatedAsset.status == .ready
        }
        XCTAssertEqual(generated.readinessInputs.playback, .localClipReady)
        XCTAssertEqual(generated.portabilityInputs.portability, .portableLocalClip)
        let generatedPath = try XCTUnwrap(generated.generatedAsset.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try AppPaths.assetURL(relativePath: generatedPath).path))
    }

    @MainActor
    func testSourceBackedCustomClipDoesNotBounceBackToPreparingOnForeground() throws {
        var clip = SongClip(cue: RollCallTestFixtures.appleMusicCue(songID: "apple-1", title: "Catalog Song", artistName: "Artist"))
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: nil,
            status: .none,
            renderedSelection: nil,
            generationKey: clip.generationKey,
            generatedAt: nil
        )
        clip.readinessInputs = SongClipReadinessInputs(
            playback: .sourceBackedReady,
            sourceAvailableOnDevice: true,
            downloadedOnDevice: false
        )
        clip.portabilityInputs = SongClipPortabilityInputs(
            portability: .sourceReferenceOnly,
            generatedAssetCanBeExported: false
        )
        var team = RollCallTestFixtures.team(players: [])
        team.teamClips = [clip]
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()

        model.prepareSongsAfterForeground()

        XCTAssertEqual(model.selectedTeam?.teamClips.first?.generatedAsset.status, GeneratedClipAssetStatus.none)
        XCTAssertEqual(model.selectedTeam?.teamClips.first?.readinessInputs.playback, .sourceBackedReady)
    }

    @MainActor
    func testExhaustedRetryableCustomClipDoesNotBounceBackToPreparingOnForeground() throws {
        var clip = SongClip(cue: RollCallTestFixtures.appleMusicCue(songID: "apple-2", title: "Unavailable Song", artistName: "Artist"))
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: nil,
            status: .failedRetryable,
            renderedSelection: nil,
            generationKey: clip.generationKey,
            generatedAt: nil
        )
        clip.readinessInputs = SongClipReadinessInputs(
            playback: .needsAppleMusic,
            sourceAvailableOnDevice: false,
            downloadedOnDevice: false
        )
        clip.retryMetadata = SongClipRetryMetadata(
            attemptCount: 3,
            lastAttemptAt: RollCallTestFixtures.now,
            nextRetryAt: nil,
            lastFailureCode: SongClipPreparationFailureCode.musicAuthorizationRequired.rawValue
        )
        var team = RollCallTestFixtures.team(players: [])
        team.teamClips = [clip]
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()

        model.prepareSongsAfterForeground()

        XCTAssertEqual(model.selectedTeam?.teamClips.first?.generatedAsset.status, .failedRetryable)
        XCTAssertEqual(model.selectedTeam?.teamClips.first?.readinessInputs.playback, .needsAppleMusic)
    }

    @MainActor
    func testCopyingCustomClipToPlayerCreatesIndependentAssignment() throws {
        let alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        var sourceClip = SongClip(cue: RollCallTestFixtures.localCue())
        sourceClip.displayName = "Hype"
        sourceClip.pauseAfterAnnouncer = 0
        var team = RollCallTestFixtures.team(players: [alex])
        team.teamClips = [sourceClip]
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()

        var editedCue = sourceClip.editingCue
        editedCue.startTime = 2
        model.savePlayerSongCopy(from: sourceClip, editedCue: editedCue, to: alex.id)

        guard case .privateClip(let playerClip)? = model.selectedTeam?.players.first?.songAssignment else {
            return XCTFail("Expected an independent player song.")
        }
        XCTAssertNotEqual(playerClip.id, sourceClip.id)
        XCTAssertEqual(playerClip.sourceLineageClipID, sourceClip.id)
        XCTAssertEqual(playerClip.requestedSelection.startTime, 2)
        XCTAssertEqual(model.selectedTeam?.teamClips.first?.requestedSelection.startTime, 0)
        XCTAssertEqual(playerClip.pauseAfterAnnouncer, 0.2)
    }

    @MainActor
    func testCopyingPlayerSongToCustomClipDoesNotAlterOriginalLocalClip() throws {
        let alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7",
            cue: RollCallTestFixtures.localCue()
        )
        try writeState(RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [alex])))
        let model = AppModel()
        let sourceClip = try XCTUnwrap(model.selectedTeam?.songClip(for: alex))

        var editedCue = sourceClip.editingCue
        editedCue.startTime = 2
        editedCue.duration = 5
        let customClipID = try XCTUnwrap(
            model.saveCustomClipCopy(from: sourceClip, editedCue: editedCue, named: "Hype")
        )

        let copiedClip = try XCTUnwrap(model.selectedTeam?.teamClips.first { $0.id == customClipID })
        let refreshedPlayerClip = try XCTUnwrap(model.selectedTeam?.songClip(for: alex))
        XCTAssertNotEqual(copiedClip.id, sourceClip.id)
        XCTAssertEqual(copiedClip.sourceLineageClipID, sourceClip.id)
        XCTAssertEqual(copiedClip.requestedSelection.startTime, 2)
        XCTAssertEqual(copiedClip.requestedSelection.duration, 5)
        XCTAssertNil(copiedClip.generatedAsset.relativePath)
        XCTAssertNotEqual(copiedClip.generationKey, sourceClip.generationKey)
        XCTAssertEqual(refreshedPlayerClip.requestedSelection.startTime, 0)
        XCTAssertEqual(refreshedPlayerClip.requestedSelection.duration, 8)
    }

    @MainActor
    func testCopyingReadyLocalClipPreservesEditableSourceWithoutChangingOriginal() throws {
        let generatedPath = "GeneratedClips/alex-ready.m4a"
        var sourceClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "original-local.m4a"))
        sourceClip.generatedAsset = GeneratedClipAsset(
            relativePath: generatedPath,
            status: .ready,
            renderedSelection: sourceClip.requestedSelection,
            generationKey: sourceClip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        sourceClip.readinessInputs.playback = .localClipReady
        var alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        alex.songAssignment = .privateClip(sourceClip)
        try writeState(RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [alex])))
        let model = AppModel()
        let loadedSource = try XCTUnwrap(model.selectedTeam?.songClip(for: alex))

        let customClipID = try XCTUnwrap(
            model.saveCustomClipCopy(from: loadedSource, editedCue: loadedSource.editingCue, named: "Ready Copy")
        )

        let copiedClip = try XCTUnwrap(model.selectedTeam?.teamClips.first { $0.id == customClipID })
        XCTAssertEqual(copiedClip.generatedAsset.relativePath, generatedPath)
        XCTAssertEqual(copiedClip.playbackCue.startTime, 0)
        XCTAssertEqual(copiedClip.editingCue.startTime, loadedSource.editingCue.startTime)
        guard case .localAudio(let editableSource) = copiedClip.editingCue.source else {
            return XCTFail("Expected editing to use the original local source.")
        }
        XCTAssertEqual(editableSource.relativePath, "original-local.m4a")
        XCTAssertEqual(model.selectedTeam?.songClip(for: alex)?.requestedSelection, sourceClip.requestedSelection)
    }

    @MainActor
    func testDeveloperToolDuplicatesPlayerSongsToCustomClips() throws {
        let generatedPath = "GeneratedClips/alex-ready.m4a"
        var alexClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "original-local.m4a"))
        alexClip.generatedAsset = GeneratedClipAsset(
            relativePath: generatedPath,
            status: .ready,
            renderedSelection: alexClip.requestedSelection,
            generationKey: alexClip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        alexClip.readinessInputs.playback = .localClipReady

        var alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        alex.songAssignment = .privateClip(alexClip)

        var jordan = RollCallTestFixtures.player(
            id: RollCallTestFixtures.jordanID,
            name: "Jordan Lee",
            number: "4"
        )
        let jordanClip = SongClip(
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog-jordan",
                title: "Thunderstruck",
                artistName: "AC/DC"
            )
        )
        jordan.songAssignment = .privateClip(jordanClip)

        let casey = RollCallTestFixtures.player(
            id: RollCallTestFixtures.caseyID,
            name: "Casey Morgan",
            number: "9"
        )

        try writeState(
            RollCallTestFixtures.appState(
                team: RollCallTestFixtures.team(players: [alex, jordan, casey])
            )
        )
        let model = AppModel()

        let result = model.duplicateSelectedTeamPlayerSongsToCustomClips()

        XCTAssertEqual(result.copiedCount, 2)
        XCTAssertEqual(result.skippedCount, 1)
        let clips = try XCTUnwrap(model.selectedTeam?.teamClips)
        XCTAssertEqual(clips.count, 2)
        XCTAssertEqual(clips.map(\.displayName), ["Alex Morgan - Alex Walkup", "Jordan Lee - Thunderstruck"])
        XCTAssertEqual(clips[0].sourceLineageClipID, alexClip.id)
        XCTAssertEqual(clips[0].generatedAsset.relativePath, generatedPath)
        XCTAssertEqual(clips[0].pauseAfterAnnouncer, 0)
        XCTAssertEqual(clips[1].sourceLineageClipID, jordanClip.id)
        XCTAssertEqual(clips[1].pauseAfterAnnouncer, 0)
        XCTAssertEqual(model.selectedTeam?.players.count, 3)
        XCTAssertEqual(model.selectedTeam?.players.first?.songAssignment?.privateClip?.id, alexClip.id)
    }

    @MainActor
    func testRetimingReadyLocalClipCopyDoesNotReuseOriginalGeneratedAsset() throws {
        var sourceClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "original-local.m4a"))
        sourceClip.generatedAsset = GeneratedClipAsset(
            relativePath: "GeneratedClips/original-ready.m4a",
            status: .ready,
            renderedSelection: sourceClip.requestedSelection,
            generationKey: sourceClip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        sourceClip.readinessInputs.playback = .localClipReady
        var alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        alex.songAssignment = .privateClip(sourceClip)
        try writeState(RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [alex])))
        let model = AppModel()
        let loadedSource = try XCTUnwrap(model.selectedTeam?.songClip(for: alex))

        var editedCue = loadedSource.editingCue
        editedCue.startTime = 3
        let customClipID = try XCTUnwrap(
            model.saveCustomClipCopy(from: loadedSource, editedCue: editedCue, named: "Retimed Copy")
        )

        let copiedClip = try XCTUnwrap(model.selectedTeam?.teamClips.first { $0.id == customClipID })
        XCTAssertEqual(copiedClip.requestedSelection.startTime, 3)
        XCTAssertNil(copiedClip.generatedAsset.relativePath)
        XCTAssertNotEqual(copiedClip.generationKey, sourceClip.generationKey)
        XCTAssertEqual(model.selectedTeam?.songClip(for: alex)?.requestedSelection.startTime, 0)
        XCTAssertEqual(
            model.selectedTeam?.songClip(for: alex)?.generatedAsset.relativePath,
            "GeneratedClips/original-ready.m4a"
        )
    }

    @MainActor
    func testRefadingReadyLocalClipCopyDoesNotReuseOriginalGeneratedAsset() throws {
        var sourceClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "original-local.m4a"))
        sourceClip.generatedAsset = GeneratedClipAsset(
            relativePath: "GeneratedClips/original-ready-fade.m4a",
            status: .ready,
            renderedSelection: sourceClip.requestedSelection,
            generationKey: sourceClip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        sourceClip.readinessInputs.playback = .localClipReady
        var alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        alex.songAssignment = .privateClip(sourceClip)
        try writeState(RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [alex])))
        let model = AppModel()
        let loadedSource = try XCTUnwrap(model.selectedTeam?.songClip(for: alex))

        var editedCue = loadedSource.editingCue
        editedCue.fadeOutDuration += 0.5
        let customClipID = try XCTUnwrap(
            model.saveCustomClipCopy(from: loadedSource, editedCue: editedCue, named: "Refaded Copy")
        )

        let copiedClip = try XCTUnwrap(model.selectedTeam?.teamClips.first { $0.id == customClipID })
        XCTAssertEqual(copiedClip.requestedSelection.fadeOutDuration, sourceClip.requestedSelection.fadeOutDuration + 0.5)
        XCTAssertNil(copiedClip.generatedAsset.relativePath)
        XCTAssertNotEqual(copiedClip.generationKey, sourceClip.generationKey)
        XCTAssertEqual(
            model.selectedTeam?.songClip(for: alex)?.generatedAsset.relativePath,
            "GeneratedClips/original-ready-fade.m4a"
        )
    }

    func testPlayerEditorStyleFadeEditPreservesOriginalSourceAndInvalidatesGeneratedAsset() {
        var sourceClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "original-local.m4a"))
        sourceClip.generatedAsset = GeneratedClipAsset(
            relativePath: "GeneratedClips/player-ready.m4a",
            status: .ready,
            renderedSelection: sourceClip.requestedSelection,
            generationKey: sourceClip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        sourceClip.readinessInputs.playback = .localClipReady
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        player.songAssignment = .privateClip(sourceClip)

        var editedCue = sourceClip.editingCue
        editedCue.fadeOutDuration += 0.5
        player.updatePrivateSongClip(with: editedCue)

        let editedClip = player.songAssignment?.privateClip
        XCTAssertEqual(editedClip?.id, sourceClip.id)
        XCTAssertEqual(editedClip?.requestedSelection.fadeOutDuration, sourceClip.requestedSelection.fadeOutDuration + 0.5)
        XCTAssertNil(editedClip?.generatedAsset.relativePath)
        guard case .localAudio(let editableSource)? = editedClip?.editingCue.source else {
            return XCTFail("Expected editing to stay attached to the original local source.")
        }
        XCTAssertEqual(editableSource.relativePath, "original-local.m4a")
    }

    @MainActor
    func testDuplicatingTeamPreservesReadyClipOriginalSource() throws {
        var sourceClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "original-local.m4a"))
        sourceClip.generatedAsset = GeneratedClipAsset(
            relativePath: "GeneratedClips/team-ready.m4a",
            status: .ready,
            renderedSelection: sourceClip.requestedSelection,
            generationKey: sourceClip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        sourceClip.readinessInputs.playback = .localClipReady
        var alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        alex.songAssignment = .privateClip(sourceClip)
        try writeState(RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [alex])))
        let model = AppModel()

        model.duplicateTeam()

        let duplicatedTeam = try XCTUnwrap(model.state.teams.first { $0.name.hasSuffix(" Copy") })
        let duplicatedPlayer = try XCTUnwrap(duplicatedTeam.players.first)
        let duplicatedClip = try XCTUnwrap(duplicatedPlayer.songAssignment?.privateClip)
        XCTAssertNotEqual(duplicatedClip.id, sourceClip.id)
        XCTAssertEqual(duplicatedClip.sourceLineageClipID, sourceClip.id)
        XCTAssertEqual(duplicatedClip.generatedAsset.relativePath, "GeneratedClips/team-ready.m4a")
        guard case .localAudio(let editableSource) = duplicatedClip.editingCue.source else {
            return XCTFail("Expected duplicated clip editing to use the original local source.")
        }
        XCTAssertEqual(editableSource.relativePath, "original-local.m4a")
        guard case .localAudio(let playbackSource) = duplicatedClip.playbackCue.source else {
            return XCTFail("Expected duplicated clip playback to use the ready generated file.")
        }
        XCTAssertEqual(playbackSource.relativePath, "GeneratedClips/team-ready.m4a")
    }

    func testRuntimeVolumeAutomationAppliesOnlyToSourceBackedAppleMusic() {
        let localSource = RollCallTestFixtures.localCue().source
        let builtInSource = CueSource.builtInClip(
            BuiltInClipSource(id: "test", displayName: "Test")
        )
        let appleMusicSource = RollCallTestFixtures.appleMusicCue(
            songID: "123",
            title: "Song",
            artistName: "Artist"
        ).source
        var libraryCue = RollCallTestFixtures.appleMusicCue(
            songID: "library-123",
            title: "Library Song",
            artistName: "Artist"
        )
        if case .appleMusic(var source) = libraryCue.source {
            source.libraryPersistentID = 123
            libraryCue.source = .appleMusic(source)
        }
        var generatedLibraryClip = SongClip(cue: libraryCue)
        generatedLibraryClip.generatedAsset = GeneratedClipAsset(
            relativePath: "GeneratedClips/library-ready.m4a",
            status: .ready,
            renderedSelection: generatedLibraryClip.requestedSelection,
            generationKey: generatedLibraryClip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )

        XCTAssertFalse(localSource.runtimeVolumeAutomationEnabled(whenSettingEnabled: true))
        XCTAssertFalse(builtInSource.runtimeVolumeAutomationEnabled(whenSettingEnabled: true))
        XCTAssertTrue(appleMusicSource.runtimeVolumeAutomationEnabled(whenSettingEnabled: true))
        XCTAssertTrue(libraryCue.source.runtimeVolumeAutomationEnabled(whenSettingEnabled: true))
        XCTAssertFalse(generatedLibraryClip.playbackCue.source.runtimeVolumeAutomationEnabled(whenSettingEnabled: true))
        XCTAssertFalse(appleMusicSource.runtimeVolumeAutomationEnabled(whenSettingEnabled: false))
    }

    /// The fallback chain in `AGENTS.md` ends at "generic cheering fallback", so a
    /// playback failure on *any* player-specific source — Apple Music or imported
    /// local audio — must still reach the built-in cheer. Only a failed built-in
    /// cue returns nil, because there is nothing further to fall back to and
    /// retrying Small Cheer with Small Cheer would loop.
    ///
    /// This previously asserted that a failed local cue produced no fallback,
    /// which would have left Game Day silent — the outcome the invariant forbids.
    @MainActor
    func testPlaybackFailureFallsBackToBuiltInCheerForEveryPlayerSource() throws {
        let appleMusicCue = RollCallTestFixtures.appleMusicCue(
            songID: "apple-music-unavailable",
            title: "Unavailable Song",
            artistName: "Artist"
        )
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        player.songAssignment = .privateClip(SongClip(cue: appleMusicCue))
        try writeState(RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [player])))
        try writeAsset("small-cheer.mp3")
        let model = AppModel()
        let loadedPlayer = try XCTUnwrap(model.selectedTeam?.players.first)

        let fallbackCue = try XCTUnwrap(
            model.fallbackCueAfterPlaybackFailure(for: loadedPlayer, failedCue: appleMusicCue)
        )

        XCTAssertEqual(fallbackCue.id, appleMusicCue.id)
        guard case .builtInClip(let source) = fallbackCue.source else {
            return XCTFail("Expected Apple Music playback failure to resolve to the built-in fallback cue.")
        }
        XCTAssertEqual(source.id, "small-cheer")

        // Imported local audio that fails must also reach the cheer fallback.
        let failedLocalCue = RollCallTestFixtures.localCue()
        let localFallback = try XCTUnwrap(
            model.fallbackCueAfterPlaybackFailure(for: loadedPlayer, failedCue: failedLocalCue),
            "A failed local cue must still fall back to the built-in cheer, not go silent."
        )
        XCTAssertEqual(localFallback.id, failedLocalCue.id)
        guard case .builtInClip(let localFallbackSource) = localFallback.source else {
            return XCTFail("Expected local playback failure to resolve to the built-in fallback cue.")
        }
        XCTAssertEqual(localFallbackSource.id, "small-cheer")

        // A built-in cue that fails has nothing further to fall back to.
        XCTAssertNil(
            model.fallbackCueAfterPlaybackFailure(
                for: loadedPlayer,
                failedCue: fallbackCue
            )
        )
    }

    /// Volume Automation fades Apple Music through `MPMusicPlayerController`'s
    /// `volume` setter. That property is public and still shipping, but was
    /// deprecated in iOS 7 — before this app's iOS 17 floor — so Swift imports it as
    /// unavailable and it can only be reached by KVC. `setPlayerVolume` probes for
    /// the selector first so that if Apple ever removes it the feature degrades to a
    /// no-op instead of raising an uncatchable `NSUnknownKeyException` mid-cue.
    ///
    /// This test asserts the probe still finds it. If this ever fails, Volume
    /// Automation has silently stopped working and needs a real replacement
    /// (`MPVolumeView`) rather than a louder guard.
    func testDeprecatedMusicPlayerVolumeSetterIsStillAvailableForVolumeAutomation() {
        XCTAssertTrue(
            MPMusicPlayerController.instancesRespond(to: NSSelectorFromString("setVolume:")),
            "Volume Automation is now a silent no-op for Apple Music cues."
        )
    }

    /// Progress publishes at 20 Hz and republishes the whole `CuePlaybackEngine`,
    /// rebuilding every Game Day view that observes it. Only the clip editor reads
    /// `activeCueProgress`, so a live Game Day cue must not turn the tracker on.
    @MainActor
    func testLiveCuePublishesNoProgressWhileClipEditorPreviewDoes() async throws {
        // `writeAsset` writes the literal bytes "test"; AVAudioPlayer needs real audio.
        try writeSilentAudio(to: try AppPaths.assetURL(relativePath: "progress.caf"), duration: 2)
        let engine = CuePlaybackEngine(
            audioAssetService: AudioAssetService(),
            musicCatalogService: MusicCatalogService()
        )
        // Distinct ids so the engine's 0.45s same-cue debounce does not swallow the
        // second play.
        var liveCue = RollCallTestFixtures.localCue(relativePath: "progress.caf")
        liveCue.id = UUID()
        var previewCue = liveCue
        previewCue.id = UUID()

        // Game Day path: no `tracksProgress`, so nothing is published.
        _ = try await engine.play(cue: liveCue, fadeOutVolumeAutomationEnabled: false)
        XCTAssertNil(engine.activeCueProgress, "Live Game Day playback must not drive the 20 Hz progress tracker.")
        engine.stop()

        // Clip editor preview path: opts in explicitly.
        _ = try await engine.play(cue: previewCue, fadeOutVolumeAutomationEnabled: false, tracksProgress: true)
        XCTAssertNotNil(engine.activeCueProgress, "The clip editor still needs its playhead.")
        engine.stop()
        XCTAssertNil(engine.activeCueProgress)
    }

    /// Backs the Custom Clip "Replace Source" action added for H4. A clip whose
    /// audio is gone previously had no way to be pointed at new audio — the only
    /// recovery was delete and recreate, losing the clip's name and its position in
    /// the live Clips grid, both of which the user arranged deliberately.
    @MainActor
    func testReplacingCustomClipSourceKeepsNameAndPositionAndRestoresPlayback() async throws {
        var brokenClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "gone.m4a"))
        brokenClip.id = UUID()
        brokenClip.displayName = "Rally Song"
        // A stale generated asset from before the source went missing.
        brokenClip.generatedAsset = GeneratedClipAsset(
            relativePath: "GeneratedClips/stale.m4a",
            status: .ready,
            renderedSelection: brokenClip.requestedSelection,
            generationKey: brokenClip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )

        var firstClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "first.caf"))
        firstClip.id = UUID()
        firstClip.displayName = "First"
        var lastClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "last.caf"))
        lastClip.id = UUID()
        lastClip.displayName = "Last"

        var team = RollCallTestFixtures.team()
        team.teamClips = [firstClip, brokenClip, lastClip]
        try writeState(RollCallTestFixtures.appState(team: team))
        try writeSilentAudio(to: try AppPaths.assetURL(relativePath: "first.caf"), duration: 1)
        try writeSilentAudio(to: try AppPaths.assetURL(relativePath: "last.caf"), duration: 1)
        // "gone.m4a" is deliberately never written — this is the broken clip.
        try writeSilentAudio(to: try AppPaths.assetURL(relativePath: "replacement.caf"), duration: 1)

        let model = AppModel()
        let stored = try XCTUnwrap(model.selectedTeam?.teamClips[1])
        XCTAssertEqual(stored.id, brokenClip.id)
        XCTAssertFalse(model.customClipCanPlay(stored), "Fixture should start unplayable.")

        // What the Replace Source flow ultimately calls.
        let replacement = Cue.localDefault(
            source: LocalAudioSource(
                id: UUID(),
                displayName: "Replacement Audio",
                relativePath: "replacement.caf",
                duration: 1,
                importedAt: RollCallTestFixtures.now,
                hiddenOriginNote: nil
            )
        )
        model.updateCustomClip(brokenClip.id, with: replacement, named: stored.displayName ?? "")
        await model.flushLatestState()

        let clips = try XCTUnwrap(model.selectedTeam?.teamClips)
        XCTAssertEqual(clips.count, 3)
        XCTAssertEqual(clips[1].id, brokenClip.id, "Replacing the source must not move the clip in the grid.")
        XCTAssertEqual(clips.map(\.displayName), ["First", "Rally Song", "Last"], "The clip's name must survive.")

        let replaced = clips[1]
        guard case .localAudio(let source) = replaced.originalSource else {
            return XCTFail("Expected the replacement local source.")
        }
        XCTAssertEqual(source.relativePath, "replacement.caf")
        XCTAssertTrue(model.customClipCanPlay(replaced), "The clip must be playable again.")
        XCTAssertNotEqual(
            replaced.generatedAsset.relativePath,
            "GeneratedClips/stale.m4a",
            "A new source changes the generation key, so the stale generated asset must be dropped."
        )
    }

    func testSourceBackedFadeScheduleEndsFadeAtSelectedDuration() {
        let schedule = PlaybackFadeSchedule.sourceBacked(
            selectedDuration: 12,
            tailGuard: 0.75,
            fadeOut: 2,
            volumeAutomationEnabled: true
        )

        XCTAssertEqual(schedule.sustainDuration, 10)
        XCTAssertEqual(schedule.fadeDuration, 2)
        XCTAssertEqual(schedule.postFadeStopDelay, 0.75)
        XCTAssertEqual(schedule.stopDelay, 12.75)
    }

    func testSourceBackedFadeScheduleUsesTailOnlyWhenAutomationIsOff() {
        let schedule = PlaybackFadeSchedule.sourceBacked(
            selectedDuration: 12,
            tailGuard: 0.75,
            fadeOut: 2,
            volumeAutomationEnabled: false
        )

        XCTAssertEqual(schedule.sustainDuration, 12.75)
        XCTAssertEqual(schedule.fadeDuration, 0)
        XCTAssertEqual(schedule.postFadeStopDelay, 0)
        XCTAssertEqual(schedule.stopDelay, 12.75)
    }

    func testSourceBackedFadeScheduleClampsFadeToSelectedDuration() {
        let schedule = PlaybackFadeSchedule.sourceBacked(
            selectedDuration: 1.5,
            tailGuard: 0.75,
            fadeOut: 4,
            volumeAutomationEnabled: true
        )

        XCTAssertEqual(schedule.sustainDuration, 0)
        XCTAssertEqual(schedule.fadeDuration, 1.5)
        XCTAssertEqual(schedule.postFadeStopDelay, 0.75)
        XCTAssertEqual(schedule.stopDelay, 2.25)
    }

    func testPlaybackVolumeBaselineFadesInPlayerDomainAndRestoresIt() {
        let baseline = PlaybackVolumeBaseline(
            systemOutputVolume: 0.40,
            playbackVolume: 0.90
        )

        XCTAssertEqual(baseline.systemOutputVolume, 0.40, accuracy: 0.001)
        XCTAssertEqual(baseline.playbackVolume(at: 1), 0.90, accuracy: 0.001)
        XCTAssertEqual(baseline.playbackVolume(at: 0.5), 0.45, accuracy: 0.001)
        XCTAssertEqual(baseline.playbackVolume(at: 0), 0, accuracy: 0.001)
        XCTAssertEqual(baseline.playbackVolume, 0.90, accuracy: 0.001)
    }

    func testPlaybackVolumeBaselineClampsInvalidInputs() {
        let baseline = PlaybackVolumeBaseline(
            systemOutputVolume: .nan,
            playbackVolume: 2
        )

        XCTAssertEqual(baseline.systemOutputVolume, 1, accuracy: 0.001)
        XCTAssertEqual(baseline.playbackVolume, 1, accuracy: 0.001)
        XCTAssertEqual(baseline.playbackVolume(at: -1), 0, accuracy: 0.001)
        XCTAssertEqual(baseline.playbackVolume(at: .infinity), 0, accuracy: 0.001)
    }

    func testMissingLocalSourceFailsPermanentlyWithoutCreatingAsset() async {
        let service = SongClipGenerationService()
        let clip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "missing.caf"))

        let outcome = await service.prepare(clip)

        XCTAssertEqual(outcome, .failed(code: .sourceMissing, retryable: false))
    }

    func testUnreadablePresentSourceReturnsRetryableRenderFailure() async throws {
        let relativePath = "unreadable.m4a"
        try Data("not-audio".utf8).write(to: AppPaths.assetURL(relativePath: relativePath))
        let clip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: relativePath))

        let outcome = await SongClipGenerationService().prepare(clip)

        XCTAssertEqual(outcome, .failed(code: .renderFailed, retryable: true))
    }

    func testAlreadyCancelledGenerationCreatesNoTemporaryOrFinalOutput() async throws {
        let relativePath = "cancel-before-start.caf"
        try writeSilentAudio(
            to: AppPaths.assetURL(relativePath: relativePath),
            duration: 1
        )
        let clip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: relativePath))
        let expectedGeneratedURL = try generatedURL(for: clip)
        let temporaryFilesBefore = try generatedTemporaryFiles()
        let gate = CancellationStartGate()
        let task = Task {
            await gate.wait()
            return await SongClipGenerationService().prepare(clip)
        }

        for _ in 0..<200 {
            if await gate.isWaiting { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let isWaiting = await gate.isWaiting
        XCTAssertTrue(isWaiting)

        task.cancel()
        await gate.release()
        let outcome = await task.value

        XCTAssertEqual(outcome, .failed(code: .renderFailed, retryable: true))
        XCTAssertFalse(FileManager.default.fileExists(atPath: expectedGeneratedURL.path))
        XCTAssertEqual(try generatedTemporaryFiles(), temporaryFilesBefore)
    }

    func testCancellingInFlightGenerationStopsAndCleansOutput() async throws {
        let relativePath = "cancel-in-flight.caf"
        try writeChunkedSilentAudio(
            to: AppPaths.assetURL(relativePath: relativePath),
            duration: 180
        )
        var cue = RollCallTestFixtures.localCue(relativePath: relativePath)
        cue.duration = 180
        let clip = SongClip(cue: cue)
        let expectedGeneratedURL = try generatedURL(for: clip)
        let temporaryFilesBefore = try generatedTemporaryFiles()
        let task = Task {
            await SongClipGenerationService().prepare(clip)
        }

        let exportStarted = try await waitForNewGeneratedTemporaryFile(
            excluding: temporaryFilesBefore,
            timeout: .seconds(10)
        )
        XCTAssertTrue(exportStarted)

        let cancellationStarted = ContinuousClock.now
        task.cancel()
        let outcome = await task.value
        let cancellationDuration = cancellationStarted.duration(to: .now)

        XCTAssertEqual(outcome, .failed(code: .renderFailed, retryable: true))
        XCTAssertLessThan(cancellationDuration, .seconds(5))
        XCTAssertFalse(FileManager.default.fileExists(atPath: expectedGeneratedURL.path))
        XCTAssertEqual(try generatedTemporaryFiles(), temporaryFilesBefore)
    }

    func testReadableLocalSourceGeneratesPortableM4A() async throws {
        let relativePath = "source.caf"
        let sourceURL = try AppPaths.assetURL(relativePath: relativePath)
        try writeSilentAudio(to: sourceURL, duration: 1)
        var cue = RollCallTestFixtures.localCue(relativePath: relativePath)
        cue.startTime = 0.1
        cue.duration = 0.5
        cue.fadeOutDuration = 0.1
        let clip = SongClip(cue: cue)

        let outcome = await SongClipGenerationService().prepare(clip)

        guard case .generated(let asset) = outcome else {
            return XCTFail("Expected a generated local clip, got \(outcome).")
        }
        XCTAssertEqual(asset.status, .ready)
        XCTAssertEqual(asset.generationKey, clip.generationKey)
        let renderedSelection = try XCTUnwrap(asset.renderedSelection)
        XCTAssertEqual(renderedSelection.startTime, 0.1, accuracy: 0.01)
        XCTAssertEqual(renderedSelection.duration, 0.5, accuracy: 0.02)
        XCTAssertTrue(asset.relativePath?.hasPrefix("GeneratedClips/") == true)
        let generatedRelativePath = try XCTUnwrap(asset.relativePath)
        let generatedURL = try AppPaths.assetURL(relativePath: generatedRelativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: generatedURL.path))
        XCTAssertEqual(generatedURL.pathExtension, "m4a")

        let generatedAVAsset = AVURLAsset(url: generatedURL)
        let generatedTracks = try await generatedAVAsset.loadTracks(withMediaType: .audio)
        let generatedDuration = CMTimeGetSeconds(try await generatedAVAsset.load(.duration))
        XCTAssertFalse(generatedTracks.isEmpty)
        XCTAssertEqual(generatedDuration, 0.5, accuracy: 0.08)
    }

    func testWaveformSamplerReflectsReadableAudioAmplitude() async throws {
        let sourceURL = try AppPaths.assetURL(relativePath: "waveform-source.caf")
        try writeSteppedAudio(to: sourceURL, duration: 1)

        let samples = try await SongWaveformService().samples(from: sourceURL, sampleCount: 20)

        XCTAssertEqual(samples.count, 20)
        XCTAssertLessThan(samples.prefix(8).max() ?? 1, 0.2)
        XCTAssertGreaterThan(samples.suffix(8).min() ?? 0, 0.9)
    }

    func testWaveformSamplerRejectsUnreadableAudio() async throws {
        let sourceURL = try AppPaths.assetURL(relativePath: "waveform-unreadable.m4a")
        try Data("not-audio".utf8).write(to: sourceURL)

        do {
            _ = try await SongWaveformService().samples(from: sourceURL, sampleCount: 20)
            XCTFail("Expected unreadable audio to fail waveform sampling.")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testChangingClipLengthKeepsWaveformStartPositionFixed() {
        let shortClip = SongShapeRailGeometry(
            width: 320,
            startTime: 60,
            duration: 8,
            timelineDuration: 180
        )
        let longClip = SongShapeRailGeometry(
            width: 320,
            startTime: 60,
            duration: 20,
            timelineDuration: 180
        )

        XCTAssertEqual(shortClip.offset, longClip.offset, accuracy: 0.001)
        XCTAssertEqual(shortClip.offset, 320 * 60 / 180, accuracy: 0.001)
        XCTAssertLessThan(shortClip.selectedWidth, longClip.selectedWidth)
    }

    func testWaveformDragMapsVisualPositionToTimelineStart() {
        let geometry = SongShapeRailGeometry(
            width: 320,
            startTime: 0,
            duration: 10,
            timelineDuration: 160
        )

        XCTAssertEqual(
            geometry.startTime(centeredAt: 170),
            80,
            accuracy: 0.001
        )
    }

    func testPrecisionStartAdjustmentClampsToAvailableTimeline() {
        let earlier = SongClipTimingAdjustment.adjustingStart(
            startTime: 0.1,
            duration: 10,
            fadeOutDuration: 2,
            delta: -0.25,
            timelineDuration: 180
        )
        let later = SongClipTimingAdjustment.adjustingStart(
            startTime: 169.75,
            duration: 10,
            fadeOutDuration: 2,
            delta: 1,
            timelineDuration: 180
        )

        XCTAssertEqual(earlier.startTime, 0)
        XCTAssertEqual(later.startTime, 170)
    }

    func testPrecisionLengthAdjustmentKeepsStartUnlessEndRequiresClamp() {
        let normal = SongClipTimingAdjustment.adjustingDuration(
            startTime: 60,
            duration: 8,
            fadeOutDuration: 2,
            delta: 0.25,
            timelineDuration: 180
        )
        let clamped = SongClipTimingAdjustment.adjustingDuration(
            startTime: 171,
            duration: 8,
            fadeOutDuration: 2,
            delta: 2,
            timelineDuration: 180
        )

        XCTAssertEqual(normal.startTime, 60)
        XCTAssertEqual(normal.duration, 8.25)
        XCTAssertEqual(clamped.startTime, 170)
        XCTAssertEqual(clamped.duration, 10)
    }

    func testPrecisionLengthAndFadeRespectBounds() {
        let minimumLength = SongClipTimingAdjustment.adjustingDuration(
            startTime: 0,
            duration: 1,
            fadeOutDuration: 1,
            delta: -1,
            timelineDuration: 180
        )
        let maximumLength = SongClipTimingAdjustment.adjustingDuration(
            startTime: 0,
            duration: 20,
            fadeOutDuration: 2,
            delta: 1,
            timelineDuration: 180
        )
        let maximumFade = SongClipTimingAdjustment.adjustingFade(
            startTime: 0,
            duration: 3,
            fadeOutDuration: 2.75,
            delta: 1,
            timelineDuration: 180
        )

        XCTAssertEqual(minimumLength.duration, 1)
        XCTAssertEqual(maximumLength.duration, 20)
        XCTAssertEqual(maximumFade.fadeOutDuration, 3)
    }

    func testQueueDeduplicatesPlayerRequestsAndHonorsLowPowerPause() async {
        let queue = SongClipGenerationQueue()
        let first = request(key: "first")
        let replacement = request(key: "replacement")

        await queue.enqueue(first)
        await queue.enqueue(replacement)
        await queue.setPaused(true, reason: .lowPowerMode)

        let pausedNext = await queue.next()
        let pausedCount = await queue.pendingCount()
        XCTAssertNil(pausedNext)
        XCTAssertEqual(pausedCount, 1)

        await queue.setPaused(false, reason: .lowPowerMode)
        let next = await queue.next()
        XCTAssertEqual(next, replacement)
        await queue.complete(replacement)
        let completedCount = await queue.pendingCount()
        XCTAssertEqual(completedCount, 0)
    }

    func testQueueKeepsPlayerAndTeamClipTargetsIndependent() async {
        let queue = SongClipGenerationQueue()
        let playerRequest = request(key: "player")
        var teamClipRequest = request(key: "team")
        teamClipRequest.target = .teamClip(teamClipRequest.clipID)

        await queue.enqueue(playerRequest)
        await queue.enqueue(teamClipRequest)

        let first = await queue.next()
        XCTAssertEqual(first, playerRequest)
        await queue.complete(playerRequest)
        let second = await queue.next()
        XCTAssertEqual(second, teamClipRequest)
    }

    func testExplicitRequestBypassesLowPowerPause() async {
        let queue = SongClipGenerationQueue()
        var explicit = request(key: "explicit")
        explicit.isExplicit = true
        await queue.enqueue(explicit)
        await queue.setPaused(true, reason: .lowPowerMode)

        let lowPowerNext = await queue.next()
        XCTAssertEqual(lowPowerNext, explicit)
        await queue.complete(explicit)
    }

    @MainActor
    func testFailedRegenerationPreservesExistingReadyGeneratedAsset() async throws {
        let generatedRelativePath = "GeneratedClips/existing.m4a"
        let generatedURL = try AppPaths.assetURL(relativePath: generatedRelativePath)
        try Data("existing-generated-audio".utf8).write(to: generatedURL)
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "missing-original.caf")
        )
        guard case .privateClip(var clip)? = player.songAssignment else {
            return XCTFail("Expected a private song assignment.")
        }
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: generatedRelativePath,
            status: .ready,
            renderedSelection: clip.requestedSelection,
            generationKey: clip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        clip.readinessInputs.playback = .localClipReady
        clip.portabilityInputs = SongClipPortabilityInputs(
            portability: .portableLocalClip,
            generatedAssetCanBeExported: true
        )
        player.songAssignment = .privateClip(clip)
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()

        model.tryPreparingSongNow(for: player.id)
        let updatedClip = try await waitForClip(in: model) {
            $0.retryMetadata.attemptCount == 1
        }

        XCTAssertEqual(updatedClip.generatedAsset.status, .ready)
        XCTAssertEqual(updatedClip.generatedAsset.relativePath, generatedRelativePath)
        XCTAssertEqual(updatedClip.readinessInputs.playback, .localClipReady)
        XCTAssertTrue(FileManager.default.fileExists(atPath: generatedURL.path))
    }

    private func request(key: String) -> SongClipPreparationRequest {
        SongClipPreparationRequest(
            id: UUID(),
            teamID: RollCallTestFixtures.teamID,
            target: .player(RollCallTestFixtures.alexID),
            clipID: RollCallTestFixtures.localCueID,
            generationKey: key,
            trigger: .assignmentSaved,
            isExplicit: false
        )
    }

    private func writeSilentAudio(to url: URL, duration: TimeInterval) throws {
        let format = try XCTUnwrap(
            AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        )
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        )
        buffer.frameLength = frameCount
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func writeChunkedSilentAudio(to url: URL, duration: TimeInterval) throws {
        let format = try XCTUnwrap(
            AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        )
        let framesPerChunk = AVAudioFrameCount(format.sampleRate)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerChunk)
        )
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        var remainingFrames = AVAudioFramePosition(duration * format.sampleRate)

        while remainingFrames > 0 {
            let frameCount = AVAudioFrameCount(
                min(remainingFrames, AVAudioFramePosition(framesPerChunk))
            )
            buffer.frameLength = frameCount
            try file.write(from: buffer)
            remainingFrames -= AVAudioFramePosition(frameCount)
        }
    }

    private func generatedURL(for clip: SongClip) throws -> URL {
        try AppPaths.generatedClipsDirectory().appendingPathComponent(
            "\(clip.id.uuidString.lowercased())-\(clip.generationKey.prefix(16)).m4a"
        )
    }

    private func generatedTemporaryFiles() throws -> Set<String> {
        Set(
            try FileManager.default.contentsOfDirectory(
                at: FileManager.default.temporaryDirectory,
                includingPropertiesForKeys: nil
            )
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix("RollCallGenerated-") && $0.hasSuffix(".m4a") }
        )
    }

    private func waitForNewGeneratedTemporaryFile(
        excluding existingFiles: Set<String>,
        timeout: Duration
    ) async throws -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if try !generatedTemporaryFiles().subtracting(existingFiles).isEmpty {
                return true
            }
            try await Task.sleep(for: .milliseconds(2))
        }
        return false
    }

    private func writeSteppedAudio(to url: URL, duration: TimeInterval) throws {
        let format = try XCTUnwrap(
            AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        )
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        )
        buffer.frameLength = frameCount
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for frame in 0..<Int(frameCount) {
            samples[frame] = frame < Int(frameCount) / 2 ? 0.05 : 0.8
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func writeState(_ state: AppState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: AppPaths.stateURL(), options: .atomic)
    }

    private func writeAsset(_ relativePath: String) throws {
        let url = try AppPaths.assetURL(relativePath: relativePath)
        try Data("test".utf8).write(to: url, options: .atomic)
    }

    @MainActor
    private func waitForTeamClip(
        in model: AppModel,
        id: UUID,
        matching predicate: (SongClip) -> Bool
    ) async throws -> SongClip {
        for _ in 0..<4_800 {
            if let clip = model.selectedTeam?.teamClips.first(where: { $0.id == id }),
               predicate(clip) {
                return clip
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        throw NSError(
            domain: "SongClipGenerationTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for Custom Clip preparation."]
        )
    }

    @MainActor
    private func waitForClip(
        in model: AppModel,
        matching predicate: (SongClip) -> Bool
    ) async throws -> SongClip {
        for _ in 0..<4_800 {
            if let clip = model.selectedTeam?.players.first?.songAssignment?.privateClip,
               predicate(clip) {
                return clip
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        throw NSError(
            domain: "SongClipGenerationTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for song clip preparation."]
        )
    }
}

final class TeamAccentThemeContrastTests: XCTestCase {
    func testGoldOnFillUsesDarkForegroundInDarkMode() {
        let traits = UITraitCollection(userInterfaceStyle: .dark)
        let foreground = TeamAccentPreset.gold.theme.uiColor(.onFill).resolvedColor(with: traits)

        XCTAssertTrue(foreground.rollCallTestMatches(.black, traits: traits))
    }

    func testOnFillChoosesHigherContrastForegroundForEveryAccent() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)

            for preset in TeamAccentPreset.allCases {
                let theme = preset.theme
                let fill = theme.uiColor(.fill).resolvedColor(with: traits)
                let foreground = theme.uiColor(.onFill).resolvedColor(with: traits)
                let blackContrast = UIColor.rollCallTestContrastRatio(between: .black, and: fill)
                let whiteContrast = UIColor.rollCallTestContrastRatio(between: .white, and: fill)
                let chosenContrast = UIColor.rollCallTestContrastRatio(between: foreground, and: fill)

                XCTAssertEqual(
                    chosenContrast,
                    max(blackContrast, whiteContrast),
                    accuracy: 0.001,
                    "\(preset.title) should use the higher-contrast on-fill color in \(style == .dark ? "dark" : "light") mode."
                )
            }
        }
    }
}

private extension UIColor {
    func rollCallTestMatches(_ expected: UIColor, traits: UITraitCollection) -> Bool {
        let lhs = rollCallTestSRGBComponents
        let rhs = expected.resolvedColor(with: traits).rollCallTestSRGBComponents
        return abs(lhs.red - rhs.red) < 0.001
            && abs(lhs.green - rhs.green) < 0.001
            && abs(lhs.blue - rhs.blue) < 0.001
    }

    static func rollCallTestContrastRatio(between foreground: UIColor, and background: UIColor) -> CGFloat {
        let foregroundLuminance = foreground.rollCallTestRelativeLuminance
        let backgroundLuminance = background.rollCallTestRelativeLuminance
        return (max(foregroundLuminance, backgroundLuminance) + 0.05) / (min(foregroundLuminance, backgroundLuminance) + 0.05)
    }

    var rollCallTestRelativeLuminance: CGFloat {
        let components = rollCallTestSRGBComponents
        return 0.2126 * UIColor.rollCallTestLinearComponent(components.red)
            + 0.7152 * UIColor.rollCallTestLinearComponent(components.green)
            + 0.0722 * UIColor.rollCallTestLinearComponent(components.blue)
    }

    var rollCallTestSRGBComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return (0, 0, 0)
        }

        return (red, green, blue)
    }

    static func rollCallTestLinearComponent(_ value: CGFloat) -> CGFloat {
        value <= 0.03928
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
}
