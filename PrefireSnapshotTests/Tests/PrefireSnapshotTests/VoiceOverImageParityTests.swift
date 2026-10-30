#if os(iOS)
import AccessibilitySnapshot
import Prefire
import PrefireVoiceOver
import SnapshotTesting
import SwiftUI
import XCTest

/// Turning `text` on next to `image` must not change the `-accessibility` references already recorded.
@MainActor
final class VoiceOverImageParityTests: XCTestCase {
    func testImageTakenWithTextMatchesImageTakenAlone() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = PrefireSnapshotSession()
        let capture = try session.capture(PrefireSnapshot(
            {
                VStack(alignment: .leading) {
                    Text("Top").font(.title)
                    Spacer()
                    Button("Bottom") {}
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.ignoresSafeArea())
            },
            name: "Parity",
            isScreen: true,
            device: session.device
        ))
        let strategy: Snapshotting<UIViewController, UIImage> = .accessibilityImage(
            showActivationPoints: .always,
            shouldRunInHostApplication: false
        )

        _ = verifySnapshot(
            of: capture.accessibilityController(),
            as: .wait(for: capture.delay, on: strategy),
            record: .all,
            snapshotDirectory: directory.path,
            testName: "Alone"
        )
        _ = try capture.voiceOverTranscript(accessibilityImage: { controller in
            _ = verifySnapshot(of: controller, as: strategy, record: .all, snapshotDirectory: directory.path, testName: "WithText")
        })

        let alone = try Data(contentsOf: directory.appendingPathComponent("Alone.1.png"))
        let withText = try Data(contentsOf: directory.appendingPathComponent("WithText.1.png"))
        XCTAssertEqual(alone, withText)
    }
}
#endif
