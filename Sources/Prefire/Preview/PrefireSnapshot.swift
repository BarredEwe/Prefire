import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit
public typealias PrefireSnapshotView = AnyView
#elseif os(macOS)
import AppKit
public typealias PrefireSnapshotView = NSView

/// Hosts a SwiftUI preview in a window so SnapshotTesting can snapshot the `NSView`.
/// Rendering itself is left to SnapshotTesting's `NSView.image` strategy.
@MainActor
private final class SnapshotHostingContainer: NSView {
    private let hostingController: NSHostingController<AnyView>
    private let windowHost: NSWindow

    var fittingContentSize: CGSize {
        let fitting = hostingController.view.fittingSize
        if isUsableCanvasSize(fitting) {
            return fitting
        }

        let proposed = hostingController.sizeThatFits(in: NSSize(width: 4096, height: 4096))
        if isUsableCanvasSize(proposed) {
            return proposed
        }

        return CGSize(width: 1, height: 1)
    }

    init(rootView: AnyView) {
        _ = NSApplication.shared
        hostingController = NSHostingController(rootView: rootView)
        windowHost = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        windowHost.isReleasedWhenClosed = false
        windowHost.hasShadow = false
        windowHost.animationBehavior = .none
        windowHost.collectionBehavior = [.ignoresCycle, .stationary, .transient]
        super.init(frame: .zero)
        wantsLayer = true
        hostingController.view.wantsLayer = true
        hostingController.view.autoresizingMask = [.width, .height]
        addSubview(hostingController.view)
        windowHost.contentView = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyCanvasSize(_ size: CGSize) {
        let canvas = CGSize(
            width: clampedCanvasDimension(size.width),
            height: clampedCanvasDimension(size.height)
        )
        frame = CGRect(origin: .zero, size: canvas)
        hostingController.view.frame = bounds
        windowHost.setContentSize(canvas)
        windowHost.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        layoutSubtreeIfNeeded()
    }

    override func layout() {
        super.layout()
        hostingController.view.frame = bounds
    }
}

private func clampedCanvasDimension(_ value: CGFloat) -> CGFloat {
    guard value.isFinite, value > 0 else { return 1 }
    return min(value, 4096)
}

private func isUsableCanvasSize(_ size: CGSize) -> Bool {
    size.width > 0 && size.height > 0 && size.width.isFinite && size.height.isFinite
        && size.width < 4096 && size.height < 4096
}
#endif

#if canImport(XCTest)
public struct DeviceConfig {
    public var size: CGSize?

    #if os(iOS) || os(tvOS)
    public var safeArea: UIEdgeInsets
    public var traits: UITraitCollection

    public init(safeArea: UIEdgeInsets, size: CGSize? = nil, traits: UITraitCollection) {
        self.safeArea = safeArea
        self.size = size
        self.traits = traits
    }
    #elseif os(macOS)
    public init(size: CGSize? = nil) {
        self.size = size
    }
    #endif

}

@MainActor public struct PrefireSnapshot<Content: SwiftUI.View> {
    private var previewContent: Content
    public var name: String
    public var isScreen: Bool
    public var device: DeviceConfig

    #if os(iOS) || os(tvOS)
    public var traits: UITraitCollection = .init()
    #endif

    private var content: AnyView {
        #if os(iOS) || os(tvOS)
        if isScreen {
            AnyView(previewContent)
        } else {
            AnyView(
                previewContent
                    .frame(width: device.size?.width)
                    .fixedSize(horizontal: false, vertical: true)
            )
        }
        #else
        if let size = device.size {
            AnyView(previewContent.frame(width: size.width, height: size.height))
        } else {
            AnyView(previewContent)
        }
        #endif
    }

    #if os(iOS) || os(tvOS)
    public init(_ preview: _Preview, testName: String = #function, device: DeviceConfig) where Content == AnyView {
        previewContent = preview.content
        name = preview.displayName ?? testName
        isScreen = preview.layout == .device
        self.device = Self.deviceConfig(device, layout: preview.layout)
    }
    #elseif os(macOS)
    public init(_ preview: _Preview, testName: String = #function, device: DeviceConfig = .init()) where Content == AnyView {
        previewContent = preview.content
        name = preview.displayName ?? testName
        isScreen = preview.layout == .device
        self.device = Self.deviceConfig(device, layout: preview.layout)
    }
    #endif

