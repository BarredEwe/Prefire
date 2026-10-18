import Foundation
import PrefireCore
import PathKit

private enum Constants {
    static let snapshotFileName = "PreviewTests.generated.swift"
    static let snapshotFileTemplated = "{PREVIEW_FILE_NAME}Tests.generated.swift"
}

struct GeneratedTestsOptions {
    let target: String?
    let testTarget: String?
    let template: Path?
    let sources: [Path]
    let output: Path
    let prefireEnabledMarker: Bool
    let testTargetPath: Path?
    let cacheBasePath: Path?
    let device: String?
    let osVersion: String?
    let snapshotDevices: [String]?
    let imports: [String]?
    let testableImports: [String]?
    let useGroupedSnapshots: Bool
    let splitSnapshotDirectories: Bool
    let drawHierarchyInKeyWindowDefaultEnabled: Bool?
    let fullPageSnapshots: Bool
}

// MARK: - Factory

extension GeneratedTestsOptions {
    /// Creates GeneratedTestsOptions by merging CLI options with Config
    /// - Parameters:
    ///   - cli: Raw CLI options
    ///   - config: Loaded config (optional)
    /// - Returns: Fully resolved GeneratedTestsOptions
    static func from(cli: CLITestsOptions, config: Config?) -> GeneratedTestsOptions {
        let target = config?.tests.target ?? cli.target
        let testTarget = cli.testTarget
        let sources = config?.tests.sources ?? cli.sources
        let output = config?.tests.testFilePath ?? cli.output
        let device = config?.tests.device ?? cli.device
        let osVersion = config?.tests.osVersion ?? cli.osVersion

        let rawTestTargetPath = config?.tests.testTargetPath ?? cli.testTargetPath
        let testTargetPath = OptionsResolver.resolvePath(
            rawTestTargetPath,
            target: target,
            testTarget: testTarget
        )

        let template = OptionsResolver.resolveTemplate(
            cliTemplate: cli.template,
            configTemplate: config?.tests.template,
            targetPath: testTargetPath
        )

        return GeneratedTestsOptions(
            target: target,
            testTarget: testTarget,
            template: template,
            sources: OptionsResolver.resolveSources(sources, default: []),
            output: output.flatMap { Path($0) } ?? .current,
            prefireEnabledMarker: config?.tests.previewDefaultEnabled ?? true,
            testTargetPath: testTargetPath,
            cacheBasePath: cli.cacheBasePath.flatMap { Path($0) },
            device: device,
            osVersion: osVersion,
            snapshotDevices: config?.tests.snapshotDevices,
            imports: config?.tests.imports,
            testableImports: config?.tests.testableImports,
            useGroupedSnapshots: config?.tests.useGroupedSnapshots ?? true,
            splitSnapshotDirectories: config?.tests.splitSnapshotDirectories ?? false,
            drawHierarchyInKeyWindowDefaultEnabled: config?.tests.drawHierarchyInKeyWindowDefaultEnabled,
            fullPageSnapshots: config?.tests.fullPageSnapshots ?? false
        )
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
        static let drawHierarchyInKeyWindowDefaultEnabled = "drawHierarchyInKeyWindowDefaultEnabled"
        static let fullPageSnapshots = "fullPageSnapshots"
    }

    static func run(_ options: GeneratedTestsOptions) async throws {
        try await PrefireGenerator.generate(
            version: Prefire.Version.value,
            sources: options.sources,
            output: options.output + (options.useGroupedSnapshots ? Constants.snapshotFileName : Constants.snapshotFileTemplated),
            arguments: await GenerateTestsCommand.makeArguments(for: options),
            inlineTemplate: try options.template?.read(.utf8) ?? EmbeddedTemplates.previewTests,
            defaultEnabled: options.prefireEnabledMarker,
            cacheDir: options.cacheBasePath,
            useGroupedSnapshots: options.useGroupedSnapshots
        )
    }

    static func makeArguments(for options: GeneratedTestsOptions) async -> [String: NSObject] {
        // `split_snapshot_directories` works only together with `use_grouped_snapshots: false`,
        // because each `__Snapshots__/<name>/` folder is derived from a distinct generated `.swift`
        // file. Warn instead of silently ignoring so the user notices the misconfiguration.
        if options.splitSnapshotDirectories && options.useGroupedSnapshots {
            Logger.warning("⚠️ `split_snapshot_directories: true` requires `use_grouped_snapshots: false` and will be ignored otherwise.")
        }

        let splitDirectories = options.splitSnapshotDirectories && !options.useGroupedSnapshots
        let snapshotFileName = splitDirectories ? Constants.snapshotFileTemplated : Constants.snapshotFileName
        let snapshotOutput = options.testTargetPath.flatMap({ $0 + snapshotFileName })

        Logger.info(
            """
            Prefire configuration
                ➜ Target used for tests: \(options.target ?? "nil")
                ➜ Tests target: \(options.testTarget ?? "nil")
                ➜ Template path: \(options.template ?? "nil")
                ➜ Generated test path: \(options.output)
                ➜ Snapshot resources path: \(snapshotOutput ?? "nil")
                ➜ Preview default enabled: \(options.prefireEnabledMarker)
                ➜ drawHierarchyInKeyWindow default enabled: \(options.drawHierarchyInKeyWindowDefaultEnabled?.description ?? "nil")
                ➜ Full page snapshots: \(options.fullPageSnapshots)
            """
        )

        return [
            Keys.simulatorOSVersion: options.osVersion as? NSString,
            Keys.simulatorDevice: options.device as? NSString,
            Keys.snapshotDevices: options.snapshotDevices?.joined(separator: "|") as? NSString,
            Keys.imports: options.imports as? NSArray,
            Keys.testableImports: options.testableImports as? NSArray,
            Keys.mainTarget: options.target as? NSString,
            Keys.file: snapshotOutput?.string as? NSString,
            Keys.drawHierarchyInKeyWindowDefaultEnabled: options.drawHierarchyInKeyWindowDefaultEnabled?.description as? NSString,
            Keys.fullPageSnapshots: options.fullPageSnapshots ? "true" as NSString : nil,
        ].filter({ $0.value != nil }) as? [String: NSObject] ?? [:]
    }
}
