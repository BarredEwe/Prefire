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
                defaultEnabled: true,
                useGroupedSnapshots: true,
                recordInDarkMode: false
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
            cacheDir: cache,
            useGroupedSnapshots: true,
            recordInDarkMode: false
        )

        let result = try output.read(.utf8)

        XCTAssertTrue(result.contains("TestPreview"), "Should include basic preview")
        XCTAssertFalse(result.contains("TestPreview_Ignored"), "Should skip explicitly ignored preview")
    }
    
    func testUngroupedFileGeneration() async throws {
        let file = Path(fixtureTestPreviewSource)
        let outputTemplate = Path("/tmp/{PREVIEW_FILE_NAME}Tests.generated.swift")
        let cache = Path("/tmp/cache/")
        let template = "// File: {PREVIEW_FILE_NAME}\n{% for p in argument.previewsMacrosDict %}{{ p.componentTestName }}\n{% endfor %}"
        let args: [String: NSObject] = [:]
        
        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: outputTemplate,
            arguments: args,
            inlineTemplate: template,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: false, // Test ungrouped generation
            recordInDarkMode: false
        )

        // Should generate file with name based on the fixture file
        let expectedOutput = Path("/tmp/TestPreviewTests.generated.swift")
        XCTAssertTrue(expectedOutput.exists, "Should generate file with replaced filename")
        
        let result = try expectedOutput.read(.utf8)
        XCTAssertTrue(result.contains("// File: TestPreview"), "Should replace {PREVIEW_FILE_NAME} placeholder")
        XCTAssertTrue(result.contains("TestPreview"), "Should include basic preview")
    }
    
    func testGroupedFileGenerationUsesCorrectClassName() async throws {
        let file = Path(fixtureTestPreviewSource)
        let outputTemplate = Path("/tmp/GroupedTests.generated.swift")
        let cache = Path("/tmp/cache/")
        let template = "class {PREVIEW_FILE_NAME}Tests: XCTestCase { }"
        let args: [String: NSObject] = [:]
        
        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: outputTemplate,
            arguments: args,
            inlineTemplate: template,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true, // Test grouped generation
            recordInDarkMode: false
        )

        // Should generate file with Preview as class name for grouped snapshots
        let expectedOutput = Path("/tmp/GroupedTests.generated.swift")
        XCTAssertTrue(expectedOutput.exists, "Should generate grouped file")
        
        let result = try expectedOutput.read(.utf8)
        XCTAssertTrue(result.contains("class PreviewTests: XCTestCase"), "Should use 'Preview' as class name for grouped snapshots")
    }
    
    func testUngroupedFileGenerationUsesFileNameInClassName() async throws {
        let file = Path(fixtureTestPreviewSource)
        let outputTemplate = Path("/tmp/{PREVIEW_FILE_NAME}Tests.generated.swift")
        let cache = Path("/tmp/cache/")
        let template = "class {PREVIEW_FILE_NAME}Tests: XCTestCase { }"
        let args: [String: NSObject] = [:]
        
        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: outputTemplate,
            arguments: args,
            inlineTemplate: template,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: false, // Test ungrouped generation
            recordInDarkMode: false
        )

        // Should generate file with source file name as class name for ungrouped snapshots
        let expectedOutput = Path("/tmp/TestPreviewTests.generated.swift")
        XCTAssertTrue(expectedOutput.exists, "Should generate ungrouped file with filename")
        
        let result = try expectedOutput.read(.utf8)
        XCTAssertTrue(result.contains("class TestPreviewTests: XCTestCase"), "Should use source file name as class name for ungrouped snapshots")
    }
}
