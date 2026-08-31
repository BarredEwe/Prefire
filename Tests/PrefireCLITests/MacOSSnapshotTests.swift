#if os(macOS)
import AppKit
import Prefire
import SwiftUI
import XCTest

@MainActor
final class MacOSSnapshotTests: XCTestCase {
    func testSwiftUISnapshotUsesExplicitSize() {
        let snapshot = PrefireSnapshot(
            { Text("Prefire") },
            name: "SwiftUI",
            isScreen: false,
            device: DeviceConfig(size: CGSize(width: 320, height: 180))
        )

        let (view, _) = snapshot.loadViewWithPreferences()

        XCTAssertEqual(view.frame.size, CGSize(width: 320, height: 180))
        XCTAssertNotNil(view.window)
    }

    func testSwiftUISnapshotWithoutSizeUsesFittingSize() {
        let snapshot = PrefireSnapshot(
            { Text("Prefire") },
            name: "SwiftUI"
        )

        let (view, _) = snapshot.loadViewWithPreferences()

        XCTAssertNil(snapshot.device.size)
        XCTAssertGreaterThan(view.frame.width, 0)
        XCTAssertGreaterThan(view.frame.height, 0)
        XCTAssertFalse(snapshot.isScreen)
        XCTAssertNotNil(view.window)
    }

    func testSnapshotAppliesFixedLayoutSize() {
        let snapshot = PrefireSnapshot(
            { Text("Prefire") },
            name: "SwiftUI",
            fixedLayoutSize: CGSize(width: 320, height: 180)
        )

        XCTAssertEqual(snapshot.device.size, CGSize(width: 320, height: 180))
    }

    func testRotation3DEffectHostsWithoutCrashing() {
        let snapshot = PrefireSnapshot(
            {
                Text("Prefire")
                    .rotation3DEffect(.degrees(45), axis: (x: 1, y: 0, z: 0))
            },
            name: "Rotated",
            device: DeviceConfig(size: CGSize(width: 200, height: 120))
        )

        let (view, _) = snapshot.loadViewWithPreferences()

        XCTAssertEqual(view.frame.size, CGSize(width: 200, height: 120))
        XCTAssertNotNil(view.window)
        XCTAssertTrue(view.wantsLayer)
    }

    func testPreviewProviderFixedLayoutSetsDeviceSize() {
        let preview = FixedLayout_Previews._allPreviews[0]
        let snapshot = PrefireSnapshot(preview)

        XCTAssertEqual(snapshot.device.size, CGSize(width: 200, height: 100))
        XCTAssertFalse(snapshot.isScreen)
    }

    func testAppKitViewAndControllerOverloadsAreAvailable() {
        let viewSnapshot = PrefireSnapshot(
            { NSView(frame: CGRect(x: 0, y: 0, width: 40, height: 30)) },
            name: "View",
            isScreen: false,
            device: DeviceConfig(size: CGSize(width: 40, height: 30))
        )
        let controllerSnapshot = PrefireSnapshot(
            { NSViewController() },
            name: "Controller",
            isScreen: false
        )

        XCTAssertEqual(viewSnapshot.loadViewWithPreferences().0.frame.size, CGSize(width: 40, height: 30))
        XCTAssertNotNil(controllerSnapshot.loadViewWithPreferences().0)
        XCTAssertLessThanOrEqual(controllerSnapshot.loadViewWithPreferences().0.frame.width, 4096)
        XCTAssertLessThanOrEqual(controllerSnapshot.loadViewWithPreferences().0.frame.height, 4096)
        XCTAssertNotNil(ViewRepresentable(view: NSView()))
        XCTAssertNotNil(ViewControllerRepresentable(viewController: NSViewController()))
        XCTAssertNotNil(PreviewModel(content: { NSView() }, name: "View"))
        XCTAssertNotNil(PreviewModel(content: { NSViewController() }, name: "Controller"))
        XCTAssertNotNil(UnqualifiedNSViewRepresentable())
    }
}

private struct FixedLayout_Previews: PreviewProvider {
    static var previews: some View {
        Text("Prefire")
            .previewLayout(.fixed(width: 200, height: 100))
    }
}

/// Compiles only when Prefire does not ship a colliding `NSViewRepresentable` type.
private struct UnqualifiedNSViewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
