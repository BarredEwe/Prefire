import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit

/// Value passed to SnapshotTesting: the SwiftUI view on iOS/tvOS, the hosting `NSView` on macOS.
public typealias PrefireSnapshotView = AnyView
#elseif os(macOS)
import AppKit

/// Value passed to SnapshotTesting: the SwiftUI view on iOS/tvOS, the hosting `NSView` on macOS.
public typealias PrefireSnapshotView = NSView

/// Largest canvas to render, in points. Larger sizes are clamped to it.
private let maxCanvasDimension: CGFloat = 4096

/// Off-screen window hosting the snapshot content.
///
/// The backing scale factor is fixed, so the recorded image size does not depend on the display.
@MainActor
private final class SnapshotHostWindow: NSWindow {
    private var pinnedScale: CGFloat = 2

    override var backingScaleFactor: CGFloat { pinnedScale }

    private static var cache: [CGFloat: SnapshotHostWindow] = [:]

    /// Shared window for `scale`, hosting one snapshot at a time.
    ///
    /// A window retains its `contentView`, so windows are reused instead of created per snapshot.
    static func shared(scale: CGFloat) -> SnapshotHostWindow {
        if let window = cache[scale] { return window }

        let window = SnapshotHostWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        window.pinnedScale = scale
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.animationBehavior = .none
        window.collectionBehavior = [.ignoresCycle, .stationary, .transient]
        cache[scale] = window
        return window
    }
}

/// Hosts a SwiftUI preview in a window so SnapshotTesting can snapshot the `NSView`.
/// Rendering itself is left to SnapshotTesting's `NSView.image` strategy.
@MainActor
private final class SnapshotHostingContainer: NSView {
    private let hostingController: NSHostingController<AnyView>

    /// Size the content asks for, clamped to `maxCanvasDimension`.
    var fittingContentSize: CGSize {
        let fitting = hostingController.view.fittingSize
        if isRenderableSize(fitting) {
            return fitting
        }

        let proposed = hostingController.sizeThatFits(
            in: NSSize(width: maxCanvasDimension, height: maxCanvasDimension)
        )
        if isRenderableSize(proposed) {
            return proposed
        }

        return CGSize(width: 1, height: 1)
    }

    init(rootView: AnyView, scale: CGFloat) {
        _ = NSApplication.shared
        hostingController = NSHostingController(rootView: rootView)
        super.init(frame: .zero)
        wantsLayer = true
        hostingController.view.wantsLayer = true
        hostingController.view.autoresizingMask = [.width, .height]
        addSubview(hostingController.view)
        SnapshotHostWindow.shared(scale: scale).contentView = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyCanvasSize(_ size: CGSize) {
        let canvas = CGSize(
            width: clampedCanvasDimension(size.width),
            height: clampedCanvasDimension(size.height)
        )
        window?.setContentSize(canvas)
        window?.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        frame = CGRect(origin: .zero, size: canvas)
        hostingController.view.frame = bounds
        layoutSubtreeIfNeeded()
    }

    override func layout() {
        super.layout()
        hostingController.view.frame = bounds
    }
}

private func clampedCanvasDimension(_ value: CGFloat) -> CGFloat {
    guard value.isFinite, value > 0 else { return 1 }
    return min(value, maxCanvasDimension)
}

private func isRenderableSize(_ size: CGSize) -> Bool {
    size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
}
#endif

#if canImport(XCTest)
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

    public init(_ preview: _Preview, testName: String = #function, device: DeviceConfig) where Content == AnyView {
        previewContent = preview.content
        name = preview.displayName ?? testName
        isScreen = preview.layout == .device
        self.device = Self.resolvedDevice(device, layout: preview.layout)
    }

    /// - Parameter fixedLayoutSize: Canvas requested by `.fixedLayout(width:height:)`. Applied on
    ///                              macOS; ignored on iOS/tvOS, where the layout follows `isScreen`.
    public init(
        @ViewBuilder _ view: @escaping @MainActor () -> Content,
        name: String,
        isScreen: Bool,
        device: DeviceConfig,
        fixedLayoutSize: CGSize? = nil
    ) {
        previewContent = view()
        self.name = name
        self.isScreen = isScreen
        self.device = Self.resolvedDevice(device, fixedLayoutSize: fixedLayoutSize)
    }

    @_disfavoredOverload
    public init<T: PrefireNativeView>(
        _ view: @escaping @MainActor () -> T,
        name: String,
        isScreen: Bool,
        device: DeviceConfig,
        fixedLayoutSize: CGSize? = nil
    ) where Content == ViewRepresentable<T> {
        previewContent = ViewRepresentable(view: view())
        self.name = name
        self.isScreen = isScreen
        self.device = Self.resolvedDevice(device, fixedLayoutSize: fixedLayoutSize)
    }

