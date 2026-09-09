import Foundation

private enum CueDefaults {
    static let fadeOutDuration: TimeInterval = 2.0
}

enum AppMetadata {
    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    static let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    static let customIntroStorageMarker = "flat-custom-intro-v2"
    static var whatsNewReleaseID: String {
        releaseFamily(for: appVersion)
    }

    static func releaseFamily(for version: String) -> String {
        let components = version.split(separator: ".")
        guard components.count >= 2 else { return version }
        return components.prefix(2).map(String.init).joined(separator: ".")
    }

    static func hasSeenWhatsNewRelease(_ savedReleaseID: String?, for currentVersion: String = appVersion) -> Bool {
        guard let savedReleaseID else { return false }
        let savedVersion = savedReleaseID.split(separator: " ").first.map(String.init) ?? savedReleaseID
        return releaseFamily(for: savedVersion) == releaseFamily(for: currentVersion)
    }

    static let appStoreWriteReviewURL = URL(string: "https://apps.apple.com/us/app/roll-call-walk-up-music/id6769516985?action=write-review")!
}

enum CueSource: Codable, Equatable {
    case appleMusic(AppleMusicSource)
    case localAudio(LocalAudioSource)
    case builtInClip(BuiltInClipSource)

    enum CodingKeys: String, CodingKey {
        case type, appleMusic, localAudio, builtInClip
    }

    enum Kind: String, Codable {
        case appleMusic, localAudio, builtInClip
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .appleMusic:
            self = .appleMusic(try container.decode(AppleMusicSource.self, forKey: .appleMusic))
        case .localAudio:
            self = .localAudio(try container.decode(LocalAudioSource.self, forKey: .localAudio))
        case .builtInClip:
            self = .builtInClip(try container.decode(BuiltInClipSource.self, forKey: .builtInClip))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .appleMusic(let value):
            try container.encode(Kind.appleMusic, forKey: .type)
            try container.encode(value, forKey: .appleMusic)
        case .localAudio(let value):
            try container.encode(Kind.localAudio, forKey: .type)
            try container.encode(value, forKey: .localAudio)
        case .builtInClip(let value):
            try container.encode(Kind.builtInClip, forKey: .type)
            try container.encode(value, forKey: .builtInClip)
        }
    }
}

struct AppleMusicSource: Codable, Equatable, Identifiable {
    var id: String { songID }
    var songID: String
    var title: String
    var artistName: String
    var duration: TimeInterval?
    var previewURL: URL?
    var isCatalogBacked: Bool? = nil
    var libraryPersistentID: UInt64? = nil
    var isExplicit: Bool? = nil
}

struct RecentAppleMusicSelection: Codable, Equatable, Identifiable {
    var id: String { songID }
    var songID: String
    var title: String
    var artistName: String
    var duration: TimeInterval?
    var previewURL: URL?
    var isCatalogBacked: Bool? = nil
    var libraryPersistentID: UInt64? = nil
    var isExplicit: Bool? = nil
    var selectedAt: Date
}

struct HiddenOriginNote: Codable, Equatable {
    var importedAt: Date
    var originSummary: String
}

struct LocalAudioSource: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var relativePath: String
    var duration: TimeInterval?
    var importedAt: Date
    var hiddenOriginNote: HiddenOriginNote?
}

struct BuiltInClipSource: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
}

func normalizedPlayerNameParts(_ name: String) -> (first: String, remainder: String) {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let splitIndex = trimmedName.firstIndex(where: \.isWhitespace) else {
        return (trimmedName, "")
    }

    let firstName = String(trimmedName[..<splitIndex])
    let remainder = trimmedName[splitIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
    return (firstName, remainder)
}

func alphabeticalPlayerIDs(for players: [Player]) -> [UUID] {
    players.sorted { lhs, rhs in
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
    .map(\.id)
}

enum GameDayAnnouncerMode: String, Codable, CaseIterable, Identifiable {
    case announcerOnly
    case announcerAndSong
    case songOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .announcerOnly:
            return "Announcer Only"
        case .announcerAndSong:
            return "Announcer+Song"
        case .songOnly:
            return "Song Only"
        }
    }

    var usesAnnouncer: Bool {
        switch self {
        case .announcerOnly, .announcerAndSong:
            return true
        case .songOnly:
            return false
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "announcerOnly":
            self = .announcerOnly
        case "announcerAndSong":
            self = .announcerAndSong
        case "songOnly":
            self = .songOnly
        case "announcer":
            self = .announcerAndSong
        case "noAnnouncer":
            self = .songOnly
        default:
            self = .announcerAndSong
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum TeamAccentPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case rollCallOrange
    case red
    case gold
    case green
    case blue
    case purple
    case gray
    case black

    var id: String { rawValue }
}

enum AnnouncerTemplate: String, Codable, CaseIterable, Identifiable {
    case nameOnly
    case numberAndName
    case nowBatting

    var id: String { rawValue }
}

struct TeamAnnouncerProfile: Codable, Equatable {
    var phraseTemplate: String
    var requestedVoiceIdentifier: String?
    var resolvedVoiceIdentifier: String?
    var voiceLanguageCode: String?
    var rate: Float
    var pitchMultiplier: Float
    var volume: Float

    static let `default` = TeamAnnouncerProfile(
        phraseTemplate: "Now batting, number <number>, <name>",
        requestedVoiceIdentifier: nil,
        resolvedVoiceIdentifier: nil,
        voiceLanguageCode: "en-US",
        rate: 0.46,
        pitchMultiplier: 1.0,
        volume: 1.0
    )
}

struct AnnouncerConfig: Codable, Equatable {
    var isEnabled: Bool
    var template: AnnouncerTemplate
    var customPrefix: String
    var generatedAssetRelativePath: String?
}

struct Cue: Codable, Equatable, Identifiable {
    var id: UUID
    var label: String
    var source: CueSource
    var startTime: TimeInterval
    var duration: TimeInterval
    var fadeOutDuration: TimeInterval
    var pauseAfterAnnouncer: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case source
        case startTime
        case duration
        case fadeOutDuration
        case pauseAfterAnnouncer
        case announcer
    }

    init(
        id: UUID,
        label: String,
        source: CueSource,
        startTime: TimeInterval,
        duration: TimeInterval,
        fadeOutDuration: TimeInterval,
        pauseAfterAnnouncer: TimeInterval
    ) {
        self.id = id
        self.label = label
        self.source = source
        self.startTime = startTime
        self.duration = duration
        self.fadeOutDuration = fadeOutDuration
        self.pauseAfterAnnouncer = pauseAfterAnnouncer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        source = try container.decode(CueSource.self, forKey: .source)
        startTime = try container.decodeIfPresent(TimeInterval.self, forKey: .startTime) ?? 0
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 12
        fadeOutDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .fadeOutDuration) ?? CueDefaults.fadeOutDuration
        pauseAfterAnnouncer = try container.decodeIfPresent(TimeInterval.self, forKey: .pauseAfterAnnouncer) ?? 0.2
        _ = try container.decodeIfPresent(AnnouncerConfig.self, forKey: .announcer)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(source, forKey: .source)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(duration, forKey: .duration)
        try container.encode(fadeOutDuration, forKey: .fadeOutDuration)
        try container.encode(pauseAfterAnnouncer, forKey: .pauseAfterAnnouncer)
    }
}

