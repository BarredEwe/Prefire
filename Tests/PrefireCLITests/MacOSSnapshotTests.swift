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
            name: "SwiftUI",
            isScreen: false,
            device: DeviceConfig()
        )

        let (view, _) = snapshot.loadViewWithPreferences()

        XCTAssertNil(snapshot.device.size)
        XCTAssertGreaterThan(view.frame.width, 0)
        XCTAssertGreaterThan(view.frame.height, 0)
        XCTAssertFalse(snapshot.isScreen)
        XCTAssertNotNil(view.window)
    }

    /// Oversized content is clamped to the maximum canvas rather than collapsed to 1x1.
    func testOversizedContentIsClampedInsteadOfCollapsing() {
        let snapshot = PrefireSnapshot(
            { Text("Prefire").frame(width: 5000, height: 200) },
            name: "Oversized",
            isScreen: false,
            device: DeviceConfig()
        )

        let (view, _) = snapshot.loadViewWithPreferences()

        XCTAssertEqual(view.frame.width, 4096)
        XCTAssertEqual(view.frame.height, 200)
    }

    /// Snapshots share a single host window instead of creating one each.
    func testHostWindowIsReusedAcrossSnapshots() {
        let first = PrefireSnapshot({ Text("first") }, name: "First", isScreen: false, device: DeviceConfig())
        let second = PrefireSnapshot({ Text("second") }, name: "Second", isScreen: false, device: DeviceConfig())

        let firstWindow = first.loadViewWithPreferences().0.window
        let secondView = second.loadViewWithPreferences().0

        XCTAssertNotNil(firstWindow)
        XCTAssertTrue(firstWindow === secondView.window)
    }

    /// Backing scale is fixed rather than taken from the current display.
    func testBackingScaleIsPinnedAndConfigurable() {
        let defaultScale = PrefireSnapshot({ Text("Prefire") }, name: "Default", isScreen: false, device: DeviceConfig())
        XCTAssertEqual(defaultScale.loadViewWithPreferences().0.window?.backingScaleFactor, 2)

        let singleScale = PrefireSnapshot({ Text("Prefire") }, name: "Single", isScreen: false, device: DeviceConfig(scale: 1))
        XCTAssertEqual(singleScale.loadViewWithPreferences().0.window?.backingScaleFactor, 1)
    }

    func testPreferencesArePickedUpDuringHosting() {
        let snapshot = PrefireSnapshot(
            { Text("Prefire").snapshot(delay: 1.5, precision: 0.9, record: true) },
            name: "Preferences",
            isScreen: false,
            device: DeviceConfig()
        )

        let (_, preferences) = snapshot.loadViewWithPreferences()

        XCTAssertEqual(preferences.delay, 1.5)
        XCTAssertEqual(preferences.precision, 0.9)
        XCTAssertTrue(preferences.record)
    }

    func testSnapshotAppliesFixedLayoutSize() {
        let snapshot = PrefireSnapshot(
            { Text("Prefire") },
            name: "SwiftUI",
            isScreen: false,
            device: DeviceConfig(),
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
            isScreen: false,
            device: DeviceConfig(size: CGSize(width: 200, height: 120))
        )

        let (view, _) = snapshot.loadViewWithPreferences()

        XCTAssertEqual(view.frame.size, CGSize(width: 200, height: 120))
        XCTAssertNotNil(view.window)
        XCTAssertTrue(view.wantsLayer)
    }

    func testPreviewProviderFixedLayoutSetsDeviceSize() {
        let preview = FixedLayout_Previews._allPreviews[0]
        let snapshot = PrefireSnapshot(preview, device: DeviceConfig())

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
        XCTAssertEqual(viewSnapshot.loadViewWithPreferences().0.frame.size, CGSize(width: 40, height: 30))

        let controllerSnapshot = PrefireSnapshot(
            { NSViewController() },
            name: "Controller",
            isScreen: false,
            device: DeviceConfig()
        )
        let controllerView = controllerSnapshot.loadViewWithPreferences().0
        XCTAssertLessThanOrEqual(controllerView.frame.width, 4096)
        XCTAssertLessThanOrEqual(controllerView.frame.height, 4096)

        XCTAssertNotNil(ViewRepresentable(view: NSView()))
        XCTAssertNotNil(ViewControllerRepresentable(viewController: NSViewController()))
        XCTAssertNotNil(PreviewModel(content: { NSView() }, name: "View"))
        XCTAssertNotNil(PreviewModel(content: { NSViewController() }, name: "Controller"))
        XCTAssertNotNil(UnqualifiedNSViewRepresentable())
    }

    func testGlobalConfigurationWrapsSnapshotContent() {
        let snapshot = PrefireSnapshot(
            { Text("Prefire") },
            name: "Wrapped",
            isScreen: false,
            device: DeviceConfig(),
            globalConfiguration: SizedConfiguration.self
        )

        let (view, _) = snapshot.loadViewWithPreferences()

        XCTAssertEqual(view.frame.size, CGSize(width: 120, height: 60))
    }

    /// The wrapper is applied inside the preference readers, so preview preferences still arrive.
    func testGlobalConfigurationKeepsPreferences() {
        let snapshot = PrefireSnapshot(
            { Text("Prefire").snapshot(delay: 1.5, precision: 0.9, record: true) },
            name: "WrappedPreferences",
            isScreen: false,
            device: DeviceConfig(),
            globalConfiguration: SizedConfiguration.self
        )

        let (_, preferences) = snapshot.loadViewWithPreferences()

        XCTAssertEqual(preferences.delay, 1.5)
        XCTAssertEqual(preferences.precision, 0.9)
        XCTAssertTrue(preferences.record)
    }

    /// The default implementation returns the view untouched.
    func testDefaultGlobalConfigurationDoesNotChangeContent() {
        let plain = PrefireSnapshot({ Text("Prefire") }, name: "Plain", isScreen: false, device: DeviceConfig())
        let configured = PrefireSnapshot(
            { Text("Prefire") },
            name: "Configured",
            isScreen: false,
            device: DeviceConfig(),
            globalConfiguration: EmptyConfiguration.self
        )

        XCTAssertEqual(plain.loadViewWithPreferences().0.frame.size, configured.loadViewWithPreferences().0.frame.size)
    }
}

private enum SizedConfiguration: PrefireGlobalConfiguration {
    static func wrap(_ view: AnyView) -> AnyView {
        AnyView(view.frame(width: 120, height: 60))
    }
}

private enum EmptyConfiguration: PrefireGlobalConfiguration {}

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
