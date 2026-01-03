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
        ] as [String: NSObject]

        let arguments = await GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(YAMLParser().string(from: arguments), YAMLParser().string(from: expectedArguments))
    }

    // MARK: - Template Parameter Tests

    func test_init_resolvesTargetPlaceholder() throws {
        let configData = """
        test_configuration:
          target: MyAppTarget
          test_target_path: "${PROJECT_DIR}/${TARGET}/Tests"
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = try GeneratedTestsOptions(
            target: nil,
            testTarget: nil,
            template: nil,
            sources: [],
            output: nil,
            testTargetPath: nil,
            cacheBasePath: nil,
            device: nil,
            osVersion: nil,
            config: config
        )

        XCTAssertEqual(options.testTargetPath?.string, "${PROJECT_DIR}/MyAppTarget/Tests")
    }

    func test_init_resolvesTestTargetPlaceholder() throws {
        let configData = """
        test_configuration:
          target: MyApp
          test_target_path: "${PROJECT_DIR}/Tests/${TEST_TARGET}"
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = try GeneratedTestsOptions(
            target: nil,
            testTarget: "MyAppTests",
            template: nil,
            sources: [],
            output: nil,
            testTargetPath: nil,
            cacheBasePath: nil,
            device: nil,
            osVersion: nil,
            config: config
        )

        XCTAssertEqual(options.testTargetPath?.string, "${PROJECT_DIR}/Tests/MyAppTests")
    }

    func test_init_resolvesBothPlaceholders() throws {
        let configData = """
        test_configuration:
          target: FeatureA
          test_target_path: "${PROJECT_DIR}/${TARGET}/Tests/${TEST_TARGET}"
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = try GeneratedTestsOptions(
            target: nil,
            testTarget: "FeatureATests",
            template: nil,
            sources: [],
            output: nil,
            testTargetPath: nil,
            cacheBasePath: nil,
            device: nil,
            osVersion: nil,
            config: config
        )

        XCTAssertEqual(options.testTargetPath?.string, "${PROJECT_DIR}/FeatureA/Tests/FeatureATests")
    }

    func test_init_noPlaceholders_keepsOriginalPath() throws {
        let configData = """
        test_configuration:
          target: MyApp
          test_target_path: "${PROJECT_DIR}/Tests"
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = try GeneratedTestsOptions(
            target: nil,
            testTarget: "MyAppTests",
            template: nil,
            sources: [],
            output: nil,
            testTargetPath: nil,
            cacheBasePath: nil,
            device: nil,
            osVersion: nil,
            config: config
        )

        XCTAssertEqual(options.testTargetPath?.string, "${PROJECT_DIR}/Tests")
    }

    func test_init_pathWithSpaces_resolvesCorrectly() throws {
        let configData = """
        test_configuration:
          target: My App
          test_target_path: "${PROJECT_DIR}/My Project/${TARGET}/Tests"
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = try GeneratedTestsOptions(
            target: nil,
            testTarget: nil,
            template: nil,
            sources: [],
            output: nil,
            testTargetPath: nil,
            cacheBasePath: nil,
            device: nil,
            osVersion: nil,
            config: config
        )

        XCTAssertEqual(options.testTargetPath?.string, "${PROJECT_DIR}/My Project/My App/Tests")
    }
}