struct Player: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var uniformNumber: String
    var pronunciationOverride: String
    var photoRelativePath: String?
    /// A metadata-stripped, orientation-normalized working master for new photos.
    /// Legacy players may have only `photoRelativePath`.
    var photoSourceRelativePath: String?
    var profilePhotoCrop: NormalizedPhotoCrop?
    var playerCardPhotoCrop: NormalizedPhotoCrop?
    var songAssignment: SongAssignment?
    var cue: Cue? {
        get {
            songAssignment?.privateClip?.playbackCue
        }
        set {
            songAssignment = newValue.map { .privateClip(SongClip(cue: $0)) }
        }
    }
    var isPresent: Bool
    var customAnnouncerRelativePath: String?
    var generatedBuiltInAnnouncerRelativePath: String?
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case uniformNumber
        case pronunciationOverride
        case photoRelativePath
        case photoSourceRelativePath
        case profilePhotoCrop
        case playerCardPhotoCrop
        case cue
        case songAssignment
        case isPresent
        case customAnnouncerRelativePath
        case generatedBuiltInAnnouncerRelativePath
    }

    init(
        id: UUID,
        displayName: String,
        uniformNumber: String,
        pronunciationOverride: String,
        photoRelativePath: String?,
        photoSourceRelativePath: String? = nil,
        profilePhotoCrop: NormalizedPhotoCrop? = nil,
        playerCardPhotoCrop: NormalizedPhotoCrop? = nil,
        cue: Cue?,
        isPresent: Bool,
        customAnnouncerRelativePath: String? = nil,
        generatedBuiltInAnnouncerRelativePath: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.uniformNumber = uniformNumber
        self.pronunciationOverride = pronunciationOverride
        self.photoRelativePath = photoRelativePath
        self.photoSourceRelativePath = photoSourceRelativePath
        self.profilePhotoCrop = profilePhotoCrop
        self.playerCardPhotoCrop = playerCardPhotoCrop
        self.songAssignment = cue.map { .privateClip(SongClip(cue: $0)) }
        self.isPresent = isPresent
        self.customAnnouncerRelativePath = customAnnouncerRelativePath
        self.generatedBuiltInAnnouncerRelativePath = generatedBuiltInAnnouncerRelativePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        uniformNumber = try container.decodeIfPresent(String.self, forKey: .uniformNumber) ?? ""
        pronunciationOverride = try container.decodeIfPresent(String.self, forKey: .pronunciationOverride) ?? ""
        photoRelativePath = try container.decodeIfPresent(String.self, forKey: .photoRelativePath)
        photoSourceRelativePath = try container.decodeIfPresent(String.self, forKey: .photoSourceRelativePath)
        profilePhotoCrop = try container.decodeIfPresent(NormalizedPhotoCrop.self, forKey: .profilePhotoCrop)
        playerCardPhotoCrop = try container.decodeIfPresent(NormalizedPhotoCrop.self, forKey: .playerCardPhotoCrop)
        if container.contains(.songAssignment) {
            if try container.decodeNil(forKey: .songAssignment) {
                songAssignment = nil
            } else {
                songAssignment = try container.decode(SongAssignment.self, forKey: .songAssignment)
            }
        } else {
            songAssignment = try container.decodeIfPresent(Cue.self, forKey: .cue)
                .map { .privateClip(SongClip(cue: $0)) }
        }
        isPresent = try container.decodeIfPresent(Bool.self, forKey: .isPresent) ?? true
        customAnnouncerRelativePath = try container.decodeIfPresent(String.self, forKey: .customAnnouncerRelativePath)
        generatedBuiltInAnnouncerRelativePath = try container.decodeIfPresent(String.self, forKey: .generatedBuiltInAnnouncerRelativePath)

        if generatedBuiltInAnnouncerRelativePath == nil,
           let legacyPayload = try? LegacyPlayerDecoder.LegacyPlayerPayload(from: decoder),
           let legacyGenerated = legacyPayload.cue?.announcer?.generatedAssetRelativePath {
           generatedBuiltInAnnouncerRelativePath = legacyGenerated
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(uniformNumber, forKey: .uniformNumber)
        try container.encode(pronunciationOverride, forKey: .pronunciationOverride)
        try container.encodeIfPresent(photoRelativePath, forKey: .photoRelativePath)
        try container.encodeIfPresent(photoSourceRelativePath, forKey: .photoSourceRelativePath)
        try container.encodeIfPresent(profilePhotoCrop, forKey: .profilePhotoCrop)
        try container.encodeIfPresent(playerCardPhotoCrop, forKey: .playerCardPhotoCrop)
        if let songAssignment {
            try container.encode(songAssignment, forKey: .songAssignment)
        }
        try container.encode(isPresent, forKey: .isPresent)
        try container.encodeIfPresent(customAnnouncerRelativePath, forKey: .customAnnouncerRelativePath)
        try container.encodeIfPresent(generatedBuiltInAnnouncerRelativePath, forKey: .generatedBuiltInAnnouncerRelativePath)
    }

    mutating func migrateLegacySharedTeamClip(using clip: SongClip) {
        guard songAssignment?.legacySharedTeamClipID != nil else { return }
        songAssignment = .privateClip(clip.playerSongCopy())
    }

    mutating func updatePrivateSongClip(with editedCue: Cue) {
        guard case .privateClip(let previousClip)? = songAssignment else {
            songAssignment = .privateClip(SongClip(cue: editedCue))
            return
        }

        var updatedClip = SongClip(cue: editedCue)
        updatedClip.id = previousClip.id
        updatedClip.sourceLineageClipID = previousClip.sourceLineageClipID
        if updatedClip.generationKey == previousClip.generationKey {
            updatedClip.generatedAsset = previousClip.generatedAsset
            updatedClip.readinessInputs = previousClip.readinessInputs
            updatedClip.portabilityInputs = previousClip.portabilityInputs
            updatedClip.retryMetadata = previousClip.retryMetadata
        }
        songAssignment = .privateClip(updatedClip)
    }
}

