// Generated using Sourcery 1.8.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import XCTest
import SwiftUI
import SwiftUISystem

import SnapshotTesting
@testable import SnapshotAppSwiftUI

class SwiftUISystemTests: XCTestCase {
    private let deviceConfig: ViewImageConfig = .iPhoneX
    private let requiredDevice = "iPhone13,2"
    private let requiredOSVersion = 15

    override func setUp() {
        super.setUp()

        checkEnvironments()
        UIView.setAnimationsEnabled(false)
    }

    func test_greenButton() {
        for state in GreenButton_Previews.State.allCases {
            var curViewType: PreviewModel.ViewType = .screen

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
                matching: curViewType == .screen ? AnyView(view) : AnyView(view.frame(width: deviceConfig.size?.width).fixedSize(horizontal: false, vertical: true)),
                as: curViewType == .screen ? .image(layout: .device(config: deviceConfig)) : .image(layout: .sizeThatFits)
            )
        }
    }

    func test_testViewWithoutState() {
        for state in TestViewWithoutState_Previews.State.allCases {
            var curViewType: PreviewModel.ViewType = .screen

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
                matching: curViewType == .screen ? AnyView(view) : AnyView(view.frame(width: deviceConfig.size?.width).fixedSize(horizontal: false, vertical: true)),
                as: curViewType == .screen ? .image(layout: .device(config: deviceConfig)) : .image(layout: .sizeThatFits)
            )
        }
    }

    func test_testView() {
        for state in TestView_Previews.State.allCases {
            var curViewType: PreviewModel.ViewType = .screen

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
                matching: curViewType == .screen ? AnyView(view) : AnyView(view.frame(width: deviceConfig.size?.width).fixedSize(horizontal: false, vertical: true)),
                as: curViewType == .screen ? .image(layout: .device(config: deviceConfig)) : .image(layout: .sizeThatFits)
            )
        }
    }

    // MARK: Private

    private func checkEnvironments() {
        let deviceModel = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"]
        let osVersion = ProcessInfo().operatingSystemVersion
        guard deviceModel?.contains(requiredDevice) ?? false else {
            fatalError("Switch to using iPhone 12 for these tests.")
        }

        guard osVersion.majorVersion == requiredOSVersion else {
            fatalError("Switch to iOS \(requiredOSVersion) for these tests.")
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
