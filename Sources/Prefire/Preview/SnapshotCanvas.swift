#if canImport(XCTest) && (os(iOS) || os(tvOS))
import SwiftUI
import UIKit

/// Window a preview is hosted, waited on and captured in, without being moved in between.
///
/// A snapshot strategy hosts the view it is given in a window of its own, and moving a preview to
/// another window restarts its `.onAppear` and `.task`, so the state it reached while waiting would
/// be lost. The canvas reproduces what `Snapshotting<SwiftUI.View, UIImage>.image(layout:traits:)`
/// of SnapshotTesting sets up, so an image it captures matches one the strategy would render.
///
/// Unlike SnapshotTesting it does not swap `WKWebView`, `SCNView` and `SKView` for their own
/// snapshots: these render blank, as with `layer.render(in:)` in general.
@MainActor
final class SnapshotCanvas {
    /// Hosting controller's view: the view that is compared while waiting and then captured.
    var view: UIView { controller.view }

    private let controller: UIHostingController<AnyView>
    private let rootViewController = UIViewController()
    private let window: UIWindow
    private let safeArea: UIEdgeInsets
    private let traits: UITraitCollection
    private let combinedTraits: UITraitCollection
    private let drawHierarchyInKeyWindow: Bool

    /// Whether the canvas follows the size of its content, like `SwiftUISnapshotLayout.sizeThatFits`.
    private let isSizedToFit: Bool

    /// Same offset as SnapshotTesting: moving the view away keeps the safe area from affecting it.
    private let offscreen: CGFloat = 10_000

    /// - Parameters:
    ///   - isScreen: Renders on `device`, like `SwiftUISnapshotLayout.device(config:)`. Otherwise the
    ///               canvas is sized to fit the content and has no safe area.
    ///   - traits: Trait override of the snapshot, used on top of the device traits.
    init(
        view: AnyView,
        isScreen: Bool,
        device: DeviceConfig,
        traits: UITraitCollection,
        drawHierarchyInKeyWindow: Bool
    ) {
        controller = UIHostingController(rootView: view)
        safeArea = isScreen ? device.safeArea : .zero
        isSizedToFit = !isScreen
        self.traits = traits
        self.drawHierarchyInKeyWindow = drawHierarchyInKeyWindow

        if isSizedToFit {
            if #available(iOS 16.4, tvOS 16.4, *) {
                controller.safeAreaRegions = []
            } else {
                controller._disableSafeArea = true
            }
        }

        let size = isScreen ? device.size ?? controller.view.frame.size : controller.sizeThatFits(in: .zero)
        let combinedTraits = UITraitCollection(traitsFrom: [isScreen ? device.traits : traits, traits])
        self.combinedTraits = combinedTraits

        if drawHierarchyInKeyWindow {
            guard let keyWindow = Self.keyWindow else {
                fatalError("'drawHierarchyInKeyWindow' requires tests to be run in a host application")
            }
            window = keyWindow
            window.frame.size = size
        } else {
            window = SnapshotCanvasWindow(size: size, safeArea: safeArea)
        }

        controller.view.frame.size = size
        add(traits: combinedTraits)

        if size.width == 0 || size.height == 0 {
            controller.view.sizeToFit()
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
    }

    /// Follows the content when the canvas is sized to fit it, since a preview may grow while it loads.
    ///
    /// `init` measures the content outside of the window, as SnapshotTesting does. Measured in place,
    /// the size is rounded to the pixels of the snapshot traits instead of those of the screen, so it
    /// is only taken when the content changed size by a point or more: otherwise an image of a preview
    /// that did not change size would not match one the strategy renders.
    func followContent() {
        guard isSizedToFit else { return }

        let size = controller.sizeThatFits(in: .zero)
        guard abs(size.width - view.frame.width) >= 1 || abs(size.height - view.frame.height) >= 1 else { return }

        window.frame.size = size
        rootViewController.view.frame.size = size
        view.frame.size = size
        rootViewController.view.layoutIfNeeded()
    }

    /// Renders the preview the way SnapshotTesting renders a view.
    func capture() -> UIImage {
        followContent()

        let initialFrame = view.frame
        defer { view.frame = initialFrame }

        if safeArea == .zero {
            view.frame.origin = CGPoint(x: offscreen, y: offscreen)
        }

        return UIGraphicsImageRenderer(bounds: view.bounds, format: .init(for: traits)).image { context in
            if drawHierarchyInKeyWindow {
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            } else {
                view.layer.render(in: context.cgContext)
            }
        }
    }

    /// Pixels of `capture()`: the wait compares what would be captured, at the scale it is captured at.
    func frameData() -> Data {
        guard let data = capture().cgImage?.dataProvider?.data else { return Data() }
        return data as Data
    }

    /// Takes the preview out of the window.
    func dispose() {
        // Representables hand back the same view and view controller every time they are made, and
        // the preview may be hosted again next. Emptying the content dismantles them here, so they
        // leave this hierarchy instead of being taken over while still attached to it.
        controller.rootView = AnyView(EmptyView())
        controller.view.layoutIfNeeded()

        rootViewController.beginAppearanceTransition(false, animated: false)
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        controller.didMove(toParent: nil)
        rootViewController.endAppearanceTransition()
        window.rootViewController = nil
    }

    // MARK: - Private functions

