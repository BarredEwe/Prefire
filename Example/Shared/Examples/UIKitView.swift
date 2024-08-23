import SwiftUI
import Prefire

#Preview {
    {
        let view = UIView(frame: .init(origin: .zero, size: .init(width: 100, height: 100)))
        view.backgroundColor = .red
        return view
    }()
}

#Preview {
    {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .green
        return viewController
    }()
}
