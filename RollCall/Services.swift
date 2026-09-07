import AVFAudio
import AVFoundation
import Foundation
import MediaPlayer
import OSLog
@preconcurrency import MusicKit
import Network
import StoreKit
import UniformTypeIdentifiers
import ZIPFoundation

enum AppError: LocalizedError {
    case missingPreview
    case invalidImport
    case unsupportedImportVersion
    case unsupportedSavedStateVersion
    case invalidSearchTerm
    case musicSearchUnavailable
    case musicAuthorizationRequired
    case musicSubscriptionRequired
    case appleMusicSongUnavailable
    case invalidCSV
    case noAudioTrack
    case microphonePermissionDenied
    case recordingUnavailable
    case customIntroSaveFailed(String)
    case invalidAnnouncerText
    case invalidAnnouncerAudio
    case announcerGenerationTimedOut
    case missingBuiltInClip
    case appleMusicFullSongCatalogUnavailable
    case noSelectedTeam
    case noAppleMusicTeamCues
    case appleMusicPlaylistSyncFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPreview:
            return "This Apple Music selection does not expose preview media for fallback playback."
        case .invalidImport:
            return "That file could not be imported."
        case .unsupportedImportVersion:
            return "That package was created by a newer Roll Call version. Update Roll Call, then try importing it again."
        case .unsupportedSavedStateVersion:
            return "Saved Roll Call data was created by a newer app version. Update Roll Call to recover that data."
        case .invalidSearchTerm:
            return "Enter a song title, artist, or both before searching."
        case .musicSearchUnavailable:
            return "Song search is temporarily unavailable."
        case .musicAuthorizationRequired:
            return "Allow Apple Music access to search and use Apple Music songs."
        case .musicSubscriptionRequired:
            return "No Apple Music playback subscription is active. You can only choose from the available preview clip."
        case .appleMusicSongUnavailable:
            return "That Apple Music song is unavailable for full-song playback right now."
        case .invalidCSV:
            return "That CSV could not be parsed. Use a header row with name and number, or simple two-column rows."
        case .noAudioTrack:
            return "That video does not contain an audio track that Roll Call can import."
        case .microphonePermissionDenied:
            return "Microphone access is required to record an Announcement Cue."
        case .recordingUnavailable:
            return "Custom announcer recording is not available right now."
        case .customIntroSaveFailed(let detail):
            return "Roll Call could not save that Announcement Cue recording. [\(AppMetadata.appVersion) build \(AppMetadata.buildNumber) \(AppMetadata.customIntroStorageMarker)] \(detail)"
        case .invalidAnnouncerText:
            return "Enter announcer text before generating or previewing built-in voice audio."
        case .invalidAnnouncerAudio:
            return "Roll Call could not create a usable built-in announcer clip for this voice on this device."
        case .announcerGenerationTimedOut:
            return "Built-in voice generation took too long and was stopped. Try a shorter phrase or a different installed voice."
        case .missingBuiltInClip:
            return "A built-in General Clip could not be loaded from the app bundle."
        case .appleMusicFullSongCatalogUnavailable:
            return "Roll Call could not load a full-song Apple Music catalog result. Check Apple Music account access and the MusicKit app service, then try again."
        case .noSelectedTeam:
            return "Select a team before updating an Apple Music team playlist."
        case .noAppleMusicTeamCues:
            return "No Apple Music song cues found for this team."
        case .appleMusicPlaylistSyncFailed(let message):
            return "Apple Music could not update this team playlist. \(message)"
        }
    }
}

enum SupportContributionKind: String, CaseIterable, Identifiable {
    case oneTime
    case recurring

    var id: String { rawValue }
}

struct SupportProductDefinition: Identifiable, Equatable {
    let productID: String
    let kind: SupportContributionKind
    let title: String
    let subtitle: String
    let priceSuffix: String?

    var id: String { productID }

    static let all: [SupportProductDefinition] = [
        SupportProductDefinition(
            productID: "com.sidelarklabs.rollcall.support.small",
            kind: .oneTime,
            title: "Tip of the Cap",
            subtitle: "A small cheer for keeping Roll Call going",
            priceSuffix: nil
        ),
        SupportProductDefinition(
            productID: "com.sidelarklabs.rollcall.support.medium",
            kind: .oneTime,
            title: "Dugout High Five",
            subtitle: "A little extra cheer for the team",
            priceSuffix: nil
        ),
        SupportProductDefinition(
            productID: "com.sidelarklabs.rollcall.support.large",
            kind: .oneTime,
            title: "Walk-Up Hero",
            subtitle: "Helps keep the walk-up magic improving",
            priceSuffix: nil
        ),
        SupportProductDefinition(
            productID: "com.sidelarklabs.rollcall.support.legendary",
            kind: .oneTime,
            title: "Grand Slam Legend",
            subtitle: "A big thank-you for the whole lineup",
            priceSuffix: nil
        ),
        SupportProductDefinition(
            productID: "com.sidelarklabs.rollcall.support.monthly",
            kind: .recurring,
            title: "Season Supporter",
            subtitle: "Monthly support to keep Roll Call maintained for every team",
            priceSuffix: "/mo"
        ),
        SupportProductDefinition(
            productID: "com.sidelarklabs.rollcall.support.yearly",
            kind: .recurring,
            title: "All-Star Season Supporter",
            subtitle: "Yearly support for compatibility, fixes, and improvements",
            priceSuffix: "/yr"
        )
    ]
}

struct SupportProductOption: Identifiable {
    let definition: SupportProductDefinition
    let displayPrice: String

    var id: String { definition.productID }
}

private struct SupportLocalCache: Codable, Equatable {
    var hasSeenVerifiedSupport: Bool
    var lastVerifiedProductID: String?
    var lastVerifiedTitle: String?
    var lastVerifiedAt: Date?
    var activeSubscriptionProductID: String?
    var activeSubscriptionTitle: String?

    static let empty = SupportLocalCache(
        hasSeenVerifiedSupport: false,
        lastVerifiedProductID: nil,
        lastVerifiedTitle: nil,
        lastVerifiedAt: nil,
        activeSubscriptionProductID: nil,
        activeSubscriptionTitle: nil
    )
}

private extension SupportLocalCache {
    mutating func recordVerifiedSupport(
        productID: String,
        title: String,
        kind: SupportContributionKind,
        purchasedAt: Date
    ) {
        hasSeenVerifiedSupport = true
        lastVerifiedProductID = productID
        lastVerifiedTitle = title
        lastVerifiedAt = purchasedAt

        if kind == .recurring {
            activeSubscriptionProductID = productID
            activeSubscriptionTitle = title
        }
    }
}

@MainActor
final class StoreKitSupportTransactionObserver {
    static let shared = StoreKitSupportTransactionObserver()

    private var updatesTask: Task<Void, Never>?

    private init() {}

    func start() {
        guard updatesTask == nil else { return }

        updatesTask = Task {
            for await verification in Transaction.updates {
                await StoreKitSupportStore.handleTransactionUpdate(verification)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }
}

@MainActor
final class StoreKitSupportStore: ObservableObject {
    @Published private(set) var oneTimeOptions: [SupportProductOption] = []
    @Published private(set) var recurringOptions: [SupportProductOption] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var productLoadMessage: String?
    @Published private(set) var purchaseMessage: String?
    @Published private(set) var purchaseInProgressProductID: String?
    @Published private(set) var isRestoring = false
    @Published private(set) var hasVerifiedSupport = false
    @Published private(set) var activeSubscriptionTitle: String?

    private var productsByID: [String: Product] = [:]
    private var cache: SupportLocalCache

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.cache = Self.loadCache(from: userDefaults)
        applyCache()
    }

    private let userDefaults: UserDefaults

    func refreshOnAppear() async {
        await loadProductsIfNeeded()
        await refreshSupportStatusFromStoreKit()
    }

    func loadProductsIfNeeded() async {
        guard productsByID.isEmpty else {
            rebuildOptions()
            return
        }

        isLoadingProducts = true
        productLoadMessage = nil
        defer { isLoadingProducts = false }

        do {
            let identifiers = SupportProductDefinition.all.map(\.productID)
            let products = try await Product.products(for: identifiers)
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            rebuildOptions()

            let missingCount = identifiers.filter { productsByID[$0] == nil }.count
            if products.isEmpty {
                productLoadMessage = "Support options are unavailable right now. Please try again later."
            } else if missingCount > 0 {
                productLoadMessage = "Some support options are temporarily unavailable."
            }
        } catch {
            productsByID = [:]
            oneTimeOptions = []
            recurringOptions = []
            productLoadMessage = "Support options are unavailable right now. Please try again later."
        }
    }

    func retryLoadingProducts() async {
        productsByID = [:]
        await loadProductsIfNeeded()
    }

    func purchase(_ option: SupportProductOption) async {
        guard let product = productsByID[option.id] else {
            purchaseMessage = "That support option is unavailable right now. Please try again later."
            return
        }

        purchaseInProgressProductID = option.id
        purchaseMessage = nil
        defer { purchaseInProgressProductID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.verifiedTransaction(from: verification)
                recordVerifiedSupport(productID: transaction.productID, purchasedAt: transaction.purchaseDate)
                await transaction.finish()
                purchaseMessage = "Thanks for supporting Roll Call."
            case .pending:
                purchaseMessage = "Purchase pending. Roll Call will update here when it completes."
            case .userCancelled:
                break
            @unknown default:
                purchaseMessage = "Support could not be completed. Please try again later."
            }
        } catch {
            purchaseMessage = "Support could not be completed. Please try again later."
        }
    }

    func restoreSupportSubscription() async {
        isRestoring = true
        purchaseMessage = nil
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshSupportStatusFromStoreKit()
            purchaseMessage = activeSubscriptionTitle == nil
                ? "No active support subscription was found for this Apple ID."
                : "Support subscription restored."
        } catch {
            purchaseMessage = "Support could not be restored right now. Please try again later."
        }
    }

    private func refreshSupportStatusFromStoreKit() async {
        cache = await Self.cacheRefreshingSupportStatusFromStoreKit(startingWith: cache)
        saveCache()
        applyCache()
    }

    private func recordVerifiedSupport(productID: String, purchasedAt: Date) {
        guard let definition = Self.definition(for: productID) else { return }
        cache.recordVerifiedSupport(
            productID: productID,
            title: definition.title,
            kind: definition.kind,
            purchasedAt: purchasedAt
        )

        saveCache()
        applyCache()
    }

    private func applyCache() {
        hasVerifiedSupport = cache.hasSeenVerifiedSupport
        activeSubscriptionTitle = cache.activeSubscriptionTitle
    }

    private func rebuildOptions() {
        let options = SupportProductDefinition.all.compactMap { definition -> SupportProductOption? in
            guard let product = productsByID[definition.productID] else { return nil }
            return SupportProductOption(definition: definition, displayPrice: product.displayPrice)
        }
        oneTimeOptions = options.filter { $0.definition.kind == .oneTime }
        recurringOptions = options.filter { $0.definition.kind == .recurring }
    }

    private func saveCache() {
        Self.save(cache, to: userDefaults)
    }

    private static func loadCache(from userDefaults: UserDefaults) -> SupportLocalCache {
        guard let data = userDefaults.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(SupportLocalCache.self, from: data) else {
            return .empty
        }
        return cache
    }

    static func handleTransactionUpdate(
        _ verification: VerificationResult<Transaction>,
        userDefaults: UserDefaults = .standard
    ) async {
        guard let transaction = try? verifiedTransaction(from: verification),
              let definition = definition(for: transaction.productID) else {
            return
        }

        var updatedCache = loadCache(from: userDefaults)
        updatedCache.recordVerifiedSupport(
            productID: transaction.productID,
            title: definition.title,
            kind: definition.kind,
            purchasedAt: transaction.purchaseDate
        )
        updatedCache = await cacheRefreshingSupportStatusFromStoreKit(startingWith: updatedCache)
        save(updatedCache, to: userDefaults)

        await transaction.finish()
    }

    private static func cacheRefreshingSupportStatusFromStoreKit(
        startingWith cache: SupportLocalCache
    ) async -> SupportLocalCache {
        var updatedCache = cache
        var activeSubscriptionID: String?

        for await verification in Transaction.currentEntitlements {
            guard let transaction = try? verifiedTransaction(from: verification),
                  let definition = definition(for: transaction.productID) else {
                continue
            }

            updatedCache.recordVerifiedSupport(
                productID: transaction.productID,
                title: definition.title,
                kind: definition.kind,
                purchasedAt: transaction.purchaseDate
            )

            if definition.kind == .recurring,
               transaction.revocationDate == nil,
               transaction.expirationDate.map({ $0 > Date() }) ?? true {
                activeSubscriptionID = transaction.productID
            }
        }

        updatedCache.activeSubscriptionProductID = activeSubscriptionID
        updatedCache.activeSubscriptionTitle = activeSubscriptionID.flatMap { definition(for: $0)?.title }
        return updatedCache
    }

    private static func save(_ cache: SupportLocalCache, to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }

    private static func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            throw error
        }
    }

    private static func definition(for productID: String) -> SupportProductDefinition? {
        SupportProductDefinition.all.first { $0.productID == productID }
    }

    private static let cacheKey = "rollCall.support.localCache.v1"
}

