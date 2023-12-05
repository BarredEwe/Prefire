import Foundation

struct GeneratedPlaybookOptions {
    var sourcery: String
    var target: String?
    var sources: String?
    var output: String?
    var template: String
    var cacheBasePath: String?
    var imports: [String]?
    var testableImports: [String]?
    var verbose: Bool

    init(sourcery: String, target: String?, sources: String?, output: String?, template: String, cacheBasePath: String?, config: Config?, verbose: Bool) {
        self.sourcery = sourcery
        self.target = target
        self.sources = sources
        self.output = output
        self.template = template
        self.cacheBasePath = cacheBasePath
        imports = config?.imports
        testableImports = config?.testableImports
        self.verbose = verbose
    }
}

enum GeneratePlaybookCommand {
    static func run(_ options: GeneratedPlaybookOptions) throws {
        let task = Process()
        task.executableURL = URL(filePath: options.sourcery)

        task.arguments = [
            "--templates", options.template,
            "--sources", options.sources ?? FileManager.default.currentDirectoryPath,
            "--output", options.output ?? (FileManager.default.currentDirectoryPath + "/PreviewModels.generated.swift"),
        ]

        if let cacheBasePath = options.cacheBasePath {
            task.arguments?.append(contentsOf: ["--cacheBasePath", cacheBasePath])
        }

        if var imports = options.imports, !imports.isEmpty {
            // It is used so that sourcery can determine the type of the parameter as an array
            imports.append("last")

            let importsArguments = imports.map { "imports=" + $0 }.joined(separator: ",")
            task.arguments?.append(contentsOf: ["--args", importsArguments])
        }

        if var testableImports = options.testableImports, !testableImports.isEmpty {
            // It is used so that sourcery can determine the type of the parameter as an array
            testableImports.append("last")

            let importsArguments = testableImports.map { "testableImports=" + $0 }.joined(separator: ",")
            task.arguments?.append(contentsOf: ["--args", importsArguments])
        }

        let target = options.target ?? (FileManager.default.currentDirectoryPath as NSString).lastPathComponent

        // Works with `#Preview` macro
        #if swift(>=5.9)
            if let macroPreviewBodies = PreviewLoader.loadMacroPreviewBodies(for: target) {
                task.arguments?.append(contentsOf: ["--args", "macroPreviewBodies=\"\(macroPreviewBodies)\""])
            }
        #endif

        if options.verbose {
            print(
                """
                Prefire configuration
                Sourcery url: \(options.sourcery)
                Target used for tests: \(target)
                Template path: \(options.template)
                """
            )
        }

        try task.run()
        task.waitUntilExit()
    }
}
