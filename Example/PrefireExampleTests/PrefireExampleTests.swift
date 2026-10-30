import Foundation
import Prefire

// MARK: - Generated Tests

private let tests = _TestFile.self

private struct _TestFile { }

import AccessibilitySnapshotParser
import PrefireVoiceOver
import SwiftUI
import XCTest
@testable import PrefireExample

@MainActor
final class UIKitVoiceOverTests: XCTestCase {
    func testUIKitExampleHasRealAppNodes() throws {
        let session = PrefireSnapshotSession()
        let capture = try session.capture(PrefireSnapshot(
            { ViewRepresentable(view: SettingsScreen()).frame(width: 320, height: 200) },
            name: "UIKit settings",
            isScreen: true,
            device: session.device
        ))
        let transcript = try capture.voiceOverTranscript { view in
            let elements: [[VoiceOverTranscript.Element]] = AccessibilityHierarchyParser().parseAccessibilityHierarchy(
                in: view,
                makeElement: { element, traversalIndex, source in
                    [.init(traversalIndex: traversalIndex, source: source, spokenDescription: element.description)]
                },
                makeContainer: { _, children, _ in Array(children.joined()) }
            )
            return Array(elements.joined())
        }
        XCTAssertEqual(transcript, """
        SettingsScreen
          [group: Settings]
            - Notifications: On
            - Language: English
        """)
    }
}
