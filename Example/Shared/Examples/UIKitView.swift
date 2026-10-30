import SwiftUI
import Prefire

#Preview {
    let view = UIView(frame: .init(origin: .zero, size: .init(width: 100, height: 100)))
    view.backgroundColor = .red
    return view
}

#Preview {
    let viewController = UIViewController()
    viewController.view.backgroundColor = .green
    return viewController
}

final class SettingsScreen: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        let list = UIStackView()
        list.axis = .vertical
        list.spacing = 12
        list.accessibilityContainerType = .semanticGroup
        list.accessibilityLabel = "Settings"
        let notifications = SettingsRow(title: "Notifications", value: "On")
        let language = SettingsRow(title: "Language", value: "English")
        list.addArrangedSubview(notifications)
        list.addArrangedSubview(language)
        list.accessibilityElements = [notifications, language]
        addSubview(list)
        list.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            list.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            list.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            list.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class SettingsRow: UILabel {
    init(title: String, value: String) {
        super.init(frame: .zero)
        isAccessibilityElement = true
        text = title + ": " + value
        accessibilityLabel = title
        accessibilityValue = value
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

#Preview("UIKit settings") {
    ViewRepresentable(view: SettingsScreen())
        .frame(width: 320, height: 200)
        .prefireIgnored()
}
