import Foundation
@testable import PrefireExecutable
import XCTest

class ConfigPathBuilderTests: XCTestCase {
    private let configFileName = ".prefire.yml"

    func test_possibleConfigPathsWithoutConfig() {
        let result = ConfigPathBuilder.possibleConfigPaths(for: nil)

        let expectableResult = [
            FileManager.default.currentDirectoryPath + "/" + configFileName,
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithConfig() {
        let configPath = "Tests/" + configFileName
        let result = ConfigPathBuilder.possibleConfigPaths(for: configPath)

        let expectableResult = [
            configPath,
            FileManager.default.currentDirectoryPath + "/\(configPath)",
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithConfigSeparated() {
        var configPath = "/Tests/" + configFileName
        let result = ConfigPathBuilder.possibleConfigPaths(for: configPath)

        configPath.removeFirst()
        let expectableResult = [
            configPath,
            FileManager.default.currentDirectoryPath + "/\(configPath)",
        ]

        XCTAssertEqual(result, expectableResult)
    }

    func test_possibleConfigPathsWithConfigNoFileName() {
        var configPath = "/Tests/"
        let result = ConfigPathBuilder.possibleConfigPaths(for: configPath)

        configPath.removeFirst()
        configPath.removeLast()
        let expectableResult = [
            configPath + "/\(configFileName)",
            FileManager.default.currentDirectoryPath + "/\(configPath)/\(configFileName)",
        ]

        XCTAssertEqual(result, expectableResult)
    }
}
