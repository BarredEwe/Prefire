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

    /// Resizes the canvas to its content, since a preview may grow while it loads.
    func followContent() {
        let fitting = fittingContentSize
        let canvas = CGSize(width: clampedCanvasDimension(fitting.width), height: clampedCanvasDimension(fitting.height))
        if canvas != frame.size {
            applyCanvasSize(canvas)
        }
    }

    /// Pixels of the view, rendered the way SnapshotTesting renders an `NSView`.
    func frameData() -> Data {
        layoutSubtreeIfNeeded()

        guard bounds.width > 0, bounds.height > 0,
              let representation = bitmapImageRepForCachingDisplay(in: bounds) else { return Data() }
        cacheDisplay(in: bounds, to: representation)

        guard let pixels = representation.bitmapData else { return Data() }
        return Data(bytes: pixels, count: representation.bytesPerRow * representation.pixelsHigh)
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

#if canImport(XCTest) && !os(watchOS)
@MainActor public struct PrefireSnapshot<Content: SwiftUI.View> {
    private var previewContent: Content
    public var name: String
    public var isScreen: Bool
    public var device: DeviceConfig

    /// Test a preview of a `PreviewProvider` is snapshotted in, like `test_card`. `prefire render`
    /// asks for a provider by it.
    public internal(set) var testName: String?

    #if os(iOS) || os(tvOS)
    public var traits: UITraitCollection = .init()
    #elseif os(macOS)
    /// Appearance `prefire render` asked for. On iOS/tvOS it is put into `traits` instead.
    var renderOptions: PrefireRenderOptions?
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
        let sized = if let size = device.size {
            AnyView(previewContent.frame(width: size.width, height: size.height))
        } else {
            AnyView(previewContent)
        }
        #if os(macOS)
        return renderOptions?.applyingAppearance(to: sized) ?? sized
        #else
        return sized
        #endif
        #endif
    }

    public init(_ preview: _Preview, testName: String = #function, device: DeviceConfig) where Content == AnyView {
        previewContent = preview.content
        name = preview.displayName ?? testName
        self.testName = testName.hasSuffix("()") ? String(testName.dropLast(2)) : testName
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

    #if os(iOS) || os(tvOS)
    /// Renders the preview once to read its preferences and, when it asks for it, waits until it is
    /// ready and captures it into `PreferenceKeys.waitResult`.
    ///
    /// Waiting runs the main run loop in place: call it from a synchronous test method. From
    /// asynchronous code `.task` and other main actor work of the preview do not run meanwhile.
    ///
    /// - Parameters:
    ///   - drawHierarchyInKeyWindow: How a preview that is waited on is captured. Pass the value given
    ///                               to the snapshot strategy.
    ///   - fullPage: Whether a screen preview that is waited on is captured at the height of its whole
    ///               scrollable content, as `fullPageDevice(delay:)` measures it. It is measured once it
    ///               settled, so content loaded while waiting counts.
    ///   - waitDefaults: How previews that do not say so themselves wait.
    public func loadViewWithPreferences(
        drawHierarchyInKeyWindow: Bool = false,
        fullPage: Bool = false,
        waitDefaults: SnapshotWaitDefaults = .init()
    ) -> (PrefireSnapshotView, PreferenceKeys) {
        let preferences = PreferenceKeys()
        let view = observingPreferences(into: preferences)

        // Hosted where it would be waited on, so a preview that waits is hosted once and keeps the
        // state it reaches: the snapshot strategy would host it in a window of its own, starting it over.
        let canvas = SnapshotCanvas(
            view: view,
            isScreen: isScreen,
            device: device,
            traits: traits,
            drawHierarchyInKeyWindow: drawHierarchyInKeyWindow
        )
        defer { canvas.dispose() }

        guard let resolved = SnapshotWaiter.resolve(preferences.wait, defaults: waitDefaults) else {
            return (view, preferences)
        }

        func waitInCanvas(delay: TimeInterval) -> String? {
            SnapshotWaiter.wait(
                for: resolved.wait,
                timeout: resolved.timeout,
                delay: delay,
                name: name,
                frame: canvas.frameData,
                layout: canvas.followContent
            )
        }

        var failure = waitInCanvas(delay: preferences.delay)
        if failure == nil, fullPage, canvas.stretchToFullPage() != nil {
            // Rows the stretched canvas brings in may start loading in their turn.
            failure = waitInCanvas(delay: 0)
        }

        preferences.waitResult = failure.map(SnapshotWaitResult.timedOut) ?? .settled(canvas.capture())
        return (view, preferences)
    }
    #elseif os(macOS)
    /// Renders the preview to read its preferences and, when it asks for it, waits until it is ready.
    ///
    /// Waiting runs the main run loop in place: call it from a synchronous test method. From
    /// asynchronous code `.task` and other main actor work of the preview do not run meanwhile.
    ///
    /// The returned view is hosted in a shared window and stays valid only until the next call.
    ///
    /// - Parameter waitDefaults: How previews that do not say so themselves wait.
    public func loadViewWithPreferences(waitDefaults: SnapshotWaitDefaults = .init()) -> (PrefireSnapshotView, PreferenceKeys) {
        let preferences = PreferenceKeys()
        let hostingView = SnapshotHostingContainer(rootView: observingPreferences(into: preferences), scale: device.scale)
        hostingView.applyCanvasSize(device.size ?? hostingView.fittingContentSize)

        // SnapshotTesting captures this view where it is, so it is waited on directly.
        guard let resolved = SnapshotWaiter.resolve(preferences.wait, defaults: waitDefaults) else {
            return (hostingView, preferences)
        }

        let failure = SnapshotWaiter.wait(
            for: resolved.wait,
            timeout: resolved.timeout,
            delay: preferences.delay,
            name: name,
            frame: hostingView.frameData,
            layout: { if device.size == nil { hostingView.followContent() } }
        )

        preferences.waitResult = failure.map(SnapshotWaitResult.timedOut) ?? .settled
        return (hostingView, preferences)
    }
    #endif

    // MARK: - Private functions

    /// The preview, reporting its snapshot preferences into `preferences` once it is rendered.
    private func observingPreferences(into preferences: PreferenceKeys) -> AnyView {
        AnyView(
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
                .onPreferenceChange(UserStoryPreferenceKey.self) {
                    preferences.userStory = $0
                }
                .onPreferenceChange(StatePreferenceKey.self) {
                    preferences.state = $0
                }
        )
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

    /// `device` with its height fitted to the content of the page's scroll view, so the snapshot
    /// shows the whole scrollable content instead of the first screen.
    ///
    /// Returns `device` unchanged for non-screen previews, devices without a fixed size, and content
    /// that fits on one screen.
    ///
    /// - Parameter delay: Time to let the content settle before measuring, as `.snapshot(delay:)`
    ///                    does before taking the image.
    func fullPageDevice(delay: TimeInterval = 0) -> DeviceConfig {
        guard isScreen, let size = device.size else { return device }

        let canvas = SnapshotCanvas(view: content, isScreen: true, device: device, traits: traits, drawHierarchyInKeyWindow: false)
        defer { canvas.dispose() }

        if delay > 0 {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: delay))
        }

        guard let height = canvas.stretchToFullPage() else { return device }

        var config = device
        config.size = CGSize(width: size.width, height: height)
        return config
    }
}
#endif
#endif
