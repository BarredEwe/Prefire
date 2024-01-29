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

        guard let targetForTestsing = context.package.targets.first(where: { $0.name != target.name }) else {
            throw "Prefire cannot find target for testing. Please, use `.prefire.yml` file, for providing `Target Name`"
        }

        return [
            .prebuildCommand(
                displayName: "Running Prefire",
                executable: executable,
                arguments: [
                    "tests",
                    "--sourcery", sourcery,
                    "--target", targetForTestsing.name,
                    "--sources", targetForTestsing.directory.string,
                    "--snapshot-output", target.directory.string,
                    "--output", outputPath,
                    "--config", targetForTestsing.directory, // [target.directory, target.directory.removingLastComponent()]
                    "--template", templatePath,
                    "--cache-base-path", cachePath,
                    "--verbose",
                ],
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

            guard let targetForTestsing = context.xcodeProject.targets.first(where: { $0.displayName != target.displayName }) else {
                throw "Prefire cannot find target for testing. Please, use `.prefire.yml` file, for providing `Target Name`"
            }

            // TODO: Add additional target for getting config file

            return [
                .prebuildCommand(
                    displayName: "Running Prefire",
                    executable: executable,
                    arguments: [
                        "tests",
                        "--sourcery", sourcery,
                        "--target", targetForTestsing.displayName,
                        "--sources", context.xcodeProject.directory,
                        "--output", outputPath,
                        "--snapshot-output", context.xcodeProject.directory.appending(subpath: target.displayName).string,
                        "--config", context.xcodeProject.directory, // [context.xcodeProject.directory.appending(subpath: target.displayName), context.xcodeProject.directory]
                        "--template", templatePath,
                        "--cache-base-path", cachePath,
                        "--verbose",
                    ],
                    outputFilesDirectory: outputPath
                ),
            ]
        }
    }
#endif

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
