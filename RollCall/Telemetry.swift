import Foundation

#if canImport(TelemetryDeck)
import TelemetryDeck
#endif

// MARK: - The Roll Call telemetry contract

enum RollCallTelemetryEvent: String, CaseIterable, Codable, Hashable {
    case retentionDay1 = "retention.day1"
    case retentionDay7 = "retention.day7"
    case retentionDay30 = "retention.day30"
    case retentionDay90 = "retention.day90"
    case retentionDay180 = "retention.day180"
    case retentionDay365 = "retention.day365"
    case onboardingStarted = "onboarding.started"
    case onboardingCompleted = "onboarding.completed"
    case onboardingImportPathUsed = "onboarding.importPathUsed"
    case onboardingCheerFallbackChosen = "onboarding.cheerFallbackChosen"
    case rosterPlayerCount3 = "roster.playerCount.3"
    case rosterPlayerCount5 = "roster.playerCount.5"
    case rosterPlayerCount10 = "roster.playerCount.10"
    case rosterPlayerCount15 = "roster.playerCount.15"
    case teamsActiveCount2 = "teams.activeCount.2"
    case teamsActiveCount3 = "teams.activeCount.3"
    case teamDuplicated = "team.duplicated"
    case teamPersonalized = "team.personalized"
    case playerPhotoFirstAdded = "playerPhoto.firstAdded"
    case announcementFirstRecorded = "announcement.firstRecorded"
    case mediaFirstAssignedMusicLibrary = "media.firstAssigned.musicLibrary"
    case mediaFirstAssignedAppleMusicCatalog = "media.firstAssigned.appleMusicCatalog"
    case mediaFirstAssignedImportedLocal = "media.firstAssigned.importedLocal"
    case mediaClipReuseFirstUsed = "media.clipReuse.firstUsed"
    case mediaImportFirstAudio = "media.import.firstAudio"
    case mediaImportFirstVideo = "media.import.firstVideo"
    case trimPreferredLengthFirstChanged = "trim.preferredLengthFirstChanged"
    case teamAccentFirstChanged = "teamAccent.firstChanged"
    case liveEntered = "live.entered"
    case playerPlaybackFirstSuccessful = "playerPlayback.firstSuccessful"
    case gameProbable = "game.probable"
    case gameMilestoneSecond = "gameMilestone.second"
    case gameMilestoneFifth = "gameMilestone.fifth"
    case gameMilestoneTenth = "gameMilestone.tenth"
    case gameMilestoneTwentyFifth = "gameMilestone.twentyFifth"
    case gameMilestoneFiftieth = "gameMilestone.fiftieth"
    case playerPlaybackCount10 = "playerPlayback.count.10"
    case playerPlaybackCount50 = "playerPlayback.count.50"
    case playerPlaybackCount100 = "playerPlayback.count.100"
    case playerPlaybackCount250 = "playerPlayback.count.250"
    case playerPlaybackCount500 = "playerPlayback.count.500"
    case playerPlaybackCount1000 = "playerPlayback.count.1000"
    case lineupProgressionUsedInProbableGame = "lineup.progressionUsedInProbableGame"
    case lineupEditedInProbableGame = "lineup.editedInProbableGame"
    case gamePlaybackModeUsed = "game.playbackModeUsed"
    case announcerModeFirstChanged = "announcerMode.firstChanged"
    case announcementPlayedInProbableGame = "announcement.playedInProbableGame"
    case mediaSourceUsedInProbableGame = "media.sourceUsedInProbableGame"
    case clipsBuiltinUsedInProbableGame = "clips.builtinUsedInProbableGame"
    case clipsCustomUsedInProbableGame = "clips.customUsedInProbableGame"
    case clipsFirstCustomCreated = "clips.firstCustomCreated"
    case csvImportFirstUsed = "csvImport.firstUsed"
    case packageFirstExport = "package.firstExport"
    case packageFirstImport = "package.firstImport"
    case packageExportCount5 = "package.exportCount.5"
    case packageImportCount5 = "package.importCount.5"
    case playlistSyncFirstUsed = "playlistSync.firstUsed"
    case playlistSyncUsedInMultipleTeams = "playlistSync.usedInMultipleTeams"
    case backupManualCreated = "backup.manualCreated"
    case backupRestored = "backup.restored"
    case recentlyDeletedRestored = "recentlyDeleted.restored"
    case readinessFirstOpened = "readiness.firstOpened"
    case repairFirstNeeded = "repair.firstNeeded"
    case repairFirstCompleted = "repair.firstCompleted"
    case settingExplicitFilterFirstChanged = "setting.explicitFilter.firstChanged"
    case settingVolumeAutomationFirstChanged = "setting.volumeAutomation.firstChanged"
    case settingDarkLiveScreensFirstChanged = "setting.darkLiveScreens.firstChanged"
    case settingKeepScreenAwakeFirstChanged = "setting.keepScreenAwake.firstChanged"
    case analyticsPreferenceChanged = "analytics.preferenceChanged"
    case ratingBecameEligible = "rating.becameEligible"
    case ratingSheetShown = "rating.sheetShown"
    case ratingRateSelected = "rating.rateSelected"
    case ratingFeedbackSelected = "rating.feedbackSelected"
    case ratingSupportSelected = "rating.supportSelected"
    case ratingNotNowSelected = "rating.notNowSelected"
    case gameRecoveryPathUsed = "game.recoveryPathUsed"
    case playbackFailedCompletely = "playback.failedCompletely"
    case gameCompletePlaybackFailureObserved = "game.completePlaybackFailureObserved"
    case packageImportFailed = "packageImport.failed"
    case packageExportFailed = "packageExport.failed"
    case csvImportFailed = "csvImport.failed"
    case backupFailed = "backup.failed"
    case restoreFailed = "restore.failed"
    case stateRecoveryTriggered = "state.recoveryTriggered"
    case telemetryStateRecovered = "telemetryState.recovered"
    case telemetryStatePersistenceFailed = "telemetryState.persistenceFailed"
    case statePersistenceFailed = "state.persistenceFailed"
    case musicAccessDenied = "musicAccess.denied"
    case microphoneAccessDenied = "microphoneAccess.denied"
    case playerCardOpened = "playerCard.opened"
    case playerCardGenerated = "playerCard.generated"
    case playerCardGenerationFailed = "playerCard.generationFailed"
    case playerCardShareInitiated = "playerCard.shareInitiated"
    case playerPhotoProfileFramingAdjusted = "playerPhoto.profileFramingAdjusted"
    case playerPhotoCardFramingAdjusted = "playerPhoto.cardFramingAdjusted"
    case playerPhotoDetectionCompleted = "playerPhoto.detectionCompleted"
    case quickGameDayInvoked = "quickGameDay.invoked"
    case quickGameDayTargetResolved = "quickGameDay.targetResolved"
    case quickGameDayReached = "quickGameDay.reached"
    case quickGameDayFallback = "quickGameDay.fallback"
    case quickGameDayFailed = "quickGameDay.failed"
}

enum RollCallTelemetryProperty: String, CaseIterable, Codable, Hashable {
    case appVersion
    case buildNumber
    case telemetrySchemaVersion
    case observationOrigin
    case enrollmentCohort
    case rowCountBucket
    case newLength
    case newAccent
    case newMode
    case newValue
    case accent
    case volumeAutomation
    case keepScreenAwake
    case darkLiveScreens
    case gameHeuristicVersion
    case mode
    case sourceFamily
    case hadMissingMedia
    case category
    case recoveryOutcome
    case failedComponent
    case reason
    case liveContext
    case fallbackAttempted
    case result
    case qualifiedGameBucket
    case daysSincePolicyEnrollmentBucket
    case automaticAttemptNumber
    case ratingPolicyVersion
    case source
    case detection
    case target
}

struct RollCallTelemetrySignal: Equatable {
    let event: RollCallTelemetryEvent
    let properties: [String: String]
}

enum RollCallTelemetryValidationError: Error, Equatable {
    case unknownEvent(String)
    case unknownProperty(String)
    case invalidValue(property: String, value: String)
    case forbiddenIdentifier
}

/// This validator is the only place where feature-facing telemetry strings are
/// converted to the SDK's dictionary representation. It intentionally rejects
/// unknown names, unknown values, identifiers, and arbitrary error text.
struct RollCallTelemetryValidator {
    static let shared = RollCallTelemetryValidator()

    private let allowedValues: [RollCallTelemetryProperty: Set<String>] = [
        .observationOrigin: ["enrollmentBaseline", "observedAction"],
        .enrollmentCohort: ["newInstall", "existingInstall"],
        .rowCountBucket: ["1-5", "6-10", "11-20", "21+"],
        .newLength: ["6", "8", "10", "15", "customShorterThan12", "customLongerThan12"],
        .newAccent: ["orange", "red", "gold", "green", "blue", "purple", "gray", "black"],
        .newMode: ["announcerOnly", "announcerAndSong", "songOnly"],
        .newValue: ["on", "off"],
        .accent: ["orange", "red", "gold", "green", "blue", "purple", "gray", "black"],
        .volumeAutomation: ["on", "off"],
        .keepScreenAwake: ["on", "off"],
        .darkLiveScreens: ["on", "off"],
        .telemetrySchemaVersion: ["1"],
        .gameHeuristicVersion: ["1"],
        .mode: ["announcerOnly", "announcerAndSong", "songOnly"],
        .sourceFamily: ["musicLibrary", "appleMusicCatalog", "appleMusicPreview", "generatedLocal", "importedLocal", "builtinIntentional", "recordedAnnouncement", "builtin", "unknown"],
        .hadMissingMedia: ["true", "false"],
        .category: ["playerMedia", "announcement", "customClip", "appleMusicAccess", "importedPackageMedia"],
        .recoveryOutcome: ["songOnly", "introOnly", "builtinCheer"],
        .failedComponent: ["announcement", "primaryCue"],
        .reason: ["missingAsset", "unreadableAsset", "authorization", "subscription", "sourceUnavailable", "startRejected", "startTimedOut", "playbackError", "unsupportedVersion", "invalidPackage", "operationFailed", "invalidCSV", "unsupportedSchema", "loadFailure", "denied", "restricted", "unknown", "unreadableImage", "encodingFailed", "noTeams", "noRememberedTeam", "rememberedTeamMissing", "explicitTeamMissing"],
        .liveContext: ["gameDay", "clips"],
        .fallbackAttempted: ["true", "false"],
        .result: ["denied", "restricted"],
        .qualifiedGameBucket: ["0", "1", "2-4", "5-9", "10+"],
        .daysSincePolicyEnrollmentBucket: ["<7", "7-13", "14-29", "30-89", "90+"],
        .automaticAttemptNumber: ["1", "2"],
        .ratingPolicyVersion: ["1"],
        .source: ["automatic", "manual", "systemControl", "appIntent", "unknownSystem", "inApp"],
        .detection: ["faceAndPerson", "multiplePeople", "faceOnly", "personOnly", "noUsableDetection"],
        .target: ["explicitTeam", "rememberedTeam"]
    ]

