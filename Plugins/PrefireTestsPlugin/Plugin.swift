import Foundation
import PackagePlugin

@main
struct PrefireTestsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let executable = try context.tool(named: "PrefireBinary").path
        let sourcery = try context.tool(named: "PrefireSourcery").path

        let cachePath = context.pluginWorkDirectory.appending(subpath: "Cache")
        let outputPath = context.pluginWorkDirectory.appending(subpath: "Generated")
        let templatePath = executable.string.components(separatedBy: "Binaries").first! + "Templates/" + "PreviewTests.stencil"

        guard let testedTarget = TestedTargetFinder.findTestedTarget(for: target) else {
            throw "Prefire cannot find target for testing. Please, use `.prefire.yml` file, for providing `Target Name`"
        }

        var arguments: [CustomStringConvertible] = [
            "tests",
            "--sourcery", sourcery,
            "--target", testedTarget.name,
            "--test-target", target.name,
            "--output", outputPath,
            "--test-target-path", target.directory.string,
            "--config", testedTarget.directory.string,
            "--template", templatePath,
            "--cache-base-path", cachePath,
            "--verbose",
        ]

        let sources = testedTarget.sourceFiles.filter { $0.type == .source }.map(\.path.string)
        arguments.append(contentsOf: sources)

        let environment = [
            "TARGET_DIR": target.directory.string,
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
            let executable = try context.tool(named: "PrefireBinary").path
            let sourcery = try context.tool(named: "PrefireSourcery").path

            let cachePath = context.pluginWorkDirectory.appending(subpath: "Cache")
            let outputPath = context.pluginWorkDirectory.appending(subpath: "Generated")
            let templatePath = executable.string.components(separatedBy: "Binaries").first! + "Templates/" + "PreviewTests.stencil"

            guard let testedTarget = TestedTargetFinder.findTestedTarget(for: target, project: context.xcodeProject) else {
                throw "Prefire cannot find target for testing. Please, use `.prefire.yml` file, for providing `Target Name`"
            }

            var arguments: [CustomStringConvertible] = [
                "tests",
                "--sourcery", sourcery,
                "--target", testedTarget.displayName,
                "--test-target", target.displayName,
                "--output", outputPath,
                "--test-target-path", context.xcodeProject.directory.appending(subpath: target.displayName).string,
                "--config", context.xcodeProject.directory.string,
                "--template", templatePath,
                "--cache-base-path", cachePath,
                "--verbose",
            ]

            let sources = testedTarget.inputFiles.filter { $0.type == .source }.map(\.path.string)
            arguments.append(contentsOf: sources)

            let environment = [
                "PROJECT_DIR": context.xcodeProject.directory.string,
            ]

            return [
                .prebuildCommand(
                    displayName: "Running Prefire Tests",
                    executable: executable,
                    arguments: arguments,
                    environment: environment,
                    outputFilesDirectory: outputPath
                ),
            ]
        }
    }
#endif

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
