import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit

/// The platform's native view type: `UIView` on iOS/tvOS, `NSView` on macOS.
public typealias PrefireNativeView = UIView

/// The platform's native view controller type: `UIViewController` on iOS/tvOS, `NSViewController` on macOS.
public typealias PrefireNativeViewController = UIViewController

public struct ViewRepresentable<WrappedView: PrefireNativeView>: UIViewRepresentable {
    let view: WrappedView

    public init(view: WrappedView) {
        self.view = view
    }

    public func makeUIView(context: Context) -> WrappedView {
        view.setContentHuggingPriority(.defaultHigh, for: .vertical)
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return view
    }

    public func updateUIView(_ uiView: WrappedView, context: Context) { }
}

public struct ViewControllerRepresentable<WrappedViewController: PrefireNativeViewController>: UIViewControllerRepresentable {
    let viewController: WrappedViewController

    public init(viewController: WrappedViewController) {
        self.viewController = viewController
    }

    public func makeUIViewController(context: Context) -> WrappedViewController {
        return viewController
    }

    public func updateUIViewController(_ uiViewController: WrappedViewController, context: Context) { }
}
#elseif os(macOS)
import AppKit

/// The platform's native view type: `UIView` on iOS/tvOS, `NSView` on macOS.
public typealias PrefireNativeView = NSView

/// The platform's native view controller type: `UIViewController` on iOS/tvOS, `NSViewController` on macOS.
public typealias PrefireNativeViewController = NSViewController

public struct ViewRepresentable<WrappedView: PrefireNativeView>: NSViewRepresentable {
    let view: WrappedView

    public init(view: WrappedView) {
        self.view = view
    }

    public func makeNSView(context: Context) -> WrappedView {
        view.setContentHuggingPriority(.defaultHigh, for: .vertical)
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return view
    }

    public func updateNSView(_ nsView: WrappedView, context: Context) { }
}

public struct ViewControllerRepresentable<WrappedViewController: PrefireNativeViewController>: NSViewControllerRepresentable {
    let viewController: WrappedViewController

    public init(viewController: WrappedViewController) {
        self.viewController = viewController
    }

    public func makeNSViewController(context: Context) -> WrappedViewController {
        viewController
    }

    public func updateNSViewController(_ nsViewController: WrappedViewController, context: Context) { }
}
#endif
