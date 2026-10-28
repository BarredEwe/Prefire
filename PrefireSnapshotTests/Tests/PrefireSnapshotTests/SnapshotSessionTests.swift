#if os(iOS)
import Prefire
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@MainActor
final class SnapshotSessionTests: XCTestCase {
    /// Devices keep the canvases of SnapshotTesting's presets, so recorded references stay valid.
    func testDevicesMatchSnapshotTestingPresets() {
        let presets: [(String, ViewImageConfig)] = [
            ("iPhone X", .iPhoneX),
            ("iPhone 16", .iPhoneX),
            ("iPhone 15 Pro", .iPhone13Pro),
            ("iPhone 16e", .iPhone13),
            ("iPhone 16 Pro Max", .iPhone13ProMax),
            ("iPhone 8", .iPhone8),
            ("iPhone 8 Plus", .iPhone8Plus),
            ("iPhone SE (1st generation)", .iPhoneSe),
            ("iPad", .iPad10_2),
            ("iPad Mini", .iPadMini),
            ("iPad Pro 11", .iPadPro11),
            ("iPad Pro 12.9", .iPadPro12_9),
        ]

        for (name, preset) in presets {
            assertDevice(DeviceConfig.named(name), matches: preset, name)
        }
        assertDevice(DeviceConfig.defaultSnapshotDevice, matches: .iPhoneX, "default")
    }

