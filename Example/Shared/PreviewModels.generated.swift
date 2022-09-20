// Generated using Sourcery 1.8.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all
// swiftformat:disable all

import SwiftUI
import PreFire


public enum PreviewModels {
    public static var models: [PreviewModel] = {
        var views: [PreviewModel] = []

        for state in CircleImage_Previews.State.allCases {
            views.append(
                PreviewModel(
                    content: {
                        CircleImage_Previews.state = state
                        return AnyView(CircleImage_Previews.previews)
                    },
                    name: "CircleImage",
                    type: CircleImage_Previews._allPreviews.first?.layout == .sizeThatFits ? .component : .screen,
                    device: CircleImage_Previews._allPreviews.first?.device,
                    state: String(String(reflecting: state).split(separator: ".").last!)
                )
            )
        }
        for state in GreenButton_Previews.State.allCases {
            views.append(
                PreviewModel(
                    content: {
                        GreenButton_Previews.state = state
                        return AnyView(GreenButton_Previews.previews)
                    },
                    name: "GreenButton",
                    type: GreenButton_Previews._allPreviews.first?.layout == .sizeThatFits ? .component : .screen,
                    device: GreenButton_Previews._allPreviews.first?.device,
                    state: String(String(reflecting: state).split(separator: ".").last!)
                )
            )
        }
        for state in TestViewWithoutState_Previews.State.allCases {
            views.append(
                PreviewModel(
                    content: {
                        TestViewWithoutState_Previews.state = state
                        return AnyView(TestViewWithoutState_Previews.previews)
                    },
                    name: "TestViewWithoutState",
                    type: TestViewWithoutState_Previews._allPreviews.first?.layout == .sizeThatFits ? .component : .screen,
                    device: TestViewWithoutState_Previews._allPreviews.first?.device,
                    state: String(String(reflecting: state).split(separator: ".").last!)
                )
            )
        }
        for state in TestView_Previews.State.allCases {
            views.append(
                PreviewModel(
                    content: {
                        TestView_Previews.state = state
                        return AnyView(TestView_Previews.previews)
                    },
                    name: "TestView",
                    type: TestView_Previews._allPreviews.first?.layout == .sizeThatFits ? .component : .screen,
                    device: TestView_Previews._allPreviews.first?.device,
                    state: String(String(reflecting: state).split(separator: ".").last!)
                )
            )
        }

        return views.sorted(by: { $0.name > $1.name || $0.story ?? "" > $1.story ?? "" })
    }()
}
