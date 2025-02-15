import Foundation
@testable import prefire
import XCTest

class GenerateTestsCommandTests: XCTestCase {
    var options: GeneratedTestsOptions!

    override func setUp() {
        super.setUp()
        options = try? GeneratedTestsOptions(
            sourcery: "sourcery",
            target: "GenerateTestsCommand",
            testTarget: "GenerateTestsCommandTests",
            template: "templatePath",
            sources: [],
            output: "User/Tests/PreviewTests.generated.swift",
            testTargetPath: "User/Tests",
            cacheBasePath: nil,
            device: nil,
            osVersion: nil,
            config: nil
        )
    }

    func test_makeArguments_sources() async {
        options.sources = ["some/sources"]
        let expectedArguments = [
            "output": options.output,
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
                "file": options.testTargetPath.flatMap({ $0 + "/PreviewTests.swift"}),
            ],
        ] as [String: Any?]

        let arguments = await GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(YAMLParser().string(from: arguments), YAMLParser().string(from: expectedArguments))
    }
    
    func test_makeArguments_snapshot_devices() async {
        options.snapshotDevices = ["iPhone 15", "iPad"]
        options.sources = ["some/sources", "some/other/sources"]

        let expectedArguments = [
            "templates": [options.template],
            "sources": ["some/sources", "some/other/sources"],
            "output": options.output,
            "args": [
                "mainTarget": "\(options.target ?? "")",
                "file": options.testTargetPath.flatMap({ $0 + "/PreviewTests.swift"}),
                "snapshotDevices": "iPhone 15|iPad",
            ]
        ] as [String: Any?]

        let arguments = await GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(YAMLParser().string(from: arguments), YAMLParser().string(from: expectedArguments))
    }
}
