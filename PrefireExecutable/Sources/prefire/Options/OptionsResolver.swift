import Foundation
import PathKit

/// Shared resolution logic for command options
enum OptionsResolver {
    /// Resolves template path - if config template exists, resolves relative to target path
    /// - Parameters:
    ///   - cliTemplate: Template path from CLI argument
    ///   - configTemplate: Template path from config file (relative to targetPath)
    ///   - targetPath: Base path for resolving config template
    /// - Returns: Resolved template path or nil
    static func resolveTemplate(
        cliTemplate: String?,
        configTemplate: String?,
        targetPath: Path?
    ) -> Path? {
        if let configTemplate, let targetPath {
            let targetURL = URL(filePath: targetPath.string)
            let templateURL = targetURL.appending(path: configTemplate)
            return Path(templateURL.absoluteURL.path())
        }
        return cliTemplate.map { Path($0) }
    }

    /// Resolves path string with template placeholders (${TARGET}, ${TEST_TARGET})
    /// - Parameters:
    ///   - path: Path string potentially containing placeholders
    ///   - target: Target name to replace ${TARGET}
    ///   - testTarget: Test target name to replace ${TEST_TARGET}
    /// - Returns: Resolved Path or nil
    static func resolvePath(
        _ path: String?,
        target: String?,
        testTarget: String?
    ) -> Path? {
        guard let path else { return nil }
        let resolved = ConfigPathResolver.resolve(path, target: target, testTarget: testTarget)
        return Path(resolved)
    }

    /// Converts string array to Path array
    /// - Parameters:
    ///   - sources: Array of path strings
    ///   - default: Default value if sources is nil or empty
    /// - Returns: Array of Path objects
    static func resolveSources(
        _ sources: [String]?,
        default defaultValue: [Path] = [.current]
    ) -> [Path] {
        guard let sources, !sources.isEmpty else { return defaultValue }
        return sources.compactMap { Path($0) }
    }

    /// Resolves output path with default filename
    /// - Parameters:
    ///   - output: Output path string
    ///   - defaultFileName: Default filename to append if output is directory
    /// - Returns: Resolved output Path
    static func resolveOutput(
        _ output: String?,
        defaultFileName: String
    ) -> Path {
        let basePath = output.flatMap { Path($0) } ?? .current
        return basePath + defaultFileName
    }
}
