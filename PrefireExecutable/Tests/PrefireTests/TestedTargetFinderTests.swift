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
    
    func test_loadTargetNameFromConfigWithPrefireConfigurationDir() {
        // Save original environment
        let originalEnv = ProcessInfo.processInfo.environment["PREFIRE_CONFIGURATION_DIR"]
        
        // Set PREFIRE_CONFIGURATION_DIR environment variable
        setenv("PREFIRE_CONFIGURATION_DIR", tempDirectory.path, 1)
        
        // Test that the target name is correctly loaded from config
        let targetName = loadTargetNameFromConfig(
            for: "/some/other/directory", 
            targetName: "SomeTests"
        )
        
        XCTAssertEqual(targetName, "MyTestTarget", "Should load target name from config in PREFIRE_CONFIGURATION_DIR")
        
        // Restore original environment
        if let originalEnv = originalEnv {
            setenv("PREFIRE_CONFIGURATION_DIR", originalEnv, 1)
        } else {
            unsetenv("PREFIRE_CONFIGURATION_DIR")
        }
    }
    
    func test_loadTargetNameFromConfigWithoutPrefireConfigurationDir() {
        // Ensure PREFIRE_CONFIGURATION_DIR is not set
        unsetenv("PREFIRE_CONFIGURATION_DIR")
        
        // Test that it falls back to other search paths
        let targetName = loadTargetNameFromConfig(
            for: "/some/directory", 
            targetName: "SomeTests"
        )
        
        XCTAssertNil(targetName, "Should return nil when no config is found in standard paths")
    }
    
    func test_loadTargetNameFromConfigWithInvalidPrefireConfigurationDir() {
        // Set PREFIRE_CONFIGURATION_DIR to a non-existent path
        setenv("PREFIRE_CONFIGURATION_DIR", "/non/existent/path", 1)
        
        let targetName = loadTargetNameFromConfig(
            for: "/some/directory", 
            targetName: "SomeTests"
        )
        
        XCTAssertNil(targetName, "Should return nil when PREFIRE_CONFIGURATION_DIR points to invalid path")
        
        // Clean up
        unsetenv("PREFIRE_CONFIGURATION_DIR")
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
        
        // Set PREFIRE_CONFIGURATION_DIR to a different directory with different target
        setenv("PREFIRE_CONFIGURATION_DIR", tempDirectory.path, 1)
        
        // Test that target directory takes precedence over PREFIRE_CONFIGURATION_DIR
        let targetName = loadTargetNameFromConfig(
            for: targetDirectory.path, 
            targetName: "SomeTests"
        )
        
        XCTAssertEqual(targetName, "TargetDirTarget", "Target directory config should take precedence over PREFIRE_CONFIGURATION_DIR")
        
        // Clean up
        unsetenv("PREFIRE_CONFIGURATION_DIR")
    }
    
    // MARK: - Helper method extracted from TestedTargetFinder
    
    /// Easy loading of testTarget from a configuration file `.prefire.yml`
    /// - Parameters:
    ///   - targetDirectory: Test target directory
    ///   - targetName: Test target name
    /// - Returns: Target loaded from configuration file
    private func loadTargetNameFromConfig(for targetDirectory: String, targetName: String) -> String? {
        let possibleConfigPaths = [
            targetDirectory.appending("/\(targetName)"),
            targetDirectory,
            
            // We shouldn't just consider the target directory for config file.
            // When running into complex modularized projects, you might have a shared settings folder
            // for all your targets.
            ProcessInfo.processInfo.environment["PREFIRE_CONFIGURATION_DIR"]
        ].compactMap { $0 }
        
        for configPath in possibleConfigPaths {
            guard let configUrl = URL(string: "file://\(configPath)/.prefire.yml"),
                  FileManager.default.fileExists(atPath: configUrl.path) else { continue }
            
            let configDataString = try? String(contentsOf: configUrl, encoding: .utf8).components(separatedBy: .newlines)
            
            if let targetName = configDataString?.first(where: { $0.contains("target:") })?.components(separatedBy: ":").last {
                return targetName.trimmingCharacters(in: .whitespaces)
            }
        }
        
        return nil
    }
}
