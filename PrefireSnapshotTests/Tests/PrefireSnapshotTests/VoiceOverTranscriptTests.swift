#if os(iOS)
@testable import Prefire
import SwiftUI
import UIKit
import XCTest

@MainActor
final class VoiceOverTranscriptTests: XCTestCase {
    func testElementsAreListedUnderTheViewsOfTheAppThatHoldThem() {
        let settings = SettingsView()
        let list = SettingsList()
        list.accessibilityContainerType = .list
        let first = SettingsRow()
        let second = SettingsRow()
        let footer = UILabel()
        settings.add(list, footer)
        list.add(first, second)
        let notifications = UILabel()
        let language = UILabel()
        first.add(notifications)
        second.add(language)

        let text = VoiceOverTranscript.text(of: [
            .init(traversalIndex: 2, source: footer, spokenDescription: ""),
            .init(
                traversalIndex: 0,
                source: notifications,
                spokenDescription: "Notifications. Button.",
                customContent: [.init(label: "", value: "3 unread", isImportant: true)]
            ),
            .init(traversalIndex: 1, source: language, spokenDescription: "Language. Button.", hint: "Opens a list.")
        ])

        XCTAssertEqual(text, """
        SettingsView
          SettingsList
            [list]
              SettingsRow
                - Notifications. Button. 3 unread
              SettingsRow
                - Language. Button. Opens a list.
          -
        """)
    }

    func testViewThatHoldsOtherElementsIsANodeAboveItsOwnPhrase() {
        let row = SettingsRow()
        let badge = UILabel()
        row.add(badge)

        let text = VoiceOverTranscript.text(of: [
            .init(traversalIndex: 0, source: row, spokenDescription: "Privacy. Button."),
            .init(traversalIndex: 1, source: badge, spokenDescription: "New")
        ])

        XCTAssertEqual(text, """
        SettingsRow
          - Privacy. Button.
          - New
        """)
    }

    func testAnnouncedContainersModalViewsAndDetails() {
        let root = UIView()
        let group = UIView()
        group.accessibilityContainerType = .semanticGroup
        group.accessibilityLabel = "Delivery"
        let unnamedGroup = UIView()
        unnamedGroup.accessibilityContainerType = .semanticGroup
        let sheet = UIView()
        sheet.accessibilityViewIsModal = true
        let tabs = UIView()
        tabs.accessibilityTraits = .tabBar
        root.add(group, sheet, tabs)
        group.add(unnamedGroup)

        let address = UILabel()
        address.accessibilityTraits = [.staticText, .updatesFrequently]
        unnamedGroup.add(address)
        let element = UIAccessibilityElement(accessibilityContainer: sheet)
        let tab = UILabel()
        tabs.add(tab)

        let text = VoiceOverTranscript.text(of: [
            .init(
                traversalIndex: 0,
                source: address,
                spokenDescription: "Home",
                customActions: ["Edit", "Delete"],
                customContent: [.init(label: "Floor", value: "3"), .init(label: "Door", value: "7")],
                customRotors: [.init(name: "Headings", resultCount: 2)],
                language: "en"
            ),
            .init(traversalIndex: 1, source: element, spokenDescription: "Close. Button."),
            .init(traversalIndex: 2, source: tab, spokenDescription: "Home. Tab. 1 of 2.")
        ])

        XCTAssertEqual(text, """
        [group: Delivery]
          - Home
            actions: Edit, Delete
            custom content: Floor: 3; Door: 7
            rotor "Headings": 2
            traits: updates frequently
            language: en
        UIView (modal)
          - Close. Button.
        [tab bar]
          - Home. Tab. 1 of 2.
        """)
    }

