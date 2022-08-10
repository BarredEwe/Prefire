// Generated using Sourcery 1.7.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import XCTest
import SwiftUI
import SwiftUISystem

import SnapshotTesting

class SwiftUISystemTests: XCTestCase {

    func buttonTest_test() {
        // When
        let view = ButtonTest_Previews.previews

        // Then
        assertSnapshot(matching: view, as: .image())
    }

    func testViewWithoutState_test() {
        // When
        let view = TestViewWithoutState_Previews.previews

        // Then
        assertSnapshot(matching: view, as: .image())
    }

    func testView_test() {
        // When
        let view = TestView_Previews.previews

        // Then
        assertSnapshot(matching: view, as: .image())
    }

}
