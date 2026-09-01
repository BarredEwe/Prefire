@preconcurrency import ArgumentParser
import Foundation
import PathKit
import PrefireCore

extension Prefire {
    struct Prune: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete snapshots no generated test records anymore",
            discussion: """
            Compares the `\(SnapshotManifest.fileName)` manifest written by `prefire tests` with the \
            `__Snapshots__` folders it describes. Orphans are only reported; pass --delete to remove them.
            """
        )

        @Option(help: "Path to a config `.prefire.yml`.")
        var config: String?
        @Option(help: "Path to generated file.")
        var output: String?
        @Option(help: "Path to your Snapshot Tests Target.")
        var testTargetPath: String?
        @Option(help: "Path to `\(SnapshotManifest.fileName)`. Overrides the config lookup.")
        var manifest: String?

        @Flag(help: "Only report the unused snapshots. Default behaviour.")
        var dryRun = false
        @Flag(help: "Delete the unused snapshots instead of only reporting them.")
        var delete = false

        @Flag(help: "Display full info")
        var verbose = false

        func run() async throws {
            Logger.level = verbose ? .verbose : .warnings
            let config = Config.load(from: config, testTargetPath: testTargetPath, env: ProcessInfo.processInfo.environment)

            let path = try manifest.map({ Path($0) }) ?? GenerateTestsCommand.manifestPath(
                for: GeneratedTestsOptions(
                    target: nil,
                    testTarget: nil,
                    template: nil,
                    sources: [],
                    output: output,
                    testTargetPath: testTargetPath,
                    cacheBasePath: nil,
                    device: nil,
                    osVersion: nil,
                    config: config
                )
            )

            guard path.exists else {
                throw ValidationError("Snapshot manifest not found at \(path). Run `prefire tests` first, or pass --manifest.")
            }

            let orphans = SnapshotPruner.orphans(for: try SnapshotManifest.read(from: path.string))

            guard !orphans.isEmpty else {
                print("✅ No unused snapshots found.")
                return
            }

            // Deleting is irreversible, so it never happens by default and --dry-run wins a conflict.
            guard delete, !dryRun else {
                print("🔍 \(orphans.count) unused snapshot(s) found:" + orphans.map({ "\n  - " + $0 }).joined())
                print("Nothing was deleted. Run `prefire prune --delete` to remove them.")
                return
            }

            let deleted = try SnapshotPruner.delete(orphans)
            print("🗑 Deleted \(deleted.count) unused snapshot(s):" + deleted.map({ "\n  - " + $0 }).joined())
        }
    }
}
