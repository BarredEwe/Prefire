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
        imports = config?.playbook.imports
        testableImports = config?.playbook.testableImports
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

        if let imports = options.imports, !imports.isEmpty {
            task.arguments?.append(contentsOf: imports.makeArgs(name: "imports"))
        }

        if let testableImports = options.testableImports, !testableImports.isEmpty {
            task.arguments?.append(contentsOf: testableImports.makeArgs(name: "testableImports"))
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
