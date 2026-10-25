@preconcurrency import ArgumentParser
import Foundation
import PrefireCore

/// Options of the commands that render previews, over the `render_configuration` of `.prefire.yml`.
struct RenderSetupOptions: ParsableArguments {
    @Option(help: "Path to a config `.prefire.yml`.")
    var config: String?

    @Option(help: "Scheme whose tests include the generated snapshot tests.")
    var scheme: String?
    @Option(help: "Path to the `.xcworkspace`.")
    var workspace: String?
    @Option(help: "Path to the `.xcodeproj`.")
    var project: String?
    @Option(help: "Destination of `xcodebuild`. Default: '\(RenderConfiguration.defaultDestination)'.")
    var destination: String?
    @Option(help: "Target of the generated snapshot tests. Lets only the tests of the previews asked for run.")
    var testTarget: String?
    @Option(help: "Directory of the images and `manifest.json`. Default: '\(RenderConfiguration.defaultOutputDirectory)'.")
    var output: String?
    @Option(name: .customLong("source"), help: "Source file or directory the previews are in. Can be repeated.")
    var sources: [String] = []
    @Option(
        name: .customLong("xcodebuild-arg"),
        parsing: .unconditionalSingleValue,
        help: "Argument passed on to xcodebuild, like '--xcodebuild-arg -derivedDataPath --xcodebuild-arg .build'. Can be repeated."
    )
    var xcodebuildArgs: [String] = []

    @Flag(help: "Display full info")
    var verbose = false

    func loadConfig() -> Config? {
        Config.load(from: config, testTargetPath: nil, env: Self.environment(config: config))
    }

    /// Environment `.prefire.yml` is read with. Outside of Xcode `PROJECT_DIR`, which configs use for
    /// their sources, is the folder of the config, or the current one.
    static func environment(config: String?) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if environment["PROJECT_DIR"] == nil {
            let directory = config.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
            environment["PROJECT_DIR"] = directory ?? FileManager.default.currentDirectoryPath
        }
        return environment
    }

    /// Directory of the render, which `prefire board` reads without building anything.
    func outputDirectory(config: Config?) -> URL {
        URL(fileURLWithPath: output ?? config?.render.outputDir ?? RenderConfiguration.defaultOutputDirectory)
    }

    /// - Parameter requiresScheme: `false` when nothing is built, like for listing the previews.
    func renderConfiguration(config: Config?, requiresScheme: Bool = true) throws -> RenderConfiguration {
        guard let scheme = scheme ?? config?.render.scheme ?? (requiresScheme ? nil : "") else {
            throw ValidationError("Set the scheme with `--scheme` or `render_configuration: - scheme:` in `.prefire.yml`.")
        }
        let workspace = workspace ?? (project == nil ? config?.render.workspace : nil)
        let project = project ?? (workspace == nil ? config?.render.project : nil)
        let sources = !sources.isEmpty ? sources : config?.render.sources ?? config?.tests.sources ?? [FileManager.default.currentDirectoryPath]

        return RenderConfiguration(
            scheme: scheme,
            workspace: workspace,
            project: project,
            destination: destination ?? config?.render.destination ?? RenderConfiguration.defaultDestination,
            testTarget: testTarget ?? config?.render.testTarget,
            outputDirectory: outputDirectory(config: config),
            sources: sources,
            previewDefaultEnabled: config?.tests.previewDefaultEnabled ?? true,
            useGroupedSnapshots: config?.tests.useGroupedSnapshots ?? true,
            xcodebuildArguments: (config?.render.xcodebuildArgs ?? []) + xcodebuildArgs,
            testsHaveDefaultNames: config?.tests.template == nil,
            launchesTestsDirectly: config?.render.directLaunch ?? true
        )
    }
}
