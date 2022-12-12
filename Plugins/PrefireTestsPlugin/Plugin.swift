import Foundation
import PackagePlugin

@main
struct PrefireTestsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let generatedSourcesDirectory = context.pluginWorkDirectory
        let executable = try context.tool(named: "Sourcery").path
        let templatesDirectory = executable.string.components(separatedBy: "Binaries").first! + "Templates"

        let configPath = target.directory.appending(subpath: ".prefire.yml")
        let configString = try String(contentsOf: URL(string: "file://\(configPath)")!, encoding: .utf8)
        let targetName = configString.matches(regex: "(test_configuration:|\\s+target:)(.+)")
            .first?.components(separatedBy: ": ").last
        let mainTarget = context.package.targets.first(where: { $0.name == targetName }) ?? target

        try FileManager.default.createDirectory(atPath: generatedSourcesDirectory.string, withIntermediateDirectories: true)

        let sourceryCommand = Command.prebuildCommand(
            displayName: "Running Sourcery",
            executable: executable,
            arguments: [
                "--templates",
                "\(templatesDirectory)/PreviewTests.stencil",
                "--sources",
                "\(mainTarget.directory)",
                "--output",
                "\(generatedSourcesDirectory)/PreviewTests.generated.swift",
                "--args",
                "mainTarget=\(mainTarget.name)",
                "--args",
                "file=\(target.directory)/PreviewTests.swift"
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

        let configPath = context.xcodeProject.directory.appending(subpath: target.displayName).appending(subpath: ".prefire.yml")
        let configString = try String(contentsOf: URL(string: "file://\(configPath)")!, encoding: .utf8)
        let targetName = configString.matches(regex: "(test_configuration:|\\s+target:)(.+)")
            .first?.components(separatedBy: ": ").last ?? context.xcodeProject.targets[0].displayName

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
                "mainTarget=\(targetName)",
                "--args",
                "file=\(context.xcodeProject.directory)/\(target.displayName)/PreviewTests.swift"
            ],
            outputFilesDirectory: generatedSourcesDirectory
        )
        return [sourceryCommand]
    }
}
#endif

private extension String {
    func matches(regex: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive]) else { return [] }
        let matches  = regex.matches(in: self, options: [], range: NSMakeRange(0, self.count))
        return matches.map { match in
             String(self[Range(match.range, in: self)!])
        }
    }
}
