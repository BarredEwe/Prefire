// Generated using Sourcery 1.8.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all
// swiftformat:disable all

import SwiftUI
import Prefire


public enum PreviewModels {
    public static var models: [PreviewModel] = {
        var views: [PreviewModel] = []

        views.append(contentsOf: createModel(for: CircleImage_Previews.self, name: "CircleImage"))
        views.append(contentsOf: createModel(for: GreenButton_Previews.self, name: "GreenButton"))
        views.append(contentsOf: createModel(for: TestViewWithoutState_Previews.self, name: "TestViewWithoutState"))
        views.append(contentsOf: createModel(for: TestView_Previews.self, name: "TestView"))

        return views.sorted(by: { $0.name > $1.name || $0.story ?? "" > $1.story ?? "" })
    }()

    @inlinable
    static func createModel<Preview: PreviewProvider>(for preview: Preview.Type, name: String) -> [PreviewModel] {
        var views: [PreviewModel] = []

        for view in Preview._allPreviews {
            views.append(
                PreviewModel(
                    content: { return view.content },
                    name: name,
                    type: Preview._allPreviews.first?.layout == .device ? .screen : .component,
                    device: Preview._allPreviews.first?.device
                )
            )
        }

        return views
    }
}
