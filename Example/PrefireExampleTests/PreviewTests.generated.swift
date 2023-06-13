// Generated using Sourcery 2.0.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all
// swiftformat:disable all

import XCTest
import SwiftUI
import Prefire

import SnapshotTesting
#if canImport(AccessibilitySnapshot)
    import AccessibilitySnapshot
#endif
@testable import PrefireExample

class PreviewTests: XCTestCase {
    private let deviceConfig: ViewImageConfig = .iPhoneX
    private let simulatorDevice = "iPhone15,2"
    private let requiredOSVersion = 16

    override func setUp() {
        super.setUp()

        checkEnvironments()
        UIView.setAnimationsEnabled(false)
    }

    func test_authView_Preview() {
        for preview in AuthView_Preview._allPreviews {
            // Given
            let isScreen = preview.layout == .device
            let device = preview.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = preview.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits),
                named: preview.displayName
            )
#if canImport(AccessibilitySnapshot)
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(
                matching: vc,
                as: .accessibilityImage(showActivationPoints: .always),
                named: preview.displayName.map { $0 + ".accessibility" }
            )
#endif
        }
    }

    func test_circleImage() {
        for preview in CircleImage_Previews._allPreviews {
            // Given
            let isScreen = preview.layout == .device
            let device = preview.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = preview.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits),
                named: preview.displayName
            )
#if canImport(AccessibilitySnapshot)
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(
                matching: vc,
                as: .accessibilityImage(showActivationPoints: .always),
                named: preview.displayName.map { $0 + ".accessibility" }
            )
#endif
        }
    }

    func test_greenButton() {
        for preview in GreenButton_Previews._allPreviews {
            // Given
            let isScreen = preview.layout == .device
            let device = preview.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = preview.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits),
                named: preview.displayName
            )
#if canImport(AccessibilitySnapshot)
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(
                matching: vc,
                as: .accessibilityImage(showActivationPoints: .always),
                named: preview.displayName.map { $0 + ".accessibility" }
            )
#endif
        }
    }

    func test_prefireView_Preview() {
        for preview in PrefireView_Preview._allPreviews {
            // Given
            let isScreen = preview.layout == .device
            let device = preview.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = preview.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits),
                named: preview.displayName
            )
#if canImport(AccessibilitySnapshot)
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(
                matching: vc,
                as: .accessibilityImage(showActivationPoints: .always),
                named: preview.displayName.map { $0 + ".accessibility" }
            )
#endif
        }
    }

    func test_testViewWithoutState() {
        for preview in TestViewWithoutState_Previews._allPreviews {
            // Given
            let isScreen = preview.layout == .device
            let device = preview.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = preview.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits),
                named: preview.displayName
            )
#if canImport(AccessibilitySnapshot)
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(
                matching: vc,
                as: .accessibilityImage(showActivationPoints: .always),
                named: preview.displayName.map { $0 + ".accessibility" }
            )
#endif
        }
    }

    func test_testView() {
        for preview in TestView_Previews._allPreviews {
            // Given
            let isScreen = preview.layout == .device
            let device = preview.device?.snapshotDevice() ?? deviceConfig

            // When
            var view = preview.content
            view = isScreen ? view : AnyView(view.frame(width: device.size?.width).fixedSize(horizontal: false, vertical: true))

            // Then
            assertSnapshot(
                matching: view,
                as: isScreen ? .image(layout: .device(config: device)) : .image(layout: .sizeThatFits),
                named: preview.displayName
            )
#if canImport(AccessibilitySnapshot)
            let vc = UIHostingController(rootView: view)
            vc.view.frame = UIScreen.main.bounds
            assertSnapshot(
                matching: vc,
                as: .accessibilityImage(showActivationPoints: .always),
                named: preview.displayName.map { $0 + ".accessibility" }
            )
#endif
        }
    }

    // MARK: Private

    private func checkEnvironments() {
        let deviceModel = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"]
        let osVersion = ProcessInfo().operatingSystemVersion
        guard deviceModel?.contains(simulatorDevice) ?? false else {
            fatalError("Switch to using \(simulatorDevice) for these tests.")
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
