import Foundation
import PackagePlugin

enum TestedTargetFinder {
    /// Search for testedTarget
    /// - Parameter target: Test target
    /// - Returns: Tested Target object
    static func findTestedTarget(for target: Target) throws -> SwiftSourceModuleTarget? {
        let swiftTarget = target as? SwiftSourceModuleTarget

        guard swiftTarget?.kind == .test else {
            throw NSError(domain: "`PrefireTestsPlugin` must be connected to the test target. \(target.name) is not a test target.", code: 0)
        }

        let targetDependencies = swiftTarget?.dependencies
            .compactMap { dependency in
                if case let .target(target) = dependency {
                    return target as? SwiftSourceModuleTarget
                } else {
                    return nil
                }
            }

        let targetNameFromConfig = loadTargetNameFromConfig(for: String(describing: target.directory), targetName: target.name)
        let potentialTargetName = target.name.replacingOccurrences(of: "Tests", with: "")
        let targetName = targetNameFromConfig ?? potentialTargetName

        return targetDependencies?.first(where: { $0.name == targetName }) ?? targetDependencies?.first(where: { $0.kind == .generic })
    }

    // MARK: - Private

    /// Easy loading of testTarget from a configuration file `.prefire.yml`
    /// - Parameters:
    ///   - targetDirectory: Test target directory
    ///   - targetName: Test traget name
    /// - Returns: Target loaded from configuration file
    private static func loadTargetNameFromConfig(for targetDirectory: String, targetName: String) -> String? {
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

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension TestedTargetFinder {
    /// Search for testedTarget
    /// - Parameters:
    ///   - target: Test Target
    ///   - project: Current Xcode Project
    /// - Returns: Tested Xcode Target
    static func findTestedTarget(for target: XcodeTarget, project: XcodeProject) throws -> XcodeTarget? {
        guard target.isTestKind else {
            throw NSError(domain: "`PrefireTestsPlugin` must be connected to the test target. \(target.displayName) is not a test target.", code: 0)
        }

        let targetNameFromConfig = loadTargetNameFromConfig(for: project.directoryURL.path, targetName: target.displayName)
        let potentialTargetName = target.displayName.replacingOccurrences(of: "Tests", with: "")
        let targetName = targetNameFromConfig ?? potentialTargetName

        let testedTargets = project.targets.filter { !$0.isTestKind }
        return testedTargets.first(where: { $0.displayName == targetName }) ?? testedTargets.first
    }
}

extension XcodeTarget {
    var isTestKind: Bool {
        guard let kind = product?.kind
        else { return false }

        switch kind {
        case .other("com.apple.product-type.bundle.unit-test"),
             .other("com.apple.product-type.bundle.ui-testing"):
            return true
        default:
            return false
        }
    }
}
#endif