struct PlayerEditorDraftState: Equatable {
    struct CueTiming: Equatable {
        var id: UUID
        var startTime: TimeInterval
        var duration: TimeInterval
        var fadeOutDuration: TimeInterval
    }

    var displayName: String
    var uniformNumber: String
    var photoRelativePath: String?
    var photoSourceRelativePath: String?
    var profilePhotoCrop: NormalizedPhotoCrop?
    var playerCardPhotoCrop: NormalizedPhotoCrop?
    var cueTiming: CueTiming?

    init(player: Player) {
        displayName = player.displayName
        uniformNumber = player.uniformNumber
        photoRelativePath = player.photoRelativePath
        photoSourceRelativePath = player.photoSourceRelativePath
        profilePhotoCrop = player.profilePhotoCrop
        playerCardPhotoCrop = player.playerCardPhotoCrop
        cueTiming = player.cue.map {
            CueTiming(
                id: $0.id,
                startTime: $0.startTime,
                duration: $0.duration,
                fadeOutDuration: $0.fadeOutDuration
            )
        }
    }
}

struct BuiltInClip: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var cue: Cue
}

struct TeamSessionState: Codable, Equatable {
    var activeSessionDate: Date?
    var battingOrder: [UUID]
    var nextBatterIndex: Int
    var gameDayAnnouncerMode: GameDayAnnouncerMode
    var battingOrderIsCustomized: Bool

    init(
        activeSessionDate: Date?,
        battingOrder: [UUID],
        nextBatterIndex: Int,
        gameDayAnnouncerMode: GameDayAnnouncerMode,
        battingOrderIsCustomized: Bool
    ) {
        self.activeSessionDate = activeSessionDate
        self.battingOrder = battingOrder
        self.nextBatterIndex = nextBatterIndex
        self.gameDayAnnouncerMode = gameDayAnnouncerMode
        self.battingOrderIsCustomized = battingOrderIsCustomized
    }

    enum CodingKeys: String, CodingKey {
        case activeSessionDate
        case battingOrder
        case nextBatterIndex
        case gameDayAnnouncerMode
        case battingOrderIsCustomized
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeSessionDate = try container.decodeIfPresent(Date.self, forKey: .activeSessionDate)
        battingOrder = try container.decodeIfPresent([UUID].self, forKey: .battingOrder) ?? []
        nextBatterIndex = try container.decodeIfPresent(Int.self, forKey: .nextBatterIndex) ?? 0
        gameDayAnnouncerMode = try container.decodeIfPresent(GameDayAnnouncerMode.self, forKey: .gameDayAnnouncerMode) ?? .announcerAndSong
        battingOrderIsCustomized = try container.decodeIfPresent(Bool.self, forKey: .battingOrderIsCustomized) ?? false
    }
}

struct AppSettings: Codable, Equatable {
    var hapticsEnabled: Bool
    var fadeOutVolumeAutomationEnabled: Bool
    var alwaysUseDarkLiveMode: Bool
    var keepScreenAwakeDuringLiveUse: Bool
    var showLineupProgressHints: Bool
    var explicitAppleMusicSearchFilteringEnabled: Bool

    static let `default` = AppSettings(
        hapticsEnabled: true,
        fadeOutVolumeAutomationEnabled: false,
        alwaysUseDarkLiveMode: true,
        keepScreenAwakeDuringLiveUse: false,
        showLineupProgressHints: false,
        explicitAppleMusicSearchFilteringEnabled: true
    )

    enum CodingKeys: String, CodingKey {
        case hapticsEnabled
        case fadeOutVolumeAutomationEnabled
        case alwaysUseDarkLiveMode
        case keepScreenAwakeDuringLiveUse
        case showLineupProgressHints
        case explicitAppleMusicSearchFilteringEnabled
    }

    init(
        hapticsEnabled: Bool,
        fadeOutVolumeAutomationEnabled: Bool,
        alwaysUseDarkLiveMode: Bool,
        keepScreenAwakeDuringLiveUse: Bool,
        showLineupProgressHints: Bool,
        explicitAppleMusicSearchFilteringEnabled: Bool
    ) {
        self.hapticsEnabled = hapticsEnabled
        self.fadeOutVolumeAutomationEnabled = fadeOutVolumeAutomationEnabled
        self.alwaysUseDarkLiveMode = alwaysUseDarkLiveMode
        self.keepScreenAwakeDuringLiveUse = keepScreenAwakeDuringLiveUse
        self.showLineupProgressHints = showLineupProgressHints
        self.explicitAppleMusicSearchFilteringEnabled = explicitAppleMusicSearchFilteringEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        fadeOutVolumeAutomationEnabled = try container.decodeIfPresent(Bool.self, forKey: .fadeOutVolumeAutomationEnabled) ?? false
        alwaysUseDarkLiveMode = try container.decodeIfPresent(Bool.self, forKey: .alwaysUseDarkLiveMode) ?? true
        keepScreenAwakeDuringLiveUse = try container.decodeIfPresent(Bool.self, forKey: .keepScreenAwakeDuringLiveUse) ?? false
        showLineupProgressHints = try container.decodeIfPresent(Bool.self, forKey: .showLineupProgressHints) ?? false
        explicitAppleMusicSearchFilteringEnabled = try container.decodeIfPresent(Bool.self, forKey: .explicitAppleMusicSearchFilteringEnabled) ?? true
    }
}

