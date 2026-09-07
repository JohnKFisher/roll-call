import AVFoundation
import Foundation
import MediaPlayer
import MusicKit

private enum SongClipGenerationError: Error {
    case missingAudioTrack
    case exportUnavailable
    case missingOutput
}

struct SongClipGenerationService: Sendable {
    static let canRequestAppleMusicOfflineDownload = false

    private let audioAssetService: AudioAssetService

    init(audioAssetService: AudioAssetService = AudioAssetService()) {
        self.audioAssetService = audioAssetService
    }

    func prepare(_ clip: SongClip) async -> SongClipPreparationOutcome {
        guard clip.policy.localClipGenerationEnabled else {
            return sourceBackedOutcome(for: clip.originalSource)
        }

        do {
            guard let source = try readableSource(for: clip.originalSource) else {
                return sourceBackedOutcome(for: clip.originalSource)
            }
            return .generated(try await render(clip: clip, from: source.url))
        } catch let error as AppError {
            switch error {
            case .musicAuthorizationRequired:
                return .needsAppleMusic
            case .invalidImport:
                return .failed(code: .sourceMissing, retryable: false)
            default:
                return .failed(code: .renderFailed, retryable: false)
            }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .failed(code: .sourceMissing, retryable: false)
        } catch let error as URLError {
            let retryable = error.code == .notConnectedToInternet
                || error.code == .networkConnectionLost
                || error.code == .timedOut
            return .failed(code: .transientSystemFailure, retryable: retryable)
        } catch {
            return .failed(code: .renderFailed, retryable: true)
        }
    }

    private func readableSource(for source: SongSource) throws -> (url: URL, downloadedOnDevice: Bool)? {
        switch source {
        case .localAudio(let local):
            let url = try audioAssetService.assetURL(relativePath: local.relativePath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw AppError.invalidImport
            }
            return (url, true)
        case .builtInClip(let builtIn):
            let url = try audioAssetService.assetURL(relativePath: "\(builtIn.id).mp3")
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw AppError.invalidImport
            }
            return (url, true)
        case .appleMusic(let appleMusic):
            guard MusicAuthorization.currentStatus == .authorized else {
                throw AppError.musicAuthorizationRequired
            }
            guard let item = libraryItem(for: appleMusic) else {
                return nil
            }
            guard !item.isCloudItem else {
                return nil
            }
            guard let assetURL = item.assetURL else {
                return nil
            }
            return (assetURL, !item.isCloudItem)
        }
    }

    private func sourceBackedOutcome(for source: SongSource) -> SongClipPreparationOutcome {
        switch source {
        case .localAudio, .builtInClip:
            return .failed(code: .sourceUnreadable, retryable: false)
        case .appleMusic(let appleMusic):
            guard MusicAuthorization.currentStatus == .authorized else {
                return .needsAppleMusic
            }
            let item = libraryItem(for: appleMusic)
            return .sourceBacked(downloadedOnDevice: item.map { !$0.isCloudItem } ?? false)
        }
    }

    private func libraryItem(for source: AppleMusicSource) -> MPMediaItem? {
        if let persistentID = source.libraryPersistentID {
            let query = MPMediaQuery.songs()
            query.addFilterPredicate(
                MPMediaPropertyPredicate(
                    value: NSNumber(value: persistentID),
                    forProperty: MPMediaItemPropertyPersistentID
                )
            )
            return query.items?.first
        }

        return nil
    }

    private func render(clip: SongClip, from sourceURL: URL) async throws -> GeneratedClipAsset {
        let sourceAsset = AVURLAsset(url: sourceURL)
        let tracks = try await sourceAsset.loadTracks(withMediaType: .audio)
        guard let sourceTrack = tracks.first else {
            throw SongClipGenerationError.missingAudioTrack
        }

        let sourceDuration = try await sourceAsset.load(.duration)
        let sourceSeconds = CMTimeGetSeconds(sourceDuration)
        let requestedStart = max(0, clip.requestedSelection.startTime)
        let availableDuration = sourceSeconds.isFinite ? max(0, sourceSeconds - requestedStart) : clip.requestedSelection.duration
        let renderedDuration = min(max(0.25, clip.requestedSelection.duration), availableDuration)
        guard renderedDuration > 0 else {
            throw SongClipGenerationError.missingAudioTrack
        }

        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw SongClipGenerationError.exportUnavailable
        }

        let timeRange = CMTimeRange(
            start: CMTime(seconds: requestedStart, preferredTimescale: 600),
            duration: CMTime(seconds: renderedDuration, preferredTimescale: 600)
        )
        try compositionTrack.insertTimeRange(timeRange, of: sourceTrack, at: .zero)

        let parameters = AVMutableAudioMixInputParameters(track: compositionTrack)
        let fadeInDuration = min(0.04, renderedDuration / 4)
        if fadeInDuration > 0 {
            parameters.setVolumeRamp(
                fromStartVolume: 0,
                toEndVolume: 1,
                timeRange: CMTimeRange(
                    start: .zero,
                    duration: CMTime(seconds: fadeInDuration, preferredTimescale: 600)
                )
            )
        }
        let fadeOutDuration = min(max(0, clip.requestedSelection.fadeOutDuration), renderedDuration)
        if fadeOutDuration > 0 {
            parameters.setVolumeRamp(
                fromStartVolume: 1,
                toEndVolume: 0,
                timeRange: CMTimeRange(
                    start: CMTime(seconds: renderedDuration - fadeOutDuration, preferredTimescale: 600),
                    duration: CMTime(seconds: fadeOutDuration, preferredTimescale: 600)
                )
            )
        }
        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [parameters]

        try Task.checkCancellation()
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw SongClipGenerationError.exportUnavailable
        }

        let generatedDirectory = try AppPaths.generatedClipsDirectory()
        let fileName = "\(clip.id.uuidString.lowercased())-\(clip.generationKey.prefix(16)).m4a"
        let destinationURL = generatedDirectory.appendingPathComponent(fileName)
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RollCallGenerated-\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: temporaryURL)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        exportSession.audioMix = audioMix
        exportSession.shouldOptimizeForNetworkUse = false
        try await exportSession.export(to: temporaryURL, as: .m4a)
        try Task.checkCancellation()
        guard FileManager.default.fileExists(atPath: temporaryURL.path) else {
            throw SongClipGenerationError.missingOutput
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)

        return GeneratedClipAsset(
            relativePath: "GeneratedClips/\(fileName)",
            status: .ready,
            renderedSelection: SongClipSelection(
                startTime: requestedStart,
                duration: renderedDuration,
                fadeOutDuration: fadeOutDuration
            ),
            generationKey: clip.generationKey,
            generatedAt: .now
        )
    }
}
