import Foundation
import PathKit
@testable import PrefireCore
import XCTest

final class SnapshotPrunerTests: XCTestCase {
    private var root: Path!
    private var snapshots: Path!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = Path(NSTemporaryDirectory()) + "prefire-prune-\(UUID().uuidString)"
        snapshots = root + "__Snapshots__" + "PreviewTests.generated"
        try snapshots.mkpath()
    }

    override func tearDownWithError() throws {
        try? root.delete()
        try super.tearDownWithError()
    }

    private func write(_ names: [String], into directory: Path? = nil) throws {
        for name in names {
            try ((directory ?? snapshots) + name).write("snapshot")
        }
    }

    private func manifest(_ names: [String], directory: Path? = nil, complete: Bool = true) -> SnapshotManifest {
        SnapshotManifest(
            snapshotDevices: [],
            directories: [
                .init(
                    path: (directory ?? snapshots).string,
                    snapshots: names.map({ .init(name: $0, parameterized: false) }),
                    complete: complete
                )
            ]
        )
    }

    func test_orphans_keepsEveryVariantOfAnExpectedSnapshot() throws {
        try write([
            "AuthView.1.png",
            "AuthView-iPhone-15.1.png",
            "AuthView-accessibility.1.png",
            "TextView-1-A.1.png",
            "TextView-2-B.1.png",
            "RemovedView.1.png",
        ])

        let orphans = SnapshotPruner.orphans(for: manifest(["AuthView", "TextView"]))

        XCTAssertEqual(orphans, [(snapshots + "RemovedView.1.png").string])
    }

    func test_orphans_ignoresNonImageAndHiddenFiles() throws {
        try write(["Stale.1.png", "README.md", "notes.txt", ".gitkeep", ".DS_Store"])

        let orphans = SnapshotPruner.orphans(for: manifest(["Kept"]))

        XCTAssertEqual(orphans, [(snapshots + "Stale.1.png").string])
    }

    /// `PrefireProvider` previews name their snapshots at runtime, so nothing in such a folder
    /// can be proven unused.
    func test_orphans_skipsIncompleteDirectories() throws {
        try write(["Stale.1.png"])

        XCTAssertTrue(SnapshotPruner.orphans(for: manifest(["Kept"], complete: false)).isEmpty)
    }

    func test_orphans_skipsDirectoriesOutsideSnapshotsFolder() throws {
        let outside = root + "Resources"
        try outside.mkpath()
        try write(["Stale.1.png"], into: outside)

        XCTAssertTrue(SnapshotPruner.orphans(for: manifest(["Kept"], directory: outside)).isEmpty)
    }

    func test_orphans_reportsNothingWhenFolderIsMissing() {
        let missing = root + "__Snapshots__" + "MissingTests.generated"

        XCTAssertTrue(SnapshotPruner.orphans(for: manifest(["Kept"], directory: missing)).isEmpty)
    }

    func test_delete_removesOnlyTheReportedSnapshots() throws {
        try write(["AuthView.1.png", "Stale.1.png"])

        let deleted = try SnapshotPruner.delete(SnapshotPruner.orphans(for: manifest(["AuthView"])))

        XCTAssertEqual(deleted, [(snapshots + "Stale.1.png").string])
        XCTAssertTrue((snapshots + "AuthView.1.png").exists)
        XCTAssertFalse((snapshots + "Stale.1.png").exists)
    }

    /// A hand-edited or stale path must not become a way to delete arbitrary files.
    func test_delete_refusesPathsOutsideSnapshotFolders() throws {
        let outside = root + "important.png"
        try outside.write("data")

        XCTAssertTrue(try SnapshotPruner.delete([outside.string]).isEmpty)
        XCTAssertTrue(outside.exists)
    }

    func test_delete_refusesNonImageFiles() throws {
        let source = snapshots + "Stale.swift"
        try source.write("code")

        XCTAssertTrue(try SnapshotPruner.delete([source.string]).isEmpty)
        XCTAssertTrue(source.exists)
    }
}
