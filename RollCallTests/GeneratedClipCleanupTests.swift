import XCTest
@testable import RollCall

final class GeneratedClipCleanupTests: XCTestCase {
    private var temp: RollCallTemporaryDirectory!
    private let service = GeneratedClipCleanupService()

    override func setUpWithError() throws {
        temp = try RollCallTemporaryDirectory()
        AppPaths.testBaseDirectoryOverride = temp.fileURL("AppSupport")
    }

    override func tearDownWithError() throws {
        AppPaths.testBaseDirectoryOverride = nil
        temp = nil
    }

    func testCleanupRemovesOnlyUnreferencedGeneratedFiles() throws {
        let referenced = try writeGeneratedFile("referenced.m4a", bytes: 7)
        let orphaned = try writeGeneratedFile("orphaned.m4a", bytes: 11)
        let state = stateReferencingGeneratedClip("GeneratedClips/\(referenced.lastPathComponent)")

        let report = service.clean(state: state, activePreparationCount: 0)

        XCTAssertNil(report.blockedReason)
        XCTAssertEqual(report.removedFileCount, 1)
        XCTAssertEqual(report.removedByteCount, 11)
        XCTAssertTrue(FileManager.default.fileExists(atPath: referenced.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphaned.path))
    }

    func testCleanupRetainsGeneratedFilesReferencedByRecentlyDeleted() throws {
        let retained = try writeGeneratedFile("deleted-player.m4a", bytes: 5)
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex",
            number: "7",
            cue: RollCallTestFixtures.localCue()
        )
        player.songAssignment = .privateClip(
            generatedClip(relativePath: "GeneratedClips/\(retained.lastPathComponent)")
        )
        var state = RollCallTestFixtures.appState()
        state.recentlyDeleted = [
            RecentlyDeletedItem(
                id: UUID(),
                deletedAt: .now,
                payload: .player(
                    DeletedPlayerRecord(
                        player: player,
                        originalTeamID: RollCallTestFixtures.teamID,
                        originalTeamName: "Thunder",
                        previousBattingOrder: [player.id]
                    )
                )
            )
        ]

        let report = service.clean(state: state, activePreparationCount: 0)