    #if os(iOS) || os(tvOS)
    public init(@ViewBuilder _ view: @escaping @MainActor () -> Content, name: String, isScreen: Bool, device: DeviceConfig, fixedLayoutSize: CGSize? = nil, traits: UITraitCollection = .init()) {
        previewContent = view()
        self.name = name
        self.isScreen = isScreen
        self.device = Self.deviceConfig(device, fixedLayoutSize: fixedLayoutSize)
        self.traits = traits
    }

    @_disfavoredOverload
    public init<T: UIView>(_ view: @escaping @MainActor () -> T, name: String, isScreen: Bool, device: DeviceConfig, fixedLayoutSize: CGSize? = nil, traits: UITraitCollection = .init()) where Content == ViewRepresentable<T> {
        previewContent = ViewRepresentable(view: view())
        self.name = name
        self.isScreen = isScreen
        self.device = Self.deviceConfig(device, fixedLayoutSize: fixedLayoutSize)
        self.traits = traits
    }

    @_disfavoredOverload
    public init<T: UIViewController>(_ viewController: @escaping @MainActor () -> T, name: String, isScreen: Bool, device: DeviceConfig, fixedLayoutSize: CGSize? = nil, traits: UITraitCollection = .init()) where Content == ViewControllerRepresentable<T> {
        previewContent = ViewControllerRepresentable(viewController: viewController())
        self.name = name
        self.isScreen = isScreen
        self.device = Self.deviceConfig(device, fixedLayoutSize: fixedLayoutSize)
        self.traits = traits
    }
    #elseif os(macOS)
    public init(@ViewBuilder _ view: @escaping @MainActor () -> Content, name: String, isScreen: Bool = false, device: DeviceConfig = .init(), fixedLayoutSize: CGSize? = nil) {
        previewContent = view()
        self.name = name
        self.isScreen = isScreen
        self.device = Self.deviceConfig(device, fixedLayoutSize: fixedLayoutSize)
    }

    @_disfavoredOverload
    public init<T: NSView>(_ view: @escaping @MainActor () -> T, name: String, isScreen: Bool = false, device: DeviceConfig = .init(), fixedLayoutSize: CGSize? = nil) where Content == ViewRepresentable<T> {
        previewContent = ViewRepresentable(view: view())
        self.name = name
        self.isScreen = isScreen
        self.device = Self.deviceConfig(device, fixedLayoutSize: fixedLayoutSize)
    }

    @_disfavoredOverload
    public init<T: NSViewController>(_ viewController: @escaping @MainActor () -> T, name: String, isScreen: Bool = false, device: DeviceConfig = .init(), fixedLayoutSize: CGSize? = nil) where Content == ViewControllerRepresentable<T> {
        previewContent = ViewControllerRepresentable(viewController: viewController())
        self.name = name
        self.isScreen = isScreen
        self.device = Self.deviceConfig(device, fixedLayoutSize: fixedLayoutSize)
    }
    #endif

    public func loadViewWithPreferences() -> (PrefireSnapshotView, PreferenceKeys) {
        let preferences = PreferenceKeys()

        let view = AnyView(
            content
                .onPreferenceChange(DelayPreferenceKey.self) {
                    preferences.delay = $0
                }
                .onPreferenceChange(PrecisionPreferenceKey.self) {
                    preferences.precision = $0
                }
                .onPreferenceChange(PerceptualPrecisionPreferenceKey.self) {
                    preferences.perceptualPrecision = $0
                }
                .onPreferenceChange(RecordPreferenceKey.self) {
                    preferences.record = $0
                }
        )

        return (render(view: view), preferences)
    }

    private func render(view: AnyView) -> PrefireSnapshotView {
        #if os(iOS) || os(tvOS)
        let hostingController = UIHostingController(rootView: view)
        let window = UIWindow(frame: .init())

        window.isHidden = false
        window.rootViewController = hostingController

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        return view
        #elseif os(macOS)
        let hostingView = SnapshotHostingContainer(rootView: view)
        hostingView.applyCanvasSize(device.size ?? hostingView.fittingContentSize)
        return hostingView
        #endif
    }

    private static func deviceConfig(_ device: DeviceConfig, layout: PreviewLayout) -> DeviceConfig {
        guard case let .fixed(width, height) = layout else { return device }
        return deviceConfig(device, fixedLayoutSize: CGSize(width: width, height: height))
    }

    private static func deviceConfig(_ device: DeviceConfig, fixedLayoutSize: CGSize?) -> DeviceConfig {
        guard let fixedLayoutSize else { return device }
        var config = device
        config.size = fixedLayoutSize
        return config
    }
}
#endif
