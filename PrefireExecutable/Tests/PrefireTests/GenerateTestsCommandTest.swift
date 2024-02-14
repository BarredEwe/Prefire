import Foundation
@testable import prefire
import XCTest

class GenerateTestsCommandTests: XCTestCase {
    var options: GeneratedTestsOptions!

    override func setUp() {
        super.setUp()
        options = GeneratedTestsOptions(
            sourcery: "sourcery",
            target: "GenerateTestsCommand",
            testTarget: "GenerateTestsCommandTests",
            template: "templatePath",
            sources: nil,
            output: nil, 
            testTargetPath: nil,
            cacheBasePath: nil,
            device: nil,
            osVerison: nil,
            config: nil,
            verbose: false
        )
    }

    func test_makeArguments_sources() {
        options.sources = "some/sources"
        let expectedArguments = [
            "--sources", options.sources,
            "--output", FileManager.default.currentDirectoryPath + "/PreviewTests.generated.swift",
            "--templates", options.template,
            "--args", "mainTarget=\(options.target ?? "")",
            "--args", "file=\(FileManager.default.currentDirectoryPath)/PreviewTests.swift"
        ]

        let arguments = GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(arguments, expectedArguments)
    }
}
