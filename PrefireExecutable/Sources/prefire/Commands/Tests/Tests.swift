import ArgumentParser
import Foundation

extension Prefire {
    struct Tests: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Generate Snapshot/Accessibility Tests")

        @Flag(help: "Display full info")
        var verbose = false

        @Option(help: "Path to the sourcery.")
        var sourcery: String
        @Option(help: "Path to your custom template.")
        var template: String

        @Option(help: "Your project Target for Snapshot tests.")
        var target: String?

        @Option(help: "Path to a source swift files or directories.")
        var sources: String?
        @Option(help: "Path to a config `.prefire.yml`.")
        var config: String?
        @Option(help: "Path to generated file.")
        var output: String?
        @Option(help: "Path to generated snapshot files `__Snapshot__`")
        var snapshotOutput: String?
        @Option(help: "Base path to the cache directory.")
        var cacheBasePath: String?
        @Option(help: "Required Device for Snapshot testing.")
        var device: String?
        @Option(help: "Required OS version for Snapshot testing.")
        var osVersion: String?

        func run() throws {
            try GenerateTestsCommand.run(
                GeneratedTestsOptions(
                    sourcery: sourcery,
                    target: target,
                    template: template,
                    sources: sources,
                    output: output,
                    snapshotOutput: snapshotOutput,
                    cacheBasePath: cacheBasePath,
                    device: device,
                    osVerison: osVersion,
                    config: Config.load(from: config, verbose: verbose),
                    verbose: verbose
                )
            )
        }
    }
}
