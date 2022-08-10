// Generated using Sourcery 1.7.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import XCTest
import SwiftUI
import SwiftUISystem

@testable import SnapshotAppSwiftUI

import SnapshotTesting

class SwiftUISystemTests: XCTestCase {

    func test_buttonTest() {
        for state in ButtonTest_Previews.State.allCases {
            // When
            let view = WrapperView(
                content: {
                    AnyView(
                        ButtonTest_Previews.previews
                    )
                },
                closure: {
                    ButtonTest_Previews.state = state
                }
            )

            // Then
            assertSnapshot(matching: view, as: .image(layout: .sizeThatFits))
        }
    }

    func test_testViewWithoutState() {
        for state in TestViewWithoutState_Previews.State.allCases {
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

            // Then
            assertSnapshot(matching: view, as: .image(layout: .sizeThatFits))
        }
    }

    func test_testView() {
        for state in TestView_Previews.State.allCases {
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

            // Then
            assertSnapshot(matching: view, as: .image(layout: .sizeThatFits))
        }
    }

}
