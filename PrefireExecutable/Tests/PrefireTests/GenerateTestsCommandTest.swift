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

    func test_makeArguments_previewMacros() async {
        let currentFile = URL(filePath: #filePath, directoryHint: .notDirectory)
        let testPreview = currentFile
            .deletingLastPathComponent()
            .appending(path: "PreviewLoaderTests/TestPreview.swift", directoryHint: .notDirectory)
        options.sources = [testPreview.absoluteString]
        let expectedArguments = [
            "output": options.output,
            "sources": options.sources,
            "templates": [options.template],
            "cacheBasePath": options.cacheBasePath,
            "args": [
                "simulatorOSVersion": options.osVersion,
                "simulatorDevice": options.device,
                "snapshotDevices": options.snapshotDevices?.joined(separator: "|"),
                "previewsMacros": """
                        func test_Previewwithproperties_Preview() {
                            struct PreviewWrapperPreviewwithproperties: SwiftUI.View {
                                @State var foo: Bool = false
                                var body: some SwiftUI.View {
                                    Text("TestPreview_WithProperties")
                                }
                            }
                            if let failure = assertSnapshots(for: PrefireSnapshot(PreviewWrapperPreviewwithproperties(), name: "Preview with properties", isScreen: true, device: deviceConfig)) {
                                XCTFail(failure)
                            }
                        }
                        func test_TestPreview_1_Preview() {
                            let preview = {
                                Text("TestPreview_Prefire")
                                    .prefireEnabled()
                            }
                            if let failure = assertSnapshots(for: PrefireSnapshot(preview(), name: "TestPreview_1", isScreen: true, device: deviceConfig)) {
                                XCTFail(failure)
                            }
                        }
                        func test_TestPreview_0_Preview() {
                            let preview = {
                                Text("TestPreview")
                            }
                            if let failure = assertSnapshots(for: PrefireSnapshot(preview(), name: "TestPreview_0", isScreen: true, device: deviceConfig)) {
                                XCTFail(failure)
                            }
                        }
                """,
                "previewsMacrosDict": [
                    [
                        "body": "    Text(\"TestPreview_WithProperties\")",
                        "isScreen": true,
                        "displayName": "Preview with properties",
                        "componentTestName": "Previewwithproperties",
                        "properties": "    @State var foo: Bool = false",
                    ],
                    [
                        "body": "    Text(\"TestPreview_Prefire\")\n        .prefireEnabled()",
                        "isScreen": true,
                        "displayName": "TestPreview_1",
                        "componentTestName": "TestPreview_1",
                        "properties": nil,
                    ],
                    [
                        "body": "    Text(\"TestPreview\")",
                        "isScreen": true,
                        "displayName": "TestPreview_0",
                        "componentTestName": "TestPreview_0",
                        "properties": nil,
                    ],
                ],
                "imports": options.imports,
                "testableImports": options.testableImports,
                "mainTarget": options.target,
                "file": options.testTargetPath.flatMap({ $0 + "/PreviewTests.swift"}),
            ] as [String: Any?],
        ] as [String: Any?]

        let arguments = await GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(YAMLParser().string(from: arguments), YAMLParser().string(from: expectedArguments))
    }
}
