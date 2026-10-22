#if os(iOS)
import Prefire
import SwiftUI
import UIKit
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

    /// Devices `prefire render` asks for replace `snapshot_devices`, and are rendered with their safe area.
    func testScreenIsRenderedOnTheDevicesAskedFor() throws {
        let session = PrefireSnapshotSession(
            devices: ["iPhone 8"],
            render: PrefireRenderOptions(directory: directory.path, runID: "run", devices: ["iPhone 15", "iPad"], colorScheme: "dark")
        )
        let snapshot = PrefireSnapshot({ Color.blue.previewState("Blue") }, name: "Screen", isScreen: true, device: session.device)

        XCTAssertEqual(session.failures(of: snapshot) { _ in "verified" }, [])

        let phone = try record(named: "Screen-iPhone 15")
        XCTAssertEqual(phone.device, "iPhone 15")
        XCTAssertEqual(phone.width, 375)
        XCTAssertEqual(phone.height, 812)
        XCTAssertGreaterThan(phone.scale, 0)
        XCTAssertTrue(phone.isScreen)
        XCTAssertEqual(phone.state, "Blue")
        XCTAssertEqual(phone.colorScheme, "dark")

        let image = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent(try XCTUnwrap(phone.image)).path))
        XCTAssertEqual(Double(image.size.width * image.scale), 375 * phone.scale)

        XCTAssertEqual(try record(named: "Screen-iPad").device, "iPad")
    }

    func testComponentIsRenderedAtTheSizeThatFits() throws {
        let session = PrefireSnapshotSession(render: PrefireRenderOptions(directory: directory.path, runID: "run"))
        let snapshot = PrefireSnapshot({ Color.red.frame(height: 40) }, name: "Component", isScreen: false, device: session.device)

        XCTAssertEqual(session.failures(of: snapshot) { _ in "verified" }, [])

        let record = try record(named: "Component")
        XCTAssertEqual(record.width, 375)
        XCTAssertEqual(record.height, 40)
        XCTAssertNil(record.device)
    }

    func testDarkColorSchemeReachesThePreview() throws {
        let session = PrefireSnapshotSession(render: PrefireRenderOptions(directory: directory.path, runID: "run", colorScheme: "dark"))
        let snapshot = PrefireSnapshot({ ColorSchemeProbe() }, name: "Probe", isScreen: false, device: session.device)

        _ = session.failures(of: snapshot) { _ in nil }

        XCTAssertEqual(try record(named: "Probe").state, "dark")
    }

    private func record(named baseName: String) throws -> PrefireRenderRecord {
        let fileName = baseName.replacingOccurrences(of: " ", with: "_")
        let data = try Data(contentsOf: directory.appendingPathComponent(fileName + ".json"))
        return try JSONDecoder().decode(PrefireRenderRecord.self, from: data)
    }
}

/// Reports the color scheme it is rendered with as its state.
private struct ColorSchemeProbe: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("Probe").previewState(colorScheme == .dark ? "dark" : "light")
    }
}
#endif
