import SwiftUI
#if os(iOS)
    import UIKit

    public struct ViewRepresentable<WrappedView: UIView>: UIViewRepresentable {
        let view: WrappedView

        public init(view: WrappedView) {
            self.view = view
        }

        public func makeUIView(context _: Context) -> WrappedView {
            view.setContentHuggingPriority(.defaultHigh, for: .vertical)
            view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            return view
        }

        public func updateUIView(_: WrappedView, context _: Context) {}
    }

    public struct ViewControllerRepresentable<WrappedViewController: UIViewController>: UIViewControllerRepresentable {
        let viewController: WrappedViewController

        public init(viewController: WrappedViewController) {
            self.viewController = viewController
        }

        public func makeUIViewController(context _: Context) -> WrappedViewController {
            return viewController
        }

        public func updateUIViewController(_: WrappedViewController, context _: Context) {}
    }
#elseif os(macOS)
    import AppKit

    public struct ViewRepresentable<WrappedView: NSView>: NSViewRepresentable {
        let view: WrappedView

        public init(view: WrappedView) {
            self.view = view
        }

        public func makeNSView(context _: Context) -> WrappedView {
            view.setContentHuggingPriority(.defaultHigh, for: .vertical)
            view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            return view
        }

        public func updateNSView(_: WrappedView, context _: Context) {}
    }

    public struct ViewControllerRepresentable<WrappedViewController: NSViewController>: NSViewControllerRepresentable {
        let viewController: WrappedViewController

        public init(viewController: WrappedViewController) {
            self.viewController = viewController
        }

        public func makeNSViewController(context _: Context) -> WrappedViewController {
            return viewController
        }

        public func updateNSViewController(_: WrappedViewController, context _: Context) {}
    }
#endif
