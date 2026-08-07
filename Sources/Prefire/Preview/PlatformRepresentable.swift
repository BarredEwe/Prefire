import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit

public struct ViewRepresentable<WrappedView: UIView>: UIViewRepresentable {
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

public struct ViewControllerRepresentable<WrappedViewController: UIViewController>: UIViewControllerRepresentable {
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

public struct NSViewRepresentable<WrappedView: NSView>: SwiftUI.NSViewRepresentable {
    let view: WrappedView

    public init(view: WrappedView) {
        self.view = view
    }

    public func makeNSView(context: Context) -> WrappedView {
        view
    }

    public func updateNSView(_ nsView: WrappedView, context: Context) { }
}

public struct NSViewControllerRepresentable<WrappedViewController: NSViewController>: SwiftUI.NSViewControllerRepresentable {
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
