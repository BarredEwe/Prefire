import Foundation

private enum Constants {
    static let snapshotFileName = "PreviewTests"
    static let configFileName = "sourcery.yml"
}

struct GeneratedTestsOptions {
    var sourcery: String
    var target: String?
    var testTarget: String?
    var template: String
    var sources: [String]
    var output: String?
    var prefireEnabledMarker: Bool
    var testTargetPath: String?
    var cacheBasePath: String?
    var device: String?
    var osVersion: String?
    var snapshotDevices: [String]?
    var imports: [String]?
    var testableImports: [String]?

    init(
        sourcery: String,
        target: String?,
        testTarget: String?,
        template: String,
        sources: [String],
        output: String?,
        testTargetPath: String?,
        cacheBasePath: String?,
        device: String?,
        osVersion: String?,
        config: Config?
    ) {
        self.sourcery = sourcery
        self.target = config?.tests.target ?? target
        self.testTarget = testTarget
        
        if let template = config?.tests.template, let testTargetPath {
            let testTargetURL = URL(filePath: testTargetPath)
            let templateURL = testTargetURL.appending(path: template)
            self.template = templateURL.absoluteURL.path()
        } else {
            self.template = template
        }
        
        self.sources = config?.tests.sources ?? sources
        self.output = config?.tests.testFilePath ?? output
        prefireEnabledMarker = config?.tests.previewDefaultEnabled ?? true
        self.testTargetPath = testTargetPath
        self.cacheBasePath = cacheBasePath
        self.device = config?.tests.device ?? device
        self.osVersion = config?.tests.osVersion ?? osVersion
        snapshotDevices = config?.tests.snapshotDevices
        imports = config?.tests.imports
        testableImports = config?.tests.testableImports
    }
}

enum GenerateTestsCommand {
    private enum Keys {
        static let templates = "templates"
        static let sources = "sources"
        static let output = "output"
        static let cacheBasePath = "cacheBasePath"
        static let args = "args"

        static let simulatorOSVersion = "simulatorOSVersion"
        static let simulatorDevice = "simulatorDevice"
        static let snapshotDevices = "snapshotDevices"
        static let mainTarget = "mainTarget"
        static let file = "file"
        static let imports = "imports"
        static let testableImports = "testableImports"
        static let previewsMacros = "previewsMacros"
    }

    static func run(_ options: GeneratedTestsOptions) async throws {
        let task = Process()
        task.executableURL = URL(filePath: options.sourcery)

        let rawArguments = await makeArguments(for: options)
        let yamlContent = YAMLParser().string(from: rawArguments)
        let filePath = (options.cacheBasePath?.appending("/") ?? FileManager.default.temporaryDirectory.path())
            .appending(Constants.configFileName)

        yamlContent.rewrite(toFile: URL(string: filePath))

        task.arguments =  ["--config", filePath]

        try task.run()
        task.waitUntilExit()
    }

    static func makeArguments(for options: GeneratedTestsOptions) async -> [String: Any?] {
        let sources = options.sources
        let output = options.output ?? FileManager.default.currentDirectoryPath.appending("/\(Constants.snapshotFileName).generated.swift")
        let snapshotOutput = options.testTargetPath?.appending("/\(Constants.snapshotFileName).swift")

        Logger.print(
            """
            Prefire configuration
                ➜ Target used for tests: \(options.target ?? "nil")
                ➜ Tests target: \(options.testTarget ?? "nil")
                ➜ Sourcery path: \(options.sourcery)
                ➜ Template path: \(options.template)
                ➜ Generated test path: \(output)
                ➜ Snapshot resources path: \(snapshotOutput ?? "nil")
                ➜ Preview default enabled: \(options.prefireEnabledMarker)
            """
        )

        // Works with `#Preview` macro
        let previewBodies = await PreviewLoader.loadPreviewBodies(for: sources, defaultEnabled: options.prefireEnabledMarker)

        let arguments: [String: Any?] = [
            Keys.output: output,
            Keys.templates: [options.template],
            Keys.sources: options.sources,
            Keys.cacheBasePath: options.cacheBasePath,
            Keys.args: [
                Keys.simulatorOSVersion: options.osVersion,
                Keys.simulatorDevice: options.device,
                Keys.snapshotDevices: options.snapshotDevices?.joined(separator: "|"),
                Keys.previewsMacros: previewBodies,
                Keys.imports: options.imports,
                Keys.testableImports: options.testableImports,
                Keys.mainTarget: options.target,
                Keys.file: snapshotOutput,
            ] as [String: Any?]
        ]

        return arguments
    }
}
