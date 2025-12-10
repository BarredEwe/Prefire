import Foundation
import PrefireCore
import PathKit

private enum Constants {
    static let defaultOutputName = "PreviewModels.generated.swift"
}

struct GeneratedPlaybookOptions {
    var targetPath: String?
    var sources: [Path]
    var output: Path
    var previewDefaultEnabled: Bool
    var template: Path?
    var cacheBasePath: Path?
    var imports: [String]?
    var testableImports: [String]?

    init(targetPath: String?, sources: [String], output: String?, template: String?, cacheBasePath: String?, config: Config?) throws {
        self.targetPath = config?.playbook.targetPath ?? targetPath
        self.sources = sources.isEmpty ? [.current] : sources.compactMap({ Path($0) })

        self.output = (output.flatMap({ Path($0) }) ?? .current) + Constants.defaultOutputName

        previewDefaultEnabled = config?.playbook.previewDefaultEnabled ?? true

        if let template = config?.playbook.template, let targetPath {
            let targetURL = URL(filePath: targetPath)
            let templateURL = targetURL.appending(path: template)
            self.template = Path(templateURL.absoluteURL.path(percentEncoded: false))
        } else if let template {
            self.template = Path(template)
        }

        self.cacheBasePath = cacheBasePath.flatMap({ Path($0) })
        imports = config?.playbook.imports
        testableImports = config?.playbook.testableImports
    }
}

enum GeneratePlaybookCommand {
    private enum Keys {
        static let imports = "imports"
        static let testableImports = "testableImports"
    }

    static func run(_ options: GeneratedPlaybookOptions) async throws {
        try await PrefireGenerator.generate(
            version: Prefire.Version.value,
            sources: options.sources,
            output: options.output,
            arguments: await makeArguments(for: options),
            inlineTemplate: try options.template?.read(.utf8) ?? EmbeddedTemplates.previewModels,
            defaultEnabled: options.previewDefaultEnabled,
            cacheDir: options.cacheBasePath,
            useGroupedSnapshots: true, // Playbooks are always grouped
            recordInDarkMode: false
        )
    }

    static func makeArguments(for options: GeneratedPlaybookOptions) async -> [String: NSObject] {
        Logger.info(
            """
            Prefire configuration
                ➜ Template path: \(options.template ?? "default")
                ➜ Generated models path: \(options.output)
                ➜ Preview default enabled: \(options.previewDefaultEnabled)
            """
        )

        return [
            Keys.imports: options.imports as? NSArray,
            Keys.testableImports: options.testableImports as? NSArray
        ].filter({ $0.value != nil }) as? [String: NSObject] ?? [:]
    }
}
