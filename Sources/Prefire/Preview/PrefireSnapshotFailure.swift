import Foundation

/// Failure messages that point at the images behind a failing snapshot.
public enum PrefireSnapshotFailure {
    /// `file://` links to the reference and recorded images, appended to a SnapshotTesting failure.
    ///
    /// SnapshotTesting numbers snapshots that share a name (`AuthView.1.png`, `AuthView.2.png`,
    /// as a `PreviewProvider` with several unnamed previews produces), so the right file cannot be
    /// derived from the name alone. It does put the absolute paths into the failure it returns,
    /// but the rendering depends on the configured diff tool, so instead of parsing that text the
    /// candidates on disk are matched against it. Nothing matching means only the folder is
    /// reported, never a guessed file.
    ///
    /// - Parameters:
    ///   - failure: Message returned by `verifySnapshot`.
    ///   - snapshotDirectory: Folder holding the reference images.
    ///   - artifactsDirectory: Folder SnapshotTesting writes recorded images to. Resolved from
    ///                         `SNAPSHOT_ARTIFACTS` when omitted.
    public static func fileLinks(for failure: String, snapshotDirectory: URL, artifactsDirectory: URL? = nil) -> String {
        guard let reference = referencedFile(in: snapshotDirectory, mentionedIn: failure) else {
            return "\nSnapshot files: \(snapshotDirectory.absoluteString)"
        }

        let artifacts = artifactsDirectory ?? defaultArtifactsDirectory(for: snapshotDirectory)
        let recorded = artifacts.appendingPathComponent(reference.lastPathComponent)

        var lines = ["", "Snapshot files:", "  reference: \(reference.absoluteString)"]
        if failure.contains(recorded.path) {
            lines.append("  recorded:  \(recorded.absoluteString)")
            lines.append("  diff:      ksdiff \"\(reference.path)\" \"\(recorded.path)\"")
        }
        return lines.joined(separator: "\n")
    }

    /// File in `directory` whose path the failure mentions — the one SnapshotTesting compared.
    private static func referencedFile(in directory: URL, mentionedIn failure: String) -> URL? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .sorted()
            .map(directory.appendingPathComponent)
            .first { failure.contains($0.path) }
    }

    private static func defaultArtifactsDirectory(for snapshotDirectory: URL) -> URL {
        URL(fileURLWithPath: ProcessInfo().environment["SNAPSHOT_ARTIFACTS"] ?? NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(snapshotDirectory.lastPathComponent)
    }
}
