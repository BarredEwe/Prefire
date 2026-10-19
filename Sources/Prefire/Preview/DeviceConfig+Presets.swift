import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit

public extension DeviceConfig {
    /// Canvas of the device a snapshot is rendered on when a preview does not name one.
    static var defaultSnapshotDevice: DeviceConfig {
        #if os(iOS)
        .phone(width: 375, height: 812, top: 44)
        #else
        .appleTV
        #endif
    }

    /// Canvas of a device named by `.previewDevice(_:)` or `snapshot_devices`, or `nil` for a name
    /// Prefire does not know.
    ///
    /// Sizes, safe areas and traits match the presets of SnapshotTesting's `ViewImageConfig`, so
    /// recorded references stay valid.
    @MainActor
    static func named(_ name: String) -> DeviceConfig? {
        presets.first { $0.names.contains(name) }?.config
    }

    /// Names `named(_:)` knows.
    @MainActor
    static var supportedNames: [String] {
        presets.flatMap(\.names)
    }
}

private extension DeviceConfig {
    /// Built once: `named(_:)` runs for every preview and every one of `snapshot_devices`.
    @MainActor
    static let presets: [(names: [String], config: DeviceConfig)] = {
        #if os(iOS)
        let iPhoneX = phone(width: 375, height: 812, top: 44)
        let iPhone13 = phone(width: 390, height: 844, top: 47)
        return [
            (["iPhone 17 Pro Max"], phone(width: 440, height: 956, top: 62)),
            (["iPhone 17", "iPhone 17 Pro"], phone(width: 402, height: 874, top: 62)),
            (["iPhone Air"], phone(width: 420, height: 912, top: 68)),
            (["iPhone 16 Plus", "iPhone 15 Plus"], phone(width: 430, height: 932, top: 59)),
            (["iPhone 17e", "iPhone 16e"], iPhone13),
            (["iPhone 16 Pro Max", "iPhone 15 Pro Max", "iPhone 14 Pro Max", "iPhone 14 Plus", "iPhone 13 Pro Max", "iPhone 12 Pro Max"], phone(width: 428, height: 926, top: 47)),
            (["iPhone 16 Pro", "iPhone 15 Pro", "iPhone 14 Pro", "iPhone 13 Pro", "iPhone 12 Pro"], iPhone13),
            (["iPhone 16", "iPhone 15", "iPhone 14", "iPhone 13", "iPhone 12", "iPhone 11", "iPhone 10", "iPhone X"], iPhoneX),
            (["iPhone 6", "iPhone 6s", "iPhone 7", "iPhone 8", "iPhone SE (2nd generation)", "iPhone SE (3rd generation)"], phone(width: 375, height: 667, top: 20, bottom: 0)),
            (["iPhone 6 Plus", "iPhone 6s Plus", "iPhone 8 Plus"], phone(width: 414, height: 736, top: 20, bottom: 0)),
            (["iPhone SE (1st generation)"], phone(width: 320, height: 568, top: 20, bottom: 0)),
            // Landscape, as SnapshotTesting's iPad presets are.
            (["iPad"], pad(width: 1080, height: 810, top: 20)),
            (["iPad Mini"], pad(width: 1024, height: 768, top: 20)),
            (["iPad Pro 11"], pad(width: 1194, height: 834, top: 24, bottom: 20)),
            (["iPad Pro 12.9"], pad(width: 1366, height: 1024, top: 20)),
        ]
        #else
        return [(["Apple TV"], appleTV)]
        #endif
    }()

    #if os(iOS)
    /// Portrait iPhone.
    static func phone(width: CGFloat, height: CGFloat, top: CGFloat, bottom: CGFloat = 34) -> DeviceConfig {
        DeviceConfig(
            safeArea: UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0),
            size: CGSize(width: width, height: height),
            traits: UITraitCollection(traitsFrom: [
                .init(forceTouchCapability: .available),
                .init(layoutDirection: .leftToRight),
                .init(preferredContentSizeCategory: .medium),
                .init(userInterfaceIdiom: .phone),
                .init(horizontalSizeClass: .compact),
                .init(verticalSizeClass: .regular),
            ])
        )
    }

    /// Full screen iPad.
    static func pad(width: CGFloat, height: CGFloat, top: CGFloat, bottom: CGFloat = 0) -> DeviceConfig {
        DeviceConfig(
            safeArea: UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0),
            size: CGSize(width: width, height: height),
            traits: UITraitCollection(traitsFrom: [
                .init(horizontalSizeClass: .regular),
                .init(verticalSizeClass: .regular),
                .init(userInterfaceIdiom: .pad),
            ])
        )
    }
    #endif

    static var appleTV: DeviceConfig {
        DeviceConfig(
            safeArea: UIEdgeInsets(top: 60, left: 90, bottom: 60, right: 90),
            size: CGSize(width: 1920, height: 1080),
            traits: UITraitCollection()
        )
    }
}
#elseif os(macOS)
public extension DeviceConfig {
    /// Canvas a snapshot is rendered on when a preview does not name one: the size that fits it.
    static var defaultSnapshotDevice: DeviceConfig { DeviceConfig() }

    /// Always `nil`: macOS previews are not rendered on devices.
    @MainActor
    static func named(_ name: String) -> DeviceConfig? { nil }

    /// Names `named(_:)` knows: none on macOS.
    @MainActor
    static var supportedNames: [String] { [] }
}
#endif
