import Foundation

struct GeneratedTestsOptions {
    var sourcery: String
    var target: String?
    var template: String
    var sources: String?
    var output: String?
    var cacheBasePath: String?
    var device: String?
    var osVersion: String?
    var verbose: Bool

    init(sourcery: String, target: String?, template: String, sources: String?, output: String?, cacheBasePath: String?, device: String?, osVerison: String?, config: Config?, verbose: Bool) {
        self.sourcery = sourcery
        self.target = config?.target ?? target
        self.template = config?.template ?? template
        self.sources = sources
        self.output = config?.testFilePath ?? output
        self.cacheBasePath = cacheBasePath
        self.device = config?.device ?? device
        osVersion = config?.osVersion ?? osVerison
        self.verbose = verbose
    }
}

enum GenerateTestsCommand {
    static func run(_ options: GeneratedTestsOptions) throws {
        guard let target = options.target else {
            fatalError("You must provide the --target")
        }

        let task = Process()
        task.executableURL = URL(filePath: options.sourcery)

        let sources = options.sources ?? FileManager.default.currentDirectoryPath
        let output = options.output ?? (FileManager.default.currentDirectoryPath + "/PreviewTests.generated.swift")
        let snapshotsPath = (options.sources?.appending("/\(target)") ?? FileManager.default.currentDirectoryPath).appending("/PreviewTests.swift")

        if options.verbose {
            print(
                """
                Prefire configuration
                Sourcery url: \(options.sourcery)
                Target used for tests: \(target)
                Template path: \(options.template)
                Generated test path: \(output)
                The Snapshot resources will be placed in the path: \(snapshotsPath)
                """
            )
        }

        task.arguments = [
            "--sources", sources,
            "--output", output,
            "--templates", options.template,
            "--args", "mainTarget=\(target)",
            "--args", "file=\(snapshotsPath)",
        ]

        if let osVersion = options.osVersion {
            task.arguments?.append(contentsOf: ["--args", "simulatorOSVersion=\(osVersion)"])
        }

        if let device = options.device {
            task.arguments?.append(contentsOf: ["--args", "simulatorDevice=\(device)"])
        }

        #if swift(>=5.9)
            if let previewMacrosSnapshotingFunc = PreviewLoader.loadPreviewBodies(for: target) {
                task.arguments?.append(contentsOf: ["--args", "previewsMacros=\"\(previewMacrosSnapshotingFunc)\""])
            }
        #endif

        if let cacheBasePath = options.cacheBasePath {
            task.arguments?.append(contentsOf: ["--cacheBasePath", cacheBasePath])
        }

        try task.run()
        task.waitUntilExit()
    }
}
