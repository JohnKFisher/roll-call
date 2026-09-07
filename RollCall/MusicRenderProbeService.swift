import Foundation
import MediaPlayer
@preconcurrency import AVFoundation
@preconcurrency import MusicKit

private enum MusicRenderProbeServiceError: LocalizedError {
    case missingLibraryItem
    case exportSessionUnavailable
    case exportFailedWithoutError

    var errorDescription: String? {
        switch self {
        case .missingLibraryItem:
            return "The selected Music Library item is no longer available on this device."
        case .exportSessionUnavailable:
            return "AVAssetExportSession could not create an export session for this media."
        case .exportFailedWithoutError:
            return "The render attempt finished without a usable output file."
        }
    }
}

struct MusicRenderProbeService: Sendable {
    private let audioAssetService: AudioAssetService
    private let musicCatalogService: MusicCatalogService

    init(
        audioAssetService: AudioAssetService = AudioAssetService(),
        musicCatalogService: MusicCatalogService = MusicCatalogService()
    ) {
        self.audioAssetService = audioAssetService
        self.musicCatalogService = musicCatalogService
    }

    func loadLibraryCandidates() throws -> [MusicRenderProbeLibraryCandidate] {
        guard MusicAuthorization.currentStatus == .authorized else {
            throw AppError.musicAuthorizationRequired
        }

        return (MPMediaQuery.songs().items ?? [])
            .compactMap { item in
                let title = (item.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.title! : "Unknown Title")
                let artist = (item.artist?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.artist! : "Unknown Artist")
                return MusicRenderProbeLibraryCandidate(
                    persistentID: item.persistentID,
                    title: title,
                    artistName: artist,
                    duration: item.playbackDuration > 0 ? item.playbackDuration : nil,
                    hasLocalAssetURL: item.assetURL != nil,
                    isCloudItem: item.isCloudItem,
                    playbackStoreID: item.playbackStoreID,
                    albumTitle: item.albumTitle
                )
            }
            .sorted {
                if $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedSame {
                    return $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    func runProbe(for sample: MusicRenderProbeSample) async -> MusicRenderProbeResult {
        let startedAt = Date()
        guard let selection = sample.selection else {
            return MusicRenderProbeResult.make(
                scenario: sample.scenario,
                startedAt: startedAt,
                fullSourceAttempt: .notAttempted(path: .fullSource, detail: "No sample has been assigned."),
                previewProxyAttempt: .notAttempted(path: .previewProxy, detail: "No sample has been assigned.")
            )
        }

        switch selection {
        case .library(let candidate):
            return await probeLibraryCandidate(candidate, scenario: sample.scenario, startedAt: startedAt)
        case .catalog(let candidate):
            return await probeCatalogCandidate(candidate, scenario: sample.scenario, startedAt: startedAt)
        case .local(let candidate):
            return await probeLocalCandidate(candidate, scenario: sample.scenario, startedAt: startedAt)
        }
    }

    private func probeLibraryCandidate(
        _ candidate: MusicRenderProbeLibraryCandidate,
        scenario: MusicRenderProbeScenario,
        startedAt: Date
    ) async -> MusicRenderProbeResult {
        let fullSourceAttempt: MusicRenderProbeAttempt
        let previewProxyAttempt: MusicRenderProbeAttempt

        do {
            guard let item = mediaItem(for: candidate.persistentID) else {
                throw MusicRenderProbeServiceError.missingLibraryItem
            }

            if let assetURL = item.assetURL {
                fullSourceAttempt = await renderAttempt(
                    from: assetURL,
                    path: .fullSource,
                    successDetail: "Readable local asset exported to a temporary probe file."
                )
            } else if candidate.playbackStoreID != nil {
                fullSourceAttempt = .failure(
                    path: .fullSource,
                    category: .protectedUnreadable,
                    detail: "Music Library metadata was readable, but the device did not expose a readable local asset URL."
                )
            } else {
                fullSourceAttempt = .failure(
                    path: .fullSource,
                    category: .sourceUnavailable,
                    detail: "This library item did not expose a readable local asset URL."
                )
            }

            if let playbackStoreID = candidate.playbackStoreID {
                do {
                    let previewURL = try await previewURL(forPlaybackStoreID: playbackStoreID)
                    if let previewURL {
                        previewProxyAttempt = await previewRenderAttempt(from: previewURL)
                    } else {
                        previewProxyAttempt = .notAttempted(
                            path: .previewProxy,
                            detail: "No Apple Music preview or proxy media was exposed for this library item."
                        )
                    }
                } catch {
                    previewProxyAttempt = .failure(
                        path: .previewProxy,
                        category: MusicRenderProbeFailureCategory.classify(error),
                        detail: error.localizedDescription
                    )
                }
            } else {
                previewProxyAttempt = .notAttempted(
                    path: .previewProxy,
                    detail: "This library item does not map to Apple Music preview media."
                )
            }
        } catch {
            let failure = MusicRenderProbeFailureCategory.classify(error)
            return MusicRenderProbeResult.make(
                scenario: scenario,
                startedAt: startedAt,
                fullSourceAttempt: .failure(path: .fullSource, category: failure, detail: error.localizedDescription),
                previewProxyAttempt: .notAttempted(path: .previewProxy, detail: "Full-source setup failed before proxy probing could begin.")
            )
        }

        return MusicRenderProbeResult.make(
            scenario: scenario,
            startedAt: startedAt,
            fullSourceAttempt: fullSourceAttempt,
            previewProxyAttempt: previewProxyAttempt
        )
    }

    private func probeCatalogCandidate(
        _ candidate: MusicRenderProbeCatalogCandidate,
        scenario: MusicRenderProbeScenario,
        startedAt: Date
    ) async -> MusicRenderProbeResult {
        let fullSourceAttempt: MusicRenderProbeAttempt
        if candidate.isCatalogBacked {
            do {
                _ = try await musicCatalogService.song(for: candidate.songID)
                fullSourceAttempt = .failure(
                    path: .fullSource,
                    category: .protectedUnreadable,
                    detail: "Catalog metadata resolved, but public APIs did not expose a readable full-source asset."
                )
            } catch {
                fullSourceAttempt = .failure(
                    path: .fullSource,
                    category: MusicRenderProbeFailureCategory.classify(error),
                    detail: error.localizedDescription
                )
            }
        } else {
            fullSourceAttempt = .failure(
                path: .fullSource,
                category: .sourceUnavailable,
                detail: "This search result only exposed preview/proxy media."
            )
        }

        let previewProxyAttempt: MusicRenderProbeAttempt
        if let previewURL = candidate.previewURL {
            previewProxyAttempt = await previewRenderAttempt(from: previewURL)
        } else {
            previewProxyAttempt = .notAttempted(
                path: .previewProxy,
                detail: "This catalog result did not expose preview media."
            )
        }

        return MusicRenderProbeResult.make(
            scenario: scenario,
            startedAt: startedAt,
            fullSourceAttempt: fullSourceAttempt,
            previewProxyAttempt: previewProxyAttempt
        )
    }

    private func probeLocalCandidate(
        _ candidate: MusicRenderProbeLocalCandidate,
        scenario: MusicRenderProbeScenario,
        startedAt: Date
    ) async -> MusicRenderProbeResult {
        let fullSourceAttempt: MusicRenderProbeAttempt
        do {
            let assetURL = try audioAssetService.assetURL(relativePath: candidate.source.relativePath)
            fullSourceAttempt = await renderAttempt(
                from: assetURL,
                path: .fullSource,
                successDetail: "Roll Call's imported local file exported to a temporary probe file."
            )
        } catch {
            fullSourceAttempt = .failure(
                path: .fullSource,
                category: MusicRenderProbeFailureCategory.classify(error),
                detail: error.localizedDescription
            )
        }

        return MusicRenderProbeResult.make(
            scenario: scenario,
            startedAt: startedAt,
            fullSourceAttempt: fullSourceAttempt,
            previewProxyAttempt: .notAttempted(
                path: .previewProxy,
                detail: "App-owned local imports do not need a separate preview/proxy fallback."
            )
        )
    }

    private func mediaItem(for persistentID: UInt64) -> MPMediaItem? {
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(
            MPMediaPropertyPredicate(
                value: NSNumber(value: persistentID),
                forProperty: MPMediaItemPropertyPersistentID
            )
        )
        return query.items?.first
    }

    private func previewURL(forPlaybackStoreID playbackStoreID: String) async throws -> URL? {
        let song = try await musicCatalogService.song(for: playbackStoreID)
        return song.previewAssets?.first?.url
    }

    private func previewRenderAttempt(from previewURL: URL) async -> MusicRenderProbeAttempt {
        do {
            let temporaryDownload = try await downloadPreviewAsset(from: previewURL)
            defer { try? FileManager.default.removeItem(at: temporaryDownload) }
            return await renderAttempt(
                from: temporaryDownload,
                path: .previewProxy,
                successDetail: "Preview/proxy media exported to a temporary probe file."
            )
        } catch {
            return .failure(
                path: .previewProxy,
                category: MusicRenderProbeFailureCategory.classify(error),
                detail: error.localizedDescription
            )
        }
    }

    private func downloadPreviewAsset(from previewURL: URL) async throws -> URL {
        let (downloadURL, response) = try await URLSession.shared.download(from: previewURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppError.invalidImport
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("RollCallProbe-\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: downloadURL, to: destination)
        return destination
    }

    private func renderAttempt(
        from sourceURL: URL,
        path: MusicRenderProbeAttemptPath,
        successDetail: String
    ) async -> MusicRenderProbeAttempt {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RollCallProbe-\(UUID().uuidString).m4a")

        do {
            try? FileManager.default.removeItem(at: outputURL)
            try await exportProbeClip(from: sourceURL, to: outputURL)
            let exists = FileManager.default.fileExists(atPath: outputURL.path)
            try? FileManager.default.removeItem(at: outputURL)

            guard exists else {
                throw MusicRenderProbeServiceError.exportFailedWithoutError
            }

            return .success(path: path, detail: successDetail)
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            return .failure(
                path: path,
                category: MusicRenderProbeFailureCategory.classify(error),
                detail: error.localizedDescription
            )
        }
    }

    private func exportProbeClip(from sourceURL: URL, to outputURL: URL) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw AppError.noAudioTrack }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw MusicRenderProbeServiceError.exportSessionUnavailable
        }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let clipLength = durationSeconds.isFinite && durationSeconds > 0
            ? max(1, min(durationSeconds, 8))
            : 8
        exportSession.timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: clipLength, preferredTimescale: 600)
        )

        try await exportSession.export(to: outputURL, as: .m4a)
    }
}
