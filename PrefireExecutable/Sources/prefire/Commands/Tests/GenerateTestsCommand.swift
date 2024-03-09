import Foundation

private enum Constants {
    static let snapshotFileName = "PreviewTests"
}

struct GeneratedTestsOptions {
    var sourcery: String
    var target: String?
    var testTarget: String?
    var template: String
    var sources: String?
    var output: String?
    var prefireEnabledMarker: Bool
    var testTargetPath: String?
    var cacheBasePath: String?
    var device: String?
    var osVersion: String?
    var snapshotDevices: [String]?
    var imports: [String]?
    var testableImports: [String]?
    var verbose: Bool

    init(
        sourcery: String,
        target: String?,
        testTarget: String?,
        template: String,
        sources: String?,
        output: String?,
        testTargetPath: String?,
        cacheBasePath: String?,
        device: String?,
        osVersion: String?,
        config: Config?,
        verbose: Bool
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
        
        self.sources = sources
        self.output = config?.tests.testFilePath ?? output
        prefireEnabledMarker = config?.tests.previewDefaultEnabled ?? true
        self.testTargetPath = testTargetPath
        self.cacheBasePath = cacheBasePath
        self.device = config?.tests.device ?? device
        self.osVersion = config?.tests.osVersion ?? osVersion
        snapshotDevices = config?.tests.snapshotDevices
        imports = config?.tests.imports
        testableImports = config?.tests.testableImports
        self.verbose = verbose
    }
}

enum GenerateTestsCommand {
    private enum Keys {
        static let templates = "--templates"
        static let sources = "--sources"
        static let output = "--output"
        static let cacheBasePath = "--cacheBasePath"
        static let args = "--args"

        static let mainTarget = "mainTarget"
        static let file = "file"
        static let imports = "imports"
        static let testableImports = "testableImports"
        static let previewsMacros = "previewsMacros"
    }

    static func run(_ options: GeneratedTestsOptions) throws {
        let task = Process()
        task.executableURL = URL(filePath: options.sourcery)
        task.arguments = makeArguments(for: options)

        try task.run()
        task.waitUntilExit()
    }

    static func makeArguments(for options: GeneratedTestsOptions) -> [String] {
        guard let target = options.target else {
            fatalError("You must provide the --target")
        }

        var arguments = [String]()

        let sources = options.sources ?? FileManager.default.currentDirectoryPath
        let output = options.output ?? FileManager.default.currentDirectoryPath.appending("/\(Constants.snapshotFileName).generated.swift")
        let snapshotOutput = (options.testTargetPath ?? FileManager.default.currentDirectoryPath)
            .appending("/\(Constants.snapshotFileName).swift")

        if options.verbose {
            print(
                """
                Prefire configuration
                    ➜ Target used for tests: \(target)
                    ➜ Tests target: \(options.testTarget ?? "nil")
                    ➜ Sourcery path: \(options.sourcery)
                    ➜ Sources path: \(sources)
                    ➜ Template path: \(options.template)
                    ➜ Generated test path: \(output)
                    ➜ Snapshot resources path: \(snapshotOutput)
                """
            )
        }

        arguments = [
            Keys.sources, sources,
            Keys.output, output,
            Keys.templates, options.template,
            Keys.args, "\(Keys.mainTarget)=\(target)",
            Keys.args, "\(Keys.file)=\(snapshotOutput)",
        ]

        if let osVersion = options.osVersion {
            arguments.append(contentsOf: [Keys.args, "simulatorOSVersion=\(osVersion)"])
        }

        if let device = options.device {
            arguments.append(contentsOf: [Keys.args, "simulatorDevice=\(device)"])
        }
        
        if let snapshotDevices = options.snapshotDevices {
            arguments.append(contentsOf: [Keys.args, "snapshotDevices=\(snapshotDevices.joined(separator: "|"))"])
        }

        if let imports = options.imports, !imports.isEmpty {
            arguments.append(contentsOf: imports.makeSourceryArgs(name: Keys.imports))
        }

        if let testableImports = options.testableImports, !testableImports.isEmpty {
            arguments.append(contentsOf: testableImports.makeSourceryArgs(name: Keys.testableImports))
        }

        // Works with `#Preview` macro
        #if swift(>=5.9)
            if let previewMacrosSnapshotingFunc = PreviewLoader.loadPreviewBodies(for: target, and: sources, defaultEnabled: options.prefireEnabledMarker) {
                arguments.append(contentsOf: [Keys.args, "previewsMacros=\"\(previewMacrosSnapshotingFunc)\""])
            }
        #endif

        if let cacheBasePath = options.cacheBasePath {
            arguments.append(contentsOf: [Keys.cacheBasePath, cacheBasePath])
        }

        return arguments
    }
}
