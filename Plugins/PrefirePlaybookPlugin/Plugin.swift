import Foundation
import PackagePlugin

@main
struct PrefirePlaybookPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let executable = try context.tool(named: "PrefireBinary").path
        let sourcery = try context.tool(named: "PrefireSourcery").path

        let cachePath = context.pluginWorkDirectory.appending(subpath: "Cache")
        let outputPath = context.pluginWorkDirectory.appending(subpath: "Generated")
        let templatePath = executable.string.components(separatedBy: "Binaries").first! + "Templates/" + "PreviewModels.stencil"

        var arguments: [CustomStringConvertible] = [
            "playbook",
            "--sourcery", sourcery,
            "--output", outputPath,
            "--config", target.directory.string,
            "--template", templatePath,
            "--cache-base-path", cachePath,
            "--verbose",
        ]

        let sources = (target as? SwiftSourceModuleTarget)?.sourceFiles.filter { $0.type == .source }.map(\.path.string)
        arguments.append(contentsOf: sources ?? [target.directory.string])

        return [
            .prebuildCommand(
                displayName: "Running Prefire",
                executable: executable,
                arguments: arguments,
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
            let templatePath = executable.string.components(separatedBy: "Binaries").first! + "Templates/" + "PreviewModels.stencil"

            var arguments: [CustomStringConvertible] = [
                "playbook",
                "--sourcery", sourcery,
                "--output", outputPath,
                "--config", context.xcodeProject.directory.string,
                "--template", templatePath,
                "--cache-base-path", cachePath,
                "--verbose",
            ]

            let sources = target.inputFiles.filter { $0.type == .source }.map { $0.path.string }
            arguments.append(contentsOf: sources)

            return [
                .prebuildCommand(
                    displayName: "Running Prefire Playbook",
                    executable: executable,
                    arguments: arguments,
                    outputFilesDirectory: outputPath
                ),
            ]
        }
    }
#endif
