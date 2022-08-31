// Generated using Sourcery 1.8.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import SwiftUI
import PreFire

@testable import PreFireExample

public enum PreviewModels {
    public static var models: [PreviewModel] = {
        var views: [PreviewModel] = []

        for state in GreenButton_Previews.State.allCases {
            views.append(
                PreviewModel(
                    content: {
                        WrapperView(
                            content: {
                                AnyView(
                                    GreenButton_Previews.previews
                                )
                            },
                            closure: {
                                GreenButton_Previews.state = state
                            }
                        )
                    },
                    name: String(String(describing: GreenButton_Previews.self).split(separator: "_").first!),
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
                    type: TestView_Previews._allPreviews.first?.layout == .sizeThatFits ? .component : .screen,
                    device: TestView_Previews._allPreviews.first?.device,
                    state: String(String(reflecting: state).split(separator: ".").last!)
                )
            )
        }

        return views.sorted(by: { $0.name > $1.name || $0.story ?? "" > $1.story ?? "" })
    }()
}

extension PreviewLayout: Equatable {
    public static func == (lhs: PreviewLayout, rhs: PreviewLayout) -> Bool {
        switch lhs {
        case .sizeThatFits:
            if case .sizeThatFits = rhs { return true }
        case .device:
            if case .device = rhs { return true }
        default: return false
        }
        return false
    }
}
