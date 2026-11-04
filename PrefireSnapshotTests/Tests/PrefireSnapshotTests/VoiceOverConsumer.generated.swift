// swiftlint:disable all
// swiftformat:disable all

import XCTest
import SwiftUI
import Prefire
import SnapshotTesting
#if os(iOS)
    import AccessibilitySnapshotParser
    import PrefireVoiceOver
#endif
#if !os(iOS)
    #warning("voiceover_snapshots lists text, which is iOS only: this platform records no VoiceOver text")
#endif

@MainActor class PreviewTests: XCTestCase {
    private let session = PrefireSnapshotSession(
        waitDefaults: SnapshotWaitDefaults()
    )

    // MARK: - PreviewProvider


    // MARK: - Macros

    func test_VoiceOverCI_Preview() {
        session.prepareEnvironment()

        assertSnapshots(for: PrefireSnapshot(
            {
                Color.white
                        .frame(width: 8, height: 8)
                        .accessibilityElement()
                        .accessibilityLabel("Generated VoiceOver")
                        .accessibilityIdentifier("voiceover-ci")
            },
            name: "VoiceOver CI",
            isScreen: false,
            device: session.device,
            fixedLayoutSize: CGSize(width: 8, height: 8)
        ))
    }

    // MARK: - SnapshotTesting

    private func assertSnapshots(of previews: [_Preview], testName: String = #function, filePath: StaticString = #filePath, line: UInt = #line) {
        for preview in previews {
            assertSnapshots(for: session.snapshot(of: preview, testName: testName), filePath: filePath, line: line)
        }
    }

    private func assertSnapshots<Content: SwiftUI.View>(for prefireSnapshot: PrefireSnapshot<Content>, filePath: StaticString = #filePath, line: UInt = #line) {
        for failure in session.failures(of: prefireSnapshot, verify: verify) {
            XCTFail(failure, file: filePath, line: line)
        }
    }

    private func verify(_ capture: PrefireSnapshotCapture) -> String? {
        let record: SnapshotTestingConfiguration.Record? = capture.record ? .all : nil

        #if os(iOS)
        do {
            let transcript = try capture.voiceOverTranscript(elements: Self.voiceOverElements, timeout: session.waitDefaults.timeout)
            if let failure = verifySnapshot(
                of: transcript,
                as: .lines,
                record: record,
                testName: capture.name + ".voiceover.text"
            ) {
                return failure
            }
        } catch {
            return "\(error)"
        }
        #endif

        return nil
    }

    #if os(iOS)
    /// What VoiceOver focuses in `view`, as AccessibilitySnapshot's parser finds it.
    private static func voiceOverElements(in view: UIView) -> [VoiceOverTranscript.Element] {
        let elements: [[VoiceOverTranscript.Element]] = AccessibilityHierarchyParser().parseAccessibilityHierarchy(
            in: view,
            makeElement: { element, traversalIndex, source in
                [VoiceOverTranscript.Element(
                    traversalIndex: traversalIndex,
                    source: source,
                    spokenDescription: element.description,
                    hint: element.hint,
                    customActions: element.customActions,
                    customContent: element.customContent.map {
                        .init(label: $0.label, value: $0.value, isImportant: $0.isImportant)
                    },
                    customRotors: element.customRotors.map {
                        .init(name: $0.name, resultCount: $0.resultMarkers.count)
                    },
                    language: element.accessibilityLanguage
                )]
            },
            makeContainer: { _, children, _ in Array(children.joined()) }
        )
        return Array(elements.joined())
    }
    #endif
}