    private let allowedPropertiesByEvent: [RollCallTelemetryEvent: Set<RollCallTelemetryProperty>] = {
        var map = Dictionary(uniqueKeysWithValues: RollCallTelemetryEvent.allCases.map { ($0, Set<RollCallTelemetryProperty>()) })
        func allow(_ events: [RollCallTelemetryEvent], _ properties: [RollCallTelemetryProperty]) {
            for event in events { map[event] = Set(properties) }
        }
        allow([.retentionDay1, .retentionDay7, .retentionDay30, .retentionDay90, .retentionDay180, .retentionDay365], [.enrollmentCohort])
        allow([.trimPreferredLengthFirstChanged], [.newLength])
        allow([.teamAccentFirstChanged], [.newAccent])
        allow([.settingExplicitFilterFirstChanged, .settingVolumeAutomationFirstChanged, .settingDarkLiveScreensFirstChanged, .settingKeepScreenAwakeFirstChanged, .analyticsPreferenceChanged], [.newValue])
        allow([.announcerModeFirstChanged], [.newMode])
        allow([.gameProbable], [.accent, .volumeAutomation, .keepScreenAwake, .darkLiveScreens, .gameHeuristicVersion])
        allow([.gamePlaybackModeUsed], [.mode])
        allow([.mediaSourceUsedInProbableGame], [.sourceFamily])
        allow([.packageFirstImport], [.hadMissingMedia])
        allow([.csvImportFirstUsed], [.rowCountBucket])
        allow([.repairFirstNeeded, .repairFirstCompleted], [.category])
        allow([.ratingBecameEligible], [.qualifiedGameBucket, .daysSincePolicyEnrollmentBucket, .enrollmentCohort, .automaticAttemptNumber, .ratingPolicyVersion])
        allow([.ratingSheetShown], [.source, .qualifiedGameBucket, .daysSincePolicyEnrollmentBucket, .enrollmentCohort, .automaticAttemptNumber, .ratingPolicyVersion])
        allow([.gameRecoveryPathUsed], [.recoveryOutcome, .failedComponent, .sourceFamily, .reason])
        allow([.playbackFailedCompletely], [.sourceFamily, .liveContext, .fallbackAttempted, .reason])
        allow([.gameCompletePlaybackFailureObserved], [.sourceFamily, .reason])
        allow([.packageImportFailed, .csvImportFailed], [.reason])
        allow([.stateRecoveryTriggered], [.reason])
        allow([.musicAccessDenied, .microphoneAccessDenied], [.result])
        allow([.playerCardGenerationFailed, .quickGameDayFallback, .quickGameDayFailed], [.reason])
        allow([.playerPhotoDetectionCompleted], [.detection])
        allow([.quickGameDayInvoked], [.source])
        allow([.quickGameDayTargetResolved], [.target])
        let baselineEvents: [RollCallTelemetryEvent] = [
            .onboardingStarted, .onboardingCompleted, .onboardingImportPathUsed,
            .onboardingCheerFallbackChosen, .rosterPlayerCount3, .rosterPlayerCount5,
            .rosterPlayerCount10, .rosterPlayerCount15, .teamsActiveCount2,
            .teamsActiveCount3, .teamPersonalized, .playerPhotoFirstAdded,
            .announcementFirstRecorded, .mediaFirstAssignedMusicLibrary,
            .mediaFirstAssignedAppleMusicCatalog, .mediaFirstAssignedImportedLocal,
            .mediaClipReuseFirstUsed, .clipsFirstCustomCreated,
            .trimPreferredLengthFirstChanged, .teamAccentFirstChanged,
            .announcerModeFirstChanged, .settingExplicitFilterFirstChanged,
            .settingVolumeAutomationFirstChanged, .settingDarkLiveScreensFirstChanged,
            .settingKeepScreenAwakeFirstChanged
        ]
        for event in baselineEvents {
            map[event, default: []].insert(.observationOrigin)
        }
        for event in RollCallTelemetryEvent.allCases {
            map[event, default: []].insert(.telemetrySchemaVersion)
        }
        return map
    }()

    private let eventSpecificValues: [String: Set<String>] = [
        "media.sourceUsedInProbableGame.sourceFamily": ["musicLibrary", "appleMusicCatalog", "appleMusicPreview", "generatedLocal", "importedLocal", "builtinIntentional"],
        "game.recoveryPathUsed.sourceFamily": ["recordedAnnouncement", "musicLibrary", "appleMusicCatalog", "appleMusicPreview", "generatedLocal", "importedLocal", "builtin", "unknown"],
        "game.completePlaybackFailureObserved.sourceFamily": ["recordedAnnouncement", "musicLibrary", "appleMusicCatalog", "appleMusicPreview", "generatedLocal", "importedLocal", "builtin", "unknown"],
        "packageImport.failed.reason": ["unsupportedVersion", "invalidPackage", "operationFailed"],
        "csvImport.failed.reason": ["invalidCSV", "operationFailed"],
        // Both values come from `AppModel.loadInitialState()`.
        "state.recoveryTriggered.reason": ["unsupportedSchema", "loadFailure"],
        "playerCard.generationFailed.reason": ["missingAsset", "unreadableImage", "encodingFailed", "unknown"],
        "quickGameDay.fallback.reason": ["noTeams", "noRememberedTeam", "rememberedTeamMissing", "explicitTeamMissing"],
        "quickGameDay.failed.reason": ["operationFailed", "unknown"],
        "rating.sheetShown.source": ["automatic", "manual"],
        "quickGameDay.invoked.source": ["systemControl", "appIntent", "unknownSystem", "inApp"]
    ]

    private func values(for event: RollCallTelemetryEvent, property: RollCallTelemetryProperty) -> Set<String> {
        eventSpecificValues["\(event.rawValue).\(property.rawValue)"] ?? allowedValues[property] ?? []
    }

    func validate(
        event: RollCallTelemetryEvent,
        properties: [RollCallTelemetryProperty: String] = [:]
    ) throws -> RollCallTelemetrySignal {
        var stringProperties: [String: String] = [:]
        for (property, value) in properties {
            guard allowedPropertiesByEvent[event]?.contains(property) == true else {
                throw RollCallTelemetryValidationError.unknownProperty(property.rawValue)
            }
            guard values(for: event, property: property).contains(value) else {
                throw RollCallTelemetryValidationError.invalidValue(property: property.rawValue, value: value)
            }
            stringProperties[property.rawValue] = value
        }
        return RollCallTelemetrySignal(event: event, properties: stringProperties)
    }

    func validate(eventName: String, properties: [String: String] = [:]) throws -> RollCallTelemetrySignal {
        guard let event = RollCallTelemetryEvent(rawValue: eventName) else {
            throw RollCallTelemetryValidationError.unknownEvent(eventName)
        }
        for (name, value) in properties {
            guard let property = RollCallTelemetryProperty(rawValue: name) else {
                throw RollCallTelemetryValidationError.unknownProperty(name)
            }
            guard property != .appVersion, property != .buildNumber else {
                throw RollCallTelemetryValidationError.forbiddenIdentifier
            }
            guard allowedPropertiesByEvent[event]?.contains(property) == true else {
                throw RollCallTelemetryValidationError.unknownProperty(name)
            }
            guard values(for: event, property: property).contains(value) else {
                throw RollCallTelemetryValidationError.invalidValue(property: name, value: value)
            }
        }
        return RollCallTelemetrySignal(event: event, properties: properties)
    }
}

protocol RollCallTelemetryProvider: AnyObject {
    func configure(enabled: Bool, context: TelemetryBuildContext)
    func send(_ signal: RollCallTelemetrySignal)
}

struct TelemetryBuildContext: Equatable {
    let isAppStoreBuild: Bool
    let isTestFlightBuild: Bool
    let isDeveloperBuild: Bool
    let isSwiftUIPreview: Bool

    var testMode: Bool { !isAppStoreBuild }

    static var current: TelemetryBuildContext {
        let receiptName = Bundle.main.appStoreReceiptURL?.lastPathComponent
        let isTestFlight = receiptName == "sandboxReceipt"
        let isAppStore = receiptName == "receipt"
        return TelemetryBuildContext(
            isAppStoreBuild: isAppStore,
            isTestFlightBuild: isTestFlight,
            isDeveloperBuild: !isAppStore && !isTestFlight,
            isSwiftUIPreview: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        )
    }
}

struct TelemetryDeckConfigurationSnapshot: Equatable {
    let appID: String
    let analyticsDisabled: Bool
    let testMode: Bool
    let sendNewSessionBeganSignal: Bool
    let sessionStatsEnabled: Bool
}

#if canImport(TelemetryDeck)
final class TelemetryDeckProvider: RollCallTelemetryProvider {
    private let appID: String
    private var context = TelemetryBuildContext.current
    private var configuration: TelemetryDeck.Config?
    private(set) var configurationSnapshot: TelemetryDeckConfigurationSnapshot?

    init(appID: String?) {
        self.appID = appID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func configure(enabled: Bool, context: TelemetryBuildContext) {
        guard !appID.isEmpty else { return }
        self.context = context
        if let configuration {
            // Config is a reference type. Mutating the already initialized
            // instance changes the SDK gate without replacing its manager,
            // preserving the SDK's in-memory and on-disk cache semantics.
            configuration.analyticsDisabled = !enabled
            configurationSnapshot = TelemetryDeckConfigurationSnapshot(
                appID: appID,
                analyticsDisabled: configuration.analyticsDisabled,
                testMode: configuration.testMode,
                sendNewSessionBeganSignal: configuration.sendNewSessionBeganSignal,
                sessionStatsEnabled: configuration.sessionStatsEnabled
            )
            return
        }
        let config = TelemetryDeck.Config(appID: appID)
        // Set every Roll Call-required setting before initialization. Leave
        // salt, identity, metadata enrichers, batching, retry, and cache at
        // their SDK defaults.
        config.analyticsDisabled = !enabled
        config.testMode = context.testMode
        config.swiftUIPreviewMode = context.isSwiftUIPreview
        config.sendNewSessionBeganSignal = false
        config.sessionStatsEnabled = false
        configuration = config
        configurationSnapshot = TelemetryDeckConfigurationSnapshot(
            appID: appID,
            analyticsDisabled: !enabled,
            testMode: context.testMode,
            sendNewSessionBeganSignal: config.sendNewSessionBeganSignal,
            sessionStatsEnabled: config.sessionStatsEnabled
        )
        TelemetryDeck.initialize(config: config)
    }

    func send(_ signal: RollCallTelemetrySignal) {
        guard !appID.isEmpty else { return }
        TelemetryDeck.signal(signal.event.rawValue, parameters: signal.properties)
    }
}
#endif

final class RecordingTelemetryProvider: RollCallTelemetryProvider {
    private(set) var configurationSnapshots: [TelemetryDeckConfigurationSnapshot] = []
    private(set) var signals: [RollCallTelemetrySignal] = []

    func configure(enabled: Bool, context: TelemetryBuildContext) {
        configurationSnapshots.append(
            TelemetryDeckConfigurationSnapshot(
                appID: "test",
                analyticsDisabled: !enabled,
                testMode: context.testMode,
                sendNewSessionBeganSignal: false,
                sessionStatsEnabled: false
            )
        )
    }

    func send(_ signal: RollCallTelemetrySignal) {
        signals.append(signal)
    }
}

final class NullTelemetryProvider: RollCallTelemetryProvider {
    func configure(enabled: Bool, context: TelemetryBuildContext) {}
    func send(_ signal: RollCallTelemetrySignal) {}
}

// MARK: - Independent preference and versioned state

struct AnonymousUsageAnalyticsPreference {
    static let key = "RollCall.anonymousUsageAnalyticsEnabled"
    let defaults: UserDefaults

    var isEnabled: Bool {
        guard defaults.object(forKey: Self.key) != nil else { return true }
        return defaults.bool(forKey: Self.key)
    }

    func persist(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.key)
    }
}

struct TelemetryRatingState: Codable, Equatable {
    var automaticAttemptsConsumed = 0
    var distinctProbableGameDates: [Date] = []
    // The date key is captured when a session first qualifies. The Date array
    // remains for compatibility with the original store shape and migration;
    // policy decisions use these frozen local-calendar keys whenever present.
    var probableGameDateKeys: [String] = []
    var enrollmentDate: Date
    var firstSheetShownAt: Date?
    var presentationCooldownAnchor: Date?
    var permanentlySuppressed = false
    var eligibilityEmittedForAttempts: Set<Int> = []
    var pendingPresentation: PendingRatingPresentation?

    private enum CodingKeys: String, CodingKey {
        case automaticAttemptsConsumed, distinctProbableGameDates, probableGameDateKeys, enrollmentDate
        case firstSheetShownAt, presentationCooldownAnchor, permanentlySuppressed
        case eligibilityEmittedForAttempts, pendingPresentation
    }

    init(
        enrollmentDate: Date,
        automaticAttemptsConsumed: Int = 0,
        distinctProbableGameDates: [Date] = [],
        probableGameDateKeys: [String] = [],
        firstSheetShownAt: Date? = nil,
        presentationCooldownAnchor: Date? = nil,
        permanentlySuppressed: Bool = false,
        eligibilityEmittedForAttempts: Set<Int> = [],
        pendingPresentation: PendingRatingPresentation? = nil
    ) {
        self.automaticAttemptsConsumed = automaticAttemptsConsumed
        self.distinctProbableGameDates = distinctProbableGameDates
        self.probableGameDateKeys = probableGameDateKeys
        self.enrollmentDate = enrollmentDate
        self.firstSheetShownAt = firstSheetShownAt
        self.presentationCooldownAnchor = presentationCooldownAnchor
        self.permanentlySuppressed = permanentlySuppressed
        self.eligibilityEmittedForAttempts = eligibilityEmittedForAttempts
        self.pendingPresentation = pendingPresentation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        automaticAttemptsConsumed = try container.decodeIfPresent(Int.self, forKey: .automaticAttemptsConsumed) ?? 0
        distinctProbableGameDates = try container.decodeIfPresent([Date].self, forKey: .distinctProbableGameDates) ?? []
        let storedDateKeys = try container.decodeIfPresent([String].self, forKey: .probableGameDateKeys) ?? []
        probableGameDateKeys = storedDateKeys.isEmpty
            ? RollCallRatingPolicy.distinctLocalDates(distinctProbableGameDates).map { RollCallRatingPolicy.localDateKey(for: $0) }
            : storedDateKeys
        enrollmentDate = try container.decodeIfPresent(Date.self, forKey: .enrollmentDate) ?? .distantFuture
        firstSheetShownAt = try container.decodeIfPresent(Date.self, forKey: .firstSheetShownAt)
        presentationCooldownAnchor = try container.decodeIfPresent(Date.self, forKey: .presentationCooldownAnchor)
        permanentlySuppressed = try container.decodeIfPresent(Bool.self, forKey: .permanentlySuppressed) ?? false
        eligibilityEmittedForAttempts = try container.decodeIfPresent(Set<Int>.self, forKey: .eligibilityEmittedForAttempts) ?? []
        pendingPresentation = try container.decodeIfPresent(PendingRatingPresentation.self, forKey: .pendingPresentation)
    }
}

