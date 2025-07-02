import Foundation
@testable import PrefireCore
import XCTest
import PathKit

final class PrefireGeneratorTests: XCTestCase {
    func testEmptySourcesDoesNotCrash() async throws {
        let output = Path(fixtureTestPreviewSource)
        let template = "Generated with {{ types.count }} types"
        let args: [String: NSObject] = [:]

        do {
            try await PrefireGenerator.generate(
                version: "1.0.0",
                sources: [],
                output: output,
                arguments: args,
                inlineTemplate: template,
                defaultEnabled: true
            )
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }

    func testPreviewFilteringAndParsing() async throws {
        let file = Path(fixtureTestPreviewSource)
        let output = Path("/tmp/generated_previews.swift")
        let cache = Path("/tmp/cache/")
        let template = "{% for p in argument.previewsMacrosDict %}{{ p.componentTestName }}\n{% endfor %}"
        let args: [String: NSObject] = [:]
        
        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: output,
            arguments: args,
            inlineTemplate: template,
            defaultEnabled: true,
            cacheDir: cache
        )

        let result = try output.read(.utf8)

        XCTAssertTrue(result.contains("TestPreview"), "Should include basic preview")
        XCTAssertFalse(result.contains("TestPreview_Ignored"), "Should skip explicitly ignored preview")
    }
}
