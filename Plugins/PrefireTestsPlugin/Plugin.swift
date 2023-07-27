import Foundation
import PackagePlugin

@main
struct PrefireTestsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let executable = try context.tool(named: "PrefireSourcery").path

        let configuration = Configuration.from(rootPaths: [target.directory, target.directory.removingLastComponent()])

        guard let mainTarget = context.package.targets.first(where: { $0.name == configuration?.targetName }) ??
                context.package.targets.first(where: { $0.name != target.name }) else {
            throw "Prefire cannot find target for testing. Please, use `.prefire.yml` file, for providing `Target Name`"
        }

        let testFilePath = configuration?.testFilePath.flatMap({ target.directory.removingLastComponent().appending(subpath: $0).string })
        ?? "\(context.pluginWorkDirectory)/PreviewTests.generated.swift"

        let templateFilePath = configuration?.templateFilePath.flatMap({ target.directory.removingLastComponent().appending(subpath: $0).string })
        ?? executable.string.components(separatedBy: "Binaries").first! + "Templates/" + "PreviewTests.stencil"

        try FileManager.default.createDirectory(atPath: context.pluginWorkDirectory.string, withIntermediateDirectories: true)

        return [
            Command.prefireCommand(
                executablePath: executable,
                sources: mainTarget.directory.string,
                templateFilePath: templateFilePath,
                generatedSourcesDirectory: context.pluginWorkDirectory,
                testFilePath: testFilePath,
                testTargetPath: target.directory.string,
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

        let configuration = Configuration.from(rootPaths: [context.xcodeProject.directory.appending(subpath: target.displayName), context.xcodeProject.directory])

        guard let targetName = configuration?.targetName ?? context.xcodeProject.targets.first(where: { $0.displayName != target.displayName })?.displayName else {
            throw "Prefire cannot find target for testing. Please, use `.prefire.yml` file, for providing `Target Name`"
        }

        let testFilePath = configuration?.testFilePath.flatMap({ context.xcodeProject.directory.appending(subpath: $0).string })
        ?? "\(context.pluginWorkDirectory)/\(target.displayName)/PreviewTests.generated.swift"

        let templateFilePath = configuration?.templateFilePath.flatMap({ context.xcodeProject.directory.appending(subpath: $0).string })
        ?? executable.string.components(separatedBy: "Binaries").first! + "Templates/" + "PreviewTests.stencil"

        try FileManager.default.createDirectory(atPath: context.pluginWorkDirectory.string, withIntermediateDirectories: true)

        return [
            Command.prefireCommand(
                executablePath: executable,
                sources: context.xcodeProject.directory.string,
                templateFilePath: templateFilePath,
                generatedSourcesDirectory: context.pluginWorkDirectory,
                testFilePath: testFilePath,
                testTargetPath: context.xcodeProject.directory.appending(subpath: target.displayName).string,
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
        sources: String,
        templateFilePath: String,
        generatedSourcesDirectory: Path,
        testFilePath: String,
        testTargetPath: String,
        targetName: String,
        configuration: Configuration?
    ) -> Command {
        var arguments: [CustomStringConvertible] = [
            "--templates",
            "\(templateFilePath)",
            "--sources",
            sources,
            "--output",
            testFilePath,
            "--cacheBasePath",
            generatedSourcesDirectory.string,
            "--args",
            "mainTarget=\(targetName)",
            "--args",
            "simulatorDevice=\(configuration?.simulatorDevice ?? defaultSimulatorDevice)",
            "--args",
            "simulatorOSVersion=\(configuration?.requiredOSVersion ?? defaultOSVersion)",
        ]

        configuration?.args?
            .forEach { key, values in
                // let valuesString = values.joined(separator: ",")
                arguments.append(contentsOf: ["--args", "\(key)=\(values)"])
            }

        if configuration?.testFilePath == nil {
            arguments.append(contentsOf: [
                "--args", "file=\(testTargetPath)/PreviewTests.swift"
            ])
        }

        Diagnostics.remark(
        """
        Prefire configuration
        Target used for tests: \(targetName)
        Preview sources path: \(sources)
        Generated test path: \(testFilePath)
        The Snapshot resources will be placed in the path: \(testTargetPath)
        Device for tests: \(configuration?.simulatorDevice ?? defaultSimulatorDevice)
        OS version for tests: \(configuration?.requiredOSVersion ?? defaultOSVersion)
        """
        )

        Diagnostics.remark("🟢 Prefire configured successfully!")

        return Command.prebuildCommand(
            displayName: "Running Prefire",
            executable: executable,
            arguments: arguments,
            outputFilesDirectory: generatedSourcesDirectory
        )
    }
}

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
