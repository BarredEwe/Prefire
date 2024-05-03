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
            config: nil
        )
    }

    func test_makeArguments_sources() {
        options.sources = ["some/sources"]
        let expectedArguments = [
            "output": FileManager.default.currentDirectoryPath + "/PreviewTests.generated.swift",
            "sources": options.sources,
            "templates": [options.template],
            "cacheBasePath": options.cacheBasePath,
            "args": [
                "simulatorOSVersion": options.osVersion,
                "simulatorDevice": options.device,
                "snapshotDevices": options.snapshotDevices?.joined(separator: "|"),
                "previewsMacros": nil,
                "imports": options.imports,
                "testableImports": options.testableImports,
                "mainTarget": options.target,
                "file": "\(FileManager.default.currentDirectoryPath)/PreviewTests.swift",
            ],
        ] as [String: Any?]

        let arguments = GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(YAMLParser().string(from: arguments), YAMLParser().string(from: expectedArguments))
    }
    
    func test_makeArguments_snapshot_devices() {
        options.snapshotDevices = ["iPhone 15", "iPad"]
        options.sources = ["some/sources", "some/other/sources"]

        let expectedArguments = [
            "templates": [options.template],
            "sources": ["some/sources", "some/other/sources"],
            "output": FileManager.default.currentDirectoryPath + "/PreviewTests.generated.swift",
            "args": [
                "mainTarget": "\(options.target ?? "")",
                "file": "\(FileManager.default.currentDirectoryPath)/PreviewTests.swift",
                "snapshotDevices": "iPhone 15|iPad",
            ]
        ] as [String: Any?]

        let arguments = GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(YAMLParser().string(from: arguments), YAMLParser().string(from: expectedArguments))
    }
}
