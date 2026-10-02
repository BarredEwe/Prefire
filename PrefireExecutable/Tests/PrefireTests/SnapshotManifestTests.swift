import Foundation
import PathKit
@testable import prefire
@testable import PrefireCore
import XCTest

final class SnapshotManifestTests: XCTestCase {
    private func makeOptions(
        testTargetPath: String? = "User/Tests",
        output: String = "User/Generated",
        template: String? = nil
    ) throws -> GeneratedTestsOptions {
        try GeneratedTestsOptions(
            target: "PrefireExample",
            testTarget: "PrefireExampleTests",
            template: template,
            sources: [],
            output: output,
            testTargetPath: testTargetPath,
            cacheBasePath: nil,
            device: nil,
            osVersion: nil,
            config: nil
        )
    }

    private func makeResult(
        _ previews: [GeneratedPreview],
        hasPreviewProviders: Bool = false,
        parsedSourceCount: Int = 1
    ) -> GenerationResult {
        GenerationResult(previews: previews, hasPreviewProviders: hasPreviewProviders, parsedSourceCount: parsedSourceCount)
    }

    func test_sanitized_matchesSnapshotTestingRules() {
        XCTAssertEqual(SnapshotManifest.sanitized("AuthView"), "AuthView")
        XCTAssertEqual(SnapshotManifest.sanitized("Auth View"), "Auth-View")
        XCTAssertEqual(SnapshotManifest.sanitized("TextView-1-- A"), "TextView-1-A")
        XCTAssertEqual(SnapshotManifest.sanitized("(Auth)"), "Auth")
    }

    func test_makeManifest_groupedUsesSingleDirectory() throws {
        let options = try makeOptions()
        let manifest = GenerateTestsCommand.makeManifest(
            for: options,
            result: makeResult([
                GeneratedPreview(sourceFileName: "AuthView", displayName: "Auth View", isParameterized: false),
                GeneratedPreview(sourceFileName: "TestView", displayName: "TestView", isParameterized: false),
            ])
        )

        XCTAssertEqual(manifest.version, SnapshotManifest.currentVersion)
        XCTAssertEqual(manifest.directories.map(\.path), ["User/Tests/__Snapshots__/PreviewTests.generated"])
        XCTAssertEqual(manifest.directories.first?.snapshots.map(\.name), ["Auth View", "TestView"])
        XCTAssertEqual(manifest.directories.first?.snapshots.map(\.stem), ["Auth-View", "TestView"])
        XCTAssertEqual(manifest.directories.first?.complete, true)
    }

    func test_makeManifest_ungroupedWithoutSplitKeepsSharedDirectory() throws {
        var options = try makeOptions()
        options.useGroupedSnapshots = false
        options.splitSnapshotDirectories = false

        let manifest = GenerateTestsCommand.makeManifest(
            for: options,
            result: makeResult([
                GeneratedPreview(sourceFileName: "AuthView", displayName: "AuthView", isParameterized: false),
                GeneratedPreview(sourceFileName: "TestView", displayName: "TestView", isParameterized: false),
            ])
        )

        XCTAssertEqual(manifest.directories.map(\.path), ["User/Tests/__Snapshots__/PreviewTests.generated"])
        XCTAssertEqual(manifest.directories.first?.snapshots.count, 2)
    }

    func test_makeManifest_splitDirectoriesUsesFolderPerSourceFile() throws {
        var options = try makeOptions()
        options.useGroupedSnapshots = false
        options.splitSnapshotDirectories = true

        let manifest = GenerateTestsCommand.makeManifest(
            for: options,
            result: makeResult([
                GeneratedPreview(sourceFileName: "AuthView", displayName: "AuthView", isParameterized: false),
                GeneratedPreview(sourceFileName: "TestView", displayName: "TestView", isParameterized: false),
            ])
        )

        XCTAssertEqual(
            manifest.directories.map(\.path),
            [
                "User/Tests/__Snapshots__/AuthViewTests.generated",
                "User/Tests/__Snapshots__/TestViewTests.generated",
            ]
        )
    }

    /// Without `test_target_path` SnapshotTesting falls back to the generated file's own `#file`,
    /// so ungrouped generation already produces a folder per source file.
    func test_makeManifest_withoutTestTargetPathFollowsGeneratedFiles() throws {
        var options = try makeOptions(testTargetPath: nil)
        options.useGroupedSnapshots = false
        options.splitSnapshotDirectories = false

        let manifest = GenerateTestsCommand.makeManifest(
            for: options,
            result: makeResult([GeneratedPreview(sourceFileName: "AuthView", displayName: "AuthView", isParameterized: false)])
        )

        XCTAssertEqual(manifest.directories.map(\.path), ["User/Generated/__Snapshots__/AuthViewTests.generated"])
    }

