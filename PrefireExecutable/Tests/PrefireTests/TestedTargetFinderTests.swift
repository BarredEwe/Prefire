import Foundation
import XCTest

final class TestedTargetFinderTests: XCTestCase {
    private let testConfigString = """
    test_configuration:
      target: MyTestTarget
      test_target_path: /path/to/tests
    """
    
    private var tempDirectory: URL!
    private var configFile: URL!
    
    override func setUp() {
        super.setUp()
        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create a test .prefire.yml file
        configFile = tempDirectory.appendingPathComponent(".prefire.yml")
        try! testConfigString.write(to: configFile, atomically: true, encoding: .utf8)
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    func test_loadTargetNameFromConfigWithoutConfig() {
        // Test that it returns nil when no config is found
        let targetName = loadTargetNameFromConfig(in: ["/some/directory/SomeTests", "/some/directory"])

        XCTAssertNil(targetName, "Should return nil when no config is found in standard paths")
    }

    func test_loadTargetNameFromConfigPrecedence() {
        // Create config file in target directory
        let targetDirectory = tempDirectory.appendingPathComponent("target")
        try! FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let targetConfigFile = targetDirectory.appendingPathComponent(".prefire.yml")
        let targetConfigString = """
        test_configuration:
          target: TargetDirTarget
        """
        try! targetConfigString.write(to: targetConfigFile, atomically: true, encoding: .utf8)

        // Test that the config in the first directory wins over the one in tempDirectory
        let targetName = loadTargetNameFromConfig(in: [targetDirectory.path, tempDirectory.path])

        XCTAssertEqual(targetName, "TargetDirTarget", "Should use the config in the first directory")
    }

    func test_loadTargetNameFromConfigFallsBackToNextDirectory() {
        let missingDirectory = tempDirectory.appendingPathComponent("missing")

        let targetName = loadTargetNameFromConfig(in: [missingDirectory.path, tempDirectory.path])

        XCTAssertEqual(targetName, "MyTestTarget", "Should use the config in the next directory")
    }

    func test_loadTargetNameFromConfigWithHashAndSpaceInPath() {
        // `URL(string:)` reads everything after `#` as the fragment
        let targetDirectory = tempDirectory.appendingPathComponent("Snap#1 Tests")
        try! FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        try! testConfigString.write(to: targetDirectory.appendingPathComponent(".prefire.yml"), atomically: true, encoding: .utf8)

        let targetName = loadTargetNameFromConfig(in: [targetDirectory.path])

        XCTAssertEqual(targetName, "MyTestTarget", "Should find config in a directory with `#` and a space in its name")
    }

    // MARK: - Helper method extracted from TestedTargetFinder

    /// Easy loading of testTarget from a configuration file `.prefire.yml`
    /// - Parameter possibleConfigPaths: Directories to look for `.prefire.yml` in, in order
    /// - Returns: Target loaded from the first configuration file found
    private func loadTargetNameFromConfig(in possibleConfigPaths: [String]) -> String? {
        for configPath in possibleConfigPaths {
            let configUrl = URL(filePath: configPath).appending(path: ".prefire.yml")
            guard FileManager.default.fileExists(atPath: configUrl.path(percentEncoded: false)) else { continue }

            let configDataString = try? String(contentsOf: configUrl, encoding: .utf8).components(separatedBy: .newlines)
            
            if let targetName = configDataString?.first(where: { $0.contains("target:") })?.components(separatedBy: ":").last {
                return targetName.trimmingCharacters(in: .whitespaces)
            }
        }
        
        return nil
    }
}