private func builtInClipRelativePath(for source: BuiltInClipSource) -> String {
    "\(source.id).mp3"
}

struct AudioAssetService: Sendable {
    func assetURL(relativePath: String) throws -> URL {
        try AppPaths.assetURL(relativePath: relativePath)
    }

    func makeWritableAssetURL(fileExtension: String) throws -> URL {
        let normalizedExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = normalizedExtension.isEmpty ? "m4a" : normalizedExtension
        return try AppPaths.assetsDirectory().appendingPathComponent("\(UUID().uuidString).\(ext)")
    }

    func importMedia(from url: URL) async throws -> LocalAudioSource {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        let asset = AVURLAsset(url: url)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let hasVideoTrack = !videoTracks.isEmpty
        if hasVideoTrack {
            return try await extractAudio(fromVideoAt: url, displayName: url.deletingPathExtension().lastPathComponent)
        }

        return try storeCopiedAsset(
            from: url,
            suggestedExtension: url.pathExtension,
            displayName: url.deletingPathExtension().lastPathComponent,
            hiddenOriginNote: nil
        )
    }

    func importRemotePreview(from previewURL: URL, displayName: String, hiddenOrigin: HiddenOriginNote) async throws -> LocalAudioSource {
        let (tempURL, response) = try await URLSession.shared.download(from: previewURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AppError.invalidImport }
        let destination = try AppPaths.assetsDirectory().appendingPathComponent("\(UUID().uuidString).m4a")
        try FileManager.default.copyItem(at: tempURL, to: destination)
        let duration = try audioDuration(for: destination)
        return LocalAudioSource(id: UUID(), displayName: displayName, relativePath: destination.lastPathComponent, duration: duration.isFinite ? duration : nil, importedAt: .now, hiddenOriginNote: hiddenOrigin)
    }

    func storeSpeechData(_ data: Data, displayName: String) throws -> LocalAudioSource {
        let destination = try AppPaths.assetsDirectory().appendingPathComponent("\(UUID().uuidString).caf")
        guard !data.isEmpty else { throw AppError.invalidAnnouncerAudio }
        try data.write(to: destination, options: .atomic)
        guard FileManager.default.fileExists(atPath: destination.path),
              let size = try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0 else {
            throw AppError.invalidAnnouncerAudio
        }
        return try localAudioSource(for: destination, displayName: displayName, hiddenOriginNote: nil)
    }

    func removeAsset(relativePath: String?) {
        guard let relativePath else { return }
        guard let url = try? assetURL(relativePath: relativePath) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func storeCustomAnnouncerRecording(from sourceURL: URL, playerID: UUID, displayName: String, relativePath preferredRelativePath: String? = nil) throws -> LocalAudioSource {
        let relativePath = preferredRelativePath ?? "custom-intro-\(playerID.uuidString.lowercased()).caf"
        let destination = try AppPaths.assetsDirectory().appendingPathComponent(relativePath)
        let recordedData = try Data(contentsOf: sourceURL)
        guard !recordedData.isEmpty else {
            throw AppError.customIntroSaveFailed("recorded temp file was empty before app-storage write")
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try recordedData.write(to: destination, options: .atomic)
        guard FileManager.default.fileExists(atPath: destination.path),
              ((try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 0 else {
            throw AppError.customIntroSaveFailed("flat saved asset was not visible at \(relativePath)")
        }
        return try localAudioSource(for: destination, displayName: displayName, hiddenOriginNote: nil, relativePath: relativePath)
    }

    func freshCustomAnnouncerRelativePath() -> String {
        "\(UUID().uuidString).caf"
    }

    func storeCopiedAsset(from sourceURL: URL, suggestedExtension: String?, displayName: String, hiddenOriginNote: HiddenOriginNote?) throws -> LocalAudioSource {
        let ext = suggestedExtension?.isEmpty == false ? suggestedExtension! : sourceURL.pathExtension
        let destination = try makeWritableAssetURL(fileExtension: ext)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return try localAudioSource(for: destination, displayName: displayName, hiddenOriginNote: hiddenOriginNote)
    }

    func ensureBuiltInAssets() throws {
        for builtIn in BuiltInClip.defaults {
            guard case .builtInClip(let source) = builtIn.cue.source else { continue }
            let relativePath = builtInClipRelativePath(for: source)
            let url = try assetURL(relativePath: relativePath)
            guard !FileManager.default.fileExists(atPath: url.path) else { continue }
            guard let bundledURL = Bundle.main.url(forResource: source.id, withExtension: "mp3", subdirectory: "BuiltInAudio") else {
                throw AppError.missingBuiltInClip
            }
            try FileManager.default.copyItem(at: bundledURL, to: url)
        }
    }

    func assetExists(relativePath: String) -> Bool {
        guard let url = try? assetURL(relativePath: relativePath) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func builtInClipExists(source: BuiltInClipSource) -> Bool {
        assetExists(relativePath: builtInClipRelativePath(for: source))
    }

    private func localAudioSource(for url: URL, displayName: String, hiddenOriginNote: HiddenOriginNote?, relativePath: String? = nil) throws -> LocalAudioSource {
        let duration = try audioDuration(for: url)
        return LocalAudioSource(
            id: UUID(),
            displayName: displayName,
            relativePath: relativePath ?? url.lastPathComponent,
            duration: duration.isFinite ? duration : nil,
            importedAt: .now,
            hiddenOriginNote: hiddenOriginNote
        )
    }

    private func ensureDirectoryExists(at url: URL) throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return
            }
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func extractAudio(fromVideoAt url: URL, displayName: String) async throws -> LocalAudioSource {
        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AppError.noAudioTrack
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AppError.invalidImport
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        exportSession.shouldOptimizeForNetworkUse = false

        try await exportSession.export(to: tempURL, as: .m4a)

        return try storeCopiedAsset(
            from: tempURL,
            suggestedExtension: "m4a",
            displayName: displayName,
            hiddenOriginNote: nil
        )
    }

    private func audioDuration(for url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard format.sampleRate > 0 else { return 0 }
        return Double(file.length) / format.sampleRate
    }
}

struct MusicSearchResult: Identifiable, Hashable {
    var id: String { songID }
    var songID: String
    var title: String
    var artistName: String
    var duration: TimeInterval?
    var previewURL: URL?
    var artworkURL: URL? = nil
    var isCatalogBacked: Bool = true
    var libraryPersistentID: UInt64? = nil
    var isExplicit: Bool? = nil
}

struct ResolvedTeamPlaylistSongs {
    var songs: [Song]
    var resolvedSongIDs: [String]
    var unresolvedSongIDs: [String]
}

enum AppleMusicPlaybackCapability: Equatable {
    case unknown
    case previewOnly
    case fullSong
}

enum AppleMusicSearchMode: Equatable {
    case catalogOnly
    case previewFallback
}

struct MusicCatalogService: Sendable {
    func search(term: String, mode: AppleMusicSearchMode) async throws -> [MusicSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.invalidSearchTerm }

        if mode == .catalogOnly {
            do {
                return try await catalogSearch(term: trimmed)
            } catch let error as AppError {
                throw error
            } catch {
                if Self.isCancellation(error) {
                    throw error
                }
                throw AppError.appleMusicFullSongCatalogUnavailable
            }
        }

        do {
            let musicKitResults = try await catalogSearch(term: trimmed)
            if !musicKitResults.isEmpty {
                return musicKitResults
            }
        } catch {
            if Self.isCancellation(error) {
                throw error
            }
            // Fall back to preview-only search when catalog access fails, including
            // local development builds that cannot fetch a MusicKit developer token.
        }

        let previewResults = try await searchWithITunesPreview(term: trimmed)
        return previewResults
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        let nsError = error as NSError
        return (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
            || (nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError)
    }

    func catalogBackedResult(for result: MusicSearchResult) async throws -> MusicSearchResult {
        let song = try await song(for: result.songID)
        var resolvedDuration = song.duration ?? result.duration
        if resolvedDuration == nil {
            resolvedDuration = try? await durationFromITunesLookup(songID: song.id.rawValue)
        }
        return MusicSearchResult(
            songID: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            duration: resolvedDuration,
            previewURL: song.previewAssets?.first?.url ?? result.previewURL,
            artworkURL: song.artwork?.url(width: 120, height: 120) ?? result.artworkURL,
            isCatalogBacked: true,
            isExplicit: song.contentRating == .explicit
        )
    }

    func playbackCapability() async -> AppleMusicPlaybackCapability {
        do {
            let status = currentAuthorizationStatus()
            guard status == .authorized else { return .previewOnly }
            let subscription = try await MusicSubscription.current
            return subscription.canPlayCatalogContent ? .fullSong : .previewOnly
        } catch {
            return .previewOnly
        }
    }

    func song(for songID: String) async throws -> Song {
        let status = try await authorizedStatus()
        guard status == .authorized else { throw AppError.musicAuthorizationRequired }

        let subscription = try await MusicSubscription.current
        guard subscription.canPlayCatalogContent else { throw AppError.musicSubscriptionRequired }

        var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(songID))
        request.limit = 1
        let response = try await request.response()
        guard let song = response.items.first else { throw AppError.appleMusicSongUnavailable }
        return song
    }

    func syncTeamPlaylist(name: String, songIDs: [String]) async throws {
        let status = try await authorizedStatus()
        guard status == .authorized else { throw AppError.musicAuthorizationRequired }

        let resolved = try await catalogSongs(for: songIDs)
        guard !resolved.songs.isEmpty else { throw AppError.noAppleMusicTeamCues }
        try await replaceTeamPlaylist(name: name, songs: resolved.songs)
    }

    func resolveTeamPlaylistSongs(songIDs: [String]) async throws -> ResolvedTeamPlaylistSongs {
        let status = try await authorizedStatus()
        guard status == .authorized else { throw AppError.musicAuthorizationRequired }

        return try await catalogSongs(for: songIDs)
    }

    func replaceTeamPlaylist(name: String, songs: [Song]) async throws {
        guard !songs.isEmpty else { throw AppError.noAppleMusicTeamCues }
        let playlist = try await existingLibraryPlaylist(named: name)
        do {
            if let playlist {
                try await MusicLibrary.shared.edit(
                    playlist,
                    name: name,
                    description: teamPlaylistDescription,
                    authorDisplayName: "Roll Call",
                    items: songs
                )
            } else {
                try await MusicLibrary.shared.createPlaylist(
                    name: name,
                    description: teamPlaylistDescription,
                    authorDisplayName: "Roll Call",
                    items: songs
                )
            }
        } catch {
            throw AppError.appleMusicPlaylistSyncFailed(error.localizedDescription)
        }
    }

    private func catalogSearch(term: String) async throws -> [MusicSearchResult] {
        let status = try await authorizedStatus()
        guard status == .authorized else { throw AppError.musicAuthorizationRequired }
        return try await searchWithMusicKit(term: term)
    }

    private var teamPlaylistDescription: String {
        "Generated by Roll Call from the selected team's Apple Music song cues."
    }

    private func existingLibraryPlaylist(named name: String) async throws -> Playlist? {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = 25
        request.filter(matching: \.name, equalTo: name)
        let response = try await request.response()
        return response.items.first
    }

    private func catalogSongs(for songIDs: [String]) async throws -> ResolvedTeamPlaylistSongs {
        var songs: [Song] = []
        var resolvedSongIDs: [String] = []
        var unresolvedSongIDs: [String] = []
        for songID in songIDs {
            var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(songID))
            request.limit = 1
            let response = try await request.response()
            if let song = response.items.first {
                songs.append(song)
                resolvedSongIDs.append(songID)
            } else {
                unresolvedSongIDs.append(songID)
            }
        }
        return ResolvedTeamPlaylistSongs(
            songs: songs,
            resolvedSongIDs: resolvedSongIDs,
            unresolvedSongIDs: unresolvedSongIDs
        )
    }

    private func searchWithMusicKit(term: String) async throws -> [MusicSearchResult] {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = 20
        let response = try await request.response()
        return response.songs.map {
            MusicSearchResult(
                songID: $0.id.rawValue,
                title: $0.title,
                artistName: $0.artistName,
                duration: $0.duration,
                previewURL: $0.previewAssets?.first?.url,
                artworkURL: $0.artwork?.url(width: 120, height: 120),
                isCatalogBacked: true,
                isExplicit: $0.contentRating == .explicit
            )
        }
    }

    private func searchWithITunesPreview(term: String) async throws -> [MusicSearchResult] {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "media", value: "music")
        ]
        guard let url = components?.url else { throw AppError.musicSearchUnavailable }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AppError.musicSearchUnavailable
        }

