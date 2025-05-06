import Foundation

private enum Constants {
    static let snapshotFileName = "PreviewTests"
    static let configFileName = "sourcery.yml"
    static let templatePath = "/opt/homebrew/Cellar/Prefire/\(Prefire.Version.value)/libexec/PreviewTests.stencil"
}

struct GeneratedTestsOptions {
    var sourcery: String?
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
        sourcery: String?,
        target: String?,
        testTarget: String?,
        template: String?,
        sources: [String],
        output: String?,
        testTargetPath: String?,
        cacheBasePath: String?,
        device: String?,
        osVersion: String?,
        config: Config?
    ) throws {
        self.sourcery = sourcery
        self.target = config?.tests.target ?? target
        self.testTarget = testTarget
        self.testTargetPath = config?.tests.testTargetPath ?? testTargetPath

        if let template = config?.tests.template, let testTargetPath = self.testTargetPath {
            let testTargetURL = URL(filePath: testTargetPath)
            let templateURL = testTargetURL.appending(path: template)
            self.template = templateURL.absoluteURL.path()
        } else if let template {
            self.template = template
        } else {
            guard FileManager.default.fileExists(atPath: Constants.templatePath) else {
                throw NSError(domain: "❌ Template not found at path: \(Constants.templatePath)", code: 0)
            }
            self.template = Constants.templatePath
        }
        
        self.sources = config?.tests.sources ?? sources
        self.output = config?.tests.testFilePath ?? output
        prefireEnabledMarker = config?.tests.previewDefaultEnabled ?? true
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
        static let previewsMacrosDict = "previewsMacrosDict"
    }

    static func run(_ options: GeneratedTestsOptions) async throws {
        let task = Process()
        task.executableURL = URL(filePath: options.sourcery ?? "/usr/bin/env")

        let rawArguments = await makeArguments(for: options)
        let yamlContent = YAMLParser().string(from: rawArguments)
        let filePath = (options.cacheBasePath?.appending("/") ?? FileManager.default.temporaryDirectory.path())
            .appending(Constants.configFileName)

        try yamlContent.rewrite(toFile: URL(string: filePath))

        task.arguments = ["--config", filePath]
        if options.sourcery == nil {
            task.arguments?.insert("sourcery", at: 0)
        }

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
                ➜ Sourcery path: \(options.sourcery ?? "nil")
                ➜ Template path: \(options.template)
                ➜ Generated test path: \(output)
                ➜ Snapshot resources path: \(snapshotOutput ?? "nil")
                ➜ Preview default enabled: \(options.prefireEnabledMarker)
            """
        )

        // Works with `#Preview` macro
        let (previewBodies, previewModels) =
            await PreviewLoader.loadPreviewMacros(for: sources, defaultEnabled: options.prefireEnabledMarker) ?? (nil, nil)

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
                Keys.previewsMacrosDict: previewModels,
                Keys.imports: options.imports,
                Keys.testableImports: options.testableImports,
                Keys.mainTarget: options.target,
                Keys.file: snapshotOutput,
            ] as [String: Any?]
        ]

        return arguments
    }
}