    func testDevicesOfNewerPhonesUsePhoneTraits() throws {
        let device = try XCTUnwrap(DeviceConfig.named("iPhone 17 Pro"))

        XCTAssertEqual(device.size, CGSize(width: 402, height: 874))
        XCTAssertEqual(device.safeArea, UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0))
        XCTAssertTrue(sameTraits(device.traits, UITraitCollection.iPhone13(.portrait)))
    }

    func testUnknownDeviceHasNoConfig() {
        XCTAssertNil(DeviceConfig.named("Nokia 3310"))
        XCTAssertTrue(DeviceConfig.supportedNames.contains("iPhone 15"))
    }

    func testVariantsAreNamedAfterTheirDevices() {
        let session = PrefireSnapshotSession(devices: ["iPhone 15", "iPad"])
        let snapshot = PrefireSnapshot({ Text("Prefire") }, name: "Text", isScreen: true, device: session.device)

        let variants = session.variants(of: snapshot)

        XCTAssertEqual(variants.map(\.name), ["Text-iPhone 15", "Text-iPad"])
        XCTAssertEqual(variants.map(\.device.size), [ViewImageConfig.iPhoneX.size, ViewImageConfig.iPad10_2.size])
        XCTAssertEqual(variants.map(\.device.safeArea), [.zero, .zero])
        XCTAssertEqual(variants.map(\.traits.displayScale), [2, 2])
    }

    func testWithoutDevicesTheSnapshotIsTakenOnce() {
        let snapshot = PrefireSnapshot({ Text("Prefire") }, name: "Text", isScreen: true, device: .defaultSnapshotDevice)

        XCTAssertEqual(PrefireSnapshotSession().variants(of: snapshot).map(\.name), ["Text"])
    }

    func testVariantsAreCapturedOnTheirDevices() {
        let session = PrefireSnapshotSession(devices: ["iPhone 15", "iPad"])
        let snapshot = PrefireSnapshot({ Text("Prefire") }, name: "Text", isScreen: true, device: session.device)
        var sizes: [CGSize?] = []

        let failures = session.failures(of: snapshot) { capture in
            if case let .view(layout) = capture.comparison {
                sizes.append(layout?.size)
            }
            return nil
        }

        XCTAssertEqual(failures, [])
        XCTAssertEqual(sizes, [ViewImageConfig.iPhoneX.size, ViewImageConfig.iPad10_2.size])
    }

    func testPreviewDeviceIsUsedForProviderPreviews() throws {
        let preview = try XCTUnwrap(DevicePreview_Previews._allPreviews.first)

        let snapshot = PrefireSnapshotSession().snapshot(of: preview)

        XCTAssertEqual(snapshot.device.size, ViewImageConfig.iPhone8.size)
    }

    func testScreenIsSnapshottedOnItsDeviceAndComponentAtTheSizeThatFits() throws {
        let session = PrefireSnapshotSession()

        let screen = try session.capture(PrefireSnapshot({ Text("Prefire") }, name: "Screen", isScreen: true, device: session.device))
        let component = try session.capture(PrefireSnapshot({ Text("Prefire") }, name: "Component", isScreen: false, device: session.device))

        guard case let .view(screenLayout) = screen.comparison, case let .view(componentLayout) = component.comparison else {
            return XCTFail("Expected views, got \(screen.comparison) and \(component.comparison)")
        }
        XCTAssertEqual(screenLayout?.size, session.device.size)
        XCTAssertNil(componentLayout)
    }

    func testSettledPreviewIsComparedAsCaptured() throws {
        let session = PrefireSnapshotSession()
        let snapshot = PrefireSnapshot({ Text("Prefire").snapshot(waitForIdle: true) }, name: "Settled", isScreen: true, device: session.device)

        guard case let .image(image) = try session.capture(snapshot).comparison else {
            return XCTFail("Expected the captured image")
        }
        XCTAssertEqual(image.size, session.device.size)
    }

    func testAccessibilitySnapshotOfFullPageFollowsTheContent() throws {
        let session = PrefireSnapshotSession(fullPage: true)
        let snapshot = PrefireSnapshot(
            {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(0..<40) { Text("Row \($0)").frame(height: 50) }
                    }
                }
            },
            name: "Rows",
            isScreen: true,
            device: session.device
        )

        let capture = try session.capture(snapshot)

        guard case let .view(layout) = capture.comparison, let height = layout?.size?.height else {
            return XCTFail("Expected the view on a device, got \(capture.comparison)")
        }
        XCTAssertGreaterThan(height, session.device.size?.height ?? 0)
        XCTAssertEqual(capture.accessibilityController().view.frame.height, height)
    }

    func testVoiceOverIsReadInAWindowOnceTwoReadsAgree() throws {
        let session = PrefireSnapshotSession()
        let capture = try session.capture(PrefireSnapshot({ Text("Prefire") }, name: "Text", isScreen: true, device: session.device))
        var reads = 0

        let value = try capture.readVoiceOver { view in
            XCTAssertNotNil(view.window)
            reads += 1
            return min(reads, 3)
        }

        XCTAssertEqual(value, 3)
        XCTAssertEqual(reads, 4)
    }

    func testVoiceOverReadThatNeverSettlesFails() throws {
        let session = PrefireSnapshotSession()
        let capture = try session.capture(PrefireSnapshot({ Text("Prefire") }, name: "Text", isScreen: true, device: session.device))
        var reads = 0

        XCTAssertThrowsError(try capture.readVoiceOver(timeout: 0.2) { _ in
            reads += 1
            return reads
        }) { error in
            XCTAssertTrue("\(error)".contains("snapshot_wait_timeout"), "\(error)")
        }
        XCTAssertGreaterThan(reads, 1)
    }

    // MARK: Private

    private func assertDevice(_ device: DeviceConfig?, matches preset: ViewImageConfig, _ name: String, line: UInt = #line) {
        guard let device else {
            return XCTFail("No device named \(name)", line: line)
        }
        XCTAssertEqual(device.size, preset.size, name, line: line)
        XCTAssertEqual(device.safeArea, preset.safeArea, name, line: line)
        XCTAssertTrue(sameTraits(device.traits, preset.traits), name, line: line)
    }

    private func sameTraits(_ lhs: UITraitCollection, _ rhs: UITraitCollection) -> Bool {
        lhs.containsTraits(in: rhs) && rhs.containsTraits(in: lhs)
    }
}

private struct DevicePreview_Previews: PreviewProvider {
    static var previews: some View {
        Text("Prefire")
            .previewDevice("iPhone 8")
    }
}
#endif
