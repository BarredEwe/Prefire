#if canImport(XCTest) && (os(iOS) || os(tvOS))
import SwiftUI
import UIKit

/// Window a preview is waited on and then captured in, without being moved in between.
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
    /// Measured in place, with the snapshot traits. SnapshotTesting measures outside of a window, where
    /// rounding to the pixel grid depends on the simulator, so heights may differ by a fraction of a point.
    func layout() {
        guard isSizedToFit else { return }

        let size = controller.sizeThatFits(in: .zero)
        guard size != view.frame.size else { return }

        window.frame.size = size
        rootViewController.view.frame.size = size
        view.frame.size = size
        rootViewController.view.layoutIfNeeded()
    }

    /// Renders the preview the way SnapshotTesting renders a view.
    func capture() -> UIImage {
        layout()

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

    /// Takes the preview out of the window.
    func dispose() {
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
