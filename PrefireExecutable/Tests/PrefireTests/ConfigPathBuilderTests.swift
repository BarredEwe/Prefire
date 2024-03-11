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
            FileManager.default.currentDirectoryPath + "/\(testTargetPath)" + "/\(configFileName)",
            FileManager.default.currentDirectoryPath + "/\(configFileName)",
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithConfig() {
        let configPath = "Tests/" + configFileName
        let result = ConfigPathBuilder.possibleConfigPaths(for: configPath, testTargetPath: testTargetPath)

        let expectableResult = [
            FileManager.default.currentDirectoryPath + "/\(testTargetPath)" + "/\(configFileName)",
            FileManager.default.currentDirectoryPath + "/\(configPath)",
            FileManager.default.currentDirectoryPath + "/\(configFileName)"
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithConfigSeparated() {
        let configPath = "Tests/" + configFileName
        let result = ConfigPathBuilder.possibleConfigPaths(for: configPath, testTargetPath: testTargetPath)

        let expectableResult = [
            FileManager.default.currentDirectoryPath + "/\(testTargetPath)" + "/\(configFileName)",
            FileManager.default.currentDirectoryPath + "/\(configPath)",
            FileManager.default.currentDirectoryPath + "/\(configFileName)"
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithConfigNoFileName() {
        let configPath = "Tests/"
        let result = ConfigPathBuilder.possibleConfigPaths(for: configPath, testTargetPath: testTargetPath)

        let expectableResult = [
            FileManager.default.currentDirectoryPath + "/\(testTargetPath)" + "/\(configFileName)",
            FileManager.default.currentDirectoryPath + "/\(configPath)" + "\(configFileName)",
            FileManager.default.currentDirectoryPath + "/\(configFileName)"
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithConfigNoFileNameNoTestingTarget() {
        let configPath = "Tests/"
        let result = ConfigPathBuilder.possibleConfigPaths(for: configPath, testTargetPath: nil)

        let expectableResult = [
            FileManager.default.currentDirectoryPath + "/\(configPath)" + "\(configFileName)",
            FileManager.default.currentDirectoryPath + "/\(configFileName)"
        ]

        XCTAssertEqual(result, expectableResult)
    }
}
