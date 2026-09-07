import AVFoundation
@preconcurrency import AVFAudio
import Combine
import Foundation
import MusicKit
import UIKit
import UniformTypeIdentifiers

struct PendingRosterImport: Identifiable {
    let id = UUID()
    let sourceName: String
    let rows: [Player]
    let targetTeamID: UUID

    func duplicateCount(comparedTo existingPlayers: [Player]) -> Int {
        let existingKeys = Set(existingPlayers.map(Self.duplicateKey).filter { !$0.isEmpty })
        var importedKeys = Set<String>()
        var duplicateCount = 0

        for player in rows {
            let key = Self.duplicateKey(for: player)
            guard !key.isEmpty else { continue }
            if existingKeys.contains(key) || !importedKeys.insert(key).inserted {
                duplicateCount += 1
            }
        }

        return duplicateCount
    }

    static func duplicateMessage(count: Int) -> String {
        let noun = count == 1 ? "player" : "players"
        return "\(count) possible duplicate \(noun) found by matching name and number."
    }

    private static func duplicateKey(for player: Player) -> String {
        let name = player.displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let number = player.uniformNumber.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty else { return "" }
        return "\(name)#\(number)"
    }
}

@MainActor
private final class RiskyOperationCoordinator {
    struct Admission {
        let id: UUID
        let name: String
    }

    private(set) var active: Admission?

    var count: Int {
        active == nil ? 0 : 1
    }

    func begin(name: String) -> Admission? {
        guard active == nil else { return nil }
        let admission = Admission(id: UUID(), name: name)
        active = admission
        return admission
    }

    func end(id: UUID) {
        guard active?.id == id else { return }
        active = nil
    }
}

struct SupportBundleExport: Identifiable {
    let id = UUID()
    let url: URL
}

struct AppBannerMessage: Identifiable, Equatable {
    enum Style: Equatable {
        case success
        case warning
    }

    let id = UUID()
    let text: String
    let style: Style
}

struct PartialRestorePrompt: Identifiable, Equatable {
    enum ItemType: Equatable {
        case team
        case player
        case customClip
    }

    let id = UUID()
    let itemID: UUID
    let itemType: ItemType
    let title: String
    let message: String
}

enum RestorePreparation: Equatable {
    case ready
    case blocked(String)
    case partialPrompt(PartialRestorePrompt)
}

enum RecoveryNavigationDestination: Equatable {
    case players
    case customClip(UUID)
}

struct AnnouncerVoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let languageCode: String
    let qualityRank: Int
}

struct AnnouncerRegenerationStatus: Equatable {
    var teamID: UUID
    var phase: String
    var completed: Int
    var total: Int

    var progressText: String {
        total == 0 ? phase : "\(phase) (\(completed)/\(total))"
    }
}

enum CustomAnnouncerRecordingPhase: Equatable {
    case idle
    case starting(UUID)
    case recording(UUID)
    case stopping(UUID)
}

struct TeamAppleMusicPlaylistSongRow: Equatable, Identifiable {
    var id: String { songID }
    var playerID: UUID
    var playerName: String
    var songID: String
    var title: String
    var artistName: String
}

enum TeamAppleMusicPlaylistSkipReason: String, Equatable {
    case missingCue
    case localAudio
    case builtInClip
    case previewOnlyAppleMusic

    var explanation: String {
        switch self {
        case .missingCue:
            return "No song cue selected"
        case .localAudio:
            return "Local audio cannot be added to Apple Music"
        case .builtInClip:
            return "Built-in clips cannot be added to Apple Music"
        case .previewOnlyAppleMusic:
            return "Preview-only Apple Music selections cannot be added"
        }
    }
}

struct TeamAppleMusicPlaylistSkippedCue: Equatable, Identifiable {
    var id: UUID { playerID }
    var playerID: UUID
    var playerName: String
    var title: String?
    var artistName: String?
    var reason: TeamAppleMusicPlaylistSkipReason
}

struct TeamAppleMusicPlaylistSummary: Equatable, Identifiable {
    var id: UUID { teamID }
    var teamID: UUID
    var teamName: String
    var playlistName: String
    var includedSongs: [TeamAppleMusicPlaylistSongRow]
    var skippedCues: [TeamAppleMusicPlaylistSkippedCue]
    var duplicateSongs: [TeamAppleMusicPlaylistSongRow]

    var songIDs: [String] {
        includedSongs.map(\.songID)
    }

    var canUpdatePlaylist: Bool {
        !includedSongs.isEmpty
    }

    init(team: Team) {
        teamID = team.id
        teamName = team.name
        playlistName = "Roll Call - \(team.name)"

        var seenSongIDs = Set<String>()
        var included: [TeamAppleMusicPlaylistSongRow] = []
        var skipped: [TeamAppleMusicPlaylistSkippedCue] = []
        var duplicates: [TeamAppleMusicPlaylistSongRow] = []

        for player in team.players {
            guard let cue = team.cue(for: player) else {
                skipped.append(TeamAppleMusicPlaylistSkippedCue(
                    playerID: player.id,
                    playerName: player.displayName,
                    title: nil,
                    artistName: nil,
                    reason: .missingCue
                ))
                continue
            }

            switch cue.source {
            case .appleMusic(let source):
                let row = TeamAppleMusicPlaylistSongRow(
                    playerID: player.id,
                    playerName: player.displayName,
                    songID: source.songID,
                    title: source.title,
                    artistName: source.artistName
                )
                if source.isCatalogBacked == false {
                    skipped.append(TeamAppleMusicPlaylistSkippedCue(
                        playerID: player.id,
                        playerName: player.displayName,
                        title: source.title,
                        artistName: source.artistName,
                        reason: .previewOnlyAppleMusic
                    ))
                } else if seenSongIDs.insert(source.songID).inserted {
                    included.append(row)
                } else {
                    duplicates.append(row)
                }
            case .localAudio(let source):
                skipped.append(TeamAppleMusicPlaylistSkippedCue(
                    playerID: player.id,
                    playerName: player.displayName,
                    title: source.displayName,
                    artistName: nil,
                    reason: .localAudio
                ))
            case .builtInClip(let source):
                skipped.append(TeamAppleMusicPlaylistSkippedCue(
                    playerID: player.id,
                    playerName: player.displayName,
                    title: source.displayName,
                    artistName: nil,
                    reason: .builtInClip
                ))
            }
        }

        includedSongs = included
        skippedCues = skipped
        duplicateSongs = duplicates
    }
}

struct AppleMusicPlaylistRecovery: Equatable, Identifiable {
    var id = UUID()
    var summary: TeamAppleMusicPlaylistSummary
    var unresolvedSongs: [TeamAppleMusicPlaylistSongRow]
    var availableSongIDs: [String]
}

enum TeamClipSaveResult: Equatable {
    case saved(UUID)
    case exactDuplicate(UUID)
}

struct TeamClipPromotionResult: Equatable {
    var addedCount: Int
    var reusedCount: Int
    var assignedPlayerCount: Int
}

enum GameDayLineupProgressHintSource: Equatable {
    case nextButton
    case onDeckCard
}

struct GameDayLineupProgressHintEvent: Equatable {
    let id = UUID()
    let teamID: UUID
    let source: GameDayLineupProgressHintSource
}

fileprivate struct RenderedAnnouncerAudio {
    var data: Data
    var resolvedVoiceIdentifier: String?
    var voiceLanguageCode: String?
}

private func customAnnouncerTemporaryURL(fileExtension: String) -> URL {
    let ext = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "caf" : fileExtension
    return FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
}

private func customIntroFileSummary(for url: URL?) -> String {
    guard let url else { return "no file url" }
    let exists = FileManager.default.fileExists(atPath: url.path)
    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    let ext = url.pathExtension.isEmpty ? "none" : url.pathExtension
    return "ext=\(ext), exists=\(exists), bytes=\(size)"
}

private func customIntroErrorSummary(_ error: Error?) -> String {
    guard let error else { return "no underlying error" }
    let nsError = error as NSError
    return "\(nsError.domain) code \(nsError.code): \(nsError.localizedDescription)"
}

private final class AnnouncerRenderCompletionState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func claimCompletion() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        finished = true
        return true
    }

    func hasFinished() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return finished
    }
}

private final class CustomAnnouncerStopState: @unchecked Sendable {
    private let lock = NSLock()
    private var pendingStopURL: URL?
    private var stopContinuation: CheckedContinuation<URL, Error>?

    func beginStop(url: URL, continuation: CheckedContinuation<URL, Error>) {
        lock.lock()
        pendingStopURL = url
        stopContinuation = continuation
        lock.unlock()
    }

    func takePendingStop() -> (URL?, CheckedContinuation<URL, Error>?) {
        lock.lock()
        defer { lock.unlock() }
        let result = (pendingStopURL, stopContinuation)
        pendingStopURL = nil
        stopContinuation = nil
        return result
    }

    func hasPendingStop() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingStopURL != nil || stopContinuation != nil
    }
}