struct PendingRatingPresentation: Codable, Equatable {
    enum Source: String, Codable { case automatic, manual }
    var token: UUID
    var source: Source
    var automaticAttemptNumber: Int?
    var reservedAt: Date

    private enum CodingKeys: String, CodingKey {
        case token, source, automaticAttemptNumber, reservedAt
    }

    init(token: UUID, source: Source, automaticAttemptNumber: Int?, reservedAt: Date) {
        self.token = token
        self.source = source
        self.automaticAttemptNumber = automaticAttemptNumber
        self.reservedAt = reservedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decodeIfPresent(UUID.self, forKey: .token) ?? UUID()
        source = try container.decode(Source.self, forKey: .source)
        automaticAttemptNumber = try container.decodeIfPresent(Int.self, forKey: .automaticAttemptNumber)
        reservedAt = try container.decode(Date.self, forKey: .reservedAt)
    }
}

struct LiveAnalyticsCheckpoint: Codable, Equatable {
    var selectedTeamID: UUID
    var firstQualifyingCueAt: Date
    var latestQualifyingCueAt: Date
    var distinctPlayerIDs: Set<UUID>
    var qualifyingCueCount: Int
    var hasThreeMinuteGap: Bool
    var latestMeaningfulActivityAt: Date
    var bufferedRecoveryKeys: Set<String>
    var bufferedCompleteFailureKeys: Set<String>
    var emittedFeatureKeys: Set<String>
    var didQualify: Bool
    var probableGameDate: Date?
    var probableGameDateKey: String? = nil
}

struct TelemetryStoreState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion = Self.currentSchemaVersion
    var enrollmentDate: Date
    var enrollmentCohort: String
    var baselineCompleted = false
    var consumedInstallEvents: Set<String> = []
    var consumedTeamEvents: Set<String> = []
    var consumedGameEvents: Set<String> = []
    var suppressedEvents: Set<String> = []
    var successfulPlayerPlaybackCount = 0
    var packageExportCount = 0
    var packageImportCount = 0
    var retentionEvents: Set<String> = []
    var probableGameDates: [Date] = []
    var liveCheckpoint: LiveAnalyticsCheckpoint?
    var rating: TelemetryRatingState
    var suspended = false
    /// A corrupt-store replacement cannot know which one-time install/team
    /// actions happened before recovery. Keep that history conservative.
    var conservativeHistoryConsumed = false

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, enrollmentDate, enrollmentCohort, baselineCompleted
        case consumedInstallEvents, consumedTeamEvents, consumedGameEvents, suppressedEvents
        case successfulPlayerPlaybackCount, packageExportCount, packageImportCount
        case retentionEvents, probableGameDates, liveCheckpoint, rating, suspended, conservativeHistoryConsumed
    }

    init(
        enrollmentDate: Date,
        enrollmentCohort: String,
        rating: TelemetryRatingState,
        schemaVersion: Int = Self.currentSchemaVersion,
        baselineCompleted: Bool = false,
        consumedInstallEvents: Set<String> = [],
        consumedTeamEvents: Set<String> = [],
        consumedGameEvents: Set<String> = [],
        suppressedEvents: Set<String> = [],
        successfulPlayerPlaybackCount: Int = 0,
        packageExportCount: Int = 0,
        packageImportCount: Int = 0,
        retentionEvents: Set<String> = [],
        probableGameDates: [Date] = [],
        liveCheckpoint: LiveAnalyticsCheckpoint? = nil,
        suspended: Bool = false,
        conservativeHistoryConsumed: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.enrollmentDate = enrollmentDate
        self.enrollmentCohort = enrollmentCohort
        self.baselineCompleted = baselineCompleted
        self.consumedInstallEvents = consumedInstallEvents
        self.consumedTeamEvents = consumedTeamEvents
        self.consumedGameEvents = consumedGameEvents
        self.suppressedEvents = suppressedEvents
        self.successfulPlayerPlaybackCount = successfulPlayerPlaybackCount
        self.packageExportCount = packageExportCount
        self.packageImportCount = packageImportCount
        self.retentionEvents = retentionEvents
        self.probableGameDates = probableGameDates
        self.liveCheckpoint = liveCheckpoint
        self.rating = rating
        self.suspended = suspended
        self.conservativeHistoryConsumed = conservativeHistoryConsumed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        enrollmentDate = try container.decodeIfPresent(Date.self, forKey: .enrollmentDate) ?? .distantFuture
        enrollmentCohort = try container.decodeIfPresent(String.self, forKey: .enrollmentCohort) ?? "existingInstall"
        baselineCompleted = try container.decodeIfPresent(Bool.self, forKey: .baselineCompleted) ?? false
        consumedInstallEvents = try container.decodeIfPresent(Set<String>.self, forKey: .consumedInstallEvents) ?? []
        consumedTeamEvents = try container.decodeIfPresent(Set<String>.self, forKey: .consumedTeamEvents) ?? []
        consumedGameEvents = try container.decodeIfPresent(Set<String>.self, forKey: .consumedGameEvents) ?? []
        suppressedEvents = try container.decodeIfPresent(Set<String>.self, forKey: .suppressedEvents) ?? []
        successfulPlayerPlaybackCount = try container.decodeIfPresent(Int.self, forKey: .successfulPlayerPlaybackCount) ?? 0
        packageExportCount = try container.decodeIfPresent(Int.self, forKey: .packageExportCount) ?? 0
        packageImportCount = try container.decodeIfPresent(Int.self, forKey: .packageImportCount) ?? 0
        retentionEvents = try container.decodeIfPresent(Set<String>.self, forKey: .retentionEvents) ?? []
        probableGameDates = try container.decodeIfPresent([Date].self, forKey: .probableGameDates) ?? []
        if container.contains(.liveCheckpoint) {
            liveCheckpoint = try? container.decode(LiveAnalyticsCheckpoint.self, forKey: .liveCheckpoint)
        } else {
            liveCheckpoint = nil
        }
        rating = try container.decodeIfPresent(TelemetryRatingState.self, forKey: .rating)
            ?? TelemetryRatingState(enrollmentDate: enrollmentDate)
        suspended = try container.decodeIfPresent(Bool.self, forKey: .suspended) ?? false
        conservativeHistoryConsumed = try container.decodeIfPresent(Bool.self, forKey: .conservativeHistoryConsumed) ?? false
    }

    static func new(cohort: String, now: Date) -> TelemetryStoreState {
        TelemetryStoreState(enrollmentDate: now, enrollmentCohort: cohort, rating: TelemetryRatingState(enrollmentDate: now))
    }

    static func conservativeReplacement(now: Date) -> TelemetryStoreState {
        var state = TelemetryStoreState.new(cohort: "existingInstall", now: now)
        state.baselineCompleted = true
        state.consumedInstallEvents = Set(RollCallTelemetryEvent.allCases.map(\.rawValue))
        state.conservativeHistoryConsumed = true
        state.retentionEvents = Set([
            RollCallTelemetryEvent.retentionDay1.rawValue,
            RollCallTelemetryEvent.retentionDay7.rawValue,
            RollCallTelemetryEvent.retentionDay30.rawValue,
            RollCallTelemetryEvent.retentionDay90.rawValue,
            RollCallTelemetryEvent.retentionDay180.rawValue,
            RollCallTelemetryEvent.retentionDay365.rawValue
        ])
        state.rating.automaticAttemptsConsumed = 2
        state.rating.permanentlySuppressed = true
        state.probableGameDates = []
        return state
    }
}

// Snapshots are copied before crossing into the persistence queue. The
// contained Foundation value types are immutable for the duration of a write.
extension TelemetryStoreState: @unchecked Sendable {}

enum TelemetryStoreLoadStatus: Equatable {
    case new
    case loaded
    case unsupported
    case recovered
    case unavailable
}

private final class TelemetrySynchronousWriteResult: @unchecked Sendable {
    let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var _didSave = false

    var didSave: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didSave
    }

    func complete(_ didSave: Bool) {
        lock.lock()
        _didSave = didSave
        lock.unlock()
        semaphore.signal()
    }
}

final class TelemetryStore: @unchecked Sendable {
    let url: URL
    private let fileManager: FileManager
    private let writeQueue = DispatchQueue(
        label: "com.rollcall.telemetry.persistence",
        qos: .utility
    )
    private let writeOverrideLock = NSLock()
    private var _writeOverride: ((Data, URL) throws -> Void)?
    private let asyncWriteStateLock = NSLock()
    private var asyncWriteBlocked = false
    var state: TelemetryStoreState
    private(set) var status: TelemetryStoreLoadStatus
    var writeOverride: ((Data, URL) throws -> Void)? {
        get {
            writeOverrideLock.lock()
            defer { writeOverrideLock.unlock() }
            return _writeOverride
        }
        set {
            writeOverrideLock.lock()
            _writeOverride = newValue
            writeOverrideLock.unlock()
        }
    }

    init(
        url: URL,
        now: Date = .now,
        fileManager: FileManager = .default,
        legacyAutomaticAttemptCount: Int = 0
    ) {
        self.url = url
        self.fileManager = fileManager
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if !fileManager.fileExists(atPath: url.path) {
            self.state = .new(cohort: "newInstall", now: now)
            self.status = .new
            self.state.rating.automaticAttemptsConsumed = max(0, min(legacyAutomaticAttemptCount, 2))
            if legacyAutomaticAttemptCount > 0 {
                self.state.enrollmentCohort = "existingInstall"
                self.state.rating.enrollmentDate = now
            }
            return
        }
        do {
            let data = try Data(contentsOf: url)
            // Probe only the version before decoding the full payload. This
            // keeps a future store untouched rather than treating it as corrupt.
            if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let schemaVersion = object["schemaVersion"] as? Int,
               schemaVersion > TelemetryStoreState.currentSchemaVersion {
                self.state = .new(cohort: "existingInstall", now: now)
                self.status = .unsupported
            } else {
                var decoded = try decoder.decode(TelemetryStoreState.self, from: data)
                if decoded.schemaVersion < TelemetryStoreState.currentSchemaVersion {
                    decoded.schemaVersion = TelemetryStoreState.currentSchemaVersion
                }
                self.state = decoded
                self.status = .loaded
            }
        } catch {
            let quarantineURL = url.deletingPathExtension().appendingPathExtension("corrupt-\(UUID().uuidString).json")
            guard (try? fileManager.moveItem(at: url, to: quarantineURL)) != nil else {
                self.state = .conservativeReplacement(now: now)
                self.status = .unavailable
                return
            }
            self.state = .conservativeReplacement(now: now)
            self.status = .recovered
        }
    }

    @discardableResult
    func save(_ candidate: TelemetryStoreState? = nil) -> Bool {
        let value = candidate ?? state
        let result = TelemetrySynchronousWriteResult()
        writeQueue.async { [weak self] in
            guard let self else {
                result.complete(false)
                return
            }
            guard !self.persistenceIsBlocked() else {
                result.complete(false)
                return
            }
            let didSave = self.write(value)
            if !didSave { self.blockPersistenceAfterFailure() }
            result.complete(didSave)
        }
        result.semaphore.wait()
        let didSave = result.didSave
        if didSave { state = value }
        return didSave
    }

    /// Persists a snapshot in submission order without encoding or writing on
    /// the caller's actor. The completion is delivered on the main actor.
    func saveAsync(
        _ candidate: TelemetryStoreState,
        completion: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        writeQueue.async { [weak self] in
            guard let self else { return }
            let didSave: Bool
            if self.persistenceIsBlocked() {
                didSave = false
            } else {
                didSave = self.write(candidate)
                if !didSave { self.blockPersistenceAfterFailure() }
            }
            DispatchQueue.main.async {
                completion(didSave)
            }
        }
    }

    /// Reopens the async writer only after an explicit retry has been chosen.
    func resetAsyncPersistenceAfterFailure() {
        writeQueue.sync {
            resetPersistenceFailure()
        }
    }

    /// Prevents both synchronous and asynchronous writes from bypassing a
    /// failed revision. The serial queue observes this barrier before each
    /// write.
    func blockAsyncPersistenceAfterFailure() {
        blockPersistenceAfterFailure()
    }

    /// Test/support hook that waits for all writes submitted before the call.
    func waitForPendingWrites() async {
        await withCheckedContinuation { continuation in
            writeQueue.async {
                continuation.resume()
            }
        }
    }

