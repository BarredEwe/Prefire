import Foundation

/// Finds recorded snapshots that no generated test refers to anymore.
///
/// Deleting a user's files is irreversible, so every step is deliberately narrow: only folders
/// listed in the manifest are scanned, only `__Snapshots__/<TestFile>` folders are accepted, only
/// regular image files are considered, and a file survives as soon as it belongs to the family of
/// any expected snapshot.
public enum SnapshotPruner {
    /// Folder SnapshotTesting keeps its snapshots in. Nothing outside it is ever touched.
    static let snapshotsFolderName = "__Snapshots__"

    /// Extensions `prune` may remove. Anything else in the folder — `.gitkeep`, a README,
    /// a hand-written `.txt` snapshot — is left alone.
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic"]

    /// Snapshot files inside the manifest's folders that no expected snapshot claims.
    public static func orphans(for manifest: SnapshotManifest, fileManager: FileManager = .default) -> [String] {
        manifest.directories.flatMap { orphans(in: $0, fileManager: fileManager) }
    }

    /// Removes the given files. Paths are re-validated, so a stale or hand-edited list
    /// cannot reach beyond a snapshot folder.
    @discardableResult
    public static func delete(_ paths: [String], fileManager: FileManager = .default) throws -> [String] {
        var deleted: [String] = []

        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard isSnapshotDirectory(url.deletingLastPathComponent().path),
                  isPrunableFile(at: url, fileManager: fileManager) else {
                Logger.warning("⚠️ Refusing to delete \(path): not a snapshot image.")
                continue
            }

            try fileManager.removeItem(at: url)
            deleted.append(path)
        }

        return deleted
    }

    // MARK: - Private methods

    private static func orphans(in directory: SnapshotManifest.Directory, fileManager: FileManager) -> [String] {
        guard directory.complete else {
            Logger.warning("⚠️ Skipping \(directory.path): it also holds snapshots named at runtime by PrefireProvider previews.")
            return []
        }

        guard isSnapshotDirectory(directory.path) else {
            Logger.warning("⚠️ Skipping \(directory.path): not a `\(snapshotsFolderName)` folder.")
            return []
        }

        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return [] }

        let stems = directory.snapshots.map(\.stem).filter({ !$0.isEmpty })
        let directoryURL = URL(fileURLWithPath: directory.path)

        return names.sorted().compactMap { name -> String? in
            let url = directoryURL.appendingPathComponent(name)
            guard isPrunableFile(at: url, fileManager: fileManager) else { return nil }

            let fileName = url.deletingPathExtension().lastPathComponent
            guard !stems.contains(where: { belongs(fileName: fileName, to: $0) }) else { return nil }

            return url.path
        }
    }

    /// A snapshot folder is always `.../__Snapshots__/<TestFile>`.
    private static func isSnapshotDirectory(_ path: String) -> Bool {
        URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent == snapshotsFolderName
    }

    private static func isPrunableFile(at url: URL, fileManager: FileManager) -> Bool {
        let name = url.lastPathComponent
        guard !name.hasPrefix("."), imageExtensions.contains(url.pathExtension.lowercased()) else { return false }

        // `attributesOfItem` does not resolve symlinks, so only real files pass.
        let type = try? fileManager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
        return type == .typeRegular
    }

    /// A file belongs to a snapshot when it is the snapshot itself or one of its variants:
    /// `Foo.1.png`, `Foo-iPhone-15.1.png`, `Foo-1-argument.1.png`, `Foo-accessibility.1.png`.
    ///
    /// Exact names cannot be predicted — the argument of a parameterized preview is rendered with
    /// `String(describing:)` at runtime — so the family prefix is the smallest unit `prune` can
    /// judge without risking a false positive.
    private static func belongs(fileName: String, to stem: String) -> Bool {
        fileName == stem || fileName.hasPrefix(stem + ".") || fileName.hasPrefix(stem + "-")
    }
}
