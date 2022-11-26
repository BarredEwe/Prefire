import Foundation
import PackagePlugin

@main
struct PrefirePlaybookPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let generatedSourcesDirectory = context.pluginWorkDirectory
        let executable = try context.tool(named: "Sourcery").path
        let templatesDirectory = executable.string.components(separatedBy: "Binaries").first! + "Templates"

        try FileManager.default.createDirectory(atPath: generatedSourcesDirectory.string, withIntermediateDirectories: true)

        let sourceryCommand = Command.prebuildCommand(
            displayName: "Running Sourcery",
            executable: executable,
            arguments: [
                "--templates",
                "\(templatesDirectory)/PreviewModels.stencil",
                "--sources",
                "\(target.directory)",
                "--output",
                "\(generatedSourcesDirectory)/PreviewModels.generated.swift"
            ],
            outputFilesDirectory: generatedSourcesDirectory
        )
        return [sourceryCommand]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension PrefirePlaybookPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
        let generatedSourcesDirectory = context.pluginWorkDirectory
        let executable = try context.tool(named: "Sourcery").path
        let templatesDirectory = executable.string.components(separatedBy: "Binaries").first! + "Templates"

        debugPrint(templatesDirectory)

        try FileManager.default.createDirectory(atPath: generatedSourcesDirectory.string, withIntermediateDirectories: true)

        let sourceryCommand = Command.prebuildCommand(
            displayName: "Running Sourcery",
            executable: executable,
            arguments: [
                "--templates",
                "\(templatesDirectory)/PreviewModels.stencil",
                "--sources",
                "\(context.xcodeProject.directory)",
                "--output",
                "\(generatedSourcesDirectory)/PreviewModels.generated.swift"
            ],
            outputFilesDirectory: generatedSourcesDirectory
        )
        return [sourceryCommand]
    }
}
#endif
