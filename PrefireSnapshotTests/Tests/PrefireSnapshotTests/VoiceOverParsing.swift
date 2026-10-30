#if os(iOS)
import AccessibilitySnapshotParser
import Prefire
import PrefireVoiceOver
import UIKit

/// The parsing the generated tests do, so these tests read previews the same way.
/// `VoiceOverConsumer.generated.swift` checks the template's own copy end to end.
@MainActor
extension PrefireSnapshotCapture {
    func voiceOverTranscript(
        timeout: TimeInterval = SnapshotWaitDefaults().timeout,
        accessibilityImage: ((UIViewController) throws -> Void)? = nil
    ) throws -> String {
        try voiceOverTranscript(elements: voiceOverElements, timeout: timeout, accessibilityImage: accessibilityImage)
    }
}

@MainActor
func voiceOverElements(in view: UIView) -> [VoiceOverTranscript.Element] {
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