struct Team: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var players: [Player]
    var teamClips: [SongClip]
    var builtInClips: [BuiltInClip]
    var session: TeamSessionState
    var announcerProfile: TeamAnnouncerProfile
    var accentPreset: TeamAccentPreset

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case modifiedAt
        case players
        case teamClips
        case builtInClips
        case session
        case announcerProfile
        case accentPreset
    }

    init(
        id: UUID,
        name: String,
        createdAt: Date,
        modifiedAt: Date,
        players: [Player],
        teamClips: [SongClip] = [],
        builtInClips: [BuiltInClip],
        session: TeamSessionState,
        announcerProfile: TeamAnnouncerProfile,
        accentPreset: TeamAccentPreset = .rollCallOrange
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.players = players
        self.teamClips = teamClips
        self.builtInClips = builtInClips
        self.session = session
        self.announcerProfile = announcerProfile
        self.accentPreset = accentPreset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt
        players = try container.decodeIfPresent([Player].self, forKey: .players) ?? []
        teamClips = try container.decodeIfPresent([SongClip].self, forKey: .teamClips) ?? []
        builtInClips = try container.decodeIfPresent([BuiltInClip].self, forKey: .builtInClips) ?? BuiltInClip.defaults
        session = try container.decodeIfPresent(TeamSessionState.self, forKey: .session) ?? TeamSessionState(activeSessionDate: nil, battingOrder: alphabeticalPlayerIDs(for: players), nextBatterIndex: 0, gameDayAnnouncerMode: .announcerAndSong, battingOrderIsCustomized: false)
        accentPreset = try container.decodeIfPresent(TeamAccentPreset.self, forKey: .accentPreset) ?? .rollCallOrange
        let legacyPlayers = (try? container.decodeIfPresent([LegacyPlayerDecoder.LegacyPlayerPayload].self, forKey: .players)) ?? []

        if let decodedProfile = try container.decodeIfPresent(TeamAnnouncerProfile.self, forKey: .announcerProfile) {
            announcerProfile = decodedProfile
        } else {
            announcerProfile = LegacyPlayerDecoder.teamAnnouncerProfile(from: legacyPlayers) ?? .default
        }
        // Team-owned legacy assignments can be resolved here because both the
        // player payloads and their referenced team clips are available.
        migrateLegacySharedAssignments()

        if try container.decodeIfPresent(TeamAnnouncerProfile.self, forKey: .announcerProfile) == nil,
           LegacyPlayerDecoder.legacyAnnouncerEnabled(in: legacyPlayers) {
            session.gameDayAnnouncerMode = .announcerAndSong
        }

        let alphabeticalIDs = alphabeticalPlayerIDs(for: players)
        if !session.battingOrderIsCustomized, !session.battingOrder.isEmpty, session.battingOrder != alphabeticalIDs {
            session.battingOrderIsCustomized = true
        }

        let builtInSourceIDs = Set(
            builtInClips.compactMap { clip in
                if case .builtInClip(let source) = clip.cue.source {
                    return source.id
                }
                return nil
            }
        )
        if builtInSourceIDs == ["charge-up", "crowd-lift"] {
            builtInClips = BuiltInClip.defaults
        }

        let legacyReleaseClipIDs: Set<String> = [
            "small-cheer",
            "victory-roar",
            "stadium-burst",
            "rhythmic-clap",
            "whistle-pop",
            "crowd-laugh"
        ]
        let mixedAudienceClipIDs: Set<String> = [
            "small-cheer",
            "happy-cheer",
            "light-applause",
            "applause",
            "strong-applause",
            "rhythmic-clap",
            "crowd-swell",
            "rally-cheer",
            "big-cheer",
            "victory-shout",
            "chant-and-drums"
        ]
        let sportsExperimentClipIDs: Set<String> = [
            "small-cheer",
            "rhythmic-clap",
            "crowd-swell",
            "rally-cheer",
            "big-cheer",
            "lets-go-chant"
        ]
        if builtInSourceIDs == legacyReleaseClipIDs
            || builtInSourceIDs == mixedAudienceClipIDs
            || builtInSourceIDs == sportsExperimentClipIDs {
            builtInClips = BuiltInClip.defaults
        }
    }

    private mutating func migrateLegacySharedAssignments() {
        var migratedClipIDs: Set<UUID> = []
        for playerIndex in players.indices {
            guard let legacyClipID = players[playerIndex].songAssignment?.legacySharedTeamClipID,
                  let clip = teamClips.first(where: { $0.id == legacyClipID }) else {
                continue
            }
            players[playerIndex].migrateLegacySharedTeamClip(using: clip)
            migratedClipIDs.insert(clip.id)
        }
        if !migratedClipIDs.isEmpty {
            teamClips = teamClips.map { clip in
                guard migratedClipIDs.contains(clip.id) else { return clip }
                var migrated = clip
                migrated.pauseAfterAnnouncer = 0
                return migrated
            }
        }
    }

    func songClip(for player: Player) -> SongClip? {
        player.songAssignment?.privateClip
    }

    func cue(for player: Player) -> Cue? {
        songClip(for: player)?.playbackCue
    }
}

enum ReadinessState: String, Codable {
    case ready
    case enhanced
    case needsAudio
    case optional
    case gameDayCheck
    case issue

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "ready":
            self = .ready
        case "enhanced":
            self = .enhanced
        case "needsAudio", "warning":
            self = .needsAudio
        case "optional":
            self = .optional
        case "gameDayCheck", "unknown":
            self = .gameDayCheck
        case "issue", "failed":
            self = .issue
        default:
            self = .gameDayCheck
        }
    }
}

enum ReadinessCheckCategory: String, Codable, Equatable {
    case playerAudio
    case playerAnnouncement
    case playerPhoto
    case audioRoute
    case volume
    case network
    case appleMusicAccess
    case lineup
}

enum ReadinessCheckAction: String, Codable, Equatable {
    case none
    case requestAppleMusicAccess
}

struct ReadinessCheck: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var state: ReadinessState
    var category: ReadinessCheckCategory
    var playerID: UUID?
    var action: ReadinessCheckAction

    init(
        id: String,
        title: String,
        detail: String,
        state: ReadinessState,
        category: ReadinessCheckCategory? = nil,
        playerID: UUID? = nil,
        action: ReadinessCheckAction = .none
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
        self.category = category ?? Self.legacyCategory(for: id)
        self.playerID = playerID
        self.action = action
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case state
        case category
        case playerID
        case action
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decode(String.self, forKey: .detail)
        state = try container.decode(ReadinessState.self, forKey: .state)
        category = try container.decodeIfPresent(ReadinessCheckCategory.self, forKey: .category)
            ?? Self.legacyCategory(for: id)
        playerID = try container.decodeIfPresent(UUID.self, forKey: .playerID)
        action = try container.decodeIfPresent(ReadinessCheckAction.self, forKey: .action) ?? .none
    }

    private static func legacyCategory(for id: String) -> ReadinessCheckCategory {
        if id.contains("announcement-upgrade") || id.contains("custom-announcer") {
            return .playerAnnouncement
        }
        if id.contains("photo-upgrade") {
            return .playerPhoto
        }
        if id.hasPrefix("player-") {
            return .playerAudio
        }
        switch id {
        case "route": return .audioRoute
        case "volume": return .volume
        case "network": return .network
        case "music-auth": return .appleMusicAccess
        default: return .lineup
        }
    }
}

struct ReadinessStatus: Codable, Equatable {
    var generatedAt: Date
    var checks: [ReadinessCheck]
    var teamID: UUID? = nil
}

enum ReadinessCheckFiltering {
    static func playerAudioChecks(from checks: [ReadinessCheck]) -> [ReadinessCheck] {
        checks.filter { $0.category == .playerAudio }
    }
}

struct GameDayReadinessWarningContext {
    let presentPlayerIDs: Set<UUID>
    let announcerMode: GameDayAnnouncerMode
    let volumeAutomationEnabled: Bool
}

