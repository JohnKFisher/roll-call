import XCTest
@testable import RollCall

final class BackupRestoreTests: XCTestCase {
    private var temp: RollCallTemporaryDirectory!

    override func setUpWithError() throws {
        temp = try RollCallTemporaryDirectory()
        AppPaths.testBaseDirectoryOverride = temp.fileURL("AppSupport")
    }

    override func tearDownWithError() throws {
        AppPaths.testBaseDirectoryOverride = nil
        temp = nil
    }

    @MainActor
    func testPackageImportCreatesAutomaticBackupBeforeChangingTeams() async throws {
        let originalTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12"),
        ])
        let incomingTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.caseyID, name: "Casey Morgan", number: "9"),
        ])
        let initialState = RollCallTestFixtures.appState(team: originalTeam)
        try writeState(initialState)
        let packageURL = try writePackageDirectory(
            name: "Incoming.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: TeamPackageManifest.currentSchemaVersion,
                appVersion: "1.0.1",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: incomingTeam
            )
        )
        let model = AppModel()

        await model.importPackage(from: packageURL)

        XCTAssertNil(model.lastError)
        XCTAssertEqual(model.state.teams.count, 2)
        XCTAssertEqual(model.state.snapshots.first?.reason, "Automatic backup before package import")
        let backupState = try readStateSnapshot(model.state.snapshots[0])
        XCTAssertEqual(backupState.teams.map(\.name), initialState.teams.map(\.name))
    }

    @MainActor
    func testFailedPackageImportLeavesStateUnchangedAndRecordsError() async throws {
        let originalTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12"),
        ])
        let initialState = RollCallTestFixtures.appState(team: originalTeam)
        try writeState(initialState)
        let brokenPackageURL = temp.fileURL("Broken.rollcall")
        try FileManager.default.createDirectory(at: brokenPackageURL, withIntermediateDirectories: true)
        let model = AppModel()

        await model.importPackage(from: brokenPackageURL)

        XCTAssertNotNil(model.lastError)
        XCTAssertEqual(model.state.teams, initialState.teams)
    }

    @MainActor
    func testRestoreBackupCreatesAutomaticPreRestoreBackupAndRestoresRoster() async throws {
        let currentTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12"),
        ])
        let restoredTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.caseyID, name: "Casey Morgan", number: "9"),
        ])
        let restoredSnapshot = SnapshotRecord(
            id: UUID(),
            createdAt: RollCallTestFixtures.now,
            reason: "Manual backup",
            relativeManifestPath: "restore.json"
        )
        let currentState = RollCallTestFixtures.appState(team: currentTeam, snapshots: [restoredSnapshot])
        try writeState(currentState)
        try writeSnapshotState(RollCallTestFixtures.appState(team: restoredTeam), fileName: restoredSnapshot.relativeManifestPath)
        let model = AppModel()

        await model.restoreBackup(restoredSnapshot)

        XCTAssertNil(model.lastError)
        XCTAssertEqual(model.state.teams.first?.players.map(\.displayName), ["Casey Morgan"])
        XCTAssertEqual(model.state.snapshots.first?.reason, "Automatic backup before restore")
    }

    @MainActor
    func testBackupsDoNotStoreRecentlyDeletedItemsAndRestoreKeepsCurrentRecoveryList() async throws {
        let currentTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12"),
        ])
        let deletedPlayer = RollCallTestFixtures.player(id: RollCallTestFixtures.caseyID, name: "Casey Morgan", number: "9")
        var currentState = RollCallTestFixtures.appState(team: currentTeam)
        currentState.recentlyDeleted = [
            RecentlyDeletedItem(
                id: UUID(),
                deletedAt: .now,
                payload: .player(
                    DeletedPlayerRecord(
                        player: deletedPlayer,
                        originalTeamID: currentTeam.id,
                        originalTeamName: currentTeam.name,
                        previousBattingOrder: [deletedPlayer.id]
                    )
                )
            )
        ]
        try writeState(currentState)
        let model = AppModel()

        try await model.createBackupAndWait(reason: "Manual backup")
        let snapshot = try XCTUnwrap(model.state.snapshots.first)

        let backupState = try readStateSnapshot(snapshot)
        XCTAssertTrue(backupState.recentlyDeleted.isEmpty)

        let restoredTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.caseyID, name: "Restored Casey", number: "9"),
        ])
        let restoreSnapshot = SnapshotRecord(
            id: UUID(),
            createdAt: RollCallTestFixtures.now,
            reason: "Manual backup",
            relativeManifestPath: "restore-without-recovery.json"
        )
        try writeSnapshotState(RollCallTestFixtures.appState(team: restoredTeam), fileName: restoreSnapshot.relativeManifestPath)

        await model.restoreBackup(restoreSnapshot)

        XCTAssertEqual(model.state.teams.first?.players.map(\.displayName), ["Restored Casey"])
        XCTAssertEqual(model.state.recentlyDeleted.count, 1)
        if case .player(let deletedPlayer)? = model.state.recentlyDeleted.first?.payload {
            XCTAssertEqual(deletedPlayer.player.displayName, "Casey Morgan")
            XCTAssertEqual(deletedPlayer.originalTeamID, currentTeam.id)
            XCTAssertEqual(deletedPlayer.originalTeamName, currentTeam.name)
            XCTAssertEqual(deletedPlayer.previousBattingOrder, [deletedPlayer.player.id])
        } else {
            XCTFail("Expected the current recovery list to survive backup restore.")
        }
    }

    @MainActor
    func testRemovingOneTeamKeepsSharedAssetsUsedByAnotherTeam() throws {
        var sharedPlayerOne = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "shared-song.m4a"),
            photoRelativePath: "shared-photo.jpg",
            customAnnouncerRelativePath: "shared-announcer.caf"
        )
        var sharedPlayerTwo = RollCallTestFixtures.player(
            id: RollCallTestFixtures.caseyID,
            name: "Casey Morgan",
            number: "9",
            cue: RollCallTestFixtures.localCue(relativePath: "shared-song.m4a"),
            photoRelativePath: "shared-photo.jpg",
            customAnnouncerRelativePath: "shared-announcer.caf"
        )
        sharedPlayerOne.photoSourceRelativePath = "shared-photo-master.jpg"
        sharedPlayerTwo.photoSourceRelativePath = "shared-photo-master.jpg"
        let firstTeam = RollCallTestFixtures.team(players: [sharedPlayerOne])
        var secondTeam = RollCallTestFixtures.team(players: [sharedPlayerTwo])
        secondTeam.id = UUID()
        secondTeam.name = "Lightning"

        try writeState(RollCallTestFixtures.appState(teams: [firstTeam, secondTeam], selectedTeamID: firstTeam.id))
        try writeAsset("shared-song.m4a")
        try writeAsset("shared-photo.jpg")
        try writeAsset("shared-photo-master.jpg")
        try writeAsset("shared-announcer.caf")
        let model = AppModel()

        model.removeSelectedTeam()

        XCTAssertEqual(model.state.teams.map(\.name), ["Lightning"])
        XCTAssertTrue(assetExists("shared-song.m4a"))
        XCTAssertTrue(assetExists("shared-photo.jpg"))
        XCTAssertTrue(assetExists("shared-photo-master.jpg"))
        XCTAssertTrue(assetExists("shared-announcer.caf"))
    }

    /// Snapshot asset references are cached and keyed on the snapshot record list,
    /// so a *newly created* backup must invalidate that cache. This does two photo
    /// replacements: the first warms the cache while only the original backup exists,
    /// then a second backup is taken that references the intermediate photo. If the
    /// cache went stale, that intermediate photo would look unreferenced and be
    /// deleted — losing a file a backup still depends on.
    @MainActor
    func testBackupCreatedAfterCacheIsWarmStillProtectsItsAssets() async throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            photoRelativePath: "photo-a.jpg"
        )
        player.photoSourceRelativePath = "master-a.jpg"
        try writeState(RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [player])))
        for name in ["photo-a.jpg", "master-a.jpg", "photo-b.jpg", "master-b.jpg", "photo-c.jpg", "master-c.jpg"] {
            try writeAsset(name)
        }
        let model = AppModel()

        // Backup 1 references photo-a. Replacing a -> b warms the reference cache.
        try await model.createBackupAndWait(reason: "First backup")
        var draft = try XCTUnwrap(model.selectedTeam?.players.first)
        draft.photoRelativePath = "photo-b.jpg"
        draft.photoSourceRelativePath = "master-b.jpg"
        model.commitPlayerEditorDraft(draft)
        await model.flushLatestState()
        XCTAssertTrue(assetExists("photo-a.jpg"), "Backup 1 still references photo-a.")

        // Backup 2 references photo-b. The cache must notice the new snapshot.
        try await model.createBackupAndWait(reason: "Second backup")
        draft = try XCTUnwrap(model.selectedTeam?.players.first)
        draft.photoRelativePath = "photo-c.jpg"
        draft.photoSourceRelativePath = "master-c.jpg"
        model.commitPlayerEditorDraft(draft)
        await model.flushLatestState()

        XCTAssertTrue(assetExists("photo-b.jpg"), "Backup 2 references photo-b; a stale cache would have deleted it.")
        XCTAssertTrue(assetExists("master-b.jpg"), "Backup 2 references master-b; a stale cache would have deleted it.")
        XCTAssertTrue(assetExists("photo-a.jpg"))
        XCTAssertTrue(assetExists("photo-c.jpg"))
    }

    /// An unreadable snapshot must keep the conservative behaviour: if we cannot
    /// prove an asset is unreferenced, it stays. Caching must not turn a failed read
    /// into a permissive answer.
    @MainActor
    func testUnreadableBackupSnapshotStillRetainsEveryAsset() async throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            photoRelativePath: "old-profile.jpg"
        )
        player.photoSourceRelativePath = "old-master.jpg"
        try writeState(RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [player])))
        for name in ["old-profile.jpg", "old-master.jpg", "new-profile.jpg", "new-master.jpg"] {
            try writeAsset(name)
        }
        let model = AppModel()
        try await model.createBackupAndWait(reason: "Corruptible backup")

        // Corrupt the snapshot on disk after it was recorded.
        let snapshot = try XCTUnwrap(model.state.snapshots.first)
        let snapshotURL = try AppPaths.snapshotsDirectory()
            .appendingPathComponent(snapshot.relativeManifestPath)
        try Data("not json".utf8).write(to: snapshotURL, options: .atomic)

        var draft = try XCTUnwrap(model.selectedTeam?.players.first)
        draft.photoRelativePath = "new-profile.jpg"
        draft.photoSourceRelativePath = "new-master.jpg"
        model.commitPlayerEditorDraft(draft)
        await model.flushLatestState()

        XCTAssertTrue(assetExists("old-profile.jpg"), "An unreadable backup must fail closed and retain assets.")
        XCTAssertTrue(assetExists("old-master.jpg"), "An unreadable backup must fail closed and retain assets.")
    }

    @MainActor
    func testReplacingPlayerPhotoKeepsPriorMasterAndProfileReferencedByBackup() async throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            photoRelativePath: "old-profile.jpg"
        )
        player.photoSourceRelativePath = "old-master.jpg"
        let team = RollCallTestFixtures.team(players: [player])
        try writeState(RollCallTestFixtures.appState(team: team))
        try writeAsset("old-profile.jpg")
        try writeAsset("old-master.jpg")
        try writeAsset("new-profile.jpg")
        try writeAsset("new-master.jpg")
        let model = AppModel()

        try await model.createBackupAndWait(reason: "Photo replacement test")
        var draft = try XCTUnwrap(model.selectedTeam?.players.first)
        draft.photoRelativePath = "new-profile.jpg"
        draft.photoSourceRelativePath = "new-master.jpg"
        model.commitPlayerEditorDraft(draft)
        await model.flushLatestState()

        XCTAssertTrue(assetExists("old-profile.jpg"))
        XCTAssertTrue(assetExists("old-master.jpg"))
        XCTAssertTrue(assetExists("new-profile.jpg"))
        XCTAssertTrue(assetExists("new-master.jpg"))
    }

    @MainActor
    func testMissingPhotoMasterRequiresPartialRestoreAndDegradesToProfileOnly() throws {
        var deletedPlayer = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            photoRelativePath: "profile.jpg"
        )
        deletedPlayer.photoSourceRelativePath = "missing-master.jpg"
        deletedPlayer.profilePhotoCrop = NormalizedPhotoCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.5)
        deletedPlayer.playerCardPhotoCrop = NormalizedPhotoCrop(x: 0.1, y: 0.05, width: 0.8, height: 0.9)
        let team = RollCallTestFixtures.team(players: [])
        let item = RecentlyDeletedItem(
            id: UUID(),
            deletedAt: .now,
            payload: .player(DeletedPlayerRecord(
                player: deletedPlayer,
                originalTeamID: team.id,
                originalTeamName: team.name,
                previousBattingOrder: [deletedPlayer.id]
            ))
        )
        var state = RollCallTestFixtures.appState(team: team)
        state.recentlyDeleted = [item]
        try writeState(state)
        try writeAsset("profile.jpg")
        let model = AppModel()

        guard case .partialPrompt = model.restorePreparation(for: item) else {
            return XCTFail("A missing working master should be disclosed before restore.")
        }
        model.restoreRecentlyDeletedItem(item, allowPartial: true)
        let restored = try XCTUnwrap(model.selectedTeam?.players.first)

        XCTAssertEqual(restored.photoRelativePath, "profile.jpg")
        XCTAssertNil(restored.photoSourceRelativePath)
        XCTAssertNil(restored.profilePhotoCrop)
        XCTAssertNil(restored.playerCardPhotoCrop)
    }

    @MainActor
    func testReplacingGeneratedBuiltInAnnouncerRemovesOldUnreferencedFile() async throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            generatedBuiltInAnnouncerRelativePath: "old-announcer.caf"
        )
        let team = RollCallTestFixtures.team(players: [player])
        try writeState(RollCallTestFixtures.appState(team: team))
        try writeAsset("old-announcer.caf")
        try writeAsset("new-announcer.caf")
        let model = AppModel()

        model.applyGeneratedBuiltInAnnouncerAsset(
            GeneratedAnnouncerAsset(
                relativePath: "new-announcer.caf",
                resolvedVoiceIdentifier: "voice-id",
                voiceLanguageCode: "en-US"
            ),
            toPlayerID: player.id,
            onTeamID: team.id
        )

        // Staged cleanup only runs once a persist lands.
        await model.flushLatestState()

        XCTAssertEqual(
            model.state.teams.first?.players.first?.generatedBuiltInAnnouncerRelativePath,
            "new-announcer.caf"
        )
        XCTAssertFalse(assetExists("old-announcer.caf"))
        XCTAssertTrue(assetExists("new-announcer.caf"))
    }

    @MainActor
    func testClearingGeneratedBuiltInAnnouncerRemovesOldFileWhenUnused() async throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            generatedBuiltInAnnouncerRelativePath: "old-announcer.caf"
        )
        let team = RollCallTestFixtures.team(players: [player])
        try writeState(RollCallTestFixtures.appState(team: team))
        try writeAsset("old-announcer.caf")
        let model = AppModel()

        model.applyGeneratedBuiltInAnnouncerAsset(nil, toPlayerID: player.id, onTeamID: team.id)

        // Staged cleanup only runs once a persist lands.
        await model.flushLatestState()

        XCTAssertNil(model.state.teams.first?.players.first?.generatedBuiltInAnnouncerRelativePath)
        XCTAssertFalse(assetExists("old-announcer.caf"))
    }

    @MainActor
    func testEditingCustomClipRetainsGeneratedAssetReferencedOnlyByBackup() throws {
        let generatedRelativePath = "GeneratedClips/backup-only-custom-clip.m4a"
        var customClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "custom-source.m4a"))
        customClip.generatedAsset = GeneratedClipAsset(
            relativePath: generatedRelativePath,
            status: .ready,
            renderedSelection: customClip.requestedSelection,
            generationKey: customClip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        customClip.readinessInputs.playback = .localClipReady
        customClip.portabilityInputs.generatedAssetCanBeExported = true
        var team = RollCallTestFixtures.team(players: [])
        team.teamClips = [customClip]
        let snapshot = SnapshotRecord(
            id: UUID(),
            createdAt: RollCallTestFixtures.now,
            reason: "Manual backup",
            relativeManifestPath: "custom-clip-backup.json"
        )
        try writeSnapshotState(
            RollCallTestFixtures.appState(team: team),
            fileName: snapshot.relativeManifestPath
        )
        try writeState(RollCallTestFixtures.appState(team: team, snapshots: [snapshot]))
        try writeGeneratedAsset("backup-only-custom-clip.m4a")
        let model = AppModel()

        var editedCue = customClip.editingCue
        editedCue.startTime += 1
        model.updateCustomClip(customClip.id, with: editedCue, named: "Edited Clip")

        XCTAssertTrue(generatedAssetExists("backup-only-custom-clip.m4a"))
    }

    @MainActor
    func testEditingPlayerSongRetainsGeneratedAssetReferencedOnlyByBackup() throws {
        let generatedRelativePath = "GeneratedClips/backup-only-player-song.m4a"
        var songClip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "player-source.m4a"))
        songClip.generatedAsset = GeneratedClipAsset(
            relativePath: generatedRelativePath,
            status: .ready,
            renderedSelection: songClip.requestedSelection,
            generationKey: songClip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        songClip.readinessInputs.playback = .localClipReady
        songClip.portabilityInputs.generatedAssetCanBeExported = true
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        player.songAssignment = .privateClip(songClip)
        let team = RollCallTestFixtures.team(players: [player])
        let snapshot = SnapshotRecord(
            id: UUID(),
            createdAt: RollCallTestFixtures.now,
            reason: "Manual backup",
            relativeManifestPath: "player-song-backup.json"
        )
        try writeSnapshotState(
            RollCallTestFixtures.appState(team: team),
            fileName: snapshot.relativeManifestPath
        )
        try writeState(RollCallTestFixtures.appState(team: team, snapshots: [snapshot]))
        try writeGeneratedAsset("backup-only-player-song.m4a")
        let model = AppModel()
        var editedPlayer = try XCTUnwrap(model.selectedTeam?.players.first)
        var editedCue = songClip.editingCue
        editedCue.startTime += 1
        editedPlayer.updatePrivateSongClip(with: editedCue)

        model.updatePlayer(editedPlayer)

        XCTAssertTrue(generatedAssetExists("backup-only-player-song.m4a"))
    }

    private func writePackageDirectory(name: String, manifest: TeamPackageManifest) throws -> URL {
        let packageURL = temp.fileURL(name)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: packageURL.appendingPathComponent("manifest.json"))
        return packageURL
    }

    private func writeState(_ state: AppState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: AppPaths.stateURL(), options: .atomic)
    }

    private func writeSnapshotState(_ state: AppState, fileName: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let snapshotURL = try AppPaths.snapshotsDirectory().appendingPathComponent(fileName)
        try encoder.encode(state).write(to: snapshotURL, options: .atomic)
    }

    private func readStateSnapshot(_ snapshot: SnapshotRecord) throws -> AppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let url = try AppPaths.snapshotsDirectory().appendingPathComponent(snapshot.relativeManifestPath)
        return try decoder.decode(AppState.self, from: Data(contentsOf: url))
    }

    private func writeAsset(_ relativePath: String) throws {
        let url = try AppPaths.assetURL(relativePath: relativePath)
        try Data("test".utf8).write(to: url, options: .atomic)
    }

    private func writeGeneratedAsset(_ fileName: String) throws {
        let url = try AppPaths.generatedClipsDirectory().appendingPathComponent(fileName)
        try Data("test".utf8).write(to: url, options: .atomic)
    }

    private func assetExists(_ relativePath: String) -> Bool {
        guard let url = try? AppPaths.assetURL(relativePath: relativePath) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func generatedAssetExists(_ fileName: String) -> Bool {
        guard let url = try? AppPaths.generatedClipsDirectory().appendingPathComponent(fileName) else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }
}
