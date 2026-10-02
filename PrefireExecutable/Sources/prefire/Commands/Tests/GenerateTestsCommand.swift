import Foundation
import PrefireCore
import PathKit

private enum Constants {
    static let snapshotFileName = "PreviewTests.generated.swift"
    static let snapshotFileTemplated = "{PREVIEW_FILE_NAME}Tests.generated.swift"
    static let snapshotsFolderName = "__Snapshots__"
    static let previewFileNamePlaceholder = "{PREVIEW_FILE_NAME}"
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
    var deleteUnusedSnapshots: Bool
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
        deleteUnusedSnapshots = config?.tests.deleteUnusedSnapshots ?? false
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
        let result = try await PrefireGenerator.generate(
            version: Prefire.Version.value,
            sources: options.sources,
            output: options.output + (options.useGroupedSnapshots ? Constants.snapshotFileName : Constants.snapshotFileTemplated),
            arguments: await GenerateTestsCommand.makeArguments(for: options),
            inlineTemplate: try options.template?.read(.utf8) ?? EmbeddedTemplates.previewTests,
            defaultEnabled: options.prefireEnabledMarker,
            cacheDir: options.cacheBasePath,
            useGroupedSnapshots: options.useGroupedSnapshots
        )

        // Nothing was parsed, so nothing was learned. Leaving the previous manifest untouched
        // keeps a misconfigured `sources` from looking like "every preview was deleted".
        guard result.parsedSourceCount > 0 else {
            Logger.warning("⚠️ No Swift sources were parsed — the snapshot manifest was left unchanged.")
            return
        }

        let manifest = makeManifest(for: options, result: result, previous: readManifest(for: options))
        writeManifest(manifest, for: options)

        guard options.deleteUnusedSnapshots else { return }

        let orphans = SnapshotPruner.orphans(for: manifest)
        guard !orphans.isEmpty else { return }

        let deleted = try SnapshotPruner.delete(orphans)
        Logger.warning("🗑 Deleted \(deleted.count) unused snapshot(s):" + deleted.map({ "\n  - " + $0 }).joined())
    }

    /// Where the manifest is looked for, most specific first.
    ///
    /// It belongs next to the snapshots it describes: a plugin build generates the tests into its
    /// work directory inside DerivedData, which a standalone `prefire prune` cannot guess, while
    /// `test_target_path` resolves the same way for both. The generated tests folder stays as a
    /// fallback for setups without `test_target_path` — and for SwiftPM plugins, which are
    /// sandboxed out of the package sources.
    static func possibleManifestPaths(for options: GeneratedTestsOptions) -> [Path] {
        [options.testTargetPath, options.output]
            .compactMap({ $0.map({ $0 + SnapshotManifest.fileName }) })
            .reduce(into: [Path]()) { paths, path in
                guard !paths.contains(path) else { return }
                paths.append(path)
            }
    }

    /// The manifest of a previous run, or `nil` when none is readable.
    static func readManifest(for options: GeneratedTestsOptions) -> SnapshotManifest? {
        for path in possibleManifestPaths(for: options) where path.exists {
            guard let manifest = try? SnapshotManifest.read(from: path.string) else {
                Logger.warning("⚠️ Ignoring the unreadable snapshot manifest at \(path).")
                continue
            }
            guard manifest.version == SnapshotManifest.currentVersion else {
                Logger.warning("⚠️ Ignoring the snapshot manifest at \(path): it was written by another Prefire version.")
                continue
            }
            return manifest
        }

        return nil
    }

    /// Writes the manifest to the first location that accepts it, dropping stale copies from the
    /// others so `prune` can never read an outdated one. A failed write is reported, never fatal:
    /// the manifest is a convenience, not part of the generated tests.
    @discardableResult
    static func writeManifest(_ manifest: SnapshotManifest, for options: GeneratedTestsOptions) -> Path? {
        let paths = possibleManifestPaths(for: options)

        for path in paths {
            do {
                try manifest.write(to: path.string)
                Logger.info("💾 Writing snapshot manifest: \(path)")
                paths.filter({ $0 != path }).forEach({ try? $0.delete() })
                return path
            } catch {
                Logger.warning("⚠️ Could not write the snapshot manifest to \(path): \(error)")
            }
        }

        return nil
    }

    /// Describes the snapshots the generated tests will record.
    ///
    /// SnapshotTesting derives a folder from each test file: `<file's folder>/__Snapshots__/<file
    /// name>`. The generated tests pass `file` explicitly whenever `test_target_path` is set;
    /// otherwise the generated file's own `#file` is used, which already splits the folders when
    /// `use_grouped_snapshots: false`.
    ///
    /// Folders of `previous` that this run no longer produces are carried over with no expected
    /// snapshots: deleting the last preview of a source file is exactly the case `prune` exists
    /// for, and a folder missing from the manifest would never be looked at again.
    static func makeManifest(
        for options: GeneratedTestsOptions,
        result: GenerationResult,
        previous: SnapshotManifest? = nil
    ) -> SnapshotManifest {
        let splitDirectories = options.splitSnapshotDirectories && !options.useGroupedSnapshots
        let perSourceDirectories = options.testTargetPath != nil ? splitDirectories : !options.useGroupedSnapshots
        let base = options.testTargetPath ?? options.output

        // The manifest only knows the display names the parser found. A custom template is free to
        // rename or add snapshots, and `PrefireProvider` previews are named at runtime, so in both
        // cases the folder is described for information only and never pruned.
        let complete = options.template == nil && !result.hasPreviewProviders
        if options.template != nil {
            Logger.warning("⚠️ A custom template is in use, so `prefire prune` will not touch the recorded snapshots.")
        }

        var grouped: [String: [SnapshotManifest.Snapshot]] = [:]

        for preview in result.previews {
            let testFileName = perSourceDirectories
                ? Constants.snapshotFileTemplated.replacingOccurrences(of: Constants.previewFileNamePlaceholder, with: preview.sourceFileName)
                : Constants.snapshotFileName
            let directory = (base + Constants.snapshotsFolderName + Path(testFileName).lastComponentWithoutExtension).string

            grouped[directory, default: []].append(
                SnapshotManifest.Snapshot(name: preview.displayName, parameterized: preview.isParameterized)
            )
        }

        var directories = grouped.map { path, snapshots in
            SnapshotManifest.Directory(path: path, snapshots: snapshots.sorted(by: { $0.name < $1.name }), complete: complete)
        }

        for directory in previous?.directories ?? [] where grouped[directory.path] == nil {
            directories.append(
                SnapshotManifest.Directory(path: directory.path, snapshots: [], complete: directory.complete && complete)
            )
        }

        return SnapshotManifest(
            snapshotDevices: options.snapshotDevices ?? [],
            directories: directories.sorted(by: { $0.path < $1.path })
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