        XCTAssertEqual(report.removedFileCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: retained.path))
    }

    func testCleanupRetainsGeneratedFilesReferencedByTeamClip() throws {
        let retained = try writeGeneratedFile("team-clip.m4a", bytes: 6)
        var team = RollCallTestFixtures.team()
        team.teamClips = [
            generatedClip(relativePath: "GeneratedClips/\(retained.lastPathComponent)")
        ]

        let report = service.clean(
            state: RollCallTestFixtures.appState(team: team),
            activePreparationCount: 0
        )

        XCTAssertEqual(report.removedFileCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: retained.path))
    }

    func testCleanupRetainsGeneratedFilesReferencedByBackupSnapshot() throws {
        let retained = try writeGeneratedFile("backup.m4a", bytes: 9)
        let snapshotState = stateReferencingGeneratedClip("GeneratedClips/\(retained.lastPathComponent)")
        let snapshotName = "backup.json"
        try writeSnapshot(snapshotState, named: snapshotName)
        var current = RollCallTestFixtures.appState()
        current.snapshots = [
            SnapshotRecord(
                id: UUID(),
                createdAt: .now,
                reason: "Backup",
                relativeManifestPath: snapshotName
            )
        ]

        let report = service.clean(state: current, activePreparationCount: 0)

        XCTAssertEqual(report.removedFileCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: retained.path))
    }

    func testCleanupRetainsGeneratedFilesReferencedByOrphanSnapshot() throws {
        let retained = try writeGeneratedFile("orphan-backup.m4a", bytes: 9)
        let snapshotState = stateReferencingGeneratedClip("GeneratedClips/\(retained.lastPathComponent)")
        try writeSnapshot(snapshotState, named: "orphan-backup.json")

        let report = service.clean(
            state: RollCallTestFixtures.appState(),
            activePreparationCount: 0
        )

        XCTAssertEqual(report.removedFileCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: retained.path))
    }

    func testCleanupAbortsWhenBackupCannotBeRead() throws {
        let retained = try writeGeneratedFile("uncertain.m4a", bytes: 13)
        var state = RollCallTestFixtures.appState()
        state.snapshots = [
            SnapshotRecord(
                id: UUID(),
                createdAt: .now,
                reason: "Missing Backup",
                relativeManifestPath: "missing.json"
            )
        ]

        let report = service.clean(state: state, activePreparationCount: 0)

        XCTAssertNotNil(report.blockedReason)
        XCTAssertEqual(report.removedFileCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: retained.path))
    }

    func testCleanupDefersWhilePreparationIsActive() throws {
        let retained = try writeGeneratedFile("preparing.m4a", bytes: 3)

        let report = service.clean(
            state: RollCallTestFixtures.appState(),
            activePreparationCount: 1
        )

        XCTAssertNotNil(report.blockedReason)
        XCTAssertTrue(FileManager.default.fileExists(atPath: retained.path))
    }

    func testUnexpectedGeneratedDirectoryEntryBlocksCleanup() throws {
        let retained = try writeGeneratedFile("orphan.m4a", bytes: 4)
        try FileManager.default.createDirectory(
            at: try AppPaths.generatedClipsDirectory().appendingPathComponent("unexpected"),
            withIntermediateDirectories: true
        )

        let report = service.clean(
            state: RollCallTestFixtures.appState(),
            activePreparationCount: 0
        )

        XCTAssertNotNil(report.blockedReason)
        XCTAssertEqual(report.removedFileCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: retained.path))
    }

    func testSupportBundleContainsAggregatesWithoutUserMetadata() throws {
        let generatedPath = "GeneratedClips/private-file-name.m4a"
        _ = try writeGeneratedFile("private-file-name.m4a", bytes: 17)
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Sensitive Player Name",
            number: "7",
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "sensitive-song-id",
                title: "Sensitive Song Title",
                artistName: "Sensitive Artist"
            )
        )
        var clip = SongClip(cue: try XCTUnwrap(player.cue))
        clip.generatedAsset.relativePath = generatedPath
        clip.generatedAsset.status = .ready
        clip.retryMetadata.attemptCount = 2
        clip.retryMetadata.lastFailureCode = SongClipPreparationFailureCode.renderFailed.rawValue
        player.songAssignment = .privateClip(clip)
        var team = RollCallTestFixtures.team(players: [player])
        team.name = "Sensitive Team Name"
        var state = RollCallTestFixtures.appState(team: team)
        state.lastReadiness = ReadinessStatus(
            generatedAt: .now,
            checks: [
                ReadinessCheck(
                    id: "player-\(player.id)-ready",
                    title: player.displayName,
                    detail: "Sensitive readiness detail",
                    state: .ready
                )
            ]
        )
        let cleanup = service.audit(state: state, activePreparationCount: 0)

        let url = try PackageService().exportSupportBundle(
            state: state,
            selectedTeam: team,
            diagnostics: PlaybackSupportDiagnostics(
                activeCueID: player.id,
                prewarmedCueID: clip.id,
                lastStartedCueID: RollCallTestFixtures.localCueID,
                debounceWindowSeconds: 0.25
            ),
            generatedClipCleanup: cleanup
        )
        let text = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(text.contains("\"totalClipCount\" : 1"))
        XCTAssertTrue(text.contains("\"generatedAssetDiskUsageBytes\" : 17"))
        XCTAssertTrue(text.contains("\"hasActiveCue\" : true"))
        XCTAssertFalse(text.contains("Sensitive Player Name"))
        XCTAssertFalse(text.contains("Sensitive Team Name"))
        XCTAssertFalse(text.contains("Sensitive Song Title"))
        XCTAssertFalse(text.contains("Sensitive Artist"))
        XCTAssertFalse(text.contains("sensitive-song-id"))
        XCTAssertFalse(text.contains("private-file-name.m4a"))
        XCTAssertFalse(text.contains(player.id.uuidString))
        XCTAssertFalse(text.contains(clip.id.uuidString))
        XCTAssertFalse(text.contains("Sensitive readiness detail"))
    }

    private func stateReferencingGeneratedClip(_ relativePath: String) -> AppState {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex",
            number: "7",
            cue: RollCallTestFixtures.localCue()
        )
        player.songAssignment = .privateClip(generatedClip(relativePath: relativePath))
        return RollCallTestFixtures.appState(
            team: RollCallTestFixtures.team(players: [player])
        )
    }

    private func generatedClip(relativePath: String) -> SongClip {
        var clip = SongClip(cue: RollCallTestFixtures.localCue())
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: relativePath,
            status: .ready,
            renderedSelection: clip.requestedSelection,
            generationKey: clip.generationKey,
            generatedAt: .now
        )
        return clip
    }

    private func writeGeneratedFile(_ name: String, bytes: Int) throws -> URL {
        let url = try AppPaths.generatedClipsDirectory().appendingPathComponent(name)
        try Data(repeating: 1, count: bytes).write(to: url)
        return url
    }

    private func writeSnapshot(_ state: AppState, named name: String) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = try AppPaths.snapshotsDirectory().appendingPathComponent(name)
        try encoder.encode(state).write(to: url)
    }
}
