import Foundation
@testable import prefire
import XCTest
import PathKit

class GenerateTestsCommandTests: XCTestCase {
    var options: GeneratedTestsOptions!

    override func setUp() {
        super.setUp()
        options = try? GeneratedTestsOptions(
            target: "GenerateTestsCommand",
            testTarget: "GenerateTestsCommandTests",
            template: nil,
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
            "mainTarget": options.target! as NSString,
            "file": options.testTargetPath.flatMap({ $0 + "PreviewTests.generated.swift"})!.string as NSString,
            "drawHierarchyInKeyWindowDefaultEnabled": "false" as NSString,
        ] as [String: NSObject]

        let arguments = await GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(YAMLParser().string(from: arguments), YAMLParser().string(from: expectedArguments))
    }
    
    func test_makeArguments_snapshot_devices() async {
        options.snapshotDevices = ["iPhone 15", "iPad"]
        options.sources = ["some/sources", "some/other/sources"]

        let expectedArguments = [
            "mainTarget": "\(options.target ?? "")" as NSString,
            "file": options.testTargetPath.flatMap({ $0 + "PreviewTests.generated.swift"})!.string as NSString,
            "snapshotDevices": "iPhone 15|iPad" as NSString,
            "drawHierarchyInKeyWindowDefaultEnabled": "false" as NSString,
        ] as [String: NSObject]

        let arguments = await GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(YAMLParser().string(from: arguments), YAMLParser().string(from: expectedArguments))
    }
    
    func test_makeArguments_drawHierarchyInKeyWindowDefaultEnabled() async {
        options.drawHierarchyInKeyWindowDefaultEnabled = true

        let expectedArguments = [
            "mainTarget": "\(options.target ?? "")" as NSString,
            "file": options.testTargetPath.flatMap({ $0 + "PreviewTests.generated.swift"})!.string as NSString,
            "drawHierarchyInKeyWindowDefaultEnabled": "true" as NSString
        ] as [String: NSObject]

        let arguments = await GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(YAMLParser().string(from: arguments), YAMLParser().string(from: expectedArguments))
    }
}
