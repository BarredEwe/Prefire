import ArgumentParser
import Foundation

extension Prefire {
    struct Tests: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Generate Snapshot/Accessibility Tests")

        @Argument(help: "Paths to a source swift files or directories.")
        var sources: [String]

        @Option(help: "Path to the sourcery.")
        var sourcery: String
        @Option(help: "Path to your custom template.")
        var template: String

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

        func run() throws {
            try GenerateTestsCommand.run(
                GeneratedTestsOptions(
                    sourcery: sourcery,
                    target: target,
                    testTarget: testTarget,
                    template: template,
                    sources: sources,
                    output: output,
                    testTargetPath: testTargetPath,
                    cacheBasePath: cacheBasePath,
                    device: device,
                    osVersion: osVersion,
                    config: Config.load(from: config, testTargetPath: testTargetPath, verbose: verbose),
                    verbose: verbose
                )
            )
        }
    }
}
