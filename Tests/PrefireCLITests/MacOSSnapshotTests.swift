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

    /// Variants are applied through the SwiftUI environment while hosting.
    ///
    /// Only the probed flag is asserted: the rest of the environment comes from the host machine.
    func testVariantIsAppliedToTheHostedView() {
        func flags(for variant: SnapshotVariant?) -> Int {
            var snapshot = PrefireSnapshot({ VariantProbe() }, name: "Variant", isScreen: false, device: DeviceConfig())
            snapshot.variant = variant
            return Int(snapshot.loadViewWithPreferences().0.frame.width - VariantProbe.baseWidth)
        }

        XCTAssertEqual(flags(for: .light) & VariantProbe.dark, 0)
        XCTAssertEqual(flags(for: .dark) & VariantProbe.dark, VariantProbe.dark)
        XCTAssertEqual(flags(for: .rightToLeft) & VariantProbe.rightToLeft, VariantProbe.rightToLeft)
        XCTAssertEqual(
            flags(for: .sizeCategory(.accessibilityExtraExtraExtraLarge)) & VariantProbe.sizeCategory,
            VariantProbe.sizeCategory
        )
        XCTAssertEqual(flags(for: .locale(VariantProbe.probedLocale)) & VariantProbe.locale, VariantProbe.locale)
        XCTAssertEqual(flags(for: .locale(Locale(identifier: "en_US"))) & VariantProbe.locale, 0)
    }

    func testSnapshotVariantsModifierIsPickedUpDuringHosting() {
        let snapshot = PrefireSnapshot(
            { Text("Prefire").snapshotVariants([.light, .dark]) },
            name: "Variants",
            isScreen: false,
            device: DeviceConfig()
        )

        let (_, preferences) = snapshot.loadViewWithPreferences()

        XCTAssertEqual(preferences.variants, [.light, .dark])
    }

    func testWithoutModifierNoVariantsAreRequested() {
        let snapshot = PrefireSnapshot({ Text("Prefire") }, name: "Plain", isScreen: false, device: DeviceConfig())

        let (_, preferences) = snapshot.loadViewWithPreferences()

        XCTAssertNil(preferences.variants)
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
}

/// Reports the environment it was rendered with as a bit mask encoded in its own width.
private struct VariantProbe: View {
    static let baseWidth: CGFloat = 100
    static let dark = 1
    static let rightToLeft = 2
    static let sizeCategory = 4
    static let locale = 8

    static let probedLocale = Locale(identifier: "th_TH")

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.locale) private var locale

    var body: some View {
        Color.clear.frame(width: Self.baseWidth + CGFloat(flags), height: 10)
    }

    private var flags: Int {
        var flags = 0
        if colorScheme == .dark { flags |= Self.dark }
        if layoutDirection == .rightToLeft { flags |= Self.rightToLeft }
        if sizeCategory == .accessibilityExtraExtraExtraLarge { flags |= Self.sizeCategory }
        if locale.identifier == Self.probedLocale.identifier { flags |= Self.locale }
        return flags
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
