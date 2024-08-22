import SwiftUI
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
