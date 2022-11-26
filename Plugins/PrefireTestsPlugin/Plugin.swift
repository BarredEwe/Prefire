import Foundation
import PackagePlugin

@main
struct PrefireTestsPlugin: BuildToolPlugin {
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
                "\(templatesDirectory)/PreviewTests.stencil",
                "--sources",
                "\(target.directory)",
                "--output",
                "\(generatedSourcesDirectory)/PreviewTests.generated.swift",
                "--args",
                "mainTarget=\(target.name)",
                "file=\(target.directory)/\(target.name)/PreviewTests.swift"
            ],
            outputFilesDirectory: generatedSourcesDirectory
        )
        return [sourceryCommand]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension PrefireTestsPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
        let generatedSourcesDirectory = context.pluginWorkDirectory
        let executable = try context.tool(named: "Sourcery").path
        let templatesDirectory = executable.string.components(separatedBy: "Binaries").first! + "Templates"

        try FileManager.default.createDirectory(atPath: generatedSourcesDirectory.string, withIntermediateDirectories: true)

        let sourceryCommand = Command.prebuildCommand(
            displayName: "Running Sourcery",
            executable: executable,
            arguments: [
                "--templates",
                "\(templatesDirectory)/PreviewTests.stencil",
                "--sources",
                "\(context.xcodeProject.directory)",
                "--output",
                "\(generatedSourcesDirectory)/PreviewTests.generated.swift",
                "--args",
                "mainTarget=\(context.xcodeProject.targets[0].displayName)", // Нужно забирать через Config?
                "--args",
                "file=\(context.xcodeProject.directory)/\(target.displayName)/PreviewTests.swift"
            ],
            outputFilesDirectory: generatedSourcesDirectory
        )
        return [sourceryCommand]
    }
}
#endif
