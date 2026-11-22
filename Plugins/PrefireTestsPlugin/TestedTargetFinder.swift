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
    /// `.prefire.yml` that a test target in an Xcode project includes, for example as a resource
    ///
    /// Xcode doesn't tell plugins where a target's files are. A test target outside `<project>/<target name>`
    /// can point at its directory by including its own `.prefire.yml`. A file in a directory that is looked in
    /// anyway, `<project>/<target name>` or next to the `.xcodeproj`, is not counted, so including it changes nothing.
    /// - Parameters:
    ///   - target: Test Target
    ///   - project: Current Xcode Project
    /// - Returns: The test target's own `.prefire.yml` with the shortest path, or `nil` without one
    static func testTargetConfig(for target: XcodeTarget, project: XcodeProject) -> URL? {
        let defaultConfigPaths = defaultConfigDirectories(for: target, project: project)
            .map { standardizedPath(of: $0.appending(path: ".prefire.yml")) }

        let configs = target.inputFiles
            .map(\.url)
            .filter { $0.lastPathComponent == ".prefire.yml" && !defaultConfigPaths.contains(standardizedPath(of: $0)) }
            .sorted { ($0.pathComponents.count, standardizedPath(of: $0)) < ($1.pathComponents.count, standardizedPath(of: $1)) }

        guard let config = configs.first else { return nil }

        if configs.count > 1 {
            Diagnostics.warning("\(target.displayName) includes more than one .prefire.yml, Prefire uses \(standardizedPath(of: config))")
        }
        return config
    }

    /// Search for testedTarget
    /// - Parameters:
    ///   - target: Test Target
    ///   - testTargetConfig: The test target's own `.prefire.yml`, from `testTargetConfig(for:project:)`
    ///   - project: Current Xcode Project
    /// - Returns: Tested Xcode Target
    static func findTestedTarget(for target: XcodeTarget, testTargetConfig: URL?, project: XcodeProject) throws -> XcodeTarget? {
        guard target.isTestKind else {
            throw NSError(domain: "`PrefireTestsPlugin` must be connected to the test target. \(target.displayName) is not a test target.", code: 0)
        }

        // The CLI uses only the first `.prefire.yml` it finds, which is the test target's own one when it has one
        let configDirectories = testTargetConfig.map { [$0.deletingLastPathComponent()] }
            ?? defaultConfigDirectories(for: target, project: project)
        let targetNameFromConfig = loadTargetNameFromConfig(in: configDirectories.map { $0.path(percentEncoded: false) })
        let potentialTargetName = target.displayName.replacingOccurrences(of: "Tests", with: "")
        let targetName = targetNameFromConfig ?? potentialTargetName

        let testedTargets = project.targets.filter { !$0.isTestKind }
        return testedTargets.first(where: { $0.displayName == targetName }) ?? testedTargets.first
    }

    /// Directories looked in for `.prefire.yml` when the test target has no `.prefire.yml` of its own, in order
    private static func defaultConfigDirectories(for target: XcodeTarget, project: XcodeProject) -> [URL] {
        [project.directoryURL.appending(path: target.displayName), project.directoryURL]
    }

    private static func standardizedPath(of url: URL) -> String {
        url.standardizedFileURL.path(percentEncoded: false)
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
