import Foundation
import PackagePlugin

@main
struct PrefirePlaybookPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let executable = try context.tool(named: "PrefireBinary").path
        let sourcery = try context.tool(named: "PrefireSourcery").path

        let cachePath = context.pluginWorkDirectory.appending(subpath: "Cache")
        let outputPath = context.pluginWorkDirectory.appending(subpath: "Generated")
        let templatePath = executable.string.components(separatedBy: "Binaries").first! + "PrefireExecutable/Templates/" + "PreviewModels.stencil"

        // TODO: Add passing the Main Target

        return [
            .prebuildCommand(
                displayName: "Running Prefire",
                executable: executable,
                arguments: [
                    "playbook",
                    "--sourcery", sourcery,
                    "--target", target.name,
                    "--sources", target.directory,
                    "--output", outputPath,
                    "--config", target.directory,
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

    extension PrefirePlaybookPlugin: XcodeBuildToolPlugin {
        func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
            let executable = try context.tool(named: "PrefireBinary").path
            let sourcery = try context.tool(named: "PrefireSourcery").path

            let cachePath = context.pluginWorkDirectory.appending(subpath: "Cache")
            let outputPath = context.pluginWorkDirectory.appending(subpath: "Generated")
            let templatePath = executable.string.components(separatedBy: "Binaries").first! + "PrefireExecutable/Templates/" + "PreviewModels.stencil"

            return [
                .prebuildCommand(
                    displayName: "Running Prefire",
                    executable: executable,
                    arguments: [
                        "playbook",
                        "--sourcery", sourcery,
                        "--target", target.displayName,
                        "--sources", context.xcodeProject.directory,
                        "--output", outputPath,
                        "--config", context.xcodeProject.directory,
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
