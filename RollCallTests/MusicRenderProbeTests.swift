@preconcurrency import AVFoundation
import XCTest
@testable import RollCall

final class MusicRenderProbeTests: XCTestCase {
    private var temp: RollCallTemporaryDirectory!

    override func setUpWithError() throws {
        temp = try RollCallTemporaryDirectory()
        AppPaths.testBaseDirectoryOverride = temp.fileURL("AppSupport")
    }

    override func tearDownWithError() throws {
        AppPaths.testBaseDirectoryOverride = nil
        temp = nil
    }

    func testFailureClassificationMapsPermissionNetworkAndPermanentCases() {
        XCTAssertEqual(
            MusicRenderProbeFailureCategory.classify(AppError.musicAuthorizationRequired),
            .permissionNeeded
        )
        XCTAssertEqual(
            MusicRenderProbeFailureCategory.classify(URLError(.notConnectedToInternet)),
            .networkNeeded
        )
        XCTAssertEqual(
            MusicRenderProbeFailureCategory.classify(AppError.invalidImport),
            .renderFailedPermanent
        )
    }

    func testRedactedSummaryOmitsSongTitlesArtistsAndIDs() throws {
        let sample = MusicRenderProbeSample(
            scenario: .appleMusicCatalogOnly,
            selection: .catalog(
                MusicRenderProbeCatalogCandidate(
                    songID: "secret-song-id-123",
                    title: "Secret Walkup Song",
                    artistName: "Hidden Artist",
                    duration: 12,
                    previewURL: URL(string: "https://example.com/preview.m4a"),
                    isCatalogBacked: true
                )
            ),
            result: MusicRenderProbeResult.make(
                scenario: .appleMusicCatalogOnly,
                startedAt: Date(timeIntervalSince1970: 100),
                fullSourceAttempt: .failure(
                    path: .fullSource,
                    category: .protectedUnreadable,
                    detail: "No readable asset URL."
                ),
                previewProxyAttempt: .success(
                    path: .previewProxy,
                    detail: "Preview/proxy media exported to a temporary probe file."
                ),
                finishedAt: Date(timeIntervalSince1970: 105)
            )
        )

        let summary = MusicRenderProbeRedactedSummary.make(
            samples: [sample],
            authorizationStatus: "Authorized",
            playbackCapability: "Full Song",
            generatedAt: Date(timeIntervalSince1970: 110)
        )

        let data = try JSONEncoder().encode(summary)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(json.contains("Secret Walkup Song"))
        XCTAssertFalse(json.contains("Hidden Artist"))
        XCTAssertFalse(json.contains("secret-song-id-123"))
        XCTAssertTrue(json.contains("appleMusicCatalogOnly"))
        XCTAssertTrue(json.contains("previewOnlyRenderable"))
    }

    func testLocalProbeExportsM4AAndCleansTemporaryOutput() async throws {
        let relativePath = "probe-source.caf"
        let sourceURL = try AppPaths.assetURL(relativePath: relativePath)
        try writeSilentAudio(to: sourceURL, duration: 1.25)
        let source = LocalAudioSource(
            id: UUID(),
            displayName: "Probe Source",
            relativePath: relativePath,
            duration: 1.25,
            importedAt: RollCallTestFixtures.now,
            hiddenOriginNote: nil
        )
        let sample = MusicRenderProbeSample(
            scenario: .appLocalImportedSong,
            selection: .local(
                MusicRenderProbeLocalCandidate(
                    id: UUID(),
                    source: source,
                    teamName: "Test Team",
                    playerName: "Test Player"
                )
            )
        )
        let temporaryFilesBefore = try probeTemporaryFiles()

        let result = await MusicRenderProbeService().runProbe(for: sample)

        XCTAssertEqual(result.verdict, .fullSourceRenderable)
        XCTAssertEqual(result.fullSourceAttempt.status, .succeeded)
        XCTAssertEqual(result.previewProxyAttempt.status, .notAttempted)
        XCTAssertEqual(try probeTemporaryFiles(), temporaryFilesBefore)
    }

    private func writeSilentAudio(to url: URL, duration: TimeInterval) throws {
        let format = try XCTUnwrap(
            AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        )
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        )
        buffer.frameLength = frameCount
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func probeTemporaryFiles() throws -> Set<String> {
        Set(
            try FileManager.default.contentsOfDirectory(
                at: FileManager.default.temporaryDirectory,
                includingPropertiesForKeys: nil
            )
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix("RollCallProbe-") && $0.hasSuffix(".m4a") }
        )
    }
}

