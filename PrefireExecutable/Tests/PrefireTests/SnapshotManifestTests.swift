import Foundation
import PathKit
@testable import prefire
@testable import PrefireCore
import XCTest

final class SnapshotManifestTests: XCTestCase {
    private func makeOptions(testTargetPath: String? = "User/Tests", output: String = "User/Generated") throws -> GeneratedTestsOptions {
        try GeneratedTestsOptions(
            target: "PrefireExample",
            testTarget: "PrefireExampleTests",
            template: nil,
            sources: [],
            output: output,
            testTargetPath: testTargetPath,
            cacheBasePath: nil,
            device: nil,
            osVersion: nil,
            config: nil
        )
    }

    private func makeResult(_ previews: [GeneratedPreview], hasPreviewProviders: Bool = false) -> GenerationResult {
        GenerationResult(previews: previews, hasPreviewProviders: hasPreviewProviders)
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
