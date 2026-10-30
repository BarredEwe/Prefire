#if os(iOS)
import AccessibilitySnapshot
import MapKit
import Prefire
@testable import PrefireVoiceOver
import SnapshotTesting
import SwiftUI
import UIKit
import WebKit
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

    func testSystemFrameworkViewsAreNotAppNodes() {
        XCTAssertNil(VoiceOverTranscript.appTypeName(of: UIView()))
        XCTAssertNil(VoiceOverTranscript.appTypeName(of: UILabel()))
        XCTAssertNil(VoiceOverTranscript.appTypeName(of: MKMapView()))
        XCTAssertNil(VoiceOverTranscript.appTypeName(of: WKWebView()))
        XCTAssertEqual(VoiceOverTranscript.appTypeName(of: SettingsView()), "SettingsView")
    }

    /// SwiftUI structures do not become UIKit nodes; their real UIKit ancestors still count.
    func testElementsOfAHostedSwiftUIViewAreUnderItsHostingView() throws {
        // Exercise library initialization rather than relying on parser +load or test order.
        let session = PrefireSnapshotSession()
        let capture = try session.capture(PrefireSnapshot(
            { Text("Warm up") }, name: "Warm up", isScreen: true, device: session.device
        ))
        _ = try capture.voiceOverTranscript()

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
          - Ada
        """)
    }

    func testUIKitParserPipelineKeepsRealAppNodes() throws {
        let session = PrefireSnapshotSession()
        let capture = try session.capture(PrefireSnapshot(
            {
                let settings = SettingsView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
                let list = UIView(frame: settings.bounds)
                list.accessibilityContainerType = .semanticGroup
                list.accessibilityLabel = "Settings"
                let label = UILabel(frame: CGRect(x: 20, y: 20, width: 280, height: 40))
                label.isAccessibilityElement = true
                label.text = "Notifications"
                label.accessibilityLabel = "Notifications"
                label.accessibilityValue = "On"
                list.addSubview(label)
                list.accessibilityElements = [label]
                settings.addSubview(list)
                return ViewRepresentable(view: settings).frame(width: 320, height: 200)
            },
            name: "UIKit settings",
            isScreen: true,
            device: session.device
        ))
        XCTAssertEqual(try capture.voiceOverTranscript(), """
        SettingsView
          [group: Settings]
            - Notifications: On
        """)
    }

    func testColdSwiftUIReadEnablesAutomationBeforeHosting() throws {
        let root = ProcessInfo.processInfo.environment["IPHONE_SIMULATOR_ROOT"] ?? ""
        let handle = try XCTUnwrap(dlopen(root + "/usr/lib/libAccessibility.dylib", RTLD_LOCAL))
        defer { dlclose(handle) }
        let getSymbol = try XCTUnwrap(dlsym(handle, "_AXSAutomationEnabled"))
        let get = unsafeBitCast(getSymbol, to: (@convention(c) () -> Int32).self)
        let setSymbol = try XCTUnwrap(dlsym(handle, "_AXSSetAutomationEnabled"))
        let set = unsafeBitCast(setSymbol, to: (@convention(c) (Int32) -> Void).self)
        let previous = get()
        set(0)
        defer { set(previous) }
        XCTAssertEqual(get(), 0)

        let session = PrefireSnapshotSession()
        let capture = try session.capture(PrefireSnapshot(
            { Text("Ada") }, name: "Cold SwiftUI", isScreen: true, device: session.device
        ))
        XCTAssertEqual(try capture.voiceOverTranscript().components(separatedBy: "\n").first, "- Ada")
        XCTAssertNotEqual(get(), 0)
    }

    func testImageAndTextShareOneSwiftUIRenderBeforeOverlays() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = PrefireSnapshotSession()
        var renders = 0
        var label: UILabel?
        let capture = try session.capture(PrefireSnapshot({
            RenderProbe {
                renders += 1
                let view = UILabel()
                view.isAccessibilityElement = true
                view.text = "Render \(renders)"
                view.accessibilityLabel = view.text
                label = view
                return view
            }.frame(width: 200, height: 40)
        }, name: "Shared", isScreen: false, device: session.device))
        let before = renders

        let transcript = try capture.voiceOverTranscript { controller in
            XCTAssertEqual(renders, before + 1)
            label?.text = "Image changed the view"
            label?.accessibilityLabel = label?.text
            _ = verifySnapshot(
                of: controller,
                as: .accessibilityImage(showActivationPoints: .always, shouldRunInHostApplication: false),
                record: .all,
                snapshotDirectory: directory.path,
                testName: "Shared.accessibility"
            )
        }

        XCTAssertEqual(transcript.components(separatedBy: "\n").first, "- Render \(before + 1)")
        XCTAssertEqual(renders, before + 1)
        XCTAssertNotNil(UIImage(contentsOfFile: directory.appendingPathComponent("Shared-accessibility.1.png").path))
    }

    func testLegallyEmptyPreviewCanBeRead() throws {
        let session = PrefireSnapshotSession()
        let capture = try session.capture(PrefireSnapshot(
            { Text("Private").accessibilityHidden(true) },
            name: "Hidden",
            isScreen: true,
            device: session.device
        ))
        XCTAssertEqual(try capture.voiceOverTranscript(), "")
    }

    // MARK: Private

    /// First accessibility element under `object`, found the way VoiceOver walks the containers.
    private func firstElement(in object: NSObject) -> NSObject? {
        if object.isAccessibilityElement, !(object is UIView) {
            return object
        }
        let children = (object.accessibilityElements as? [NSObject])
            ?? (0 ..< max(object.accessibilityElementCount(), 0)).compactMap {
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

private struct RenderProbe: UIViewRepresentable {
    let make: () -> UILabel

    func makeUIView(context _: Context) -> UILabel {
        make()
    }

    func updateUIView(_: UILabel, context _: Context) {}
}

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

@MainActor
final class VoiceOverTranscriptLanguageTests: XCTestCase {
    /// Some SDK runtimes autofill the ambient UI language into every element (iOS 18 attaches
    /// "en-Latn-US" on an en-US system) while others leave it empty; the transcript must not
    /// depend on that, so the ambient language is omitted from the details.
    func testAmbientElementLanguageIsOmitted() {
        let ambient = Locale.current
        let spoken = [ambient.languageCode, ambient.regionCode]
            .compactMap { $0 }
            .joined(separator: "-")

        let text = VoiceOverTranscript.text(of: [
            .init(traversalIndex: 0, source: UILabel(), spokenDescription: "Home", language: spoken)
        ])

        XCTAssertEqual(text, """
        - Home
        """)
    }

    func testElementLanguageDifferentFromTheAmbientOneIsKept() {
        let foreign = Locale.current.languageCode == "ja" ? "en-NZ" : "ja-JP"

        let text = VoiceOverTranscript.text(of: [
            .init(traversalIndex: 0, source: UILabel(), spokenDescription: "Home", language: foreign)
        ])

        XCTAssertEqual(text, """
        - Home
          language: \(foreign)
        """)
    }
}
#endif