    @_disfavoredOverload
    public init<T: PrefireNativeViewController>(
        _ viewController: @escaping @MainActor () -> T,
        name: String,
        isScreen: Bool,
        device: DeviceConfig,
        fixedLayoutSize: CGSize? = nil
    ) where Content == ViewControllerRepresentable<T> {
        previewContent = ViewControllerRepresentable(viewController: viewController())
        self.name = name
        self.isScreen = isScreen
        self.device = Self.resolvedDevice(device, fixedLayoutSize: fixedLayoutSize)
    }

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
                .onPreferenceChange(WaitPreferenceKey.self) {
                    preferences.wait = $0
                }
                .onPreferenceChange(WaitTimeoutPreferenceKey.self) {
                    preferences.waitTimeout = $0
                }
        )

        return (render(view: view, preferences: preferences), preferences)
    }

    // MARK: - Private functions

    /// Renders the view once so `onPreferenceChange` has fired, waits until it is ready,
    /// and returns the value to snapshot.
    ///
    /// On macOS the result is hosted in a shared window and stays valid only until the next
    /// `loadViewWithPreferences()` call.
    private func render(view: AnyView, preferences: PreferenceKeys) -> PrefireSnapshotView {
        #if os(iOS) || os(tvOS)
        let hostingController = UIHostingController(rootView: view)
        let window = UIWindow(frame: .init())

        window.isHidden = false
        window.rootViewController = hostingController

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        // The snapshot strategy builds its own hosting controller from `view`, discarding any state
        // this one reached. So the wait runs on this window, which is given a canvas only when it is
        // needed, and the time it took is replayed as a delay by `PreferenceKeys.resolvedDelay`.
        if preferences.resolvedWait != nil {
            window.frame = CGRect(origin: .zero, size: device.size ?? UIScreen.main.bounds.size)
            hostingController.view.frame = window.bounds
            hostingController.view.layoutIfNeeded()

            preferences.settleDelay = SnapshotWaiter.wait(for: preferences, in: hostingController.view, name: name)
            window.isHidden = true
        }

        return view
        #elseif os(macOS)
        let hostingView = SnapshotHostingContainer(rootView: view, scale: device.scale)
        hostingView.applyCanvasSize(device.size ?? hostingView.fittingContentSize)

        // The view being captured is the one waited on, so nothing has to be replayed as a delay.
        SnapshotWaiter.wait(for: preferences, in: hostingView, name: name)
        return hostingView
        #endif
    }

    private static func resolvedDevice(_ device: DeviceConfig, layout: PreviewLayout) -> DeviceConfig {
        guard case let .fixed(width, height) = layout else { return device }
        return resolvedDevice(device, fixedLayoutSize: CGSize(width: width, height: height))
    }

    private static func resolvedDevice(_ device: DeviceConfig, fixedLayoutSize: CGSize?) -> DeviceConfig {
        #if os(macOS)
        guard let fixedLayoutSize else { return device }
        var config = device
        config.size = fixedLayoutSize
        return config
        #else
        // iOS/tvOS ignore the fixed-layout canvas: their layout follows `isScreen`.
        return device
        #endif
    }
}

#if os(iOS) || os(tvOS)
public extension PrefireSnapshot {
    init(
        @ViewBuilder _ view: @escaping @MainActor () -> Content,
        name: String,
        isScreen: Bool,
        device: DeviceConfig,
        fixedLayoutSize: CGSize? = nil,
        traits: UITraitCollection
    ) {
        self.init(view, name: name, isScreen: isScreen, device: device, fixedLayoutSize: fixedLayoutSize)
        self.traits = traits
    }

    @_disfavoredOverload
    init<T: PrefireNativeView>(
        _ view: @escaping @MainActor () -> T,
        name: String,
        isScreen: Bool,
        device: DeviceConfig,
        fixedLayoutSize: CGSize? = nil,
        traits: UITraitCollection
    ) where Content == ViewRepresentable<T> {
        self.init(view, name: name, isScreen: isScreen, device: device, fixedLayoutSize: fixedLayoutSize)
        self.traits = traits
    }

    @_disfavoredOverload
    init<T: PrefireNativeViewController>(
        _ viewController: @escaping @MainActor () -> T,
        name: String,
        isScreen: Bool,
        device: DeviceConfig,
        fixedLayoutSize: CGSize? = nil,
        traits: UITraitCollection
    ) where Content == ViewControllerRepresentable<T> {
        self.init(viewController, name: name, isScreen: isScreen, device: device, fixedLayoutSize: fixedLayoutSize)
        self.traits = traits
    }
}
#endif
#endif