        let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        return decoded.results.compactMap { item in
            guard let previewURL = item.previewURL else { return nil }
            return MusicSearchResult(
                songID: String(item.trackID),
                title: item.trackName,
                artistName: item.artistName,
                duration: item.trackTimeMillis.map { TimeInterval($0) / 1000 },
                previewURL: previewURL,
                artworkURL: item.artworkURL,
                isCatalogBacked: false,
                isExplicit: item.isExplicit
            )
        }
    }

    private func durationFromITunesLookup(songID: String) async throws -> TimeInterval? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [URLQueryItem(name: "id", value: songID)]
        guard let url = components?.url else { return nil }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        return decoded.results.first?.trackTimeMillis.map { TimeInterval($0) / 1000 }
    }

    private func authorizedStatus() async throws -> MusicAuthorization.Status {
        switch MusicAuthorization.currentStatus {
        case .notDetermined:
            return await MusicAuthorization.request()
        default:
            return MusicAuthorization.currentStatus
        }
    }

    private func currentAuthorizationStatus() -> MusicAuthorization.Status {
        MusicAuthorization.currentStatus
    }
}

private struct ITunesSearchResponse: Decodable {
    let results: [ITunesTrack]
}

private struct ITunesTrack: Decodable {
    let trackID: Int
    let trackName: String
    let artistName: String
    let previewURL: URL?
    let trackTimeMillis: Int?
    let artworkURL: URL?
    let trackExplicitness: String?

    enum CodingKeys: String, CodingKey {
        case trackID = "trackId"
        case trackName
        case artistName
        case previewURL = "previewUrl"
        case trackTimeMillis
        case artworkURL = "artworkUrl100"
        case trackExplicitness
    }

    var isExplicit: Bool? {
        guard let trackExplicitness else { return nil }
        return trackExplicitness == "explicit"
    }
}

struct ParsedRosterRow: Equatable {
    let name: String
    let number: String
}

struct PlaybackSupportDiagnostics: Codable, Equatable {
    var activeCueID: UUID?
    var prewarmedCueID: UUID?
    var lastStartedCueID: UUID?
    var debounceWindowSeconds: Double
}

private struct SupportBundlePayload: Codable {
    struct TeamSummary: Codable {
        var name: String
        var playerCount: Int
        var presentPlayerCount: Int
        var builtInClipCount: Int
    }

    struct SongClipDiagnostics: Codable {
        var totalClipCount: Int
        var sourceTypeCounts: [String: Int]
        var generationStatusCounts: [String: Int]
        var readinessCounts: [String: Int]
        var portabilityCounts: [String: Int]
        var totalRetryCount: Int
        var failureCodeCounts: [String: Int]
        var generatedAssetDiskUsageBytes: Int64
        var localGenerationEnabled: Bool
        var appleMusicHandlingPolicy: String
        var autoDownloadEligibleSongsEnabled: Bool
        var generationPolicyVersions: [Int]
    }

    struct PlaybackSummary: Codable {
        var hasActiveCue: Bool
        var hasPrewarmedCue: Bool
        var hasLastStartedCue: Bool
        var debounceWindowSeconds: Double
    }

    var generatedAt: Date
    var appVersion: String
    var schemaVersion: Int
    var selectedTeamIndex: Int?
    var settings: AppSettings
    var experimental: ExperimentalSettings
    var readinessStateCounts: [String: Int]
    var playback: PlaybackSummary
    var teams: [TeamSummary]
    var songClips: SongClipDiagnostics
    var generatedClipCleanup: GeneratedClipCleanupReport?
}

@MainActor
private protocol AppleMusicCatalogPlaybackControlling: AnyObject {
    func preconnect()
    func play(
        songID: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        volumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool,
        fadeOutDuration: TimeInterval
    ) async throws
    func play(
        mediaItem: MPMediaItem,
        startTime: TimeInterval,
        duration: TimeInterval,
        volumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool,
        fadeOutDuration: TimeInterval
    ) async throws
    func setVolume(_ volume: Float)
    func restoreVolume()
    func discardPendingRestore()
    func stop(restoresVolume: Bool)
}

@MainActor
private final class MediaPlayerCatalogPlaybackController: AppleMusicCatalogPlaybackControlling {
    private let player: MPMusicPlayerApplicationController
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "RollCall",
        category: "AppleMusicVolumeAutomation"
    )

    private var capturedSystemVolumeBaseline: Float = 1
    private var volumeAutomationEnabledForCurrentCue = true
    private var hasPendingVolumeRestore = false

    init(player: MPMusicPlayerApplicationController = MPMusicPlayerController.applicationQueuePlayer) {
        self.player = player
    }

    func preconnect() {
        _ = player
    }

    func play(
        songID: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        volumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool,
        fadeOutDuration: TimeInterval
    ) async throws {
        volumeAutomationEnabledForCurrentCue = volumeAutomationEnabled
        if volumeAutomationEnabled {
            // Volume Automation must not touch Apple Music volume before playback starts.
            // Capture the pre-cue baseline here, only apply volume changes once fade-out
            // begins, then restore this exact baseline after playback has fully stopped.
            captureSystemVolumeBaseline()
            hasPendingVolumeRestore = true
        } else {
            hasPendingVolumeRestore = false
        }
        player.stop()

        let descriptor = MPMusicPlayerStoreQueueDescriptor(storeIDs: [songID])
        descriptor.startItemID = songID
        descriptor.setStartTime(startTime, forItemWithStoreID: songID)
        descriptor.setEndTime(startTime + duration, forItemWithStoreID: songID)
        player.setQueue(with: descriptor)

        // MediaPlayer queue start times can still be sticky on reused selections, so
        // force the playhead to the cue's current trim point before and after playback.
        if startTime > 0 {
            player.currentPlaybackTime = startTime
        }

        player.play()
        try await waitForPlaybackStart()

        if startTime > 0 {
            await Task.yield()
            player.currentPlaybackTime = startTime
        }
    }

    func play(
        mediaItem: MPMediaItem,
        startTime: TimeInterval,
        duration: TimeInterval,
        volumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool,
        fadeOutDuration: TimeInterval
    ) async throws {
        volumeAutomationEnabledForCurrentCue = volumeAutomationEnabled
        if volumeAutomationEnabled {
            captureSystemVolumeBaseline()
            hasPendingVolumeRestore = true
        } else {
            hasPendingVolumeRestore = false
        }
        player.stop()

        player.setQueue(with: MPMediaItemCollection(items: [mediaItem]))
        if startTime > 0 {
            player.currentPlaybackTime = startTime
        }

        player.play()
        try await waitForPlaybackStart()

        if startTime > 0 {
            await Task.yield()
            player.currentPlaybackTime = startTime
        }
    }

    func setVolume(_ volume: Float) {
        let clamped = min(max(0, volume), 1)
        setPlayerVolume(capturedSystemVolumeBaseline * clamped)
    }

    func restoreVolume() {
        guard hasPendingVolumeRestore else { return }
        setPlayerVolume(capturedSystemVolumeBaseline)
        Self.logger.debug(
            "Restored Apple Music player volume to captured baseline \(self.formattedVolume(self.capturedSystemVolumeBaseline), privacy: .public) after playback stopped"
        )
        hasPendingVolumeRestore = false
    }

    func discardPendingRestore() {
        guard hasPendingVolumeRestore else { return }
        hasPendingVolumeRestore = false
        Self.logger.debug(
            "Discarded pending Apple Music restore during cue handoff; next cue will recapture system volume baseline from \(self.formattedVolume(self.capturedSystemVolumeBaseline), privacy: .public)"
        )
    }

    func stop(restoresVolume: Bool = true) {
        player.stop()
        if restoresVolume {
            restoreVolume()
        }
        volumeAutomationEnabledForCurrentCue = false
    }

    private func waitForPlaybackStart() async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while clock.now < deadline {
            if player.playbackState == .playing { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw PlaybackStartFailure(reason: .startTimedOut)
    }

    private func captureSystemVolumeBaseline() {
        capturedSystemVolumeBaseline = AVAudioSession.sharedInstance().outputVolume
        Self.logger.debug(
            "Captured system volume baseline \(self.formattedVolume(self.capturedSystemVolumeBaseline), privacy: .public) before Apple Music automation"
        )
    }

    private func formattedVolume(_ volume: Float) -> String {
        String(format: "%.3f", volume)
    }

    private func setPlayerVolume(_ volume: Float) {
        // `MPMusicPlayerController.volume` is marked unavailable on modern iOS SDKs,
        // but the application queue player still exposes the underlying Objective-C
        // setter. Keep this isolated as a provisional on-device experiment.
        player.setValue(volume, forKey: "volume")
    }

}

struct PlaybackFadeSchedule: Equatable {
    var sustainDuration: TimeInterval
    var fadeDuration: TimeInterval
    var postFadeStopDelay: TimeInterval
    var stopDelay: TimeInterval

    static func sourceBacked(
        selectedDuration: TimeInterval,
        tailGuard: TimeInterval,
        fadeOut: TimeInterval,
        volumeAutomationEnabled: Bool
    ) -> PlaybackFadeSchedule {
        let boundedDuration = selectedDuration.isFinite ? max(0, selectedDuration) : 0
        let boundedTailGuard = tailGuard.isFinite ? max(0, tailGuard) : 0
        let stopDelay = boundedDuration + boundedTailGuard
        guard volumeAutomationEnabled else {
            return PlaybackFadeSchedule(
                sustainDuration: stopDelay,
                fadeDuration: 0,
                postFadeStopDelay: 0,
                stopDelay: stopDelay
            )
        }
        let boundedFade = fadeOut.isFinite ? max(0, fadeOut) : 0
        let fadeDuration = min(boundedDuration, boundedFade)
        return PlaybackFadeSchedule(
            sustainDuration: max(0, boundedDuration - fadeDuration),
            fadeDuration: fadeDuration,
            postFadeStopDelay: boundedTailGuard,
            stopDelay: stopDelay
        )
    }
}

private struct PlaybackStartFailure: Error {
    let reason: PlaybackFailureReason
}

@MainActor
final class CuePlaybackEngine: NSObject, ObservableObject {
    @Published private(set) var activeCueID: UUID?
    @Published private(set) var activeCueProgress: Double?

    private let audioAssetService: AudioAssetService
    private let musicCatalogService: MusicCatalogService
    private var catalogPlaybackController: any AppleMusicCatalogPlaybackControlling
    private let debounceWindow: TimeInterval = 0.45
    private let appleMusicClipDurationLimit: TimeInterval = 20
    private let primaryCueTailGuard: TimeInterval = 0.75
    private let announcerCompletionGrace: TimeInterval = 1.25
    private let announcerCompletionPollInterval: TimeInterval = 0.05
    private var audioPlayer: AVAudioPlayer?
    private var announcerPlayer: AVAudioPlayer?
    private var remotePlayer: AVPlayer?
    private var stopTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var prewarmedCueID: UUID?
    private var prewarmedLocalPlayer: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private var playbackSessionID = UUID()
    private var lastStartDate: Date?
    private var lastStartedCueID: UUID?
    private var sourceBackedVolumeAutomationEnabledForCurrentCue = false
    var onAsynchronousPlaybackResult: ((PlaybackStartConfirmation) -> Void)?

    init(
        audioAssetService: AudioAssetService,
        musicCatalogService: MusicCatalogService
    ) {
        self.audioAssetService = audioAssetService
        self.musicCatalogService = musicCatalogService
        self.catalogPlaybackController = MediaPlayerCatalogPlaybackController()
    }

    @discardableResult
    func play(
        cue: Cue,
        announcerRelativePath: String? = nil,
        fadeOutVolumeAutomationEnabled: Bool = true,
        sourceFamilyOverride: PlaybackSourceFamily? = nil
    ) async throws -> PlaybackRequestResult {
        if activeCueID == cue.id {
            stop()
            let requestID = UUID()
            return PlaybackRequestResult(requestID: requestID, confirmations: [PlaybackStartConfirmation(requestID: requestID, component: .primaryCue, sourceFamily: .unknown, outcome: .cancelled)], wasDebounced: false)
        }
        if let lastStartDate,
           let lastStartedCueID,
           lastStartedCueID == cue.id,
           Date().timeIntervalSince(lastStartDate) < debounceWindow {
            let requestID = UUID()
            return PlaybackRequestResult(requestID: requestID, confirmations: [], wasDebounced: true)
        }
        let sessionID = beginPlayback(
            activeCueID: cue.id,
            sourceBackedVolumeAutomationEnabled: cue.source.runtimeVolumeAutomationEnabled(
                whenSettingEnabled: fadeOutVolumeAutomationEnabled
            )
        )
        lastStartDate = Date()
        lastStartedCueID = cue.id
        do {
            let confirmations = try await playCueSequence(
                cue,
                announcerRelativePath: announcerRelativePath,
                fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                sessionID: sessionID,
                sourceFamilyOverride: sourceFamilyOverride
            )
            return PlaybackRequestResult(requestID: sessionID, confirmations: confirmations, wasDebounced: false)
        } catch {
            stopIfCurrent(sessionID: sessionID)
            throw error
        }
    }

