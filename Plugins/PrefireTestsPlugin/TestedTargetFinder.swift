import Foundation
import PackagePlugin

enum TestedTargetFinder {
    /// Search for testedTarget
    /// - Parameter target: Test target
    /// - Returns: Tested Target object
    static func findTestedTarget(for target: Target) -> SwiftSourceModuleTarget? {
        let swiftTarget = target as? SwiftSourceModuleTarget

        if swiftTarget?.kind != .test {
            print("The `PrefireTestsPlugin` must be connected to the test package")
        }

        let targetDependencies = swiftTarget?.dependencies
            .compactMap { dependency in
                if case let .target(target) = dependency {
                    return target as? SwiftSourceModuleTarget
                } else {
                    return nil
                }
            }

        let expectedTarget = loadTargetNameFromConfig(for: target.directory, targetName: target.name)
            .flatMap { targetName in targetDependencies?.first(where: { $0.name == targetName }) }

        return expectedTarget ?? targetDependencies?.first(where: { $0.kind == .generic })
    }

    // MARK: - Private
    
    /// Easy loading of testTarget from a configuration file `.prefire.yml`
    /// - Parameters:
    ///   - targetDirectory: Test target directory
    ///   - targetName: Test traget name
    /// - Returns: Target loaded from configuration file
    private static func loadTargetNameFromConfig(for targetDirectory: Path, targetName: String) -> String? {
        let possibleConfigPaths = [
            targetDirectory.appending(subpath: targetName).string,
            targetDirectory.string
        ]

        for configPath in possibleConfigPaths {
            guard let configUrl = URL(string: "file://\(configPath)/.prefire.yml"),
                  FileManager.default.fileExists(atPath: configUrl.path) else { continue }

            let configDataString = try? String(contentsOf: configUrl, encoding: .utf8).components(separatedBy: .newlines)
            let targetLine = configDataString?.first(where: { $0.contains("target") })

            if var targetName = targetLine?.split(separator: ":").last.flatMap({ String($0) }) {
                targetName.removeFirst()
                return targetName
            }
        }

        return nil
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension TestedTargetFinder {
    /// Search for testedTarget
    /// - Parameters:
    ///   - target: Test Target
    ///   - project: Current Xcode Project
    /// - Returns: Tested Xcode Target
    static func findTestedTarget(for target: XcodeTarget, project: XcodeProject) -> XcodeTarget? {
        project.targets.lazy
            .filter {
                if case .other("com.apple.product-type.bundle.unit-test") = $0.product?.kind {
                    return false
                } else {
                    return true
                }
            }
            .first(where: { $0.displayName != target.displayName })
    }
}
#endif
