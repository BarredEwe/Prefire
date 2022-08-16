// Generated using Sourcery 1.7.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import SwiftUI
import SwiftUISystem

@testable import SnapshotAppSwiftUI

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
                    state: String(String(reflecting: state).split(separator: ".").last!)
                )
            )
        }

        return views.sorted(by: { $0.name > $1.name || $0.story ?? "" > $1.story ?? "" })
    }()

    public static func loadViews() {
        PreviewModels.models.enumerated().forEach { index, viewModel in
            viewModel.content()
                .onPreferenceChange(ViewTypePreferenceKey.self) { viewType in
                    PreviewModels.models[index].type = viewType
                }
                .onPreferenceChange(UserStoryPreferenceKey.self) { userStory in
                    PreviewModels.models[index].story = userStory
                }
                .loadView()
        }
    }
}

let window: UIWindow = {
    let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
    window.isHidden = false
    return window
}()

class PreviewObservedObject: ObservableObject {}

private extension View {
    func loadView() {
        let viewController = UIHostingController(rootView: self.environmentObject(PreviewObservedObject()))
        window.rootViewController = viewController
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
    }
}
