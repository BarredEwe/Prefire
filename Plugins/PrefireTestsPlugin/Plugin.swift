import Foundation
import PackagePlugin

@main
struct PrefireTestsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let executable = try context.tool(named: "PrefireBinary").url
        let sourcery = try context.tool(named: "PrefireSourcery").url

        let cachePath = context.pluginWorkDirectoryURL.appending(path: "Cache")
        let outputPath = context.pluginWorkDirectoryURL.appending(path: "Generated")
        let templatePath = executable.path.components(separatedBy: "Binaries").first! + "Templates/" + "PreviewTests.stencil"

        guard let testedTarget = TestedTargetFinder.findTestedTarget(for: target) else {
            throw "Prefire cannot find target for testing. Please, use `.prefire.yml` file, for providing `Target Name`"
        }

        var arguments: [String] = [
            "tests",
            "--sourcery", sourcery.path,
            "--target", testedTarget.name,
            "--test-target", target.name,
            "--output", outputPath.path,
            "--test-target-path", String(describing: target.directory),
            "--config", testedTarget.directoryURL.path,
            "--template", templatePath,
            "--cache-base-path", cachePath.path,
            "--verbose",
        ]

        let sources = testedTarget.sourceFiles.filter { $0.type == .source }.map(\.url.path)
        arguments.append(contentsOf: sources)

        var environment = [
            "TARGET_DIR": String(describing: target.directory),
            "PACKAGE_DIR": context.package.directoryURL.path(),
        ]

        return [
            .prebuildCommand(
                displayName: "Running Prefire",
                executable: executable,
                arguments: arguments,
                environment: environment,
                outputFilesDirectory: outputPath
            ),
        ]
    }
}

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension PrefireTestsPlugin: XcodeBuildToolPlugin {
        func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
            let executable = try context.tool(named: "PrefireBinary").url
            let sourcery = try context.tool(named: "PrefireSourcery").url

            let cacheURL = context.pluginWorkDirectoryURL.appending(path: "Cache")
            let outputURL = context.pluginWorkDirectoryURL.appending(path: "Generated")
            let templatePath = executable.path.components(separatedBy: "Binaries").first! + "Templates/" + "PreviewTests.stencil"
            let testTagetPath = context.xcodeProject.directoryURL.appending(path: target.displayName).path

            guard let testedTarget = TestedTargetFinder.findTestedTarget(for: target, project: context.xcodeProject) else {
                throw "Prefire cannot find target for testing. Please, use `.prefire.yml` file, for providing `Target Name`"
            }

            var arguments: [String] = [
                "tests",
                "--sourcery", sourcery.path,
                "--target", testedTarget.displayName,
                "--test-target", target.displayName,
                "--output", outputURL.path,
                "--test-target-path", testTagetPath,
                "--config", context.xcodeProject.directoryURL.path,
                "--template", templatePath,
                "--cache-base-path", cacheURL.path,
                "--verbose",
            ]

            let sources = testedTarget.inputFiles.filter { $0.type == .source }.map(\.url.path)
            arguments.append(contentsOf: sources)

            let environment = [
                "PROJECT_DIR": context.xcodeProject.directoryURL.path(),
            ]

            return [
                .prebuildCommand(
                    displayName: "Running Prefire Tests",
                    executable: executable,
                    arguments: arguments,
                    environment: environment,
                    outputFilesDirectory: outputURL
                ),
            ]
        }
    }
#endif

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { return self }
}
