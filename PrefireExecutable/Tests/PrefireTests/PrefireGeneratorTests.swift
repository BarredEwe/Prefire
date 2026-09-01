import Foundation
@testable import PrefireCore
import XCTest
import PathKit

final class PrefireGeneratorTests: XCTestCase {
    func testEmptySourcesDoesNotCrash() async throws {
        let output = Path(fixtureTestPreviewSource)
        let template = "Generated with {{ types.count }} types"
        let args: [String: NSObject] = [:]

        do {
            try await PrefireGenerator.generate(
                version: "1.0.0",
                sources: [],
                output: output,
                arguments: args,
                inlineTemplate: template,
                defaultEnabled: true,
                useGroupedSnapshots: true
            )
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }

    func testPreviewFilteringAndParsing() async throws {
        let file = Path(fixtureTestPreviewSource)
        let output = Path("/tmp/generated_previews.swift")
        let cache = Path("/tmp/cache/")
        let template = "{% for p in argument.previewsMacrosDict %}{{ p.componentTestName }}\n{% endfor %}"
        let args: [String: NSObject] = [:]
        
        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: output,
            arguments: args,
            inlineTemplate: template,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true
        )

        let result = try output.read(.utf8)

        XCTAssertTrue(result.contains("TestPreview"), "Should include basic preview")
        XCTAssertFalse(result.contains("TestPreview_Ignored"), "Should skip explicitly ignored preview")
    }

    func testParameterizedPreviewRendersSnapshotTemplate() async throws {
        let file = Path("/tmp/ParameterizedPreview.swift")
        let output = Path("/tmp/ParameterizedPreviewTests.generated.swift")
        let cache = Path("/tmp/cache_parameterized_preview/")
        try file.write("""
        import SwiftUI

        #Preview("TextView", traits: .sizeThatFitsLayout, arguments: ["- A", "- B"]) { suffix in
            Text("1 \\(suffix)")
        }

        """)

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: output,
            arguments: [:],
            inlineTemplate: EmbeddedTemplates.previewTests,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true
        )

        let result = try output.read(.utf8)