    private func write(_ value: TelemetryStoreState) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(value)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let writeOverride {
                try writeOverride(data, url)
            } else {
                try data.write(to: url, options: .atomic)
            }
            return true
        } catch {
            return false
        }
    }

    private func persistenceIsBlocked() -> Bool {
        asyncWriteStateLock.lock()
        defer { asyncWriteStateLock.unlock() }
        return asyncWriteBlocked
    }

    private func blockPersistenceAfterFailure() {
        asyncWriteStateLock.lock()
        asyncWriteBlocked = true
        asyncWriteStateLock.unlock()
    }

    private func resetPersistenceFailure() {
        asyncWriteStateLock.lock()
        asyncWriteBlocked = false
        asyncWriteStateLock.unlock()
    }
}

struct TelemetryPolicySnapshot: Equatable {
    let probableGameDateCount: Int
    let automaticAttemptsConsumed: Int
    let permanentlySuppressed: Bool
    let firstSheetShownAt: Date?
}

struct RollCallRatingPolicy {
    static let maxAutomaticAttempts = 2
    static let secondOpportunityDays = 30

    static func distinctLocalDates(_ dates: [Date], calendar: Calendar = .current) -> [Date] {
        var seen = Set<DateComponents>()
        return dates.filter { seen.insert(calendar.dateComponents([.era, .year, .month, .day], from: $0)).inserted }
    }

    static func localDateKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return "\(components.era ?? 0)-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    static func distinctProbableGameDateCount(for rating: TelemetryRatingState, calendar: Calendar = .current) -> Int {
        if !rating.probableGameDateKeys.isEmpty {
            return Set(rating.probableGameDateKeys).count
        }
        return distinctLocalDates(rating.distinctProbableGameDates, calendar: calendar).count
    }

    static func bucket(for count: Int) -> String {
        switch count {
        case 0: return "0"
        case 1: return "1"
        case 2...4: return "2-4"
        case 5...9: return "5-9"
        default: return "10+"
        }
    }

    static func daysBucket(from enrollment: Date, to now: Date) -> String {
        let days = max(0, Int(floor(now.timeIntervalSince(enrollment) / 86_400)))
        switch days {
        case ..<7: return "<7"
        case 7...13: return "7-13"
        case 14...29: return "14-29"
        case 30...89: return "30-89"
        default: return "90+"
        }
    }

    static func automaticOpportunity(for rating: TelemetryRatingState, now: Date) -> Int? {
        guard !rating.permanentlySuppressed, rating.automaticAttemptsConsumed < maxAutomaticAttempts else { return nil }
        let dateCount = distinctProbableGameDateCount(for: rating)
        if rating.automaticAttemptsConsumed == 0 {
            guard dateCount >= 2,
                  now.timeIntervalSince(rating.enrollmentDate) >= 7 * 86_400,
                  rating.presentationCooldownAnchor.map({ now.timeIntervalSince($0) >= 30 * 86_400 }) ?? true else { return nil }
            return 1
        }
        guard dateCount >= 5,
              let cooldownAnchor = rating.presentationCooldownAnchor ?? rating.firstSheetShownAt,
              now.timeIntervalSince(cooldownAnchor) >= 30 * 86_400 else { return nil }
        return 2
    }
}

enum PlaybackComponent: String, Codable { case announcement, primaryCue }
enum PlaybackSourceFamily: String, Codable, CaseIterable {
    case musicLibrary, appleMusicCatalog, appleMusicPreview, generatedLocal, importedLocal, builtinIntentional
    case recordedAnnouncement, builtin, unknown
}
enum PlaybackFailureReason: String, Codable, CaseIterable {
    case missingAsset, unreadableAsset, authorization, subscription, sourceUnavailable
    case startRejected, startTimedOut, playbackError, unknown
}
struct PlaybackStartConfirmation: Equatable {
    enum Outcome: Equatable { case started, failed(PlaybackFailureReason), cancelled }
    let requestID: UUID
    let component: PlaybackComponent
    let sourceFamily: PlaybackSourceFamily
    let outcome: Outcome
}
struct PlaybackRequestResult: Equatable {
    let requestID: UUID
    let confirmations: [PlaybackStartConfirmation]
    let wasDebounced: Bool

    var hasStartedComponent: Bool {
        confirmations.contains { if case .started = $0.outcome { return true }; return false }
    }
}

// MARK: - Live probable-game state machine

struct LiveAnalyticsSessionReducer {
    static let timeout: TimeInterval = 60 * 60
    static let minimumSpan: TimeInterval = 15 * 60
    static let minimumGap: TimeInterval = 3 * 60

    static func accepting(
        checkpoint: LiveAnalyticsCheckpoint?,
        selectedTeamID: UUID,
        now: Date,
        useWallClockTimeout: Bool = true
    ) -> LiveAnalyticsCheckpoint? {
        guard let checkpoint,
              checkpoint.selectedTeamID == selectedTeamID,
              checkpoint.qualifyingCueCount >= 0,
              checkpoint.distinctPlayerIDs.count <= checkpoint.qualifyingCueCount,
              checkpoint.latestMeaningfulActivityAt <= now,
              (!useWallClockTimeout || now.timeIntervalSince(checkpoint.latestMeaningfulActivityAt) <= timeout),
              checkpoint.latestQualifyingCueAt <= now,
              checkpoint.firstQualifyingCueAt <= checkpoint.latestQualifyingCueAt,
              checkpoint.probableGameDate.map({ $0 <= now }) ?? true,
              !checkpoint.didQualify || checkpoint.probableGameDate != nil else { return nil }
        return checkpoint
    }

    static func playerCue(
        checkpoint: inout LiveAnalyticsCheckpoint?,
        teamID: UUID,
        playerID: UUID,
        now: Date,
        sourceFamily: PlaybackSourceFamily,
        useWallClockTimeout: Bool = true
    ) -> Bool {
        if let current = checkpoint,
           let valid = accepting(checkpoint: current, selectedTeamID: teamID, now: now, useWallClockTimeout: useWallClockTimeout) {
            guard now >= valid.latestQualifyingCueAt else { return false }
            checkpoint = valid
            if valid.qualifyingCueCount == 0 {
                checkpoint?.firstQualifyingCueAt = now
                checkpoint?.latestQualifyingCueAt = now
                checkpoint?.latestMeaningfulActivityAt = now
                checkpoint?.distinctPlayerIDs = [playerID]
                checkpoint?.qualifyingCueCount = 1
                return false
            }
            let gap = now.timeIntervalSince(valid.latestQualifyingCueAt)
            checkpoint?.hasThreeMinuteGap = valid.hasThreeMinuteGap || gap >= minimumGap
            checkpoint?.latestQualifyingCueAt = now
            checkpoint?.latestMeaningfulActivityAt = now
            checkpoint?.distinctPlayerIDs.insert(playerID)
            checkpoint?.qualifyingCueCount += 1
        } else {
            checkpoint = LiveAnalyticsCheckpoint(
                selectedTeamID: teamID,
                firstQualifyingCueAt: now,
                latestQualifyingCueAt: now,
                distinctPlayerIDs: [playerID],
                qualifyingCueCount: 1,
                hasThreeMinuteGap: false,
                latestMeaningfulActivityAt: now,
                bufferedRecoveryKeys: [],
                bufferedCompleteFailureKeys: [],
                emittedFeatureKeys: [],
                didQualify: false,
                probableGameDate: nil, probableGameDateKey: nil
            )
        }
        return qualifies(checkpoint: checkpoint!)
    }

    static func meaningfulActivity(
        checkpoint: inout LiveAnalyticsCheckpoint,
        teamID: UUID,
        now: Date,
        useWallClockTimeout: Bool = true
    ) {
        guard let valid = accepting(checkpoint: checkpoint, selectedTeamID: teamID, now: now, useWallClockTimeout: useWallClockTimeout) else { return }
        checkpoint = valid
        checkpoint.latestMeaningfulActivityAt = now
    }

    static func qualifies(checkpoint: LiveAnalyticsCheckpoint) -> Bool {
        checkpoint.qualifyingCueCount >= 4
            && checkpoint.distinctPlayerIDs.count >= 3
            && checkpoint.latestQualifyingCueAt.timeIntervalSince(checkpoint.firstQualifyingCueAt) >= minimumSpan
            && checkpoint.hasThreeMinuteGap
    }
}

// MARK: - Coordinator

@MainActor
final class RollCallTelemetryCoordinator {
    let provider: RollCallTelemetryProvider
    let store: TelemetryStore
    let preference: AnonymousUsageAnalyticsPreference
    let buildContext: TelemetryBuildContext
    private(set) var ordinaryRecordingGate: Bool
    private(set) var persistenceFailureReported = false
    private var monotonicActivityDeadline: ContinuousClock.Instant?
    private var recoveryReported = false
    private var volatileManualRatingPresentation: PendingRatingPresentation?
    private var pendingAsyncPersistenceCount = 0
    private var pendingAsyncSignals: [(generation: Int, event: RollCallTelemetryEvent, properties: [RollCallTelemetryProperty: String])] = []
    private var asyncPersistenceFailed = false
    private var persistenceGeneration = 0
    private var lastDurableState: TelemetryStoreState
    private var nextPersistenceRevision = 0
    private var lastDurableRevision = 0
    private let maximumPendingAsyncPersistences = 32
    private let maximumPendingAsyncSignals = 256

    init(
        provider: RollCallTelemetryProvider,
        store: TelemetryStore,
        preference: AnonymousUsageAnalyticsPreference = AnonymousUsageAnalyticsPreference(defaults: .standard),
        buildContext: TelemetryBuildContext = .current
    ) {
        // Preference is intentionally read before any SDK configuration or
        // initialization. A disabled installation never initializes enabled.
        self.provider = provider
        self.store = store
        self.preference = preference
        self.buildContext = buildContext
        self.ordinaryRecordingGate = preference.isEnabled
        self.lastDurableState = store.state
        provider.configure(enabled: ordinaryRecordingGate, context: buildContext)
        if store.status == .recovered, !persistSynchronously() {
            suspendAfterPersistenceFailure()
        }
        recoverUnresolvedPresentationIfNeeded(now: .now)
    }

    var isAvailableForProductPolicy: Bool {
        !store.state.suspended && store.status != .unsupported && store.status != .unavailable
    }

    var analyticsEnabled: Bool { preference.isEnabled }

    var ratingSnapshot: TelemetryPolicySnapshot {
        TelemetryPolicySnapshot(
            probableGameDateCount: RollCallRatingPolicy.distinctProbableGameDateCount(for: store.state.rating),
            automaticAttemptsConsumed: store.state.rating.automaticAttemptsConsumed,
            permanentlySuppressed: store.state.rating.permanentlySuppressed,
            firstSheetShownAt: store.state.rating.firstSheetShownAt
        )
    }

    var canPresentAutomaticRatingRequest: Bool {
        buildContext.isAppStoreBuild
            && isAvailableForProductPolicy
            && RollCallRatingPolicy.automaticOpportunity(for: store.state.rating, now: .now) != nil
    }

    func enroll(currentState: AppState) {
        guard store.status == .new else {
            reportStoreRecoveredIfNeeded()
            return
        }
        let existingInstall = !currentState.teams.isEmpty || currentState.onboarding.isComplete
        var candidate = store.state
        candidate.enrollmentCohort = existingInstall ? "existingInstall" : "newInstall"
        if currentState.ratingRequest.automaticPromptAttemptCount > 0 {
            candidate.rating.automaticAttemptsConsumed = min(2, max(0, currentState.ratingRequest.automaticPromptAttemptCount))
            if candidate.rating.automaticAttemptsConsumed == 1 {
                // Legacy state has no trustworthy sheet timestamp. The policy
                // migration date is the conservative second-opportunity anchor.
                candidate.rating.presentationCooldownAnchor = candidate.rating.enrollmentDate
            }
        }
        store.state = candidate
        recordBaseline(baselineSignals(from: currentState))
    }

