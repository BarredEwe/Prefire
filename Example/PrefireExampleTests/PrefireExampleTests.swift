import Foundation
import Prefire

// MARK: - Generated Tests

private let tests = _TestFile.self

private struct _TestFile { }

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
        XCTAssertEqual(try capture.voiceOverTranscript(), """
        SettingsScreen
          [group: Settings]
            - Notifications: On
            - Language: English
        """)
    }
}
