import Foundation
import CryptoKit

enum SongSource: Codable, Equatable {
    case appleMusic(AppleMusicSource)
    case localAudio(LocalAudioSource)
    case builtInClip(BuiltInClipSource)

    private enum CodingKeys: String, CodingKey {
        case type
        case appleMusic
        case localAudio
        case builtInClip
    }

    private enum Kind: String, Codable {
        case appleMusic
        case localAudio
        case builtInClip
    }

    init(cueSource: CueSource) {
        switch cueSource {
        case .appleMusic(let source):
            self = .appleMusic(source)
        case .localAudio(let source):
            self = .localAudio(source)
        case .builtInClip(let source):
            self = .builtInClip(source)
        }
    }

    var cueSource: CueSource {
        switch self {
        case .appleMusic(let source):
            return .appleMusic(source)
        case .localAudio(let source):
            return .localAudio(source)
        case .builtInClip(let source):
            return .builtInClip(source)
        }
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
        case .appleMusic(let source):
            try container.encode(Kind.appleMusic, forKey: .type)
            try container.encode(source, forKey: .appleMusic)
        case .localAudio(let source):
            try container.encode(Kind.localAudio, forKey: .type)
            try container.encode(source, forKey: .localAudio)
        case .builtInClip(let source):
            try container.encode(Kind.builtInClip, forKey: .type)
            try container.encode(source, forKey: .builtInClip)
        }
    }
}

struct SongClipSelection: Codable, Equatable {
    var startTime: TimeInterval
    var duration: TimeInterval
    var fadeOutDuration: TimeInterval
}

enum GeneratedClipAssetStatus: String, Codable, Equatable {
    case none
    case pending
    case ready
    case failedRetryable
    case failedPermanent
}

struct GeneratedClipAsset: Codable, Equatable {
    var relativePath: String?
    var status: GeneratedClipAssetStatus
    var renderedSelection: SongClipSelection?
    var generationKey: String?
    var generatedAt: Date?
}

enum SongClipPlaybackReadiness: String, Codable, Equatable {
    case localClipReady
    case sourceBackedReady
    case sourceBackedDownloaded
    case needsAppleMusic
    case needsRepair
}

enum SongClipPortability: String, Codable, Equatable {
    case portableLocalClip
    case sourceReferenceOnly
    case metadataOnly
}

struct SongClipReadinessInputs: Codable, Equatable {
    var playback: SongClipPlaybackReadiness
    var sourceAvailableOnDevice: Bool
    var downloadedOnDevice: Bool
}

struct SongClipPortabilityInputs: Codable, Equatable {
    var portability: SongClipPortability
    var generatedAssetCanBeExported: Bool
}

struct SongClipRetryMetadata: Codable, Equatable {
    var attemptCount: Int
    var lastAttemptAt: Date?
    var nextRetryAt: Date?
    var lastFailureCode: String?

    static let none = SongClipRetryMetadata(
        attemptCount: 0,
        lastAttemptAt: nil,
        nextRetryAt: nil,
        lastFailureCode: nil
    )
}

enum SongClipPreparationFailureCode: String, Codable, Equatable {
    case sourceMissing
    case sourceUnreadable
    case renderFailed
    case musicAuthorizationRequired
    case transientSystemFailure
}

enum AppleMusicHandlingPolicy: String, Codable, Equatable {
    case readableLocalOnly
}

struct SongClipPolicy: Codable, Equatable {
    var localClipGenerationEnabled: Bool
    var appleMusicHandlingPolicy: AppleMusicHandlingPolicy
    var autoDownloadEligibleSongsEnabled: Bool
    var generationPolicyVersion: Int

    static let current = SongClipPolicy(
        localClipGenerationEnabled: true,
        appleMusicHandlingPolicy: .readableLocalOnly,
        autoDownloadEligibleSongsEnabled: false,
        generationPolicyVersion: 1
    )
}