    private func baselineSignals(from state: AppState) -> [BaselineSignal] {
        var signals: [BaselineSignal] = []
        func add(
            _ event: RollCallTelemetryEvent,
            _ properties: [RollCallTelemetryProperty: String] = [:],
            key: String? = nil,
            teamID: UUID? = nil
        ) {
            signals.append(BaselineSignal(event: event, properties: properties, key: key, teamID: teamID))
        }

        if state.onboarding.isComplete || state.onboarding.activeFlow != nil { add(.onboardingStarted) }
        if state.onboarding.isComplete { add(.onboardingCompleted) }
        if state.onboarding.activeFlow == .importHandoff { add(.onboardingImportPathUsed) }
        if state.onboarding.didChooseCheerFallback { add(.onboardingCheerFallbackChosen) }

        let maxRoster = state.teams.map { $0.players.count }.max() ?? 0
        for (count, event) in [(3, RollCallTelemetryEvent.rosterPlayerCount3), (5, .rosterPlayerCount5), (10, .rosterPlayerCount10), (15, .rosterPlayerCount15)] where maxRoster >= count {
            add(event)
        }
        for (count, event) in [(2, RollCallTelemetryEvent.teamsActiveCount2), (3, .teamsActiveCount3)] where state.teams.count >= count {
            add(event)
        }
        if state.teams.contains(where: isPersonalized) { add(.teamPersonalized) }
        if state.teams.contains(where: { $0.players.contains(where: { $0.photoRelativePath != nil }) }) { add(.playerPhotoFirstAdded) }
        if state.teams.contains(where: { $0.players.contains(where: { $0.customAnnouncerRelativePath != nil }) }) { add(.announcementFirstRecorded) }
        for team in state.teams {
            for player in team.players {
                guard let clip = team.songClip(for: player) else { continue }
                if let event = mediaAssignmentEvent(for: clip.originalSource) {
                    add(event)
                }
                if clip.sourceLineageClipID != nil { add(.mediaClipReuseFirstUsed) }
            }
        }
        if state.teams.contains(where: { !$0.teamClips.isEmpty }) { add(.clipsFirstCustomCreated) }
        if state.trimDefaults.preferredLength != 12 {
            let value: String
            switch state.trimDefaults.preferredLength {
            case 6: value = "6"
            case 8: value = "8"
            case 10: value = "10"
            case 15: value = "15"
            case let length where length < 12: value = "customShorterThan12"
            default: value = "customLongerThan12"
            }
            add(.trimPreferredLengthFirstChanged, [.newLength: value])
        }
        for team in state.teams where team.accentPreset != .rollCallOrange {
            add(.teamAccentFirstChanged, [.newAccent: accentValue(team.accentPreset)], teamID: team.id)
        }
        for team in state.teams where team.session.gameDayAnnouncerMode != .announcerAndSong {
            add(.announcerModeFirstChanged, [.newMode: team.session.gameDayAnnouncerMode.rawValue], teamID: team.id)
        }
        if !state.settings.explicitAppleMusicSearchFilteringEnabled { add(.settingExplicitFilterFirstChanged, [.newValue: "off"]) }
        if state.settings.fadeOutVolumeAutomationEnabled { add(.settingVolumeAutomationFirstChanged, [.newValue: "on"]) }
        if !state.settings.alwaysUseDarkLiveMode { add(.settingDarkLiveScreensFirstChanged, [.newValue: "off"]) }
        if state.settings.keepScreenAwakeDuringLiveUse { add(.settingKeepScreenAwakeFirstChanged, [.newValue: "on"]) }
        return signals
    }

    private func isPersonalized(_ team: Team) -> Bool {
        let present = team.players.filter(\.isPresent)
        guard present.count >= 3 else { return false }
        let personalized = present.filter { player in
            if player.customAnnouncerRelativePath != nil { return true }
            guard let clip = team.songClip(for: player) else { return false }
            if case .builtInClip = clip.playbackCue.source { return false }
            return true
        }.count
        return personalized * 4 >= present.count * 3
    }

    private func accentValue(_ accent: TeamAccentPreset) -> String {
        accent == .rollCallOrange ? "orange" : accent.rawValue
    }

    private func mediaAssignmentEvent(for source: SongSource) -> RollCallTelemetryEvent? {
        // Derived from the one shared classifier so this milestone cannot drift from
        // how playback and recovery report the same cue. It used to carry its own
        // copy of the predicate, which made `.mediaFirstAssignedMusicLibrary`
        // unreachable — Music Library picks were all counted as catalog assignments.
        switch source.cueSource.playbackSourceFamily {
        case .musicLibrary:
            return .mediaFirstAssignedMusicLibrary
        case .appleMusicCatalog, .appleMusicPreview:
            return .mediaFirstAssignedAppleMusicCatalog
        case .importedLocal, .generatedLocal:
            return .mediaFirstAssignedImportedLocal
        case .builtin, .builtinIntentional, .recordedAnnouncement, .unknown:
            return nil
        }
    }

    func recordRosterMilestones(for state: AppState) {
        let maximum = state.teams.map { $0.players.count }.max() ?? 0
        for (count, event) in [(3, RollCallTelemetryEvent.rosterPlayerCount3), (5, .rosterPlayerCount5), (10, .rosterPlayerCount10), (15, .rosterPlayerCount15)] where maximum >= count {
            recordOnce(event)
        }
        if state.teams.count >= 2 { recordOnce(.teamsActiveCount2) }
        if state.teams.count >= 3 { recordOnce(.teamsActiveCount3) }
        if state.teams.contains(where: isPersonalized) { recordOnce(.teamPersonalized) }
    }

    func recordPersonalizationChanges(from old: Player, to new: Player, state: AppState) {
        if old.photoRelativePath == nil, new.photoRelativePath != nil { recordOnce(.playerPhotoFirstAdded) }
        if old.customAnnouncerRelativePath == nil, new.customAnnouncerRelativePath != nil { recordOnce(.announcementFirstRecorded) }
        guard old.songAssignment != new.songAssignment,
              let team = state.teams.first(where: { $0.players.contains(where: { $0.id == new.id }) }),
              let clip = team.songClip(for: new) else { return }
        if let event = mediaAssignmentEvent(for: clip.originalSource) {
            recordOnce(event)
        }
        if clip.sourceLineageClipID != nil { recordOnce(.mediaClipReuseFirstUsed) }
    }

    func recordRepairNeeded(category: String, asynchronousPersistence: Bool = false) {
        guard isRepairCategory(category) else { return }
        recordOnce(
            .repairFirstNeeded,
            properties: [.category: category],
            key: "repairNeeded|\(category)",
            asynchronousPersistence: asynchronousPersistence
        )
    }

    func recordRepairAttempted(category: String) {
        guard isRepairCategory(category), isAvailableForProductPolicy else { return }
        var candidate = store.state
        guard candidate.consumedInstallEvents.insert("repairAttempted|\(category)").inserted else { return }
        guard persistSynchronously(candidate) else { suspendAfterPersistenceFailure(); return }
    }

    func recordRepairCompleted(category: String) {
        guard isRepairCategory(category), isAvailableForProductPolicy,
              store.state.consumedInstallEvents.contains("repairAttempted|\(category)") else { return }
        recordOnce(.repairFirstCompleted, properties: [.category: category], key: "repairCompleted|\(category)")
    }

    private func isRepairCategory(_ category: String) -> Bool {
        ["playerMedia", "announcement", "customClip", "appleMusicAccess", "importedPackageMedia"].contains(category)
    }

    func recordPackageExportCompleted() {
        guard isAvailableForProductPolicy else { return }
        var candidate = store.state
        candidate.packageExportCount += 1
        let crossedFirst = candidate.packageExportCount == 1
            && !candidate.consumedInstallEvents.contains(RollCallTelemetryEvent.packageFirstExport.rawValue)
        let crossedFifth = candidate.packageExportCount >= 5
            && !candidate.consumedInstallEvents.contains(RollCallTelemetryEvent.packageExportCount5.rawValue)
        if crossedFirst {
            candidate.consumedInstallEvents.insert(RollCallTelemetryEvent.packageFirstExport.rawValue)
            if !ordinaryRecordingGate { candidate.suppressedEvents.insert(RollCallTelemetryEvent.packageFirstExport.rawValue) }
        }
        if crossedFifth {
            candidate.consumedInstallEvents.insert(RollCallTelemetryEvent.packageExportCount5.rawValue)
            if !ordinaryRecordingGate { candidate.suppressedEvents.insert(RollCallTelemetryEvent.packageExportCount5.rawValue) }
        }
        guard persistSynchronously(candidate) else { suspendAfterPersistenceFailure(); return }
        if crossedFirst { record(.packageFirstExport) }
        if crossedFifth { record(.packageExportCount5) }
    }

    func recordPackageImportCompleted(hadMissingMedia: Bool) {
        guard isAvailableForProductPolicy else { return }
        var candidate = store.state
        candidate.packageImportCount += 1
        let crossedFirst = candidate.packageImportCount == 1
            && !candidate.consumedInstallEvents.contains(RollCallTelemetryEvent.packageFirstImport.rawValue)
        let crossedFifth = candidate.packageImportCount >= 5
            && !candidate.consumedInstallEvents.contains(RollCallTelemetryEvent.packageImportCount5.rawValue)
        if crossedFirst {
            candidate.consumedInstallEvents.insert(RollCallTelemetryEvent.packageFirstImport.rawValue)
            if !ordinaryRecordingGate { candidate.suppressedEvents.insert(RollCallTelemetryEvent.packageFirstImport.rawValue) }
        }
        if crossedFifth {
            candidate.consumedInstallEvents.insert(RollCallTelemetryEvent.packageImportCount5.rawValue)
            if !ordinaryRecordingGate { candidate.suppressedEvents.insert(RollCallTelemetryEvent.packageImportCount5.rawValue) }
        }
        guard persistSynchronously(candidate) else { suspendAfterPersistenceFailure(); return }
        if crossedFirst { record(.packageFirstImport, properties: [.hadMissingMedia: hadMissingMedia ? "true" : "false"]) }
        if crossedFifth { record(.packageImportCount5) }
    }

    func recordPlaylistSyncSuccess(teamID: UUID) {
        guard isAvailableForProductPolicy else { return }
        let teamKey = "playlistSync|\(teamID.uuidString)"
        var candidate = store.state
        guard candidate.consumedTeamEvents.insert(teamKey).inserted else { return }
        let teamCount = candidate.consumedTeamEvents.filter { $0.hasPrefix("playlistSync|") }.count
        let isFirst = !candidate.consumedInstallEvents.contains(RollCallTelemetryEvent.playlistSyncFirstUsed.rawValue)
        let isMultiple = teamCount >= 2 && !candidate.consumedInstallEvents.contains(RollCallTelemetryEvent.playlistSyncUsedInMultipleTeams.rawValue)
        if isFirst { candidate.consumedInstallEvents.insert(RollCallTelemetryEvent.playlistSyncFirstUsed.rawValue) }
        if isMultiple { candidate.consumedInstallEvents.insert(RollCallTelemetryEvent.playlistSyncUsedInMultipleTeams.rawValue) }
        if !ordinaryRecordingGate || !isAvailableForProductPolicy {
            if isFirst { candidate.suppressedEvents.insert(RollCallTelemetryEvent.playlistSyncFirstUsed.rawValue) }
            if isMultiple { candidate.suppressedEvents.insert(RollCallTelemetryEvent.playlistSyncUsedInMultipleTeams.rawValue) }
        }
        guard persistSynchronously(candidate) else { suspendAfterPersistenceFailure(); return }
        if isFirst { record(.playlistSyncFirstUsed) }
        if isMultiple { record(.playlistSyncUsedInMultipleTeams) }
    }

    func setAnalyticsEnabled(_ enabled: Bool) {
        guard enabled != preference.isEnabled else { return }
        persistenceGeneration += 1
        if !enabled {
            ordinaryRecordingGate = false
            preference.persist(false)
            sendNarrowPreferenceTransition("off")
            provider.configure(enabled: false, context: buildContext)
        } else {
            preference.persist(true)
            provider.configure(enabled: true, context: buildContext)
            sendNarrowPreferenceTransition("on")
            ordinaryRecordingGate = isAvailableForProductPolicy
        }
    }

    func record(
        _ event: RollCallTelemetryEvent,
        properties: [RollCallTelemetryProperty: String] = [:]
    ) {
        guard ordinaryRecordingGate, isAvailableForProductPolicy else { return }
        if pendingAsyncPersistenceCount > 0 {
            guard pendingAsyncSignals.count < maximumPendingAsyncSignals else {
                suspendAfterAsyncPersistenceFailure()
                return
            }
            pendingAsyncSignals.append((persistenceGeneration, event, properties))
            return
        }
        recordImmediately(event, properties: properties)
    }

    private func recordImmediately(
        _ event: RollCallTelemetryEvent,
        properties: [RollCallTelemetryProperty: String] = [:]
    ) {
        guard ordinaryRecordingGate, isAvailableForProductPolicy else { return }
        var validatedProperties = properties
        validatedProperties[.telemetrySchemaVersion] = "1"
        let signal: RollCallTelemetrySignal
        do {
            signal = try RollCallTelemetryValidator.shared.validate(event: event, properties: validatedProperties)
        } catch {
            // Failing closed is correct in the field — a malformed signal must never
            // ship. But swallowing it silently is how `state.recoveryTriggered` went
            // unemitted for a whole release: the call site passed a property the
            // allowlist did not grant, and nothing surfaced it. Make the mismatch
            // loud in development while keeping shipping builds fail-closed.
            assertionFailureForTelemetryValidation(event: event, properties: validatedProperties, error: error)
            return
        }
        provider.send(signal)
    }

    /// Keeps legacy synchronous callers on the same serial writer and
    /// advances the coordinator's durable rollback baseline only after the
    /// write has succeeded. The revision prevents an older async completion
    /// from restoring over a newer synchronous write.
    @discardableResult
    private func persistSynchronously(_ candidate: TelemetryStoreState? = nil) -> Bool {
        let value = candidate ?? store.state
        nextPersistenceRevision += 1
        let revision = nextPersistenceRevision
        guard store.save(value) else { return false }
        if revision > lastDurableRevision {
            lastDurableState = value
            lastDurableRevision = revision
        }
        return true
    }

