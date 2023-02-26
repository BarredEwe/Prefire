import Foundation
import PackagePlugin

@main
struct PrefirePlaybookPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let executable = try context.tool(named: "PrefireSourcery").path
        let templatesDirectory = executable.string.components(separatedBy: "Binaries").first! + "Templates"

        try FileManager.default.createDirectory(atPath: context.pluginWorkDirectory.string, withIntermediateDirectories: true)

        return [
            Command.prefireCommand(
                executablePath: executable,
                templatesDirectory: templatesDirectory,
                sources: target.directory,
                generatedSourcesDirectory: context.pluginWorkDirectory)
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension PrefirePlaybookPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
        let executable = try context.tool(named: "PrefireSourcery").path
        let templatesDirectory = executable.string.components(separatedBy: "Binaries").first! + "Templates"

        try FileManager.default.createDirectory(atPath: context.pluginWorkDirectory.string, withIntermediateDirectories: true)

        return [
            Command.prefireCommand(
                executablePath: executable,
                templatesDirectory: templatesDirectory,
                sources: context.xcodeProject.directory,
                generatedSourcesDirectory: context.pluginWorkDirectory)
        ]
    }
}
#endif

// MARK: - Extensions

extension Command {
    static func prefireCommand(
        executablePath executable: Path,
        templatesDirectory: String,
        sources: Path,
        generatedSourcesDirectory: Path
    ) -> Command {
        Command.prebuildCommand(
            displayName: "Running Prefire",
            executable: executable,
            arguments: [
                "--templates",
                "\(templatesDirectory)/PreviewModels.stencil",
                "--sources",
                sources.string,
                "--output",
                "\(generatedSourcesDirectory)/PreviewModels.generated.swift",
                "--cacheBasePath",
                generatedSourcesDirectory.string,
            ],
            outputFilesDirectory: generatedSourcesDirectory
        )
    }
}
