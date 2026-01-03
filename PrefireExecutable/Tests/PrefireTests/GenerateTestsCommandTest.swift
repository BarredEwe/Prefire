import Foundation
@testable import prefire
import XCTest
import PathKit

class GenerateTestsCommandTests: XCTestCase {

    // MARK: - Helper Methods

    private func makeOptions(
        target: String? = nil,
        testTarget: String? = nil,
        template: String? = nil,
        sources: [String] = [],
        output: String? = nil,
        testTargetPath: String? = nil,
        cacheBasePath: String? = nil,
        device: String? = nil,
        osVersion: String? = nil,
        config: Config? = nil
    ) -> GeneratedTestsOptions {
        let cli = CLITestsOptions(
            target: target,
            testTarget: testTarget,
            template: template,
            sources: sources,
            output: output,
            testTargetPath: testTargetPath,
            cacheBasePath: cacheBasePath,
            device: device,
            osVersion: osVersion
        )
        return GeneratedTestsOptions.from(cli: cli, config: config)
    }

    // MARK: - makeArguments Tests

    func test_makeArguments_sources() async {
        let options = makeOptions(
            target: "GenerateTestsCommand",
            testTarget: "GenerateTestsCommandTests",
            sources: ["some/sources"],
            testTargetPath: "User/Tests"
        )

        let expectedArguments = [
            "mainTarget": options.target! as NSString,
            "file": options.testTargetPath.flatMap({ $0 + "PreviewTests.generated.swift"})!.string as NSString,
        ] as [String: NSObject]

        let arguments = await GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(YAMLParser().string(from: arguments), YAMLParser().string(from: expectedArguments))
    }

    func test_makeArguments_snapshot_devices() async {
        let configData = """
        test_configuration:
          snapshot_devices:
            - iPhone 15
            - iPad
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = makeOptions(
            target: "GenerateTestsCommand",
            testTarget: "GenerateTestsCommandTests",
            sources: ["some/sources", "some/other/sources"],
            testTargetPath: "User/Tests",
            config: config
        )

        let expectedArguments = [
            "mainTarget": options.target! as NSString,
            "file": options.testTargetPath.flatMap({ $0 + "PreviewTests.generated.swift"})!.string as NSString,
            "snapshotDevices": "iPhone 15|iPad" as NSString,
        ] as [String: NSObject]

        let arguments = await GenerateTestsCommand.makeArguments(for: options)

        XCTAssertEqual(YAMLParser().string(from: arguments), YAMLParser().string(from: expectedArguments))
    }

    // MARK: - Template Parameter Tests

    func test_from_resolvesTargetPlaceholder() {
        let configData = """
        test_configuration:
          target: MyAppTarget
          test_target_path: "${PROJECT_DIR}/${TARGET}/Tests"
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = makeOptions(config: config)

        XCTAssertEqual(options.testTargetPath?.string, "${PROJECT_DIR}/MyAppTarget/Tests")
    }

    func test_from_resolvesTestTargetPlaceholder() {
        let configData = """
        test_configuration:
          target: MyApp
          test_target_path: "${PROJECT_DIR}/Tests/${TEST_TARGET}"
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = makeOptions(testTarget: "MyAppTests", config: config)

        XCTAssertEqual(options.testTargetPath?.string, "${PROJECT_DIR}/Tests/MyAppTests")
    }

    func test_from_resolvesBothPlaceholders() {
        let configData = """
        test_configuration:
          target: FeatureA
          test_target_path: "${PROJECT_DIR}/${TARGET}/Tests/${TEST_TARGET}"
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = makeOptions(testTarget: "FeatureATests", config: config)

        XCTAssertEqual(options.testTargetPath?.string, "${PROJECT_DIR}/FeatureA/Tests/FeatureATests")
    }

    func test_from_noPlaceholders_keepsOriginalPath() {
        let configData = """
        test_configuration:
          target: MyApp
          test_target_path: "${PROJECT_DIR}/Tests"
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = makeOptions(testTarget: "MyAppTests", config: config)

        XCTAssertEqual(options.testTargetPath?.string, "${PROJECT_DIR}/Tests")
    }

    func test_from_pathWithSpaces_resolvesCorrectly() {
        let configData = """
        test_configuration:
          target: My App
          test_target_path: "${PROJECT_DIR}/My Project/${TARGET}/Tests"
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = makeOptions(config: config)

        XCTAssertEqual(options.testTargetPath?.string, "${PROJECT_DIR}/My Project/My App/Tests")
    }

    // MARK: - CLI and Config Merging Tests

    func test_from_configTakesPrecedenceOverCLI_forTarget() {
        let configData = """
        test_configuration:
          target: ConfigTarget
        """
        let config = ConfigDecoder().decode(from: configData, env: [:])

        let options = makeOptions(
            target: "CLITarget",
            testTarget: "CLITestTarget",
            config: config
        )

        XCTAssertEqual(options.target, "ConfigTarget")
        // testTarget only comes from CLI (not in config)
        XCTAssertEqual(options.testTarget, "CLITestTarget")
    }

    func test_from_usesCliWhenConfigIsNil() {
        let options = makeOptions(
            target: "CLITarget",
            testTarget: "CLITestTarget"
        )

        XCTAssertEqual(options.target, "CLITarget")
        XCTAssertEqual(options.testTarget, "CLITestTarget")
    }
}