    func test_makeManifest_recordsSnapshotDevicesAndParameterizedPreviews() throws {
        var options = try makeOptions()
        options.snapshotDevices = ["iPhone 15", "iPad"]

        let manifest = GenerateTestsCommand.makeManifest(
            for: options,
            result: makeResult([GeneratedPreview(sourceFileName: "TestView", displayName: "TextView", isParameterized: true)])
        )

        XCTAssertEqual(manifest.snapshotDevices, ["iPhone 15", "iPad"])
        XCTAssertEqual(manifest.directories.first?.snapshots.first?.parameterized, true)
    }

    /// `PrefireProvider` previews are named from `previewDisplayName` at runtime, so the folder
    /// cannot be considered fully described and must never be pruned.
    func test_makeManifest_previewProvidersMarkDirectoryIncomplete() throws {
        let options = try makeOptions()
        let manifest = GenerateTestsCommand.makeManifest(
            for: options,
            result: makeResult(
                [GeneratedPreview(sourceFileName: "TestView", displayName: "TestView", isParameterized: false)],
                hasPreviewProviders: true
            )
        )

        XCTAssertEqual(manifest.directories.first?.complete, false)
    }

    /// A custom template renders whatever it likes, including snapshots under names the parser
    /// never saw. Pruning against a manifest of parsed display names would delete files the tests
    /// actively use, so a custom template disables pruning altogether.
    func test_makeManifest_customTemplateMarksDirectoryIncomplete() throws {
        let options = try makeOptions(template: "CustomPreviewTests.stencil")
        let manifest = GenerateTestsCommand.makeManifest(
            for: options,
            result: makeResult([GeneratedPreview(sourceFileName: "TestView", displayName: "TestView", isParameterized: false)])
        )

        XCTAssertEqual(manifest.directories.first?.complete, false)
    }

    /// Deleting the last preview of a source file is the very case `prune` exists for. The folder
    /// has to stay in the manifest — with nothing expected in it — or it is never looked at again.
    func test_makeManifest_carriesForwardFoldersTheRunNoLongerProduces() throws {
        var options = try makeOptions()
        options.useGroupedSnapshots = false
        options.splitSnapshotDirectories = true

        let previous = GenerateTestsCommand.makeManifest(
            for: options,
            result: makeResult([
                GeneratedPreview(sourceFileName: "AuthView", displayName: "AuthView", isParameterized: false),
                GeneratedPreview(sourceFileName: "TestView", displayName: "TestView", isParameterized: false),
            ])
        )

        let manifest = GenerateTestsCommand.makeManifest(
            for: options,
            result: makeResult([GeneratedPreview(sourceFileName: "AuthView", displayName: "AuthView", isParameterized: false)]),
            previous: previous
        )

        XCTAssertEqual(
            manifest.directories.map(\.path),
            [
                "User/Tests/__Snapshots__/AuthViewTests.generated",
                "User/Tests/__Snapshots__/TestViewTests.generated",
            ]
        )
        XCTAssertEqual(manifest.directories.last?.snapshots, [])
        XCTAssertEqual(manifest.directories.last?.complete, true)
    }

    func test_makeManifest_carriesForwardTheOnlyFolderWhenEveryPreviewIsGone() throws {
        let options = try makeOptions()
        let previous = GenerateTestsCommand.makeManifest(
            for: options,
            result: makeResult([GeneratedPreview(sourceFileName: "TestView", displayName: "TestView", isParameterized: false)])
        )

        let manifest = GenerateTestsCommand.makeManifest(for: options, result: makeResult([]), previous: previous)

        XCTAssertEqual(manifest.directories.map(\.path), ["User/Tests/__Snapshots__/PreviewTests.generated"])
        XCTAssertEqual(manifest.directories.first?.snapshots, [])
    }

    /// Carrying a folder over must not upgrade it: whatever made it unprunable still holds.
    func test_makeManifest_carriedForwardFolderStaysIncomplete() throws {
        let options = try makeOptions()
        let previous = SnapshotManifest(
            snapshotDevices: [],
            directories: [.init(path: "User/Tests/__Snapshots__/LegacyTests.generated", snapshots: [], complete: false)]
        )

        let manifest = GenerateTestsCommand.makeManifest(for: options, result: makeResult([]), previous: previous)

        XCTAssertEqual(manifest.directories.first?.complete, false)
    }

    func test_makeManifest_carriedForwardFolderIsIncompleteUnderACustomTemplate() throws {
        let options = try makeOptions(template: "CustomPreviewTests.stencil")
        let previous = SnapshotManifest(
            snapshotDevices: [],
            directories: [.init(path: "User/Tests/__Snapshots__/LegacyTests.generated", snapshots: [], complete: true)]
        )

        let manifest = GenerateTestsCommand.makeManifest(for: options, result: makeResult([]), previous: previous)

        XCTAssertEqual(manifest.directories.first?.complete, false)
    }

