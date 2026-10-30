import Foundation
import PathKit
@testable import PrefireCore
import XCTest

final class VoiceOverTemplateTests: XCTestCase {
    func testTemplateAppliesVoiceOverSnapshotStrategies() async throws {
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
            let result = try await generateStrategyOutput(strategies, index: index)

            XCTAssertEqual(result.contains("import AccessibilitySnapshot\n"), image, strategies ?? "default")
            XCTAssertEqual(result.contains(imageAssertion), image, strategies ?? "default")
            XCTAssertEqual(result.contains("import PrefireVoiceOver\n"), voiceOver, strategies ?? "default")
            XCTAssertEqual(result.contains("import AccessibilitySnapshotParser\n"), voiceOver, strategies ?? "default")
            XCTAssertEqual(result.contains(voiceOverAssertion), voiceOver, strategies ?? "default")
            XCTAssertEqual(result.contains("capture.voiceOverTranscript(elements: Self.voiceOverElements, timeout:"), voiceOver, strategies ?? "default")
            XCTAssertFalse(result.contains("super.setUp"))
            XCTAssertTrue(result.contains("session.prepareEnvironment()"))
            XCTAssertEqual(result.contains("AccessibilityHierarchyParser().parseAccessibilityHierarchy("), voiceOver, strategies ?? "default")
            XCTAssertFalse(result.contains("voiceOverImageTestName"))
            XCTAssertTrue(result.contains("record: record, file: self.file,"))
            XCTAssertFalse(result.contains("record: record, file: file,"))
            if image {
                XCTAssertTrue(result.contains("testName: capture.name + \".accessibility\""))
            }
            if image, voiceOver {
                XCTAssertTrue(result.contains(
                    "capture.voiceOverTranscript(elements: Self.voiceOverElements, timeout: session.waitDefaults.timeout) { controller in"
                ))
                XCTAssertTrue(result.contains("of: controller,"))
                XCTAssertTrue(result.contains("as: .accessibilityImage(showActivationPoints: .always),"))
            }
        }
    }

    /// A configured reference file is part of every strategy case: it exercises the
    /// escaping image callback's explicit `self.file` forwarding.
    private func generateStrategyOutput(_ strategies: String?, index: Int) async throws -> String {
        let root = Path(#filePath).parent().parent().parent().parent()
        let temporary = root + "Tasks/temp/VoiceOverStrategies\(index)"
        defer { try? temporary.delete() }
        let output = temporary + "PreviewTests.generated.swift"
        var arguments: [String: NSObject] = ["file": "VoiceOverFixture.swift" as NSString]
        if let strategies {
            arguments["voiceOverSnapshots"] = strategies as NSString
        }

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [Path(fixtureTestPreviewSource)],
            output: output,
            arguments: arguments,
            inlineTemplate: EmbeddedTemplates.previewTests,
            defaultEnabled: true,
            cacheDir: temporary + "cache",
            useGroupedSnapshots: true
        )

        return try output.read(.utf8)
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
