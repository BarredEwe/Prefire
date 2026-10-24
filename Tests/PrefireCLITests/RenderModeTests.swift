#if os(macOS)
import Prefire
import SpriteKit
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

    func testPreviewsThatAreNotAskedForAreSkipped() throws {
        let session = PrefireSnapshotSession(render: PrefireRenderOptions(directory: directory.path, runID: "run", previews: ["Other"]))

        XCTAssertEqual(session.failures(of: snapshot { Text("Prefire") }) { _ in "verified" }, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Text.json").path))

        // `prefire render` tells a run that matched nothing from tests that ignore render mode by it.
        let marker = directory.appendingPathComponent(PrefireRenderOptions.runMarkerFileName)
        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "run")
    }

    func testProviderIsAskedForByItsTest() throws {
        let session = PrefireSnapshotSession(render: PrefireRenderOptions(directory: directory.path, runID: "run", previews: ["test_card"]))

        for preview in Card_Previews._allPreviews {
            _ = session.failures(of: session.snapshot(of: preview, testName: "test_card()")) { _ in nil }
        }

        XCTAssertEqual(try record(named: "Card").name, "Card")
    }

    func testSpriteKitIsRendered() throws {
        let session = PrefireSnapshotSession(render: PrefireRenderOptions(directory: directory.path, runID: "run"))

        _ = session.failures(of: snapshot { SpriteKitView().frame(width: 40, height: 40) }) { _ in nil }

        let image = try XCTUnwrap(NSImage(contentsOf: directory.appendingPathComponent("Text.png")))
        let bitmap = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)
        let color = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
        // SpriteKit draws in the color space of the display, so red is not quite pure.
        XCTAssertGreaterThan(color.redComponent, 0.8)
        XCTAssertLessThan(color.greenComponent, 0.3)
        XCTAssertLessThan(color.blueComponent, 0.3)
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

    func testImageOfAnEarlierRunGoes_whenThePreviewNoLongerRenders() throws {
        _ = PrefireSnapshotSession(render: PrefireRenderOptions(directory: directory.path, runID: "earlier"))
            .failures(of: snapshot { Text("Prefire") }) { _ in nil }
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Text.png").path))

        let session = PrefireSnapshotSession(
            waitDefaults: SnapshotWaitDefaults(timeout: 0.2),
            render: PrefireRenderOptions(directory: directory.path, runID: "now")
        )
        _ = session.failures(of: snapshot { Text("Prefire").snapshot(waitUntil: { false }) }) { _ in nil }

        XCTAssertNil(try record(named: "Text").image)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Text.png").path))
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

private struct Card_Previews: PreviewProvider {
    static var previews: some View {
        Text("Card").previewDisplayName("Card")
    }
}

/// An `SKView` showing a red scene, which `cacheDisplay` alone draws blank.
private struct SpriteKitView: NSViewRepresentable {
    func makeNSView(context: Context) -> SKView {
        let scene = SKScene(size: CGSize(width: 40, height: 40))
        scene.backgroundColor = .red
        let view = SKView()
        view.presentScene(scene)
        return view
    }

    func updateNSView(_ nsView: SKView, context: Context) {}
}
#endif
