// Generated using Sourcery 1.8.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all
// swiftformat:disable all

import XCTest
import SwiftUI
import PreFire

import SnapshotTesting
@testable import PreFireExample

class SwiftUISystemTests: XCTestCase {
    private let deviceConfig: ViewImageConfig = .iPhoneX
    private let simulatorDevice = "iPhone13,2"
    private let requiredOSVersion = 15

    override func setUp() {
        super.setUp()

        checkEnvironments()
        UIView.setAnimationsEnabled(false)
    }

    func test_greenButton() {
        for state in GreenButton_Previews.State.allCases {
            let type: PreviewModel.ViewType = GreenButton_Previews._allPreviews.first?.layout == .sizeThatFits ? .component : .screen
            let device = TestView_Previews._allPreviews.first?.device?.snapshotDevice() ?? deviceConfig

            // When
            GreenButton_Previews.state = state
            let view = GreenButton_Previews.previews

            // Then
            assertSnapshot(
                matching: type == .screen ? AnyView(view) : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true)),
                as: type == .screen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits)
            )
        }
    }

    func test_testViewWithoutState() {
        for state in TestViewWithoutState_Previews.State.allCases {
            let type: PreviewModel.ViewType = TestViewWithoutState_Previews._allPreviews.first?.layout == .sizeThatFits ? .component : .screen
            let device = TestView_Previews._allPreviews.first?.device?.snapshotDevice() ?? deviceConfig

            // When
            TestViewWithoutState_Previews.state = state
            let view = TestViewWithoutState_Previews.previews

            // Then
            assertSnapshot(
                matching: type == .screen ? AnyView(view) : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true)),
                as: type == .screen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits)
            )
        }
    }

    func test_testView() {
        for state in TestView_Previews.State.allCases {
            let type: PreviewModel.ViewType = TestView_Previews._allPreviews.first?.layout == .sizeThatFits ? .component : .screen
            let device = TestView_Previews._allPreviews.first?.device?.snapshotDevice() ?? deviceConfig

            // When
            TestView_Previews.state = state
            let view = TestView_Previews.previews

            // Then
            assertSnapshot(
                matching: type == .screen ? AnyView(view) : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true)),
                as: type == .screen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits)
            )
        }
    }

    // MARK: Private

    private func checkEnvironments() {
        let deviceModel = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"]
        let osVersion = ProcessInfo().operatingSystemVersion
        guard deviceModel?.contains(simulatorDevice) ?? false else {
            fatalError("Switch to using iPhone 12 for these tests.")
        }

        guard osVersion.majorVersion == requiredOSVersion else {
            fatalError("Switch to iOS \(requiredOSVersion) for these tests.")
        }
    }
}

private extension PreviewDevice {
    func snapshotDevice() -> ViewImageConfig? {
        switch rawValue {
        case "iPhone 12", "iPhone 11", "iPhone 10":
            return .iPhoneX
        case "iPhone 6", "iPhone 6s", "iPhone 7", "iPhone 8":
            return .iPhone8
        case "iPhone 6 Plus", "iPhone 6s Plus", "iPhone 8 Plus":
            return .iPhone8Plus
        case "iPhone SE (1st generation)", "iPhone SE (2nd generation)":
            return .iPhoneSe
        default: return nil
        }
    }
}
