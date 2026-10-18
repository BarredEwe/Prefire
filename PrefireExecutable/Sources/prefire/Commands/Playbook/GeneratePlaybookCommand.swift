import Foundation
import PrefireCore
import PathKit

private enum Constants {
    static let defaultOutputName = "PreviewModels.generated.swift"
}

struct GeneratedPlaybookOptions {
    let targetPath: String?
    let sources: [Path]
    let output: Path
    let previewDefaultEnabled: Bool
    let template: Path?
    let cacheBasePath: Path?
    let imports: [String]?
    let testableImports: [String]?
}

// MARK: - Factory

extension GeneratedPlaybookOptions {
    /// Creates GeneratedPlaybookOptions by merging CLI options with Config
    /// - Parameters:
    ///   - cli: Raw CLI options
    ///   - config: Loaded config (optional)
    /// - Returns: Fully resolved GeneratedPlaybookOptions
    static func from(
        cli: CLIPlaybookOptions,
        config: Config?
    ) -> GeneratedPlaybookOptions {
        let targetPath = config?.playbook.targetPath ?? cli.targetPath

        let template = OptionsResolver.resolveTemplate(
            cliTemplate: cli.template,
            configTemplate: config?.playbook.template,
            targetPath: targetPath.flatMap { Path($0) }
        )

        return GeneratedPlaybookOptions(
            targetPath: targetPath,
            sources: OptionsResolver.resolveSources(cli.sources),
            output: OptionsResolver.resolveOutput(cli.output, defaultFileName: Constants.defaultOutputName),
            previewDefaultEnabled: config?.playbook.previewDefaultEnabled ?? true,
            template: template,
            cacheBasePath: cli.cacheBasePath.flatMap { Path($0) },
            imports: config?.playbook.imports,
            testableImports: config?.playbook.testableImports
        )
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
            useGroupedSnapshots: true // Playbooks are always grouped
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