struct SongClip: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String?
    var originalSource: SongSource
    var requestedSelection: SongClipSelection
    var pauseAfterAnnouncer: TimeInterval
    var generatedAsset: GeneratedClipAsset
    var readinessInputs: SongClipReadinessInputs
    var portabilityInputs: SongClipPortabilityInputs
    var retryMetadata: SongClipRetryMetadata
    var policy: SongClipPolicy
    var sourceLineageClipID: UUID?

    init(cue: Cue) {
        id = cue.id
        displayName = cue.label
        originalSource = SongSource(cueSource: cue.source)
        requestedSelection = SongClipSelection(
            startTime: cue.startTime,
            duration: cue.duration,
            fadeOutDuration: cue.fadeOutDuration
        )
        pauseAfterAnnouncer = cue.pauseAfterAnnouncer
        generatedAsset = GeneratedClipAsset(
            relativePath: nil,
            status: .none,
            renderedSelection: nil,
            generationKey: nil,
            generatedAt: nil
        )
        readinessInputs = Self.defaultReadiness(for: cue.source)
        portabilityInputs = Self.defaultPortability(for: cue.source)
        retryMetadata = .none
        policy = .current
        sourceLineageClipID = nil
    }

    var hasCurrentGeneratedAsset: Bool {
        generatedAsset.status == .ready
            && generatedAsset.generationKey == generationKey
            && generatedAsset.relativePath != nil
    }

    var playbackCue: Cue {
        let usesGeneratedAsset = hasCurrentGeneratedAsset
        let selection = usesGeneratedAsset
            ? generatedAsset.renderedSelection ?? requestedSelection
            : requestedSelection
        let source: CueSource

        if usesGeneratedAsset, let relativePath = generatedAsset.relativePath {
            source = .localAudio(
                LocalAudioSource(
                    id: id,
                    displayName: displayName ?? "Walk-Up Song",
                    relativePath: relativePath,
                    duration: selection.duration,
                    importedAt: generatedAsset.generatedAt ?? .now,
                    hiddenOriginNote: nil
                )
            )
        } else {
            source = originalSource.cueSource
        }

        return Cue(
            id: id,
            label: displayName ?? "Walk-Up Song",
            source: source,
            startTime: usesGeneratedAsset ? 0 : selection.startTime,
            duration: selection.duration,
            fadeOutDuration: usesGeneratedAsset ? 0 : selection.fadeOutDuration,
            pauseAfterAnnouncer: pauseAfterAnnouncer
        )
    }

    var editingCue: Cue {
        Cue(
            id: id,
            label: displayName ?? "Walk-Up Song",
            source: originalSource.cueSource,
            startTime: requestedSelection.startTime,
            duration: requestedSelection.duration,
            fadeOutDuration: requestedSelection.fadeOutDuration,
            pauseAfterAnnouncer: pauseAfterAnnouncer
        )
    }

    var generationKey: String {
        let sourceKey: String
        switch originalSource {
        case .appleMusic(let source):
            sourceKey = "appleMusic|\(source.songID)"
        case .localAudio(let source):
            sourceKey = "localAudio|\(source.id.uuidString)|\(source.relativePath)"
        case .builtInClip(let source):
            sourceKey = "builtInClip|\(source.id)"
        }

        let rawValue = [
            sourceKey,
            String(format: "%.3f", requestedSelection.startTime),
            String(format: "%.3f", requestedSelection.duration),
            String(format: "%.3f", requestedSelection.fadeOutDuration),
            String(policy.generationPolicyVersion),
            policy.appleMusicHandlingPolicy.rawValue
        ].joined(separator: "|")
        return SHA256.hash(data: Data(rawValue.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func isExactCreativeDuplicate(of other: SongClip) -> Bool {
        originalSource == other.originalSource
            && requestedSelection == other.requestedSelection
            && pauseAfterAnnouncer == other.pauseAfterAnnouncer
    }

    func privateCopy() -> SongClip {
        var copy = self
        copy.id = UUID()
        copy.sourceLineageClipID = id
        return copy
    }

    func playerSongCopy() -> SongClip {
        var copy = privateCopy()
        copy.pauseAfterAnnouncer = 0.2
        return copy
    }

    func customClipCopy() -> SongClip {
        var copy = privateCopy()
        copy.pauseAfterAnnouncer = 0
        return copy
    }

    private static func defaultReadiness(for source: CueSource) -> SongClipReadinessInputs {
        switch source {
        case .localAudio, .builtInClip:
            return SongClipReadinessInputs(
                playback: .sourceBackedReady,
                sourceAvailableOnDevice: true,
                downloadedOnDevice: true
            )
        case .appleMusic:
            return SongClipReadinessInputs(
                playback: .sourceBackedReady,
                sourceAvailableOnDevice: true,
                downloadedOnDevice: false
            )
        }
    }

    private static func defaultPortability(for source: CueSource) -> SongClipPortabilityInputs {
        switch source {
        case .localAudio, .builtInClip:
            return SongClipPortabilityInputs(
                portability: .portableLocalClip,
                generatedAssetCanBeExported: true
            )
        case .appleMusic:
            return SongClipPortabilityInputs(
                portability: .sourceReferenceOnly,
                generatedAssetCanBeExported: false
            )
        }
    }
}

enum SongClipPreparationTrigger: String, Codable, Equatable {
    case assignmentSaved
    case appLaunch
    case foreground
    case playerEditor
    case readiness
    case authorizationChanged
    case importRepair
    case explicitTryNow
    case retry
}

struct SongClipPreparationRequest: Equatable, Identifiable {
    enum Target: Equatable, Hashable {
        case player(UUID)
        case teamClip(UUID)
    }

    var id: UUID
    var teamID: UUID
    var target: Target
    var clipID: UUID
    var generationKey: String
    var trigger: SongClipPreparationTrigger
    var isExplicit: Bool

    func matches(_ clip: SongClip) -> Bool {
        clip.id == clipID && clip.generationKey == generationKey
    }
}

enum PackageClipTransferState: String, Codable, Equatable {
    case localClipIncluded
    case sourceReferenceOnly
    case needsAppleMusicCheck
    case needsAppleMusic
    case stillPreparing
    case needsRepair
    case photoSourceMissing
}

struct PackageTransferSummary: Codable, Equatable {
    var localClipIncludedCount: Int
    var sourceReferenceOnlyCount: Int
    var needsAppleMusicCount: Int
    var stillPreparingCount: Int
    var needsRepairCount: Int

    var totalClipCount: Int {
        localClipIncludedCount
            + sourceReferenceOnlyCount
            + needsAppleMusicCount
            + stillPreparingCount
            + needsRepairCount
    }

    var hasDeviceDependentClips: Bool {
        sourceReferenceOnlyCount > 0 || needsAppleMusicCount > 0
    }

    var hasUnresolvedClips: Bool {
        stillPreparingCount > 0 || needsRepairCount > 0
    }
}

struct PackageImportAudit: Identifiable, Equatable {
    struct Item: Identifiable, Equatable {
        enum Destination: Equatable {
            case player(UUID)
            case teamClip(UUID)
        }

        var id: UUID
        var destination: Destination
        var title: String
        var state: PackageClipTransferState
        var detail: String
    }

    var id = UUID()
    var teamID: UUID
    var teamName: String
    var items: [Item]

    var summary: PackageTransferSummary {
        PackageTransferSummary(
            localClipIncludedCount: items.filter { $0.state == .localClipIncluded }.count,
            sourceReferenceOnlyCount: items.filter { $0.state == .sourceReferenceOnly }.count,
            needsAppleMusicCount: items.filter { $0.state == .needsAppleMusic || $0.state == .needsAppleMusicCheck }.count,
            stillPreparingCount: items.filter { $0.state == .stillPreparing }.count,
            needsRepairCount: items.filter { $0.state == .needsRepair }.count
        )
    }

    func retargeted(from _: UUID, to teamID: UUID, teamName: String) -> PackageImportAudit {
        var copy = self
        copy.teamID = teamID
        copy.teamName = teamName
        return copy
    }
}

enum SongClipPreparationOutcome: Equatable {
    case generated(GeneratedClipAsset)
    case sourceBacked(downloadedOnDevice: Bool)
    case needsAppleMusic
    case failed(code: SongClipPreparationFailureCode, retryable: Bool)
}

enum SongAssignment: Codable, Equatable {
    case privateClip(SongClip)
    // Compatibility-only state for old data whose shared clip cannot currently be resolved.
    // It remains non-playable but must survive a save rather than being silently discarded.
    case unresolvedLegacySharedTeamClip(UUID)

    private enum CodingKeys: String, CodingKey {
        case type
        case privateClip
        case sharedTeamClipID
    }

    private enum Kind: String, Codable {
        case privateClip
        case sharedTeamClip
    }

    var privateClip: SongClip? {
        guard case .privateClip(let clip) = self else { return nil }
        return clip
    }

    var legacySharedTeamClipID: UUID? {
        guard case .unresolvedLegacySharedTeamClip(let clipID) = self else { return nil }
        return clipID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .privateClip:
            self = .privateClip(try container.decode(SongClip.self, forKey: .privateClip))
        case .sharedTeamClip:
            self = .unresolvedLegacySharedTeamClip(try container.decode(UUID.self, forKey: .sharedTeamClipID))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .privateClip(let clip):
            try container.encode(Kind.privateClip, forKey: .type)
            try container.encode(clip, forKey: .privateClip)
        case .unresolvedLegacySharedTeamClip(let clipID):
            try container.encode(Kind.sharedTeamClip, forKey: .type)
            try container.encode(clipID, forKey: .sharedTeamClipID)
        }
    }
}
