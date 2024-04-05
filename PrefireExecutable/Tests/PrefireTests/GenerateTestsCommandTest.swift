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
            sources: [],
            output: nil,
            testTargetPath: nil,
            cacheBasePath: nil,
            device: nil,
            osVersion: nil,
            config: nil,
            verbose: false
        )
    }

    func test_makeArguments_sources() {
        options.sources = ["some/sources"]
        let expectedArguments = [
            "--output", FileManager.default.currentDirectoryPath + "/PreviewTests.generated.swift",
            "--templates", options.template,
            "--args", "mainTarget=\(options.target ?? "")",
            "--args", "file=\(FileManager.default.currentDirectoryPath)/PreviewTests.swift",
            "--sources", options.sources.first!,
        ]

        let arguments = GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(arguments, expectedArguments)
    }
    
    func test_makeArguments_snapshot_devices() {
        options.snapshotDevices = ["iPhone 15", "iPad"]
        options.sources = ["some/sources", "some/other/sources"]

        let expectedArguments = [
            "--output", FileManager.default.currentDirectoryPath + "/PreviewTests.generated.swift",
            "--templates", options.template,
            "--args", "mainTarget=\(options.target ?? "")",
            "--args", "file=\(FileManager.default.currentDirectoryPath)/PreviewTests.swift",
            "--sources", "some/sources",
            "--sources", "some/other/sources",
            "--args", "snapshotDevices=iPhone 15|iPad",
        ]

        let arguments = GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(arguments, expectedArguments)
    }
}