    @discardableResult
    func playAsset(
        relativePath: String,
        activeCueID: UUID,
        fadeOutVolumeAutomationEnabled: Bool = true
    ) async throws -> PlaybackRequestResult {
        if self.activeCueID == activeCueID {
            stop()
            return PlaybackRequestResult(requestID: UUID(), confirmations: [], wasDebounced: false)
        }
        if let lastStartDate,
           let lastStartedCueID,
           lastStartedCueID == activeCueID,
           Date().timeIntervalSince(lastStartDate) < debounceWindow {
            return PlaybackRequestResult(requestID: UUID(), confirmations: [], wasDebounced: true)
        }
        let sessionID = beginPlayback(
            activeCueID: activeCueID,
            sourceBackedVolumeAutomationEnabled: false
        )
        lastStartDate = Date()
        lastStartedCueID = activeCueID

        do {
            let url = try audioAssetService.assetURL(relativePath: relativePath)
            let player = try AVAudioPlayer(contentsOf: url)
            announcerPlayer = player
            player.prepareToPlay()
            guard player.play() else {
                announcerPlayer = nil
                stopIfCurrent(sessionID: sessionID)
                throw PlaybackStartFailure(reason: .startRejected)
            }

            stopTask = Task { [weak self] in
                await self?.waitForAnnouncerPlaybackToFinish(player)
                guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                self.stop()
            }
        } catch {
            stopIfCurrent(sessionID: sessionID)
            throw error
        }
        let confirmation = PlaybackStartConfirmation(requestID: sessionID, component: .announcement, sourceFamily: .recordedAnnouncement, outcome: .started)
        return PlaybackRequestResult(requestID: sessionID, confirmations: [confirmation], wasDebounced: false)
    }

    func prewarm(cue: Cue) async throws {
        switch cue.source {
        case .appleMusic:
            prewarmedCueID = cue.id
            prewarmedLocalPlayer = nil
            catalogPlaybackController.preconnect()
        case .localAudio(let source):
            let url = try audioAssetService.assetURL(relativePath: source.relativePath)
            let player = try AVAudioPlayer(contentsOf: url)
            player.currentTime = cue.startTime
            player.prepareToPlay()
            prewarmedCueID = cue.id
            prewarmedLocalPlayer = player
        case .builtInClip(let source):
            let url = try audioAssetService.assetURL(relativePath: builtInClipRelativePath(for: source))
            let player = try AVAudioPlayer(contentsOf: url)
            player.currentTime = cue.startTime
            player.prepareToPlay()
            prewarmedCueID = cue.id
            prewarmedLocalPlayer = player
        }
    }

    func preconnectForUpcomingPlayback() {
        catalogPlaybackController.preconnect()
    }

    func supportDiagnostics() -> PlaybackSupportDiagnostics {
        PlaybackSupportDiagnostics(
            activeCueID: activeCueID,
            prewarmedCueID: prewarmedCueID,
            lastStartedCueID: lastStartedCueID,
            debounceWindowSeconds: debounceWindow
        )
    }

