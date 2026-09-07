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

    /// Conformance inherited through another protocol has to be detected, not just the one
    /// written on the declaration.
    func testProviderDetectedThroughIntermediateProtocol() async throws {
        let file = Path("/tmp/PrefireIndirectProvider.swift")
        let output = Path("/tmp/PrefireIndirectProviderTests.generated.swift")
        let cache = Path("/tmp/cache_prefire_indirect_provider/")
        try file.write("""
        import SwiftUI

        protocol PrefireProvider {}
        protocol TeamProvider: PrefireProvider {}

        struct Panel_Previews: PreviewProvider, TeamProvider {
            static var previews: some View {
                Text("Panel")
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
        XCTAssertFalse(result.contains("TeamProvider._allPreviews"))
    }

    func testProviderDetectedThroughProtocolComposition() async throws {
        let file = Path("/tmp/PrefireCompositionProvider.swift")
        let output = Path("/tmp/PrefireCompositionProviderTests.generated.swift")
        let cache = Path("/tmp/cache_prefire_composition_provider/")
        try file.write("""
        import SwiftUI

        protocol PrefireProvider {}

        struct Panel_Previews: PreviewProvider & PrefireProvider {
            static var previews: some View {
                Text("Panel")
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

        XCTAssertTrue(try output.read(.utf8).contains("for preview in Panel_Previews._allPreviews"))
    }

    /// Conformance added by an extension in another file has to be detected too.
    func testProviderDetectedThroughExtension() async throws {
        let declaration = Path("/tmp/PrefireExtensionProviderDecl.swift")
        let conformance = Path("/tmp/PrefireExtensionProviderConformance.swift")
        let output = Path("/tmp/PrefireExtensionProviderTests.generated.swift")
        let cache = Path("/tmp/cache_prefire_extension_provider/")
        try declaration.write("""
        import SwiftUI

        protocol PrefireProvider {}

        struct Panel_Previews: PreviewProvider {
            static var previews: some View {
                Text("Panel")
            }
        }

        """)
        try conformance.write("extension Panel_Previews: PrefireProvider {}\n")

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [declaration, conformance],
            output: output,
            arguments: [:],
            inlineTemplate: EmbeddedTemplates.previewTests,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true
        )

        XCTAssertTrue(try output.read(.utf8).contains("for preview in Panel_Previews._allPreviews"))
    }

    /// The `annotated:` filter keeps working without Sourcery.
    func testProviderDetectedThroughAnnotation() async throws {
        let file = Path("/tmp/PrefireAnnotatedProvider.swift")
        let output = Path("/tmp/PrefireAnnotatedProviderTests.generated.swift")
        let cache = Path("/tmp/cache_prefire_annotated_provider/")
        try file.write("""
        import SwiftUI

        // sourcery: PrefireProvider
        struct Panel_Previews: PreviewProvider {
            static var previews: some View {
                Text("Panel")
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

        XCTAssertTrue(try output.read(.utf8).contains("for preview in Panel_Previews._allPreviews"))
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
        XCTAssertTrue(result.contains(
            "PrefireSnapshot(preview, device: preview.device?.snapshotDeviceConfig() ?? deviceConfig, globalConfiguration: prefireGlobalConfiguration)"
        ))
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

    func testGlobalConfigurationIsAppliedInTestsTemplate() async throws {
        let file = Path("/tmp/GlobalConfigurationPreview.swift")
        let output = Path("/tmp/GlobalConfigurationPreviewTests.generated.swift")
        let cache = Path("/tmp/cache_global_configuration_tests/")
        try file.write("""
        import SwiftUI

        protocol PrefireProvider {}

        struct Panel_Previews: PreviewProvider, PrefireProvider {
            static var previews: some View {
                Text("Panel")
            }
        }

        #Preview("TextView") {
            Text("1")
        }

        """)

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: output,
            arguments: ["globalConfiguration": "MyPrefireSetup" as NSString],
            inlineTemplate: EmbeddedTemplates.previewTests,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true
        )

        let result = try output.read(.utf8)

        // Resolved once, then referenced by every call site.
        XCTAssertTrue(result.contains(
            "private let prefireGlobalConfiguration: (any PrefireGlobalConfiguration.Type)? = MyPrefireSetup.self"
        ))
        XCTAssertTrue(result.contains(
            "PrefireSnapshot(preview, device: preview.device?.snapshotDeviceConfig() ?? deviceConfig, globalConfiguration: prefireGlobalConfiguration)"
        ))
        XCTAssertFalse(result.contains("MyPrefireSetup.self,"), "The type name belongs on the resolving line only")
    }

    /// With no `global_configuration:` key, the type is found in the sources.
    func testGlobalConfigurationIsDetectedWithoutConfiguration() async throws {
        let file = Path("/tmp/DetectedGlobalConfigurationPreview.swift")
        let output = Path("/tmp/DetectedGlobalConfigurationTests.generated.swift")
        let cache = Path("/tmp/cache_detected_global_configuration/")
        try file.write("""
        import Prefire
        import SwiftUI

        enum MyPrefireSetup: PrefireGlobalConfiguration {
            static func wrap(_ view: AnyView) -> AnyView { view }
        }

        #Preview("TextView") {
            Text("1")
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

        XCTAssertTrue(try output.read(.utf8).contains(
            "private let prefireGlobalConfiguration: (any PrefireGlobalConfiguration.Type)? = MyPrefireSetup.self"
        ))
    }

    func testAmbiguousGlobalConfigurationFailsGeneration() async throws {
        let file = Path("/tmp/AmbiguousGlobalConfigurationPreview.swift")
        let output = Path("/tmp/AmbiguousGlobalConfigurationTests.generated.swift")
        let cache = Path("/tmp/cache_ambiguous_global_configuration/")
        try file.write("""
        import Prefire
        import SwiftUI

        enum FirstSetup: PrefireGlobalConfiguration {}
        enum SecondSetup: PrefireGlobalConfiguration {}

        #Preview("TextView") {
            Text("1")
        }

        """)

        do {
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
            XCTFail("Generation should fail rather than pick one of the two arbitrarily")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? ""
            XCTAssertTrue(message.contains("FirstSetup"), message)
            XCTAssertTrue(message.contains("SecondSetup"), message)
        }
    }

    func testMissingGlobalConfigurationResolvesToNilInTestsTemplate() async throws {
        let file = Path("/tmp/NoGlobalConfigurationPreview.swift")
        let output = Path("/tmp/NoGlobalConfigurationPreviewTests.generated.swift")
        let cache = Path("/tmp/cache_no_global_configuration_tests/")
        try file.write("""
        import SwiftUI

        #Preview("TextView") {
            Text("1")
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

        XCTAssertTrue(result.contains(
            "private let prefireGlobalConfiguration: (any PrefireGlobalConfiguration.Type)? = nil"
        ))
        XCTAssertTrue(result.contains("globalConfiguration: prefireGlobalConfiguration"))
    }

    func testGlobalConfigurationIsAppliedInPlaybookTemplate() async throws {
        let file = Path("/tmp/GlobalConfigurationPlaybookPreview.swift")
        let output = Path("/tmp/GlobalConfigurationPreviewModels.generated.swift")
        let cache = Path("/tmp/cache_global_configuration_playbook/")
        try file.write("""
        import SwiftUI

        #Preview("TextView") {
            Text("1")
        }

        """)

        try await PrefireGenerator.generate(
            version: "1.0.0",
            sources: [file],
            output: output,
            arguments: ["globalConfiguration": "MyPlaybookSetup" as NSString],
            inlineTemplate: EmbeddedTemplates.previewModels,
            defaultEnabled: true,
            cacheDir: cache,
            useGroupedSnapshots: true
        )

        let result = try output.read(.utf8)

        XCTAssertTrue(result.contains(
            "private let prefireGlobalConfiguration: (any PrefireGlobalConfiguration.Type)? = MyPlaybookSetup.self"
        ))
        XCTAssertTrue(result.contains("globalConfiguration: prefireGlobalConfiguration"))
    }

    func testMissingGlobalConfigurationResolvesToNilInPlaybookTemplate() async throws {
        let file = Path("/tmp/NoGlobalConfigurationPlaybookPreview.swift")
        let output = Path("/tmp/NoGlobalConfigurationPreviewModels.generated.swift")
        let cache = Path("/tmp/cache_no_global_configuration_playbook/")
        try file.write("""
        import SwiftUI

        #Preview("TextView") {
            Text("1")
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

        XCTAssertTrue(result.contains(
            "private let prefireGlobalConfiguration: (any PrefireGlobalConfiguration.Type)? = nil"
        ))
        XCTAssertTrue(result.contains("globalConfiguration: prefireGlobalConfiguration"))
    }
}
