extension EmbeddedTemplates {
    public static let previewTests = #"""
// swiftlint:disable all
// swiftformat:disable all

import XCTest
import SwiftUI
import Prefire
{% for import in argument.imports %}
import {{ import }}
{% endfor %}
{% if argument.mainTarget %}
@testable import {{ argument.mainTarget }}
{% endif %}
{% for import in argument.testableImports %}
@testable import {{ import }}
{% endfor %}
import SnapshotTesting
{% set voiceOverStrategies argument.voiceOverSnapshots|split:"|" %}
{% if not argument.voiceOverSnapshots or ("image" in voiceOverStrategies) %}
#if canImport(AccessibilitySnapshot) && (os(iOS) || os(tvOS))
    import AccessibilitySnapshot
#endif
{% endif %}
{% if "text" in voiceOverStrategies %}
#if os(iOS)
    import PrefireVoiceOver
#endif
{% endif %}

@MainActor class {PREVIEW_FILE_NAME}Tests: XCTestCase {
    private let session = PrefireSnapshotSession(
        {% if argument.simulatorDevice %}
        simulatorDevice: "{{ argument.simulatorDevice }}",
        {% endif %}
        {% if argument.simulatorOSVersion %}
        osVersion: {{ argument.simulatorOSVersion }},
        {% endif %}
        {% if argument.snapshotDevices %}
        devices: {{ argument.snapshotDevices|split:"|" }},
        {% endif %}
        {% if argument.drawHierarchyInKeyWindowDefaultEnabled %}
        drawHierarchyInKeyWindow: {{ argument.drawHierarchyInKeyWindowDefaultEnabled }},
        {% endif %}
        {% if argument.fullPageSnapshots %}
        fullPage: true,
        {% endif %}
        waitDefaults: SnapshotWaitDefaults({% if argument.snapshotWaitForIdle %}waitForIdle: {{ argument.snapshotWaitForIdle }}{% if argument.snapshotWaitTimeout %}, {% endif %}{% endif %}{% if argument.snapshotWaitTimeout %}timeout: {{ argument.snapshotWaitTimeout }}{% endif %})
    )
    {% if argument.file %}

    private var file: StaticString { .init(stringLiteral: "{{ argument.file }}") }
    {% endif %}

    // MARK: - PreviewProvider

    {% for type in types.types where type.kind != "protocol" and (type.implements.PrefireProvider or type.based.PrefireProvider or type|annotated:"PrefireProvider") %}
    func test_{{ type.name|lowerFirstLetter|replace:"_Previews", ""|replace:".", "_" }}() {
        session.prepareEnvironment()

        assertSnapshots(of: {{ type.name }}._allPreviews)
    }
    {%- if not forloop.last %}

    {% endif %}
    {% endfor %}
    {% if argument.previewsMacrosDict %}

    // MARK: - Macros

    {% for macroModel in argument.previewsMacrosDict %}
{# Written once for both kinds of preview below, indented where it is used. #}
{% set snapshotAssertion %}assertSnapshots(for: PrefireSnapshot(
    {
        {% if macroModel.properties and not macroModel.hasArguments %}PreviewWrapper{{ macroModel.componentTestName }}(){% else %}{{ macroModel.body|indent:8 }}{% endif %}
    },
    name: "{{ macroModel.displayName }}{% if macroModel.hasArguments %}-\(previewArgumentIndex + 1)-\(String(describing: previewArgument)){% endif %}",
    isScreen: {% if macroModel.isScreen == 1 %}true{% else %}false{% endif %},
    device: session.device{% if macroModel.fixedLayoutSize %},
    fixedLayoutSize: {{ macroModel.fixedLayoutSize }}{% endif %}
)){% endset %}
    func test_{{ macroModel.componentTestName }}_Preview() {
        session.prepareEnvironment()

        {% if macroModel.hasArguments %}
        for (previewArgumentIndex, previewArgument) in ({{ macroModel.arguments }}).enumerated() {
            let {{ macroModel.argumentPattern }} = previewArgument

            {{ snapshotAssertion|indent:12 }}
        }
        {% else %}
        {% if macroModel.properties %}
        struct PreviewWrapper{{ macroModel.componentTestName }}: SwiftUI.View {
            {{ macroModel.properties }}
            var body: some View {
                {{ macroModel.body|indent:12 }}
            }
        }

        {% endif %}
        {{ snapshotAssertion|indent:8 }}
        {% endif %}
    }
    {%- if not forloop.last %}

    {% endif %}
    {% endfor %}
    {% endif %}

    // MARK: - SnapshotTesting

    private func assertSnapshots(of previews: [_Preview], testName: String = #function, filePath: StaticString = #filePath, line: UInt = #line) {
        for preview in previews {
            assertSnapshots(for: session.snapshot(of: preview, testName: testName), filePath: filePath, line: line)
        }
    }

    private func assertSnapshots<Content: SwiftUI.View>(for prefireSnapshot: PrefireSnapshot<Content>, filePath: StaticString = #filePath, line: UInt = #line) {
        for failure in session.failures(of: prefireSnapshot, verify: verify) {
            XCTFail(failure, file: filePath, line: line)
        }
    }

    private func verify(_ capture: PrefireSnapshotCapture) -> String? {
        let record: SnapshotTestingConfiguration.Record? = capture.record ? .all : nil
{% set reference %}record: record,{% if argument.file %} file: file,{% endif %}{% endset %}

        {% if not argument.voiceOverSnapshots or ("image" in voiceOverStrategies) %}
        #if canImport(AccessibilitySnapshot) && (os(iOS) || os(tvOS))
        SnapshotTesting.assertSnapshot(
            of: capture.accessibilityController(),
            as: .wait(for: capture.delay, on: .accessibilityImage(showActivationPoints: .always)),
            {{ reference }}
            testName: capture.name + ".accessibility"
        )
        #endif
        {% endif %}
        {% if "text" in voiceOverStrategies %}
        #if os(iOS)
        do {
            let transcript = try capture.voiceOverTranscript(timeout: session.waitDefaults.timeout)
            if let failure = verifySnapshot(
                of: transcript,
                as: .lines,
                {{ reference }}
                testName: capture.name + ".voiceover.text"
            ) {
                return failure
            }
        } catch {
            return "\(error)"
        }
        #endif
        {% endif %}

        switch capture.comparison {
        #if os(macOS)
        case let .view(size):
            return verifySnapshot(
                of: capture.view,
                as: .wait(
                    for: capture.delay,
                    on: .image(precision: capture.precision, perceptualPrecision: capture.perceptualPrecision, size: size)
                ),
                {{ reference }}
                testName: capture.name
            )
        #else
        case let .image(image):
            return verifySnapshot(
                of: image,
                as: .image(precision: capture.precision, perceptualPrecision: capture.perceptualPrecision, scale: capture.traits.displayScale),
                {{ reference }}
                testName: capture.name
            )
        case let .view(device):
            return verifySnapshot(
                of: capture.view,
                as: .wait(
                    for: capture.delay,
                    on: .image(
                        drawHierarchyInKeyWindow: session.drawHierarchyInKeyWindow,
                        precision: capture.precision,
                        perceptualPrecision: capture.perceptualPrecision,
                        layout: device.map { .device(config: ViewImageConfig(safeArea: $0.safeArea, size: $0.size, traits: $0.traits)) } ?? .sizeThatFits,
                        traits: capture.traits
                    )
                ),
                {{ reference }}
                testName: capture.name
            )
        #endif
        }
    }
}
"""#
}