    func previewAudio(data: Data) throws {
        stop()
        let sessionID = beginPreview()
        let player = try AVAudioPlayer(data: data)
        previewPlayer = player
        player.prepareToPlay()
        player.play()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(player.duration))
            guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
            self.previewPlayer?.stop()
            self.previewPlayer = nil
            self.stopTask = nil
        }
    }

    func previewAsset(relativePath: String) throws {
        stop()
        let sessionID = beginPreview()
        let url = try audioAssetService.assetURL(relativePath: relativePath)
        let player = try AVAudioPlayer(contentsOf: url)
        previewPlayer = player
        player.prepareToPlay()
        player.play()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(player.duration))
            guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
            self.previewPlayer?.stop()
            self.previewPlayer = nil
            self.stopTask = nil
        }
    }

    func stop() {
        stop(restoresCatalogVolume: true)
    }

    private func stop(restoresCatalogVolume: Bool) {
        playbackSessionID = UUID()
        stopTask?.cancel()
        stopTask = nil
        progressTask?.cancel()
        progressTask = nil
        announcerPlayer?.stop()
        announcerPlayer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        remotePlayer?.pause()
        if sourceBackedVolumeAutomationEnabledForCurrentCue {
            remotePlayer?.volume = 1
        }
        remotePlayer = nil
        catalogPlaybackController.stop(restoresVolume: restoresCatalogVolume)
        previewPlayer?.stop()
        previewPlayer = nil
        activeCueID = nil
        activeCueProgress = nil
        sourceBackedVolumeAutomationEnabledForCurrentCue = false
    }

    private func beginPlayback(activeCueID: UUID, sourceBackedVolumeAutomationEnabled: Bool) -> UUID {
        // When replacing one cue with another, keep the outgoing cue from briefly
        // restoring its old Apple Music volume before the new cue captures its own anchor.
        stop(restoresCatalogVolume: false)
        catalogPlaybackController.discardPendingRestore()
        let sessionID = UUID()
        playbackSessionID = sessionID
        self.activeCueID = activeCueID
        sourceBackedVolumeAutomationEnabledForCurrentCue = sourceBackedVolumeAutomationEnabled
        return sessionID
    }

    private func beginPreview() -> UUID {
        let sessionID = UUID()
        playbackSessionID = sessionID
        return sessionID
    }

    private func stopIfCurrent(sessionID: UUID) {
        guard playbackSessionID == sessionID else { return }
        stop()
    }

    private func playCueSequence(
        _ cue: Cue,
        announcerRelativePath: String?,
        fadeOutVolumeAutomationEnabled: Bool,
        sessionID: UUID,
        sourceFamilyOverride: PlaybackSourceFamily?
    ) async throws -> [PlaybackStartConfirmation] {
        if let relativePath = announcerRelativePath {
            try? await prewarm(cue: cue)
            guard playbackSessionID == sessionID else {
                return [PlaybackStartConfirmation(requestID: sessionID, component: .primaryCue, sourceFamily: .unknown, outcome: .cancelled)]
            }

            let announcerURL = try audioAssetService.assetURL(relativePath: relativePath)
            guard FileManager.default.fileExists(atPath: announcerURL.path) else {
                let primary = try await startPrimaryCue(
                    cue,
                    fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                    sessionID: sessionID,
                    sourceFamilyOverride: sourceFamilyOverride
                )
                return [
                    PlaybackStartConfirmation(requestID: sessionID, component: .announcement, sourceFamily: .recordedAnnouncement, outcome: .failed(.missingAsset)),
                    primary
                ]
            }

            let player: AVAudioPlayer
            do {
                player = try AVAudioPlayer(contentsOf: announcerURL)
            } catch {
                let primary = try await startPrimaryCue(
                    cue,
                    fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                    sessionID: sessionID,
                    sourceFamilyOverride: sourceFamilyOverride
                )
                return [
                    PlaybackStartConfirmation(requestID: sessionID, component: .announcement, sourceFamily: .recordedAnnouncement, outcome: .failed(.unreadableAsset)),
                    primary
                ]
            }
            announcerPlayer = player
            player.prepareToPlay()
            guard player.play() else {
                announcerPlayer = nil
                let primary = try await startPrimaryCue(
                    cue,
                    fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                    sessionID: sessionID,
                    sourceFamilyOverride: sourceFamilyOverride
                )
                return [
                    PlaybackStartConfirmation(requestID: sessionID, component: .announcement, sourceFamily: .recordedAnnouncement, outcome: .failed(.startRejected)),
                    primary
                ]
            }

            guard player.duration.isFinite, player.duration >= 0 else {
                let primary = try await startPrimaryCue(
                    cue,
                    fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                    sessionID: sessionID,
                    sourceFamilyOverride: sourceFamilyOverride
                )
                return [
                    PlaybackStartConfirmation(requestID: sessionID, component: .announcement, sourceFamily: .recordedAnnouncement, outcome: .failed(.unreadableAsset)),
                    primary
                ]
            }

            let announcement = PlaybackStartConfirmation(requestID: sessionID, component: .announcement, sourceFamily: .recordedAnnouncement, outcome: .started)
            stopTask = Task { [weak self] in
                await self?.waitForAnnouncerPlaybackToFinish(player)
                guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                let pauseAfterAnnouncer = max(0, cue.pauseAfterAnnouncer)
                if pauseAfterAnnouncer > 0 {
                    try? await Task.sleep(for: .seconds(pauseAfterAnnouncer))
                    guard !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                }
                do {
                    let result = try await self.startPrimaryCue(
                        cue,
                        cancelPendingStopTask: false,
                        fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                        setsInitialVolumeToMax: false,
                        sessionID: sessionID,
                        sourceFamilyOverride: sourceFamilyOverride
                    )
                    self.onAsynchronousPlaybackResult?(result)
                } catch {
                    self.onAsynchronousPlaybackResult?(
                        PlaybackStartConfirmation(
                            requestID: sessionID,
                            component: .primaryCue,
                            sourceFamily: sourceFamilyOverride ?? self.sourceFamily(for: cue),
                            outcome: .failed(self.playbackFailureReason(for: error))
                        )
                    )
                    self.stopIfCurrent(sessionID: sessionID)
                }
            }
            return [announcement]
        }

        let primary = try await startPrimaryCue(
            cue,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
            sessionID: sessionID,
            sourceFamilyOverride: sourceFamilyOverride
        )
        return [primary]
    }

    private func startPrimaryCue(
        _ cue: Cue,
        cancelPendingStopTask: Bool = true,
        fadeOutVolumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool = true,
        sessionID: UUID,
        sourceFamilyOverride: PlaybackSourceFamily? = nil
    ) async throws -> PlaybackStartConfirmation {
        guard playbackSessionID == sessionID else {
            return PlaybackStartConfirmation(requestID: sessionID, component: .primaryCue, sourceFamily: sourceFamily(for: cue), outcome: .cancelled)
        }
        if cancelPendingStopTask {
            stopTask?.cancel()
            stopTask = nil
        } else {
            stopTask = nil
        }
        announcerPlayer?.stop()
        announcerPlayer = nil

        let duration = cue.source.maximumPlaybackDuration.map { min(cue.duration, $0) } ?? cue.duration

        switch cue.source {
        case .appleMusic(let source):
            let clipDuration = min(duration, appleMusicClipDurationLimit)
            if let libraryItem = musicLibraryItem(for: source) {
                try await playLibraryItem(
                    libraryItem,
                    startTime: cue.startTime,
                    duration: clipDuration,
                    fadeOut: cue.fadeOutDuration,
                    fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                    setsInitialVolumeToMax: setsInitialVolumeToMax,
                    sessionID: sessionID
                    )
                    guard playbackSessionID == sessionID else {
                        return PlaybackStartConfirmation(requestID: sessionID, component: .primaryCue, sourceFamily: sourceFamily(for: cue), outcome: .cancelled)
                    }
                    return PlaybackStartConfirmation(requestID: sessionID, component: .primaryCue, sourceFamily: .musicLibrary, outcome: .started)
            }

            if source.isCatalogBacked != false, await musicCatalogService.playbackCapability() == .fullSong {
                guard playbackSessionID == sessionID else {
                    return PlaybackStartConfirmation(requestID: sessionID, component: .primaryCue, sourceFamily: .appleMusicCatalog, outcome: .cancelled)
                }
                do {
                    try await playCatalogSong(
                        source: source,
                        startTime: cue.startTime,
                        duration: clipDuration,
                        fadeOut: cue.fadeOutDuration,
                        fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                        setsInitialVolumeToMax: setsInitialVolumeToMax,
                        sessionID: sessionID
                    )
                    guard playbackSessionID == sessionID else {
                        return PlaybackStartConfirmation(requestID: sessionID, component: .primaryCue, sourceFamily: sourceFamily(for: cue), outcome: .cancelled)
                    }
                    return PlaybackStartConfirmation(requestID: sessionID, component: .primaryCue, sourceFamily: .appleMusicCatalog, outcome: .started)
                } catch {
                    throw AppError.appleMusicFullSongCatalogUnavailable
                }
            }

            guard let previewURL = source.previewURL else { throw AppError.missingPreview }
            let player = AVPlayer(url: previewURL)
            remotePlayer = player
            let maxPreviewStart = max(0, appleMusicClipDurationLimit - clipDuration)
            let previewStart = min(max(0, cue.startTime), maxPreviewStart)
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                player.seek(to: CMTime(seconds: previewStart, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] _ in
                    Task { @MainActor [weak self, weak player] in
                        guard let self, self.playbackSessionID == sessionID else {
                            continuation.resume()
                            return
                        }
                        if fadeOutVolumeAutomationEnabled, setsInitialVolumeToMax {
                            player?.volume = 1
                        }
                        player?.play()
                        continuation.resume()
                    }
                }
            }
            try await waitForRemotePlaybackStart(player, sessionID: sessionID)
            startProgressTracking(duration: clipDuration, sessionID: sessionID)
            scheduleRemoteStop(
                duration: clipDuration,
                fadeOut: cue.fadeOutDuration,
                fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                sessionID: sessionID
            )
            return PlaybackStartConfirmation(requestID: sessionID, component: .primaryCue, sourceFamily: .appleMusicPreview, outcome: .started)
        case .localAudio(let source):
            let url = try audioAssetService.assetURL(relativePath: source.relativePath)
            try playLocal(
                url: url,
                start: cue.startTime,
                duration: duration,
                reusePrewarm: prewarmedCueID == cue.id,
                sessionID: sessionID
            )
            return PlaybackStartConfirmation(requestID: sessionID, component: .primaryCue, sourceFamily: sourceFamilyOverride ?? .importedLocal, outcome: .started)
        case .builtInClip(let source):
            let url = try audioAssetService.assetURL(relativePath: builtInClipRelativePath(for: source))
            try playLocal(
                url: url,
                start: cue.startTime,
                duration: duration,
                reusePrewarm: prewarmedCueID == cue.id,
                sessionID: sessionID
            )
            return PlaybackStartConfirmation(requestID: sessionID, component: .primaryCue, sourceFamily: sourceFamilyOverride ?? .builtinIntentional, outcome: .started)
        }
    }

    private func musicLibraryItem(for source: AppleMusicSource) -> MPMediaItem? {
        guard let persistentID = source.libraryPersistentID else { return nil }
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(
            MPMediaPropertyPredicate(
                value: NSNumber(value: persistentID),
                forProperty: MPMediaItemPropertyPersistentID
            )
        )
        return query.items?.first
    }

    private func playLibraryItem(
        _ item: MPMediaItem,
        startTime: TimeInterval,
        duration: TimeInterval,
        fadeOut: TimeInterval,
        fadeOutVolumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool,
        sessionID: UUID
    ) async throws {
        try await catalogPlaybackController.play(
            mediaItem: item,
            startTime: startTime,
            duration: duration,
            volumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
            setsInitialVolumeToMax: setsInitialVolumeToMax,
            fadeOutDuration: fadeOut
        )
        guard playbackSessionID == sessionID else { return }
        startProgressTracking(duration: duration, sessionID: sessionID)
        scheduleCatalogStop(
            duration: duration,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
            sessionID: sessionID
        )
    }

    private func playCatalogSong(
        source: AppleMusicSource,
        startTime: TimeInterval,
        duration: TimeInterval,
        fadeOut: TimeInterval,
        fadeOutVolumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool,
        sessionID: UUID
    ) async throws {
        try await catalogPlaybackController.play(
            songID: source.songID,
            startTime: startTime,
            duration: catalogPlaybackDurationIncludingTailGuard(for: duration),
            volumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
            setsInitialVolumeToMax: setsInitialVolumeToMax,
            fadeOutDuration: fadeOut
        )
        guard playbackSessionID == sessionID else { return }
        startProgressTracking(duration: duration, sessionID: sessionID)
        scheduleCatalogStop(
            duration: duration,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
            sessionID: sessionID
        )
    }

    private func playLocal(
        url: URL,
        start: TimeInterval,
        duration: TimeInterval,
        reusePrewarm: Bool,
        sessionID: UUID
    ) throws {
        let player = if reusePrewarm, let prewarmedLocalPlayer {
            prewarmedLocalPlayer
        } else {
            try AVAudioPlayer(contentsOf: url)
        }
        audioPlayer = player
        player.currentTime = start
        guard player.play() else { throw PlaybackStartFailure(reason: .startRejected) }
        startProgressTracking(duration: duration, sessionID: sessionID)
        scheduleLocalStop(
            duration: duration,
            sessionID: sessionID
        )
    }

    private func sourceFamily(for cue: Cue) -> PlaybackSourceFamily {
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

    func playbackFailureReason(for error: Error) -> PlaybackFailureReason {
        if let failure = error as? PlaybackStartFailure { return failure.reason }
        if let appError = error as? AppError {
            switch appError {
            case .missingPreview: return .sourceUnavailable
            case .appleMusicFullSongCatalogUnavailable: return .sourceUnavailable
            default: return .playbackError
            }
        }
        return .playbackError
    }

    private func waitForRemotePlaybackStart(_ player: AVPlayer, sessionID: UUID) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while clock.now < deadline {
            guard playbackSessionID == sessionID else {
                throw PlaybackStartFailure(reason: .startTimedOut)
            }
            if player.timeControlStatus == .playing { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw PlaybackStartFailure(reason: .startTimedOut)
    }

    private func scheduleLocalStop(duration: TimeInterval, sessionID: UUID) {
        let stopDelay = playbackStopDelayIncludingTailGuard(for: duration)
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(stopDelay))
            guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
            self.stopIfCurrent(sessionID: sessionID)
        }
    }

    private func scheduleRemoteStop(duration: TimeInterval, fadeOut: TimeInterval, fadeOutVolumeAutomationEnabled: Bool, sessionID: UUID) {
        let schedule = PlaybackFadeSchedule.sourceBacked(
            selectedDuration: duration,
            tailGuard: primaryCueTailGuard,
            fadeOut: fadeOut,
            volumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
        stopTask = Task { [weak self] in
            if schedule.sustainDuration > 0 {
                try? await Task.sleep(for: .seconds(schedule.sustainDuration))
            }
            guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
            if schedule.fadeDuration > 0 {
                await self.fadeRemote(duration: schedule.fadeDuration, sessionID: sessionID)
                guard !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                if schedule.postFadeStopDelay > 0 {
                    try? await Task.sleep(for: .seconds(schedule.postFadeStopDelay))
                    guard !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                }
            }
            self.stopIfCurrent(sessionID: sessionID)
        }
    }

    private func scheduleCatalogStop(duration: TimeInterval, fadeOut: TimeInterval, fadeOutVolumeAutomationEnabled: Bool, sessionID: UUID) {
        let schedule = PlaybackFadeSchedule.sourceBacked(
            selectedDuration: duration,
            tailGuard: primaryCueTailGuard,
            fadeOut: fadeOut,
            volumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
        stopTask = Task { [weak self] in
            if schedule.sustainDuration > 0 {
                try? await Task.sleep(for: .seconds(schedule.sustainDuration))
            }
            guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
            if schedule.fadeDuration > 0 {
                await self.fadeCatalog(duration: schedule.fadeDuration, sessionID: sessionID)
                guard !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                if schedule.postFadeStopDelay > 0 {
                    try? await Task.sleep(for: .seconds(schedule.postFadeStopDelay))
                    guard !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                }
            }
            self.stopIfCurrent(sessionID: sessionID)
        }
    }

    private func playbackStopDelayIncludingTailGuard(for duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite else { return 0 }
        return max(0, duration) + primaryCueTailGuard
    }

    private func catalogPlaybackDurationIncludingTailGuard(for duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite else { return 0 }
        return min(appleMusicClipDurationLimit, max(0, duration) + primaryCueTailGuard)
    }

    private func startProgressTracking(duration: TimeInterval, sessionID: UUID) {
        progressTask?.cancel()
        let boundedDuration = max(0.01, duration)
        activeCueProgress = 0
        progressTask = Task { [weak self] in
            let clock = ContinuousClock()
            let start = clock.now
            while let self,
                  !Task.isCancelled,
                  self.playbackSessionID == sessionID {
                let elapsed = start.duration(to: clock.now)
                let components = elapsed.components
                let seconds = Double(components.seconds)
                    + Double(components.attoseconds) / 1_000_000_000_000_000_000
                self.activeCueProgress = min(1, seconds / boundedDuration)
                if seconds >= boundedDuration {
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func waitForAnnouncerPlaybackToFinish(_ player: AVAudioPlayer) async {
        let maxWait = max(0, player.duration) + announcerCompletionGrace
        let startDate = Date()
        while player.isPlaying, Date().timeIntervalSince(startDate) < maxWait {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(announcerCompletionPollInterval))
        }
    }

    private func fadeRemote(duration: TimeInterval, sessionID: UUID) async {
        guard let player = remotePlayer else { return }
        for step in stride(from: 8, through: 1, by: -1) {
            guard playbackSessionID == sessionID, !Task.isCancelled else { return }
            player.volume = Float(step) / 8
            try? await Task.sleep(for: .seconds(duration / 8))
        }
        guard playbackSessionID == sessionID, !Task.isCancelled else { return }
        player.volume = 0
    }

    private func fadeCatalog(duration: TimeInterval, sessionID: UUID) async {
        for step in stride(from: 8, through: 1, by: -1) {
            guard playbackSessionID == sessionID, !Task.isCancelled else { return }
            catalogPlaybackController.setVolume(Float(step) / 8)
            try? await Task.sleep(for: .seconds(duration / 8))
        }
        guard playbackSessionID == sessionID, !Task.isCancelled else { return }
        catalogPlaybackController.setVolume(0)
    }
}

extension CueSource {
    func runtimeVolumeAutomationEnabled(whenSettingEnabled settingEnabled: Bool) -> Bool {
        guard settingEnabled else { return false }
        if case .appleMusic = self {
            return true
        }
        return false
    }

    var maximumPlaybackDuration: TimeInterval? {
        switch self {
        case .appleMusic:
            return 20
        case .localAudio, .builtInClip:
            return nil
        }
    }
}

@MainActor
final class ReadinessService {
    private let audioAssetService: AudioAssetService
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "RollCall.Readiness")
    private var pathStatus: NWPath.Status = .requiresConnection
    var onPathStatusChange: (() -> Void)?

    init(audioAssetService: AudioAssetService) {
        self.audioAssetService = audioAssetService
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let previousStatus = self.pathStatus
                self.pathStatus = path.status
                if previousStatus != path.status {
                    self.onPathStatusChange?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    func snapshot(for team: Team?) -> ReadinessStatus {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute.outputs.first?.portName ?? "Unknown"
        let volume = session.outputVolume
        let presentPlayers = team?.presentPlayersInBattingOrder ?? []
        let appleMusicCount = presentPlayers.compactMap { team?.cue(for: $0) }.filter { cue in
            if case .appleMusic = cue.source { return true }
            return false
        }.count
        let musicAuthStatus = MusicAuthorization.currentStatus
        let playerChecks = presentPlayers.compactMap { readinessCheck(for: $0, team: team) }
        let customChecks = customAnnouncerChecks(for: team)
        let optionalChecks = optionalUpgradeChecks(for: team)
        return ReadinessStatus(
            generatedAt: .now,
            checks: [
                ReadinessCheck(id: "route", title: "Audio Route", detail: route == "Unknown" ? "Choose your speaker before live use." : route, state: route == "Unknown" ? .issue : .gameDayCheck, category: .audioRoute),
                ReadinessCheck(id: "volume", title: "Volume", detail: volume < 0.30 ? "Please check your volume - it appears low." : "\(Int(volume * 100))%", state: volume < 0.30 ? .issue : .gameDayCheck, category: .volume),
                ReadinessCheck(id: "network", title: "Apple Music Network", detail: appleMusicCount == 0 ? "No Apple Music cues in today's lineup." : (pathStatus == .satisfied ? "Connection available." : "Connection unavailable. Apple Music cues may fail."), state: appleMusicCount == 0 ? .gameDayCheck : (pathStatus == .satisfied ? .gameDayCheck : .issue), category: .network),
                ReadinessCheck(id: "music-auth", title: "Apple Music Access", detail: appleMusicCount == 0 ? "No Apple Music cues assigned." : appleMusicAuthorizationDetail(for: musicAuthStatus), state: readinessStateForMusic(status: musicAuthStatus, appleMusicCount: appleMusicCount), category: .appleMusicAccess, action: musicAuthStatus == .notDetermined && appleMusicCount > 0 ? .requestAppleMusicAccess : .none),
                ReadinessCheck(id: "lineup", title: "Present Players", detail: "\(presentPlayers.count) players marked present", state: team == nil || presentPlayers.isEmpty ? .issue : .gameDayCheck, category: .lineup),
            ] + playerChecks + customChecks + optionalChecks,
            teamID: team?.id
        )
    }

    private func readinessCheck(for player: Player, team: Team?) -> ReadinessCheck? {
        guard let team else { return nil }
        guard player.songAssignment != nil else {
            return ReadinessCheck(id: "player-\(player.id)-needs-audio", title: player.displayName, detail: "Add a song or local audio. Game Day can still use Small Cheer fallback.", state: .needsAudio, category: .playerAudio, playerID: player.id)
        }
        guard let clip = team.songClip(for: player) else {
            return ReadinessCheck(
                id: "player-\(player.id)-audio-issue",
                title: player.displayName,
                detail: "This player references a Team Clip that is no longer available. Choose a replacement.",
                state: .issue, category: .playerAudio, playerID: player.id
            )
        }

        if clip.hasCurrentGeneratedAsset,
           let generatedPath = clip.generatedAsset.relativePath,
           audioAssetService.assetExists(relativePath: generatedPath) {
            return playerReadinessCheck(
                for: player,
                detail: "A portable Roll Call clip is ready for Game Day."
            )
        }

        switch clip.readinessInputs.playback {
        case .needsAppleMusic:
            return ReadinessCheck(
                id: "player-\(player.id)-audio-issue",
                title: player.displayName,
                detail: "The song choice is preserved, but Apple Music access is needed on this device.",
                state: .issue, category: .playerAudio, playerID: player.id
            )
        case .needsRepair:
            return ReadinessCheck(
                id: "player-\(player.id)-audio-issue",
                title: player.displayName,
                detail: "The song choice is preserved, but its playable audio needs to be replaced or relinked.",
                state: .issue, category: .playerAudio, playerID: player.id
            )
        case .localClipReady, .sourceBackedReady, .sourceBackedDownloaded:
            break
        }

        switch clip.originalSource {
        case .appleMusic:
            return playerReadinessCheck(
                for: player,
                detail: clip.readinessInputs.downloadedOnDevice
                    ? "Apple Music playback is available on this device, but it is not portable in a team package."
                    : "Apple Music playback is available here and may require access again on another device."
            )
        case .localAudio(let source):
            if !audioAssetService.assetExists(relativePath: source.relativePath) {
                return ReadinessCheck(id: "player-\(player.id)-audio-issue", title: player.displayName, detail: "The selected local cue file is missing from app storage.", state: .issue, category: .playerAudio, playerID: player.id)
            }
            return playerReadinessCheck(
                for: player,
                detail: "Local audio is ready and can travel with an exported team."
            )
        case .builtInClip(let source):
            if !audioAssetService.assetExists(relativePath: builtInClipRelativePath(for: source)) {
                return ReadinessCheck(id: "player-\(player.id)-audio-issue", title: player.displayName, detail: "The selected built-in clip asset is missing.", state: .issue, category: .playerAudio, playerID: player.id)
            }
            return playerReadinessCheck(
                for: player,
                detail: "A built-in Roll Call clip is ready for Game Day."
            )
        }
    }

    private func playerReadinessCheck(for player: Player, detail: String) -> ReadinessCheck {
        if let customAnnouncerRelativePath = player.customAnnouncerRelativePath,
           !audioAssetService.assetExists(relativePath: customAnnouncerRelativePath) {
            return ReadinessCheck(id: "player-\(player.id)-custom-announcer-issue", title: player.displayName, detail: "The Announcement Cue file is missing from app storage.", state: .issue, category: .playerAnnouncement, playerID: player.id)
        }

        if hasStoredCustomAnnouncer(for: player) {
            return ReadinessCheck(
                id: "player-\(player.id)-enhanced",
                title: player.displayName,
                detail: "\(detail) An Announcement Cue is also ready.",
                state: .enhanced, category: .playerAudio, playerID: player.id
            )
        }

        return ReadinessCheck(
            id: "player-\(player.id)-ready",
            title: player.displayName,
            detail: detail,
            state: .ready, category: .playerAudio, playerID: player.id
        )
    }

    private func customAnnouncerChecks(for team: Team?) -> [ReadinessCheck] {
        guard let team else { return [] }
        let presentPlayers = team.presentPlayersInBattingOrder
        guard !presentPlayers.isEmpty else { return [] }
        let readyPlayers = presentPlayers.filter { player in
            guard team.cue(for: player) != nil else { return false }
            return readinessCheck(for: player, team: team)?.state != .issue
        }
        guard !readyPlayers.isEmpty else { return [] }

        return readyPlayers.compactMap { player in
            guard !hasStoredCustomAnnouncer(for: player) else { return nil }
            return ReadinessCheck(
                id: "player-\(player.id)-announcement-upgrade",
                title: player.displayName,
                detail: "Add an Announcement Cue to make this walkup feel more stadium-like.",
                state: .optional, category: .playerAnnouncement, playerID: player.id
            )
        }
    }

    private func readinessStateForMusic(status: MusicAuthorization.Status, appleMusicCount: Int) -> ReadinessState {
        guard appleMusicCount > 0 else { return .gameDayCheck }
        return status == .authorized ? .gameDayCheck : .issue
    }

    private func optionalUpgradeChecks(for team: Team?) -> [ReadinessCheck] {
        guard let team else { return [] }
        return team.presentPlayersInBattingOrder.compactMap { player in
            if player.photoRelativePath == nil {
                return ReadinessCheck(
                    id: "player-\(player.id)-photo-upgrade",
                    title: player.displayName,
                    detail: "A photo can make the live board easier to recognize, but this player can still be ready without one.",
                    state: .optional, category: .playerPhoto, playerID: player.id
                )
            }
            if let photoRelativePath = player.photoRelativePath,
               !audioAssetService.assetExists(relativePath: photoRelativePath) {
                return ReadinessCheck(
                    id: "player-\(player.id)-photo-upgrade",
                    title: player.displayName,
                    detail: "The saved photo is missing. This only affects presentation, not Game Day audio.",
                    state: .optional, category: .playerPhoto, playerID: player.id
                )
            }
            return nil
        }
    }

    private func hasStoredCustomAnnouncer(for player: Player) -> Bool {
        guard let relativePath = player.customAnnouncerRelativePath else { return false }
        return audioAssetService.assetExists(relativePath: relativePath)
    }

    private func appleMusicAuthorizationDetail(for status: MusicAuthorization.Status) -> String {
        switch status {
        case .authorized:
            return "Music authorization is available."
        case .denied:
            return "Music authorization is denied."
        case .restricted:
            return "Music authorization is restricted."
        case .notDetermined:
            return "Music authorization has not been requested yet."
        @unknown default:
            return "Music authorization state is unknown."
        }
    }
}

struct PackageService: Sendable {
    struct PreviewResult {
        var manifest: TeamPackageManifest
        var summary: PackageTransferSummary
    }

    struct ImportResult {
        var manifest: TeamPackageManifest
        var audit: PackageImportAudit
    }

    func transferSummary(for team: Team) -> PackageTransferSummary {
        let states = uniqueSongClips(in: team).map(transferState(for:))
        return PackageTransferSummary(
            localClipIncludedCount: states.filter { $0 == .localClipIncluded }.count,
            sourceReferenceOnlyCount: states.filter { $0 == .sourceReferenceOnly }.count,
            needsAppleMusicCount: states.filter { $0 == .needsAppleMusic }.count,
            stillPreparingCount: states.filter { $0 == .stillPreparing }.count,
            needsRepairCount: states.filter { $0 == .needsRepair }.count
        )
    }

    func export(team: Team, state: AppState) throws -> URL {
        let packageName = safePackageName(for: team.name)
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(packageName).rollcall", isDirectory: false)
        let stagingDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("\(packageName)-\(UUID().uuidString)", isDirectory: true)
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }
        if FileManager.default.fileExists(atPath: stagingDirectory.path) {
            try FileManager.default.removeItem(at: stagingDirectory)
        }
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stagingDirectory) }

        let manifest = TeamPackageManifest(
            schemaVersion: TeamPackageManifest.currentSchemaVersion,
            appVersion: state.appVersion,
            exportedAt: .now,
            deviceLabel: state.deviceIdentity.label,
            team: sanitized(team)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: stagingDirectory.appendingPathComponent("manifest.json"), options: .atomic)

        let packageAssetsURL = stagingDirectory.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: packageAssetsURL, withIntermediateDirectories: true)
        try copyAssets(for: manifest.team, into: packageAssetsURL)
        try FileManager.default.zipItem(at: stagingDirectory, to: exportURL, shouldKeepParent: false)

        return exportURL
    }

    func `import`(packageURL: URL, audioAssetService: AudioAssetService) throws -> TeamPackageManifest {
        try importWithAudit(
            packageURL: packageURL,
            audioAssetService: audioAssetService,
            musicAuthorizationStatus: MusicAuthorization.currentStatus,
            appleMusicPlaybackCapability: .unknown
        ).manifest
    }

    func importWithAudit(
        packageURL: URL,
        audioAssetService: AudioAssetService,
        musicAuthorizationStatus: MusicAuthorization.Status,
        appleMusicPlaybackCapability: AppleMusicPlaybackCapability
    ) throws -> ImportResult {
        let extractedDirectory = try extractedDirectoryIfNeeded(for: packageURL)
        defer {
            if let extractedDirectory {
                try? FileManager.default.removeItem(at: extractedDirectory)
            }
        }

        let packageRootURL = extractedDirectory ?? packageURL
        let manifestURL = try manifestURL(for: packageRootURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var manifest = try decoder.decode(TeamPackageManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.schemaVersion <= TeamPackageManifest.currentSchemaVersion else { throw AppError.unsupportedImportVersion }
        try validateImportableTeam(manifest.team)

        let packageAssetsURL = packageRootURL.appendingPathComponent("Assets", isDirectory: true)
        let attachmentIssues = try missingAttachmentAuditItems(for: manifest.team, packageAssetsDirectory: packageAssetsURL)
        if try isDirectory(packageRootURL) {
            var importedAssetPaths: [String] = []
            do {
                manifest.team = try importAssets(
                    for: manifest.team,
                    from: packageAssetsURL,
                    audioAssetService: audioAssetService,
                    importedAssetPaths: &importedAssetPaths
                )
            } catch {
                importedAssetPaths.forEach { audioAssetService.removeAsset(relativePath: $0) }
                throw error
            }
        }
        let audit = importAudit(
            for: manifest.team,
            musicAuthorizationStatus: musicAuthorizationStatus,
            appleMusicPlaybackCapability: appleMusicPlaybackCapability,
            attachmentIssues: attachmentIssues
        )
        return ImportResult(manifest: manifest, audit: audit)
    }

    func importAudit(
        for team: Team,
        musicAuthorizationStatus: MusicAuthorization.Status,
        appleMusicPlaybackCapability: AppleMusicPlaybackCapability,
        attachmentIssues: [PackageImportAudit.Item] = []
    ) -> PackageImportAudit {
        var items: [PackageImportAudit.Item] = []

        for player in team.players {
            guard let clip = team.songClip(for: player) else { continue }
            items.append(
                auditItem(
                    clip: clip,
                    title: player.displayName,
                    destination: .player(player.id),
                    musicAuthorizationStatus: musicAuthorizationStatus,
                    appleMusicPlaybackCapability: appleMusicPlaybackCapability
                )
            )
        }
        for clip in team.teamClips {
            items.append(
                auditItem(
                    clip: clip,
                    title: clip.displayName ?? clip.playbackCue.label,
                    destination: .teamClip(clip.id),
                    musicAuthorizationStatus: musicAuthorizationStatus,
                    appleMusicPlaybackCapability: appleMusicPlaybackCapability
                )
            )
        }
        items.append(contentsOf: attachmentIssues)
        return PackageImportAudit(
            teamID: team.id,
            teamName: team.name,
            items: items
        )
    }

    func preview(packageURL: URL) throws -> TeamPackageManifest {
        try previewDetails(packageURL: packageURL).manifest
    }

    func previewDetails(packageURL: URL) throws -> PreviewResult {
        let extractedDirectory = try extractedDirectoryIfNeeded(for: packageURL)
        defer {
            if let extractedDirectory {
                try? FileManager.default.removeItem(at: extractedDirectory)
            }
        }

        let packageRootURL = extractedDirectory ?? packageURL
        let manifestURL = try manifestURL(for: packageRootURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(TeamPackageManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.schemaVersion <= TeamPackageManifest.currentSchemaVersion else { throw AppError.unsupportedImportVersion }
        try validateImportableTeam(manifest.team)
        let packageAssetsURL = packageRootURL.appendingPathComponent("Assets", isDirectory: true)
        let states = try uniqueSongClips(in: manifest.team).map {
            try previewTransferState(for: $0, packageAssetsDirectory: packageAssetsURL)
        }
        return PreviewResult(
            manifest: manifest,
            summary: PackageTransferSummary(
                localClipIncludedCount: states.filter { $0 == .localClipIncluded }.count,
                sourceReferenceOnlyCount: states.filter { $0 == .sourceReferenceOnly }.count,
                needsAppleMusicCount: states.filter { $0 == .needsAppleMusic }.count,
                stillPreparingCount: states.filter { $0 == .stillPreparing }.count,
                needsRepairCount: states.filter { $0 == .needsRepair }.count
            )
        )
    }

    private func validateImportableTeam(_ team: Team) throws {
        let playerIDs = team.players.map(\.id)
        let teamClipIDs = team.teamClips.map(\.id)
        let lineupIDs = team.session.battingOrder

        guard Set(playerIDs).count == playerIDs.count,
              Set(teamClipIDs).count == teamClipIDs.count,
              Set(lineupIDs).count == lineupIDs.count,
              Set(lineupIDs).isSubset(of: Set(playerIDs)) else {
            throw AppError.invalidImport
        }
    }

    private func missingAttachmentAuditItems(
        for team: Team,
        packageAssetsDirectory: URL
    ) throws -> [PackageImportAudit.Item] {
        var items: [PackageImportAudit.Item] = []
        for player in team.players {
            if let photoPath = player.photoRelativePath,
               try packageAssetURLIfPresent(relativePath: photoPath, from: packageAssetsDirectory) == nil {
                items.append(.init(id: UUID(), destination: .player(player.id), title: "\(player.displayName) — Photo", state: .needsRepair, detail: "The package references a player photo, but its file was not included. Open the player to add it again."))
            }
            if let sourcePath = player.photoSourceRelativePath,
               try packageAssetURLIfPresent(relativePath: sourcePath, from: packageAssetsDirectory) == nil {
                items.append(.init(
                    id: UUID(),
                    destination: .player(player.id),
                    title: "\(player.displayName) — Photo Source",
                    state: .photoSourceMissing,
                    detail: "The compact photo is still usable, but the wider photo source was not included. Player Card framing will use the available profile photo until it is replaced."
                ))
            }
            if let announcementPath = player.customAnnouncerRelativePath,
               try packageAssetURLIfPresent(relativePath: announcementPath, from: packageAssetsDirectory) == nil {
                items.append(.init(id: UUID(), destination: .player(player.id), title: "\(player.displayName) — Announcement Cue", state: .needsRepair, detail: "The package references an Announcement Cue, but its audio file was not included. Open the player to record or import it again."))
            }
        }
        return items
    }

    func parseRosterCSV(from url: URL) async throws -> [ParsedRosterRow] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw AppError.invalidCSV
        }

        let rawLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !rawLines.isEmpty else { throw AppError.invalidCSV }

        let parsedLines = rawLines.map(parseCSVColumns)
        let firstRow = parsedLines[0].map { $0.lowercased() }
        let hasHeader = firstRow.contains("name")
        let rows = (hasHeader ? Array(parsedLines.dropFirst()) : parsedLines).compactMap { columns -> ParsedRosterRow? in
            guard !columns.isEmpty else { return nil }
            if hasHeader {
                guard let nameIndex = firstRow.firstIndex(of: "name") else { return nil }
                let numberIndex = firstRow.firstIndex(of: "number")
                let name = columns[safe: nameIndex]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let number = numberIndex.flatMap { columns[safe: $0] }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !name.isEmpty else { return nil }
                return ParsedRosterRow(name: name, number: number)
            }

            let name = columns.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let number = columns.count > 1 ? columns[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            guard !name.isEmpty else { return nil }
            return ParsedRosterRow(name: name, number: number)
        }

        guard !rows.isEmpty else { throw AppError.invalidCSV }
        return rows
    }

    func exportSupportBundle(
        state: AppState,
        selectedTeam: Team?,
        diagnostics: PlaybackSupportDiagnostics,
        generatedClipCleanup: GeneratedClipCleanupReport?
    ) throws -> URL {
        let teamSummaries = state.teams.enumerated().map { index, team in
            SupportBundlePayload.TeamSummary(
                name: "Team \(index + 1)",
                playerCount: team.players.count,
                presentPlayerCount: team.presentPlayersInBattingOrder.count,
                builtInClipCount: team.builtInClips.count
            )
        }
        let selectedTeamIndex = selectedTeam.flatMap { selectedTeam in
            state.teams.firstIndex(where: { $0.id == selectedTeam.id })
        }
        let payload = SupportBundlePayload(
            generatedAt: .now,
            appVersion: state.appVersion,
            schemaVersion: state.schemaVersion,
            selectedTeamIndex: selectedTeamIndex,
            settings: state.settings,
            experimental: state.experimental,
            readinessStateCounts: Dictionary(
                grouping: state.lastReadiness?.checks ?? [],
                by: { $0.state.rawValue }
            ).mapValues(\.count),
            playback: SupportBundlePayload.PlaybackSummary(
                hasActiveCue: diagnostics.activeCueID != nil,
                hasPrewarmedCue: diagnostics.prewarmedCueID != nil,
                hasLastStartedCue: diagnostics.lastStartedCueID != nil,
                debounceWindowSeconds: diagnostics.debounceWindowSeconds
            ),
            teams: teamSummaries,
            songClips: songClipDiagnostics(for: state, cleanup: generatedClipCleanup),
            generatedClipCleanup: generatedClipCleanup
        )

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RollCall-Support-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(payload).write(to: url, options: .atomic)
        return url
    }

    private func songClipDiagnostics(
        for state: AppState,
        cleanup: GeneratedClipCleanupReport?
    ) -> SupportBundlePayload.SongClipDiagnostics {
        let clips = state.teams.flatMap { team in
            team.teamClips + team.players.compactMap(\.songAssignment?.privateClip)
        }
        var sourceCounts: [String: Int] = [:]
        var generationCounts: [String: Int] = [:]
        var readinessCounts: [String: Int] = [:]
        var portabilityCounts: [String: Int] = [:]
        var failureCounts: [String: Int] = [:]
        var retryCount = 0

        for clip in clips {
            let sourceType: String
            switch clip.originalSource {
            case .appleMusic:
                sourceType = "appleMusic"
            case .localAudio:
                sourceType = "localAudio"
            case .builtInClip:
                sourceType = "builtInClip"
            }
            sourceCounts[sourceType, default: 0] += 1
            generationCounts[clip.generatedAsset.status.rawValue, default: 0] += 1
            readinessCounts[clip.readinessInputs.playback.rawValue, default: 0] += 1
            portabilityCounts[clip.portabilityInputs.portability.rawValue, default: 0] += 1
            retryCount += clip.retryMetadata.attemptCount
            if let failureCode = clip.retryMetadata.lastFailureCode {
                failureCounts[failureCode, default: 0] += 1
            }
        }

        return SupportBundlePayload.SongClipDiagnostics(
            totalClipCount: clips.count,
            sourceTypeCounts: sourceCounts,
            generationStatusCounts: generationCounts,
            readinessCounts: readinessCounts,
            portabilityCounts: portabilityCounts,
            totalRetryCount: retryCount,
            failureCodeCounts: failureCounts,
            generatedAssetDiskUsageBytes: cleanup?.discoveredByteCount
                ?? generatedReferencedDiskUsage(in: state),
            localGenerationEnabled: SongClipPolicy.current.localClipGenerationEnabled,
            appleMusicHandlingPolicy: SongClipPolicy.current.appleMusicHandlingPolicy.rawValue,
            autoDownloadEligibleSongsEnabled: SongClipPolicy.current.autoDownloadEligibleSongsEnabled,
            generationPolicyVersions: Array(Set(clips.map(\.policy.generationPolicyVersion))).sorted()
        )
    }

    private func generatedReferencedDiskUsage(in state: AppState) -> Int64 {
        let paths = Set(
            state.teams.flatMap { team in
                let clips = team.teamClips + team.players.compactMap(\.songAssignment?.privateClip)
                return clips.compactMap(\.generatedAsset.relativePath)
            }
        )
        return paths.reduce(0) { total, path in
            guard let url = try? AppPaths.assetURL(relativePath: path),
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                return total
            }
            return total + Int64(size)
        }
    }

    private func sanitized(_ team: Team) -> Team {
        var team = team
        team.teamClips = team.teamClips.map(sanitized)
        team.players = team.players.map { player in
            var player = player
            if case .privateClip(let clip)? = player.songAssignment {
                player.songAssignment = .privateClip(sanitized(clip))
            }
            return player
        }
        return team
    }

    private func sanitized(_ clip: SongClip) -> SongClip {
        var clip = clip
        if case .localAudio(var local) = clip.originalSource {
            local.hiddenOriginNote = nil
            clip.originalSource = .localAudio(local)
        }
        guard clip.hasCurrentGeneratedAsset,
              clip.portabilityInputs.generatedAssetCanBeExported,
              let relativePath = clip.generatedAsset.relativePath,
              assetExists(relativePath: relativePath) else {
            if clip.generatedAsset.status == .ready {
                clip.generatedAsset = GeneratedClipAsset(
                    relativePath: nil,
                    status: .failedPermanent,
                    renderedSelection: nil,
                    generationKey: clip.generatedAsset.generationKey,
                    generatedAt: nil
                )
                clip.readinessInputs.playback = fallbackReadiness(for: clip.originalSource)
                clip.portabilityInputs = fallbackPortability(for: clip.originalSource)
            }
            return clip
        }
        return clip
    }

    private func safePackageName(for teamName: String) -> String {
        let sanitized = teamName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "RollCall-Team" : sanitized.replacingOccurrences(of: " ", with: "-")
    }

    private func extractedDirectoryIfNeeded(for packageURL: URL) throws -> URL? {
        if try isDirectory(packageURL) {
            return nil
        }
        let extractedURL = FileManager.default.temporaryDirectory.appendingPathComponent("RollCall-Import-\(UUID().uuidString)", isDirectory: true)
        if FileManager.default.fileExists(atPath: extractedURL.path) {
            try FileManager.default.removeItem(at: extractedURL)
        }
        try FileManager.default.createDirectory(at: extractedURL, withIntermediateDirectories: true)
        do {
            try FileManager.default.unzipItem(at: packageURL, to: extractedURL)
            return extractedURL
        } catch {
            try? FileManager.default.removeItem(at: extractedURL)
            throw error
        }
    }

    private func manifestURL(for packageURL: URL) throws -> URL {
        if try isDirectory(packageURL) {
            let manifestURL = packageURL.appendingPathComponent("manifest.json")
            guard FileManager.default.fileExists(atPath: manifestURL.path) else { throw AppError.invalidImport }
            return manifestURL
        }
        return packageURL
    }

    private func copyAssets(for team: Team, into assetsDirectory: URL) throws {
        try copyPlayerAssets(for: team.players, into: assetsDirectory)
        for clip in uniqueSongClips(in: team) {
            try copyClipAssets(for: clip, into: assetsDirectory)
        }
    }

    private func copyPlayerAssets(for players: [Player], into assetsDirectory: URL) throws {
        for player in players {
            if let photoRelativePath = player.photoRelativePath {
                try copyAssetIfPresent(relativePath: photoRelativePath, into: assetsDirectory)
            }
            if let photoSourceRelativePath = player.photoSourceRelativePath {
                try copyAssetIfPresent(relativePath: photoSourceRelativePath, into: assetsDirectory)
            }
            try copyAssetIfPresent(relativePath: player.customAnnouncerRelativePath, into: assetsDirectory)
        }
    }

    private func copyClipAssets(for clip: SongClip, into assetsDirectory: URL) throws {
        if case .localAudio(let source) = clip.originalSource {
            try copyAssetIfPresent(relativePath: source.relativePath, into: assetsDirectory)
        }
        if clip.hasCurrentGeneratedAsset,
           clip.portabilityInputs.generatedAssetCanBeExported {
            try copyAssetIfPresent(
                relativePath: clip.generatedAsset.relativePath,
                into: assetsDirectory
            )
        }
    }

    private func copyAssetIfPresent(relativePath: String?, into packageAssetsDirectory: URL) throws {
        guard let relativePath else { return }
        let sourceURL = try AppPaths.assetURL(relativePath: relativePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        let packagePath = try validatedPackageAssetRelativePath(relativePath)
        let destinationURL = packageAssetsDirectory.appendingPathComponent(packagePath)
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    private func importAssets(
        for team: Team,
        from packageAssetsDirectory: URL,
        audioAssetService: AudioAssetService,
        importedAssetPaths: inout [String]
    ) throws -> Team {
        var importedTeam = team
        importedTeam.teamClips = try importedTeam.teamClips.map {
            try importSongClip(
                $0,
                from: packageAssetsDirectory,
                audioAssetService: audioAssetService,
                importedAssetPaths: &importedAssetPaths
            )
        }
        importedTeam.players = try importedTeam.players.map { player in
            var player = player
            if let photoRelativePath = player.photoRelativePath {
                player.photoRelativePath = try importPhotoIfPresent(relativePath: photoRelativePath, from: packageAssetsDirectory)
                if let importedPhotoPath = player.photoRelativePath {
                    importedAssetPaths.append(importedPhotoPath)
                }
            }
            if let photoSourceRelativePath = player.photoSourceRelativePath {
                player.photoSourceRelativePath = try importPhotoIfPresent(relativePath: photoSourceRelativePath, from: packageAssetsDirectory)
                if let importedSourcePath = player.photoSourceRelativePath {
                    importedAssetPaths.append(importedSourcePath)
                } else {
                    player.profilePhotoCrop = nil
                    player.playerCardPhotoCrop = nil
                }
            }
            if case .privateClip(let clip)? = player.songAssignment {
                player.songAssignment = .privateClip(
                    try importSongClip(
                        clip,
                        from: packageAssetsDirectory,
                        audioAssetService: audioAssetService,
                        importedAssetPaths: &importedAssetPaths
                    )
                )
            }
            player.customAnnouncerRelativePath = try importGeneratedAudioIfPresent(relativePath: player.customAnnouncerRelativePath, from: packageAssetsDirectory, audioAssetService: audioAssetService)
            if let importedAnnouncementPath = player.customAnnouncerRelativePath {
                importedAssetPaths.append(importedAnnouncementPath)
            }
            return player
        }
        return importedTeam
    }

    private func importSongClip(
        _ original: SongClip,
        from packageAssetsDirectory: URL,
        audioAssetService: AudioAssetService,
        importedAssetPaths: inout [String]
    ) throws -> SongClip {
        var clip = original
        var originalLocalSourceWasRestored = true

        if case .localAudio(let source) = clip.originalSource {
            if let imported = try importLocalAudioIfPresent(
                source,
                from: packageAssetsDirectory,
                audioAssetService: audioAssetService
            ) {
                clip.originalSource = .localAudio(imported)
                importedAssetPaths.append(imported.relativePath)
            } else {
                originalLocalSourceWasRestored = false
                var missing = source
                let ext = URL(fileURLWithPath: source.relativePath).pathExtension
                let suffix = ext.isEmpty ? "m4a" : ext
                missing.relativePath = "MissingImportedAssets/\(UUID().uuidString).\(suffix)"
                missing.hiddenOriginNote = nil
                clip.originalSource = .localAudio(missing)
            }
        }

        if clip.hasCurrentGeneratedAsset,
           clip.portabilityInputs.generatedAssetCanBeExported,
           let relativePath = clip.generatedAsset.relativePath,
           let importedGeneratedPath = try importGeneratedClipIfPresent(
                relativePath: relativePath,
                from: packageAssetsDirectory
           ) {
            clip.generatedAsset.relativePath = importedGeneratedPath
            importedAssetPaths.append(importedGeneratedPath)
            clip.readinessInputs = SongClipReadinessInputs(
                playback: .localClipReady,
                sourceAvailableOnDevice: true,
                downloadedOnDevice: true
            )
            clip.portabilityInputs = SongClipPortabilityInputs(
                portability: .portableLocalClip,
                generatedAssetCanBeExported: true
            )
            return clip
        }

        clip.generatedAsset.relativePath = nil
        if clip.generatedAsset.status == .ready {
            clip.generatedAsset.status = .failedPermanent
        }

        switch clip.originalSource {
        case .localAudio:
            clip.readinessInputs = SongClipReadinessInputs(
                playback: originalLocalSourceWasRestored ? .sourceBackedReady : .needsRepair,
                sourceAvailableOnDevice: originalLocalSourceWasRestored,
                downloadedOnDevice: originalLocalSourceWasRestored
            )
            clip.portabilityInputs = SongClipPortabilityInputs(
                portability: originalLocalSourceWasRestored ? .portableLocalClip : .metadataOnly,
                generatedAssetCanBeExported: false
            )
        case .builtInClip:
            clip.readinessInputs = SongClipReadinessInputs(
                playback: .sourceBackedReady,
                sourceAvailableOnDevice: true,
                downloadedOnDevice: true
            )
            clip.portabilityInputs = SongClipPortabilityInputs(
                portability: .portableLocalClip,
                generatedAssetCanBeExported: false
            )
        case .appleMusic:
            clip.readinessInputs = SongClipReadinessInputs(
                playback: .needsAppleMusic,
                sourceAvailableOnDevice: false,
                downloadedOnDevice: false
            )
            clip.portabilityInputs = SongClipPortabilityInputs(
                portability: .sourceReferenceOnly,
                generatedAssetCanBeExported: false
            )
        }
        return clip
    }

    private func importLocalAudioIfPresent(
        _ source: LocalAudioSource,
        from packageAssetsDirectory: URL,
        audioAssetService: AudioAssetService
    ) throws -> LocalAudioSource? {
        guard let sourceURL = try packageAssetURLIfPresent(
            relativePath: source.relativePath,
            from: packageAssetsDirectory
        ) else {
            return nil
        }
        var imported = try audioAssetService.storeCopiedAsset(
            from: sourceURL,
            suggestedExtension: sourceURL.pathExtension,
            displayName: source.displayName,
            hiddenOriginNote: source.hiddenOriginNote
        )
        imported.importedAt = source.importedAt
        imported.hiddenOriginNote = source.hiddenOriginNote
        return imported
    }

    private func importGeneratedClipIfPresent(
        relativePath: String,
        from packageAssetsDirectory: URL
    ) throws -> String? {
        guard let sourceURL = try packageAssetURLIfPresent(
            relativePath: relativePath,
            from: packageAssetsDirectory
        ) else {
            return nil
        }
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let fileName = "\(UUID().uuidString).\(ext)"
        let destinationURL = try AppPaths.generatedClipsDirectory()
            .appendingPathComponent(fileName, isDirectory: false)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return "GeneratedClips/\(fileName)"
    }

    private func importGeneratedAudioIfPresent(relativePath: String?, from packageAssetsDirectory: URL, audioAssetService: AudioAssetService) throws -> String? {
        guard let relativePath else { return nil }
        guard let sourceURL = try packageAssetURLIfPresent(relativePath: relativePath, from: packageAssetsDirectory) else { return nil }
        let imported = try audioAssetService.storeCopiedAsset(
            from: sourceURL,
            suggestedExtension: sourceURL.pathExtension,
            displayName: sourceURL.deletingPathExtension().lastPathComponent,
            hiddenOriginNote: nil
        )
        return imported.relativePath
    }

    private func importPhotoIfPresent(relativePath: String, from packageAssetsDirectory: URL) throws -> String? {
        guard let sourceURL = try packageAssetURLIfPresent(relativePath: relativePath, from: packageAssetsDirectory) else { return nil }
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destinationURL = try AppPaths.assetURL(relativePath: "\(UUID().uuidString).\(ext)")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL.lastPathComponent
    }

    private func packageAssetURLIfPresent(relativePath: String, from packageAssetsDirectory: URL) throws -> URL? {
        let validatedPath = try validatedPackageAssetRelativePath(relativePath)
        let assetURL = packageAssetsDirectory.appendingPathComponent(validatedPath, isDirectory: false)
        let packageAssetsPath = packageAssetsDirectory.standardizedFileURL.path
        let assetPath = assetURL.standardizedFileURL.path
        guard assetPath.hasPrefix(packageAssetsPath + "/") else { throw AppError.invalidImport }
        guard FileManager.default.fileExists(atPath: assetURL.path) else { return nil }
        let values = try assetURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw AppError.invalidImport }
        return assetURL
    }

    private func validatedPackageAssetRelativePath(_ relativePath: String) throws -> String {
        let path = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let allowedDirectory = components.count == 2
            && ["GeneratedClips", "MissingImportedAssets"].contains(components[0])
        let isSingleFile = components.count == 1
        guard !path.isEmpty,
              isSingleFile || allowedDirectory,
              components.allSatisfy({
                  !$0.isEmpty && $0 != "." && $0 != ".." && !$0.hasPrefix(".") && !$0.contains("\\")
              }) else {
            throw AppError.invalidImport
        }
        return components.joined(separator: "/")
    }

    private func uniqueSongClips(in team: Team) -> [SongClip] {
        var seen: Set<UUID> = []
        return (team.teamClips + team.players.compactMap(\.songAssignment?.privateClip)).filter {
            seen.insert($0.id).inserted
        }
    }

    private func transferState(for clip: SongClip) -> PackageClipTransferState {
        if clip.generatedAsset.status == .pending {
            return .stillPreparing
        }
        if clip.readinessInputs.playback == .needsRepair {
            return .needsRepair
        }
        if clip.readinessInputs.playback == .needsAppleMusic {
            return .needsAppleMusic
        }
        if clip.hasCurrentGeneratedAsset,
           clip.portabilityInputs.generatedAssetCanBeExported,
           let path = clip.generatedAsset.relativePath,
           assetExists(relativePath: path) {
            return .localClipIncluded
        }
        switch clip.originalSource {
        case .localAudio(let source):
            return assetExists(relativePath: source.relativePath) ? .localClipIncluded : .needsRepair
        case .builtInClip:
            return .localClipIncluded
        case .appleMusic:
            return .sourceReferenceOnly
        }
    }

    private func previewTransferState(
        for clip: SongClip,
        packageAssetsDirectory: URL
    ) throws -> PackageClipTransferState {
        if clip.generatedAsset.status == .pending {
            return .stillPreparing
        }
        if clip.hasCurrentGeneratedAsset,
           clip.portabilityInputs.generatedAssetCanBeExported,
           let path = clip.generatedAsset.relativePath,
           try packageAssetURLIfPresent(
               relativePath: path,
               from: packageAssetsDirectory
           ) != nil {
            return .localClipIncluded
        }
        switch clip.originalSource {
        case .localAudio(let source):
            return try packageAssetURLIfPresent(
                relativePath: source.relativePath,
                from: packageAssetsDirectory
            ) == nil ? .needsRepair : .localClipIncluded
        case .builtInClip:
            return .localClipIncluded
        case .appleMusic:
            return clip.readinessInputs.playback == .needsAppleMusic
                ? .needsAppleMusic
                : .sourceReferenceOnly
        }
    }

    private func auditItem(
        clip: SongClip,
        title: String,
        destination: PackageImportAudit.Item.Destination,
        musicAuthorizationStatus: MusicAuthorization.Status,
        appleMusicPlaybackCapability: AppleMusicPlaybackCapability
    ) -> PackageImportAudit.Item {
        let state: PackageClipTransferState
        let detail: String
        if clip.hasCurrentGeneratedAsset,
           let path = clip.generatedAsset.relativePath,
           assetExists(relativePath: path) {
            state = .localClipIncluded
            detail = "A portable Roll Call clip was included and is ready on this device."
        } else {
            switch clip.originalSource {
            case .localAudio(let source) where assetExists(relativePath: source.relativePath):
                state = .localClipIncluded
                detail = "Local audio was included and is ready on this device."
            case .builtInClip:
                state = .localClipIncluded
                detail = "This built-in Roll Call clip is ready on this device."
            case .appleMusic:
                if musicAuthorizationStatus == .notDetermined {
                    state = .needsAppleMusicCheck
                    detail = "The song choice was preserved. Tap the marker to allow Music access and check Apple Music on this device."
                } else if musicAuthorizationStatus == .authorized && appleMusicPlaybackCapability == .fullSong {
                    state = .sourceReferenceOnly
                    detail = "Apple Music playback access is confirmed on this device. The saved song link is still device-dependent."
                } else if musicAuthorizationStatus == .authorized {
                    state = .needsAppleMusic
                    detail = "The song choice was preserved, but this device does not have an active Apple Music playback subscription available to Roll Call."
                } else {
                    state = .needsAppleMusic
                    detail = "The song choice was preserved, but Music access is not available to Roll Call on this device."
                }
            case .localAudio:
                state = .needsRepair
                detail = "The song choice was preserved, but its local audio file was not included."
            }
        }
        return PackageImportAudit.Item(
            id: UUID(),
            destination: destination,
            title: title,
            state: state,
            detail: detail
        )
    }

    private func assetExists(relativePath: String) -> Bool {
        guard let url = try? AppPaths.assetURL(relativePath: relativePath) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func fallbackReadiness(for source: SongSource) -> SongClipPlaybackReadiness {
        switch source {
        case .appleMusic:
            return .needsAppleMusic
        case .localAudio(let local):
            return assetExists(relativePath: local.relativePath) ? .sourceBackedReady : .needsRepair
        case .builtInClip:
            return .sourceBackedReady
        }
    }

    private func fallbackPortability(for source: SongSource) -> SongClipPortabilityInputs {
        switch source {
        case .appleMusic:
            return SongClipPortabilityInputs(
                portability: .sourceReferenceOnly,
                generatedAssetCanBeExported: false
            )
        case .localAudio(let local):
            return SongClipPortabilityInputs(
                portability: assetExists(relativePath: local.relativePath)
                    ? .portableLocalClip
                    : .metadataOnly,
                generatedAssetCanBeExported: false
            )
        case .builtInClip:
            return SongClipPortabilityInputs(
                portability: .portableLocalClip,
                generatedAssetCanBeExported: false
            )
        }
    }

    private func isDirectory(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        return values.isDirectory == true
    }

    private func parseCSVColumns(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false
        for character in line {
            switch character {
            case "\"":
                inQuotes.toggle()
            case "," where !inQuotes:
                values.append(current)
                current = ""
            default:
                current.append(character)
            }
        }
        values.append(current)
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
