import Foundation
import PackagePlugin

@main
struct PrefireTestsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let executable = try context.tool(named: "PrefireSourcery").path
        let templatesDirectory = executable.string.components(separatedBy: "Binaries").first! + "Templates"

        let configuration = [target.directory, target.directory.removingLastComponent()]
            .compactMap(Configuration.from(rootPath:)).first

        guard let mainTarget = context.package.targets.first(where: { $0.name == configuration?.targetName }) ?? context.package.targets.first else {
            throw "Prefire cannot find target for testing. Please, use `.prefire.yml` file, for providing `Target Name`"
        }

        let testFilePath = configuration?.testFilePath.flatMap({ target.directory.removingLastComponent().appending(subpath: $0).string }) ??
            "\(target.directory)/PreviewTests.generated.swift"

        try FileManager.default.createDirectory(atPath: context.pluginWorkDirectory.string, withIntermediateDirectories: true)

        return [
            Command.prefireCommand(
                executablePath: executable,
                templatesDirectory: templatesDirectory,
                sources: mainTarget.directory.string,
                generatedSourcesDirectory: context.pluginWorkDirectory,
                testFilePath: testFilePath,
                targetName: mainTarget.name,
                configuration: configuration
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension PrefireTestsPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
        let executable = try context.tool(named: "PrefireSourcery").path
        let templatesDirectory = executable.string.components(separatedBy: "Binaries").first! + "Templates"

        let configuration = [context.xcodeProject.directory.appending(subpath: target.displayName), context.xcodeProject.directory]
            .compactMap(Configuration.from(rootPath:)).first

        guard let targetName = configuration?.targetName ?? context.xcodeProject.targets.first?.displayName else {
            throw "Prefire cannot find target for testing. Please, use `.prefire.yml` file, for providing `Target Name`"
        }
        let testFilePath = configuration?.testFilePath.flatMap({ context.xcodeProject.directory.appending(subpath: $0).string }) ?? "\(context.xcodeProject.directory)/\(target.displayName)/PreviewTests.generated.swift"

        try FileManager.default.createDirectory(atPath: context.pluginWorkDirectory.string, withIntermediateDirectories: true)

        return [
            Command.prefireCommand(
                executablePath: executable,
                templatesDirectory: templatesDirectory,
                sources: context.xcodeProject.directory.string,
                generatedSourcesDirectory: context.pluginWorkDirectory,
                testFilePath: testFilePath,
                targetName: targetName,
                configuration: configuration
            )
        ]
    }
}
#endif

// MARK: - Extensions

private let defaultSimulatorDevice = "iPhone15,2"
private let defaultOSVersion = "16"

extension Command {
    static func prefireCommand(
        executablePath executable: Path,
        templatesDirectory: String,
        sources: String,
        generatedSourcesDirectory: Path,
        testFilePath: String,
        targetName: String,
        configuration: Configuration?
    ) -> Command {
        Command.prebuildCommand(
            displayName: "Running Prefire",
            executable: executable,
            arguments: [
                "--templates",
                "\(templatesDirectory)/PreviewTests.stencil",
                "--sources",
                sources,
                "--output",
                testFilePath,
                "--cacheBasePath",
                generatedSourcesDirectory.string,
                "--args",
                "mainTarget=\(targetName)",
                "--args",
                "file=\(testFilePath)",
                "--args",
                "simulatorDevice=\(configuration?.simulatorDevice ?? defaultSimulatorDevice)",
                "--args",
                "simulatorOSVersion=\(configuration?.requiredOSVersion ?? defaultOSVersion)"
            ],
            outputFilesDirectory: generatedSourcesDirectory
        )
    }
}

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
