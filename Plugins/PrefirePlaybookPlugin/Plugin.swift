import Foundation
import PackagePlugin

@main
struct PrefirePlaybookPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let executable = try context.tool(named: "PrefireBinary").url
        let sourcery = try context.tool(named: "PrefireSourcery").url

        let cachePath = context.pluginWorkDirectoryURL.appending(path: "Cache")
        let outputPath = context.pluginWorkDirectoryURL.appending(path: "Generated")
        let templatePath = executable.path.components(separatedBy: "Binaries").first! + "Templates/" + "PreviewModels.stencil"
        let targetPath = String(describing: target.directory)

        var arguments: [String] = [
            "playbook",
            "--sourcery", sourcery.path,
            "--output", outputPath.path,
            "--target-path", targetPath,
            "--config", targetPath,
            "--template", templatePath,
            "--cache-base-path", cachePath.path,
            "--verbose",
        ]

        let sources = (target as? SwiftSourceModuleTarget)?.sourceFiles.filter { $0.type == .source }.map(\.url.path)
        arguments.append(contentsOf: sources ?? [targetPath])

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
            let executable = try context.tool(named: "PrefireBinary").url
            let sourcery = try context.tool(named: "PrefireSourcery").url

            let cachePath = context.pluginWorkDirectoryURL.appending(path: "Cache")
            let outputPath = context.pluginWorkDirectoryURL.appending(path: "Generated")
            let templatePath = executable.path.components(separatedBy: "Binaries").first! + "Templates/" + "PreviewModels.stencil"
            let targetPath = context.xcodeProject.directoryURL.appending(path: target.displayName)

            var arguments: [String] = [
                "playbook",
                "--sourcery", sourcery.path,
                "--output", outputPath.path,
                "--target-path", targetPath.path,
                "--config", context.xcodeProject.directoryURL.path,
                "--template", templatePath,
                "--cache-base-path", cachePath.path,
                "--verbose",
            ]

            let sources = target.inputFiles.filter { $0.type == .source }.map { $0.url.path }
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
