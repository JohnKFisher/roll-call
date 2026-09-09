import XCTest
@testable import RollCall
import ZIPFoundation

final class PackageServiceTests: XCTestCase {
    private var temp: RollCallTemporaryDirectory!
    private let service = PackageService()

    override func setUpWithError() throws {
        temp = try RollCallTemporaryDirectory()
        AppPaths.testBaseDirectoryOverride = temp.fileURL("AppSupport")
    }

    override func tearDownWithError() throws {
        AppPaths.testBaseDirectoryOverride = nil
        temp = nil
    }

    func testExportedRollCallPackageCanBePreviewedAndStripsHiddenLocalAudioOrigin() throws {
        let assetURL = try AppPaths.assetURL(relativePath: "alex.m4a")
        try Data("fake-audio".utf8).write(to: assetURL)
        let alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "alex.m4a")
        )
        let team = RollCallTestFixtures.team(players: [alex], battingOrder: [alex.id])
        let state = RollCallTestFixtures.appState(team: team)

        let packageURL = try service.export(team: team, state: state)
        let manifest = try service.preview(packageURL: packageURL)

        XCTAssertEqual(packageURL.pathExtension, "rollcall")
        XCTAssertEqual(manifest.team.name, "Thunder")
        XCTAssertEqual(manifest.team.players.count, 1)
        guard case .localAudio(let source)? = manifest.team.players.first?.cue?.source else {
            return XCTFail("Expected exported player to keep a local audio cue")
        }
        XCTAssertNil(source.hiddenOriginNote)
    }

    func testNewPhotoMasterAndFramingsRoundTripWithoutRaisingPackageSchema() throws {
        try Data("profile-photo".utf8).write(to: AppPaths.assetURL(relativePath: "profile.jpg"))
        try Data("clean-master-photo".utf8).write(to: AppPaths.assetURL(relativePath: "master.jpg"))
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            photoRelativePath: "profile.jpg"
        )
        player.photoSourceRelativePath = "master.jpg"
        player.profilePhotoCrop = NormalizedPhotoCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.5)
        player.playerCardPhotoCrop = NormalizedPhotoCrop(x: 0.1, y: 0.05, width: 0.8, height: 0.9)
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])

        let packageURL = try service.export(team: team, state: RollCallTestFixtures.appState(team: team))
        let preview = try service.preview(packageURL: packageURL)
        let imported = try service.import(packageURL: packageURL, audioAssetService: AudioAssetService())
        let importedPlayer = try XCTUnwrap(imported.team.players.first)

        XCTAssertEqual(preview.schemaVersion, TeamPackageManifest.currentSchemaVersion)
        XCTAssertLessThanOrEqual(preview.schemaVersion, 9, "Roll Call 1.2 must continue accepting the additive package.")
        XCTAssertNotEqual(importedPlayer.photoRelativePath, player.photoRelativePath)
        XCTAssertNotEqual(importedPlayer.photoSourceRelativePath, player.photoSourceRelativePath)
        XCTAssertEqual(importedPlayer.profilePhotoCrop, player.profilePhotoCrop)
        XCTAssertEqual(importedPlayer.playerCardPhotoCrop, player.playerCardPhotoCrop)
        XCTAssertTrue(AudioAssetService().assetExists(relativePath: importedPlayer.photoRelativePath ?? ""))
        XCTAssertTrue(AudioAssetService().assetExists(relativePath: importedPlayer.photoSourceRelativePath ?? ""))
    }

    func testMissingPhotoMasterImportsProfileOnlyAndClearsMasterRelativeCrops() throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            photoRelativePath: "profile.jpg"
        )
        player.photoSourceRelativePath = "missing-master.jpg"
        player.profilePhotoCrop = NormalizedPhotoCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.5)
        player.playerCardPhotoCrop = NormalizedPhotoCrop(x: 0.1, y: 0.05, width: 0.8, height: 0.9)
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let packageURL = try writePackageDirectory(
            name: "MissingMaster.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: TeamPackageManifest.currentSchemaVersion,
                appVersion: "1.3.0",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: team
            )
        )
        let assetsURL = packageURL.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        try Data("profile-photo".utf8).write(to: assetsURL.appendingPathComponent("profile.jpg"))

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )
        let imported = try XCTUnwrap(result.manifest.team.players.first)

        XCTAssertNotNil(imported.photoRelativePath)
        XCTAssertNil(imported.photoSourceRelativePath)
        XCTAssertNil(imported.profilePhotoCrop)
        XCTAssertNil(imported.playerCardPhotoCrop)
        XCTAssertTrue(result.audit.items.contains { $0.state == .photoSourceMissing })
        XCTAssertEqual(result.audit.summary.needsRepairCount, 0)
    }

    func testPreviewRejectsPackageDirectoryWithoutManifest() throws {
        let packageURL = temp.fileURL("Broken.rollcall")
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testPreviewMigratesLegacyPlayerCuePackage() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue()
        )
        let manifest = TeamPackageManifest(
            schemaVersion: 7,
            appVersion: "1.1.0",
            exportedAt: RollCallTestFixtures.now,
            deviceLabel: "Legacy Device",
            team: RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var manifestObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(manifest)) as? [String: Any]
        )
        var teamObject = try XCTUnwrap(manifestObject["team"] as? [String: Any])
        var players = try XCTUnwrap(teamObject["players"] as? [[String: Any]])
        var legacyPlayer = try XCTUnwrap(players.first)
        legacyPlayer.removeValue(forKey: "songAssignment")
        legacyPlayer["cue"] = try JSONSerialization.jsonObject(
            with: encoder.encode(RollCallTestFixtures.localCue())
        )
        players[0] = legacyPlayer
        teamObject["players"] = players
        teamObject.removeValue(forKey: "teamClips")
        manifestObject["team"] = teamObject

        let packageURL = temp.fileURL("Legacy.rollcall")
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: manifestObject)
            .write(to: packageURL.appendingPathComponent("manifest.json"))

        let preview = try service.preview(packageURL: packageURL)

        XCTAssertEqual(preview.team.players.first?.cue, RollCallTestFixtures.localCue())
        XCTAssertTrue(preview.team.teamClips.isEmpty)
    }

    func testPreviewRejectsFutureSchemaPackages() throws {
        let packageURL = try writePackageDirectory(
            name: "Future.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: TeamPackageManifest.currentSchemaVersion + 1,
                appVersion: "99.0",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Future Device",
                team: RollCallTestFixtures.team()
            )
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .unsupportedImportVersion)
        }
    }

    func testPreviewRejectsDuplicatePlayerOrLineupIDs() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        var team = RollCallTestFixtures.team(players: [player, player], battingOrder: [player.id, player.id])
        team.session.battingOrderIsCustomized = true
        let packageURL = try writePackageDirectory(
            name: "DuplicateIDs.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: TeamPackageManifest.currentSchemaVersion,
                appVersion: "1.0.1",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: team
            )
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testImportPreservesMissingLocalAudioAsRepairableAssignment() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "missing.m4a")
        )
        let packageURL = try writePackageDirectory(
            name: "MissingAsset.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: TeamPackageManifest.currentSchemaVersion,
                appVersion: "1.0.1",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
            )
        )
        try FileManager.default.createDirectory(
            at: packageURL.appendingPathComponent("Assets", isDirectory: true),
            withIntermediateDirectories: true
        )

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )

        guard let clip = result.manifest.team.players.first?.songAssignment?.privateClip else {
            return XCTFail("Expected the missing local assignment to be preserved.")
        }
        XCTAssertEqual(clip.readinessInputs.playback, .needsRepair)
        XCTAssertEqual(clip.portabilityInputs.portability, .metadataOnly)
        XCTAssertEqual(result.audit.items.first?.state, .needsRepair)
    }

    func testImportRejectsUnsafePackageAssetPath() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "../escape.m4a")
        )
        let packageURL = try writePackageDirectory(
            name: "UnsafeAsset.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: TeamPackageManifest.currentSchemaVersion,
                appVersion: "1.0.1",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
            )
        )
        try FileManager.default.createDirectory(
            at: packageURL.appendingPathComponent("Assets", isDirectory: true),
            withIntermediateDirectories: true
        )

        XCTAssertThrowsError(try service.import(packageURL: packageURL, audioAssetService: AudioAssetService())) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsTraversalEntryPath() throws {
        let sourceURL = temp.fileURL("entry.txt")
        try Data("entry".utf8).write(to: sourceURL)
        let packageURL = try writeArchive(
            name: "TraversalEntry.rollcall",
            entries: [(path: "../manifest.json", sourceURL: sourceURL, compressionMethod: .none)]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsAbsoluteEntryPath() throws {
        let sourceURL = temp.fileURL("entry.txt")
        try Data("entry".utf8).write(to: sourceURL)
        let packageURL = try writeArchive(
            name: "AbsoluteEntry.rollcall",
            entries: [(path: "/manifest.json", sourceURL: sourceURL, compressionMethod: .none)]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsDuplicateEntryPaths() throws {
        let sourceURL = temp.fileURL("entry.txt")
        try Data("entry".utf8).write(to: sourceURL)
        let packageURL = try writeArchive(
            name: "DuplicateEntries.rollcall",
            entries: [
                (path: "manifest.json", sourceURL: sourceURL, compressionMethod: .none),
                (path: "manifest.json", sourceURL: sourceURL, compressionMethod: .none)
            ]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsSymlinkEntries() throws {
        let sourceURL = temp.fileURL("entry.txt")
        try Data("entry".utf8).write(to: sourceURL)
        let symlinkURL = temp.fileURL("link.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: sourceURL)
        let packageURL = try writeArchive(
            name: "SymlinkEntry.rollcall",
            entries: [
                (path: "manifest.json", sourceURL: sourceURL, compressionMethod: .none),
                (path: "Assets/link.txt", sourceURL: symlinkURL, compressionMethod: .none)
            ]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsHighCompressionRatio() throws {
        let sourceURL = temp.fileURL("high-ratio.bin")
        try Data(repeating: 0, count: 2 * 1024 * 1024).write(to: sourceURL)
        let packageURL = try writeArchive(
            name: "HighRatio.rollcall",
            entries: [(path: "payload.bin", sourceURL: sourceURL, compressionMethod: .deflate)]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsExcessiveEntryCount() throws {
        let sourceURL = temp.fileURL("entry.txt")
        try Data("entry".utf8).write(to: sourceURL)
        let entries = (0...1_024).map {
            (path: "entry-\($0).txt", sourceURL: sourceURL, compressionMethod: CompressionMethod.none)
        }
        let packageURL = try writeArchive(name: "TooManyEntries.rollcall", entries: entries)

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsOversizedEntry() throws {
        let sourceURL = temp.fileURL("oversized.bin")
        FileManager.default.createFile(atPath: sourceURL.path, contents: nil)
        let file = try FileHandle(forWritingTo: sourceURL)
        try file.truncate(atOffset: 64 * 1024 * 1024 + 1)
        try file.close()
        let packageURL = try writeArchive(
            name: "OversizedEntry.rollcall",
            entries: [(path: "payload.bin", sourceURL: sourceURL, compressionMethod: .none)]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testGeneratedCustomClipRoundTripsAsPortablePackageAsset() throws {
        let generatedPath = "GeneratedClips/team-warmup.m4a"
        try Data("portable-generated-audio".utf8)
            .write(to: AppPaths.assetURL(relativePath: generatedPath))
        var clip = SongClip(
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.team.warmup",
                title: "Team Warmup",
                artistName: "Test Artist"
            )
        )
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: generatedPath,
            status: .ready,
            renderedSelection: clip.requestedSelection,
            generationKey: clip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        clip.readinessInputs = SongClipReadinessInputs(
            playback: .localClipReady,
            sourceAvailableOnDevice: true,
            downloadedOnDevice: true
        )
        clip.portabilityInputs = SongClipPortabilityInputs(
            portability: .portableLocalClip,
            generatedAssetCanBeExported: true
        )
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        var team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        team.teamClips = [clip]

        let packageURL = try service.export(
            team: team,
            state: RollCallTestFixtures.appState(team: team)
        )
        let preview = try service.previewDetails(packageURL: packageURL)
        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )

        XCTAssertEqual(preview.summary.localClipIncludedCount, 1)
        let importedClip = try XCTUnwrap(result.manifest.team.teamClips.first)
        let importedPath = try XCTUnwrap(importedClip.generatedAsset.relativePath)
        XCTAssertTrue(importedPath.hasPrefix("GeneratedClips/"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try AppPaths.assetURL(relativePath: importedPath).path))
        XCTAssertEqual(result.audit.items.first?.state, .localClipIncluded)
        guard case .localAudio = importedClip.playbackCue.source else {
            return XCTFail("Expected the imported Custom Clip to use its included generated asset.")
        }
    }

    func testAppleMusicAssignmentSurvivesImportAndReportsAccessNeed() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.keep.me",
                title: "Keep Me",
                artistName: "Test Artist"
            )
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let packageURL = try service.export(
            team: team,
            state: RollCallTestFixtures.appState(team: team)
        )

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )

        guard case .appleMusic(let source)? = result.manifest.team.players.first?
            .songAssignment?.privateClip?.originalSource else {
            return XCTFail("Expected Apple Music metadata to survive import.")
        }
        XCTAssertEqual(source.songID, "catalog.keep.me")
        XCTAssertEqual(result.audit.items.first?.state, .needsAppleMusic)
    }

    func testAppleMusicAssignmentReportsCheckNeededBeforeMusicAuthorization() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.check.me",
                title: "Check Me",
                artistName: "Test Artist"
            )
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let packageURL = try service.export(
            team: team,
            state: RollCallTestFixtures.appState(team: team)
        )

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .notDetermined,
            appleMusicPlaybackCapability: .unknown
        )

        XCTAssertEqual(result.audit.items.first?.state, .needsAppleMusicCheck)
        XCTAssertEqual(result.audit.summary.needsAppleMusicCount, 1)
    }

    func testAppleMusicAssignmentReportsReadyWhenPlaybackCapabilityIsConfirmed() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.ready.here",
                title: "Ready Here",
                artistName: "Test Artist"
            )
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let packageURL = try service.export(
            team: team,
            state: RollCallTestFixtures.appState(team: team)
        )

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .authorized,
            appleMusicPlaybackCapability: .fullSong
        )

        XCTAssertEqual(result.audit.items.first?.state, .sourceReferenceOnly)
        XCTAssertEqual(result.audit.summary.sourceReferenceOnlyCount, 1)
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

    private func writeArchive(
        name: String,
        entries: [(path: String, sourceURL: URL, compressionMethod: CompressionMethod)]
    ) throws -> URL {
        let packageURL = temp.fileURL(name)
        let archive = try Archive(url: packageURL, accessMode: .create)
        for entry in entries {
            try archive.addEntry(
                with: entry.path,
                fileURL: entry.sourceURL,
                compressionMethod: entry.compressionMethod
            )
        }
        return packageURL
    }
}
