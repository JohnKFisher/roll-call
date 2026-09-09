import Foundation

struct GeneratedClipCleanupReport: Codable, Equatable, Sendable {
    var discoveredFileCount: Int
    var discoveredByteCount: Int64
    var referencedFileCount: Int
    var orphanedFileCount: Int
    var orphanedByteCount: Int64
    var removedFileCount: Int
    var removedByteCount: Int64
    var retainedUncertainFileCount: Int
    var blockedReason: String?

    var canClean: Bool {
        blockedReason == nil && orphanedFileCount > 0
    }
}

struct GeneratedClipCleanupService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func audit(state: AppState, activePreparationCount: Int) -> GeneratedClipCleanupReport {
        do {
            let generatedDirectory = try AppPaths.generatedClipsDirectory()
            let inventory = try generatedClipInventory(in: generatedDirectory)
            var referencedPaths = generatedClipReferences(in: state)

            do {
                for snapshotState in try snapshotStatesIncludingOrphanedFiles(in: state) {
                    referencedPaths.formUnion(generatedClipReferences(in: snapshotState))
                }
            } catch {
                return blockedReport(
                    inventory: inventory,
                    reason: "A backup snapshot could not be read, so Roll Call retained every generated clip."
                )
            }

            if activePreparationCount > 0 {
                return blockedReport(
                    inventory: inventory,
                    reason: "Clip preparation is active, so cleanup was deferred."
                )
            }

            let orphaned = inventory.files.filter { !referencedPaths.contains($0.relativePath) }
            return GeneratedClipCleanupReport(
                discoveredFileCount: inventory.files.count,
                discoveredByteCount: inventory.files.reduce(0) { $0 + $1.byteCount },
                referencedFileCount: inventory.files.count - orphaned.count,
                orphanedFileCount: orphaned.count,
                orphanedByteCount: orphaned.reduce(0) { $0 + $1.byteCount },
                removedFileCount: 0,
                removedByteCount: 0,
                retainedUncertainFileCount: inventory.uncertainFileCount,
                blockedReason: inventory.uncertainFileCount > 0
                    ? "The generated clips folder contains an unexpected item, so Roll Call retained every generated clip."
                    : nil
            )
        } catch {
            return GeneratedClipCleanupReport(
                discoveredFileCount: 0,
                discoveredByteCount: 0,
                referencedFileCount: 0,
                orphanedFileCount: 0,
                orphanedByteCount: 0,
                removedFileCount: 0,
                removedByteCount: 0,
                retainedUncertainFileCount: 0,
                blockedReason: "Generated clip storage could not be inspected, so nothing was removed."
            )
        }
    }

    func clean(state: AppState, activePreparationCount: Int) -> GeneratedClipCleanupReport {
        let report = audit(state: state, activePreparationCount: activePreparationCount)
        guard report.blockedReason == nil, report.orphanedFileCount > 0 else { return report }

        do {
            let directory = try AppPaths.generatedClipsDirectory()
            let inventory = try generatedClipInventory(in: directory)
            let references = try allReferencesIncludingSnapshots(in: state)
            let orphaned = inventory.files.filter { !references.contains($0.relativePath) }
            var removedCount = 0
            var removedBytes: Int64 = 0

            for file in orphaned {
                try fileManager.removeItem(at: file.url)
                removedCount += 1
                removedBytes += file.byteCount
            }

            var cleaned = report
            cleaned.removedFileCount = removedCount
            cleaned.removedByteCount = removedBytes
            cleaned.discoveredFileCount = max(0, report.discoveredFileCount - removedCount)
            cleaned.discoveredByteCount = max(0, report.discoveredByteCount - removedBytes)
            cleaned.orphanedFileCount = max(0, report.orphanedFileCount - removedCount)
            cleaned.orphanedByteCount = max(0, report.orphanedByteCount - removedBytes)
            return cleaned
        } catch {
            var blocked = report
            blocked.blockedReason = "Cleanup stopped because a generated clip could not be removed."
            return blocked
        }
    }

    private func allReferencesIncludingSnapshots(in state: AppState) throws -> Set<String> {
        var references = generatedClipReferences(in: state)
        for snapshotState in try snapshotStatesIncludingOrphanedFiles(in: state) {
            references.formUnion(generatedClipReferences(in: snapshotState))
        }
        return references
    }

    private func snapshotStatesIncludingOrphanedFiles(in state: AppState) throws -> [AppState] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var urls: [URL] = []

        for snapshot in state.snapshots {
            let url = try snapshotURL(for: snapshot)
            guard fileManager.fileExists(atPath: url.path) else {
                throw AppError.invalidImport
            }
            urls.append(url)
        }

        let snapshotsDirectory = try AppPaths.snapshotsDirectory()
        let knownPaths = Set(urls.map { $0.standardizedFileURL.path })
        let orphanedSnapshotFiles = try fileManager.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            guard url.pathExtension.lowercased() == "json",
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else {
                return false
            }
            return !knownPaths.contains(url.standardizedFileURL.path)
        }
        urls.append(contentsOf: orphanedSnapshotFiles)

        return try urls.map { url in
            let snapshotState = try decoder.decode(AppState.self, from: Data(contentsOf: url))
            guard snapshotState.schemaVersion <= AppState.currentSchemaVersion else {
                throw AppError.unsupportedSavedStateVersion
            }
            return snapshotState
        }
    }

    private func snapshotURL(for snapshot: SnapshotRecord) throws -> URL {
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

    private func generatedClipReferences(in state: AppState) -> Set<String> {
        var references = Set<String>()
        state.teams.forEach { collectReferences(from: $0, into: &references) }
        state.recentlyDeleted.forEach { item in
            switch item.payload {
            case .team(let deleted):
                collectReferences(from: deleted.team, into: &references)
            case .player(let deleted):
                collectReferences(from: deleted.player, into: &references)
            case .customClip(let deleted):
                collectReferences(from: deleted.clip, into: &references)
            }
        }
        return references
    }

    private func collectReferences(from team: Team, into references: inout Set<String>) {
        team.players.forEach { collectReferences(from: $0, into: &references) }
        team.teamClips.forEach { collectReferences(from: $0, into: &references) }
    }

    private func collectReferences(from player: Player, into references: inout Set<String>) {
        if case .privateClip(let clip)? = player.songAssignment {
            collectReferences(from: clip, into: &references)
        }
    }

    private func collectReferences(from clip: SongClip, into references: inout Set<String>) {
        addGeneratedPath(clip.generatedAsset.relativePath, to: &references)
        if case .localAudio(let source) = clip.originalSource.cueSource {
            addGeneratedPath(source.relativePath, to: &references)
        }
    }

    private func addGeneratedPath(_ path: String?, to references: inout Set<String>) {
        guard let path, path.hasPrefix("GeneratedClips/") else { return }
        references.insert(path)
    }

    private func blockedReport(
        inventory: GeneratedClipInventory,
        reason: String
    ) -> GeneratedClipCleanupReport {
        GeneratedClipCleanupReport(
            discoveredFileCount: inventory.files.count,
            discoveredByteCount: inventory.files.reduce(0) { $0 + $1.byteCount },
            referencedFileCount: inventory.files.count,
            orphanedFileCount: 0,
            orphanedByteCount: 0,
            removedFileCount: 0,
            removedByteCount: 0,
            retainedUncertainFileCount: inventory.uncertainFileCount,
            blockedReason: reason
        )
    }

    private func generatedClipInventory(in directory: URL) throws -> GeneratedClipInventory {
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        var files: [GeneratedClipFile] = []
        var uncertainCount = 0

        for url in urls {
            let values = try url.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
            )
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                uncertainCount += 1
                continue
            }
            files.append(
                GeneratedClipFile(
                    url: url,
                    relativePath: "GeneratedClips/\(url.lastPathComponent)",
                    byteCount: Int64(values.fileSize ?? 0)
                )
            )
        }
        return GeneratedClipInventory(files: files, uncertainFileCount: uncertainCount)
    }
}

private struct GeneratedClipInventory {
    var files: [GeneratedClipFile]
    var uncertainFileCount: Int
}

private struct GeneratedClipFile {
    var url: URL
    var relativePath: String
    var byteCount: Int64
}
