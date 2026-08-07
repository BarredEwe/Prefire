#if os(macOS)
import AppKit
import Prefire
import SnapshotTesting
import SwiftUI
import XCTest

/// Mirrors the macOS-specific path emitted by the default snapshot template.
@MainActor
final class GeneratedMacOSSnapshotFixtureTests: XCTestCase {
    func testFixedLayoutFixtureCompilesAgainstSnapshotTesting() {
        let prefireSnapshot = PrefireSnapshot(
            { Text("Fixture") },
            name: "Fixture",
            isScreen: false,
            device: DeviceConfig(),
            fixedLayoutSize: CGSize(width: 320, height: 180)
        )
        let (previewView, preferences) = prefireSnapshot.loadViewWithPreferences()

        let strategy: Snapshotting<NSView, NSImage> = .wait(
            for: preferences.delay,
            on: .image(
                precision: preferences.precision,
                perceptualPrecision: preferences.perceptualPrecision,
                size: prefireSnapshot.device.size
            )
        )

        XCTAssertEqual(previewView.frame.size, CGSize(width: 320, height: 180))
        _ = strategy
    }
}
#endif