/// The checks that can interrupt the live Game Day experience. Volume
/// automation fades and restores playback, but it does not raise the device's
/// output baseline, so a low-volume warning must remain visible when it is on.
enum GameDayReadinessWarningPolicy {
    static func shouldSurface(
        _ check: ReadinessCheck,
        context: GameDayReadinessWarningContext
    ) -> Bool {
        guard check.state == .issue else { return false }
        if check.category == .playerPhoto { return false }
        if check.category == .playerAnnouncement {
            return context.announcerMode.usesAnnouncer
        }
        if check.category == .playerAudio {
            return check.playerID.map(context.presentPlayerIDs.contains) ?? false
        }
        if check.category == .volume {
            return true
        }
        return [.audioRoute, .network, .appleMusicAccess, .lineup].contains(check.category)
    }
}

struct SnapshotRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var createdAt: Date
    var reason: String
    var relativeManifestPath: String
}

struct DeletedTeamRecord: Codable, Equatable {
    var team: Team
}

struct DeletedPlayerRecord: Codable, Equatable {
    var player: Player
    var originalTeamID: UUID
    var originalTeamName: String
    var previousBattingOrder: [UUID]
}

struct DeletedCustomClipRecord: Codable, Equatable {
    var clip: SongClip
    var originalTeamID: UUID
    var originalTeamName: String
    var previousIndex: Int
}

enum RecentlyDeletedPayload: Equatable {
    case team(DeletedTeamRecord)
    case player(DeletedPlayerRecord)
    case customClip(DeletedCustomClipRecord)
}

extension RecentlyDeletedPayload: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case team
        case player
        case customClip
    }

    enum Kind: String, Codable {
        case team
        case player
        case customClip
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .team:
            self = .team(try container.decode(DeletedTeamRecord.self, forKey: .team))
        case .player:
            self = .player(try container.decode(DeletedPlayerRecord.self, forKey: .player))
        case .customClip:
            self = .customClip(try container.decode(DeletedCustomClipRecord.self, forKey: .customClip))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .team(let value):
            try container.encode(Kind.team, forKey: .type)
            try container.encode(value, forKey: .team)
        case .player(let value):
            try container.encode(Kind.player, forKey: .type)
            try container.encode(value, forKey: .player)
        case .customClip(let value):
            try container.encode(Kind.customClip, forKey: .type)
            try container.encode(value, forKey: .customClip)
        }
    }
}

struct RecentlyDeletedItem: Codable, Equatable, Identifiable {
    static let retentionDays = 60

    var id: UUID
    var deletedAt: Date
    var payload: RecentlyDeletedPayload

    var expiresAt: Date {
        Calendar.current.date(byAdding: .day, value: Self.retentionDays, to: deletedAt) ?? deletedAt
    }
}

struct ExperimentalSettings: Codable, Equatable {
    var showExperimentalFeatures: Bool
    var appleMusicTeamPlaylistSyncEnabled: Bool
    var acknowledgedAt: Date?
    var appleMusicTeamPlaylistAcknowledgedAt: Date?

    static let `default` = ExperimentalSettings(
        showExperimentalFeatures: false,
        appleMusicTeamPlaylistSyncEnabled: false,
        acknowledgedAt: nil,
        appleMusicTeamPlaylistAcknowledgedAt: nil
    )

    enum CodingKeys: String, CodingKey {
        case showExperimentalFeatures
        case appleMusicTeamPlaylistSyncEnabled
        case acknowledgedAt
        case appleMusicTeamPlaylistAcknowledgedAt
    }

    init(
        showExperimentalFeatures: Bool,
        appleMusicTeamPlaylistSyncEnabled: Bool,
        acknowledgedAt: Date?,
        appleMusicTeamPlaylistAcknowledgedAt: Date?
    ) {
        self.showExperimentalFeatures = showExperimentalFeatures
        self.appleMusicTeamPlaylistSyncEnabled = appleMusicTeamPlaylistSyncEnabled
        self.acknowledgedAt = acknowledgedAt
        self.appleMusicTeamPlaylistAcknowledgedAt = appleMusicTeamPlaylistAcknowledgedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showExperimentalFeatures = try container.decodeIfPresent(Bool.self, forKey: .showExperimentalFeatures) ?? false
        appleMusicTeamPlaylistSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .appleMusicTeamPlaylistSyncEnabled) ?? false
        acknowledgedAt = try container.decodeIfPresent(Date.self, forKey: .acknowledgedAt)
        appleMusicTeamPlaylistAcknowledgedAt = try container.decodeIfPresent(Date.self, forKey: .appleMusicTeamPlaylistAcknowledgedAt)
    }
}

struct TrimDefaults: Codable, Equatable {
    var preferredLength: TimeInterval
    var hasAppliedTwelveSecondDefaultReset: Bool = true

    enum CodingKeys: String, CodingKey {
        case preferredLength
        case hasAppliedTwelveSecondDefaultReset
    }

    init(preferredLength: TimeInterval, hasAppliedTwelveSecondDefaultReset: Bool = true) {
        self.preferredLength = preferredLength
        self.hasAppliedTwelveSecondDefaultReset = hasAppliedTwelveSecondDefaultReset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hasAppliedReset = try container.decodeIfPresent(Bool.self, forKey: .hasAppliedTwelveSecondDefaultReset) ?? false
        preferredLength = hasAppliedReset
            ? try container.decodeIfPresent(TimeInterval.self, forKey: .preferredLength) ?? 12
            : 12
        hasAppliedTwelveSecondDefaultReset = true
    }

    static let `default` = TrimDefaults(preferredLength: 12)
}

enum OnboardingFlow: String, Codable, Equatable {
    case automatic
    case manualChooser
    case manualCreate
    case manualReview
    case importHandoff
}

struct OnboardingState: Codable, Equatable {
    var completedAt: Date?
    var activeFlow: OnboardingFlow?
    var activeTeamID: UUID?
    var didChooseCheerFallback: Bool
    var didSeeLineup: Bool
    var importHandoffTeamID: UUID?

    var isComplete: Bool {
        completedAt != nil
    }

    static let notStarted = OnboardingState(
        completedAt: nil,
        activeFlow: .automatic,
        activeTeamID: nil,
        didChooseCheerFallback: false,
        didSeeLineup: false,
        importHandoffTeamID: nil
    )

    static func completed(at date: Date = .now) -> OnboardingState {
        OnboardingState(
            completedAt: date,
            activeFlow: nil,
            activeTeamID: nil,
            didChooseCheerFallback: false,
            didSeeLineup: false,
            importHandoffTeamID: nil
        )
    }

