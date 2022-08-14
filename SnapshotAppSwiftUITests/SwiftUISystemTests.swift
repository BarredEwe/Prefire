// Generated using Sourcery 1.7.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import XCTest
import SwiftUI
import SwiftUISystem

@testable import SnapshotAppSwiftUI

import SnapshotTesting

class SwiftUISystemTests: XCTestCase {

    func test_greenButton() {
        for state in GreenButton_Previews.State.allCases {
            var curViewType: SystemViewModel.ViewType = .screen

            // When
            let view = WrapperView(
                content: {
                    AnyView(
                        GreenButton_Previews.previews
                    )
                },
                closure: {
                    GreenButton_Previews.state = state
                }
            )
            .onPreferenceChange(ViewTypePreferenceKey.self) { viewType in
                curViewType = viewType
            }

            view.loadPreferences()

            // Then
            assertSnapshot(
                matching: curViewType == .screen ? AnyView(view) : AnyView(view.fixedSize()),
                as: curViewType == .screen ? .image(layout: .device(config: .iPhoneX)) : .image(layout: .sizeThatFits)
            )
        }
    }

    func test_testViewWithoutState() {
        for state in TestViewWithoutState_Previews.State.allCases {
            var curViewType: SystemViewModel.ViewType = .screen

            // When
            let view = WrapperView(
                content: {
                    AnyView(
                        TestViewWithoutState_Previews.previews
                    )
                },
                closure: {
                    TestViewWithoutState_Previews.state = state
                }
            )
            .onPreferenceChange(ViewTypePreferenceKey.self) { viewType in
                curViewType = viewType
            }

            view.loadPreferences()

            // Then
            assertSnapshot(
                matching: curViewType == .screen ? AnyView(view) : AnyView(view.fixedSize()),
                as: curViewType == .screen ? .image(layout: .device(config: .iPhoneX)) : .image(layout: .sizeThatFits)
            )
        }
    }

    func test_testView() {
        for state in TestView_Previews.State.allCases {
            var curViewType: SystemViewModel.ViewType = .screen

            // When
            let view = WrapperView(
                content: {
                    AnyView(
                        TestView_Previews.previews
                    )
                },
                closure: {
                    TestView_Previews.state = state
                }
            )
            .onPreferenceChange(ViewTypePreferenceKey.self) { viewType in
                curViewType = viewType
            }

            view.loadPreferences()

            // Then
            assertSnapshot(
                matching: curViewType == .screen ? AnyView(view) : AnyView(view.fixedSize()),
                as: curViewType == .screen ? .image(layout: .device(config: .iPhoneX)) : .image(layout: .sizeThatFits)
            )
        }
    }

}

private extension View {
    func loadPreferences() {
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
        window.isHidden = false
        let viewController = UIHostingController(rootView: self)
        window.rootViewController = viewController
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
    }
}
