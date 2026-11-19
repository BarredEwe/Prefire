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

        let targetDirectory = String(describing: target.directory)
        let targetNameFromConfig = loadTargetNameFromConfig(in: [targetDirectory.appending("/\(target.name)"), targetDirectory])
        let potentialTargetName = target.name.replacingOccurrences(of: "Tests", with: "")
        let targetName = targetNameFromConfig ?? potentialTargetName

        return targetDependencies?.first(where: { $0.name == targetName }) ?? targetDependencies?.first(where: { $0.kind == .generic })
    }

    // MARK: - Private

    /// Easy loading of testTarget from a configuration file `.prefire.yml`
    /// - Parameter possibleConfigPaths: Directories to look for `.prefire.yml` in, in order
    /// - Returns: Target loaded from the first configuration file found
    private static func loadTargetNameFromConfig(in possibleConfigPaths: [String]) -> String? {
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

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension TestedTargetFinder {
    /// Directory of a test target in an Xcode project
    ///
    /// Xcode doesn't tell plugins where a target's files are. A test target outside `<project>/<target name>`
    /// can point at its directory by including its own `.prefire.yml`, for example as a resource.
    /// - Parameters:
    ///   - target: Test Target
    ///   - project: Current Xcode Project
    /// - Returns: Directory of the test target's `.prefire.yml`, or `<project>/<target name>` without one
    static func testTargetDirectory(for target: XcodeTarget, project: XcodeProject) -> URL {
        if let config = target.inputFiles.first(where: { $0.url.lastPathComponent == ".prefire.yml" }) {
            return config.url.deletingLastPathComponent()
        }
        return project.directoryURL.appending(path: target.displayName)
    }

    /// Search for testedTarget
    /// - Parameters:
    ///   - target: Test Target
    ///   - testTargetDirectory: Directory of the test target, from `testTargetDirectory(for:project:)`
    ///   - project: Current Xcode Project
    /// - Returns: Tested Xcode Target
    static func findTestedTarget(for target: XcodeTarget, testTargetDirectory: URL, project: XcodeProject) throws -> XcodeTarget? {
        guard target.isTestKind else {
            throw NSError(domain: "`PrefireTestsPlugin` must be connected to the test target. \(target.displayName) is not a test target.", code: 0)
        }

        let targetNameFromConfig = loadTargetNameFromConfig(in: [testTargetDirectory.path, project.directoryURL.path])
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
