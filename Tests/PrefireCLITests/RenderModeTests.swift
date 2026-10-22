#if os(macOS)
import Prefire
import SwiftUI
import XCTest

@MainActor
final class RenderModeTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("PrefireRender-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
        try await super.tearDown()
    }

    func testOptionsAreReadFromTheEnvironment() throws {
        let options = PrefireRenderOptions(directory: "/tmp/out", runID: "run", previews: ["Button"], colorScheme: "dark")
        let json = String(decoding: try JSONEncoder().encode(options), as: UTF8.self)

        XCTAssertEqual(PrefireRenderOptions.fromEnvironment([PrefireRenderOptions.environmentKey: json]), options)
        XCTAssertNil(PrefireRenderOptions.fromEnvironment([:]))
        XCTAssertNil(PrefireRenderOptions.fromEnvironment([PrefireRenderOptions.environmentKey: "not json"]))
    }

    func testPreviewsAreMatchedByNameAndArgumentSuffix() {
        let options = PrefireRenderOptions(directory: "", previews: ["Button"])

        XCTAssertTrue(options.includes("Button"))
        XCTAssertTrue(options.includes("Button-1-primary"))
        XCTAssertFalse(options.includes("ButtonRow"))
        XCTAssertTrue(PrefireRenderOptions(directory: "").includes("Anything"))
    }

    func testRenderWritesImageAndRecordInsteadOfVerifying() throws {
        let session = PrefireSnapshotSession(render: PrefireRenderOptions(directory: directory.path, runID: "run", colorScheme: "dark"))
        var isVerified = false

        let failures = session.failures(of: snapshot {
            Text("Prefire").previewUserStory("Auth").previewState("Empty")
        }) { _ in
            isVerified = true
            return "verified"
        }

        XCTAssertEqual(failures, [])
        XCTAssertFalse(isVerified)

        let record = try self.record(named: "Text")
        XCTAssertEqual(record.runID, "run")
        XCTAssertEqual(record.image, "Text.png")
        XCTAssertEqual(record.colorScheme, "dark")
        XCTAssertEqual(record.userStory, "Auth")
        XCTAssertEqual(record.state, "Empty")
        XCTAssertGreaterThan(record.width, 0)
        XCTAssertEqual(record.scale, 2)
        XCTAssertNil(record.error)

        let image = try XCTUnwrap(NSImage(contentsOf: directory.appendingPathComponent("Text.png")))
        XCTAssertGreaterThan(image.size.width, 0)
    }

    func testPreviewsThatAreNotAskedForAreSkipped() {
        let session = PrefireSnapshotSession(render: PrefireRenderOptions(directory: directory.path, previews: ["Other"]))

        XCTAssertEqual(session.failures(of: snapshot { Text("Prefire") }) { _ in "verified" }, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Text.json").path))
    }

    func testPreviewsNamedAlikeAreBothKept() throws {
        let session = PrefireSnapshotSession(render: PrefireRenderOptions(directory: directory.path, runID: "run"))

        _ = session.failures(of: snapshot { Text("First") }) { _ in nil }
        _ = session.failures(of: snapshot { Text("Second") }) { _ in nil }

        XCTAssertEqual(try record(named: "Text").image, "Text.png")
        XCTAssertEqual(try record(named: "Text-2").image, "Text-2.png")
    }

    func testTimedOutWaitIsRecordedAndReported() throws {
        let session = PrefireSnapshotSession(
            waitDefaults: SnapshotWaitDefaults(timeout: 0.2),
            render: PrefireRenderOptions(directory: directory.path, runID: "run")
        )

        let failures = session.failures(of: snapshot { Text("Prefire").snapshot(waitUntil: { false }) }) { _ in nil }

        XCTAssertEqual(failures.count, 1)
        let record = try self.record(named: "Text")
        XCTAssertNil(record.image)
        XCTAssertEqual(record.error, failures.first)
    }

    func testFileNamesKeepOnlySafeCharacters() {
        let session = PrefireSnapshotSession(render: PrefireRenderOptions(directory: directory.path, runID: "run"))

        _ = session.failures(of: PrefireSnapshot({ Text("Prefire") }, name: "Sign in / Error", isScreen: false, device: DeviceConfig())) { _ in nil }

        XCTAssertEqual(try record(named: "Sign_in___Error").name, "Sign in / Error")
    }

    private func record(named baseName: String) throws -> PrefireRenderRecord {
        let data = try Data(contentsOf: directory.appendingPathComponent(baseName + ".json"))
        return try JSONDecoder().decode(PrefireRenderRecord.self, from: data)
    }

    private func snapshot(@ViewBuilder _ view: @escaping @MainActor () -> some View) -> PrefireSnapshot<some View> {
        PrefireSnapshot(view, name: "Text", isScreen: false, device: DeviceConfig())
    }
}
#endif
