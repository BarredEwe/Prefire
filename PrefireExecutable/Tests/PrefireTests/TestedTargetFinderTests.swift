import Foundation
import XCTest
@testable import prefire

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
        let targetName = TestTargetConfig.loadTargetName(in: ["/some/directory/SomeTests", "/some/directory"])

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
        let targetName = TestTargetConfig.loadTargetName(in: [targetDirectory.path, tempDirectory.path])

        XCTAssertEqual(targetName, "TargetDirTarget", "Should use the config in the first directory")
    }

    func test_loadTargetNameFromConfigFallsBackToNextDirectory() {
        let missingDirectory = tempDirectory.appendingPathComponent("missing")

        let targetName = TestTargetConfig.loadTargetName(in: [missingDirectory.path, tempDirectory.path])

        XCTAssertEqual(targetName, "MyTestTarget", "Should use the config in the next directory")
    }

    func test_loadTargetNameFromConfigWithHashAndSpaceInPath() {
        // `URL(string:)` reads everything after `#` as the fragment
        let targetDirectory = tempDirectory.appendingPathComponent("Snap#1 Tests")
        try! FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        try! testConfigString.write(to: targetDirectory.appendingPathComponent(".prefire.yml"), atomically: true, encoding: .utf8)

        let targetName = TestTargetConfig.loadTargetName(in: [targetDirectory.path])

        XCTAssertEqual(targetName, "MyTestTarget", "Should find config in a directory with `#` and a space in its name")
    }

    func test_loadTargetNameFromConfigMatchesCLIWithAndWithoutDoubleQuotes() throws {
        for value in ["FeatureA", "\"FeatureA\""] {
            let contents = """
            test_configuration:
              target: \(value)
            """
            try contents.write(to: configFile, atomically: true, encoding: .utf8)

            let cliTarget = ConfigDecoder().decode(from: contents, env: [:]).tests.target
            let pluginTarget = TestTargetConfig.loadTargetName(in: [tempDirectory.path])

            XCTAssertEqual(cliTarget, "FeatureA")
            XCTAssertEqual(pluginTarget, cliTarget, "Target names should match for \(value)")
        }
    }
}
