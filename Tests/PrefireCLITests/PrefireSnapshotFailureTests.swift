import Prefire
import XCTest

final class PrefireSnapshotFailureTests: XCTestCase {
    private var snapshotDirectory: URL!
    private var artifactsDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrefireSnapshotFailureTests-\(UUID().uuidString)")
        snapshotDirectory = root.appendingPathComponent("__Snapshots__/PreviewTests.generated")
        artifactsDirectory = root.appendingPathComponent("artifacts/PreviewTests.generated")

        // A `PreviewProvider` with several unnamed previews snapshots them all under one name,
        // so SnapshotTesting tells them apart by a counter.
        try write("test_authView.1.png", "test_authView.2.png", "test_authView.3.png", to: snapshotDirectory)
        try write("test_authView.1.png", "test_authView.2.png", "test_authView.3.png", to: artifactsDirectory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: snapshotDirectory.deletingLastPathComponent().deletingLastPathComponent())
        try super.tearDownWithError()
    }

    /// The second preview of the same name must not link to the first one's images.
    func testLinksTheSnapshotTheFailureIsAbout() {
        let links = PrefireSnapshotFailure.fileLinks(
            for: defaultDiffToolFailure(for: "test_authView.2.png"),
            snapshotDirectory: snapshotDirectory,
            artifactsDirectory: artifactsDirectory
        )

        XCTAssertTrue(links.contains("reference: \(snapshotDirectory.appendingPathComponent("test_authView.2.png").absoluteString)"))
        XCTAssertTrue(links.contains("recorded:  \(artifactsDirectory.appendingPathComponent("test_authView.2.png").absoluteString)"))
        XCTAssertFalse(links.contains("test_authView.1.png"), "The first snapshot's images are a different preview")
        XCTAssertFalse(links.contains("test_authView.3.png"))
    }

    /// Every counter resolves to its own pair of images, not to the lowest one on disk.
    func testEachSnapshotOfTheSameNameResolvesToItsOwnFiles() {
        for counter in 1...3 {
            let name = "test_authView.\(counter).png"
            let links = PrefireSnapshotFailure.fileLinks(
                for: defaultDiffToolFailure(for: name),
                snapshotDirectory: snapshotDirectory,
                artifactsDirectory: artifactsDirectory
            )

            XCTAssertTrue(links.contains("reference: \(snapshotDirectory.appendingPathComponent(name).absoluteString)"), "counter \(counter)")
            XCTAssertTrue(links.contains("ksdiff \"\(snapshotDirectory.appendingPathComponent(name).path)\""), "counter \(counter)")
        }
    }

    /// `ksdiff` prints the same paths without the `file://` scheme.
    func testReadsPathsFromTheKsdiffDiffTool() {
        let reference = snapshotDirectory.appendingPathComponent("test_authView.2.png")
        let recorded = artifactsDirectory.appendingPathComponent("test_authView.2.png")
        let failure = """
        Snapshot does not match reference.

        ksdiff "\(reference.path)" "\(recorded.path)"

        Newly-taken snapshot does not match reference.
        """

        let links = PrefireSnapshotFailure.fileLinks(
            for: failure,
            snapshotDirectory: snapshotDirectory,
            artifactsDirectory: artifactsDirectory
        )

        XCTAssertTrue(links.contains("reference: \(reference.absoluteString)"))
        XCTAssertTrue(links.contains("recorded:  \(recorded.absoluteString)"))
    }

    /// A freshly recorded reference has no counterpart to diff against yet.
    func testReportsOnlyTheReferenceWhenNothingWasRecorded() {
        let reference = snapshotDirectory.appendingPathComponent("test_authView.2.png")
        let failure = """
        No reference was found on disk. Automatically recorded snapshot: …

        open "\(reference.path)"
        """

        let links = PrefireSnapshotFailure.fileLinks(
            for: failure,
            snapshotDirectory: snapshotDirectory,
            artifactsDirectory: artifactsDirectory
        )

        XCTAssertTrue(links.contains("reference: \(reference.absoluteString)"))
        XCTAssertFalse(links.contains("recorded:"))
        XCTAssertFalse(links.contains("ksdiff"))
    }

    /// Without a path to match, the folder is reported rather than a guessed file.
    func testFallsBackToTheFolderWhenTheFailureNamesNoFile() {
        let links = PrefireSnapshotFailure.fileLinks(
            for: "Snapshot does not match reference.",
            snapshotDirectory: snapshotDirectory,
            artifactsDirectory: artifactsDirectory
        )

        XCTAssertEqual(links, "\nSnapshot files: \(snapshotDirectory.absoluteString)")
    }

    func testFallsBackToTheFolderWhenItDoesNotExist() {
        let missing = snapshotDirectory.appendingPathComponent("Missing")

        let links = PrefireSnapshotFailure.fileLinks(
            for: defaultDiffToolFailure(for: "test_authView.2.png"),
            snapshotDirectory: missing,
            artifactsDirectory: artifactsDirectory
        )

        XCTAssertEqual(links, "\nSnapshot files: \(missing.absoluteString)")
    }

    // MARK: Private

    /// Failure as SnapshotTesting's default diff tool renders it.
    private func defaultDiffToolFailure(for fileName: String) -> String {
        """
        Snapshot does not match reference.

        @−
        "file://\(snapshotDirectory.appendingPathComponent(fileName).path)"
        @+
        "file://\(artifactsDirectory.appendingPathComponent(fileName).path)"

        Newly-taken snapshot does not match reference.
        """
    }

    private func write(_ fileNames: String..., to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for fileName in fileNames {
            try Data().write(to: directory.appendingPathComponent(fileName))
        }
    }
}
