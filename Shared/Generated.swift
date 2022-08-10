// Generated using Sourcery 1.7.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import SwiftUI
import SwiftUISystem

public enum UISystemViews {
    public static let views: [SystemViewModel] = {
        var views: [SystemViewModel] = []

        for state in ButtonTest_Previews.State.allCases {
            views.append(
                SystemViewModel(
                    content: {
                        WrapperView(
                            content: {
                                AnyView(
                                    ButtonTest_Previews.previews
                                )
                            },
                            closure: {
                                ButtonTest_Previews.state = state
                            }
                        )
                    },
                    name: String(String(describing: ButtonTest_Previews.self).split(separator: "_").first!),
                    state: String(String(reflecting: state).split(separator: ".").last!)
                )
            )
        }
        for state in TestViewWithoutState_Previews.State.allCases {
            views.append(
                SystemViewModel(
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
                    state: String(String(reflecting: state).split(separator: ".").last!)
                )
            )
        }
        for state in TestView_Previews.State.allCases {
            views.append(
                SystemViewModel(
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
                    state: String(String(reflecting: state).split(separator: ".").last!)
                )
            )
        }

        return views.sorted(by: { $0.name > $1.name || $0.story ?? "" > $1.story ?? "" })
    }()
}
