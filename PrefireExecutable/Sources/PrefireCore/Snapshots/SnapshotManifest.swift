import Foundation

/// Snapshots the generated tests are expected to record.
///
/// Written next to the snapshots it describes so `prefire prune` can tell the ones that are still
/// referenced from the ones left behind by a renamed or deleted preview.
public struct SnapshotManifest: Codable, Equatable, Sendable {
    /// One `__Snapshots__/<TestFile>` folder, the unit SnapshotTesting writes into.
    public struct Directory: Codable, Equatable, Sendable {
        /// Folder SnapshotTesting derives from the generated test file.
        public var path: String
        /// Snapshots recorded in this folder, sorted by name.
        public var snapshots: [Snapshot]
        /// `false` when `snapshots` is not the whole picture: `PrefireProvider` previews take
        /// their names from `previewDisplayName` at runtime, and a custom template may record
        /// snapshots under names the parser never saw. Such folders are listed for information
        /// and never pruned.
        public var complete: Bool

        public init(path: String, snapshots: [Snapshot], complete: Bool) {
            self.path = path
            self.snapshots = snapshots
            self.complete = complete
        }
    }

    public struct Snapshot: Codable, Equatable, Sendable {
        /// `#Preview` display name.
        public var name: String
        /// File name prefix SnapshotTesting derives from `name`. A test run appends the
        /// `snapshot_devices` suffix, the `#Preview(arguments:)` argument, the accessibility
        /// marker and the `.1.png` counter to it, so the prefix identifies the whole family.
        public var stem: String
        /// `#Preview(arguments:)` expands into one snapshot per argument.
        public var parameterized: Bool

        public init(name: String, parameterized: Bool) {
            self.name = name
            stem = SnapshotManifest.sanitized(name)
            self.parameterized = parameterized
        }
    }

    /// File name of the manifest inside the generated tests folder.
    public static let fileName = "prefire-snapshots.json"
    /// Bumped whenever the layout changes in a way older `prune` builds cannot read.
    public static let currentVersion = 1

    public var version: Int
    /// `snapshot_devices` in use. Every snapshot name gains one suffix per device on iOS/tvOS.
    public var snapshotDevices: [String]
    public var directories: [Directory]

    public init(snapshotDevices: [String], directories: [Directory]) {
        version = Self.currentVersion
        self.snapshotDevices = snapshotDevices
        self.directories = directories
    }
}

public extension SnapshotManifest {
    func write(to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (encoder.encode(self) + Data("\n".utf8)).write(to: url, options: .atomic)
    }

    static func read(from path: String) throws -> SnapshotManifest {
        try JSONDecoder().decode(SnapshotManifest.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    }

    /// Mirrors SnapshotTesting's `sanitizePathComponent`, which turns a test name into a file name.
    static func sanitized(_ name: String) -> String {
        name
            .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
    }
}
