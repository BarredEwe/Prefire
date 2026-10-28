#if os(iOS)
@testable import Prefire
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class VoiceOverReferenceNameTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
        try await super.tearDown()
    }

    func testImageWithoutReferencesIsRecordedUnderTheNewName() throws {
        XCTAssertEqual(try capture().voiceOverImageTestName(filePath: file), "Card.voiceover.image")
    }

    func testImageWithOnlyNewReferencesKeepsTheNewName() throws {
        try record("Card-voiceover-image.1.png")

        XCTAssertEqual(try capture().voiceOverImageTestName(filePath: file), "Card.voiceover.image")
    }

    func testImageWithOnlyOldReferencesIsComparedWithThem() throws {
        try record("Card-accessibility.1.png", "Card-accessibility.2.png")

        XCTAssertEqual(try capture().voiceOverImageTestName(filePath: file), "Card.accessibility")
    }

    func testImageWithBothNamesTakesTheNewOne() throws {
        try record("Card-accessibility.1.png", "Card-voiceover-image.1.png")

        XCTAssertEqual(try capture().voiceOverImageTestName(filePath: file), "Card.voiceover.image")
    }

    func testOldReferencesOfAnotherPreviewDoNotCount() throws {
        try record("CardList-accessibility.1.png")

        XCTAssertEqual(try capture().voiceOverImageTestName(filePath: file), "Card.voiceover.image")
    }

    /// SnapshotTesting numbers references per test name, so the text keeps its number with or without
    /// an image before it.
    func testTextIsNumberedTheSameWithAndWithoutTheImage() throws {
        let capture = try capture()

        verify(capture.voiceOverTextTestName)
        verify(capture.voiceOverImageTestName(filePath: file))
        verify(capture.voiceOverTextTestName)

        let files = try FileManager.default.contentsOfDirectory(atPath: snapshots.path).sorted()
        XCTAssertEqual(files, [
            "Card-voiceover-image.1.txt",
            "Card-voiceover-text.1.txt",
            "Card-voiceover-text.2.txt"
        ])
    }

    // MARK: Private

    /// Generated tests file the references are recorded next to.
    private var file: String {
        directory.appendingPathComponent("PreviewTests.swift").path
    }

    private var snapshots: URL {
        directory.appendingPathComponent("__Snapshots__").appendingPathComponent("PreviewTests")
    }

    private func capture() throws -> PrefireSnapshotCapture {
        let session = PrefireSnapshotSession()
        let snapshot = PrefireSnapshot({ Text("Card") }, name: "Card", isScreen: true, device: session.device)
        return try session.capture(snapshot)
    }

    private func record(_ names: String...) throws {
        for name in names {
            try Data().write(to: snapshots.appendingPathComponent(name))
        }
    }

    private func verify(_ testName: String) {
        _ = verifySnapshot(
            of: "VoiceOver",
            as: .lines,
            record: .all,
            snapshotDirectory: snapshots.path,
            testName: testName
        )
    }
}
#endif
