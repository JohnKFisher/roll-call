import XCTest
@testable import RollCall

final class ReadinessServiceTests: XCTestCase {
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
    func testLowVolumeThresholdIsStrictlyBelowThirtyPercent() {
        XCTAssertTrue(ReadinessService.isLowVolume(0.29))
        XCTAssertFalse(ReadinessService.isLowVolume(0.30))
    }

    @MainActor
    func testLowVolumeWarningRemainsLiveWithVolumeAutomationOnOrOff() {
        let check = ReadinessCheck(
            id: "volume",
            title: "Volume",
            detail: "Please check your volume - it appears low.",
            state: .issue,
            category: .volume
        )
        let playerIDs: Set<UUID> = [RollCallTestFixtures.alexID]

        for automationEnabled in [false, true] {
            let context = GameDayReadinessWarningContext(
                presentPlayerIDs: playerIDs,
                announcerMode: .announcerAndSong,
                volumeAutomationEnabled: automationEnabled
            )
            XCTAssertTrue(
                GameDayReadinessWarningPolicy.shouldSurface(check, context: context),
                "Low-volume warning should remain visible with volume automation \(automationEnabled ? "on" : "off")."
            )
        }
    }

    @MainActor
    func testSnapshotMarksMissingPlayerAudioAsNeedsAudioWithoutBlockingGameDayFallback() {
        let team = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12", cue: nil),
        ])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)

        XCTAssertEqual(
            snapshot.checks.first { $0.id == "player-\(RollCallTestFixtures.alexID)-needs-audio" }?.state,
            .needsAudio
        )
    }

    @MainActor
    func testSnapshotMarksMissingLocalAudioAssetAsIssue() {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "missing.m4a")
        )
        let team = RollCallTestFixtures.team(players: [player])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)

        XCTAssertEqual(
            snapshot.checks.first { $0.id == "player-\(RollCallTestFixtures.alexID)-audio-issue" }?.state,
            .issue
        )
    }

    @MainActor
    func testSnapshotMarksPlayerWithLocalAudioAndAnnouncementAsEnhanced() throws {
        let cueURL = try AppPaths.assetURL(relativePath: "alex.m4a")
        try Data("fake-audio".utf8).write(to: cueURL)
        let announcerURL = try AppPaths.assetURL(relativePath: "alex-announcer.caf")
        try Data("fake-announcer".utf8).write(to: announcerURL)
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "alex.m4a"),
            customAnnouncerRelativePath: "alex-announcer.caf"
        )
        let team = RollCallTestFixtures.team(players: [player])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)

        XCTAssertEqual(
            snapshot.checks.first { $0.id == "player-\(RollCallTestFixtures.alexID)-enhanced" }?.state,
            .enhanced
        )
    }

    @MainActor
    func testSnapshotSeparatesReadyPlayerAudioFromMissingAnnouncement() throws {
        let cueURL = try AppPaths.assetURL(relativePath: "alex.m4a")
        try Data("fake-audio".utf8).write(to: cueURL)
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "alex.m4a"),
            customAnnouncerRelativePath: "missing-announcer.caf"
        )
        let team = RollCallTestFixtures.team(players: [player])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)
        let playerChecks = snapshot.checks.filter { $0.playerID == player.id }
        let audioChecks = playerChecks.filter { $0.category == .playerAudio }
        let announcementChecks = playerChecks.filter { $0.category == .playerAnnouncement }

        XCTAssertEqual(audioChecks.count, 1)
        XCTAssertEqual(audioChecks.first?.state, .ready)
        XCTAssertEqual(announcementChecks.count, 1)
        XCTAssertEqual(announcementChecks.first?.state, .issue)
        XCTAssertEqual(announcementChecks.first?.id, "player-\(player.id)-custom-announcer-issue")
    }

    @MainActor
    func testSnapshotKeepsReadyPlayerAudioAndOffersAnnouncementUpgrade() throws {
        let cueURL = try AppPaths.assetURL(relativePath: "alex.m4a")
        try Data("fake-audio".utf8).write(to: cueURL)
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "alex.m4a")
        )
        let team = RollCallTestFixtures.team(players: [player])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)
        let playerChecks = snapshot.checks.filter { $0.playerID == player.id }

        XCTAssertEqual(playerChecks.filter { $0.category == .playerAudio }.count, 1)
        XCTAssertEqual(playerChecks.first { $0.category == .playerAudio }?.state, .ready)
        XCTAssertEqual(playerChecks.filter { $0.category == .playerAnnouncement }.count, 1)
        XCTAssertEqual(
            playerChecks.first { $0.category == .playerAnnouncement }?.state,
            .optional
        )
    }

    @MainActor
    func testMissingAnnouncementWarningOnlySurfacesWhenAnnouncerIsUsed() throws {
        let cueURL = try AppPaths.assetURL(relativePath: "alex.m4a")
        try Data("fake-audio".utf8).write(to: cueURL)
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "alex.m4a"),
            customAnnouncerRelativePath: "missing-announcer.caf"
        )
        let team = RollCallTestFixtures.team(players: [player])
        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)
        guard let announcementCheck = snapshot.checks.first(where: {
            $0.category == .playerAnnouncement && $0.playerID == player.id
        }) else {
            return XCTFail("Expected a missing Announcement Cue check.")
        }

        let playerIDs: Set<UUID> = [player.id]
        for mode in [GameDayAnnouncerMode.announcerOnly, .announcerAndSong] {
            let context = GameDayReadinessWarningContext(
                presentPlayerIDs: playerIDs,
                announcerMode: mode,
                volumeAutomationEnabled: false
            )
            XCTAssertTrue(GameDayReadinessWarningPolicy.shouldSurface(announcementCheck, context: context))
        }

        let songOnlyContext = GameDayReadinessWarningContext(
            presentPlayerIDs: playerIDs,
            announcerMode: .songOnly,
            volumeAutomationEnabled: false
        )
        XCTAssertFalse(GameDayReadinessWarningPolicy.shouldSurface(announcementCheck, context: songOnlyContext))
    }

    @MainActor
    func testPlayerAudioFilteringExcludesAnnouncementChecks() {
        let playerID = RollCallTestFixtures.alexID
        let checks = [
            ReadinessCheck(
                id: "player-\(playerID)-ready",
                title: "Alex Ramirez",
                detail: "Song ready",
                state: .ready,
                category: .playerAudio,
                playerID: playerID
            ),
            ReadinessCheck(
                id: "player-\(playerID)-custom-announcer-issue",
                title: "Alex Ramirez",
                detail: "Announcement missing",
                state: .issue,
                category: .playerAnnouncement,
                playerID: playerID
            )
        ]

        let audioChecks = ReadinessCheckFiltering.playerAudioChecks(from: checks)

        XCTAssertEqual(audioChecks.map(\.id), ["player-\(playerID)-ready"])
    }

    @MainActor
    func testSnapshotMarksEmptyLineupAsIssue() {
        let team = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12", isPresent: false),
        ])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)

        XCTAssertEqual(snapshot.checks.first { $0.id == "lineup" }?.state, .issue)
    }

    @MainActor
    func testSnapshotExplainsPreservedAppleMusicAssignmentThatNeedsAccess() {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.needs.access",
                title: "Needs Access",
                artistName: "Test Artist"
            )
        )
        guard case .privateClip(var clip)? = player.songAssignment else {
            return XCTFail("Expected private song clip.")
        }
        clip.readinessInputs.playback = .needsAppleMusic
        clip.readinessInputs.sourceAvailableOnDevice = false
        player.songAssignment = .privateClip(clip)
        let team = RollCallTestFixtures.team(players: [player])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)
        let check = snapshot.checks.first { $0.id == "player-\(player.id)-audio-issue" }

        XCTAssertEqual(check?.state, .issue)
        XCTAssertTrue(check?.detail.contains("song choice is preserved") == true)
    }

    @MainActor
    func testSnapshotTreatsIncludedGeneratedPlayerClipAsPortableReady() throws {
        let generatedPath = "GeneratedClips/shared-ready.m4a"
        try Data("generated".utf8).write(to: AppPaths.assetURL(relativePath: generatedPath))
        var clip = SongClip(
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.shared.ready",
                title: "Shared Ready",
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
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        player.songAssignment = .privateClip(clip)
        let team = RollCallTestFixtures.team(players: [player])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)
        let check = snapshot.checks.first { $0.id == "player-\(player.id)-ready" }

        XCTAssertEqual(check?.state, .ready)
        XCTAssertTrue(check?.detail.contains("portable Roll Call clip") == true)
    }
}