    /// A plugin build generates the tests into DerivedData, which a standalone `prefire prune`
    /// cannot guess, so the manifest is looked for next to the snapshots first.
    func test_possibleManifestPaths_prefersTheSnapshotsFolder() throws {
        let paths = GenerateTestsCommand.possibleManifestPaths(for: try makeOptions())

        XCTAssertEqual(
            paths.map(\.string),
            [
                "User/Tests/\(SnapshotManifest.fileName)",
                "User/Generated/\(SnapshotManifest.fileName)",
            ]
        )
    }

    func test_possibleManifestPaths_fallsBackToTheGeneratedTestsFolder() throws {
        let paths = GenerateTestsCommand.possibleManifestPaths(for: try makeOptions(testTargetPath: nil))

        XCTAssertEqual(paths.map(\.string), ["User/Generated/\(SnapshotManifest.fileName)"])
    }

    func test_possibleManifestPaths_doesNotRepeatTheSameFolder() throws {
        let paths = GenerateTestsCommand.possibleManifestPaths(for: try makeOptions(testTargetPath: "User/Tests", output: "User/Tests"))

        XCTAssertEqual(paths.map(\.string), ["User/Tests/\(SnapshotManifest.fileName)"])
    }

    func test_writeManifest_writesNextToTheSnapshotsAndDropsAStaleCopy() throws {
        let root = try makeTemporaryDirectory()
        let tests = root + "Tests"
        let generated = root + "Generated"
        try tests.mkpath()
        try generated.mkpath()

        let options = try makeOptions(testTargetPath: tests.string, output: generated.string)
        let stale = generated + SnapshotManifest.fileName
        try SnapshotManifest(snapshotDevices: [], directories: []).write(to: stale.string)

        let manifest = GenerateTestsCommand.makeManifest(
            for: options,
            result: makeResult([GeneratedPreview(sourceFileName: "TestView", displayName: "TestView", isParameterized: false)])
        )
        let written = GenerateTestsCommand.writeManifest(manifest, for: options)

        XCTAssertEqual(written, tests + SnapshotManifest.fileName)
        XCTAssertFalse(stale.exists, "A copy left in the generated tests folder could be read back as a stale manifest")
        XCTAssertEqual(GenerateTestsCommand.readManifest(for: options), manifest)
    }

    func test_readManifest_ignoresAManifestFromAnotherVersion() throws {
        let root = try makeTemporaryDirectory()
        let options = try makeOptions(testTargetPath: root.string, output: root.string)

        var manifest = SnapshotManifest(snapshotDevices: [], directories: [])
        manifest.version = SnapshotManifest.currentVersion + 1
        try manifest.write(to: (root + SnapshotManifest.fileName).string)

        XCTAssertNil(GenerateTestsCommand.readManifest(for: options))
    }

    /// Parsing nothing is not the same as finding nothing: a misconfigured `sources` must not be
    /// read as "every preview was deleted".
    func test_run_withoutParsedSourcesLeavesThePreviousManifestUntouched() async throws {
        let root = try makeTemporaryDirectory()
        let sources = root + "Sources"
        try sources.mkpath()

        var options = try makeOptions(testTargetPath: root.string, output: root.string)
        options.sources = [sources]

        let previous = SnapshotManifest(
            snapshotDevices: [],
            directories: [.init(path: (root + "__Snapshots__" + "PreviewTests.generated").string, snapshots: [.init(name: "TestView", parameterized: false)], complete: true)]
        )
        try previous.write(to: (root + SnapshotManifest.fileName).string)

        try await GenerateTestsCommand.run(options)

        XCTAssertEqual(GenerateTestsCommand.readManifest(for: options), previous)
    }

    private func makeTemporaryDirectory() throws -> Path {
        let directory = Path(NSTemporaryDirectory()) + "prefire-manifest-\(UUID().uuidString)"
        try directory.mkpath()
        let path = directory.string
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }
        return directory
    }

    func test_manifest_roundTripsThroughDisk() throws {
        let directory = Path(NSTemporaryDirectory()) + "prefire-manifest-\(UUID().uuidString)"
        try directory.mkpath()
        defer { try? directory.delete() }

        let manifest = SnapshotManifest(
            snapshotDevices: ["iPad"],
            directories: [
                .init(path: "/Tests/__Snapshots__/PreviewTests.generated", snapshots: [.init(name: "Auth View", parameterized: false)], complete: true)
            ]
        )
        let path = (directory + SnapshotManifest.fileName).string

        try manifest.write(to: path)

        XCTAssertEqual(try SnapshotManifest.read(from: path), manifest)
    }
}
