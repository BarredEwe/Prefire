import Foundation
@testable import PrefireCore
import XCTest
import PathKit

final class VoiceOverTemplateTests: XCTestCase {
    func testTemplateAppliesVoiceOverSnapshotStrategies() async throws {
        let file = Path(fixtureTestPreviewSource)
        let imageAssertion = ".accessibilityImage(showActivationPoints: .always)"
        let voiceOverAssertion = "as: .lines,"
        let cases: [(strategies: String?, expected: (image: Bool, voiceOver: Bool))] = [
            (nil, (true, false)),
            ("image", (true, false)),
            ("text", (false, true)),
            ("image|text", (true, true)),
            ("none", (false, false))
        ]

        for (index, (strategies, (image, voiceOver))) in cases.enumerated() {
            let output = Path("/tmp/VoiceOverStrategiesPreviewTests\(index).generated.swift")

            try await PrefireGenerator.generate(
                version: "1.0.0",
                sources: [file],
                output: output,
                arguments: strategies.map { ["voiceOverSnapshots": $0 as NSString] } ?? [:],
                inlineTemplate: EmbeddedTemplates.previewTests,
                defaultEnabled: true,
                cacheDir: Path("/tmp/cache_voiceover_strategies_preview\(index)/"),
                useGroupedSnapshots: true
            )

            let result = try output.read(.utf8)

            XCTAssertEqual(result.contains("import AccessibilitySnapshot\n"), image, strategies ?? "default")
            XCTAssertEqual(result.contains(imageAssertion), image, strategies ?? "default")
            XCTAssertEqual(result.contains("import AccessibilitySnapshotParser\n"), voiceOver, strategies ?? "default")
            XCTAssertEqual(result.contains(voiceOverAssertion), voiceOver, strategies ?? "default")
            XCTAssertEqual(result.contains("VoiceOverTranscript.text(of:"), voiceOver, strategies ?? "default")
        }
    }
}