    /// Stages a live-use snapshot immediately, then persists it on the serial
    /// background writer. Signals recorded while this snapshot is pending are
    /// held until the write succeeds, preserving persist-before-send.
    @discardableResult
    private func persistLive(_ candidate: TelemetryStoreState) -> Bool {
        guard !asyncPersistenceFailed,
              pendingAsyncPersistenceCount < maximumPendingAsyncPersistences else {
            if pendingAsyncPersistenceCount >= maximumPendingAsyncPersistences {
                suspendAfterAsyncPersistenceFailure()
            }
            return false
        }
        nextPersistenceRevision += 1
        let revision = nextPersistenceRevision
        store.state = candidate
        pendingAsyncPersistenceCount += 1
        store.saveAsync(candidate) { [weak self] didSave in
            guard let self else { return }
            self.pendingAsyncPersistenceCount = max(0, self.pendingAsyncPersistenceCount - 1)
            guard didSave, !self.asyncPersistenceFailed else {
                self.suspendAfterAsyncPersistenceFailure()
                return
            }
            if revision > self.lastDurableRevision {
                self.lastDurableState = candidate
                self.lastDurableRevision = revision
            }
            guard self.pendingAsyncPersistenceCount == 0 else { return }
            let generation = self.persistenceGeneration
            let signals = self.pendingAsyncSignals
            self.pendingAsyncSignals.removeAll()
            for pending in signals where pending.generation == generation {
                self.recordImmediately(pending.event, properties: pending.properties)
            }
        }
        return true
    }

    private func suspendAfterAsyncPersistenceFailure() {
        guard !asyncPersistenceFailed else { return }
        asyncPersistenceFailed = true
        persistenceGeneration += 1
        pendingAsyncSignals.removeAll()
        store.blockAsyncPersistenceAfterFailure()
        store.state = lastDurableState
        suspendAfterPersistenceFailure()
    }

    /// Allows focused tests to wait for the serial writer and its main-actor
    /// completion callbacks without making production playback async.
    func waitForPendingPersistenceForTesting() async {
        await store.waitForPendingWrites()
        while pendingAsyncPersistenceCount > 0 {
            await Task.yield()
        }
    }

    func recordOnce(
        _ event: RollCallTelemetryEvent,
        properties: [RollCallTelemetryProperty: String] = [:],
        key: String? = nil,
        teamID: UUID? = nil,
        gameKey: String? = nil,
        asynchronousPersistence: Bool = false
    ) {
        guard store.status != .unsupported,
              store.status != .unavailable,
              !store.state.suspended else { return }
        if store.state.conservativeHistoryConsumed {
            // Recovery cannot prove whether a prior one-time install/team
            // milestone was already earned. Game-scoped events remain
            // available because each newly qualified game is independently
            // observable.
            guard gameKey != nil else { return }
        }
        let identity = key ?? event.rawValue
        var candidate = store.state
        let alreadyConsumed: Bool
        if let teamID {
            alreadyConsumed = candidate.consumedTeamEvents.contains("\(teamID.uuidString)|\(identity)")
        } else if let gameKey {
            alreadyConsumed = candidate.consumedGameEvents.contains("\(gameKey)|\(identity)")
        } else {
            alreadyConsumed = candidate.consumedInstallEvents.contains(identity)
        }
        guard !alreadyConsumed else { return }
        if let teamID {
            candidate.consumedTeamEvents.insert("\(teamID.uuidString)|\(identity)")
        } else if let gameKey {
            candidate.consumedGameEvents.insert("\(gameKey)|\(identity)")
        } else {
            candidate.consumedInstallEvents.insert(identity)
        }
        if !ordinaryRecordingGate || !isAvailableForProductPolicy {
            candidate.suppressedEvents.insert(identity)
        }
        if asynchronousPersistence {
            guard persistLive(candidate) else { return }
        } else {
            guard persistSynchronously(candidate) else {
                suspendAfterPersistenceFailure()
                return
            }
        }
        guard ordinaryRecordingGate, isAvailableForProductPolicy else { return }
        record(event, properties: properties)
    }

    private struct BaselineSignal {
        let event: RollCallTelemetryEvent
        let properties: [RollCallTelemetryProperty: String]
        let key: String?
        let teamID: UUID?

        var localIdentity: String {
            key ?? event.rawValue
        }

        var deDuplicationIdentity: String {
            if let teamID {
                return "\(teamID.uuidString)|\(localIdentity)"
            }
            return localIdentity
        }
    }

    private func recordBaseline(_ signals: [BaselineSignal]) {
        guard store.status != .unsupported,
              store.status != .unavailable,
              !store.state.suspended else { return }
        guard !store.state.baselineCompleted else { return }
        var uniqueSignals: [BaselineSignal] = []
        var seen = Set<String>()
        for signal in signals where seen.insert(signal.deDuplicationIdentity).inserted {
            uniqueSignals.append(signal)
        }
        var candidate = store.state
        candidate.baselineCompleted = true
        for signal in uniqueSignals {
            if signal.teamID != nil {
                candidate.consumedTeamEvents.insert(signal.deDuplicationIdentity)
            } else {
                candidate.consumedInstallEvents.insert(signal.localIdentity)
            }
        }
        if !ordinaryRecordingGate || !isAvailableForProductPolicy {
            candidate.suppressedEvents.formUnion(uniqueSignals.map(\.deDuplicationIdentity))
        }
        guard persistSynchronously(candidate) else { suspendAfterPersistenceFailure(); return }
        guard ordinaryRecordingGate, isAvailableForProductPolicy else { return }
        for signal in uniqueSignals {
            record(
                signal.event,
                properties: signal.properties.merging([.observationOrigin: "enrollmentBaseline"]) { current, _ in current }
            )
        }
    }

    func reportStoreRecoveredIfNeeded() {
        guard !recoveryReported,
              store.status == .recovered,
              store.state.schemaVersion == TelemetryStoreState.currentSchemaVersion else { return }
        guard persistSynchronously() else { suspendAfterPersistenceFailure(); return }
        recoveryReported = true
        record(.telemetryStateRecovered)
    }

    func suspendAfterPersistenceFailure() {
        store.state.suspended = true
        ordinaryRecordingGate = false
        if !persistenceFailureReported, preference.isEnabled {
            persistenceFailureReported = true
            sendNarrow(.telemetryStatePersistenceFailed)
        }
    }

    func retryPersistence() -> Bool {
        guard pendingAsyncPersistenceCount == 0 else { return false }
        var candidate = store.state
        candidate.suspended = false
        store.resetAsyncPersistenceAfterFailure()
        guard persistSynchronously(candidate) else { return false }
        asyncPersistenceFailed = false
        lastDurableState = candidate
        ordinaryRecordingGate = preference.isEnabled
        return true
    }

    func observeRetentionActivation(at now: Date, wasAlreadyActive: Bool) {
        guard isAvailableForProductPolicy else { return }
        guard !wasAlreadyActive else { return }
        let milestones: [(TimeInterval, RollCallTelemetryEvent)] = [
            (1 * 86_400, .retentionDay1), (7 * 86_400, .retentionDay7),
            (30 * 86_400, .retentionDay30), (90 * 86_400, .retentionDay90),
            (180 * 86_400, .retentionDay180), (365 * 86_400, .retentionDay365)
        ]
        for (threshold, event) in milestones where now.timeIntervalSince(store.state.enrollmentDate) >= threshold {
            guard !store.state.retentionEvents.contains(event.rawValue) else { continue }
            var candidate = store.state
            candidate.retentionEvents.insert(event.rawValue)
            if !ordinaryRecordingGate { candidate.suppressedEvents.insert(event.rawValue) }
            guard persistSynchronously(candidate) else { suspendAfterPersistenceFailure(); return }
            record(event, properties: [.enrollmentCohort: store.state.enrollmentCohort])
        }
        observeRatingEligibility(at: now)
    }

    func observeRatingEligibility(at now: Date = .now) {
        guard isAvailableForProductPolicy else { return }
        guard let opportunity = RollCallRatingPolicy.automaticOpportunity(for: store.state.rating, now: now),
              !store.state.rating.eligibilityEmittedForAttempts.contains(opportunity) else { return }
        var candidate = store.state
        candidate.rating.eligibilityEmittedForAttempts.insert(opportunity)
        if !ordinaryRecordingGate { candidate.suppressedEvents.insert(RollCallTelemetryEvent.ratingBecameEligible.rawValue) }
        let properties: [RollCallTelemetryProperty: String] = [
            .qualifiedGameBucket: RollCallRatingPolicy.bucket(for: RollCallRatingPolicy.distinctProbableGameDateCount(for: candidate.rating)),
            .daysSincePolicyEnrollmentBucket: RollCallRatingPolicy.daysBucket(from: candidate.rating.enrollmentDate, to: now),
            .enrollmentCohort: candidate.enrollmentCohort,
            .automaticAttemptNumber: String(opportunity),
            .ratingPolicyVersion: "1"
        ]
        guard persistSynchronously(candidate) else { suspendAfterPersistenceFailure(); return }
        record(.ratingBecameEligible, properties: properties)
    }

    func beginLiveSessionIfNeeded(teamID: UUID, now: Date = .now) {
        guard isAvailableForProductPolicy else { return }
        if store.state.liveCheckpoint?.selectedTeamID != teamID {
            handleTeamBoundaryChange()
        }
        recordOnce(.liveEntered, asynchronousPersistence: true)
        guard store.state.liveCheckpoint == nil else { return }
        // Entering a surface is not meaningful activity, so no checkpoint is created here.
        _ = now
    }

    func handleTeamBoundaryChange() {
        guard store.status != .unsupported, store.status != .unavailable else { return }
        _ = clearLiveCheckpoint()
    }

    func validateLiveCheckpoint(availableTeamIDs: Set<UUID>, selectedTeamID: UUID?) {
        guard store.status != .unsupported, store.status != .unavailable else { return }
        guard let checkpoint = store.state.liveCheckpoint else { return }
        guard availableTeamIDs.contains(checkpoint.selectedTeamID), checkpoint.selectedTeamID == selectedTeamID else {
            handleTeamBoundaryChange()
            return
        }
        let now = Date.now
        guard let accepted = LiveAnalyticsSessionReducer.accepting(checkpoint: checkpoint, selectedTeamID: checkpoint.selectedTeamID, now: now) else {
            handleTeamBoundaryChange()
            return
        }
        let remaining = max(0, LiveAnalyticsSessionReducer.timeout - now.timeIntervalSince(accepted.latestMeaningfulActivityAt))
        monotonicActivityDeadline = ContinuousClock().now.advanced(by: .seconds(remaining))
    }

    private func acceptMonotonicActivity() -> Bool {
        let now = ContinuousClock().now
        if let deadline = monotonicActivityDeadline, now > deadline {
            var candidate = store.state
            candidate.liveCheckpoint = nil
            guard persistLive(candidate) else { return false }
            monotonicActivityDeadline = nil
        }
        monotonicActivityDeadline = now.advanced(by: .seconds(Int64(LiveAnalyticsSessionReducer.timeout)))
        return true
    }

    private func expireMonotonicCheckpointIfNeeded() -> Bool {
        guard let deadline = monotonicActivityDeadline,
              ContinuousClock().now > deadline else { return true }
        var candidate = store.state
        candidate.liveCheckpoint = nil
        guard persistLive(candidate) else { return false }
        monotonicActivityDeadline = nil
        return false
    }

    @discardableResult
    private func clearLiveCheckpoint() -> Bool {
        monotonicActivityDeadline = nil
        guard store.state.liveCheckpoint != nil else { return true }
        var candidate = store.state
        candidate.liveCheckpoint = nil
        guard persistLive(candidate) else { return false }
        return true
    }

