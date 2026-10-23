@preconcurrency import ArgumentParser
import Foundation
import PrefireCore

extension Prefire {
    struct Board: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Write an HTML flow board of the last render",
            discussion: """
            Groups the previews of `manifest.json` by `previewUserStory`, keeps the order they are declared \
            in, and shows their `previewState`. Writes `board.html` next to the manifest.
            """
        )

        @Flag(help: "Put the images into the page, so it can be shared on its own.")
        var embedImages = false

        @Option(help: "Path to a config `.prefire.yml`.")
        var config: String?
        @Option(help: "Directory of the render. Default: '\(RenderConfiguration.defaultOutputDirectory)'.")
        var output: String?

        func run() throws {
            // Standard output carries the path of the board only.
            Logger.output = .standardError
            let config = Config.load(from: config, testTargetPath: nil, env: RenderSetupOptions.environment(config: config))
            let directory = URL(fileURLWithPath: output ?? config?.render.outputDir ?? RenderConfiguration.defaultOutputDirectory)

            guard FileManager.default.fileExists(atPath: directory.appendingPathComponent(RenderManifest.fileName).path) else {
                throw ValidationError("No \(RenderManifest.fileName) in \(directory.path). Run `prefire render` first.")
            }
            print(try BoardRenderer.write(directory: directory, embedImages: embedImages).path)
        }
    }
}