final class VideoAudioImportExportTests: XCTestCase {
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
    func testVideoImportExtractsM4AAndCleansTemporaryExport() async throws {
        let sourceVideoURL = temp.fileURL("video-with-audio.mov")
        try await writeVideoWithAudio(to: sourceVideoURL)
        let temporaryFilesBefore = try anonymousTemporaryM4AFiles()

        let source = try await AudioAssetService().importMedia(from: sourceVideoURL)

        XCTAssertEqual(URL(fileURLWithPath: source.relativePath).pathExtension, "m4a")
        let storedURL = try AppPaths.assetURL(relativePath: source.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storedURL.path))
        let storedAsset = AVURLAsset(url: storedURL)
        let audioTracks = try await storedAsset.loadTracks(withMediaType: .audio)
        let videoTracks = try await storedAsset.loadTracks(withMediaType: .video)
        let duration = CMTimeGetSeconds(try await storedAsset.load(.duration))
        XCTAssertFalse(audioTracks.isEmpty)
        XCTAssertTrue(videoTracks.isEmpty)
        XCTAssertGreaterThan(duration, 0.5)
        XCTAssertLessThan(duration, 1.5)
        XCTAssertEqual(try anonymousTemporaryM4AFiles(), temporaryFilesBefore)
    }

    @MainActor
    private func writeVideoWithAudio(to outputURL: URL) async throws {
        let videoOnlyURL = temp.fileURL("video-only.mov")
        let audioOnlyURL = temp.fileURL("audio-only.caf")
        try await writeSilentVideo(to: videoOnlyURL)
        try writeSilentAudio(to: audioOnlyURL, duration: 1)

        let videoAsset = AVURLAsset(url: videoOnlyURL)
        let audioAsset = AVURLAsset(url: audioOnlyURL)
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        let sourceVideoTrack = try XCTUnwrap(videoTracks.first)
        let sourceAudioTrack = try XCTUnwrap(audioTracks.first)
        let videoDuration = try await videoAsset.load(.duration)
        let audioDuration = try await audioAsset.load(.duration)
        let duration = CMTimeMinimum(videoDuration, audioDuration)
        XCTAssertGreaterThan(CMTimeGetSeconds(duration), 0)

        let composition = AVMutableComposition()
        let compositionVideoTrack = try XCTUnwrap(
            composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        )
        let compositionAudioTrack = try XCTUnwrap(
            composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        )
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        try compositionVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
        try compositionAudioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)

        let exportSession = try XCTUnwrap(
            AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            )
        )
        try? FileManager.default.removeItem(at: outputURL)
        try await exportSession.export(to: outputURL, as: .mov)
    }

    @MainActor
    private func writeSilentVideo(to outputURL: URL) async throws {
        try? FileManager.default.removeItem(at: outputURL)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 32,
                AVVideoHeightKey: 32,
            ]
        )
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 32,
                kCVPixelBufferHeightKey as String: 32,
            ]
        )
        guard writer.canAdd(input) else {
            throw mediaTestError("Could not add the synthetic video input.")
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? mediaTestError("Could not start the synthetic video writer.")
        }
        writer.startSession(atSourceTime: .zero)
        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw mediaTestError("The synthetic video writer did not create a pixel-buffer pool.")
        }

        let writerReadinessDeadline = ContinuousClock.now + .seconds(10)
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData,
                  ContinuousClock.now < writerReadinessDeadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            guard input.isReadyForMoreMediaData else {
                throw mediaTestError("The synthetic video input stopped accepting frames.")
            }
            var optionalPixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(
                nil,
                pixelBufferPool,
                &optionalPixelBuffer
            )
            guard status == kCVReturnSuccess, let pixelBuffer = optionalPixelBuffer else {
                throw mediaTestError("Could not allocate a synthetic video frame.")
            }
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
                baseAddress.initializeMemory(
                    as: UInt8.self,
                    repeating: 0,
                    count: CVPixelBufferGetBytesPerRow(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer)
                )
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            guard adaptor.append(
                pixelBuffer,
                withPresentationTime: CMTime(value: Int64(frame), timescale: 30)
            ) else {
                throw writer.error ?? mediaTestError("Could not append a synthetic video frame.")
            }
        }

        writer.endSession(atSourceTime: CMTime(value: 30, timescale: 30))
        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }
        guard writer.status == .completed else {
            throw writer.error ?? mediaTestError("The synthetic video writer did not finish.")
        }
    }

    private func writeSilentAudio(to url: URL, duration: TimeInterval) throws {
        let format = try XCTUnwrap(
            AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        )
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        )
        buffer.frameLength = frameCount
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func anonymousTemporaryM4AFiles() throws -> Set<String> {
        Set(
            try FileManager.default.contentsOfDirectory(
                at: FileManager.default.temporaryDirectory,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "m4a" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { UUID(uuidString: $0) != nil }
        )
    }

    private func mediaTestError(_ description: String) -> NSError {
        NSError(
            domain: "VideoAudioImportExportTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}