    static func manualChooser(completedAt: Date?) -> OnboardingState {
        OnboardingState(
            completedAt: completedAt,
            activeFlow: .manualChooser,
            activeTeamID: nil,
            didChooseCheerFallback: false,
            didSeeLineup: false,
            importHandoffTeamID: nil
        )
    }
}

struct DeviceIdentity: Codable, Equatable {
    var label: String
}

struct RatingRequestState: Codable, Equatable {
    var successfulGameDaySessionCount: Int
    var hasPlayedQualifyingCueInCurrentGameDayVisit: Bool
    var hasCountedCurrentGameDayVisit: Bool
    var lastCountedSuccessfulGameDaySessionAt: Date?
    var automaticPromptAttemptCount: Int
    var nextAutomaticPromptSessionThreshold: Int

    static let `default` = RatingRequestState(
        successfulGameDaySessionCount: 0,
        hasPlayedQualifyingCueInCurrentGameDayVisit: false,
        hasCountedCurrentGameDayVisit: false,
        lastCountedSuccessfulGameDaySessionAt: nil,
        automaticPromptAttemptCount: 0,
        nextAutomaticPromptSessionThreshold: 10
    )

    enum CodingKeys: String, CodingKey {
        case successfulGameDaySessionCount
        case hasPlayedQualifyingCueInCurrentGameDayVisit
        case hasCountedCurrentGameDayVisit
        case lastCountedSuccessfulGameDaySessionAt
        case automaticPromptAttemptCount
        case nextAutomaticPromptSessionThreshold
        case hasAttemptedAutomaticPrompt
    }

    init(
        successfulGameDaySessionCount: Int,
        hasPlayedQualifyingCueInCurrentGameDayVisit: Bool,
        hasCountedCurrentGameDayVisit: Bool,
        lastCountedSuccessfulGameDaySessionAt: Date?,
        automaticPromptAttemptCount: Int,
        nextAutomaticPromptSessionThreshold: Int
    ) {
        self.successfulGameDaySessionCount = successfulGameDaySessionCount
        self.hasPlayedQualifyingCueInCurrentGameDayVisit = hasPlayedQualifyingCueInCurrentGameDayVisit
        self.hasCountedCurrentGameDayVisit = hasCountedCurrentGameDayVisit
        self.lastCountedSuccessfulGameDaySessionAt = lastCountedSuccessfulGameDaySessionAt
        self.automaticPromptAttemptCount = automaticPromptAttemptCount
        self.nextAutomaticPromptSessionThreshold = nextAutomaticPromptSessionThreshold
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        successfulGameDaySessionCount = try container.decodeIfPresent(Int.self, forKey: .successfulGameDaySessionCount) ?? 0
        hasPlayedQualifyingCueInCurrentGameDayVisit = try container.decodeIfPresent(Bool.self, forKey: .hasPlayedQualifyingCueInCurrentGameDayVisit) ?? false
        hasCountedCurrentGameDayVisit = try container.decodeIfPresent(Bool.self, forKey: .hasCountedCurrentGameDayVisit) ?? false
        lastCountedSuccessfulGameDaySessionAt = try container.decodeIfPresent(Date.self, forKey: .lastCountedSuccessfulGameDaySessionAt)
        automaticPromptAttemptCount = try container.decodeIfPresent(Int.self, forKey: .automaticPromptAttemptCount)
            ?? ((try container.decodeIfPresent(Bool.self, forKey: .hasAttemptedAutomaticPrompt)) == true ? 1 : 0)
        nextAutomaticPromptSessionThreshold = try container.decodeIfPresent(Int.self, forKey: .nextAutomaticPromptSessionThreshold) ?? 10
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(successfulGameDaySessionCount, forKey: .successfulGameDaySessionCount)
        try container.encode(hasPlayedQualifyingCueInCurrentGameDayVisit, forKey: .hasPlayedQualifyingCueInCurrentGameDayVisit)
        try container.encode(hasCountedCurrentGameDayVisit, forKey: .hasCountedCurrentGameDayVisit)
        try container.encodeIfPresent(lastCountedSuccessfulGameDaySessionAt, forKey: .lastCountedSuccessfulGameDaySessionAt)
        try container.encode(automaticPromptAttemptCount, forKey: .automaticPromptAttemptCount)
        try container.encode(nextAutomaticPromptSessionThreshold, forKey: .nextAutomaticPromptSessionThreshold)
    }
}

struct AppState: Codable, Equatable {
    static let currentSchemaVersion = 10

