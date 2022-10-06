// Generated using Sourcery 1.8.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all
// swiftformat:disable all

import XCTest
import SwiftUI
import Prefire

import SnapshotTesting
import AccessibilitySnapshot
@testable import PrefireExample

class PreviewTests: XCTestCase {
    private let deviceConfig: ViewImageConfig = .iPhoneX
    private let simulatorDevice = "iPhone13,2"
    private let requiredOSVersion = 15

    override func setUp() {
        super.setUp()

        checkEnvironments()
        UIView.setAnimationsEnabled(false)
    }

    func test_authView_Preview() {
        for view in AuthView_Preview._allPreviews {
            // Given
            let preview = AuthView_Preview._allPreviews.first
            let isScreen = preview?.layout == .device
            let device = preview?.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = view.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits)
            )
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(matching: vc, as: .accessibilityImage(showActivationPoints: .always))
        }
    }

    func test_circleImage() {
        for view in CircleImage_Previews._allPreviews {
            // Given
            let preview = CircleImage_Previews._allPreviews.first
            let isScreen = preview?.layout == .device
            let device = preview?.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = view.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits)
            )
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(matching: vc, as: .accessibilityImage(showActivationPoints: .always))
        }
    }

    func test_greenButton() {
        for view in GreenButton_Previews._allPreviews {
            // Given
            let preview = GreenButton_Previews._allPreviews.first
            let isScreen = preview?.layout == .device
            let device = preview?.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = view.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits)
            )
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(matching: vc, as: .accessibilityImage(showActivationPoints: .always))
        }
    }

    func test_prefireView_Preview() {
        for view in PrefireView_Preview._allPreviews {
            // Given
            let preview = PrefireView_Preview._allPreviews.first
            let isScreen = preview?.layout == .device
            let device = preview?.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = view.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits)
            )
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(matching: vc, as: .accessibilityImage(showActivationPoints: .always))
        }
    }

    func test_testViewWithoutState() {
        for view in TestViewWithoutState_Previews._allPreviews {
            // Given
            let preview = TestViewWithoutState_Previews._allPreviews.first
            let isScreen = preview?.layout == .device
            let device = preview?.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = view.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits)
            )
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(matching: vc, as: .accessibilityImage(showActivationPoints: .always))
        }
    }

    func test_testView() {
        for view in TestView_Previews._allPreviews {
            // Given
            let preview = TestView_Previews._allPreviews.first
            let isScreen = preview?.layout == .device
            let device = preview?.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = view.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits)
            )
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(matching: vc, as: .accessibilityImage(showActivationPoints: .always))
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
