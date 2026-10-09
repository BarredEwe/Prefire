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

#if canImport(XCTest) && !os(watchOS)
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
        )

        return (render(view: view), preferences)
    }

    // MARK: - Private functions

    /// Renders the view once so `onPreferenceChange` has fired, and returns the value to snapshot.
    ///
    /// On macOS the result is hosted in a shared window and stays valid only until the next
    /// `loadViewWithPreferences()` call.
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
        let hostingView = SnapshotHostingContainer(rootView: view, scale: device.scale)
        hostingView.applyCanvasSize(device.size ?? hostingView.fittingContentSize)
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

        let host = FullPageMeasuringHost(
            content: content,
            size: size,
            safeArea: device.safeArea,
            traits: UITraitCollection(traitsFrom: [device.traits, traits])
        )
        defer { host.tearDown() }

        host.layout(height: size.height)
        if delay > 0 {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: delay))
            host.layout(height: size.height)
        }

        // Only the page's scroll view decides the height. Other scroll views (carousels, fixed-height
        // ones nested in the page) do not grow with the canvas, so following them would only add empty
        // space below the content.
        guard let scrollView = host.scrollViews().max(by: { verticalOverflow(of: $0) < verticalOverflow(of: $1) }),
              verticalOverflow(of: scrollView) > 0 else {
            return device
        }

        var height = size.height
        for _ in 0..<fullPageMaxIterations {
            // Signed: lazy stacks estimate the size of rows they have not laid out yet, so the content
            // may turn out shorter as well as longer once the canvas is stretched.
            let candidate = min(max(height + verticalOverflow(of: scrollView), size.height), fullPageMaxHeight)
            guard abs(candidate - height) >= 0.5 else { break }

            let viewportHeight = scrollView.bounds.height
            host.layout(height: candidate)
            guard scrollView.bounds.height != viewportHeight else { break }

            height = candidate
        }

        var config = device
        config.size = CGSize(width: size.width, height: height.rounded(.up))
        return config
    }
}

/// Lays the content out the way SnapshotTesting's `.device` layout does: the device's safe area and the
/// snapshot's traits, at a canvas height that can be changed.
@MainActor
private final class FullPageMeasuringHost {
    private let window: FullPageMeasuringWindow
    private let container = UIViewController()
    private let hostingController: UIHostingController<AnyView>

    init(content: AnyView, size: CGSize, safeArea: UIEdgeInsets, traits: UITraitCollection) {
        window = FullPageMeasuringWindow(frame: CGRect(origin: .zero, size: size), safeArea: safeArea)
        hostingController = UIHostingController(rootView: content)

        container.addChild(hostingController)
        container.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: container)
        container.setOverrideTraitCollection(traits, forChild: hostingController)

        window.rootViewController = container
        window.isHidden = false
    }

    func layout(height: CGFloat) {
        window.frame.size.height = height
        container.view.frame = window.bounds
        hostingController.view.frame = container.view.bounds
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        // SwiftUI updates lazy content after the first pass, so settle the layout once more.
        hostingController.view.layoutIfNeeded()
    }

    func scrollViews() -> [UIScrollView] {
        visibleScrollViews(in: hostingController.view)
    }

    func tearDown() {
        window.isHidden = true
        window.rootViewController = nil
    }

    private func visibleScrollViews(in view: UIView) -> [UIScrollView] {
        guard !view.isHidden, view.alpha > 0 else { return [] }

        let nested = view.subviews.flatMap(visibleScrollViews(in:))
        guard let scrollView = view as? UIScrollView, scrollView.isScrollEnabled else { return nested }
        return [scrollView] + nested
    }
}

/// Window reporting the device's safe area, the way SnapshotTesting's own window does.
///
/// A plain `UIWindow` takes the safe area of the simulator running the tests, even off-screen,
/// which would leave the snapshot that much taller than its content.
private final class FullPageMeasuringWindow: UIWindow {
    private let safeArea: UIEdgeInsets

    init(frame: CGRect, safeArea: UIEdgeInsets) {
        self.safeArea = safeArea
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var safeAreaInsets: UIEdgeInsets { safeArea }
}

/// Upper bound for `fullPageDevice()`, in points. The image is held in memory at the device scale.
private let fullPageMaxHeight: CGFloat = 10_000

/// Lazy stacks report an estimated content size, so the height may need a few rounds to settle.
private let fullPageMaxIterations = 10

/// How much taller the content of `scrollView` is than its viewport. Negative when it is shorter.
@MainActor
private func verticalOverflow(of scrollView: UIScrollView) -> CGFloat {
    let insets = scrollView.adjustedContentInset
    return scrollView.contentSize.height + insets.top + insets.bottom - scrollView.bounds.height
}
#endif
#endif