final class CustomAnnouncerRecorder: NSObject, AVAudioRecorderDelegate, @unchecked Sendable {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private(set) var recordingPlayerID: UUID?
    private let stopState = CustomAnnouncerStopState()

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func requestPermissionIfNeeded() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission(completionHandler: { granted in
                    continuation.resume(returning: granted)
                })
            }
        @unknown default:
            return false
        }
    }

    func startRecording(for playerID: UUID, destinationURL: URL) async throws {
        guard await requestPermissionIfNeeded() else { throw AppError.microphonePermissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        let recorder = try AVAudioRecorder(url: destinationURL, settings: settings)
        recorder.delegate = self
        recorder.prepareToRecord()
        guard recorder.record() else { throw AppError.recordingUnavailable }

        self.recorder = recorder
        self.recordingURL = destinationURL
        self.recordingPlayerID = playerID
    }

    func stopRecording() async throws -> URL {
        guard let recorder, let recordingURL else { throw AppError.recordingUnavailable }
        return try await withCheckedThrowingContinuation { continuation in
            stopState.beginStop(url: recordingURL, continuation: continuation)
            recorder.stop()
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let (finishedURL, continuation) = stopState.takePendingStop()
        guard let continuation else { return }
        clearRecordingState()

        guard let finishedURL else {
            continuation.resume(throwing: AppError.customIntroSaveFailed("recorder finished with no destination url"))
            return
        }

        let fileSize = (try? finishedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard fileSize > 0 else {
            continuation.resume(throwing: AppError.customIntroSaveFailed("finish flag=\(flag), \(customIntroFileSummary(for: finishedURL))"))
            return
        }

        continuation.resume(returning: finishedURL)
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let (_, continuation) = stopState.takePendingStop()
        guard let continuation else { return }
        clearRecordingState()
        continuation.resume(throwing: AppError.customIntroSaveFailed("encode callback: \(customIntroErrorSummary(error))"))
    }

    private func finishPendingStopAsCancelled() {
        let (_, continuation) = stopState.takePendingStop()
        guard let continuation else { return }
        continuation.resume(throwing: AppError.recordingUnavailable)
    }

    private func clearRecordingState() {
        self.recorder = nil
        self.recordingURL = nil
        self.recordingPlayerID = nil
    }

    func cancelRecording() {
        guard !stopState.hasPendingStop() else { return }
        let recordingURL = self.recordingURL
        recorder?.stop()
        clearRecordingState()
        finishPendingStopAsCancelled()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingPlayerID = nil
    }
}

@MainActor
final class GameDayHaptics {
    func success(isEnabled: Bool) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func warning(isEnabled: Bool) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

@MainActor
struct PlayerSongsToCustomClipsResult: Equatable {
    var copiedCount: Int
    var skippedCount: Int
}

@MainActor
final class AppModel: ObservableObject {
    // Central default so a future settings UI can replace this with user selection.
    private let defaultNoSongFallbackBuiltInClipSourceID = "small-cheer"

    let telemetry: RollCallTelemetryCoordinator

    @Published var state: AppState
    @Published private(set) var isBusy = false
    @Published var lastError: String?
    @Published var bannerMessage: AppBannerMessage?
    @Published var exportURL: URL?
    @Published var pendingPackageExport: PendingPackageExport?
    @Published var pendingRosterImport: PendingRosterImport?
    @Published var pendingPackageImport: PendingPackageImport?
    @Published var completedPackageImportTeamID: UUID?
    @Published var completedPackageImportAudit: PackageImportAudit?
    @Published var supportBundle: SupportBundleExport?
    @Published private(set) var musicRenderProbeSamples = MusicRenderProbeScenario.allCases.map { MusicRenderProbeSample(scenario: $0) }
    @Published private(set) var musicRenderProbeLibraryCandidates: [MusicRenderProbeLibraryCandidate] = []
    @Published private(set) var musicRenderProbeCatalogCandidates: [MusicRenderProbeCatalogCandidate] = []
    @Published private(set) var isMusicRenderProbeLoadingLibrary = false
    @Published private(set) var isMusicRenderProbeSearchingCatalog = false
    @Published var musicRenderProbeSummaryURL: URL?
    @Published var announcerRegenerationStatus: AnnouncerRegenerationStatus?
    @Published private(set) var isAppleMusicPlaylistSyncing = false
    @Published private(set) var appleMusicPlaylistSyncStatus: String?
    @Published private(set) var appleMusicPlaylistRecovery: AppleMusicPlaylistRecovery?
    @Published private(set) var appleMusicPlaybackCapability: AppleMusicPlaybackCapability = .unknown
    @Published private(set) var customAnnouncerRecordingPhase: CustomAnnouncerRecordingPhase = .idle
    @Published var pendingRecoveryNavigation: RecoveryNavigationDestination?
    @Published private(set) var gameDayLineupProgressHintEvent: GameDayLineupProgressHintEvent?
    @Published private(set) var pendingSongClipPreparationCount = 0
    @Published private(set) var generatedClipCleanupReport: GeneratedClipCleanupReport?
    @Published private(set) var activeFallbackPlayerID: UUID?
    @Published private(set) var riskyOperationCount = 0
    private var hasFinishedLaunching = false
    private let riskyOperationCoordinator = RiskyOperationCoordinator()
    private let persistenceWriter = StatePersistenceWriter()
    private var persistSequence = 0
    private var latestRequestedPersistenceSequence = 0
    private var latestDurablePersistenceSequence = 0
    private var statePersistenceFailureEpisodeActive = false
    private var readinessRefreshTask: Task<Void, Never>?
    private var audioRouteChangeTask: Task<Void, Never>?
    private var outputVolumeObservation: NSKeyValueObservation?
    private var prewarmTask: Task<Void, Never>?
    private var startupWarmupTask: Task<Void, Never>?
    private var announcerRegenerationTask: Task<Void, Never>?
    private var pendingIncomingPackageURLs: [URL] = []
    private var isPreparingIncomingPackagePreview = false
    private var initialStateLoadWarning: String?
    private var bannerDismissTask: Task<Void, Never>?
    private var songClipPreparationLiveUseThrottled = false
    private var lowPowerModeTask: Task<Void, Never>?
    private var activePlaybackRequestID = UUID()
    private var activePlaybackTelemetryContext: (engineRequestID: UUID, teamID: UUID, playerID: UUID, sourceFamily: PlaybackSourceFamily)?
    private var pendingAssetCleanupPaths = Set<String>()
    private let appleMusicPlaybackCapabilityResolver: () async -> AppleMusicPlaybackCapability
    private let catalogBackedResultResolver: (MusicSearchResult) async throws -> MusicSearchResult
    private let previewPlaybackResolver: ((Cue) async throws -> Void)?

    let audioAssetService = AudioAssetService()
    let musicCatalogService = MusicCatalogService()
    let musicRenderProbeService: MusicRenderProbeService
    let packageService = PackageService()
    let announcerRenderer = AnnouncerSpeechRenderer()
    let haptics = GameDayHaptics()
    let readinessService: ReadinessService
    let playbackEngine: CuePlaybackEngine
    let customAnnouncerRecorder = CustomAnnouncerRecorder()
    let songClipGenerationService = SongClipGenerationService()
    private let songClipPreparationCoordinator: SongClipPreparationCoordinator

    private struct PersistenceRequest {
        let snapshot: AppState
        let cleanupPaths: Set<String>
        let sequence: Int
        let destinationURL: URL
    }

    var featureFlags: FeatureFlags {
        FeatureFlags(environment: .current, experimental: state.experimental)
    }

    var hasUnseenWhatsNew: Bool {
        !AppMetadata.hasSeenWhatsNewRelease(state.lastSeenWhatsNewReleaseID)
    }

    var hasEarnedRatingRequest: Bool {
        telemetry.ratingSnapshot.probableGameDateCount >= 2
    }

    var canPresentAutomaticRatingRequest: Bool { telemetry.canPresentAutomaticRatingRequest }

    var ratingRequestDebugSummary: String {
        let snapshot = telemetry.ratingSnapshot
        return "\(snapshot.probableGameDateCount) probable-game dates, attempt \(snapshot.automaticAttemptsConsumed)/2"
    }

    init(
        appleMusicPlaybackCapabilityResolver: @escaping () async -> AppleMusicPlaybackCapability = {
            await MusicCatalogService().playbackCapability()
        },
        catalogBackedResultResolver: @escaping (MusicSearchResult) async throws -> MusicSearchResult = { result in
            try await MusicCatalogService().catalogBackedResult(for: result)
        },
        previewPlaybackResolver: ((Cue) async throws -> Void)? = nil,
        telemetry: RollCallTelemetryCoordinator? = nil
    ) {
        self.appleMusicPlaybackCapabilityResolver = appleMusicPlaybackCapabilityResolver
        self.catalogBackedResultResolver = catalogBackedResultResolver
        self.previewPlaybackResolver = previewPlaybackResolver
        self.songClipPreparationCoordinator = SongClipPreparationCoordinator(
            generationService: songClipGenerationService,
            audioAssetService: audioAssetService
        )
        FeatureFlags.assertReleaseSafety()
        self.musicRenderProbeService = MusicRenderProbeService(audioAssetService: audioAssetService, musicCatalogService: musicCatalogService)
        self.playbackEngine = CuePlaybackEngine(audioAssetService: audioAssetService, musicCatalogService: musicCatalogService)
        self.readinessService = ReadinessService(audioAssetService: audioAssetService)
        let loadResult = Self.loadInitialState()
        self.state = loadResult.state
        if let telemetry {
            self.telemetry = telemetry
        } else {
            self.telemetry = Self.makeDefaultTelemetryCoordinator(
                legacyAutomaticAttemptCount: loadResult.state.ratingRequest.automaticPromptAttemptCount
            )
        }
        self.playbackEngine.onAsynchronousPlaybackResult = { [weak self] result in
            guard let self,
                  let context = self.activePlaybackTelemetryContext,
                  result.requestID == context.engineRequestID,
                  context.sourceFamily != .unknown else { return }
            switch result.outcome {
            case .started:
                self.telemetry.handlePlaybackContinuation(
                    teamID: context.teamID,
                    confirmation: result,
                    playbackMode: self.playbackMode(for: context.teamID)
                )
            case .failed(let reason):
                self.telemetry.recordRecovery(
                    teamID: context.teamID,
                    failedComponent: result.component,
                    sourceFamily: result.sourceFamily,
                    recoveryOutcome: result.component == .announcement ? "songOnly" : "introOnly",
                    reason: reason
                )
            case .cancelled:
                break
            }
        }
        self.initialStateLoadWarning = loadResult.warning
        self.state.appVersion = AppMetadata.appVersion
        self.state.schemaVersion = max(self.state.schemaVersion, AppState.empty.schemaVersion)
        normalizeRatingRequestPolicyState()
        self.readinessService.onPathStatusChange = { [weak self] in
            self?.scheduleReadinessRefresh()
        }
        observeReadinessInputs()
        observeLowPowerMode()
        FeatureFlags.assertReleaseSafety(featureFlags)
        normalizeSelectedTeamIfNeeded()
        normalizeAllTeams()
        self.telemetry.validateLiveCheckpoint(
            availableTeamIDs: Set(self.state.teams.map(\.id)),
            selectedTeamID: self.state.selectedTeamID
        )
        purgeExpiredRecentlyDeletedItems()
        reconcileOnboardingForExistingTeamIfNeeded()
        self.telemetry.enroll(currentState: self.state)
        if let recoveryReason = loadResult.recoveryReason {
            self.telemetry.record(.stateRecoveryTriggered, properties: [.reason: recoveryReason])
        }
        if let initialStateLoadWarning {
            lastError = initialStateLoadWarning
        }
        persist()
    }

    private static func makeDefaultTelemetryCoordinator(legacyAutomaticAttemptCount: Int) -> RollCallTelemetryCoordinator {
        let url = (try? AppPaths.telemetryStateURL())
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("rollcall-telemetry-state.json")
        let store = TelemetryStore(
            url: url,
            legacyAutomaticAttemptCount: legacyAutomaticAttemptCount
        )
        let context = TelemetryBuildContext.current
        #if canImport(TelemetryDeck)
        let provider: RollCallTelemetryProvider
        if context.isSwiftUIPreview {
            provider = NullTelemetryProvider()
        } else {
            provider = TelemetryDeckProvider(
                appID: Bundle.main.object(forInfoDictionaryKey: "TelemetryDeckAppID") as? String
            )
        }
        #else
        let provider: RollCallTelemetryProvider = NullTelemetryProvider()
        #endif
        return RollCallTelemetryCoordinator(provider: provider, store: store, buildContext: context)
    }

    func finishLaunchingIfNeeded() async {
        guard !hasFinishedLaunching else { return }
        hasFinishedLaunching = true
        telemetry.observeRetentionActivation(at: .now, wasAlreadyActive: false)

        let audioAssetService = self.audioAssetService
        let assetError = await Task.detached(priority: .utility) { () -> String? in
            do {
                try audioAssetService.ensureBuiltInAssets()
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value

        if let assetError {
            lastError = assetError
            return
        }

        do {
            try configurePlaybackAudioSession()
            await refreshAppleMusicPlaybackCapability()
            refreshReadiness()
            scheduleStartupGameDayWarmup()
            await runAutomaticGeneratedClipCleanup()
            scheduleAllSongClipPreparation(trigger: .appLaunch)
            persist()
            await preparePendingIncomingPackageIfNeeded()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func handleTelemetryActivation(wasAlreadyActive: Bool) {
        telemetry.observeRetentionActivation(at: .now, wasAlreadyActive: wasAlreadyActive)
        telemetry.observeRatingEligibility(at: .now)
    }

    func handleIncomingPackage(_ url: URL) {
        guard isSupportedIncomingPackageURL(url) else {
            lastError = "Roll Call can only open .rollcall packages from Share or AirDrop."
            return
        }
        pendingIncomingPackageURLs.append(url)
        Task { await self.preparePendingIncomingPackageIfNeeded() }
    }

    var selectedTeam: Team? {
        state.teams.first(where: { $0.id == state.selectedTeamID })
    }

    var selectedTeamReadiness: ReadinessStatus? {
        guard let readiness = state.lastReadiness,
              readiness.teamID == selectedTeam?.id else {
            return nil
        }
        return readiness
    }

    var shouldShowOnboarding: Bool {
        state.teams.isEmpty || state.onboarding.activeFlow != nil || !state.onboarding.isComplete
    }

    private func reconcileOnboardingForExistingTeamIfNeeded() {
        guard !state.onboarding.isComplete,
              state.onboarding.activeFlow == .automatic,
              state.teams.contains(where: { !$0.players.isEmpty }) else {
            return
        }

        state.onboarding = .completed()
    }

    var onboardingTeam: Team? {
        if let activeTeamID = state.onboarding.activeTeamID {
            return state.teams.first(where: { $0.id == activeTeamID }) ?? selectedTeam
        }
        if state.onboarding.activeFlow == .manualCreate {
            return nil
        }
        return selectedTeam
    }

    func beginSetupGuide() {
        state.onboarding = .manualChooser(completedAt: state.onboarding.completedAt)
        persist()
    }

    func dismissManualSetupGuide() {
        if state.teams.isEmpty {
            state.onboarding = .notStarted
        } else {
            state.onboarding = .completed(at: state.onboarding.completedAt ?? .now)
        }
        persist()
    }

    func startOnboardingCreateNewTeam() {
        state.onboarding.activeFlow = state.teams.isEmpty ? .automatic : .manualCreate
        state.onboarding.activeTeamID = nil
        state.onboarding.didChooseCheerFallback = false
        state.onboarding.didSeeLineup = false
        state.onboarding.importHandoffTeamID = nil
        persist()
        telemetry.recordOnce(.onboardingStarted)
    }

    func startOnboardingReviewCurrentTeam() {
        state.onboarding.activeFlow = .manualReview
        state.onboarding.activeTeamID = state.selectedTeamID
        state.onboarding.didChooseCheerFallback = selectedTeam?.players.contains { $0.cue != nil } ?? false
        state.onboarding.didSeeLineup = false
        state.onboarding.importHandoffTeamID = nil
        persist()
        telemetry.recordOnce(.onboardingStarted)
    }

    func completeOnboarding() {
        state.onboarding = .completed()
        persist()
        telemetry.recordOnce(.onboardingCompleted)
    }

    func markOnboardingCheerFallbackChosen() {
        state.onboarding.didChooseCheerFallback = true
        persist()
        telemetry.recordOnce(.onboardingCheerFallbackChosen)
    }

    func markOnboardingLineupSeen() {
        state.onboarding.didSeeLineup = true
        persist()
    }

    func selectTeam(_ team: Team) {
        setSelectedTeamID(team.id)
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
    }

    @discardableResult
    func resolveOpenGameDay(_ request: OpenGameDayRequest) -> OpenGameDayResolution {
        telemetry.record(.quickGameDayInvoked, properties: [.source: request.source.telemetryValue])
        let resolution = OpenGameDayResolver.resolve(request, in: state)
        switch resolution {
        case .gameDay(let teamID, let targetKind):
            if state.teams.contains(where: { $0.id == teamID }) {
                setSelectedTeamID(teamID)
                state.lastGameDayTeamID = teamID
                prewarmNextBatterCue()
                scheduleReadinessRefresh()
                persist()
                telemetry.record(.quickGameDayTargetResolved, properties: [.target: targetKind.rawValue])
            }
        case .fallback(let reason):
            if reason == .rememberedTeamMissing {
                state.lastGameDayTeamID = nil
                persist()
            }
            telemetry.record(.quickGameDayFallback, properties: [.reason: reason.rawValue])
        }
        return resolution
    }

    func recordQuickGameDayReached() {
        telemetry.record(.quickGameDayReached)
    }

    func recordIntentionalGameDayEntry() {
        guard let teamID = state.selectedTeamID,
              state.teams.contains(where: { $0.id == teamID }),
              state.lastGameDayTeamID != teamID else { return }
        state.lastGameDayTeamID = teamID
        persist()
    }

    @discardableResult
    func addTeam(named name: String, accentPreset: TeamAccentPreset = .rollCallOrange, forOnboarding: Bool = false) -> Team? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let team = Team(
            id: UUID(),
            name: trimmed,
            createdAt: .now,
            modifiedAt: .now,
            players: [],
            builtInClips: BuiltInClip.defaults,
            session: TeamSessionState(activeSessionDate: nil, battingOrder: [], nextBatterIndex: 0, gameDayAnnouncerMode: .announcerAndSong, battingOrderIsCustomized: false),
            announcerProfile: .default,
            accentPreset: accentPreset
        )
        state.teams.append(team)
        setSelectedTeamID(team.id)
        if forOnboarding {
            state.onboarding.activeFlow = state.teams.count == 1 ? .automatic : .manualCreate
            state.onboarding.activeTeamID = team.id
            state.onboarding.didChooseCheerFallback = false
            state.onboarding.didSeeLineup = false
            state.onboarding.importHandoffTeamID = nil
        }
        persist()
        telemetry.recordRosterMilestones(for: state)
        return team
    }

    func duplicateTeam() {
        guard var team = selectedTeam else { return }
        let originalPlayers = team.players
        let originalBattingOrder = team.session.battingOrder
        let originalNextBatter = team.nextBatter?.id
        team.id = UUID()
        team.name += " Copy"
        var playerIDMap: [UUID: UUID] = [:]
        team.players = originalPlayers.map { player in
            var player = player
            let oldID = player.id
            player.id = UUID()
            playerIDMap[oldID] = player.id
            player.songAssignment = duplicatedSongAssignment(from: player.songAssignment)
            return player
        }
        let duplicatedOrder = originalBattingOrder.compactMap { playerIDMap[$0] }
        let nextBatterID = originalNextBatter.flatMap { playerIDMap[$0] }
        let duplicatedPresentPlayers = team.orderedPlayers(by: duplicatedOrder).filter(\.isPresent)
        let duplicatedNextBatterIndex = nextBatterID.flatMap { nextID in
            duplicatedPresentPlayers.firstIndex(where: { $0.id == nextID })
        } ?? 0
        team.session = TeamSessionState(
            activeSessionDate: nil,
            battingOrder: duplicatedOrder,
            nextBatterIndex: duplicatedNextBatterIndex,
            gameDayAnnouncerMode: team.session.gameDayAnnouncerMode,
            battingOrderIsCustomized: team.session.battingOrderIsCustomized
        )
        state.teams.append(team)
        setSelectedTeamID(team.id)
        normalizeLineup(for: state.teams.count - 1)
        persist()
        telemetry.recordOnce(.teamDuplicated)
        telemetry.recordRosterMilestones(for: state)
    }

    private func duplicatedSongAssignment(from assignment: SongAssignment?) -> SongAssignment? {
        guard let assignment else {
            return nil
        }
        guard case .privateClip(var clip) = assignment else { return assignment }
        let sourceClipID = clip.id
        clip.id = UUID()
        clip.sourceLineageClipID = clip.sourceLineageClipID ?? sourceClipID
        return .privateClip(clip)
    }

    func renameSelectedTeam(to name: String) {
        guard let teamIndex else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.teams[teamIndex].name = trimmed
        state.teams[teamIndex].modifiedAt = .now
        persist()
    }

    func setAccentPreset(_ accentPreset: TeamAccentPreset, for teamID: UUID) {
        guard let index = state.teams.firstIndex(where: { $0.id == teamID }) else { return }
        let changed = state.teams[index].accentPreset != accentPreset
        state.teams[index].accentPreset = accentPreset
        state.teams[index].modifiedAt = .now
        persist()
        if changed, accentPreset != .rollCallOrange {
            telemetry.recordOnce(.teamAccentFirstChanged, properties: [.newAccent: accentPreset == .rollCallOrange ? "orange" : accentPreset.rawValue], teamID: teamID)
        }
    }

    func removeSelectedTeam() {
        guard let teamIndex, let team = selectedTeam else { return }
        addRecentlyDeletedItem(
            RecentlyDeletedItem(
                id: UUID(),
                deletedAt: .now,
                payload: .team(DeletedTeamRecord(team: team))
            )
        )
        state.teams.remove(at: teamIndex)
        if state.lastGameDayTeamID == team.id {
            state.lastGameDayTeamID = nil
        }
        Task { await cancelSongClipPreparation(teamID: team.id) }
        normalizeSelectedTeamIfNeeded()
        stopPlayback()
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
    }

    @discardableResult
    func addPlayer(name: String, number: String) -> Player? {
        guard let teamIndex = teamIndex else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let player = Player(id: UUID(), displayName: trimmedName, uniformNumber: number.trimmingCharacters(in: .whitespacesAndNewlines), pronunciationOverride: "", photoRelativePath: nil, cue: nil, isPresent: true)
        state.teams[teamIndex].players.append(player)
        state.teams[teamIndex].session.battingOrder.append(player.id)
        state.teams[teamIndex].modifiedAt = .now
        normalizeLineup(for: teamIndex)
        persist()
        telemetry.recordRosterMilestones(for: state)
        return player
    }

    func updatePlayer(_ player: Player) {
        guard let teamIndex, let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == player.id }) else { return }
        let previousPlayer = state.teams[teamIndex].players[playerIndex]
        let teamID = state.teams[teamIndex].id
        let previousRepairCategories = repairCategories(for: previousPlayer, in: state.teams[teamIndex])
        let repairAttemptedCategories = Set(
            (previousPlayer.songAssignment != player.songAssignment ? ["playerMedia"] : [])
                + (previousPlayer.customAnnouncerRelativePath != player.customAnnouncerRelativePath ? ["announcement"] : [])
        )
        state.teams[teamIndex].players[playerIndex] = player
        state.teams[teamIndex].modifiedAt = .now
        normalizeLineup(for: teamIndex)
        removeAssetsNoLongerReferenced(from: previousPlayer, to: player)
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
        telemetry.recordPersonalizationChanges(from: previousPlayer, to: player, state: state)
        telemetry.recordRosterMilestones(for: state)
        for category in repairAttemptedCategories where previousRepairCategories.contains(category) {
            telemetry.recordRepairNeeded(category: category)
            telemetry.recordRepairAttempted(category: category)
            if !repairCategories(for: player, in: state.teams[teamIndex]).contains(category) {
                telemetry.recordRepairCompleted(category: category)
            }
        }
        if previousPlayer.songAssignment != player.songAssignment {
            Task { [weak self] in
                guard let self else { return }
                await self.cancelSongClipPreparation(teamID: teamID, target: .player(player.id))
                guard self.songClip(teamID: teamID, target: .player(player.id)) != nil else { return }
                self.scheduleSongClipPreparation(
                    teamID: teamID,
                    playerID: player.id,
                    trigger: .assignmentSaved
                )
            }
        }
    }

    func commitPlayerEditorDraft(_ draft: Player) {
        guard let teamIndex,
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == draft.id }) else {
            return
        }

        var merged = state.teams[teamIndex].players[playerIndex]
        merged.displayName = draft.displayName
        merged.uniformNumber = draft.uniformNumber
        merged.pronunciationOverride = draft.pronunciationOverride
        merged.photoRelativePath = draft.photoRelativePath
        merged.photoSourceRelativePath = draft.photoSourceRelativePath
        merged.profilePhotoCrop = draft.profilePhotoCrop
        merged.playerCardPhotoCrop = draft.playerCardPhotoCrop

        if let draftCue = draft.songAssignment?.privateClip?.editingCue,
           merged.songAssignment?.privateClip?.editingCue != draftCue {
            merged.updatePrivateSongClip(with: draftCue)
        }

        updatePlayer(merged)
    }

    func resolvedSongClip(for player: Player) -> SongClip? {
        selectedTeam?.songClip(for: player)
    }

    func resolvedCue(for player: Player) -> Cue? {
        selectedTeam?.cue(for: player)
    }

    @discardableResult
    func saveCustomClip(cue: Cue, named name: String) -> UUID? {
        guard let teamIndex else { return nil }
        var clip = SongClip(cue: cue)
        clip.id = UUID()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        clip.displayName = trimmedName.isEmpty ? nil : trimmedName
        clip.pauseAfterAnnouncer = 0

        state.teams[teamIndex].teamClips.append(clip)
        state.teams[teamIndex].modifiedAt = .now
        persist()
        telemetry.recordOnce(.clipsFirstCustomCreated)
        scheduleTeamClipPreparation(
            teamID: state.teams[teamIndex].id,
            teamClipID: clip.id,
            trigger: .assignmentSaved
        )
        return clip.id
    }

    func updateCustomClip(_ clipID: UUID, with cue: Cue, named name: String) {
        guard let teamIndex,
              let clipIndex = state.teams[teamIndex].teamClips.firstIndex(where: { $0.id == clipID }) else {
            return
        }
        let previous = state.teams[teamIndex].teamClips[clipIndex]
        let wasInRepair = !cueIsPlayable(previous.playbackCue)
        if wasInRepair {
            telemetry.recordRepairNeeded(category: "customClip")
            telemetry.recordRepairAttempted(category: "customClip")
        }
        let previousPaths = storedAssetRelativePaths(for: previous)
        var updated = SongClip(cue: cue)
        updated.id = clipID
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.displayName = trimmedName.isEmpty ? nil : trimmedName
        updated.pauseAfterAnnouncer = 0
        updated.sourceLineageClipID = previous.sourceLineageClipID
        if previous.generationKey == updated.generationKey {
            updated.generatedAsset = previous.generatedAsset
            updated.readinessInputs = previous.readinessInputs
            updated.portabilityInputs = previous.portabilityInputs
            updated.retryMetadata = previous.retryMetadata
        }
        state.teams[teamIndex].teamClips[clipIndex] = updated
        state.teams[teamIndex].modifiedAt = .now
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        let updatedPaths = Set(storedAssetRelativePaths(for: updated))
        previousPaths
            .filter { !updatedPaths.contains($0) }
            .forEach(removeAssetIfUnreferenced(relativePath:))
        persist()
        scheduleTeamClipPreparation(
            teamID: state.teams[teamIndex].id,
            teamClipID: clipID,
            trigger: .assignmentSaved
        )
        if wasInRepair, cueIsPlayable(updated.playbackCue) {
            telemetry.recordRepairCompleted(category: "customClip")
        }
    }

    func copyExistingClip(_ clip: SongClip, to playerID: UUID) {
        guard let teamIndex,
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }) else {
            return
        }
        state.teams[teamIndex].players[playerIndex].songAssignment = .privateClip(clip.playerSongCopy())
        state.teams[teamIndex].modifiedAt = .now
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
        telemetry.recordOnce(.mediaClipReuseFirstUsed)
        scheduleSongClipPreparation(
            teamID: state.teams[teamIndex].id,
            playerID: playerID,
            trigger: .assignmentSaved
        )
    }

    func savePlayerSongCopy(from sourceClip: SongClip, editedCue: Cue, to playerID: UUID) {
        var copy = SongClip(cue: editedCue)
        copy.id = UUID()
        copy.sourceLineageClipID = sourceClip.id
        copy.pauseAfterAnnouncer = 0.2
        if copy.generationKey == sourceClip.generationKey {
            copy.generatedAsset = sourceClip.generatedAsset
            copy.readinessInputs = sourceClip.readinessInputs
            copy.portabilityInputs = sourceClip.portabilityInputs
            copy.retryMetadata = sourceClip.retryMetadata
        }
        guard let teamIndex,
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }) else {
            return
        }
        state.teams[teamIndex].players[playerIndex].songAssignment = .privateClip(copy)
        state.teams[teamIndex].modifiedAt = .now
        persist()
        telemetry.recordOnce(.mediaClipReuseFirstUsed)
        scheduleSongClipPreparation(
            teamID: state.teams[teamIndex].id,
            playerID: playerID,
            trigger: .assignmentSaved
        )
    }

    @discardableResult
    func saveCustomClipCopy(from sourceClip: SongClip, editedCue: Cue, named name: String) -> UUID? {
        guard let teamIndex else { return nil }
        var copy = SongClip(cue: editedCue)
        copy.id = UUID()
        copy.sourceLineageClipID = sourceClip.id
        copy.pauseAfterAnnouncer = 0
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.displayName = trimmedName.isEmpty ? nil : trimmedName
        if copy.generationKey == sourceClip.generationKey {
            copy.generatedAsset = sourceClip.generatedAsset
            copy.readinessInputs = sourceClip.readinessInputs
            copy.portabilityInputs = sourceClip.portabilityInputs
            copy.retryMetadata = sourceClip.retryMetadata
        }
        state.teams[teamIndex].teamClips.append(copy)
        state.teams[teamIndex].modifiedAt = .now
        persist()
        telemetry.recordOnce(.clipsFirstCustomCreated)
        scheduleTeamClipPreparation(
            teamID: state.teams[teamIndex].id,
            teamClipID: copy.id,
            trigger: .assignmentSaved
        )
        return copy.id
    }

    @discardableResult
    func duplicateSelectedTeamPlayerSongsToCustomClips() -> PlayerSongsToCustomClipsResult {
        guard let teamIndex else {
            return PlayerSongsToCustomClipsResult(copiedCount: 0, skippedCount: 0)
        }

        let team = state.teams[teamIndex]
        let teamID = team.id
        var copies: [SongClip] = []
        var skippedCount = 0

        for player in team.players {
            guard let sourceClip = team.songClip(for: player) else {
                skippedCount += 1
                continue
            }

            var copy = sourceClip.customClipCopy()
            let sourceTitle = sourceClip.displayName ?? sourceClip.playbackCue.label
            copy.displayName = "\(player.displayName) - \(sourceTitle)"
            copies.append(copy)
        }

        guard !copies.isEmpty else {
            return PlayerSongsToCustomClipsResult(copiedCount: 0, skippedCount: skippedCount)
        }

        state.teams[teamIndex].teamClips.append(contentsOf: copies)
        state.teams[teamIndex].modifiedAt = .now
        persist()

        for copy in copies {
            scheduleTeamClipPreparation(
                teamID: teamID,
                teamClipID: copy.id,
                trigger: .assignmentSaved
            )
        }

        return PlayerSongsToCustomClipsResult(copiedCount: copies.count, skippedCount: skippedCount)
    }

    func deleteCustomClip(_ clipID: UUID) {
        guard let teamIndex,
              let clipIndex = state.teams[teamIndex].teamClips.firstIndex(where: { $0.id == clipID }) else {
            return
        }
        let team = state.teams[teamIndex]
        let clip = state.teams[teamIndex].teamClips.remove(at: clipIndex)
        addRecentlyDeletedItem(
            RecentlyDeletedItem(
                id: UUID(),
                deletedAt: .now,
                payload: .customClip(
                    DeletedCustomClipRecord(
                        clip: clip,
                        originalTeamID: team.id,
                        originalTeamName: team.name,
                        previousIndex: clipIndex
                    )
                )
            )
        )
        state.teams[teamIndex].modifiedAt = .now
        Task { [weak self] in
            guard let self else { return }
            await self.cancelSongClipPreparation(teamID: team.id, target: .teamClip(clipID))
        }
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
    }

    func moveCustomClips(fromOffsets: IndexSet, toOffset: Int) {
        guard let teamIndex else { return }
        state.teams[teamIndex].teamClips.move(fromOffsets: fromOffsets, toOffset: toOffset)
        state.teams[teamIndex].modifiedAt = .now
        persist()
    }

    func removePlayer(_ player: Player) {
        guard let teamIndex,
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == player.id }) else { return }
        let team = state.teams[teamIndex]
        let removed = state.teams[teamIndex].players.remove(at: playerIndex)
        addRecentlyDeletedItem(
            RecentlyDeletedItem(
                id: UUID(),
                deletedAt: .now,
                payload: .player(
                    DeletedPlayerRecord(
                        player: removed,
                        originalTeamID: team.id,
                        originalTeamName: team.name,
                        previousBattingOrder: team.session.battingOrder
                    )
                )
            )
        )
        state.teams[teamIndex].modifiedAt = .now
        Task { [weak self] in
            guard let self else { return }
            await self.cancelSongClipPreparation(teamID: team.id, target: .player(player.id))
        }
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
    }

    func togglePresent(_ player: Player) {
        var updated = player
        updated.isPresent.toggle()
        updatePlayer(updated)
    }

    func setPresent(_ player: Player, isPresent: Bool, recordLiveActivity: Bool = false) {
        guard player.isPresent != isPresent else { return }
        var updated = player
        updated.isPresent = isPresent
        updatePlayer(updated)
        if recordLiveActivity, let teamIndex {
            telemetry.handleLineupActivity(teamID: state.teams[teamIndex].id, edited: true)
        }
    }

    func refreshGameDayWarmup() {
        prewarmNextBatterCue()
    }

    func movePlayers(from offsets: IndexSet, to offset: Int, recordLiveActivity: Bool = false) {
        guard let teamIndex else { return }
        state.teams[teamIndex].players.move(fromOffsets: offsets, toOffset: offset)
        state.teams[teamIndex].session.battingOrder = state.teams[teamIndex].players.map(\.id)
        state.teams[teamIndex].session.battingOrderIsCustomized = true
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
        if recordLiveActivity {
            telemetry.handleLineupActivity(teamID: state.teams[teamIndex].id, edited: true)
        }
    }

    func moveBattingOrder(from offsets: IndexSet, to offset: Int, recordLiveActivity: Bool = false) {
        guard let teamIndex else { return }
        state.teams[teamIndex].session.battingOrder.move(fromOffsets: offsets, toOffset: offset)
        state.teams[teamIndex].session.battingOrderIsCustomized = true
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
        if recordLiveActivity {
            telemetry.handleLineupActivity(teamID: state.teams[teamIndex].id, edited: true)
        }
    }

    func sortBattingOrderAlphabetically(recordLiveActivity: Bool = false) {
        guard let teamIndex else { return }
        state.teams[teamIndex].session.battingOrder = alphabeticalBattingOrder(for: state.teams[teamIndex].players)
        state.teams[teamIndex].session.battingOrderIsCustomized = true
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
        if recordLiveActivity {
            telemetry.handleLineupActivity(teamID: state.teams[teamIndex].id, edited: true)
        }
    }

    func sortBattingOrderByNumber(recordLiveActivity: Bool = false) {
        guard let teamIndex else { return }
        state.teams[teamIndex].session.battingOrder = uniformNumberBattingOrder(for: state.teams[teamIndex].players)
        state.teams[teamIndex].session.battingOrderIsCustomized = true
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
        if recordLiveActivity {
            telemetry.handleLineupActivity(teamID: state.teams[teamIndex].id, edited: true)
        }
    }

    @discardableResult
    func assignAppleMusic(_ result: MusicSearchResult, to player: Player) async -> Bool {
        do {
            await refreshAppleMusicPlaybackCapability()
            let resolvedResult = try await enrichedAppleMusicSelection(result)
            var updated = player
            updated.cue = makeDefaultAppleMusicCue(for: resolvedResult)
            rememberAppleMusicSelection(resolvedResult)
            updatePlayer(updated)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func makeAppleMusicCueDraft(_ result: MusicSearchResult) -> Cue {
        makeDefaultAppleMusicCue(for: result)
    }

    func makeImportedSongCueDraft(from url: URL) async -> Cue? {
        do {
            let source = try await audioAssetService.importMedia(from: url)
            return .localDefault(source: source)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func discardImportedSongCueDraft(_ cue: Cue) {
        guard case .localAudio(let source) = cue.source else { return }
        audioAssetService.removeAsset(relativePath: source.relativePath)
    }

    func saveSongCue(_ cue: Cue, to playerID: UUID) {
        guard let teamIndex,
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }) else {
            return
        }
        var updated = state.teams[teamIndex].players[playerIndex]
        updated.cue = cue
        if case .appleMusic(let source) = cue.source {
            rememberAppleMusicSelection(
                MusicSearchResult(
                    songID: source.songID,
                    title: source.title,
                    artistName: source.artistName,
                    duration: source.duration,
                    previewURL: source.previewURL,
                    isCatalogBacked: source.isCatalogBacked ?? true,
                    libraryPersistentID: source.libraryPersistentID,
                    isExplicit: source.isExplicit
                )
            )
        }
        updatePlayer(updated)
    }

    func importMedia(from url: URL, for player: Player) async {
        await busy(operationName: "Media import") {
            let source = try await self.audioAssetService.importMedia(from: url)
            var updated = player
            updated.cue = .localDefault(source: source)
            self.updatePlayer(updated)
            let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv"]
            self.telemetry.recordOnce(videoExtensions.contains(url.pathExtension.lowercased()) ? .mediaImportFirstVideo : .mediaImportFirstAudio)
        }
    }

    func startRecordingCustomAnnouncer(forPlayerID playerID: UUID) async {
        customAnnouncerRecordingPhase = .starting(playerID)
        do {
            let destinationURL = customAnnouncerTemporaryURL(fileExtension: "caf")
            try await customAnnouncerRecorder.startRecording(for: playerID, destinationURL: destinationURL)
            customAnnouncerRecordingPhase = .recording(playerID)
        } catch {
            customAnnouncerRecordingPhase = .idle
            if let appError = error as? AppError, case .microphonePermissionDenied = appError {
                telemetry.recordOnce(.microphoneAccessDenied, properties: [.result: "denied"])
            }
            lastError = error.localizedDescription
        }
    }

    func stopRecordingCustomAnnouncer(forPlayerID playerID: UUID) async {
        guard let teamIndex,
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }) else {
            customAnnouncerRecorder.cancelRecording()
            customAnnouncerRecordingPhase = .idle
            return
        }
        let player = state.teams[teamIndex].players[playerIndex]
        customAnnouncerRecordingPhase = .stopping(playerID)
        do {
            let recordedURL = try await customAnnouncerRecorder.stopRecording()
            let asset: LocalAudioSource
            do {
                let replacementRelativePath = player.customAnnouncerRelativePath == nil
                    ? nil
                    : self.audioAssetService.freshCustomAnnouncerRelativePath()
                asset = try audioAssetService.storeCustomAnnouncerRecording(
                    from: recordedURL,
                    playerID: player.id,
                    displayName: "\(player.displayName)-custom-announcer",
                    relativePath: replacementRelativePath
                )
            } catch {
                throw AppError.customIntroSaveFailed("recorded file could not be reopened. \(customIntroFileSummary(for: recordedURL)); reader error: \(customIntroErrorSummary(error))")
            }
            guard audioAssetService.assetExists(relativePath: asset.relativePath) else {
                throw AppError.customIntroSaveFailed("saved flat asset was not visible at \(asset.relativePath)")
            }
            try? FileManager.default.removeItem(at: recordedURL)
            var updated = player
            updated.customAnnouncerRelativePath = asset.relativePath
            updatePlayer(updated)
            try configurePlaybackAudioSession()
            customAnnouncerRecordingPhase = .idle
        } catch {
            customAnnouncerRecordingPhase = .idle
            lastError = error.localizedDescription
        }
    }

    func cancelRecordingCustomAnnouncer() {
        customAnnouncerRecorder.cancelRecording()
        customAnnouncerRecordingPhase = .idle
        try? configurePlaybackAudioSession()
    }

    func previewCustomAnnouncer(for player: Player) {
        guard let relativePath = player.customAnnouncerRelativePath else { return }
        do {
            try playbackEngine.previewAsset(relativePath: relativePath)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearSong(forPlayerID playerID: UUID) {
        guard let teamIndex,
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }) else {
            return
        }
        var updated = state.teams[teamIndex].players[playerIndex]
        updated.cue = nil
        updatePlayer(updated)
    }

    func clearCustomAnnouncer(forPlayerID playerID: UUID) {
        guard let teamIndex,
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }) else {
            return
        }
        var updated = state.teams[teamIndex].players[playerIndex]
        updated.customAnnouncerRelativePath = nil
        updatePlayer(updated)
    }

    func play(player: Player, teamID: UUID? = nil) async {
        let requestID = beginPlaybackRequest()
        let currentPlayer: Player
        if let teamID {
            guard state.selectedTeamID == teamID,
                  let selectedPlayer = selectedTeam?.players.first(where: { $0.id == player.id }) else { return }
            currentPlayer = selectedPlayer
        } else {
            guard let selectedPlayer = selectedTeam?.players.first(where: { $0.id == player.id }) else { return }
            currentPlayer = selectedPlayer
        }
        let selectedTeamID = state.selectedTeamID ?? teamID
        var attemptedPlan: PlayerPlaybackPlan?
        do {
            guard let plan = playbackPlan(for: currentPlayer) else { return }
            attemptedPlan = plan
            let result: PlaybackRequestResult
            switch plan {
            case .cue(let cue, let announcerRelativePath, let sourceFamily):
                result = try await playbackEngine.play(
                    cue: cue,
                    announcerRelativePath: announcerRelativePath,
                    fadeOutVolumeAutomationEnabled: state.settings.fadeOutVolumeAutomationEnabled,
                    sourceFamilyOverride: sourceFamily
                )
            case .assetOnly(let relativePath, let activeCueID):
                result = try await playbackEngine.playAsset(
                    relativePath: relativePath,
                    activeCueID: activeCueID,
                    fadeOutVolumeAutomationEnabled: state.settings.fadeOutVolumeAutomationEnabled
                )
            }
            guard isCurrentPlaybackRequest(requestID) else { return }
            guard result.hasStartedComponent else { return }
            if let selectedTeamID {
                if let started = result.confirmations.first(where: {
                    if case .started = $0.outcome { return true }; return false
                }) {
                    activePlaybackTelemetryContext = (result.requestID, selectedTeamID, currentPlayer.id, started.sourceFamily)
                }
                telemetry.beginLiveSessionIfNeeded(teamID: selectedTeamID)
                telemetry.handlePlayerPlayback(
                    teamID: selectedTeamID,
                    playerID: currentPlayer.id,
                    result: result,
                    gameProperties: gameProperties(for: selectedTeamID),
                    playbackMode: playbackMode(for: selectedTeamID)
                )
                recordRecoveries(in: result, teamID: selectedTeamID)
            }
            haptics.success(isEnabled: state.settings.hapticsEnabled)
        } catch {
            guard isCurrentPlaybackRequest(requestID) else { return }
            if let attemptedPlan,
               let fallbackCue = fallbackCueAfterPlaybackFailure(for: currentPlayer, plan: attemptedPlan) {
                activeFallbackPlayerID = currentPlayer.id
                do {
                    let fallbackResult = try await playbackEngine.play(
                        cue: fallbackCue,
                        announcerRelativePath: nil,
                        fadeOutVolumeAutomationEnabled: state.settings.fadeOutVolumeAutomationEnabled
                    )
                    guard isCurrentPlaybackRequest(requestID) else { return }
                    guard fallbackResult.hasStartedComponent else { return }
                    if let selectedTeamID {
                        if let started = fallbackResult.confirmations.first(where: {
                            if case .started = $0.outcome { return true }; return false
                        }) {
                            activePlaybackTelemetryContext = (fallbackResult.requestID, selectedTeamID, currentPlayer.id, started.sourceFamily)
                        }
                        telemetry.beginLiveSessionIfNeeded(teamID: selectedTeamID)
                        telemetry.handlePlayerPlayback(
                            teamID: selectedTeamID,
                            playerID: currentPlayer.id,
                            result: fallbackResult,
                            gameProperties: gameProperties(for: selectedTeamID),
                            playbackMode: playbackMode(for: selectedTeamID)
                        )
                        recordRecoveries(in: fallbackResult, teamID: selectedTeamID)
                        let failedComponent: PlaybackComponent = {
                            if case .assetOnly = attemptedPlan { return .announcement }
                            return .primaryCue
                        }()
                        telemetry.recordRecovery(
                            teamID: selectedTeamID,
                            failedComponent: failedComponent,
                            sourceFamily: failureSourceFamily(for: attemptedPlan),
                            recoveryOutcome: {
                                if case .builtInClip = fallbackCue.source { return "builtinCheer" }
                                return "songOnly"
                            }(),
                            reason: playbackEngine.playbackFailureReason(for: error)
                        )
                    }
                    haptics.success(isEnabled: state.settings.hapticsEnabled)
                    return
                } catch {
                    guard isCurrentPlaybackRequest(requestID) else { return }
                    if let selectedTeamID {
                        telemetry.recordPlaybackFailure(
                            teamID: selectedTeamID,
                            sourceFamily: failureSourceFamily(for: attemptedPlan),
                            liveContext: "gameDay",
                            fallbackAttempted: true,
                            reason: playbackEngine.playbackFailureReason(for: error)
                        )
                    }
                    activeFallbackPlayerID = nil
                    lastError = error.localizedDescription
                    haptics.warning(isEnabled: state.settings.hapticsEnabled)
                    return
                }
            }
            if let selectedTeamID {
                telemetry.recordPlaybackFailure(
                    teamID: selectedTeamID,
                    sourceFamily: attemptedPlan.map(failureSourceFamily(for:)) ?? .unknown,
                    liveContext: "gameDay",
                    fallbackAttempted: false,
                    reason: playbackEngine.playbackFailureReason(for: error)
                )
            }
            lastError = error.localizedDescription
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
        }
    }

    func play(builtInClip: BuiltInClip) async {
        let requestID = beginPlaybackRequest()
        do {
            let result = try await playbackEngine.play(
                cue: builtInClip.cue,
                fadeOutVolumeAutomationEnabled: state.settings.fadeOutVolumeAutomationEnabled
            )
            guard isCurrentPlaybackRequest(requestID) else { return }
            if result.hasStartedComponent, let teamID = state.selectedTeamID {
                telemetry.beginLiveSessionIfNeeded(teamID: teamID)
                telemetry.handleClipPlayback(teamID: teamID, isCustom: false)
            }
            haptics.success(isEnabled: state.settings.hapticsEnabled)
        } catch {
            guard isCurrentPlaybackRequest(requestID) else { return }
            telemetry.recordPlaybackFailure(
                teamID: state.selectedTeamID,
                sourceFamily: .builtin,
                liveContext: "clips",
                fallbackAttempted: false,
                reason: playbackEngine.playbackFailureReason(for: error)
            )
            lastError = error.localizedDescription
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
        }
    }

    func play(customClip: SongClip) async {
        let requestID = beginPlaybackRequest()
        let currentClip = selectedTeam?.teamClips.first(where: { $0.id == customClip.id }) ?? customClip
        let cue = currentClip.playbackCue
        guard cueIsPlayable(cue) else {
            telemetry.recordRepairNeeded(category: "customClip")
            lastError = currentClip.readinessInputs.playback == .needsAppleMusic
                ? "This Custom Clip needs Apple Music access on this device."
                : "This Custom Clip needs repair before it can play."
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
            return
        }
        let sourceFamily = currentClip.hasCurrentGeneratedAsset
            ? PlaybackSourceFamily.generatedLocal
            : playbackSourceFamily(for: cue)
        do {
            let result = try await playbackEngine.play(
                cue: cue,
                fadeOutVolumeAutomationEnabled: state.settings.fadeOutVolumeAutomationEnabled,
                sourceFamilyOverride: sourceFamily
            )
            guard isCurrentPlaybackRequest(requestID) else { return }
            if result.hasStartedComponent, let teamID = state.selectedTeamID {
                telemetry.beginLiveSessionIfNeeded(teamID: teamID)
                telemetry.handleClipPlayback(teamID: teamID, isCustom: true)
            }
            haptics.success(isEnabled: state.settings.hapticsEnabled)
        } catch {
            guard isCurrentPlaybackRequest(requestID) else { return }
            telemetry.recordPlaybackFailure(
                teamID: state.selectedTeamID,
                sourceFamily: sourceFamily,
                liveContext: "clips",
                fallbackAttempted: false,
                reason: playbackEngine.playbackFailureReason(for: error)
            )
            lastError = error.localizedDescription
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
        }
    }

    func customClipCanPlay(_ clip: SongClip) -> Bool {
        cueIsPlayable(clip.playbackCue)
    }

    func stopPlayback() {
        _ = beginPlaybackRequest()
        playbackEngine.stop()
    }

    private func beginPlaybackRequest() -> UUID {
        let requestID = UUID()
        activePlaybackRequestID = requestID
        activePlaybackTelemetryContext = nil
        activeFallbackPlayerID = nil
        return requestID
    }

    private func isCurrentPlaybackRequest(_ requestID: UUID) -> Bool {
        activePlaybackRequestID == requestID
    }

    private func recordRecoveries(in result: PlaybackRequestResult, teamID: UUID) {
        guard result.confirmations.contains(where: {
            if case .started = $0.outcome { return true }; return false
        }) else { return }
        for confirmation in result.confirmations {
            guard case .failed(let reason) = confirmation.outcome else { continue }
            let outcome: String
            switch confirmation.component {
            case .announcement: outcome = "songOnly"
            case .primaryCue: outcome = "introOnly"
            }
            telemetry.recordRecovery(
                teamID: teamID,
                failedComponent: confirmation.component,
                sourceFamily: confirmation.sourceFamily,
                recoveryOutcome: outcome,
                reason: reason
            )
        }
    }

    func previewCue(_ cue: Cue) async {
        let requestID = beginPlaybackRequest()
        await previewCue(cue, requestID: requestID)
    }

    private func previewCue(_ cue: Cue, requestID: UUID) async {
        do {
            if let previewPlaybackResolver {
                try await previewPlaybackResolver(cue)
            } else {
                try await playbackEngine.play(
                    cue: cue,
                    fadeOutVolumeAutomationEnabled: state.settings.fadeOutVolumeAutomationEnabled
                )
            }
            guard isCurrentPlaybackRequest(requestID) else { return }
        } catch {
            guard isCurrentPlaybackRequest(requestID), !Task.isCancelled else { return }
            lastError = error.localizedDescription
        }
    }

    func previewAppleMusicSearchResult(_ result: MusicSearchResult) async {
        let requestID = beginPlaybackRequest()
        do {
            await refreshAppleMusicPlaybackCapability()
            guard isCurrentPlaybackRequest(requestID), !Task.isCancelled else { return }
            let resolvedResult = try await enrichedAppleMusicSelection(result)
            guard isCurrentPlaybackRequest(requestID), !Task.isCancelled else { return }
            let cue = makeDefaultAppleMusicCue(for: resolvedResult)
            await previewCue(cue, requestID: requestID)
        } catch {
            guard isCurrentPlaybackRequest(requestID), !Task.isCancelled else { return }
            guard !MusicCatalogService.isCancellation(error) else { return }
            lastError = error.localizedDescription
        }
    }

    func refreshAppleMusicPlaybackCapability() async {
        let capability = await appleMusicPlaybackCapabilityResolver()
        appleMusicPlaybackCapability = capability
    }

    var musicRenderProbeAuthorizationStatusText: String {
        switch MusicAuthorization.currentStatus {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }

    var musicRenderProbePlaybackCapabilityText: String {
        switch appleMusicPlaybackCapability {
        case .unknown:
            return "Unknown"
        case .previewOnly:
            return "Preview Only"
        case .fullSong:
            return "Full Song"
        }
    }

    var musicRenderProbeLocalCandidates: [MusicRenderProbeLocalCandidate] {
        var seenRelativePaths = Set<String>()
        var candidates: [MusicRenderProbeLocalCandidate] = []

        for team in state.teams {
            for player in team.players {
                guard let cue = player.cue,
                      case .localAudio(let source) = cue.source,
                      seenRelativePaths.insert(source.relativePath).inserted else {
                    continue
                }

                candidates.append(
                    MusicRenderProbeLocalCandidate(
                        id: player.id,
                        source: source,
                        teamName: team.name,
                        playerName: player.displayName
                    )
                )
            }
        }

        return candidates.sorted {
            if $0.source.displayName.localizedCaseInsensitiveCompare($1.source.displayName) == .orderedSame {
                return $0.playerName.localizedCaseInsensitiveCompare($1.playerName) == .orderedAscending
            }
            return $0.source.displayName.localizedCaseInsensitiveCompare($1.source.displayName) == .orderedAscending
        }
    }

    var musicRenderProbeSummary: MusicRenderProbeRedactedSummary? {
        guard musicRenderProbeSamples.contains(where: { $0.selection != nil || $0.result != nil }) else {
            return nil
        }

        return MusicRenderProbeRedactedSummary.make(
            samples: musicRenderProbeSamples,
            authorizationStatus: musicRenderProbeAuthorizationStatusText,
            playbackCapability: musicRenderProbePlaybackCapabilityText
        )
    }

    func searchAppleMusic(term: String) async throws -> [MusicSearchResult] {
        await refreshAppleMusicPlaybackCapability()
        let mode: AppleMusicSearchMode = appleMusicPlaybackCapability == .fullSong ? .catalogOnly : .previewFallback
        return try await musicCatalogService.search(term: term, mode: mode)
    }

    func loadMusicRenderProbeLibraryCandidates() async {
        isMusicRenderProbeLoadingLibrary = true
        defer { isMusicRenderProbeLoadingLibrary = false }

        if MusicAuthorization.currentStatus == .notDetermined {
            _ = await requestAppleMusicAccess()
        } else {
            await refreshAppleMusicPlaybackCapability()
        }

        guard MusicAuthorization.currentStatus == .authorized else {
            lastError = AppError.musicAuthorizationRequired.localizedDescription
            return
        }

        do {
            musicRenderProbeLibraryCandidates = try musicRenderProbeService.loadLibraryCandidates()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func searchMusicRenderProbeCatalog(term: String) async {
        isMusicRenderProbeSearchingCatalog = true
        defer { isMusicRenderProbeSearchingCatalog = false }

        do {
            musicRenderProbeCatalogCandidates = try await searchAppleMusic(term: term).map {
                MusicRenderProbeCatalogCandidate(
                    songID: $0.songID,
                    title: $0.title,
                    artistName: $0.artistName,
                    duration: $0.duration,
                    previewURL: $0.previewURL,
                    isCatalogBacked: $0.isCatalogBacked
                )
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func assignMusicRenderProbeLibraryCandidate(_ candidate: MusicRenderProbeLibraryCandidate, to scenario: MusicRenderProbeScenario) {
        updateMusicRenderProbeSample(for: scenario) { sample in
            sample.selection = .library(candidate)
            sample.result = nil
        }
    }

    func assignMusicRenderProbeCatalogCandidate(_ candidate: MusicRenderProbeCatalogCandidate, to scenario: MusicRenderProbeScenario) {
        updateMusicRenderProbeSample(for: scenario) { sample in
            sample.selection = .catalog(candidate)
            sample.result = nil
        }
    }

    func assignMusicRenderProbeLocalCandidate(_ candidate: MusicRenderProbeLocalCandidate, to scenario: MusicRenderProbeScenario) {
        updateMusicRenderProbeSample(for: scenario) { sample in
            sample.selection = .local(candidate)
            sample.result = nil
        }
    }

    func clearMusicRenderProbeSample(for scenario: MusicRenderProbeScenario) {
        updateMusicRenderProbeSample(for: scenario) { sample in
            sample.selection = nil
            sample.result = nil
        }
    }

    func runMusicRenderProbe(for scenario: MusicRenderProbeScenario) async {
        guard let sample = musicRenderProbeSamples.first(where: { $0.scenario == scenario }) else { return }
        guard sample.selection != nil else {
            lastError = "Choose a sample before running the probe."
            return
        }

        let result = await musicRenderProbeService.runProbe(for: sample)
        updateMusicRenderProbeSample(for: scenario) { $0.result = result }
    }

    func runAllAssignedMusicRenderProbes() async {
        for sample in musicRenderProbeSamples where sample.selection != nil {
            await runMusicRenderProbe(for: sample.scenario)
        }
    }

    func exportMusicRenderProbeSummary() {
        guard let summary = musicRenderProbeSummary else { return }

        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("RollCall-MusicRenderProbe-\(UUID().uuidString).json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(summary).write(to: url, options: .atomic)
            musicRenderProbeSummaryURL = url
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func refreshAppleMusicCueMetadata(for playerID: UUID) async -> Bool {
        await refreshAppleMusicPlaybackCapability()
        guard appleMusicPlaybackCapability == .fullSong,
              let teamID = state.selectedTeamID,
              let team = state.teams.first(where: { $0.id == teamID }),
              let player = team.players.first(where: { $0.id == playerID }),
              let cue = player.cue,
              case .appleMusic(let source) = cue.source,
              source.isCatalogBacked != false,
              source.duration == nil else {
            return false
        }

        do {
            let resolved = try await catalogBackedResultResolver(MusicSearchResult(
                songID: source.songID,
                title: source.title,
                artistName: source.artistName,
                duration: source.duration,
                previewURL: source.previewURL,
                isCatalogBacked: true
            ))
            guard let teamIndex = state.teams.firstIndex(where: { $0.id == teamID }),
                  let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }),
                  var currentCue = state.teams[teamIndex].players[playerIndex].cue,
                  case .appleMusic(let currentSource) = currentCue.source,
                  currentSource == source else {
                return false
            }

            var refreshedSource = source
            refreshedSource.songID = resolved.songID
            refreshedSource.title = resolved.title
            refreshedSource.artistName = resolved.artistName
            refreshedSource.duration = resolved.duration
            refreshedSource.previewURL = resolved.previewURL
            refreshedSource.isCatalogBacked = true
            refreshedSource.libraryPersistentID = nil
            currentCue.source = .appleMusic(refreshedSource)
            state.teams[teamIndex].players[playerIndex].cue = currentCue
            persist()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func previewBuiltInAnnouncer(profile: TeamAnnouncerProfile? = nil) async {
        lastError = "Built-in Voice has been removed from Roll Call. Use Announcement Cue recordings instead."
    }

    func advanceNextBatter() {
        advanceNextBatter(hintSource: .nextButton)
    }

    func advanceNextBatterFromOnDeck() {
        advanceNextBatter(hintSource: .onDeckCard)
    }

    private func advanceNextBatter(hintSource: GameDayLineupProgressHintSource) {
        guard let teamIndex else { return }
        let present = state.teams[teamIndex].presentPlayersInBattingOrder
        guard !present.isEmpty else {
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
            return
        }
        state.teams[teamIndex].session.nextBatterIndex = (state.teams[teamIndex].session.nextBatterIndex + 1) % present.count
        state.teams[teamIndex].modifiedAt = .now
        gameDayLineupProgressHintEvent = GameDayLineupProgressHintEvent(teamID: state.teams[teamIndex].id, source: hintSource)
        haptics.success(isEnabled: state.settings.hapticsEnabled)
        prewarmNextBatterCue()
        persist()
        telemetry.handleLineupActivity(teamID: state.teams[teamIndex].id)
    }

    func goToPreviousBatter() {
        guard let teamIndex else { return }
        let present = state.teams[teamIndex].presentPlayersInBattingOrder
        guard !present.isEmpty else {
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
            return
        }
        let count = present.count
        state.teams[teamIndex].session.nextBatterIndex = (state.teams[teamIndex].session.nextBatterIndex - 1 + count) % count
        state.teams[teamIndex].modifiedAt = .now
        haptics.success(isEnabled: state.settings.hapticsEnabled)
        prewarmNextBatterCue()
        persist()
        telemetry.handleLineupActivity(teamID: state.teams[teamIndex].id)
    }

    func setHapticsEnabled(_ isEnabled: Bool) {
        state.settings.hapticsEnabled = isEnabled
        persist()
    }

    func setFadeOutVolumeAutomationEnabled(_ isEnabled: Bool) {
        let changed = state.settings.fadeOutVolumeAutomationEnabled != isEnabled
        state.settings.fadeOutVolumeAutomationEnabled = isEnabled
        persist()
        if changed { telemetry.recordOnce(.settingVolumeAutomationFirstChanged, properties: [.newValue: isEnabled ? "on" : "off"]) }
    }

    func setAlwaysUseDarkLiveMode(_ isEnabled: Bool) {
        let changed = state.settings.alwaysUseDarkLiveMode != isEnabled
        state.settings.alwaysUseDarkLiveMode = isEnabled
        persist()
        if changed { telemetry.recordOnce(.settingDarkLiveScreensFirstChanged, properties: [.newValue: isEnabled ? "on" : "off"]) }
    }

    func setKeepScreenAwakeDuringLiveUse(_ isEnabled: Bool) {
        let changed = state.settings.keepScreenAwakeDuringLiveUse != isEnabled
        state.settings.keepScreenAwakeDuringLiveUse = isEnabled
        persist()
        if changed { telemetry.recordOnce(.settingKeepScreenAwakeFirstChanged, properties: [.newValue: isEnabled ? "on" : "off"]) }
    }

    func setShowLineupProgressHints(_ isEnabled: Bool) {
        state.settings.showLineupProgressHints = isEnabled
        persist()
    }

    func setExplicitAppleMusicSearchFilteringEnabled(_ isEnabled: Bool) {
        let changed = state.settings.explicitAppleMusicSearchFilteringEnabled != isEnabled
        state.settings.explicitAppleMusicSearchFilteringEnabled = isEnabled
        persist()
        if changed { telemetry.recordOnce(.settingExplicitFilterFirstChanged, properties: [.newValue: isEnabled ? "on" : "off"]) }
    }

    var anonymousUsageAnalyticsEnabled: Bool { telemetry.analyticsEnabled }

    func setAnonymousUsageAnalyticsEnabled(_ isEnabled: Bool) {
        telemetry.setAnalyticsEnabled(isEnabled)
    }

    func setSongClipPreparationLiveUseThrottled(_ throttled: Bool) {
        songClipPreparationLiveUseThrottled = throttled
        Task {
            await runSongClipPreparationQueueIfNeeded()
            await refreshPendingSongClipPreparationCount()
        }
    }

    func prepareSongClipForPlayerEditor(_ playerID: UUID) {
        guard let teamID = selectedTeam?.id else { return }
        scheduleSongClipPreparation(teamID: teamID, playerID: playerID, trigger: .playerEditor)
    }

    func prepareSongsForReadiness() {
        scheduleAllSongClipPreparation(trigger: .readiness)
    }

    func prepareSongsAfterForeground() {
        scheduleAllSongClipPreparation(trigger: .foreground)
    }

    func tryPreparingSongNow(for playerID: UUID) {
        guard let teamID = selectedTeam?.id else { return }
        scheduleSongClipPreparation(
            teamID: teamID,
            playerID: playerID,
            trigger: .explicitTryNow,
            isExplicit: true
        )
    }

    func tryPreparingTeamClipNow(_ teamClipID: UUID) {
        guard let teamID = selectedTeam?.id else { return }
        scheduleTeamClipPreparation(
            teamID: teamID,
            teamClipID: teamClipID,
            trigger: .explicitTryNow,
            isExplicit: true
        )
    }

    func markCurrentWhatsNewSeen() {
        state.lastSeenWhatsNewReleaseID = AppMetadata.whatsNewReleaseID
        persist()
    }

    func resetWhatsNewSeenForTesting() {
        state.lastSeenWhatsNewReleaseID = nil
        persist()
    }

    func beginGameDayVisitForRatingIfNeeded() {
        // Retained as a source-compatible no-op for older callers. Rating
        // policy is now driven by the telemetry store's probable-game state.
    }

    func finalizeGameDayVisitForRatingIfNeeded(at date: Date = .now) {
        // Retained as a source-compatible no-op. Leaving Game Day is not a
        // qualifying telemetry or rating event.
    }

    func markAutomaticRatingPromptAttempted() {
        // Automatic attempts are consumed only by the confirmed appearance
        // callback. This old method intentionally cannot consume one.
    }

    func setRatingThresholdMetForTesting(_ isMet: Bool) {
        var candidate = telemetry.store.state
        candidate.rating.enrollmentDate = isMet ? Date().addingTimeInterval(-7 * 86_400) : Date()
        candidate.rating.distinctProbableGameDates = isMet
            ? [candidate.rating.enrollmentDate, candidate.rating.enrollmentDate.addingTimeInterval(86_400)]
            : []
        candidate.rating.probableGameDateKeys = isMet
            ? RollCallRatingPolicy.distinctLocalDates(candidate.rating.distinctProbableGameDates).map { RollCallRatingPolicy.localDateKey(for: $0) }
            : []
        candidate.rating.automaticAttemptsConsumed = 0
        candidate.rating.firstSheetShownAt = nil
        candidate.rating.presentationCooldownAnchor = nil
        candidate.rating.permanentlySuppressed = false
        candidate.rating.eligibilityEmittedForAttempts = []
        _ = telemetry.store.save(candidate)
    }

    private func normalizeRatingRequestPolicyState() {
        // The legacy AppState fields remain decodable for migration only. New
        // policy state is never normalized back into AppState.
    }

    func reserveAutomaticRatingPresentation() -> UUID? {
        telemetry.reserveRatingPresentation(source: .automatic)
    }

    func reserveManualRatingPresentation() -> UUID? {
        telemetry.reserveRatingPresentation(source: .manual)
    }

    func confirmRatingSheetAppeared(token: UUID, source: PendingRatingPresentation.Source) {
        _ = source
        telemetry.confirmRatingPresentation(token: token)
    }

    func cancelRatingSheetBeforeAppearance(token: UUID? = nil) {
        telemetry.cancelRatingPresentationBeforeAppearance(token: token)
    }

    func recordRatingAction(_ event: RollCallTelemetryEvent, suppressesAutomatic: Bool) {
        telemetry.recordRatingAction(event, suppressesAutomatic: suppressesAutomatic)
    }

    func setGameDayAnnouncerMode(_ mode: GameDayAnnouncerMode) {
        guard let teamIndex else { return }
        let teamID = state.teams[teamIndex].id
        let changed = state.teams[teamIndex].session.gameDayAnnouncerMode != mode
        state.teams[teamIndex].session.gameDayAnnouncerMode = mode
        state.teams[teamIndex].modifiedAt = .now
        scheduleReadinessRefresh()
        persist()
        if changed, mode != .announcerAndSong {
            telemetry.recordOnce(.announcerModeFirstChanged, properties: [.newMode: mode.rawValue], teamID: teamID)
        }
    }

    func saveSelectedTeamAnnouncerProfile(_ profile: TeamAnnouncerProfile) {
        lastError = "Built-in Voice has been removed from Roll Call. Use Announcement Cue recordings instead."
    }

    func setShowExperimentalFeatures(_ isEnabled: Bool) {
        state.experimental.showExperimentalFeatures = isEnabled
        persist()
    }

    private func markGameDayPlayerCuePlayedForRating() {
        // Rating eligibility is updated by confirmed structured playback.
    }

    func selectedTeamAppleMusicPlaylistSummary() -> TeamAppleMusicPlaylistSummary? {
        guard let team = selectedTeam else { return nil }
        return TeamAppleMusicPlaylistSummary(team: team)
    }

    func clearAppleMusicPlaylistStatus() {
        appleMusicPlaylistSyncStatus = nil
        appleMusicPlaylistRecovery = nil
    }

    func cancelAppleMusicPlaylistRecovery() {
        appleMusicPlaylistRecovery = nil
        appleMusicPlaylistSyncStatus = "Playlist update canceled. Apple Music was not changed."
    }

    func continueAppleMusicPlaylistUpdate(_ recovery: AppleMusicPlaylistRecovery) async {
        appleMusicPlaylistRecovery = nil
        await syncAppleMusicPlaylist(summary: recovery.summary, songIDs: recovery.availableSongIDs, allowsRecovery: false)
    }

    func syncAppleMusicPlaylist(summary: TeamAppleMusicPlaylistSummary) async {
        await syncAppleMusicPlaylist(summary: summary, songIDs: summary.songIDs, allowsRecovery: true)
    }

    private func syncAppleMusicPlaylist(
        summary: TeamAppleMusicPlaylistSummary,
        songIDs: [String],
        allowsRecovery: Bool
    ) async {
        guard !isAppleMusicPlaylistSyncing else { return }
        guard !songIDs.isEmpty else {
            appleMusicPlaylistSyncStatus = AppError.noAppleMusicTeamCues.localizedDescription
            return
        }

        isAppleMusicPlaylistSyncing = true
        appleMusicPlaylistSyncStatus = "Saving \"\(summary.playlistName)\"..."
        defer { isAppleMusicPlaylistSyncing = false }

        do {
            let resolved = try await musicCatalogService.resolveTeamPlaylistSongs(songIDs: songIDs)
            if !resolved.unresolvedSongIDs.isEmpty {
                if allowsRecovery {
                    let unresolvedIDSet = Set(resolved.unresolvedSongIDs)
                    appleMusicPlaylistRecovery = AppleMusicPlaylistRecovery(
                        summary: summary,
                        unresolvedSongs: summary.includedSongs.filter { unresolvedIDSet.contains($0.songID) },
                        availableSongIDs: resolved.resolvedSongIDs
                    )
                    appleMusicPlaylistSyncStatus = "Apple Music could not find \(resolved.unresolvedSongIDs.count) \(resolved.unresolvedSongIDs.count == 1 ? "song" : "songs"). Review before continuing."
                    haptics.warning(isEnabled: state.settings.hapticsEnabled)
                    return
                } else {
                    appleMusicPlaylistSyncStatus = "Apple Music could not find every selected song. Playlist was not changed."
                    haptics.warning(isEnabled: state.settings.hapticsEnabled)
                    return
                }
            }
            guard !resolved.songs.isEmpty else {
                appleMusicPlaylistSyncStatus = AppError.noAppleMusicTeamCues.localizedDescription
                return
            }

            try await musicCatalogService.replaceTeamPlaylist(name: summary.playlistName, songs: resolved.songs)
            var message = "Saved \"\(summary.playlistName)\" with \(resolved.songs.count) \(resolved.songs.count == 1 ? "song" : "songs")."
            let skippedCount = summary.skippedCues.count
            if skippedCount > 0 {
                message += " Skipped \(skippedCount) unsupported \(skippedCount == 1 ? "cue" : "cues")."
            }
            let duplicateCount = summary.duplicateSongs.count
            if duplicateCount > 0 {
                message += " Added \(duplicateCount == 1 ? "1 duplicate song" : "\(duplicateCount) duplicate songs") once."
            }
            appleMusicPlaylistSyncStatus = message
            if let teamID = state.selectedTeamID {
                telemetry.recordPlaylistSyncSuccess(teamID: teamID)
            }
            haptics.success(isEnabled: state.settings.hapticsEnabled)
        } catch {
            appleMusicPlaylistSyncStatus = error.localizedDescription
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
        }
    }

    func prepareSelectedTeamExport() {
        guard let team = selectedTeam else { return }
        pendingPackageExport = PendingPackageExport(
            teamID: team.id,
            teamName: team.name,
            summary: packageService.transferSummary(for: team)
        )
    }

    func cancelPendingPackageExport() {
        pendingPackageExport = nil
    }

    func confirmPendingPackageExport() async {
        guard let pendingPackageExport,
              let team = state.teams.first(where: { $0.id == pendingPackageExport.teamID }) else {
            return
        }
        await busy(operationName: "Package export") {
            self.exportURL = try self.packageService.export(team: team, state: self.state)
            self.pendingPackageExport = nil
        }
    }

    func importPackage(from url: URL) async {
        await performPackageImport(from: url, opensOnboardingHandoff: false)
    }

    func importPackageFromOnboarding(from url: URL) async {
        await performPackageImport(from: url, opensOnboardingHandoff: true)
    }

    func preparePackageImportConfirmation(from url: URL, opensOnboardingHandoff: Bool) async {
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
            let preview = try packageService.previewDetails(packageURL: url)
            pendingPackageImport = PendingPackageImport(
                url: url,
                manifest: preview.manifest,
                transferSummary: preview.summary,
                opensOnboardingHandoff: opensOnboardingHandoff
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func confirmPendingPackageImport() async {
        guard let pendingPackageImport else { return }
        await performPackageImport(
            from: pendingPackageImport.url,
            opensOnboardingHandoff: pendingPackageImport.opensOnboardingHandoff
        )
        await preparePendingIncomingPackageIfNeeded()
    }

    func cancelPendingPackageImport() {
        pendingPackageImport = nil
        Task { await self.preparePendingIncomingPackageIfNeeded() }
    }

    private func performPackageImport(from url: URL, opensOnboardingHandoff: Bool) async {
        await busy(operationName: "Package import") {
            self.pendingPackageImport = nil
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
            _ = try self.packageService.preview(packageURL: url)
            try await self.createBackupBeforeRiskyOperation(reason: "Automatic backup before package import")
            let musicAuthorizationStatus = MusicAuthorization.currentStatus
            let appleMusicPlaybackCapability = await self.appleMusicPlaybackCapabilityForAudit(
                musicAuthorizationStatus: musicAuthorizationStatus
            )
            let importResult = try self.packageService.importWithAudit(
                packageURL: url,
                audioAssetService: self.audioAssetService,
                musicAuthorizationStatus: musicAuthorizationStatus,
                appleMusicPlaybackCapability: appleMusicPlaybackCapability
            )
            var imported = importResult.manifest.team
            imported.id = UUID()
            imported.name += " Imported"
            let originalImportedTeamID = importResult.manifest.team.id
            self.state.teams.append(imported)
            self.setSelectedTeamID(imported.id)
            self.normalizeLineup(for: self.state.teams.count - 1)
            if opensOnboardingHandoff {
                self.state.onboarding = OnboardingState(
                    completedAt: nil,
                    activeFlow: .importHandoff,
                    activeTeamID: imported.id,
                    didChooseCheerFallback: false,
                    didSeeLineup: false,
                    importHandoffTeamID: imported.id
                )
            }
            self.completedPackageImportTeamID = imported.id
            self.completedPackageImportAudit = importResult.audit.retargeted(
                from: originalImportedTeamID,
                to: imported.id,
                teamName: imported.name
            )
            self.persist()
            let hadMissingMedia = importResult.audit.summary.hasDeviceDependentClips || importResult.audit.summary.hasUnresolvedClips
            self.telemetry.recordPackageImportCompleted(hadMissingMedia: hadMissingMedia)
            if hadMissingMedia {
                self.telemetry.recordRepairNeeded(category: "importedPackageMedia")
            }
            self.telemetry.recordRosterMilestones(for: self.state)
            if opensOnboardingHandoff {
                self.telemetry.recordOnce(.onboardingImportPathUsed)
            }
            for teamClip in imported.teamClips {
                self.scheduleTeamClipPreparation(
                    teamID: imported.id,
                    teamClipID: teamClip.id,
                    trigger: .importRepair
                )
            }
            for player in imported.players {
                if player.songAssignment?.privateClip != nil {
                    self.scheduleSongClipPreparation(
                        teamID: imported.id,
                        playerID: player.id,
                        trigger: .importRepair
                    )
                }
            }
        }
    }

    func prepareRosterImport(from url: URL) async {
        await busy(operationName: "Roster CSV import") {
            guard let targetTeamID = self.state.selectedTeamID,
                  self.state.teams.contains(where: { $0.id == targetTeamID }) else {
                throw AppError.noSelectedTeam
            }
            let rows = try await self.packageService.parseRosterCSV(from: url)
            self.pendingRosterImport = PendingRosterImport(
                sourceName: url.lastPathComponent,
                rows: rows.map {
                    Player(
                        id: UUID(),
                        displayName: $0.name,
                        uniformNumber: $0.number,
                        pronunciationOverride: "",
                        photoRelativePath: nil,
                        cue: nil,
                        isPresent: true
                    )
                },
                targetTeamID: targetTeamID
            )
        }
    }

    func applyPendingRosterImport() async {
        guard let pendingRosterImport else {
            lastError = "This roster import is no longer associated with a team. Choose the CSV again."
            return
        }
        let targetTeamID = pendingRosterImport.targetTeamID
        await busy(operationName: "Roster CSV apply") {
            guard let teamIndex = self.state.teams.firstIndex(where: { $0.id == targetTeamID }) else {
                throw AppError.noSelectedTeam
            }
            let importedRowCount = pendingRosterImport.rows.count
            try await self.createBackupBeforeRiskyOperation(reason: "Automatic backup before roster CSV import")
            self.state.teams[teamIndex].players.append(contentsOf: pendingRosterImport.rows)
            self.state.teams[teamIndex].session.battingOrder.append(contentsOf: pendingRosterImport.rows.map(\.id))
            self.state.teams[teamIndex].modifiedAt = .now
            self.normalizeLineup(for: teamIndex)
            self.pendingRosterImport = nil
            self.prewarmNextBatterCue()
            self.scheduleReadinessRefresh()
            self.persist()
            self.telemetry.recordRosterMilestones(for: self.state)
            let bucket: String
            switch importedRowCount {
            case 1...5: bucket = "1-5"
            case 6...10: bucket = "6-10"
            case 11...20: bucket = "11-20"
            default: bucket = "21+"
            }
            self.telemetry.recordOnce(.csvImportFirstUsed, properties: [.rowCountBucket: bucket])
        }
    }

    func discardPendingRosterImport() {
        pendingRosterImport = nil
    }

    func refreshReadiness() {
        state.lastReadiness = readinessService.snapshot(for: selectedTeam)
    }

    func recordReadinessOpened() {
        telemetry.recordOnce(.readinessFirstOpened)
        guard let checks = selectedTeamReadiness?.checks else { return }
        for check in checks where check.state == .issue {
            switch check.category {
            case .playerAudio:
                telemetry.recordRepairNeeded(category: "playerMedia")
            case .playerAnnouncement:
                telemetry.recordRepairNeeded(category: "announcement")
            case .appleMusicAccess:
                telemetry.recordRepairNeeded(category: "appleMusicAccess")
            case .audioRoute, .volume, .network, .lineup, .playerPhoto:
                break
            }
        }
    }

    private func repairCategories(for player: Player, in team: Team) -> Set<String> {
        var categories = Set<String>()
        let checks = readinessService.snapshot(for: team).checks
        for check in checks where check.playerID == player.id && check.state == .issue {
            switch check.category {
            case .playerAudio:
                categories.insert("playerMedia")
            case .playerAnnouncement:
                categories.insert("announcement")
            case .appleMusicAccess, .playerPhoto, .audioRoute, .volume, .network, .lineup:
                break
            }
        }
        return categories
    }

    var needsAppleMusicAccessPrompt: Bool {
        MusicAuthorization.currentStatus == .notDetermined
    }

    @discardableResult
    func requestAppleMusicAccess() async -> MusicAuthorization.Status {
        if selectedTeamReadiness?.checks.contains(where: { $0.category == .appleMusicAccess && $0.state == .issue }) == true {
            telemetry.recordRepairNeeded(category: "appleMusicAccess")
            telemetry.recordRepairAttempted(category: "appleMusicAccess")
        }
        let status = await MusicAuthorization.request()
        await refreshAppleMusicPlaybackCapability()
        refreshReadiness()
        scheduleAllSongClipPreparation(trigger: .authorizationChanged)
        switch status {
        case .denied, .restricted:
            telemetry.recordOnce(.musicAccessDenied, properties: [.result: status == .denied ? "denied" : "restricted"])
        case .authorized:
            telemetry.recordRepairCompleted(category: "appleMusicAccess")
        default:
            break
        }
        return status
    }

    func checkAppleMusicForCompletedPackageImport() async {
        guard let audit = completedPackageImportAudit,
              let team = state.teams.first(where: { $0.id == audit.teamID }) else {
            return
        }
        let status: MusicAuthorization.Status
        if MusicAuthorization.currentStatus == .notDetermined {
            status = await requestAppleMusicAccess()
        } else {
            status = MusicAuthorization.currentStatus
        }
        let capability = await appleMusicPlaybackCapabilityForAudit(musicAuthorizationStatus: status)
        completedPackageImportAudit = packageService.importAudit(
            for: team,
            musicAuthorizationStatus: status,
            appleMusicPlaybackCapability: capability
        )
    }

    private func appleMusicPlaybackCapabilityForAudit(
        musicAuthorizationStatus: MusicAuthorization.Status
    ) async -> AppleMusicPlaybackCapability {
        guard musicAuthorizationStatus == .authorized else { return .unknown }
        let capability = await musicCatalogService.playbackCapability()
        appleMusicPlaybackCapability = capability
        return capability
    }

    func createBackup(reason: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.createBackupAndWait(reason: reason)
            } catch {
                self.telemetry.record(.backupFailed)
                self.lastError = error.localizedDescription
            }
        }
    }

    func createBackupAndWait(reason: String) async throws {
        let snapshotState = backupSnapshotState(from: state)
        let snapshotRecord = try await writeBackupRecord(for: snapshotState, reason: reason).get()
        insertBackupRecord(snapshotRecord)
        persist()
        if reason == "Manual backup" {
            telemetry.recordOnce(.backupManualCreated)
        }
    }

    private func createBackupBeforeRiskyOperation(reason: String) async throws {
        let snapshotState = backupSnapshotState(from: state)
        let snapshotRecord = try await writeBackupRecord(for: snapshotState, reason: reason).get()
        insertBackupRecord(snapshotRecord)
        persist()
    }

    func refreshRecoveryState() {
        if purgeExpiredRecentlyDeletedItems() {
            persist()
        }
    }

    private func writeBackupRecord(for snapshotState: AppState, reason: String) async -> Result<SnapshotRecord, Error> {
        await Task.detached(priority: .utility) { () -> Result<SnapshotRecord, Error> in
            guard let snapshotsDirectory = try? AppPaths.snapshotsDirectory() else {
                return .failure(AppError.invalidImport)
            }
            let name = "\(UUID().uuidString).json"
            let destination = snapshotsDirectory.appendingPathComponent(name)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            do {
                try encoder.encode(snapshotState).write(to: destination, options: .atomic)
                return .success(
                    SnapshotRecord(
                        id: UUID(),
                        createdAt: .now,
                        reason: reason,
                        relativeManifestPath: name
                    )
                )
            } catch {
                return .failure(error)
            }
        }.value
    }

    private func insertBackupRecord(_ snapshotRecord: SnapshotRecord) {
        state.snapshots.insert(snapshotRecord, at: 0)
        let overflow = Array(state.snapshots.dropFirst(10))
        state.snapshots = Array(state.snapshots.prefix(10))
        pruneBackupFiles(for: overflow)
    }

    private func pruneBackupFiles(for snapshots: [SnapshotRecord]) {
        guard !snapshots.isEmpty else { return }
        Task.detached(priority: .utility) {
            guard let snapshotsDirectory = try? AppPaths.snapshotsDirectory() else { return }
            for snapshot in snapshots {
                let url = snapshotsDirectory.appendingPathComponent(snapshot.relativeManifestPath)
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    func restoreBackup(_ snapshot: SnapshotRecord) async {
        await busy(operationName: "Backup restore") {
            guard let snapshotsDirectory = try? AppPaths.snapshotsDirectory() else {
                throw AppError.invalidImport
            }
            let preRestoreBackup = try await self.writeBackupRecord(
                for: self.state,
                reason: "Automatic backup before restore"
            ).get()
            let sourceURL = snapshotsDirectory.appendingPathComponent(snapshot.relativeManifestPath)
            let currentVersion = self.state.appVersion
            let currentDeviceIdentity = self.state.deviceIdentity
            let currentSettings = self.state.settings
            let currentLastSeenWhatsNewReleaseID = self.state.lastSeenWhatsNewReleaseID
            let currentSchemaVersion = self.state.schemaVersion
            let currentRecentlyDeleted = self.state.recentlyDeleted
            let currentSnapshots = self.state.snapshots

            let restoredState = try await Task.detached(priority: .utility) { () -> AppState in
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                var restoredState = try decoder.decode(AppState.self, from: Data(contentsOf: sourceURL))
                restoredState.appVersion = currentVersion
                restoredState.deviceIdentity = currentDeviceIdentity
                restoredState.settings = currentSettings
                restoredState.lastSeenWhatsNewReleaseID = currentLastSeenWhatsNewReleaseID
                restoredState.schemaVersion = max(restoredState.schemaVersion, currentSchemaVersion)
                restoredState.recentlyDeleted = currentRecentlyDeleted
                restoredState.snapshots = currentSnapshots
                return restoredState
            }.value

            self.state = restoredState
            self.telemetry.handleTeamBoundaryChange()
            self.insertBackupRecord(preRestoreBackup)
            self.normalizeSelectedTeamIfNeeded()
            self.normalizeAllTeams()
            self.scheduleReadinessRefresh()
            self.persist()
            self.telemetry.recordOnce(.backupRestored)
            self.telemetry.recordRosterMilestones(for: self.state)
        }
    }

    func restorePreparation(for item: RecentlyDeletedItem) -> RestorePreparation {
        switch item.payload {
        case .team(let deletedTeam):
            let missingSummary = missingMediaSummary(for: deletedTeam.team)
            guard !missingSummary.hasMissingMedia else { return .partialPrompt(teamPartialPrompt(for: item, team: deletedTeam.team, summary: missingSummary)) }
            return .ready
        case .player(let deletedPlayer):
            guard state.teams.contains(where: { $0.id == deletedPlayer.originalTeamID }) else {
                return .blocked("Restore the team first to bring this player back.")
            }
            let missingTypes = missingMediaTypes(for: deletedPlayer.player)
            guard !missingTypes.isEmpty else { return .ready }
            return .partialPrompt(playerPartialPrompt(for: item, player: deletedPlayer.player, missingTypes: missingTypes))
        case .customClip(let deletedClip):
            guard state.teams.contains(where: { $0.id == deletedClip.originalTeamID }) else {
                return .blocked("Restore the team first to bring this Custom Clip back.")
            }
            guard !cueIsPlayable(deletedClip.clip.playbackCue) else { return .ready }
            return .partialPrompt(customClipPartialPrompt(for: item, clip: deletedClip.clip))
        }
    }

    func restoreRecentlyDeletedItem(
        _ item: RecentlyDeletedItem,
        allowPartial: Bool = false,
        markRestoredPlayerPresent: Bool = false
    ) {
        switch item.payload {
        case .team(let deletedTeam):
            let summary = missingMediaSummary(for: deletedTeam.team)
            if summary.hasMissingMedia && !allowPartial {
                lastError = "Roll Call could not fully restore \(deletedTeam.team.name). Choose Restore What We Can to bring back the team without the missing media."
                return
            }
            restoreDeletedTeam(item, deletedTeam: deletedTeam, partialSummary: summary.hasMissingMedia ? summary : nil)
        case .player(let deletedPlayer):
            guard state.teams.contains(where: { $0.id == deletedPlayer.originalTeamID }) else {
                lastError = "Restore the team first to bring this player back."
                return
            }
            let missingTypes = missingMediaTypes(for: deletedPlayer.player)
            if !missingTypes.isEmpty && !allowPartial {
                lastError = "Roll Call could not fully restore \(deletedPlayer.player.displayName). Choose Restore What We Can to bring back the player without the missing media."
                return
            }
            restoreDeletedPlayer(
                item,
                deletedPlayer: deletedPlayer,
                missingTypes: missingTypes,
                markPresent: markRestoredPlayerPresent
            )
        case .customClip(let deletedClip):
            guard state.teams.contains(where: { $0.id == deletedClip.originalTeamID }) else {
                lastError = "Restore the team first to bring this Custom Clip back."
                return
            }
            let isMissingMedia = !cueIsPlayable(deletedClip.clip.playbackCue)
            if isMissingMedia && !allowPartial {
                lastError = "Roll Call could not fully restore this Custom Clip. Choose Restore What We Can to keep its place and repair it afterward."
                return
            }
            restoreDeletedCustomClip(item, deletedClip: deletedClip, isMissingMedia: isMissingMedia)
        }
        telemetry.recordOnce(.recentlyDeletedRestored)
    }

    func permanentlyDeleteRecentlyDeletedItem(_ item: RecentlyDeletedItem) {
        guard let itemIndex = state.recentlyDeleted.firstIndex(where: { $0.id == item.id }) else { return }
        state.recentlyDeleted.remove(at: itemIndex)
        removeStoredAssetsForDeletedItemIfUnreferenced(item)
        persist()
    }

    func recoveryTeamName(for deletedPlayer: DeletedPlayerRecord) -> String {
        state.teams.first(where: { $0.id == deletedPlayer.originalTeamID })?.name ?? deletedPlayer.originalTeamName
    }

    func recoveryTeamName(for deletedClip: DeletedCustomClipRecord) -> String {
        state.teams.first(where: { $0.id == deletedClip.originalTeamID })?.name ?? deletedClip.originalTeamName
    }

    func exportSupportBundle() async {
        await busy(operationName: "Support bundle export") {
            await self.refreshGeneratedClipCleanupReport()
            let url = try self.packageService.exportSupportBundle(
                state: self.state,
                selectedTeam: self.selectedTeam,
                diagnostics: self.playbackEngine.supportDiagnostics(),
                generatedClipCleanup: self.generatedClipCleanupReport
            )
            self.supportBundle = SupportBundleExport(url: url)
        }
    }

    func refreshGeneratedClipCleanupReport() async {
        let activeCount = await songClipPreparationCoordinator.pendingCount()
        generatedClipCleanupReport = await runGeneratedClipCleanup(
            activePreparationCount: activeCount,
            shouldRemoveOrphans: false
        )
    }

    func cleanGeneratedClipsNow() async {
        let activeCount = await songClipPreparationCoordinator.pendingCount()
        generatedClipCleanupReport = await runGeneratedClipCleanup(
            activePreparationCount: activeCount,
            shouldRemoveOrphans: true
        )
    }

    private func runAutomaticGeneratedClipCleanup() async {
        let activeCount = await songClipPreparationCoordinator.pendingCount()
        generatedClipCleanupReport = await runGeneratedClipCleanup(
            activePreparationCount: activeCount,
            shouldRemoveOrphans: true
        )
    }

    private func runGeneratedClipCleanup(
        activePreparationCount: Int,
        shouldRemoveOrphans: Bool
    ) async -> GeneratedClipCleanupReport {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let stateData = try? encoder.encode(state) else {
            return blockedGeneratedClipCleanupReport()
        }

        return await Task.detached(priority: .utility) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            guard let decodedState = try? decoder.decode(AppState.self, from: stateData) else {
                return Self.blockedGeneratedClipCleanupReport()
            }

            let service = GeneratedClipCleanupService()
            if shouldRemoveOrphans {
                return service.clean(
                    state: decodedState,
                    activePreparationCount: activePreparationCount
                )
            }
            return service.audit(
                state: decodedState,
                activePreparationCount: activePreparationCount
            )
        }.value
    }

    nonisolated private static func blockedGeneratedClipCleanupReport() -> GeneratedClipCleanupReport {
        GeneratedClipCleanupReport(
            discoveredFileCount: 0,
            discoveredByteCount: 0,
            referencedFileCount: 0,
            orphanedFileCount: 0,
            orphanedByteCount: 0,
            removedFileCount: 0,
            removedByteCount: 0,
            retainedUncertainFileCount: 0,
            blockedReason: "Cleanup was skipped because the current app state could not be inspected safely."
        )
    }

    private func blockedGeneratedClipCleanupReport() -> GeneratedClipCleanupReport {
        Self.blockedGeneratedClipCleanupReport()
    }

    var selectedTeamPresentPlayers: [Player] {
        selectedTeam?.presentPlayersInBattingOrder ?? []
    }

    var selectedTeamBuiltInClips: [BuiltInClip] {
        selectedTeam?.builtInClips ?? []
    }

    var selectedTeamCustomClips: [SongClip] {
        selectedTeam?.teamClips ?? []
    }

    private func playableCueForPlayerPlayback(_ player: Player) -> Cue? {
        if let cue = resolvedCue(for: player) {
            return cue
        }
        return fallbackCue(for: player, cueID: playbackID(for: player))
    }

    private func fallbackCue(for player: Player, cueID: UUID? = nil) -> Cue? {
        let teamBuiltIns = selectedTeam?.builtInClips ?? []
        if let fallbackClip = BuiltInClip.firstMatchingSourceID(defaultNoSongFallbackBuiltInClipSourceID, in: teamBuiltIns) {
            var cue = fallbackClip.cue
            cue.id = cueID ?? player.id
            if cueIsPlayable(cue) {
                return cue
            }
        }
        if let fallbackClip = BuiltInClip.firstMatchingSourceID(defaultNoSongFallbackBuiltInClipSourceID, in: BuiltInClip.defaults) {
            var cue = fallbackClip.cue
            cue.id = cueID ?? player.id
            if cueIsPlayable(cue) {
                return cue
            }
        }
        return nil
    }

    func fallbackCueAfterPlaybackFailure(for player: Player, failedCue: Cue) -> Cue? {
        guard case .builtInClip = failedCue.source else {
            return fallbackCue(for: player, cueID: failedCue.id)
        }
        return nil
    }

    private func fallbackCueAfterPlaybackFailure(for player: Player, plan: PlayerPlaybackPlan) -> Cue? {
        switch plan {
        case .cue(let cue, _, _):
            return fallbackCueAfterPlaybackFailure(for: player, failedCue: cue)
        case .assetOnly:
            return fallbackCue(for: player, cueID: playbackID(for: player))
        }
    }

    private func cueIsPlayable(_ cue: Cue) -> Bool {
        switch cue.source {
        case .appleMusic:
            return true
        case .localAudio(let source):
            return audioAssetService.assetExists(relativePath: source.relativePath)
        case .builtInClip(let source):
            return audioAssetService.builtInClipExists(source: source)
        }
    }

    func playerWillUseFallback(for player: Player) -> Bool {
        switch selectedTeam?.session.gameDayAnnouncerMode ?? .announcerAndSong {
        case .announcerOnly:
            return !hasStoredCustomAnnouncer(for: player)
        case .announcerAndSong, .songOnly:
            guard let cue = resolvedCue(for: player) else { return true }
            return !cueIsPlayable(cue)
        }
    }

    func isPlayingFallback(for player: Player) -> Bool {
        activeFallbackPlayerID == player.id && playbackEngine.activeCueID == playbackID(for: player)
    }

    private func playbackPlan(for player: Player) -> PlayerPlaybackPlan? {
        let mode = selectedTeam?.session.gameDayAnnouncerMode ?? .announcerAndSong
        let announcerRelativePath = storedCustomAnnouncerRelativePath(for: player)
        switch mode {
        case .announcerOnly:
            if let announcerRelativePath {
                return .assetOnly(relativePath: announcerRelativePath, activeCueID: playbackID(for: player))
            }
            guard let fallbackCue = fallbackCue(for: player, cueID: playbackID(for: player)) else { return nil }
            return .cue(cue: fallbackCue, announcerRelativePath: nil, sourceFamily: .builtinIntentional)
        case .announcerAndSong:
            guard let cue = playableCueForPlayerPlayback(player) else { return nil }
            return .cue(cue: cue, announcerRelativePath: announcerRelativePath, sourceFamily: playerPlaybackSourceFamily(player: player, cue: cue))
        case .songOnly:
            guard let cue = playableCueForPlayerPlayback(player) else { return nil }
            return .cue(cue: cue, announcerRelativePath: nil, sourceFamily: playerPlaybackSourceFamily(player: player, cue: cue))
        }
    }

    private func playbackID(for player: Player) -> UUID {
        resolvedCue(for: player)?.id ?? player.id
    }

    private var teamIndex: Int? {
        state.teams.firstIndex(where: { $0.id == state.selectedTeamID })
    }

    private func normalizeSelectedTeamIfNeeded() {
        if let selectedTeamID = state.selectedTeamID,
           state.teams.contains(where: { $0.id == selectedTeamID }) {
            return
        }
        setSelectedTeamID(state.teams.first?.id)
    }

    private func setSelectedTeamID(_ teamID: UUID?) {
        guard state.selectedTeamID != teamID else { return }
        telemetry.handleTeamBoundaryChange()
        state.selectedTeamID = teamID
    }

    private func normalizeAllTeams() {
        for index in state.teams.indices {
            normalizeLineup(for: index)
        }
        flattenLegacyRecentlyDeletedAssignments()
    }

    private func flattenLegacyRecentlyDeletedAssignments() {
        for itemIndex in state.recentlyDeleted.indices {
            guard case .player(var deletedPlayer) = state.recentlyDeleted[itemIndex].payload,
                  let legacyClipID = deletedPlayer.player.songAssignment?.legacySharedTeamClipID,
                  let team = state.teams.first(where: { $0.id == deletedPlayer.originalTeamID }),
                  let clip = team.teamClips.first(where: { $0.id == legacyClipID }) else {
                continue
            }
            deletedPlayer.player.migrateLegacySharedTeamClip(using: clip)
            state.recentlyDeleted[itemIndex].payload = .player(deletedPlayer)
        }
    }

    private func normalizeLineup(for teamIndex: Int) {
        let players = state.teams[teamIndex].players
        let ids = Set(players.map(\.id))
        let existingOrder = state.teams[teamIndex].session.battingOrder.filter { ids.contains($0) }
        if state.teams[teamIndex].session.battingOrderIsCustomized {
            let missingOrder = players.map(\.id).filter { !existingOrder.contains($0) }
            state.teams[teamIndex].session.battingOrder = existingOrder + missingOrder
        } else {
            state.teams[teamIndex].session.battingOrder = alphabeticalBattingOrder(for: players)
        }
        let presentCount = state.teams[teamIndex].presentPlayersInBattingOrder.count
        state.teams[teamIndex].session.nextBatterIndex = presentCount == 0 ? 0 : min(max(state.teams[teamIndex].session.nextBatterIndex, 0), presentCount - 1)
    }

    private func removeStoredAssetsIfUnreferenced(for player: Player) {
        storedAssetRelativePaths(for: player).forEach(removeAssetIfUnreferenced(relativePath:))
    }

    private func removeAssetsNoLongerReferenced(from previousPlayer: Player, to updatedPlayer: Player) {
        let updatedPaths = Set(storedAssetRelativePaths(for: updatedPlayer))
        storedAssetRelativePaths(for: previousPlayer)
            .filter { !updatedPaths.contains($0) }
            .forEach(removeAssetIfUnreferenced(relativePath:))
    }

    func applyGeneratedBuiltInAnnouncerAsset(
        _ asset: GeneratedAnnouncerAsset?,
        toPlayerID playerID: UUID,
        onTeamID teamID: UUID
    ) {
        guard let teamIndex = state.teams.firstIndex(where: { $0.id == teamID }),
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }) else {
            return
        }

        let previousPlayer = state.teams[teamIndex].players[playerIndex]
        state.teams[teamIndex].players[playerIndex].generatedBuiltInAnnouncerRelativePath = asset?.relativePath
        let updatedPlayer = state.teams[teamIndex].players[playerIndex]

        if let asset {
            state.teams[teamIndex].announcerProfile.applyResolvedVoice(from: asset)
        }

        state.teams[teamIndex].modifiedAt = .now
        removeAssetsNoLongerReferenced(from: previousPlayer, to: updatedPlayer)
    }

    private func removeAssetIfUnreferenced(relativePath: String) {
        guard !assetIsReferenced(relativePath: relativePath) else { return }
        guard !assetIsReferencedByBackupSnapshot(relativePath: relativePath) else { return }
        pendingAssetCleanupPaths.insert(relativePath)
    }

    func discardUncommittedAsset(relativePath: String) {
        removeAssetIfUnreferenced(relativePath: relativePath)
        persist()
    }

    private func removePersistedAssetIfStillUnreferenced(relativePath: String) {
        guard !assetIsReferenced(relativePath: relativePath) else { return }
        guard !assetIsReferencedByBackupSnapshot(relativePath: relativePath) else { return }
        audioAssetService.removeAsset(relativePath: relativePath)
    }

    private func assetIsReferenced(relativePath: String?, byAnyPlayerOtherThan ignoredPlayerID: UUID? = nil) -> Bool {
        guard let relativePath else { return false }
        if state.teams.contains(where: { team in
            team.players.contains { player in
                guard player.id != ignoredPlayerID else { return false }
                return storedAssetRelativePaths(for: player).contains(relativePath)
            }
        }) {
            return true
        }
        if state.teams.contains(where: { team in
            team.teamClips.contains { storedAssetRelativePaths(for: $0).contains(relativePath) }
        }) {
            return true
        }
        return state.recentlyDeleted.contains { item in
            storedAssetRelativePaths(for: item).contains(relativePath)
        }
    }

    private func assetIsReferencedByBackupSnapshot(relativePath: String) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for snapshot in state.snapshots {
            do {
                let snapshotURL = try backupSnapshotURL(for: snapshot)
                let snapshotState = try decoder.decode(AppState.self, from: Data(contentsOf: snapshotURL))
                if snapshotState.teams.contains(where: { storedAssetRelativePaths(for: $0).contains(relativePath) }) {
                    return true
                }
            } catch {
                return true
            }
        }
        return false
    }

    private func backupSnapshotURL(for snapshot: SnapshotRecord) throws -> URL {
        let fileName = snapshot.relativeManifestPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileName.isEmpty,
              fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              !fileName.hasPrefix("."),
              !fileName.contains("/"),
              !fileName.contains("\\") else {
            throw AppError.invalidImport
        }
        return try AppPaths.snapshotsDirectory().appendingPathComponent(fileName)
    }

    private func storedAssetRelativePaths(for player: Player) -> [String] {
        var paths: [String] = []
        if let photoRelativePath = player.photoRelativePath {
            paths.append(photoRelativePath)
        }
        if let photoSourceRelativePath = player.photoSourceRelativePath {
            paths.append(photoSourceRelativePath)
        }
        if let customAnnouncerRelativePath = player.customAnnouncerRelativePath {
            paths.append(customAnnouncerRelativePath)
        }
        if let generatedBuiltInAnnouncerRelativePath = player.generatedBuiltInAnnouncerRelativePath {
            paths.append(generatedBuiltInAnnouncerRelativePath)
        }
        if case .localAudio(let source)? = player.cue?.source {
            paths.append(source.relativePath)
        }
        if let generatedRelativePath = player.songAssignment?.privateClip?.generatedAsset.relativePath {
            paths.append(generatedRelativePath)
        }
        return paths
    }

    private func storedAssetRelativePaths(for team: Team) -> [String] {
        team.players.flatMap(storedAssetRelativePaths(for:))
            + team.teamClips.flatMap(storedAssetRelativePaths(for:))
    }

    private func storedAssetRelativePaths(for clip: SongClip) -> [String] {
        var paths: [String] = []
        if case .localAudio(let source) = clip.originalSource.cueSource {
            paths.append(source.relativePath)
        }
        if let generatedPath = clip.generatedAsset.relativePath {
            paths.append(generatedPath)
        }
        return paths
    }

    private func storedAssetRelativePaths(for item: RecentlyDeletedItem) -> [String] {
        switch item.payload {
        case .team(let deletedTeam):
            return storedAssetRelativePaths(for: deletedTeam.team)
        case .player(let deletedPlayer):
            return storedAssetRelativePaths(for: deletedPlayer.player)
        case .customClip(let deletedClip):
            return storedAssetRelativePaths(for: deletedClip.clip)
        }
    }

    private func addRecentlyDeletedItem(_ item: RecentlyDeletedItem) {
        _ = purgeExpiredRecentlyDeletedItems()
        state.recentlyDeleted.insert(item, at: 0)
    }

    @discardableResult
    private func purgeExpiredRecentlyDeletedItems(now: Date = .now) -> Bool {
        let expiredItems = state.recentlyDeleted.filter { $0.expiresAt <= now }
        guard !expiredItems.isEmpty else { return false }
        state.recentlyDeleted.removeAll { $0.expiresAt <= now }
        expiredItems.forEach(removeStoredAssetsForDeletedItemIfUnreferenced)
        return true
    }

    private func backupSnapshotState(from state: AppState) -> AppState {
        var snapshotState = state
        snapshotState.recentlyDeleted = []
        snapshotState.snapshots = []
        return snapshotState
    }

    private func removeStoredAssetsForDeletedItemIfUnreferenced(_ item: RecentlyDeletedItem) {
        storedAssetRelativePaths(for: item).forEach(removeAssetIfUnreferenced(relativePath:))
    }

    private enum MissingMediaType: String {
        case song = "song"
        case photo = "photo"
        case photoSource = "full photo source"
        case announcementCue = "Announcement Cue"
    }

    private struct MissingMediaSummary {
        var songCount = 0
        var photoCount = 0
        var announcementCueCount = 0
        var customClipCount = 0

        var hasMissingMedia: Bool {
            songCount > 0 || photoCount > 0 || announcementCueCount > 0 || customClipCount > 0
        }

        var warningText: String {
            var segments: [String] = []
            if songCount > 0 {
                segments.append("\(songCount) \(songCount == 1 ? "player is" : "players are") missing song audio")
            }
            if photoCount > 0 {
                segments.append("\(photoCount) \(photoCount == 1 ? "player photo could" : "player photos could") not be recovered")
            }
            if announcementCueCount > 0 {
                segments.append("\(announcementCueCount) \(announcementCueCount == 1 ? "Announcement Cue is" : "Announcement Cues are") missing")
            }
            if customClipCount > 0 {
                segments.append("\(customClipCount) \(customClipCount == 1 ? "Custom Clip is" : "Custom Clips are") missing audio")
            }
            guard let first = segments.first else { return "" }
            if segments.count == 1 {
                return first
            }
            if segments.count == 2 {
                return "\(first), and \(segments[1])"
            }
            return "\(segments[0]), \(segments[1]), and \(segments[2])"
        }
    }

    private func missingMediaTypes(for player: Player) -> [MissingMediaType] {
        var types: [MissingMediaType] = []
        if let photoRelativePath = player.photoRelativePath,
           !audioAssetService.assetExists(relativePath: photoRelativePath) {
            types.append(.photo)
        }
        if let photoSourceRelativePath = player.photoSourceRelativePath,
           !audioAssetService.assetExists(relativePath: photoSourceRelativePath) {
            types.append(.photoSource)
        }
        if let customAnnouncerRelativePath = player.customAnnouncerRelativePath,
           !audioAssetService.assetExists(relativePath: customAnnouncerRelativePath) {
            types.append(.announcementCue)
        }
        if case .localAudio(let source)? = player.cue?.source,
           !audioAssetService.assetExists(relativePath: source.relativePath) {
            types.append(.song)
        }
        return types
    }

    private func missingMediaSummary(for team: Team) -> MissingMediaSummary {
        var summary = team.players.reduce(into: MissingMediaSummary()) { summary, player in
            let missingTypes = missingMediaTypes(for: player)
            if missingTypes.contains(.song) {
                summary.songCount += 1
            }
            if missingTypes.contains(.photo) || missingTypes.contains(.photoSource) {
                summary.photoCount += 1
            }
            if missingTypes.contains(.announcementCue) {
                summary.announcementCueCount += 1
            }
        }
        summary.customClipCount = team.teamClips.filter { !cueIsPlayable($0.playbackCue) }.count
        return summary
    }

    private func playerPartialPrompt(for item: RecentlyDeletedItem, player: Player, missingTypes: [MissingMediaType]) -> PartialRestorePrompt {
        PartialRestorePrompt(
            itemID: item.id,
            itemType: .player,
            title: "Restore What We Can?",
            message: "\(player.displayName) could not be fully restored because \(playerMissingSummaryText(missingTypes)) missing. You can still restore the player and re-add the missing media afterward."
        )
    }

    private func customClipPartialPrompt(for item: RecentlyDeletedItem, clip: SongClip) -> PartialRestorePrompt {
        PartialRestorePrompt(
            itemID: item.id,
            itemType: .customClip,
            title: "Restore What We Can?",
            message: "\(clip.displayName ?? clip.playbackCue.label) could not be fully restored because its audio is unavailable. You can still restore it in its saved position and repair it afterward."
        )
    }

    private func teamPartialPrompt(for item: RecentlyDeletedItem, team: Team, summary: MissingMediaSummary) -> PartialRestorePrompt {
        PartialRestorePrompt(
            itemID: item.id,
            itemType: .team,
            title: "Restore What We Can?",
            message: "\(team.name) could not be fully restored because \(summary.warningText). You can still restore the team and re-add the missing media afterward."
        )
    }

    private func playerMissingSummaryText(_ missingTypes: [MissingMediaType]) -> String {
        let names = missingTypes.map(\.rawValue)
        guard let first = names.first else { return "some media is" }
        if names.count == 1 {
            return "the \(first) is"
        }
        if names.count == 2 {
            return "the \(names[0]) and \(names[1]) are"
        }
        return "the \(names[0]), \(names[1]), and \(names[2]) are"
    }

    private func restoreDeletedTeam(_ item: RecentlyDeletedItem, deletedTeam: DeletedTeamRecord, partialSummary: MissingMediaSummary?) {
        var restoredTeam = deletedTeam.team
        restoredTeam.players = restoredTeam.players.map(degradingMissingPhotoSourceIfNeeded)
        restoredTeam.name = restoredTeamName(from: restoredTeam.name)
        restoredTeam.modifiedAt = .now
        state.teams.append(restoredTeam)
        setSelectedTeamID(restoredTeam.id)
        normalizeLineup(for: state.teams.count - 1)
        state.recentlyDeleted.removeAll { $0.id == item.id }
        scheduleReadinessRefresh()
        prewarmNextBatterCue()
        pendingRecoveryNavigation = .players
        if let partialSummary {
            showBanner("\(restoredTeam.name) restored, but \(partialSummary.warningText). Open players to re-add the missing media.", style: .warning)
        } else {
            showBanner("\(restoredTeam.name) restored.", style: .success)
        }
        persist()
    }

    private func restoreDeletedPlayer(
        _ item: RecentlyDeletedItem,
        deletedPlayer: DeletedPlayerRecord,
        missingTypes: [MissingMediaType],
        markPresent: Bool
    ) {
        guard let restoreTeamIndex = state.teams.firstIndex(where: { $0.id == deletedPlayer.originalTeamID }) else {
            lastError = "Restore the team first to bring this player back."
            return
        }

        var restoredPlayer = deletedPlayer.player
        restoredPlayer = degradingMissingPhotoSourceIfNeeded(restoredPlayer)
        if markPresent {
            restoredPlayer.isPresent = true
        }
        let insertionIndex = restoredPlayerInsertionIndex(
            previousBattingOrder: deletedPlayer.previousBattingOrder,
            playerID: restoredPlayer.id,
            currentBattingOrder: state.teams[restoreTeamIndex].session.battingOrder
        )

        let rosterInsertionIndex = min(insertionIndex, state.teams[restoreTeamIndex].players.count)
        state.teams[restoreTeamIndex].players.insert(restoredPlayer, at: rosterInsertionIndex)
        let battingOrderInsertionIndex = min(insertionIndex, state.teams[restoreTeamIndex].session.battingOrder.count)
        state.teams[restoreTeamIndex].session.battingOrder.insert(restoredPlayer.id, at: battingOrderInsertionIndex)
        state.teams[restoreTeamIndex].modifiedAt = .now
        setSelectedTeamID(state.teams[restoreTeamIndex].id)
        normalizeLineup(for: restoreTeamIndex)
        state.recentlyDeleted.removeAll { $0.id == item.id }
        scheduleReadinessRefresh()
        prewarmNextBatterCue()
        pendingRecoveryNavigation = .players
        if missingTypes.isEmpty {
            showBanner(
                markPresent ? "\(restoredPlayer.displayName) restored and marked present." : "\(restoredPlayer.displayName) restored.",
                style: .success
            )
        } else {
            showBanner("\(restoredPlayer.displayName) restored, but \(playerMissingSummaryText(missingTypes)) missing. Open the player to re-add it.", style: .warning)
        }
        persist()
    }

    private func degradingMissingPhotoSourceIfNeeded(_ player: Player) -> Player {
        guard let sourcePath = player.photoSourceRelativePath,
              !audioAssetService.assetExists(relativePath: sourcePath) else { return player }
        var degraded = player
        degraded.photoSourceRelativePath = nil
        degraded.profilePhotoCrop = nil
        degraded.playerCardPhotoCrop = nil
        return degraded
    }

    private func restoreDeletedCustomClip(
        _ item: RecentlyDeletedItem,
        deletedClip: DeletedCustomClipRecord,
        isMissingMedia: Bool
    ) {
        guard let restoreTeamIndex = state.teams.firstIndex(where: { $0.id == deletedClip.originalTeamID }) else {
            lastError = "Restore the team first to bring this Custom Clip back."
            return
        }
        let insertionIndex = min(max(deletedClip.previousIndex, 0), state.teams[restoreTeamIndex].teamClips.count)
        state.teams[restoreTeamIndex].teamClips.insert(deletedClip.clip, at: insertionIndex)
        state.teams[restoreTeamIndex].modifiedAt = .now
        setSelectedTeamID(state.teams[restoreTeamIndex].id)
        state.recentlyDeleted.removeAll { $0.id == item.id }
        scheduleTeamClipPreparation(
            teamID: state.teams[restoreTeamIndex].id,
            teamClipID: deletedClip.clip.id,
            trigger: .importRepair
        )
        scheduleReadinessRefresh()
        pendingRecoveryNavigation = .customClip(deletedClip.clip.id)
        let name = deletedClip.clip.displayName ?? deletedClip.clip.playbackCue.label
        if isMissingMedia {
            telemetry.recordRepairNeeded(category: "customClip")
        }
        showBanner(
            isMissingMedia ? "\(name) restored, but it still needs repair." : "\(name) restored.",
            style: isMissingMedia ? .warning : .success
        )
        persist()
    }

    private func restoredTeamName(from originalName: String) -> String {
        let activeNames = Set(state.teams.map(\.name))
        guard activeNames.contains(originalName) else { return originalName }

        let restoredBase = "\(originalName) (Restored)"
        guard activeNames.contains(restoredBase) else { return restoredBase }

        var suffix = 2
        while activeNames.contains("\(originalName) (Restored \(suffix))") {
            suffix += 1
        }
        return "\(originalName) (Restored \(suffix))"
    }

    private func restoredPlayerInsertionIndex(previousBattingOrder: [UUID], playerID: UUID, currentBattingOrder: [UUID]) -> Int {
        guard let deletedIndex = previousBattingOrder.firstIndex(of: playerID) else {
            return currentBattingOrder.count
        }

        for candidateID in previousBattingOrder[..<deletedIndex].reversed() {
            if let currentIndex = currentBattingOrder.firstIndex(of: candidateID) {
                return currentIndex + 1
            }
        }

        let successorStart = previousBattingOrder.index(after: deletedIndex)
        if successorStart < previousBattingOrder.endIndex {
            for candidateID in previousBattingOrder[successorStart...] {
                if let currentIndex = currentBattingOrder.firstIndex(of: candidateID) {
                    return currentIndex
                }
            }
        }

        return currentBattingOrder.count
    }

    private func showBanner(_ text: String, style: AppBannerMessage.Style) {
        let banner = AppBannerMessage(text: text, style: style)
        bannerDismissTask?.cancel()
        bannerMessage = banner
        bannerDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, self.bannerMessage?.id == banner.id else { return }
            self.bannerMessage = nil
        }
    }

    private func alphabeticalBattingOrder(for players: [Player]) -> [UUID] {
        alphabeticalPlayerIDs(for: players)
    }

    private func uniformNumberBattingOrder(for players: [Player]) -> [UUID] {
        players.sorted { lhs, rhs in
            let lhsNumber = Int(lhs.uniformNumber.trimmingCharacters(in: .whitespacesAndNewlines))
            let rhsNumber = Int(rhs.uniformNumber.trimmingCharacters(in: .whitespacesAndNewlines))
            switch (lhsNumber, rhsNumber) {
            case let (lhs?, rhs?) where lhs != rhs:
                return lhs < rhs
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                let lhsName = normalizedPlayerNameParts(lhs.displayName)
                let rhsName = normalizedPlayerNameParts(rhs.displayName)
                if lhsName.first != rhsName.first {
                    return lhsName.first.localizedCaseInsensitiveCompare(rhsName.first) == .orderedAscending
                }
                if lhsName.remainder != rhsName.remainder {
                    return lhsName.remainder.localizedCaseInsensitiveCompare(rhsName.remainder) == .orderedAscending
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        }
        .map(\.id)
    }

    private func prewarmNextBatterCue() {
        prewarmTask?.cancel()
        guard let nextCue = selectedTeam?.nextBatter?.cue else { return }
        prewarmTask = Task(priority: .utility) { [playbackEngine] in
            guard !Task.isCancelled else { return }
            try? await playbackEngine.prewarm(cue: nextCue)
        }
    }

    private func scheduleStartupGameDayWarmup() {
        startupWarmupTask?.cancel()
        let nextCue = selectedTeam?.nextBatter?.cue
        startupWarmupTask = Task(priority: .utility) { [playbackEngine] in
            guard !Task.isCancelled else { return }
            guard let nextCue, !Task.isCancelled else { return }
            try? await playbackEngine.prewarm(cue: nextCue)
        }
    }

    private func scheduleReadinessRefresh() {
        readinessRefreshTask?.cancel()
        readinessRefreshTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.refreshReadiness()
        }
    }

    private func observeReadinessInputs() {
        audioRouteChangeTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(named: AVAudioSession.routeChangeNotification)
            for await _ in notifications {
                await MainActor.run {
                    self?.scheduleReadinessRefresh()
                }
            }
        }

        outputVolumeObservation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.scheduleReadinessRefresh()
            }
        }
    }

    private func observeLowPowerMode() {
        let applyCurrentState: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            Task {
                let isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                await self.songClipPreparationCoordinator.setPaused(isLowPowerModeEnabled, reason: .lowPowerMode)
                if !isLowPowerModeEnabled {
                    await self.runSongClipPreparationQueueIfNeeded()
                }
                await self.refreshPendingSongClipPreparationCount()
            }
        }
        applyCurrentState()
        lowPowerModeTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .NSProcessInfoPowerStateDidChange
            )
            for await _ in notifications {
                await MainActor.run {
                    guard self != nil else { return }
                    applyCurrentState()
                }
            }
        }
    }

    private func scheduleAllSongClipPreparation(trigger: SongClipPreparationTrigger) {
        for team in state.teams {
            for teamClip in team.teamClips {
                scheduleTeamClipPreparation(
                    teamID: team.id,
                    teamClipID: teamClip.id,
                    trigger: trigger
                )
            }
            for player in team.players where player.songAssignment?.privateClip != nil {
                scheduleSongClipPreparation(teamID: team.id, playerID: player.id, trigger: trigger)
            }
        }
    }

    private func scheduleSongClipPreparation(
        teamID: UUID,
        playerID: UUID,
        trigger: SongClipPreparationTrigger,
        isExplicit: Bool = false
    ) {
        scheduleSongClipPreparation(
            teamID: teamID,
            target: .player(playerID),
            trigger: trigger,
            isExplicit: isExplicit
        )
    }

    private func scheduleTeamClipPreparation(
        teamID: UUID,
        teamClipID: UUID,
        trigger: SongClipPreparationTrigger,
        isExplicit: Bool = false
    ) {
        scheduleSongClipPreparation(
            teamID: teamID,
            target: .teamClip(teamClipID),
            trigger: trigger,
            isExplicit: isExplicit
        )
    }

    private func scheduleSongClipPreparation(
        teamID: UUID,
        target: SongClipPreparationRequest.Target,
        trigger: SongClipPreparationTrigger,
        isExplicit: Bool
    ) {
        guard var clip = songClip(teamID: teamID, target: target) else {
            return
        }

        let generationKey = clip.generationKey
        if !isExplicit,
           clip.generatedAsset.status == .ready,
           clip.generatedAsset.generationKey == generationKey {
            return
        }
        if !isExplicit,
           shouldSkipAutomaticSongClipPreparation(for: clip, generationKey: generationKey, trigger: trigger) {
            return
        }
        if !isExplicit,
           let nextRetryAt = clip.retryMetadata.nextRetryAt,
           nextRetryAt > .now {
            return
        }

        if clip.generatedAsset.status != .ready {
            clip.generatedAsset.status = .pending
            clip.generatedAsset.generationKey = generationKey
            updateSongClip(clip, teamID: teamID, target: target)
            persist()
        }

        let request = SongClipPreparationRequest(
            id: UUID(),
            teamID: teamID,
            target: target,
            clipID: clip.id,
            generationKey: generationKey,
            trigger: trigger,
            isExplicit: isExplicit
        )
        Task {
            await songClipPreparationCoordinator.enqueue(request)
            await refreshPendingSongClipPreparationCount()
            await runSongClipPreparationQueueIfNeeded()
        }
    }

    private func runSongClipPreparationQueueIfNeeded() async {
        await songClipPreparationCoordinator.runIfNeeded(
            clipFor: { [weak self] request in
                self?.songClip(matching: request)
            },
            waitForSlot: { [weak self] in
                await self?.waitForSongClipPreparationSlotIfNeeded() ?? false
            },
            applyOutcome: { [weak self] outcome, request in
                self?.applySongClipPreparationOutcome(outcome, request: request)
            }
        )
    }

    private func cancelSongClipPreparation(
        teamID: UUID,
        target: SongClipPreparationRequest.Target? = nil
    ) async {
        await songClipPreparationCoordinator.cancel(teamID: teamID, target: target)
        await refreshPendingSongClipPreparationCount()
    }

    private func shouldSkipAutomaticSongClipPreparation(
        for clip: SongClip,
        generationKey: String,
        trigger: SongClipPreparationTrigger
    ) -> Bool {
        guard clip.generatedAsset.generationKey == generationKey else { return false }

        switch clip.generatedAsset.status {
        case .none:
            switch clip.readinessInputs.playback {
            case .sourceBackedReady, .sourceBackedDownloaded:
                return trigger != .authorizationChanged
            default:
                return false
            }
        case .failedPermanent:
            return true
        case .failedRetryable:
            if clip.retryMetadata.lastFailureCode == SongClipPreparationFailureCode.musicAuthorizationRequired.rawValue,
               MusicAuthorization.currentStatus != .authorized,
               trigger != .authorizationChanged {
                return true
            }
            return clip.retryMetadata.attemptCount >= 3
                && trigger != .authorizationChanged
        case .pending, .ready:
            return false
        }
    }

    private func waitForSongClipPreparationSlotIfNeeded() async -> Bool {
        guard songClipPreparationLiveUseThrottled else { return true }

        while songClipPreparationLiveUseThrottled {
            guard !Task.isCancelled else { return false }
            guard playbackEngine.activeCueID == nil else {
                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return false
                }
                continue
            }

            do {
                try await Task.sleep(for: .milliseconds(700))
            } catch {
                return false
            }
            if playbackEngine.activeCueID == nil {
                return true
            }
        }
        return true
    }

    private func songClip(
        teamID: UUID,
        target: SongClipPreparationRequest.Target
    ) -> SongClip? {
        guard let team = state.teams.first(where: { $0.id == teamID }) else { return nil }
        switch target {
        case .player(let playerID):
            guard let player = team.players.first(where: { $0.id == playerID }),
                  case .privateClip(let clip)? = player.songAssignment else {
                return nil
            }
            return clip
        case .teamClip(let teamClipID):
            return team.teamClips.first(where: { $0.id == teamClipID })
        }
    }

    private func songClip(matching request: SongClipPreparationRequest) -> SongClip? {
        guard let clip = songClip(teamID: request.teamID, target: request.target),
              request.matches(clip) else {
            return nil
        }
        return clip
    }

    private func updateSongClip(
        _ clip: SongClip,
        teamID: UUID,
        target: SongClipPreparationRequest.Target
    ) {
        guard let teamIndex = state.teams.firstIndex(where: { $0.id == teamID }) else { return }
        switch target {
        case .player(let playerID):
            guard let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }) else {
                return
            }
            state.teams[teamIndex].players[playerIndex].songAssignment = .privateClip(clip)
        case .teamClip(let teamClipID):
            guard let clipIndex = state.teams[teamIndex].teamClips.firstIndex(where: { $0.id == teamClipID }) else {
                return
            }
            state.teams[teamIndex].teamClips[clipIndex] = clip
        }
    }

    private func applySongClipPreparationOutcome(
        _ outcome: SongClipPreparationOutcome,
        request: SongClipPreparationRequest
    ) {
        guard var clip = songClip(matching: request),
              let teamIndex = state.teams.firstIndex(where: { $0.id == request.teamID }) else {
            if case .generated(let asset) = outcome {
                audioAssetService.removeAsset(relativePath: asset.relativePath)
            }
            return
        }

        let previousGeneratedPath = clip.generatedAsset.status == .ready
            ? clip.generatedAsset.relativePath
            : nil
        clip.retryMetadata.lastAttemptAt = .now

        switch outcome {
        case .generated(let asset):
            clip.generatedAsset = asset
            clip.readinessInputs = SongClipReadinessInputs(
                playback: .localClipReady,
                sourceAvailableOnDevice: true,
                downloadedOnDevice: true
            )
            clip.portabilityInputs = SongClipPortabilityInputs(
                portability: .portableLocalClip,
                generatedAssetCanBeExported: true
            )
            clip.retryMetadata = .none
        case .sourceBacked(let downloadedOnDevice):
            if clip.generatedAsset.status != .ready {
                clip.generatedAsset = GeneratedClipAsset(
                    relativePath: nil,
                    status: .none,
                    renderedSelection: nil,
                    generationKey: request.generationKey,
                    generatedAt: nil
                )
            }
            clip.readinessInputs = SongClipReadinessInputs(
                playback: downloadedOnDevice ? .sourceBackedDownloaded : .sourceBackedReady,
                sourceAvailableOnDevice: true,
                downloadedOnDevice: downloadedOnDevice
            )
            clip.portabilityInputs = SongClipPortabilityInputs(
                portability: .sourceReferenceOnly,
                generatedAssetCanBeExported: false
            )
            clip.retryMetadata = .none
        case .needsAppleMusic:
            let hasReadyGeneratedAsset = clip.generatedAsset.status == .ready
            if !hasReadyGeneratedAsset {
                clip.generatedAsset.status = .failedRetryable
                clip.readinessInputs = SongClipReadinessInputs(
                    playback: .needsAppleMusic,
                    sourceAvailableOnDevice: false,
                    downloadedOnDevice: false
                )
            }
            recordPreparationFailure(
                on: &clip,
                code: .musicAuthorizationRequired,
                retryable: true,
                request: request
            )
        case .failed(let code, let retryable):
            let hasReadyGeneratedAsset = clip.generatedAsset.status == .ready
            if !hasReadyGeneratedAsset {
                clip.generatedAsset.status = retryable ? .failedRetryable : .failedPermanent
                if !retryable {
                    clip.readinessInputs.playback = .needsRepair
                    clip.readinessInputs.sourceAvailableOnDevice = false
                }
            }
            recordPreparationFailure(on: &clip, code: code, retryable: retryable, request: request)
        }

        updateSongClip(clip, teamID: request.teamID, target: request.target)
        state.teams[teamIndex].modifiedAt = .now
        if let previousGeneratedPath,
           previousGeneratedPath != clip.generatedAsset.relativePath {
            removeAssetIfUnreferenced(relativePath: previousGeneratedPath)
        }
        persist()
        scheduleReadinessRefresh()
    }

    private func recordPreparationFailure(
        on clip: inout SongClip,
        code: SongClipPreparationFailureCode,
        retryable: Bool,
        request: SongClipPreparationRequest
    ) {
        clip.retryMetadata.attemptCount += 1
        clip.retryMetadata.lastFailureCode = code.rawValue
        guard retryable, clip.retryMetadata.attemptCount < 3 else {
            clip.retryMetadata.nextRetryAt = nil
            return
        }

        let delay: TimeInterval = clip.retryMetadata.attemptCount == 1 ? 30 : 120
        let retryAt = Date().addingTimeInterval(delay)
        clip.retryMetadata.nextRetryAt = retryAt
        let teamID = request.teamID
        let target = request.target
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.scheduleSongClipPreparation(
                teamID: teamID,
                target: target,
                trigger: .retry,
                isExplicit: false
            )
        }
    }

    private func refreshPendingSongClipPreparationCount() async {
        pendingSongClipPreparationCount = await songClipPreparationCoordinator.pendingCount()
    }

    private func persist() {
        guard let request = makePersistenceRequest() else { return }
        Task(priority: .utility) { [persistenceWriter] in
            let result = await persistenceWriter.enqueue(
                request.snapshot,
                sequence: request.sequence,
                destinationURL: request.destinationURL
            )

            await MainActor.run {
                self.applyPersistenceResult(result, cleanupPaths: request.cleanupPaths)
            }
        }
    }

    func flushLatestState() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                guard let self else { return }
                await self.persistLatestStateAndWait()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(1))
            }
            await group.next()
            group.cancelAll()
        }
    }

    private func makePersistenceRequest() -> PersistenceRequest? {
        let snapshot = state
        let cleanupPaths = pendingAssetCleanupPaths
        pendingAssetCleanupPaths.removeAll()
        let destinationURL: URL
        do {
            destinationURL = try AppPaths.stateURL()
        } catch {
            pendingAssetCleanupPaths.formUnion(cleanupPaths)
            lastError = error.localizedDescription
            return nil
        }
        persistSequence += 1
        latestRequestedPersistenceSequence = persistSequence
        return PersistenceRequest(
            snapshot: snapshot,
            cleanupPaths: cleanupPaths,
            sequence: persistSequence,
            destinationURL: destinationURL
        )
    }

    private func persistLatestStateAndWait() async {
        guard let request = makePersistenceRequest() else { return }
        let result = await persistenceWriter.enqueueAndWait(
            request.snapshot,
            sequence: request.sequence,
            destinationURL: request.destinationURL
        )
        applyPersistenceResult(result, cleanupPaths: request.cleanupPaths)
    }

    private func applyPersistenceResult(
        _ result: StatePersistenceResult,
        cleanupPaths: Set<String>
    ) {
        switch result {
        case .written(let sequence):
            guard sequence >= latestRequestedPersistenceSequence else { return }
            latestDurablePersistenceSequence = sequence
            statePersistenceFailureEpisodeActive = false
            cleanupPaths.forEach(removePersistedAssetIfStillUnreferenced)
        case .failed(let sequence, let errorDescription):
            pendingAssetCleanupPaths.formUnion(cleanupPaths)
            lastError = errorDescription
            guard StatePersistenceFailureSemantics.shouldReportFailure(
                failedSequence: sequence,
                latestRequestedSequence: latestRequestedPersistenceSequence
            ) else { return }
            if !statePersistenceFailureEpisodeActive {
                statePersistenceFailureEpisodeActive = true
                telemetry.record(.statePersistenceFailed)
            }
        case .unconfirmed:
            pendingAssetCleanupPaths.formUnion(cleanupPaths)
        }
    }

    private static func load() throws -> AppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppState.self, from: Data(contentsOf: AppPaths.stateURL()))
    }

    private static func loadInitialState() -> (state: AppState, warning: String?, recoveryReason: String?) {
        do {
            let stateURL = try AppPaths.stateURL()
            guard FileManager.default.fileExists(atPath: stateURL.path) else {
                return (freshEmptyState(), nil, nil)
            }
            let loadedState = try load()
            guard loadedState.schemaVersion <= AppState.currentSchemaVersion else {
                return (
                    freshEmptyState(),
                    preserveUnreadableStateFile(
                        loadError: AppError.unsupportedSavedStateVersion
                    ),
                    "unsupportedSchema"
                )
            }
            return (loadedState, nil, nil)
        } catch {
            let recoveryMessage = preserveUnreadableStateFile(loadError: error)
            return (freshEmptyState(), recoveryMessage, "loadFailure")
        }
    }

    private static func freshEmptyState() -> AppState {
        var state = AppState.empty
        state.deviceIdentity = DeviceIdentity(label: UIDevice.current.name)
        return state
    }

    private static func preserveUnreadableStateFile(loadError: Error) -> String {
        let fallbackMessage = "Roll Call could not load saved app data. Your previous state file could not be decoded, so Roll Call preserved a recovery copy before starting from an empty state. Error: \(loadError.localizedDescription)"

        do {
            let stateURL = try AppPaths.stateURL()
            guard FileManager.default.fileExists(atPath: stateURL.path) else {
                return fallbackMessage
            }
            let recoveryURL = try AppPaths.unreadableStateRecoveryURL()
            try FileManager.default.copyItem(at: stateURL, to: recoveryURL)
            return "Roll Call could not load saved app data. A recovery copy was saved as \(recoveryURL.lastPathComponent) before Roll Call started from an empty state. Error: \(loadError.localizedDescription)"
        } catch {
            return "\(fallbackMessage) Recovery copy failed: \(error.localizedDescription)"
        }
    }

    nonisolated fileprivate static func write(_ state: AppState, to destinationURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: destinationURL, options: .atomic)
    }

    private func busy(
        operationName: String = "This operation",
        _ operation: @escaping () async throws -> Void
    ) async {
        guard let admission = riskyOperationCoordinator.begin(name: operationName) else {
            let activeName = riskyOperationCoordinator.active?.name ?? "another operation"
            lastError = "\(activeName) is still in progress. Finish it before starting \(operationName.lowercased())."
            return
        }
        riskyOperationCount = riskyOperationCoordinator.count
        isBusy = true
        defer {
            riskyOperationCoordinator.end(id: admission.id)
            riskyOperationCount = riskyOperationCoordinator.count
            isBusy = false
            if !pendingIncomingPackageURLs.isEmpty {
                Task { await self.preparePendingIncomingPackageIfNeeded() }
            }
        }
        do {
            try await operation()
            refreshReadiness()
            persist()
        } catch {
            switch operationName {
            case "Package import":
                let reason: String
                if let appError = error as? AppError {
                    switch appError {
                    case .unsupportedImportVersion: reason = "unsupportedVersion"
                    case .invalidImport: reason = "invalidPackage"
                    default: reason = "operationFailed"
                    }
                } else {
                    reason = "operationFailed"
                }
                telemetry.record(.packageImportFailed, properties: [.reason: reason])
            case "Package export":
                telemetry.record(.packageExportFailed)
            case "Roster CSV import", "Roster CSV apply":
                telemetry.record(.csvImportFailed, properties: [
                    .reason: (error as? AppError).map { if case .invalidCSV = $0 { return "invalidCSV" }; return "operationFailed" } ?? "operationFailed"
                ])
            case "Backup restore":
                telemetry.record(.restoreFailed)
            default:
                break
            }
            lastError = error.localizedDescription
        }
    }

    private func updateMusicRenderProbeSample(
        for scenario: MusicRenderProbeScenario,
        mutate: (inout MusicRenderProbeSample) -> Void
    ) {
        guard let index = musicRenderProbeSamples.firstIndex(where: { $0.scenario == scenario }) else { return }
        var sample = musicRenderProbeSamples[index]
        mutate(&sample)
        musicRenderProbeSamples[index] = sample
        musicRenderProbeSummaryURL = nil
    }

    private func preparePendingIncomingPackageIfNeeded() async {
        guard hasFinishedLaunching,
              !isBusy,
              pendingPackageImport == nil,
              !isPreparingIncomingPackagePreview else {
            return
        }

        isPreparingIncomingPackagePreview = true
        defer { isPreparingIncomingPackagePreview = false }

        while pendingPackageImport == nil, !pendingIncomingPackageURLs.isEmpty {
            let nextURL = pendingIncomingPackageURLs.removeFirst()
            do {
                let scoped = nextURL.startAccessingSecurityScopedResource()
                defer {
                    if scoped { nextURL.stopAccessingSecurityScopedResource() }
                }
                let preview = try packageService.previewDetails(packageURL: nextURL)
                pendingPackageImport = PendingPackageImport(
                    url: nextURL,
                    manifest: preview.manifest,
                    transferSummary: preview.summary,
                    opensOnboardingHandoff: !state.onboarding.isComplete
                )
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func isSupportedIncomingPackageURL(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        if url.pathExtension.localizedCaseInsensitiveCompare("rollcall") == .orderedSame {
            return true
        }
        if let type = UTType(filenameExtension: url.pathExtension),
           type.conforms(to: .rollCallPackage) {
            return true
        }

        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path)
    }

    func announcerPreviewText(for team: Team, profile: TeamAnnouncerProfile? = nil) -> String {
        let previewPlayer = announcerPreviewPlayer(for: team)
        return announcerText(for: previewPlayer, teamName: team.name, profile: profile ?? team.announcerProfile)
    }

    func announcerVoiceOptions(includeAllLanguages: Bool) -> [AnnouncerVoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { includeAllLanguages || $0.language.hasPrefix("en") }
            .filter { !isNoveltyVoice($0) }
            .map { voice in
                AnnouncerVoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    languageCode: voice.language,
                    qualityRank: qualityRank(for: voice.quality)
                )
            }
            .sorted {
                if $0.qualityRank != $1.qualityRank {
                    return $0.qualityRank > $1.qualityRank
                }
                if $0.languageCode != $1.languageCode {
                    return $0.languageCode.localizedCaseInsensitiveCompare($1.languageCode) == .orderedAscending
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    func isRecordingCustomAnnouncer(for player: Player) -> Bool {
        switch customAnnouncerRecordingPhase {
        case .recording(let playerID):
            return playerID == player.id
        default:
            return false
        }
    }

    func isCustomAnnouncerTransitioning(for player: Player) -> Bool {
        switch customAnnouncerRecordingPhase {
        case .starting(let playerID), .stopping(let playerID):
            return playerID == player.id
        default:
            return false
        }
    }

    func customAnnouncerButtonTitle(for player: Player) -> String {
        switch customAnnouncerRecordingPhase {
        case .starting(let playerID) where playerID == player.id:
            return "Starting Recording..."
        case .stopping(let playerID) where playerID == player.id:
            return "Saving Recording..."
        case .recording(let playerID) where playerID == player.id:
            return "Stop Recording"
        default:
            return player.customAnnouncerRelativePath == nil ? "Record Announcement Cue" : "Re-record Announcement Cue"
        }
    }

    func hasStoredCustomAnnouncer(for player: Player) -> Bool {
        guard let relativePath = player.customAnnouncerRelativePath else { return false }
        return audioAssetService.assetExists(relativePath: relativePath)
    }

    func chooseSuggestedHook(for cue: Cue) -> Cue {
        var updated = cue
        let clipLength = min(max(state.trimDefaults.preferredLength, 6), cueDurationLimit(for: cue))
        updated.duration = max(0.5, clipLength)
        let maxStart = max(0, cueTimelineLength(for: updated) - updated.duration)
        let candidateStart = min(max(4, maxStart * 0.45), maxStart)
        updated.startTime = roundedQuarterSecond(candidateStart)
        return updated
    }

    func chooseStartAtBeginning(for cue: Cue) -> Cue {
        var updated = cue
        updated.startTime = 0
        updated.duration = min(max(state.trimDefaults.preferredLength, 6), cueDurationLimit(for: updated))
        return updated
    }

    func rememberPreferredLength(_ duration: TimeInterval) {
        let wasDefault = state.trimDefaults.preferredLength == 12
        let value = roundedQuarterSecond(duration)
        state.trimDefaults.preferredLength = value
        persist()
        if wasDefault, value != 12 {
            let length: String
            switch value {
            case 6: length = "6"
            case 8: length = "8"
            case 10: length = "10"
            case 15: length = "15"
            case let value where value < 12: length = "customShorterThan12"
            default: length = "customLongerThan12"
            }
            telemetry.recordOnce(.trimPreferredLengthFirstChanged, properties: [.newLength: length])
        }
    }

    var recentAppleMusicSelections: [RecentAppleMusicSelection] {
        let selections = state.settings.explicitAppleMusicSearchFilteringEnabled
            ? state.recentAppleMusicSelections.filter { $0.isExplicit != true }
            : state.recentAppleMusicSelections
        return Array(selections.prefix(8))
    }

    private func configurePlaybackAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func makeDefaultAppleMusicCue(for result: MusicSearchResult) -> Cue {
        var cue = Cue.appleDefault(source: AppleMusicSource(songID: result.songID, title: result.title, artistName: result.artistName, duration: result.duration, previewURL: result.previewURL, isCatalogBacked: result.isCatalogBacked, libraryPersistentID: result.libraryPersistentID, isExplicit: result.isExplicit))
        cue.duration = min(max(state.trimDefaults.preferredLength, 6), cueDurationLimit(for: cue))
        return cue
    }

    private func enrichedAppleMusicSelection(_ result: MusicSearchResult) async throws -> MusicSearchResult {
        guard appleMusicPlaybackCapability == .fullSong else { return result }
        return try await catalogBackedResultResolver(result)
    }

    private func rememberAppleMusicSelection(_ result: MusicSearchResult) {
        let selection = RecentAppleMusicSelection(
            songID: result.songID,
            title: result.title,
            artistName: result.artistName,
            duration: result.duration,
            previewURL: result.previewURL,
            isCatalogBacked: result.isCatalogBacked,
            libraryPersistentID: result.libraryPersistentID,
            isExplicit: result.isExplicit,
            selectedAt: .now
        )
        state.recentAppleMusicSelections.removeAll { $0.songID == selection.songID }
        state.recentAppleMusicSelections.insert(selection, at: 0)
        if state.recentAppleMusicSelections.count > 20 {
            state.recentAppleMusicSelections.removeLast(state.recentAppleMusicSelections.count - 20)
        }
        persist()
    }

    func cueTimelineLength(for cue: Cue) -> Double {
        switch cue.source {
        case .appleMusic(let source):
            if source.isCatalogBacked == false {
                return 20
            }
            switch appleMusicPlaybackCapability {
            case .fullSong:
                return max(source.duration ?? 30, cue.startTime + cue.duration)
            case .previewOnly, .unknown:
                return 20
            }
        case .builtInClip:
            return max(12, cue.startTime + cue.duration)
        case .localAudio(let source):
            return max(source.duration ?? 30, cue.startTime + cue.duration)
        }
    }

    func cueDurationLimit(for cue: Cue) -> Double {
        switch cue.source {
        case .appleMusic:
            return min(20, cueTimelineLength(for: cue))
        case .builtInClip, .localAudio:
            return cueTimelineLength(for: cue)
        }
    }

    func appleMusicTrimHelpText(for cue: Cue) -> String? {
        guard case .appleMusic = cue.source else { return nil }
        switch appleMusicPlaybackCapability {
        case .fullSong:
            return "Choose up to 20 seconds from anywhere in the full song."
        case .previewOnly, .unknown:
            return "No Apple Music playback subscription is active. You can choose up to 20 seconds from the available preview clip."
        }
    }

    private func roundedQuarterSecond(_ value: TimeInterval) -> TimeInterval {
        (value / 0.25).rounded() * 0.25
    }

    private func announcerText(for player: Player, teamName: String, profile: TeamAnnouncerProfile) -> String {
        let name = player.pronunciationOverride.isEmpty ? player.displayName : player.pronunciationOverride
        let values: [(String, String)] = [
            ("<number>", player.uniformNumber),
            ("<name>", name),
            ("<team>", teamName)
        ]

        var rendered = profile.phraseTemplate
        for (token, value) in values {
            rendered = rendered.replacingOccurrences(of: token, with: value)
        }
        return rendered
            .replacingOccurrences(of: " ,", with: ",")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func announcerPreviewPlayer(for team: Team) -> Player {
        team.nextBatter
        ?? team.players.first
        ?? Player(
            id: UUID(),
            displayName: "Alex Ramirez",
            uniformNumber: "12",
            pronunciationOverride: "",
            photoRelativePath: nil,
            cue: Cue.localDefault(source: LocalAudioSource(id: UUID(), displayName: "Sample Cue", relativePath: "", duration: nil, importedAt: .now, hiddenOriginNote: nil)),
            isPresent: true
        )
    }

    private func storedCustomAnnouncerRelativePath(for player: Player) -> String? {
        if let custom = player.customAnnouncerRelativePath,
           audioAssetService.assetExists(relativePath: custom) {
            return custom
        }
        return nil
    }

    private enum PlayerPlaybackPlan {
        case cue(cue: Cue, announcerRelativePath: String?, sourceFamily: PlaybackSourceFamily)
        case assetOnly(relativePath: String, activeCueID: UUID)
    }

    private func sourceFamily(for plan: PlayerPlaybackPlan) -> PlaybackSourceFamily {
        switch plan {
        case .assetOnly:
            return .recordedAnnouncement
        case .cue(_, _, let sourceFamily):
            return sourceFamily
        }
    }

    private func failureSourceFamily(for plan: PlayerPlaybackPlan) -> PlaybackSourceFamily {
        switch sourceFamily(for: plan) {
        case .builtinIntentional:
            return .builtin
        case let source:
            return source
        }
    }

    private func playbackMode(for teamID: UUID) -> String {
        state.teams.first(where: { $0.id == teamID })?.session.gameDayAnnouncerMode.rawValue ?? "announcerAndSong"
    }

    private func playbackSourceFamily(for cue: Cue) -> PlaybackSourceFamily {
        switch cue.source {
        case .appleMusic(let source):
            if source.libraryPersistentID != nil, source.isCatalogBacked == false { return .musicLibrary }
            return source.isCatalogBacked == false ? .appleMusicPreview : .appleMusicCatalog
        case .localAudio:
            return .importedLocal
        case .builtInClip:
            return .builtin
        }
    }

    private func playerPlaybackSourceFamily(player: Player, cue: Cue) -> PlaybackSourceFamily {
        if case .localAudio = cue.source,
           let clip = selectedTeam?.songClip(for: player),
           clip.hasCurrentGeneratedAsset {
            return .generatedLocal
        }
        switch cue.source {
        case .builtInClip:
            return .builtinIntentional
        default:
            return playbackSourceFamily(for: cue)
        }
    }

    private func gameProperties(for teamID: UUID) -> [RollCallTelemetryProperty: String] {
        let team = state.teams.first(where: { $0.id == teamID })
        return [
            .accent: team.map { accentTelemetryValue($0.accentPreset) } ?? "orange",
            .volumeAutomation: state.settings.fadeOutVolumeAutomationEnabled ? "on" : "off",
            .keepScreenAwake: state.settings.keepScreenAwakeDuringLiveUse ? "on" : "off",
            .darkLiveScreens: state.settings.alwaysUseDarkLiveMode ? "on" : "off",
            .gameHeuristicVersion: "1"
        ]
    }

    private func accentTelemetryValue(_ accent: TeamAccentPreset) -> String {
        accent == .rollCallOrange ? "orange" : accent.rawValue
    }

    private func triggerAnnouncerRegeneration(for teamID: UUID, phase: String) {
        announcerRegenerationTask?.cancel()
        announcerRegenerationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.regenerateBuiltInAnnouncers(for: teamID, phase: phase)
        }
    }

    private func regenerateBuiltInAnnouncers(for teamID: UUID, phase: String) async {
        guard let teamIndex = state.teams.firstIndex(where: { $0.id == teamID }) else { return }
        let teamName = state.teams[teamIndex].name
        let profile = state.teams[teamIndex].announcerProfile
        let players = state.teams[teamIndex].players
        var firstFailure: String?

        announcerRegenerationStatus = AnnouncerRegenerationStatus(teamID: teamID, phase: phase, completed: 0, total: players.count)
        for (index, player) in players.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                let asset = try await generateBuiltInAnnouncerAsset(for: player, teamName: teamName, profile: profile)
                applyGeneratedBuiltInAnnouncerAsset(asset, toPlayerID: player.id, onTeamID: teamID)
                announcerRegenerationStatus = AnnouncerRegenerationStatus(teamID: teamID, phase: phase, completed: index + 1, total: players.count)
                persist()
            } catch {
                applyGeneratedBuiltInAnnouncerAsset(nil, toPlayerID: player.id, onTeamID: teamID)
                if firstFailure == nil {
                    firstFailure = "\(player.displayName): \(error.localizedDescription)"
                }
                announcerRegenerationStatus = AnnouncerRegenerationStatus(teamID: teamID, phase: phase, completed: index + 1, total: players.count)
            }
        }
        scheduleReadinessRefresh()
        announcerRegenerationStatus = nil
        if let firstFailure {
            lastError = "Built-in voice clips could not be pre-generated on this device. Roll Call will speak built-in announcers live during playback. First failure: \(firstFailure)"
        }
        persist()
    }

    private func renderBuiltInAnnouncer(for player: Player, teamName: String, profile: TeamAnnouncerProfile) async throws -> RenderedAnnouncerAudio {
        let phrase = announcerText(for: player, teamName: teamName, profile: profile)
        guard !phrase.isEmpty else { throw AppError.invalidAnnouncerText }
        return try await announcerRenderer.renderSpeechAudio(for: phrase, profile: profile)
    }

    private func generateBuiltInAnnouncerAsset(for player: Player, teamName: String, profile: TeamAnnouncerProfile) async throws -> GeneratedAnnouncerAsset {
        let rendered = try await renderBuiltInAnnouncer(for: player, teamName: teamName, profile: profile)
        let asset = try audioAssetService.storeSpeechData(rendered.data, displayName: "\(player.displayName)-built-in-announcer")
        return GeneratedAnnouncerAsset(
            relativePath: asset.relativePath,
            resolvedVoiceIdentifier: rendered.resolvedVoiceIdentifier,
            voiceLanguageCode: rendered.voiceLanguageCode
        )
    }

    private func qualityRank(for quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium:
            return 3
        case .enhanced:
            return 2
        default:
            return 1
        }
    }

    private func isNoveltyVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        let noveltyNames: Set<String> = [
            "bad news",
            "bahh",
            "bells",
            "boing",
            "bubbles",
            "cellos",
            "good news",
            "jester",
            "organ",
            "superstar",
            "trinoids",
            "whisper",
            "wobble",
            "zarvox"
        ]
        return noveltyNames.contains(voice.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

struct GeneratedAnnouncerAsset {
    var relativePath: String
    var resolvedVoiceIdentifier: String?
    var voiceLanguageCode: String?
}

enum StatePersistenceFailureSemantics {
    static func shouldReportFailure(failedSequence: Int, latestRequestedSequence: Int) -> Bool {
        failedSequence >= latestRequestedSequence
    }
}

private enum StatePersistenceResult {
    case written(sequence: Int)
    case failed(sequence: Int, String)
    case unconfirmed
}

private actor StatePersistenceWriter {
    private struct Waiter {
        let sequence: Int
        let continuation: CheckedContinuation<StatePersistenceResult, Never>
    }

    private var latestSequence = 0
    private var pending: (state: AppState, sequence: Int, destinationURL: URL)?
    private var isWriting = false
    private var waiters: [Waiter] = []

    func enqueue(_ state: AppState, sequence: Int, destinationURL: URL) async -> StatePersistenceResult {
        guard sequence >= latestSequence else { return .unconfirmed }
        latestSequence = sequence
        pending = (state, sequence, destinationURL)

        guard !isWriting else { return .unconfirmed }
        return writePending()
    }

    func enqueueAndWait(_ state: AppState, sequence: Int, destinationURL: URL) async -> StatePersistenceResult {
        guard sequence >= latestSequence else { return .unconfirmed }
        latestSequence = sequence
        pending = (state, sequence, destinationURL)

        guard isWriting else {
            return writePending()
        }

        return await withCheckedContinuation { continuation in
            waiters.append(Waiter(sequence: sequence, continuation: continuation))
        }
    }

    private func writePending() -> StatePersistenceResult {
        isWriting = true
        defer {
            isWriting = false
        }

        var finalResult: StatePersistenceResult = .unconfirmed
        while let next = pending {
            pending = nil
            do {
                try AppModel.write(next.state, to: next.destinationURL)
                finalResult = .written(sequence: next.sequence)
            } catch {
                finalResult = .failed(sequence: next.sequence, error.localizedDescription)
            }
        }
        let completedSequence: Int
        switch finalResult {
        case .written(let sequence), .failed(let sequence, _):
            completedSequence = sequence
        case .unconfirmed:
            completedSequence = latestSequence
        }
        resumeWaiters(through: completedSequence, result: finalResult)
        return finalResult
    }

    private func resumeWaiters(through sequence: Int, result: StatePersistenceResult) {
        let ready = waiters.filter { $0.sequence <= sequence }
        waiters.removeAll { $0.sequence <= sequence }
        ready.forEach { $0.continuation.resume(returning: result) }
    }
}

private extension TeamAnnouncerProfile {
    mutating func applyResolvedVoice(from asset: GeneratedAnnouncerAsset) {
        resolvedVoiceIdentifier = asset.resolvedVoiceIdentifier
        voiceLanguageCode = asset.voiceLanguageCode
    }
}

@MainActor
final class AnnouncerSpeechRenderer {
    private let renderTimeout: Duration = .seconds(12)

    fileprivate func renderSpeechAudio(for text: String, profile: TeamAnnouncerProfile) async throws -> RenderedAnnouncerAudio {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.invalidAnnouncerText }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf")
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.usesApplicationAudioSession = true
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = profile.rate
        utterance.pitchMultiplier = profile.pitchMultiplier
        utterance.volume = profile.volume
        let resolvedVoice = resolvedVoice(for: profile)
        utterance.voice = resolvedVoice

        return try await withCheckedThrowingContinuation { continuation in
            var file: AVAudioFile?
            var wroteAudioData = false
            let completionState = AnnouncerRenderCompletionState()
            var timeoutTask: Task<Void, Never>?

            func finish(with result: Result<RenderedAnnouncerAudio, Error>) {
                guard completionState.claimCompletion() else { return }
                timeoutTask?.cancel()
                continuation.resume(with: result)
            }

            func loadRenderedAudio() -> Result<RenderedAnnouncerAudio, Error> {
                do {
                    guard wroteAudioData, FileManager.default.fileExists(atPath: tempURL.path) else {
                        return .failure(AppError.invalidAnnouncerAudio)
                    }
                    file = nil
                    let data = try Data(contentsOf: tempURL)
                    guard !data.isEmpty else {
                        try? FileManager.default.removeItem(at: tempURL)
                        return .failure(AppError.invalidAnnouncerAudio)
                    }
                    try? FileManager.default.removeItem(at: tempURL)
                    return .success(
                        RenderedAnnouncerAudio(
                            data: data,
                            resolvedVoiceIdentifier: resolvedVoice?.identifier,
                            voiceLanguageCode: resolvedVoice?.language
                        )
                    )
                } catch {
                    return .failure(error)
                }
            }

            timeoutTask = Task {
                try? await Task.sleep(for: renderTimeout)
                guard completionState.claimCompletion() else { return }
                synthesizer.stopSpeaking(at: .immediate)
                try? FileManager.default.removeItem(at: tempURL)
                continuation.resume(throwing: AppError.announcerGenerationTimedOut)
            }

            synthesizer.write(utterance) { buffer in
                guard !completionState.hasFinished() else { return }

                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                    finish(with: loadRenderedAudio())
                    return
                }

                if pcmBuffer.frameLength == 0 {
                    finish(with: loadRenderedAudio())
                    return
                }

                guard self.pcmBufferHasAudioData(pcmBuffer) else { return }

                do {
                    if file == nil {
                        let fileSettings = self.audioFileSettings(for: resolvedVoice) ?? pcmBuffer.format.settings
                        file = try AVAudioFile(forWriting: tempURL, settings: fileSettings)
                    }
                    try file?.write(from: pcmBuffer)
                    wroteAudioData = true
                } catch {
                    try? FileManager.default.removeItem(at: tempURL)
                    finish(with: .failure(error))
                }
            }
        }
    }

    private func pcmBufferHasAudioData(_ buffer: AVAudioPCMBuffer) -> Bool {
        UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList).contains { audioBuffer in
            audioBuffer.mDataByteSize > 0
        }
    }

    private func audioFileSettings(for voice: AVSpeechSynthesisVoice?) -> [String: Any]? {
        guard let voice else { return nil }
        let settings = voice.audioFileSettings
        return settings.isEmpty ? nil : settings
    }

    private func resolvedVoice(for profile: TeamAnnouncerProfile) -> AVSpeechSynthesisVoice? {
        if let requested = profile.requestedVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: requested) {
            return voice
        }

        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let languageCode = profile.voiceLanguageCode {
            if let languageMatch = exportPreferredVoices(from: voices)
                .filter({ $0.language == languageCode })
                .sorted(by: { qualityRank(for: $0.quality) > qualityRank(for: $1.quality) })
                .first {
                return languageMatch
            }
        }

        if let usEnglish = exportPreferredVoices(from: voices)
            .filter({ $0.language.hasPrefix("en-US") || $0.language == "en-US" })
            .sorted(by: { qualityRank(for: $0.quality) > qualityRank(for: $1.quality) })
            .first {
            return usEnglish
        }

        return exportPreferredVoices(from: voices)
            .sorted(by: { qualityRank(for: $0.quality) > qualityRank(for: $1.quality) })
            .first
    }

    private func exportPreferredVoices(from voices: [AVSpeechSynthesisVoice]) -> [AVSpeechSynthesisVoice] {
        let exportable = voices.filter { !(self.audioFileSettings(for: $0)?.isEmpty ?? true) }
        return exportable.isEmpty ? voices : exportable
    }

    private func qualityRank(for quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium:
            return 3
        case .enhanced:
            return 2
        default:
            return 1
        }
    }
}
