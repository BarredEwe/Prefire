import Foundation
import PathKit
@testable import PrefireCore
import XCTest

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
            ("none", (false, false)),
            ("notimage|nottext", (false, false))
        ]

        for (index, (strategies, (image, voiceOver))) in cases.enumerated() {
            let root = Path(#filePath).parent().parent().parent().parent()
            let temporary = root + "Tasks/temp/VoiceOverStrategies\(index)"
            defer { try? temporary.delete() }
            let output = temporary + "PreviewTests.generated.swift"

            try await PrefireGenerator.generate(
                version: "1.0.0",
                sources: [file],
                output: output,
                arguments: strategies.map { ["voiceOverSnapshots": $0 as NSString] } ?? [:],
                inlineTemplate: EmbeddedTemplates.previewTests,
                defaultEnabled: true,
                cacheDir: temporary + "cache",
                useGroupedSnapshots: true
            )

            let result = try output.read(.utf8)

            XCTAssertEqual(result.contains("import AccessibilitySnapshot\n"), image, strategies ?? "default")
            XCTAssertEqual(result.contains(imageAssertion), image, strategies ?? "default")
            XCTAssertEqual(result.contains("import PrefireVoiceOver\n"), voiceOver, strategies ?? "default")
            XCTAssertEqual(result.contains(voiceOverAssertion), voiceOver, strategies ?? "default")
            XCTAssertEqual(result.contains("capture.voiceOverTranscript(timeout:"), voiceOver, strategies ?? "default")
            XCTAssertFalse(result.contains("parseAccessibilityHierarchy"))
            XCTAssertFalse(result.contains("voiceOverImageTestName"))
            if image {
                XCTAssertTrue(result.contains("testName: capture.name + \".accessibility\""))
            }
        }
    }

    func testGeneratedTextConsumerMatchesTheCompiledFixture() async throws {
        let root = Path(#filePath).parent().parent().parent().parent()
        let temporary = root + "Tasks/temp/VoiceOverConsumer"
        defer { try? temporary.delete() }
        let output = temporary + "PreviewTests.generated.swift"
        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [Path(fixtureVoiceOverConsumerSource)],
            output: output,
            arguments: ["voiceOverSnapshots": "text" as NSString],
            inlineTemplate: EmbeddedTemplates.previewTests,
            defaultEnabled: true,
            cacheDir: temporary + "cache",
            useGroupedSnapshots: true
        )
        let compiled = root + "PrefireSnapshotTests/Tests/PrefireSnapshotTests/VoiceOverConsumer.generated.swift"
        XCTAssertEqual(try output.read(.utf8), try compiled.read(.utf8))
    }
}