        XCTAssertTrue(result.contains("for (previewArgumentIndex, previewArgument) in ([\"- A\", \"- B\"]).enumerated()"))
        XCTAssertTrue(result.contains("let suffix = previewArgument"))
        XCTAssertTrue(result.contains("name: \"TextView-\\(previewArgumentIndex + 1)-\\(String(describing: previewArgument))\""))
        XCTAssertTrue(result.contains("Text(\"1 \\(suffix)\")"))
    }

    func testFixedLayoutPreviewRendersMacOSDeviceConfig() async throws {
        let file = Path("/tmp/FixedLayoutPreview.swift")
        let output = Path("/tmp/FixedLayoutPreviewTests.generated.swift")
        let cache = Path("/tmp/cache_fixed_layout_preview/")
        try file.write("""
        import SwiftUI

        #Preview("Panel", traits: .fixedLayout(width: 640, height: Layout.height)) {
            Text("Panel")
        }

        """)

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: output,
            arguments: [:],
            inlineTemplate: EmbeddedTemplates.previewTests,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true
        )

        let result = try output.read(.utf8)

        XCTAssertTrue(result.contains("fixedLayoutSize: CGSize(width: 640, height: Layout.height)"))
        XCTAssertTrue(result.contains("let strategy: Snapshotting<NSView, NSImage>"))
        XCTAssertTrue(result.contains("size: prefireSnapshot.device.size"))
        XCTAssertTrue(result.contains("isScreen: false,"))
        // On iOS/tvOS the layout follows `isScreen` only.
        XCTAssertTrue(result.contains("layout: prefireSnapshot.isScreen ? .device(config: prefireSnapshot.device.imageConfig) : .sizeThatFits"))
    }

    func testPrefireProviderTemplateUsesPreviewDeviceNotPreviewModel() async throws {
        let file = Path("/tmp/PrefireProviderPreview.swift")
        let output = Path("/tmp/PrefireProviderPreviewTests.generated.swift")
        let cache = Path("/tmp/cache_prefire_provider_preview/")
        try file.write("""
        import SwiftUI

        protocol PrefireProvider {}

        struct Panel_Previews: PreviewProvider, PrefireProvider {
            static var previews: some View {
                Text("Panel")
                    .previewLayout(.fixed(width: 640, height: 320))
            }
        }

        """)

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: output,
            arguments: [:],
            inlineTemplate: EmbeddedTemplates.previewTests,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true
        )

        let result = try output.read(.utf8)

        XCTAssertTrue(result.contains("for preview in Panel_Previews._allPreviews"))
        XCTAssertTrue(result.contains("PrefireSnapshot(preview, device: preview.device?.snapshotDeviceConfig() ?? deviceConfig)"))
        XCTAssertFalse(result.contains("preview.deviceConfig"))
    }

    func testParameterizedPreviewRendersPlaybookTemplate() async throws {
        let file = Path("/tmp/ParameterizedPlaybookPreview.swift")
        let output = Path("/tmp/ParameterizedPreviewModels.generated.swift")
        let cache = Path("/tmp/cache_parameterized_playbook_preview/")
        try file.write("""
        import SwiftUI

        #Preview("TextView", traits: .sizeThatFitsLayout, arguments: ["- A", "- B"]) { suffix in
            Text("1 \\(suffix)")
        }

        """)

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: output,
            arguments: [:],
            inlineTemplate: EmbeddedTemplates.previewModels,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true
        )

        let result = try output.read(.utf8)

        XCTAssertTrue(result.contains("for (previewArgumentIndex, previewArgument) in ([\"- A\", \"- B\"]).enumerated()"))
        XCTAssertTrue(result.contains("let suffix = previewArgument"))
        XCTAssertTrue(result.contains("id: \"TextView-\\(previewArgumentIndex)\""))
        XCTAssertTrue(result.contains("name: \"TextView-\\(previewArgumentIndex + 1)-\\(String(describing: previewArgument))\""))
        XCTAssertTrue(result.contains("Text(\"1 \\(suffix)\")"))
    }
    
    func testUngroupedFileGeneration() async throws {
        let file = Path(fixtureTestPreviewSource)
        let outputTemplate = Path("/tmp/{PREVIEW_FILE_NAME}Tests.generated.swift")
        let cache = Path("/tmp/cache/")
        let template = "// File: {PREVIEW_FILE_NAME}\n{% for p in argument.previewsMacrosDict %}{{ p.componentTestName }}\n{% endfor %}"
        let args: [String: NSObject] = [:]
        
        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: outputTemplate,
            arguments: args,
            inlineTemplate: template,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: false // Test ungrouped generation
        )

        // Should generate file with name based on the fixture file
        let expectedOutput = Path("/tmp/TestPreviewTests.generated.swift")
        XCTAssertTrue(expectedOutput.exists, "Should generate file with replaced filename")
        
        let result = try expectedOutput.read(.utf8)
        XCTAssertTrue(result.contains("// File: TestPreview"), "Should replace {PREVIEW_FILE_NAME} placeholder")
        XCTAssertTrue(result.contains("TestPreview"), "Should include basic preview")
    }
    
    func testGroupedFileGenerationUsesCorrectClassName() async throws {
        let file = Path(fixtureTestPreviewSource)
        let outputTemplate = Path("/tmp/GroupedTests.generated.swift")
        let cache = Path("/tmp/cache/")
        let template = "class {PREVIEW_FILE_NAME}Tests: XCTestCase { }"
        let args: [String: NSObject] = [:]
        
        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: outputTemplate,
            arguments: args,
            inlineTemplate: template,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true // Test grouped generation
        )

        // Should generate file with Preview as class name for grouped snapshots
        let expectedOutput = Path("/tmp/GroupedTests.generated.swift")
        XCTAssertTrue(expectedOutput.exists, "Should generate grouped file")
        
        let result = try expectedOutput.read(.utf8)
        XCTAssertTrue(result.contains("class PreviewTests: XCTestCase"), "Should use 'Preview' as class name for grouped snapshots")
    }
    
    func testUngroupedFileGenerationResolvesPlaceholderInArguments() async throws {
        let file = Path(fixtureTestPreviewSource)
        let outputTemplate = Path("/tmp/{PREVIEW_FILE_NAME}Tests.generated.swift")
        let cache = Path("/tmp/cache/")
        let template = "// snapshot file: {{ argument.file }}"
        let args: [String: NSObject] = [
            "file": "/Users/dev/Tests/{PREVIEW_FILE_NAME}Tests.generated.swift" as NSString
        ]

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: outputTemplate,
            arguments: args,
            inlineTemplate: template,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: false
        )

        let expectedOutput = Path("/tmp/TestPreviewTests.generated.swift")
        XCTAssertTrue(expectedOutput.exists, "Should generate ungrouped file with filename")

        let result = try expectedOutput.read(.utf8)
        XCTAssertTrue(
            result.contains("// snapshot file: /Users/dev/Tests/TestPreviewTests.generated.swift"),
            "Should resolve {PREVIEW_FILE_NAME} in string-valued arguments so the `file` path points at the per-source generated file"
        )
        XCTAssertFalse(result.contains("{PREVIEW_FILE_NAME}"), "Placeholder should not leak into the rendered output")
    }

    func testUngroupedFileGenerationUsesFileNameInClassName() async throws {
        let file = Path(fixtureTestPreviewSource)
        let outputTemplate = Path("/tmp/{PREVIEW_FILE_NAME}Tests.generated.swift")
        let cache = Path("/tmp/cache/")
        let template = "class {PREVIEW_FILE_NAME}Tests: XCTestCase { }"
        let args: [String: NSObject] = [:]
        
        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: outputTemplate,
            arguments: args,
            inlineTemplate: template,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: false // Test ungrouped generation
        )

        // Should generate file with source file name as class name for ungrouped snapshots
        let expectedOutput = Path("/tmp/TestPreviewTests.generated.swift")
        XCTAssertTrue(expectedOutput.exists, "Should generate ungrouped file with filename")
        
        let result = try expectedOutput.read(.utf8)
        XCTAssertTrue(result.contains("class TestPreviewTests: XCTestCase"), "Should use source file name as class name for ungrouped snapshots")
    }

    func testGeneratedTestsExplainWhichSimulatorIsExpected() async throws {
        let file = Path(fixtureTestPreviewSource)
        let output = Path("/tmp/SimulatorMismatchTests.generated.swift")
        let cache = Path("/tmp/cache_simulator_mismatch/")

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: output,
            arguments: ["simulatorDevice": "iPhone17,1" as NSString, "simulatorOSVersion": 18 as NSNumber],
            inlineTemplate: EmbeddedTemplates.previewTests,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true
        )

        let result = try output.read(.utf8)

        XCTAssertFalse(result.contains("Switch to using"), "The unreadable message should be gone")
        XCTAssertTrue(result.contains("Prefire: wrong simulator."))
        XCTAssertTrue(result.contains("PrefireDeviceIdentifier.describe(simulatorDevice)"))
        XCTAssertTrue(
            result.contains("PrefireDeviceIdentifier.describe(deviceModel, name: ProcessInfo().environment[\"SIMULATOR_DEVICE_NAME\"])"),
            "The name reported by the simulator should win over the identifier table"
        )
        XCTAssertTrue(result.contains("change `simulator_device` in .prefire.yml"))
        XCTAssertTrue(result.contains("Prefire: wrong OS version."))
        XCTAssertTrue(
            result.contains("\\(osVersion.majorVersion).\\(osVersion.minorVersion).\\(osVersion.patchVersion)"),
            "The OS version should be printed as a version, not as an OperatingSystemVersion dump"
        )
        XCTAssertTrue(result.contains("change `required_os` in .prefire.yml"))
    }

    func testGeneratedTestsLinkSnapshotFilesInFailures() async throws {
        let file = Path(fixtureTestPreviewSource)
        let output = Path("/tmp/SnapshotLinksTests.generated.swift")
        let cache = Path("/tmp/cache_snapshot_links/")

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: output,
            arguments: ["file": "/Users/dev/Tests/PreviewTests.generated.swift" as NSString],
            inlineTemplate: EmbeddedTemplates.previewTests,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true
        )

        let result = try output.read(.utf8)

        XCTAssertTrue(result.contains("private var snapshotSourceFile: String { \"/Users/dev/Tests/PreviewTests.generated.swift\" }"))
        XCTAssertTrue(result.contains("return failure.map { $0 + snapshotFilesDescription(for: prefireSnapshot.name) }"))
        XCTAssertTrue(result.contains("appendingPathComponent(\"__Snapshots__\")"))
        XCTAssertTrue(result.contains("ProcessInfo().environment[\"SNAPSHOT_ARTIFACTS\"] ?? NSTemporaryDirectory()"))
        XCTAssertTrue(result.contains("\"  reference: \\(reference?.absoluteString ?? snapshotDirectory.absoluteString)\""))
        XCTAssertTrue(result.contains("\"  recorded:  \\(recorded.absoluteString)\""))
        XCTAssertTrue(result.contains("\"  diff:      ksdiff"))
    }

    func testGeneratedTestsFallBackToOwnPathWhenNoSnapshotPathIsConfigured() async throws {
        let file = Path(fixtureTestPreviewSource)
        let output = Path("/tmp/SnapshotLinksWithoutFileTests.generated.swift")
        let cache = Path("/tmp/cache_snapshot_links_no_file/")

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: output,
            arguments: [:],
            inlineTemplate: EmbeddedTemplates.previewTests,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true
        )

        let result = try output.read(.utf8)

        XCTAssertTrue(result.contains("private var snapshotSourceFile: String { #filePath }"))
    }

    /// With `split_snapshot_directories`, each generated file points at its own `__Snapshots__` folder.
    func testGeneratedTestsLinkPerSourceSnapshotDirectory() async throws {
        let file = Path(fixtureTestPreviewSource)
        let outputTemplate = Path("/tmp/{PREVIEW_FILE_NAME}SplitLinksTests.generated.swift")
        let cache = Path("/tmp/cache_snapshot_links_split/")

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: outputTemplate,
            arguments: ["file": "/Users/dev/Tests/{PREVIEW_FILE_NAME}Tests.generated.swift" as NSString],
            inlineTemplate: EmbeddedTemplates.previewTests,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: false
        )

        let result = try Path("/tmp/TestPreviewSplitLinksTests.generated.swift").read(.utf8)

        XCTAssertTrue(result.contains("private var snapshotSourceFile: String { \"/Users/dev/Tests/TestPreviewTests.generated.swift\" }"))
    }
}
