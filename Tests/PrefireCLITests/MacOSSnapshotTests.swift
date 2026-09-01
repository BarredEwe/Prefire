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

    // MARK: - Masking

    /// Masked content is replaced by a placeholder, so unstable values snapshot identically.
    func testMaskedContentRendersIdenticallyForDifferentValues() throws {
        let first = try snapshotImageData(of: unstableRow(value: "2024-01-01 10:00", masked: true))
        let second = try snapshotImageData(of: unstableRow(value: "1999-12-31 23:59", masked: true))

        XCTAssertEqual(first, second)
    }

    /// The same views without the modifier differ — the equality above comes from masking.
    func testUnmaskedContentRendersDifferentlyForDifferentValues() throws {
        let first = try snapshotImageData(of: unstableRow(value: "2024-01-01 10:00", masked: false))
        let second = try snapshotImageData(of: unstableRow(value: "1999-12-31 23:59", masked: false))

        XCTAssertNotEqual(first, second)
    }

    /// The placeholder is really drawn: the masked area is filled with the mask color.
    func testMaskDrawsOpaquePlaceholder() throws {
        let bitmap = try snapshotBitmap(of: unstableRow(value: "2024-01-01 10:00", masked: true))
        let center = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
        let expected = try XCTUnwrap(NSColor(Color.prefireSnapshotMask).usingColorSpace(.sRGB))
        let rendered = try XCTUnwrap(center.usingColorSpace(.sRGB))

        XCTAssertEqual(rendered.redComponent, expected.redComponent, accuracy: 0.01)
        XCTAssertEqual(rendered.greenComponent, expected.greenComponent, accuracy: 0.01)
        XCTAssertEqual(rendered.blueComponent, expected.blueComponent, accuracy: 0.01)
        XCTAssertEqual(rendered.alphaComponent, 1, accuracy: 0.01)
    }

    /// Masking keeps the view laid out, so nothing around it moves.
    func testMaskingKeepsLayoutSize() {
        let masked = PrefireSnapshot(
            { HStack { Text("Updated").snapshotMasked() }.padding(8) },
            name: "Masked",
            isScreen: false,
            device: DeviceConfig()
        )
        let plain = PrefireSnapshot(
            { HStack { Text("Updated") }.padding(8) },
            name: "Plain",
            isScreen: false,
            device: DeviceConfig()
        )

        let maskedSize = masked.loadViewWithPreferences().0.frame.size
        let plainSize = plain.loadViewWithPreferences().0.frame.size

        XCTAssertEqual(maskedSize, plainSize)
    }

    /// Outside the snapshot path — Playbook, Canvas, the app — the modifier is a no-op.
    func testMaskingIsNotAppliedOutsideSnapshots() throws {
        let size = CGSize(width: 160, height: 40)
        let first = try imageData(of: hostedView(unstableRow(value: "2024-01-01 10:00", masked: true), size: size))
        let second = try imageData(of: hostedView(unstableRow(value: "1999-12-31 23:59", masked: true), size: size))

        XCTAssertNotEqual(first, second)
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

// MARK: - Helpers

private extension MacOSSnapshotTests {
    /// Row with a fixed frame, so masked and unmasked variants are laid out the same way.
    @ViewBuilder
    func unstableRow(value: String, masked: Bool) -> some View {
        let text = Text(value)
            .font(.system(size: 12))
            .frame(width: 140, height: 20)

        if masked {
            text.snapshotMasked()
        } else {
            text
        }
    }

    func snapshotImageData(of view: some View) throws -> Data {
        try XCTUnwrap(snapshotBitmap(of: view).representation(using: .png, properties: [:]))
    }

    func snapshotBitmap(of view: some View) throws -> NSBitmapImageRep {
        let snapshot = PrefireSnapshot(
            { view },
            name: "Masking",
            isScreen: false,
            device: DeviceConfig(size: CGSize(width: 160, height: 40))
        )

        return try bitmap(of: snapshot.loadViewWithPreferences().0)
    }

    /// Hosts the view the way `PlaybookView` would: without the snapshot environment.
    func hostedView(_ view: some View, size: CGSize) -> NSView {
        _ = NSApplication.shared
        let hostingController = NSHostingController(rootView: AnyView(view))
        hostingController.view.frame = CGRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -10_000, y: -10_000), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        window.contentView = hostingController.view
        return hostingController.view
    }

    func imageData(of view: NSView) throws -> Data {
        try XCTUnwrap(bitmap(of: view).representation(using: .png, properties: [:]))
    }

    func bitmap(of view: NSView) throws -> NSBitmapImageRep {
        view.layoutSubtreeIfNeeded()
        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: representation)
        return representation
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
