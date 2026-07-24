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
            isScreen: false,
            device: DeviceConfig()
        )

        XCTAssertEqual(viewSnapshot.loadViewWithPreferences().0.frame.size, CGSize(width: 40, height: 30))
        XCTAssertNotNil(controllerSnapshot.loadViewWithPreferences().0)
        XCTAssertNotNil(PreviewModel(content: { NSView() }, name: "View"))
        XCTAssertNotNil(PreviewModel(content: { NSViewController() }, name: "Controller"))
    }
}
#endif
