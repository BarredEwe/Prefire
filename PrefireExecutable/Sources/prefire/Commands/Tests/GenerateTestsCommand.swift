import Foundation
import PrefireCore
import PathKit

private enum Constants {
    static let snapshotFileName = "PreviewTests.generated.swift"
    static let snapshotFileTemplated = "{PREVIEW_FILE_NAME}Tests.generated.swift"
}

struct GeneratedTestsOptions {
    var target: String?
    var testTarget: String?
    var template: Path?
    var sources: [Path]
    var output: Path
    var prefireEnabledMarker: Bool
    var testTargetPath: Path?
    var cacheBasePath: Path?
    var device: String?
    var osVersion: String?
    var snapshotDevices: [String]?
    var imports: [String]?
    var testableImports: [String]?
    var useGroupedSnapshots: Bool
    var splitSnapshotDirectories: Bool
    var drawHierarchyInKeyWindowDefaultEnabled: Bool?

    init(
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
        self.target = config?.tests.target ?? target
        self.testTarget = testTarget
        self.testTargetPath = (config?.tests.testTargetPath ?? testTargetPath).flatMap({ Path($0) })

        if let template = config?.tests.template, let testTargetPath = self.testTargetPath {
            let testTargetURL = URL(filePath: testTargetPath.string)
            let templateURL = testTargetURL.appending(path: template)
            self.template = Path(templateURL.absoluteURL.path(percentEncoded: false))
        } else if let template {
            self.template = Path(template)
        }

        self.sources = (config?.tests.sources ?? sources).compactMap({ Path($0) })
        self.output = (config?.tests.testFilePath ?? output).flatMap({ Path($0) }) ?? .current
        prefireEnabledMarker = config?.tests.previewDefaultEnabled ?? true
        self.cacheBasePath = cacheBasePath.flatMap({ Path($0) })
        self.device = config?.tests.device ?? device
        self.osVersion = config?.tests.osVersion ?? osVersion
        useGroupedSnapshots = config?.tests.useGroupedSnapshots ?? true
        splitSnapshotDirectories = config?.tests.splitSnapshotDirectories ?? false
        snapshotDevices = config?.tests.snapshotDevices
        imports = config?.tests.imports
        testableImports = config?.tests.testableImports
        drawHierarchyInKeyWindowDefaultEnabled = config?.tests.drawHierarchyInKeyWindowDefaultEnabled
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
        ].filter({ $0.value != nil }) as? [String: NSObject] ?? [:]
    }
}