    func testNodesAreTheTypesOfTheApp() {
        XCTAssertEqual(VoiceOverTranscript.appTypeName("App.ProfileView"), "ProfileView")
        XCTAssertEqual(VoiceOverTranscript.appTypeName("App.Wrapper<App.ProfileView>"), "Wrapper")
        XCTAssertEqual(VoiceOverTranscript.appTypeName("App.(unknown context at $10a0c).ProfileView"), "ProfileView")
        XCTAssertEqual(VoiceOverTranscript.appTypeName("SwiftUI._UIHostingView<App.ProfileView>"), "ProfileView")
        XCTAssertEqual(VoiceOverTranscript.appTypeName("App.Profile_View"), "Profile_View")
        XCTAssertEqual(VoiceOverTranscript.appTypeName("ThirdParty.Badge"), "Badge")
        XCTAssertNil(VoiceOverTranscript.appTypeName("SwiftUI._UIHostingView<SwiftUI.AnyView>"))
        XCTAssertNil(VoiceOverTranscript.appTypeName("SwiftUI.PlatformViewHost<App.ProfileView>"))
        XCTAssertNil(VoiceOverTranscript.appTypeName("UILabel"))
        XCTAssertNil(VoiceOverTranscript.appTypeName("Prefire.SnapshotCanvasWindow"))
        XCTAssertNil(VoiceOverTranscript.appTypeName("App._ProfileView"))
    }

    /// Elements of SwiftUI are not views: their path goes up `accessibilityContainer` to the hosting
    /// view, which is named after the view it hosts.
    func testElementsOfAHostedSwiftUIViewAreUnderItsHostingView() throws {
        // SwiftUI builds its accessibility elements only while accessibility is on. In the generated
        // tests AccessibilitySnapshotParser turns it on when it loads; this target does not link it.
        try enableAccessibilityAutomation()

        let profile = ProfileContainer(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let controller = UIHostingController(rootView: ProfileCard())
        controller.view.frame = profile.bounds
        profile.add(controller.view)
        let window = UIWindow(frame: profile.frame)
        window.addSubview(profile)
        window.isHidden = false
        defer { window.isHidden = true }
        profile.layoutIfNeeded()

        var element: NSObject?
        let deadline = Date(timeIntervalSinceNow: 2)
        while element == nil, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            element = firstElement(in: controller.view)
        }
        let hosted = try XCTUnwrap(element)
        XCTAssertFalse(hosted is UIView)

        let text = VoiceOverTranscript.text(of: [.init(traversalIndex: 0, source: hosted, spokenDescription: "Ada")])

        XCTAssertEqual(text, """
        ProfileContainer
          ProfileCard
            - Ada
        """)
    }

    // MARK: Private

    /// Turns on accessibility automation for the rest of the tests, as AccessibilitySnapshotParser does.
    private func enableAccessibilityAutomation() throws {
        var path = "/usr/lib/libAccessibility.dylib"
        if let simulatorRoot = ProcessInfo.processInfo.environment["IPHONE_SIMULATOR_ROOT"] {
            path = simulatorRoot + path
        }
        let handle = try XCTUnwrap(dlopen(path, RTLD_LOCAL), "Could not load \(path)")
        let symbol = try XCTUnwrap(dlsym(handle, "_AXSSetAutomationEnabled"))
        unsafeBitCast(symbol, to: (@convention(c) (Int32) -> Void).self)(1)
    }

    /// First accessibility element under `object`, found the way VoiceOver walks the containers.
    private func firstElement(in object: NSObject) -> NSObject? {
        if object.isAccessibilityElement, !(object is UIView) {
            return object
        }
        let children = (object.accessibilityElements as? [NSObject])
            ?? (0..<max(object.accessibilityElementCount(), 0)).compactMap {
                object.accessibilityElement(at: $0) as? NSObject
            }
        let subviews = (object as? UIView)?.subviews ?? []
        for child in children + subviews {
            if let element = firstElement(in: child) {
                return element
            }
        }
        return nil
    }
}

private final class SettingsView: UIView {}
private final class SettingsList: UIView {}
private final class SettingsRow: UIView {}
private final class ProfileContainer: UIView {}

private struct ProfileCard: View {
    var body: some View {
        Text("Ada")
    }
}

private extension UIView {
    func add(_ views: UIView...) {
        views.forEach(addSubview)
    }
}
#endif
