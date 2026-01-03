import Foundation

/// Utility for resolving template placeholders in configuration paths
///
/// Supports the following placeholders:
/// - `${TARGET}` - Replaced with the target name
/// - `${TEST_TARGET}` - Replaced with the test target name
///
/// Example:
/// ```swift
/// let path = "${PROJECT_DIR}/${TARGET}/Tests"
/// let resolved = ConfigPathResolver.resolve(path, target: "MyApp")
/// // Result: "${PROJECT_DIR}/MyApp/Tests"
/// ```
enum ConfigPathResolver {
    /// Resolves template placeholders in a configuration path
    ///
    /// - Parameters:
    ///   - path: The path string containing placeholders
    ///   - target: Optional target name to replace ${TARGET}
    ///   - testTarget: Optional test target name to replace ${TEST_TARGET}
    /// - Returns: Resolved path with placeholders replaced by their values
    static func resolve(
        _ path: String,
        target: String? = nil,
        testTarget: String? = nil
    ) -> String {
        var result = path

        if let target {
            result = result.replacingOccurrences(of: "{{target}}", with: target)
        }

        if let testTarget {
            result = result.replacingOccurrences(of: "{{testTarget}}", with: testTarget)
        }

        return result
    }
}
