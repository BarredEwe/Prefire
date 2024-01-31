import Foundation

private enum Constants {
    static let outputFileName = "PreviewModels.generated.swift"
}

struct GeneratedPlaybookOptions {
    var sourcery: String
    var target: String?
    var sources: String
    var output: String
    var template: String
    var cacheBasePath: String?
    var imports: [String]?
    var testableImports: [String]?
    var verbose: Bool

    init(sourcery: String, target: String?, sources: String?, output: String?, template: String, cacheBasePath: String?, config: Config?, verbose: Bool) {
        self.sourcery = sourcery
        self.target = target
        self.sources = sources ?? FileManager.default.currentDirectoryPath
        self.output = output ?? "\(FileManager.default.currentDirectoryPath)/\(Constants.outputFileName)"
        self.template = template
        self.cacheBasePath = cacheBasePath
        imports = config?.playbook.imports
        testableImports = config?.playbook.testableImports
        self.verbose = verbose
    }
}

enum GeneratePlaybookCommand {
    private enum Keys {
        static let templates = "--templates"
        static let sources = "--sources"
        static let output = "--output"
        static let cacheBasePath = "--cacheBasePath"
        static let args = "--args"

        static let imports = "imports"
        static let testableImports = "testableImports"
        static let macroPreviewBodies = "macroPreviewBodies"
    }

    static func run(_ options: GeneratedPlaybookOptions) throws {
        let task = Process()
        task.executableURL = URL(filePath: options.sourcery)

        task.arguments = [
            Keys.templates, options.template,
            Keys.sources, options.sources,
            Keys.output, options.output,
        ]

        if let cacheBasePath = options.cacheBasePath {
            task.arguments?.append(contentsOf: [Keys.cacheBasePath, cacheBasePath])
        }

        if let imports = options.imports, !imports.isEmpty {
            task.arguments?.append(contentsOf: imports.makeSourceryArgs(name: Keys.imports))
        }

        if let testableImports = options.testableImports, !testableImports.isEmpty {
            task.arguments?.append(contentsOf: testableImports.makeSourceryArgs(name: Keys.testableImports))
        }

        let target = options.target ?? (FileManager.default.currentDirectoryPath as NSString).lastPathComponent

        // Works with `#Preview` macro
        #if swift(>=5.9)
            if let macroPreviewBodies = PreviewLoader.loadMacroPreviewBodies(for: target, and: options.sources) {
                task.arguments?.append(contentsOf: [Keys.args, Keys.macroPreviewBodies + "=\"\(macroPreviewBodies)\""])
            }
        #endif

        if options.verbose {
            print(
                """
                Prefire configuration
                    ➜ Target used for tests: \(target)
                    ➜ Sources path: \(options.sources)
                    ➜ Sourcery path: \(options.sourcery)
                    ➜ Template path: \(options.template)
                """
            )
        }

        try task.run()
        task.waitUntilExit()
    }
}
