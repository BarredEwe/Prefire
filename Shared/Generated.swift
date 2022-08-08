// Generated using Sourcery 1.7.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import SwiftUI
import SwiftUISystem

public enum UISystemViews {
    public static let views: [SystemView] = {
        var views: [SystemView] = []

        for state in TestViewWithoutState_Previews.State.allCases {
            views.append(
                SystemView(
                    content: {
                        WrapperView(
                            content: {
                                AnyView(
                                    TestViewWithoutState_Previews.previews
                                )
                            },
                            closure: {
                                TestViewWithoutState_Previews.state = state
                            }
                        )
                    },
                    name: String(String(describing: TestViewWithoutState_Previews.self).split(separator: "_").first!),
                    state: String(String(reflecting: state).split(separator: ".").last!),
                    type: TestViewWithoutState_Previews.viewType,
                    story: TestViewWithoutState_Previews.story
                )
            )
        }
        for state in TestView_Previews.State.allCases {
            views.append(
                SystemView(
                    content: {
                        WrapperView(
                            content: {
                                AnyView(
                                    TestView_Previews.previews
                                )
                            },
                            closure: {
                                TestView_Previews.state = state
                            }
                        )
                    },
                    name: String(String(describing: TestView_Previews.self).split(separator: "_").first!),
                    state: String(String(reflecting: state).split(separator: ".").last!),
                    type: TestView_Previews.viewType,
                    story: TestView_Previews.story
                )
            )
        }

        return views.sorted(by: { $0.name > $1.name || $0.type.rawValue > $1.type.rawValue || $0.story ?? "" > $1.story ?? "" })
    }()
}