    /// Records one confirmed player cue against the live analytics session.
    ///
    /// - Returns: whether the cue was **accepted for ordered persistence** — not
    ///   whether it qualified a probable game. Live persistence is intentionally
    ///   nonblocking; dependent signals are released only after the snapshot is
    ///   durable. A single confirmed cue returns `true` even though four are
    ///   required to qualify. Rejections (uncorrelated request id, no confirmed
    ///   start, cancelled, debounced, wrong team, stale checkpoint) return `false`.
    ///   Probable-game qualification is observable only through the emitted
    ///   `game.probable` signal and `probableGameDates`, never from here.
    @discardableResult
    func handlePlayerPlayback(
        teamID: UUID,
        playerID: UUID,
        result: PlaybackRequestResult,
        now: Date = .now,
        gameProperties: [RollCallTelemetryProperty: String] = [:],
        playbackMode: String? = nil
    ) -> Bool {
        guard isAvailableForProductPolicy else { return false }
        guard let start = result.confirmations.first(where: {
            if case .started = $0.outcome { return true }; return false
        }) else { return false }
        guard start.requestID == result.requestID else { return false }
        let useWallClockTimeout = monotonicActivityDeadline == nil
        guard acceptMonotonicActivity() else { return false }
        var candidate = store.state
        var checkpoint = candidate.liveCheckpoint
        if let current = checkpoint {
            guard current.selectedTeamID == teamID else {
                _ = clearLiveCheckpoint()
                return false
            }
            guard now >= current.latestQualifyingCueAt,
                  now >= current.latestMeaningfulActivityAt else {
                _ = clearLiveCheckpoint()
                return false
            }
            if LiveAnalyticsSessionReducer.accepting(
                checkpoint: current,
                selectedTeamID: teamID,
                now: now,
                useWallClockTimeout: useWallClockTimeout
            ) == nil {
                checkpoint = nil
            }
        }
        let wasProbable = checkpoint?.didQualify == true
        let qualified = LiveAnalyticsSessionReducer.playerCue(
            checkpoint: &checkpoint,
            teamID: teamID,
            playerID: playerID,
            now: now,
            sourceFamily: start.sourceFamily,
            useWallClockTimeout: useWallClockTimeout
        )
        candidate.liveCheckpoint = checkpoint
        if let mode = playbackMode, var checkpoint = candidate.liveCheckpoint {
            checkpoint.emittedFeatureKeys.insert("mode:\(mode)")
            candidate.liveCheckpoint = checkpoint
        }
        if result.confirmations.contains(where: { $0.component == .announcement && $0.outcome == .started }),
           var checkpoint = candidate.liveCheckpoint {
            checkpoint.emittedFeatureKeys.insert("announcementPlayed")
            candidate.liveCheckpoint = checkpoint
        }
        if var checkpoint = candidate.liveCheckpoint {
            checkpoint.emittedFeatureKeys.insert("source:\(start.sourceFamily.rawValue)")
            candidate.liveCheckpoint = checkpoint
        }
        candidate.successfulPlayerPlaybackCount += 1
        let depthThresholds: [(Int, RollCallTelemetryEvent)] = [
            (10, .playerPlaybackCount10), (50, .playerPlaybackCount50), (100, .playerPlaybackCount100),
            (250, .playerPlaybackCount250), (500, .playerPlaybackCount500), (1000, .playerPlaybackCount1000)
        ]
        var events: [(RollCallTelemetryEvent, [RollCallTelemetryProperty: String])] = []
        if !candidate.consumedInstallEvents.contains(RollCallTelemetryEvent.playerPlaybackFirstSuccessful.rawValue) {
            candidate.consumedInstallEvents.insert(RollCallTelemetryEvent.playerPlaybackFirstSuccessful.rawValue)
            if !ordinaryRecordingGate { candidate.suppressedEvents.insert(RollCallTelemetryEvent.playerPlaybackFirstSuccessful.rawValue) }
            events.append((.playerPlaybackFirstSuccessful, [:]))
        }
        for (threshold, event) in depthThresholds where candidate.successfulPlayerPlaybackCount >= threshold && !candidate.consumedInstallEvents.contains(event.rawValue) {
            candidate.consumedInstallEvents.insert(event.rawValue)
            if !ordinaryRecordingGate { candidate.suppressedEvents.insert(event.rawValue) }
            events.append((event, [:]))
        }
        if qualified && !wasProbable, var finalCheckpoint = candidate.liveCheckpoint {
            finalCheckpoint.didQualify = true
            let probableGameDateKey = RollCallRatingPolicy.localDateKey(for: now)
            finalCheckpoint.probableGameDate = now
            finalCheckpoint.probableGameDateKey = probableGameDateKey
            candidate.liveCheckpoint = finalCheckpoint
            candidate.probableGameDates.append(now)
            candidate.rating.distinctProbableGameDates.append(now)
            if !candidate.rating.probableGameDateKeys.contains(probableGameDateKey) {
                candidate.rating.probableGameDateKeys.append(probableGameDateKey)
            }
            let probableGameDateCount = RollCallRatingPolicy.distinctProbableGameDateCount(for: candidate.rating)
            var probableProperties: [RollCallTelemetryProperty: String] = [
                .accent: "orange", .volumeAutomation: "off", .keepScreenAwake: "off",
                .darkLiveScreens: "on", .gameHeuristicVersion: "1"
            ]
            for (property, value) in gameProperties { probableProperties[property] = value }
            events.append((.gameProbable, probableProperties))
            let dateMilestones: [(Int, RollCallTelemetryEvent)] = [
                (2, .gameMilestoneSecond), (5, .gameMilestoneFifth),
                (10, .gameMilestoneTenth), (25, .gameMilestoneTwentyFifth),
                (50, .gameMilestoneFiftieth)
            ]
            for (threshold, event) in dateMilestones
                where probableGameDateCount >= threshold
                    && !candidate.consumedInstallEvents.contains(event.rawValue) {
                candidate.consumedInstallEvents.insert(event.rawValue)
                if !ordinaryRecordingGate { candidate.suppressedEvents.insert(event.rawValue) }
                events.append((event, [:]))
            }
        }
        if let checkpoint = candidate.liveCheckpoint, checkpoint.didQualify {
            events.append(contentsOf: gameFeatureEvents(from: checkpoint, candidate: &candidate))
        }
        if let opportunity = RollCallRatingPolicy.automaticOpportunity(for: candidate.rating, now: now),
           !candidate.rating.eligibilityEmittedForAttempts.contains(opportunity) {
            candidate.rating.eligibilityEmittedForAttempts.insert(opportunity)
            events.append((.ratingBecameEligible, [
                .qualifiedGameBucket: RollCallRatingPolicy.bucket(for: RollCallRatingPolicy.distinctProbableGameDateCount(for: candidate.rating)),
                .daysSincePolicyEnrollmentBucket: RollCallRatingPolicy.daysBucket(from: candidate.rating.enrollmentDate, to: now),
                .enrollmentCohort: candidate.enrollmentCohort,
                .automaticAttemptNumber: String(opportunity),
                .ratingPolicyVersion: "1"
            ]))
        }
        guard persistLive(candidate) else { return false }
        for (event, properties) in events { record(event, properties: properties) }
        return true
    }

    /// Completes the feature-use portion of an announcer-then-song request.
    /// The announcement already established the single qualifying player cue;
    /// a later confirmed primary start only adds the actual source route.
    func handlePlaybackContinuation(
        teamID: UUID,
        confirmation: PlaybackStartConfirmation,
        playbackMode: String?,
        now: Date = .now
    ) {
        guard confirmation.component == .primaryCue,
              confirmation.outcome == .started,
              isAvailableForProductPolicy else { return }
        guard expireMonotonicCheckpointIfNeeded() else { return }
        let useWallClockTimeout = monotonicActivityDeadline == nil
        guard var checkpoint = store.state.liveCheckpoint else { return }
        guard checkpoint.selectedTeamID == teamID else {
            _ = clearLiveCheckpoint()
            return
        }
        guard LiveAnalyticsSessionReducer.accepting(
            checkpoint: checkpoint,
            selectedTeamID: teamID,
            now: now,
            useWallClockTimeout: useWallClockTimeout
        ) != nil else {
            _ = clearLiveCheckpoint()
            return
        }
        checkpoint.emittedFeatureKeys.insert("source:\(confirmation.sourceFamily.rawValue)")
        if let playbackMode {
            checkpoint.emittedFeatureKeys.insert("mode:\(playbackMode)")
        }
        var candidate = store.state
        candidate.liveCheckpoint = checkpoint
        let events = checkpoint.didQualify ? gameFeatureEvents(from: checkpoint, candidate: &candidate) : []
        guard persistLive(candidate) else { return }
        for (event, properties) in events { record(event, properties: properties) }
    }

    private func gameFeatureEvents(
        from checkpoint: LiveAnalyticsCheckpoint,
        candidate: inout TelemetryStoreState
    ) -> [(RollCallTelemetryEvent, [RollCallTelemetryProperty: String])] {
        guard var current = candidate.liveCheckpoint, current.selectedTeamID == checkpoint.selectedTeamID else { return [] }
        var events: [(RollCallTelemetryEvent, [RollCallTelemetryProperty: String])] = []
        func add(_ key: String, _ event: RollCallTelemetryEvent, _ properties: [RollCallTelemetryProperty: String] = [:]) {
            let emittedKey = "emitted:\(key)"
            guard !current.emittedFeatureKeys.contains(emittedKey) else { return }
            current.emittedFeatureKeys.insert(emittedKey)
            events.append((event, properties))
        }
        let featureKeys = current.emittedFeatureKeys
        for key in featureKeys {
            if key.hasPrefix("mode:") {
                let mode = String(key.dropFirst("mode:".count))
                guard ["announcerOnly", "announcerAndSong", "songOnly"].contains(mode) else { continue }
                add(key, .gamePlaybackModeUsed, [.mode: mode])
            } else if key.hasPrefix("source:") {
                let source = String(key.dropFirst("source:".count))
                guard ["musicLibrary", "appleMusicCatalog", "appleMusicPreview", "generatedLocal", "importedLocal", "builtinIntentional"].contains(source) else { continue }
                add(key, .mediaSourceUsedInProbableGame, [.sourceFamily: source])
            } else if key == "announcementPlayed" {
                add(key, .announcementPlayedInProbableGame)
            } else if key == "clip:builtin" {
                add(key, .clipsBuiltinUsedInProbableGame)
            } else if key == "clip:custom" {
                add(key, .clipsCustomUsedInProbableGame)
            } else if key == RollCallTelemetryEvent.lineupProgressionUsedInProbableGame.rawValue {
                add(key, .lineupProgressionUsedInProbableGame)
            } else if key == RollCallTelemetryEvent.lineupEditedInProbableGame.rawValue {
                add(key, .lineupEditedInProbableGame)
            }
        }
        for key in current.bufferedRecoveryKeys {
            let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 4,
                  let failed = PlaybackComponent(rawValue: parts[0]),
                  let source = PlaybackSourceFamily(rawValue: parts[1]),
                  let reason = PlaybackFailureReason(rawValue: parts[3]) else { continue }
            let featureKey = "recovery:\(key)"
            add(featureKey, .gameRecoveryPathUsed, [
                .failedComponent: failed.rawValue,
                .sourceFamily: source.rawValue,
                .recoveryOutcome: parts[2],
                .reason: reason.rawValue
            ])
        }
        for key in current.bufferedCompleteFailureKeys {
            let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2,
                  let source = PlaybackSourceFamily(rawValue: parts[0]),
                  let reason = PlaybackFailureReason(rawValue: parts[1]) else { continue }
            add("failure:\(key)", .gameCompletePlaybackFailureObserved, [
                .sourceFamily: source.rawValue,
                .reason: reason.rawValue
            ])
        }
        candidate.liveCheckpoint = current
        return events
    }

    private func gameKey(for checkpoint: LiveAnalyticsCheckpoint) -> String {
        let date = checkpoint.probableGameDate ?? checkpoint.latestQualifyingCueAt
        return "\(checkpoint.selectedTeamID.uuidString)|\(date.timeIntervalSinceReferenceDate)"
    }

    func recordPlaybackFailure(
        teamID: UUID?,
        sourceFamily: PlaybackSourceFamily,
        liveContext: String,
        fallbackAttempted: Bool,
        reason: PlaybackFailureReason,
        now: Date = .now
    ) {
        record(.playbackFailedCompletely, properties: [
            .sourceFamily: sourceFamily.rawValue,
            .liveContext: liveContext,
            .fallbackAttempted: fallbackAttempted ? "true" : "false",
            .reason: reason.rawValue
        ])
        guard isAvailableForProductPolicy else { return }
        guard expireMonotonicCheckpointIfNeeded() else { return }
        let useWallClockTimeout = monotonicActivityDeadline == nil
        guard let teamID, let current = store.state.liveCheckpoint else {
            // A failed or cancelled request cannot create or refresh a live
            // analytics session. The raw failure above remains intentionally
            // repeatable; only an existing session can buffer its aggregate.
            return
        }
        guard current.selectedTeamID == teamID else {
            _ = clearLiveCheckpoint()
            return
        }
        guard LiveAnalyticsSessionReducer.accepting(
            checkpoint: current,
            selectedTeamID: teamID,
            now: now,
            useWallClockTimeout: useWallClockTimeout
        ) != nil else {
            _ = clearLiveCheckpoint()
            return
        }
        var candidate = store.state
        var checkpoint = current
        let key = "\(sourceFamily.rawValue)|\(reason.rawValue)"
        checkpoint.bufferedCompleteFailureKeys.insert(key)
        if checkpoint.didQualify {
            checkpoint.emittedFeatureKeys.insert("emitted:failure:\(key)")
        }
        candidate.liveCheckpoint = checkpoint
        guard persistLive(candidate) else { return }
        if checkpoint.didQualify {
            record(.gameCompletePlaybackFailureObserved, properties: [.sourceFamily: sourceFamily.rawValue, .reason: reason.rawValue])
        }
    }

