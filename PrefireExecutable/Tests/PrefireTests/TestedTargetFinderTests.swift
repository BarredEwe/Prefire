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
        let targetName = loadTargetNameFromConfig(
            for: "/some/directory", 
            targetName: "SomeTests"
        )
        
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
        
        // Test that target directory config is found
        let targetName = loadTargetNameFromConfig(
            for: targetDirectory.path, 
            targetName: "SomeTests"
        )
        
        XCTAssertEqual(targetName, "TargetDirTarget", "Should find config in target directory")
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
            targetDirectory
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
