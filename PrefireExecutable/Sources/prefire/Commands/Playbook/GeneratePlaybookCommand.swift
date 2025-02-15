import Foundation

private enum Constants {
    static let configFileName = "sourcery.yml"
    static let templatePath = "/opt/homebrew/Cellar/Prefire/\(Prefire.Version.value)/libexec/PreviewModels.stencil"
    static let defaultOutputName = "/PreviewModels.generated.swift"
}

struct GeneratedPlaybookOptions {
    var sourcery: String?
    var targetPath: String?
    var sources: [String]
    var output: String
    var previewDefaultEnabled: Bool
    var template: String
    var cacheBasePath: String?
    var imports: [String]?
    var testableImports: [String]?

    init(sourcery: String?, targetPath: String?, sources: [String], output: String?, template: String?, cacheBasePath: String?, config: Config?) throws {
        self.sourcery = sourcery
        self.targetPath = config?.playbook.targetPath ?? targetPath
        self.sources = sources.isEmpty ? [FileManager.default.currentDirectoryPath] : sources
        self.output = output ?? FileManager.default.currentDirectoryPath.appending(Constants.defaultOutputName)
        previewDefaultEnabled = config?.playbook.previewDefaultEnabled ?? true

        if let template = config?.playbook.template, let targetPath {
            let targetURL = URL(filePath: targetPath)
            let templateURL = targetURL.appending(path: template)
            self.template = templateURL.absoluteURL.path()
        } else if let template {
            self.template = template
        } else {
            guard FileManager.default.fileExists(atPath: Constants.templatePath) else {
                throw NSError(domain: "Cannot find template", code: 0)
            }
            self.template = Constants.templatePath
        }

        self.cacheBasePath = cacheBasePath
        imports = config?.playbook.imports
        testableImports = config?.playbook.testableImports
    }
}

enum GeneratePlaybookCommand {
    private enum Keys {
        static let templates = "templates"
        static let sources = "sources"
        static let output = "output"
        static let cacheBasePath = "cacheBasePath"
        static let args = "args"

        static let imports = "imports"
        static let testableImports = "testableImports"
        static let macroPreviewBodies = "macroPreviewBodies"
    }

    static func run(_ options: GeneratedPlaybookOptions) async throws {
        let task = Process()
        task.executableURL = URL(filePath: options.sourcery ?? "/usr/bin/env")

        let rawArguments = await makeArguments(for: options)
        let yamlContent = YAMLParser().string(from: rawArguments)
        let filePath = (options.cacheBasePath?.appending("/") ?? FileManager.default.temporaryDirectory.path())
            .appending(Constants.configFileName)

        yamlContent.rewrite(toFile: URL(string: filePath))

        task.arguments = ["--config", filePath]
        if options.sourcery == nil {
            task.arguments?.insert("sourcery", at: 0)
        }

        try task.run()
        task.waitUntilExit()
    }

    static func makeArguments(for options: GeneratedPlaybookOptions) async -> [String: Any?] {
        // Works with `#Preview` macro
        let previewBodies = await PreviewLoader.loadMacroPreviewBodies(for: options.sources, defaultEnabled: options.previewDefaultEnabled)

        Logger.print(
            """
            Prefire configuration
                ➜ Sourcery path: \(options.sourcery ?? "")
                ➜ Template path: \(options.template)
                ➜ Generated test path: \(options.output)
                ➜ Preview default enabled: \(options.previewDefaultEnabled)
            """
        )

        let arguments: [String: Any?] = [
            Keys.templates: [options.template],
            Keys.output: options.output,
            Keys.sources: options.sources,
            Keys.cacheBasePath: options.cacheBasePath,
            Keys.args: [
                Keys.imports: options.imports,
                Keys.testableImports: options.testableImports,
                Keys.macroPreviewBodies: previewBodies
            ] as [String: Any?]
        ]

        return arguments
    }
}