    func recordRecovery(
        teamID: UUID,
        failedComponent: PlaybackComponent,
        sourceFamily: PlaybackSourceFamily,
        recoveryOutcome: String,
        reason: PlaybackFailureReason,
        now: Date = .now
    ) {
        guard isAvailableForProductPolicy else { return }
        guard expireMonotonicCheckpointIfNeeded() else { return }
        let useWallClockTimeout = monotonicActivityDeadline == nil
        guard var checkpoint = store.state.liveCheckpoint else { return }
        guard checkpoint.selectedTeamID == teamID else {
            _ = clearLiveCheckpoint()
            return
        }
        guard LiveAnalyticsSessionReducer.accepting(
            checkpoint: checkpoint,
            selectedTeamID: teamID,
            now: now,
            useWallClockTimeout: useWallClockTimeout
        ) != nil else {
            _ = clearLiveCheckpoint()
            return
        }
        let key = "\(failedComponent.rawValue)|\(sourceFamily.rawValue)|\(recoveryOutcome)|\(reason.rawValue)"
        guard checkpoint.bufferedRecoveryKeys.insert(key).inserted else { return }
        if checkpoint.didQualify {
            checkpoint.emittedFeatureKeys.insert("emitted:recovery:\(key)")
        }
        var candidate = store.state
        candidate.liveCheckpoint = checkpoint
        guard persistLive(candidate) else { return }
        guard checkpoint.didQualify else { return }
        record(.gameRecoveryPathUsed, properties: [
            .failedComponent: failedComponent.rawValue,
            .sourceFamily: sourceFamily.rawValue,
            .recoveryOutcome: recoveryOutcome,
            .reason: reason.rawValue
        ])
    }

    func handleClipPlayback(teamID: UUID, isCustom: Bool = false, now: Date = .now) {
        guard isAvailableForProductPolicy else { return }
        let useWallClockTimeout = monotonicActivityDeadline == nil
        guard acceptMonotonicActivity() else { return }
        var candidate = store.state
        if var checkpoint = candidate.liveCheckpoint {
            if checkpoint.selectedTeamID != teamID {
                candidate.liveCheckpoint = nil
                guard persistLive(candidate) else { return }
                checkpoint = LiveAnalyticsCheckpoint(
                    selectedTeamID: teamID, firstQualifyingCueAt: now, latestQualifyingCueAt: now,
                    distinctPlayerIDs: [], qualifyingCueCount: 0, hasThreeMinuteGap: false,
                    latestMeaningfulActivityAt: now, bufferedRecoveryKeys: [], bufferedCompleteFailureKeys: [],
                    emittedFeatureKeys: [], didQualify: false, probableGameDate: nil, probableGameDateKey: nil
                )
            }
            guard now >= checkpoint.latestMeaningfulActivityAt else {
                _ = clearLiveCheckpoint()
                return
            }
            if LiveAnalyticsSessionReducer.accepting(
                checkpoint: checkpoint,
                selectedTeamID: teamID,
                now: now,
                useWallClockTimeout: useWallClockTimeout
            ) == nil {
                checkpoint = LiveAnalyticsCheckpoint(
                    selectedTeamID: teamID, firstQualifyingCueAt: now, latestQualifyingCueAt: now,
                    distinctPlayerIDs: [], qualifyingCueCount: 0, hasThreeMinuteGap: false,
                    latestMeaningfulActivityAt: now, bufferedRecoveryKeys: [], bufferedCompleteFailureKeys: [],
                    emittedFeatureKeys: [], didQualify: false, probableGameDate: nil, probableGameDateKey: nil
                )
            }
            LiveAnalyticsSessionReducer.meaningfulActivity(checkpoint: &checkpoint, teamID: teamID, now: now, useWallClockTimeout: false)
            candidate.liveCheckpoint = checkpoint
        } else {
            candidate.liveCheckpoint = LiveAnalyticsCheckpoint(
                selectedTeamID: teamID, firstQualifyingCueAt: now, latestQualifyingCueAt: now,
                distinctPlayerIDs: [], qualifyingCueCount: 0, hasThreeMinuteGap: false,
                latestMeaningfulActivityAt: now, bufferedRecoveryKeys: [], bufferedCompleteFailureKeys: [],
                emittedFeatureKeys: [], didQualify: false, probableGameDate: nil, probableGameDateKey: nil
            )
        }
        if var checkpoint = candidate.liveCheckpoint {
            checkpoint.emittedFeatureKeys.insert(isCustom ? "clip:custom" : "clip:builtin")
            candidate.liveCheckpoint = checkpoint
        }
        if let checkpoint = candidate.liveCheckpoint, checkpoint.didQualify {
            let events = gameFeatureEvents(from: checkpoint, candidate: &candidate)
            guard persistLive(candidate) else { return }
            for (event, properties) in events { record(event, properties: properties) }
            return
        }
        guard persistLive(candidate) else { return }
    }

    func handleLineupActivity(teamID: UUID, now: Date = .now, edited: Bool = false) {
        guard isAvailableForProductPolicy else { return }
        let useWallClockTimeout = monotonicActivityDeadline == nil
        guard acceptMonotonicActivity() else { return }
        var checkpoint = store.state.liveCheckpoint
        if let current = checkpoint {
            guard current.selectedTeamID == teamID else {
                _ = clearLiveCheckpoint()
                return
            }
            guard now >= current.latestMeaningfulActivityAt else {
                _ = clearLiveCheckpoint()
                return
            }
            if LiveAnalyticsSessionReducer.accepting(
                checkpoint: current,
                selectedTeamID: teamID,
                now: now,
                useWallClockTimeout: useWallClockTimeout
            ) == nil {
                checkpoint = nil
            }
        }
        if checkpoint == nil {
            checkpoint = LiveAnalyticsCheckpoint(
                selectedTeamID: teamID, firstQualifyingCueAt: now, latestQualifyingCueAt: now,
                distinctPlayerIDs: [], qualifyingCueCount: 0, hasThreeMinuteGap: false,
                latestMeaningfulActivityAt: now, bufferedRecoveryKeys: [], bufferedCompleteFailureKeys: [],
                emittedFeatureKeys: [], didQualify: false, probableGameDate: nil, probableGameDateKey: nil
            )
        }
        guard var checkpoint else { return }
        LiveAnalyticsSessionReducer.meaningfulActivity(checkpoint: &checkpoint, teamID: teamID, now: now, useWallClockTimeout: false)
        let event = edited ? RollCallTelemetryEvent.lineupEditedInProbableGame : .lineupProgressionUsedInProbableGame
        let featureKey = event.rawValue
        guard !checkpoint.emittedFeatureKeys.contains(featureKey) else { return }
        checkpoint.emittedFeatureKeys.insert(featureKey)
        var candidate = store.state
        candidate.liveCheckpoint = checkpoint
        if checkpoint.didQualify {
            let events = gameFeatureEvents(from: checkpoint, candidate: &candidate)
            guard persistLive(candidate) else { return }
            for (event, properties) in events { record(event, properties: properties) }
        } else {
            guard persistLive(candidate) else { return }
        }
    }

    func reserveRatingPresentation(source: PendingRatingPresentation.Source, now: Date = .now) -> UUID? {
        guard store.state.rating.pendingPresentation == nil,
              volatileManualRatingPresentation == nil else { return nil }
        let attempt = source == .automatic ? RollCallRatingPolicy.automaticOpportunity(for: store.state.rating, now: now) : nil
        if source == .automatic {
            guard isAvailableForProductPolicy, buildContext.isAppStoreBuild, let attempt else { return nil }
            var candidate = store.state
            let token = UUID()
            candidate.rating.pendingPresentation = PendingRatingPresentation(token: token, source: source, automaticAttemptNumber: attempt, reservedAt: now)
            return persistSynchronously(candidate) ? token : nil
        }
        let token = UUID()
        let pending = PendingRatingPresentation(token: token, source: source, automaticAttemptNumber: nil, reservedAt: now)
        guard isAvailableForProductPolicy else {
            // A manual request remains available even when a newer or
            // unavailable telemetry store cannot safely be overwritten. Its
            // cooldown is process-local in this exceptional state.
            volatileManualRatingPresentation = pending
            return token
        }
        var candidate = store.state
        candidate.rating.pendingPresentation = pending
        return persistSynchronously(candidate) ? token : nil
    }

    func confirmRatingPresentation(token: UUID, now: Date = .now) {
        let pending: PendingRatingPresentation
        let isVolatileManual: Bool
        if let stored = store.state.rating.pendingPresentation, stored.token == token {
            pending = stored
            isVolatileManual = false
        } else if let volatile = volatileManualRatingPresentation, volatile.token == token {
            pending = volatile
            isVolatileManual = true
        } else {
            return
        }
        var candidate = store.state
        candidate.rating.pendingPresentation = nil
        volatileManualRatingPresentation = nil
        candidate.rating.firstSheetShownAt = now
        candidate.rating.presentationCooldownAnchor = now
        if pending.source == .automatic {
            candidate.rating.automaticAttemptsConsumed = min(2, candidate.rating.automaticAttemptsConsumed + 1)
        }
        if isVolatileManual {
            store.state = candidate
        } else {
            guard persistSynchronously(candidate) else {
                suspendAfterPersistenceFailure()
                return
            }
        }
        var properties: [RollCallTelemetryProperty: String] = [
            .source: pending.source.rawValue,
            .qualifiedGameBucket: RollCallRatingPolicy.bucket(for: RollCallRatingPolicy.distinctProbableGameDateCount(for: candidate.rating)),
            .daysSincePolicyEnrollmentBucket: RollCallRatingPolicy.daysBucket(from: candidate.rating.enrollmentDate, to: now),
            .enrollmentCohort: candidate.enrollmentCohort,
            .ratingPolicyVersion: "1"
        ]
        if let attempt = pending.automaticAttemptNumber { properties[.automaticAttemptNumber] = String(attempt) }
        record(.ratingSheetShown, properties: properties)
    }

    func cancelRatingPresentationBeforeAppearance(token: UUID? = nil) {
        if let pending = volatileManualRatingPresentation,
           token == nil || pending.token == token {
            volatileManualRatingPresentation = nil
            return
        }
        guard let pending = store.state.rating.pendingPresentation,
              token == nil || pending.token == token else { return }
        var candidate = store.state
        candidate.rating.pendingPresentation = nil
        guard persistSynchronously(candidate) else {
            suspendAfterPersistenceFailure()
            return
        }
    }

    func suppressAutomaticRating() {
        var candidate = store.state
        candidate.rating.permanentlySuppressed = true
        guard isAvailableForProductPolicy else {
            store.state = candidate
            return
        }
        guard persistSynchronously(candidate) else {
            suspendAfterPersistenceFailure()
            return
        }
    }

    func recordRatingAction(_ event: RollCallTelemetryEvent, suppressesAutomatic: Bool) {
        if suppressesAutomatic { suppressAutomaticRating() }
        record(event)
    }

    func recoverUnresolvedPresentationIfNeeded(now: Date) {
        guard let pending = store.state.rating.pendingPresentation else { return }
        var candidate = store.state
        candidate.rating.pendingPresentation = nil
        candidate.rating.firstSheetShownAt = pending.reservedAt
        candidate.rating.presentationCooldownAnchor = pending.reservedAt
        if pending.source == .automatic {
            candidate.rating.automaticAttemptsConsumed = min(2, candidate.rating.automaticAttemptsConsumed + 1)
        }
        guard persistSynchronously(candidate) else {
            suspendAfterPersistenceFailure()
            return
        }
        _ = now
    }

    private func sendNarrowPreferenceTransition(_ value: String) {
        guard let signal = try? RollCallTelemetryValidator.shared.validate(
            event: .analyticsPreferenceChanged,
            properties: [.newValue: value, .telemetrySchemaVersion: "1"]
        ) else { return }
        provider.send(signal)
    }

    /// Surfaces an allowlist/value mismatch during development only. Release and
    /// Internal builds keep the fail-closed behaviour with no user-visible effect.
    private func assertionFailureForTelemetryValidation(
        event: RollCallTelemetryEvent,
        properties: [RollCallTelemetryProperty: String],
        error: Error
    ) {
        #if DEBUG
        let described = properties
            .map { "\($0.key.rawValue)=\($0.value)" }
            .sorted()
            .joined(separator: ", ")
        assertionFailure(
            "Telemetry allowlist rejected \(event.rawValue) [\(described)]: \(error). "
                + "Add the property/value to allowedPropertiesByEvent or eventSpecificValues, "
                + "or stop sending it at the call site."
        )
        #endif
    }

    private func sendNarrow(_ event: RollCallTelemetryEvent) {
        guard let signal = try? RollCallTelemetryValidator.shared.validate(
            event: event,
            properties: [.telemetrySchemaVersion: "1"]
        ) else { return }
        provider.send(signal)
    }
}
