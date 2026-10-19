#if os(macOS)
import Prefire
import SwiftUI
import XCTest

@MainActor
final class SnapshotSessionTests: XCTestCase {
    func testPreviewThatIsNotWaitedOnSpendsItsDelayInTheStrategy() throws {
        let capture = try PrefireSnapshotSession().capture(snapshot { Text("Prefire").snapshot(delay: 0.3) })

        XCTAssertEqual(capture.name, "Text")
        XCTAssertEqual(capture.delay, 0.3)
        guard case let .view(size) = capture.comparison else {
            return XCTFail("Expected the view, got \(capture.comparison)")
        }
        XCTAssertNil(size)
    }

    func testPreviewThatWasWaitedOnHasSpentItsDelay() throws {
        let capture = try PrefireSnapshotSession().capture(snapshot { Text("Prefire").snapshot(delay: 0.1).snapshot(waitForIdle: true) })

        XCTAssertEqual(capture.delay, 0)
    }

    func testTimedOutWaitThrows() {
        let session = PrefireSnapshotSession(waitDefaults: SnapshotWaitDefaults(timeout: 0.2))

        XCTAssertThrowsError(try session.capture(snapshot { Text("Prefire").snapshot(waitUntil: { false }) })) { error in
            let message = (error as? SnapshotWaitTimeout)?.message ?? ""
            XCTAssertTrue(message.contains("after 0.2s"), message)
        }
    }

    func testFailuresCollectWhatVerifyReports() {
        var verified: [String] = []

        let failures = PrefireSnapshotSession().failures(of: snapshot { Text("Prefire") }) { capture in
            verified.append(capture.name)
            return "\(capture.name) differs"
        }

        XCTAssertEqual(verified, ["Text"])
        XCTAssertEqual(failures, ["Text differs"])
    }

    func testFailuresReportTimedOutWaitWithoutVerifying() {
        let session = PrefireSnapshotSession(waitDefaults: SnapshotWaitDefaults(timeout: 0.2))
        var isVerified = false

        let failures = session.failures(of: snapshot { Text("Prefire").snapshot(waitUntil: { false }) }) { _ in
            isVerified = true
            return nil
        }

        XCTAssertFalse(isVerified)
        XCTAssertEqual(failures.count, 1)
        XCTAssertTrue(failures.first?.contains("after 0.2s") == true, failures.description)
    }

    func testPassingVerifyReportsNothing() {
        XCTAssertEqual(PrefireSnapshotSession().failures(of: snapshot { Text("Prefire") }) { _ in nil }, [])
    }

    func testPreferencesArePassedOn() throws {
        let capture = try PrefireSnapshotSession().capture(snapshot {
            Text("Prefire").snapshot(precision: 0.9, perceptualPrecision: 0.8, record: true)
        })

        XCTAssertEqual(capture.precision, 0.9)
        XCTAssertEqual(capture.perceptualPrecision, 0.8)
        XCTAssertTrue(capture.record)
    }

    func testFixedLayoutSizeIsTheSnapshotSize() throws {
        let snapshot = PrefireSnapshot(
            { Text("Prefire") },
            name: "Fixed",
            isScreen: false,
            device: DeviceConfig(),
            fixedLayoutSize: CGSize(width: 40, height: 30)
        )

        let comparison = try PrefireSnapshotSession().capture(snapshot).comparison
        guard case let .view(size) = comparison else {
            return XCTFail("Expected the view, got \(comparison)")
        }
        XCTAssertEqual(size, CGSize(width: 40, height: 30))
    }

    /// macOS previews are not rendered on devices, so `snapshot_devices` does not apply.
    func testDevicesDoNotMultiplySnapshots() {
        let session = PrefireSnapshotSession(devices: ["iPhone 15", "iPad"])

        let variants = session.variants(of: snapshot { Text("Prefire") })

        XCTAssertEqual(variants.map(\.name), ["Text"])
        XCTAssertNil(DeviceConfig.named("iPhone 15"))
    }

    private func snapshot(@ViewBuilder _ view: @escaping @MainActor () -> some View) -> PrefireSnapshot<some View> {
        PrefireSnapshot(view, name: "Text", isScreen: false, device: DeviceConfig())
    }
}
#endif