    var schemaVersion: Int
    var appVersion: String
    var deviceIdentity: DeviceIdentity
    var selectedTeamID: UUID?
    var lastGameDayTeamID: UUID?
    var teams: [Team]
    var recentlyDeleted: [RecentlyDeletedItem]
    var snapshots: [SnapshotRecord]
    var experimental: ExperimentalSettings
    var settings: AppSettings
    var lastReadiness: ReadinessStatus?
    var lastSeenWhatsNewReleaseID: String?
    var recentAppleMusicSelections: [RecentAppleMusicSelection]
    var trimDefaults: TrimDefaults
    var onboarding: OnboardingState
    var ratingRequest: RatingRequestState

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appVersion
        case deviceIdentity
        case selectedTeamID
        case lastGameDayTeamID
        case teams
        case recentlyDeleted
        case snapshots
        case experimental
        case settings
        case lastReadiness
        case lastSeenWhatsNewReleaseID
        case recentAppleMusicSelections
        case trimDefaults
        case onboarding
        case ratingRequest
    }

    init(
        schemaVersion: Int,
        appVersion: String,
        deviceIdentity: DeviceIdentity,
        selectedTeamID: UUID?,
        lastGameDayTeamID: UUID? = nil,
        teams: [Team],
        recentlyDeleted: [RecentlyDeletedItem],
        snapshots: [SnapshotRecord],
        experimental: ExperimentalSettings,
        settings: AppSettings,
        lastReadiness: ReadinessStatus?,
        lastSeenWhatsNewReleaseID: String?,
        recentAppleMusicSelections: [RecentAppleMusicSelection],
        trimDefaults: TrimDefaults,
        onboarding: OnboardingState,
        ratingRequest: RatingRequestState
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.deviceIdentity = deviceIdentity
        self.selectedTeamID = selectedTeamID
        self.lastGameDayTeamID = lastGameDayTeamID
        self.teams = teams
        self.recentlyDeleted = recentlyDeleted
        self.snapshots = snapshots
        self.experimental = experimental
        self.settings = settings
        self.lastReadiness = lastReadiness
        self.lastSeenWhatsNewReleaseID = lastSeenWhatsNewReleaseID
        self.recentAppleMusicSelections = recentAppleMusicSelections
        self.trimDefaults = trimDefaults
        self.onboarding = onboarding
        self.ratingRequest = ratingRequest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion) ?? AppMetadata.appVersion
        deviceIdentity = try container.decodeIfPresent(DeviceIdentity.self, forKey: .deviceIdentity) ?? DeviceIdentity(label: "This iPhone")
        selectedTeamID = try container.decodeIfPresent(UUID.self, forKey: .selectedTeamID)
        lastGameDayTeamID = try container.decodeIfPresent(UUID.self, forKey: .lastGameDayTeamID)
        teams = try container.decodeIfPresent([Team].self, forKey: .teams) ?? []
        recentlyDeleted = try container.decodeIfPresent([RecentlyDeletedItem].self, forKey: .recentlyDeleted) ?? []
        snapshots = try container.decodeIfPresent([SnapshotRecord].self, forKey: .snapshots) ?? []
        experimental = try container.decodeIfPresent(ExperimentalSettings.self, forKey: .experimental) ?? .default
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? .default
        lastReadiness = try container.decodeIfPresent(ReadinessStatus.self, forKey: .lastReadiness)
        lastSeenWhatsNewReleaseID = try container.decodeIfPresent(String.self, forKey: .lastSeenWhatsNewReleaseID)
        recentAppleMusicSelections = try container.decodeIfPresent([RecentAppleMusicSelection].self, forKey: .recentAppleMusicSelections) ?? []
        trimDefaults = try container.decodeIfPresent(TrimDefaults.self, forKey: .trimDefaults) ?? .default
        if let decodedOnboarding = try container.decodeIfPresent(OnboardingState.self, forKey: .onboarding) {
            onboarding = decodedOnboarding
        } else {
            onboarding = teams.isEmpty ? .notStarted : .completed()
        }
        ratingRequest = try container.decodeIfPresent(RatingRequestState.self, forKey: .ratingRequest) ?? .default
    }

    static let empty = AppState(
        schemaVersion: currentSchemaVersion,
        appVersion: AppMetadata.appVersion,
        deviceIdentity: DeviceIdentity(label: "This iPhone"),
        selectedTeamID: nil,
        lastGameDayTeamID: nil,
        teams: [],
        recentlyDeleted: [],
        snapshots: [],
        experimental: .default,
        settings: .default,
        lastReadiness: nil,
        lastSeenWhatsNewReleaseID: AppMetadata.whatsNewReleaseID,
        recentAppleMusicSelections: [],
        trimDefaults: .default,
        onboarding: .notStarted,
        ratingRequest: .default
    )
}

struct TeamPackageManifest: Codable {
    /// Kept independent from `AppState.currentSchemaVersion` so additive app-state
    /// migrations do not unnecessarily break team-package compatibility.
    static let currentSchemaVersion = 9

    var schemaVersion: Int
    var appVersion: String
    var exportedAt: Date
    var deviceLabel: String
    var team: Team
}

struct PendingPackageImport: Identifiable {
    let id = UUID()
    var url: URL
    var manifest: TeamPackageManifest
    var transferSummary: PackageTransferSummary
    var opensOnboardingHandoff: Bool

    var team: Team {
        manifest.team
    }

    var playerCount: Int {
        team.players.count
    }

    var playersWithAudioCount: Int {
        team.players.filter { team.cue(for: $0) != nil }.count
    }

    var appleMusicCueCount: Int {
        team.players.filter {
            if case .appleMusic? = team.cue(for: $0)?.source {
                return true
            }
            return false
        }.count
    }

    var localAudioCueCount: Int {
        team.players.filter {
            if case .localAudio? = team.cue(for: $0)?.source {
                return true
            }
            return false
        }.count
    }

    var builtInCueCount: Int {
        team.players.filter {
            if case .builtInClip? = team.cue(for: $0)?.source {
                return true
            }
            return false
        }.count
    }

    var photoCount: Int {
        team.players.filter { $0.photoRelativePath != nil }.count
    }

    var customAnnouncementCount: Int {
        team.players.filter { $0.customAnnouncerRelativePath != nil }.count
    }

    var customClipCount: Int {
        team.teamClips.count
    }
}

struct PendingPackageExport: Identifiable {
    let id = UUID()
    var teamID: UUID
    var teamName: String
    var summary: PackageTransferSummary
}

enum AppPaths {
    nonisolated(unsafe) static var testBaseDirectoryOverride: URL?

