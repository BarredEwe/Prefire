@preconcurrency import ArgumentParser
import Foundation
import PrefireCore

extension Prefire {
    struct Playbook: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Generate Playbook")

        @Argument(help: "Paths to a source swift files or directories.")
        var sources: [String] = [FileManager.default.currentDirectoryPath]

        @Option(help: "Path to your custom template.")
        var template: String?

        @Option(help: "Path to a config `.prefire.yml`.")
        var config: String?
        @Option(help: "Path to generated file.")
        var output: String?
        @Option(help: "Path to Playbook destination target.")
        var targetPath: String?
        @Option(help: "Base path to the cache directory.")
        var cacheBasePath: String?

        @Flag(help: "Display full info")
        var verbose = false

        func run() async throws {
            Logger.level = verbose ? .verbose : .warnings
            let config = Config.load(from: config, testTargetPath: nil, env: ProcessInfo.processInfo.environment)

            try await GeneratePlaybookCommand.run(
                GeneratedPlaybookOptions(
                    targetPath: targetPath,
                    sources: sources,
                    output: output,
                    template: template,
                    cacheBasePath: cacheBasePath,
                    config: config
                )
            )
        }
    }
}