    /// Key window of the test host. `UIApplication.shared` is not available to app extensions.
    private static var keyWindow: UIWindow? {
        let application = UIApplication.value(forKey: "sharedApplication") as? UIApplication
        return application?.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private func add(traits: UITraitCollection) {
        rootViewController.view.backgroundColor = .clear
        rootViewController.view.frame = window.frame
        rootViewController.preferredContentSize = rootViewController.view.frame.size

        controller.view.frame = rootViewController.view.frame
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        rootViewController.view.addSubview(controller.view)
        rootViewController.addChild(controller)
        rootViewController.setOverrideTraitCollection(traits, forChild: controller)
        controller.didMove(toParent: rootViewController)

        window.rootViewController = rootViewController

        rootViewController.beginAppearanceTransition(true, animated: false)
        rootViewController.endAppearanceTransition()

        rootViewController.view.setNeedsLayout()
        rootViewController.view.layoutIfNeeded()

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }
}

// MARK: - Full page

extension SnapshotCanvas {
    /// Stretches a screen canvas until the page's scroll view shows all of its content.
    ///
    /// - Returns: The height of the canvas, rounded up to a point, or `nil` when the page does not
    ///            scroll or the canvas is sized to fit its content.
    @discardableResult
    func stretchToFullPage() -> CGFloat? {
        guard !isSizedToFit else { return nil }

        let height = window.frame.height
        layout(height: height)
        guard let scrollView = pageScrollView(height: height) else { return nil }

        let scale = combinedTraits.displayScale > 0 ? combinedTraits.displayScale : window.screen.scale
        let maxHeight = max(height, (fullPageMaxPixelHeight / scale).rounded(.down))

        var fittedHeight = height
        for _ in 0..<fullPageMaxIterations {
            // Signed: lazy stacks estimate the size of rows they have not laid out yet, so the content
            // may turn out shorter as well as longer once the canvas is stretched.
            let candidate = min(max(fittedHeight + verticalOverflow(of: scrollView), height), maxHeight)
            guard abs(candidate - fittedHeight) >= 0.5 else { break }

            let viewportHeight = scrollView.bounds.height
            layout(height: candidate)
            guard scrollView.bounds.height != viewportHeight else { break }

            fittedHeight = candidate
        }

        let roundedHeight = fittedHeight.rounded(.up)
        if roundedHeight != fittedHeight {
            layout(height: roundedHeight)
        }
        return roundedHeight
    }

    /// Lays the content out on a canvas `height` points tall.
    func layout(height: CGFloat) {
        window.frame.size.height = height
        rootViewController.view.frame.size.height = height
        view.frame.size.height = height
        view.setNeedsLayout()
        view.layoutIfNeeded()
        // SwiftUI updates lazy content after the first pass, so settle the layout once more.
        view.layoutIfNeeded()
    }

    /// The scroll view that clips the most content among those whose viewport follows the canvas.
    ///
    /// The one that overflows the most is not enough on its own: a scroll view with a fixed height
    /// nested in the page (e.g. `.frame(height: 200)`) can overflow more, but stretching the canvas
    /// never shows more of it, so following it would stop at the first screen.
    private func pageScrollView(height: CGFloat) -> UIScrollView? {
        let candidates = visibleScrollViews(in: view).filter { verticalOverflow(of: $0) > 0 }
        guard !candidates.isEmpty else { return nil }

        let viewportHeights = candidates.map(\.bounds.height)
        layout(height: height + fullPageProbeHeight)
        let followingCanvas = zip(candidates, viewportHeights)
            .filter { scrollView, viewportHeight in scrollView.bounds.height > viewportHeight }
            .map(\.0)
        layout(height: height)

        return followingCanvas.max { verticalOverflow(of: $0) < verticalOverflow(of: $1) }
    }

    private func visibleScrollViews(in view: UIView) -> [UIScrollView] {
        guard !view.isHidden, view.alpha > 0 else { return [] }

        let nested = view.subviews.flatMap(visibleScrollViews(in:))
        guard let scrollView = view as? UIScrollView, scrollView.isScrollEnabled else { return nested }
        return [scrollView] + nested
    }
}

/// Upper bound for the height of a full-page snapshot, in pixels. The image is held in memory, so the
/// limit applies to pixels rather than points, which would allow three times as much at 3x.
private let fullPageMaxPixelHeight: CGFloat = 16_384

/// How much `pageScrollView(height:)` stretches the canvas to see which scroll views follow it.
private let fullPageProbeHeight: CGFloat = 100

/// Lazy stacks report an estimated content size, so the height may need a few rounds to settle.
private let fullPageMaxIterations = 10

/// How much taller the content of `scrollView` is than its viewport. Negative when it is shorter.
@MainActor
private func verticalOverflow(of scrollView: UIScrollView) -> CGFloat {
    let insets = scrollView.adjustedContentInset
    return scrollView.contentSize.height + insets.top + insets.bottom - scrollView.bounds.height
}

/// Window with the safe area of the snapshot device instead of the one of the simulator.
private final class SnapshotCanvasWindow: UIWindow {
    private let safeArea: UIEdgeInsets

    init(size: CGSize, safeArea: UIEdgeInsets) {
        self.safeArea = safeArea
        super.init(frame: CGRect(origin: .zero, size: size))
        isHidden = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var safeAreaInsets: UIEdgeInsets {
        #if os(iOS)
        // A hidden status bar takes the 20 pt inset of the older devices with it.
        if safeArea == UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0), rootViewController?.prefersStatusBarHidden ?? false {
            return .zero
        }
        #endif
        return safeArea
    }
}
#endif
