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

        @Option(help: "Path to a config `.prefire.yml`.")
        var config: String?
        @Option(help: "Path to generated file.")
        var output: String
        @Option(help: "Path to Playbook destination target.")
        var targetPath: String?
        @Option(help: "Base path to the cache directory.")
        var cacheBasePath: String?

        @Flag(help: "Display full info")
        var verbose = false

        func run() throws {
            Logger.verbose = verbose

            try GeneratePlaybookCommand.run(
                GeneratedPlaybookOptions(
                    sourcery: sourcery,
                    targetPath: targetPath,
                    sources: sources,
                    output: output,
                    template: template,
                    cacheBasePath: cacheBasePath,
                    config: Config.load(from: config, testTargetPath: nil)
                )
            )
        }
    }
}
