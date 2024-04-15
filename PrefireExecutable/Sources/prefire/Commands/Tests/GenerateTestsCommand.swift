import Foundation

private enum Constants {
    static let snapshotFileName = "PreviewTests"
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
    var verbose: Bool

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

        let sources = options.sources
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
                    ➜ Template path: \(options.template)
                    ➜ Generated test path: \(output)
                    ➜ Snapshot resources path: \(snapshotOutput)
                """
            )
        }

        // Works with `#Preview` macro
        #if swift(>=5.9)
            let previewBodies = PreviewLoader.loadPreviewBodies(for: target, and: sources, defaultEnabled: options.prefireEnabledMarker)
        #else
            let previewBodies: String? = nil
        #endif

        let finalResult: [String: Any?] = [
            Keys.output: output,
            Keys.templates: [options.template],
            Keys.sources: options.sources,
            Keys.cacheBasePath: options.cacheBasePath,
            Keys.args: [
                Keys.simulatorOSVersion: options.osVersion,
                Keys.simulatorDevice: options.device,
                Keys.snapshotDevices: options.snapshotDevices?.joined(separator: "|"),
                Keys.previewsMacros: previewBodies,
                Keys.imports: "[\((options.imports ?? []).joined(separator: ","))]",
                Keys.testableImports: "[\((options.testableImports ?? []).joined(separator: ","))]",
                Keys.mainTarget: target,
                Keys.file: snapshotOutput,

            ] as [String: String?]
        ]

        let configFolder = options.cacheBasePath?.appending("/") ?? FileManager.default.temporaryDirectory.path()
        let filePath = configFolder + "sourcery.yml"

        do {
            try? FileManager.default.removeItem(atPath: filePath)
            try? FileManager.default.createDirectory(atPath: configFolder, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: filePath, contents: nil)

            let string = finalResult.makeYaml()
            try string.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            print(error)
        }

        return ["--config", filePath]
    }
}

extension Dictionary where Key == String, Value == Any? {
    func makeYaml() -> String {
        var result = ""

        for item in self {
            if let values = item.value as? [String] {
                result += "\(item.key):\n" + values.map({ "  - \($0)\n" }).reduce("", +)
            } else if let values = item.value as? [String: Any?] {
                result += "\(item.key):\n  " + values.makeYaml().replacingOccurrences(of: "\n", with: "\n  ")
                result.removeLast(2)
            } else if let value = item.value {
                result += "\(item.key): \(value)\n"
            }
        }

        return result
    }
}
