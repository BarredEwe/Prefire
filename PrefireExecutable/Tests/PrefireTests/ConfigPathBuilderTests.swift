import Foundation
@testable import prefire
import XCTest

class ConfigPathBuilderTests: XCTestCase {
    private let configFileName = ".prefire.yml"
    private let testTargetPath = "PrefireExampleTests"

    func test_possibleConfigPathsWithoutConfig() {
        let result = ConfigPathBuilder.possibleConfigPaths(for: nil, testTargetPath: nil)

        let expectableResult = [
            FileManager.default.currentDirectoryPath + "/\(configFileName)",
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithoutConfigWithTarget() {
        let result = ConfigPathBuilder.possibleConfigPaths(for: nil, testTargetPath: testTargetPath)

        let expectableResult = [
            testTargetPath + "/\(configFileName)",
            FileManager.default.currentDirectoryPath + "/\(configFileName)",
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithConfig() {
        let configPath = "Tests/" + configFileName
        let result = ConfigPathBuilder.possibleConfigPaths(for: configPath, testTargetPath: testTargetPath)

        let expectableResult = [
            testTargetPath + "/\(configFileName)",
            configPath,
            FileManager.default.currentDirectoryPath + "/\(configPath)",
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithConfigSeparated() {
        var configPath = "/Tests/" + configFileName
        let result = ConfigPathBuilder.possibleConfigPaths(for: configPath, testTargetPath: testTargetPath)

        configPath.removeFirst()
        let expectableResult = [
            testTargetPath + "/\(configFileName)",
            configPath,
            FileManager.default.currentDirectoryPath + "/\(configPath)",
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithConfigNoFileName() {
        var configPath = "/Tests/"
        let result = ConfigPathBuilder.possibleConfigPaths(for: configPath, testTargetPath: testTargetPath)

        configPath.removeFirst()
        configPath.removeLast()
        let expectableResult = [
            testTargetPath + "/\(configFileName)",
            configPath + "/\(configFileName)",
            FileManager.default.currentDirectoryPath + "/\(configPath)/\(configFileName)",
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithConfigNoFileNameNoTestingTarget() {
        var configPath = "/Tests/"
        let result = ConfigPathBuilder.possibleConfigPaths(for: configPath, testTargetPath: nil)

        configPath.removeFirst()
        configPath.removeLast()
        let expectableResult = [
            configPath + "/\(configFileName)",
            FileManager.default.currentDirectoryPath + "/\(configPath)/\(configFileName)",
        ]

        XCTAssertEqual(result, expectableResult)
    }
}