    static func baseDirectory() throws -> URL {
        if let testBaseDirectoryOverride {
            try FileManager.default.createDirectory(at: testBaseDirectoryOverride, withIntermediateDirectories: true)
            return testBaseDirectoryOverride
        }

        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let url = base.appendingPathComponent("RollCall", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func stateURL() throws -> URL {
        try baseDirectory().appendingPathComponent("state.json")
    }

    static func unreadableStateRecoveryURL() throws -> URL {
        let fileName = "state-unreadable-\(UUID().uuidString).json"
        return try baseDirectory().appendingPathComponent(fileName)
    }

    static func unreadableStateRecoveryFiles() -> [URL] {
        guard let directory = try? baseDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }
        return files
            .filter {
                $0.lastPathComponent.hasPrefix("state-unreadable-")
                    && $0.pathExtension.lowercased() == "json"
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func telemetryStateURL() throws -> URL {
        try baseDirectory().appendingPathComponent("telemetry-state.json")
    }

    static func assetsDirectory() throws -> URL {
        let url = try baseDirectory().appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func generatedClipsDirectory() throws -> URL {
        let url = try baseDirectory().appendingPathComponent("GeneratedClips", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func assetURL(relativePath: String) throws -> URL {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/") else { throw AppError.invalidImport }

        let components = trimmed.split(separator: "/").map(String.init)
        let rootURL: URL
        let pathComponents: ArraySlice<String>
        if components.first == "GeneratedClips" {
            rootURL = try generatedClipsDirectory()
            pathComponents = components.dropFirst()
        } else {
            rootURL = try assetsDirectory()
            pathComponents = components[...]
        }

        return try pathComponents.reduce(rootURL) { partialURL, part in
                guard part != ".", part != ".." else { throw AppError.invalidImport }
                return partialURL.appendingPathComponent(part)
            }
    }

    static func snapshotsDirectory() throws -> URL {
        let url = try baseDirectory().appendingPathComponent("Snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

extension Cue {
    static func localDefault(source: LocalAudioSource) -> Cue {
        Cue(
            id: UUID(),
            label: source.displayName,
            source: .localAudio(source),
            startTime: 0,
            duration: min(12, source.duration ?? 12),
            fadeOutDuration: CueDefaults.fadeOutDuration,
            pauseAfterAnnouncer: 0.2
        )
    }

    static func appleDefault(source: AppleMusicSource) -> Cue {
        Cue(
            id: UUID(),
            label: source.title,
            source: .appleMusic(source),
            startTime: 0,
            duration: 12,
            fadeOutDuration: CueDefaults.fadeOutDuration,
            pauseAfterAnnouncer: 0.2
        )
    }
}

extension BuiltInClip {
    var sourceID: String? {
        guard case .builtInClip(let source) = cue.source else { return nil }
        return source.id
    }

    static func firstMatchingSourceID(_ sourceID: String, in clips: [BuiltInClip]) -> BuiltInClip? {
        clips.first { $0.sourceID == sourceID }
    }

    static let defaults: [BuiltInClip] = [
        BuiltInClip(id: UUID(), title: "Small Cheer", cue: Cue(id: UUID(), label: "Small Cheer", source: .builtInClip(BuiltInClipSource(id: "small-cheer", displayName: "Small Cheer")), startTime: 0, duration: 5.5, fadeOutDuration: 0.35, pauseAfterAnnouncer: 0.2)),
        BuiltInClip(id: UUID(), title: "Victory Roar", cue: Cue(id: UUID(), label: "Victory Roar", source: .builtInClip(BuiltInClipSource(id: "victory-roar", displayName: "Victory Roar")), startTime: 0, duration: 6.0, fadeOutDuration: 0.35, pauseAfterAnnouncer: 0.2)),
        BuiltInClip(id: UUID(), title: "Stadium Burst", cue: Cue(id: UUID(), label: "Stadium Burst", source: .builtInClip(BuiltInClipSource(id: "stadium-burst", displayName: "Stadium Burst")), startTime: 0, duration: 5.0, fadeOutDuration: 0.35, pauseAfterAnnouncer: 0.2)),
        BuiltInClip(id: UUID(), title: "Rhythmic Clap", cue: Cue(id: UUID(), label: "Rhythmic Clap", source: .builtInClip(BuiltInClipSource(id: "rhythmic-clap", displayName: "Rhythmic Clap")), startTime: 0, duration: 6.0, fadeOutDuration: 0.35, pauseAfterAnnouncer: 0.2)),
        BuiltInClip(id: UUID(), title: "Whistle Pop", cue: Cue(id: UUID(), label: "Whistle Pop", source: .builtInClip(BuiltInClipSource(id: "whistle-pop", displayName: "Whistle Pop")), startTime: 0, duration: 4.0, fadeOutDuration: 0.3, pauseAfterAnnouncer: 0.2)),
    ]
}

extension Team {
    func orderedPlayers(by ids: [UUID]) -> [Player] {
        let lookup = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = ids.compactMap { lookup[$0] }
        // Set membership, not `ids.contains` — this runs on every Game Day render
        // path via `presentPlayersInBattingOrder`, and the linear scan made it
        // O(roster x lineup).
        let orderedIDs = Set(ids)
        let unordered = players.filter { !orderedIDs.contains($0.id) }
        return ordered + unordered
    }

    var battingOrderPlayers: [Player] {
        orderedPlayers(by: session.battingOrder)
    }

    var presentPlayersInBattingOrder: [Player] {
        battingOrderPlayers.filter(\.isPresent)
    }

    var nextBatter: Player? {
        let present = presentPlayersInBattingOrder
        guard !present.isEmpty else { return nil }
        let normalizedIndex = min(max(session.nextBatterIndex, 0), present.count - 1)
        return present[normalizedIndex]
    }

    func gameDayGridPlayers(startingAfter playerID: UUID?) -> [Player] {
        let present = presentPlayersInBattingOrder
        guard present.count > 1 else { return present }
        guard let playerID, let startIndex = present.firstIndex(where: { $0.id == playerID }) else {
            return present
        }

        let firstSegment = present[(startIndex + 1)...]
        let secondSegment = present[...startIndex]
        return Array(firstSegment + secondSegment)
    }

    func gameDayOverridePlayer(activePlayerID: UUID?) -> Player? {
        guard let activePlayerID else { return nil }
        guard activePlayerID != nextBatter?.id else { return nil }
        return presentPlayersInBattingOrder.first(where: { $0.id == activePlayerID })
    }

    static func sample() -> Team {
        let players = [
            Player(id: UUID(), displayName: "Alex Ramirez", uniformNumber: "12", pronunciationOverride: "", photoRelativePath: nil, cue: nil, isPresent: true),
            Player(id: UUID(), displayName: "Jordan Lee", uniformNumber: "4", pronunciationOverride: "", photoRelativePath: nil, cue: nil, isPresent: true),
        ]
        return Team(
            id: UUID(),
            name: "Home Team",
            createdAt: .now,
            modifiedAt: .now,
            players: players,
            builtInClips: BuiltInClip.defaults,
            session: TeamSessionState(activeSessionDate: nil, battingOrder: alphabeticalPlayerIDs(for: players), nextBatterIndex: 0, gameDayAnnouncerMode: .announcerAndSong, battingOrderIsCustomized: false),
            announcerProfile: .default
        )
    }
}

private enum LegacyPlayerDecoder {
    struct LegacyPlayerPayload: Decodable {
        struct LegacyCuePayload: Decodable {
            var announcer: AnnouncerConfig?
        }

        var cue: LegacyCuePayload?
    }

    static func legacyAnnouncerEnabled(in players: [LegacyPlayerPayload]) -> Bool {
        players.contains(where: { $0.cue?.announcer?.isEnabled == true })
    }

    static func teamAnnouncerProfile(from players: [LegacyPlayerPayload]) -> TeamAnnouncerProfile? {
        guard let announcer = players.compactMap({ $0.cue?.announcer }).first else { return nil }
        return TeamAnnouncerProfile(
            phraseTemplate: legacyPhraseTemplate(from: announcer),
            requestedVoiceIdentifier: nil,
            resolvedVoiceIdentifier: nil,
            voiceLanguageCode: "en-US",
            rate: TeamAnnouncerProfile.default.rate,
            pitchMultiplier: TeamAnnouncerProfile.default.pitchMultiplier,
            volume: TeamAnnouncerProfile.default.volume
        )
    }

    private static func legacyPhraseTemplate(from announcer: AnnouncerConfig) -> String {
        switch announcer.template {
        case .nameOnly:
            return "<name>"
        case .numberAndName:
            return announcer.customPrefix.isEmpty ? "Number <number>, <name>" : "\(announcer.customPrefix), number <number>, <name>"
        case .nowBatting:
            let prefix = announcer.customPrefix.isEmpty ? "Now batting" : announcer.customPrefix
            return "\(prefix), number <number>, <name>"
        }
    }
}
