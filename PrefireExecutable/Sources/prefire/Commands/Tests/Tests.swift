@preconcurrency import ArgumentParser
import Foundation
import PrefireCore

extension Prefire {
    struct Tests: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Generate Snapshot/Accessibility Tests")

        @Argument(help: "Paths to a source swift files or directories.")
        var sources: [String] = [FileManager.default.currentDirectoryPath]

        @Option(help: "Path to your custom template.")
        var template: String?

        @Option(help: "Your project Target tested by snapshots.")
        var target: String?
        @Option(help: "Your Snapshot Tests Target.")
        var testTarget: String?

        @Option(help: "Path to a config `.prefire.yml`.")
        var config: String?
        @Option(help: "Path to generated file.")
        var output: String?
        @Option(help: "Path to your Snapshot Tests Target.")
        var testTargetPath: String?
        @Option(help: "Base path to the cache directory.")
        var cacheBasePath: String?
        @Option(help: "Required Device for Snapshot testing.")
        var device: String?
        @Option(help: "Required OS version for Snapshot testing.")
        var osVersion: String?

        @Flag(help: "Display full info")
        var verbose = false

        func run() async throws {
            Logger.level = verbose ? .verbose : .warnings

            let cliOptions = CLITestsOptions(
                target: target,
                testTarget: testTarget,
                template: template,
                sources: sources,
                output: output,
                testTargetPath: testTargetPath,
                cacheBasePath: cacheBasePath,
                device: device,
                osVersion: osVersion
            )

            let loadedConfig = Config.load(
                from: config,
                testTargetPath: testTargetPath,
                env: ProcessInfo.processInfo.environment
            )

            let options = GeneratedTestsOptions.from(
                cli: cliOptions,
                config: loadedConfig
            )

            try await GenerateTestsCommand.run(options)
        }
    }
}
