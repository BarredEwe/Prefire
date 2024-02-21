import ArgumentParser
import Foundation

extension Prefire {
    struct Playbook: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Generate Playbook")

        @Argument(help: "Paths to a source swift files or directories.")
        var sources: [String]

        @Option(help: "Path to the sourcery.")
        var sourcery: String
        @Option(help: "Path to your custom template.")
        var template: String

        @Option(help: "Your project Target for Playbook.")
        var target: String?
        @Option(help: "Path to a config `.prefire.yml`.")
        var config: String?
        @Option(help: "Path to generated file.")
        var output: String?
        @Option(help: "Base path to the cache directory.")
        var cacheBasePath: String?

        @Flag(help: "Display full info")
        var verbose = false

        func run() throws {
            try GeneratePlaybookCommand.run(
                GeneratedPlaybookOptions(
                    sourcery: sourcery,
                    target: target,
                    sources: sources,
                    output: output,
                    template: template,
                    cacheBasePath: cacheBasePath,
                    config: Config.load(from: config, testTargetPath: nil, verbose: verbose),
                    verbose: verbose
                )
            )
        }
    }
}
