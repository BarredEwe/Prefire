import Prefire
import SwiftUI

#Preview {
    #if os(iOS)
    let view = UIView(frame: .init(origin: .zero, size: .init(width: 100, height: 100)))
    view.backgroundColor = .red
    return view
    #else
    EmptyView()
    #endif
}

#Preview {
    #if os(iOS)
    let viewController = UIViewController()
    viewController.view.backgroundColor = .green
    return viewController
    #else
    EmptyView()
    #endif
}
