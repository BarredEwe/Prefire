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
#if canImport(AccessibilitySnapshot) && (os(iOS) || os(tvOS))
    import AccessibilitySnapshot
#endif

@MainActor class {PREVIEW_FILE_NAME}Tests: XCTestCase {
    private var simulatorDevice: String?{% if argument.simulatorDevice %} = "{{ argument.simulatorDevice|default:nil }}"{% endif %}
    private var requiredOSVersion: Int?{% if argument.simulatorOSVersion %} = {{ argument.simulatorOSVersion }}{% endif %}
    private let snapshotDevices: [String]{% if argument.snapshotDevices %} = {{ argument.snapshotDevices|split:"|" }}{% else %} = []{% endif %}
#if os(iOS)
    private let deviceConfig: DeviceConfig = ViewImageConfig.iPhoneX.deviceConfig
#elseif os(tvOS)
    private let deviceConfig: DeviceConfig = ViewImageConfig.tv.deviceConfig
#elseif os(macOS)
    private let deviceConfig = DeviceConfig()
#endif


    {% if argument.file %}

    private var file: StaticString { .init(stringLiteral: "{{ argument.file }}") }
    {% endif %}

    @MainActor override func setUp() async throws {
        try await super.setUp()

        prepareEnvironment()
    }

    // MARK: - PreviewProvider

    {% for type in types.types where type.implements.PrefireProvider or type.based.PrefireProvider or type|annotated:"PrefireProvider" %}
    func test_{{ type.name|lowerFirstLetter|replace:"_Previews", "" }}() {
        for preview in {{ type.name }}._allPreviews {
            let prefireSnapshot = PrefireSnapshot(preview, device: preview.device?.snapshotDeviceConfig() ?? deviceConfig)
            if let failure = assertSnapshots(for: prefireSnapshot) {
                XCTFail(failure)
            }
        }
    }
    {%- if not forloop.last %}

    {% endif %}
    {% endfor %}
    {% if argument.previewsMacrosDict %}
    // MARK: - Macros

    {% for macroModel in argument.previewsMacrosDict %}
    func test_{{ macroModel.componentTestName }}_Preview() {        
        {% if macroModel.hasArguments %}
        for (previewArgumentIndex, previewArgument) in ({{ macroModel.arguments }}).enumerated() {
            let {{ macroModel.argumentPattern }} = previewArgument

            let prefireSnapshot = PrefireSnapshot(
                {
                    {{ macroModel.body|indent:20 }}
                },
                name: "{{ macroModel.displayName }}-\(previewArgumentIndex + 1)-\(String(describing: previewArgument))",
                isScreen: {% if macroModel.isScreen == 1 %}true{% else %}false{% endif %},
                device: deviceConfig,
                fixedLayoutSize: {% if macroModel.fixedLayoutSize %}{{ macroModel.fixedLayoutSize }}{% else %}nil{% endif %}
            )

            if let failure = assertSnapshots(for: prefireSnapshot) {
                XCTFail(failure)
            }
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
        let prefireSnapshot = PrefireSnapshot(
            {
                {% if macroModel.properties %}
                PreviewWrapper{{ macroModel.componentTestName }}()
                {% else %}
                {{ macroModel.body|indent:12 }}
                {% endif %}
            },
            name: "{{ macroModel.displayName }}",
            isScreen: {% if macroModel.isScreen == 1 %}true{% else %}false{% endif %},
            device: deviceConfig,
            fixedLayoutSize: {% if macroModel.fixedLayoutSize %}{{ macroModel.fixedLayoutSize }}{% else %}nil{% endif %}
        )

        if let failure = assertSnapshots(for: prefireSnapshot) {
            XCTFail(failure)
        }
        {% endif %}
    }
    {%- if not forloop.last %}

    {% endif %}
    {% endfor %}
    {% endif %}
    // MARK: Private

    private func assertSnapshots<Content: SwiftUI.View>(for prefireSnapshot: PrefireSnapshot<Content>) -> String? {
        #if os(macOS)
        return assertSnapshot(for: prefireSnapshot)
        #else
        guard !snapshotDevices.isEmpty else {
            return assertSnapshot(for: prefireSnapshot)
        }

        for deviceName in snapshotDevices {
            var snapshot = prefireSnapshot
            guard let device: DeviceConfig = PreviewDevice(rawValue: deviceName).snapshotDevice() else {
                fatalError("Unknown device name from configuration file: \(deviceName)")
            }

            snapshot.name = "\(prefireSnapshot.name)-\(deviceName)"
            snapshot.device = device

            // Ignore specific device safe area
            snapshot.device.safeArea = .zero

            // Ignore specific device display scale
            snapshot.traits = UITraitCollection(displayScale: 2.0)

            if let failure = assertSnapshot(for: snapshot) {
                XCTFail(failure)
            }
        }

        return nil
        #endif
    }

    private func assertSnapshot<Content: SwiftUI.View>(for prefireSnapshot: PrefireSnapshot<Content>) -> String? {
        let (previewView, preferences) = prefireSnapshot.loadViewWithPreferences()

        #if os(macOS)
        let failure = verifySnapshot(
            of: previewView,
            as: .wait(
                for: preferences.delay,
                on: .image(
                    precision: preferences.precision,
                    perceptualPrecision: preferences.perceptualPrecision,
                    size: prefireSnapshot.device.size
                )
            ),
            record: preferences.record ? .all : .missing{% if argument.file %},
            file: file{% endif %},
            testName: prefireSnapshot.name
        )
        #else
        let failure = verifySnapshot(
            of: previewView,
            as: .wait(
                for: preferences.delay,
                on: .image(
                    {% if argument.drawHierarchyInKeyWindowDefaultEnabled %}
                    drawHierarchyInKeyWindow: {{ argument.drawHierarchyInKeyWindowDefaultEnabled }},
                    {% endif %}
                    precision: preferences.precision,
                    perceptualPrecision: preferences.perceptualPrecision,
                    layout: snapshotLayout(for: prefireSnapshot),
                    traits: prefireSnapshot.traits
                )
            ),
            record: preferences.record ? .all : .missing{% if argument.file %},
            file: file{% endif %},
            testName: prefireSnapshot.name
        )
        #endif

        #if canImport(AccessibilitySnapshot) && (os(iOS) || os(tvOS))
            let vc = UIHostingController(rootView: previewView)
            vc.view.frame = UIScreen.main.bounds

            SnapshotTesting.assertSnapshot(
                matching: vc,
                as: .wait(for: preferences.delay, on: .accessibilityImage(showActivationPoints: .always)){% if argument.file %},
                record: preferences.record ? .all : .missing,
                file: file{% endif %},
                testName: prefireSnapshot.name + ".accessibility"
            )
        #endif
        return failure
    }

    private func prepareEnvironment() {
        #if os(iOS) || os(tvOS)
        if let simulatorDevice, let deviceModel = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            guard deviceModel.contains(simulatorDevice) else {
                fatalError("Switch to using \(simulatorDevice) for these tests. (You are using \(deviceModel))")
            }
        }

        if let requiredOSVersion {
            let osVersion = ProcessInfo().operatingSystemVersion
            guard osVersion.majorVersion == requiredOSVersion else {
                fatalError("Switch to iOS \(requiredOSVersion) for these tests. (You are using \(osVersion))")
            }
        }

        UIView.setAnimationsEnabled(false)
        #endif
    }
}

// MARK: - SnapshotTesting + Extensions

#if os(iOS) || os(tvOS)
private func snapshotLayout<Content: SwiftUI.View>(for prefireSnapshot: PrefireSnapshot<Content>) -> SwiftUISnapshotLayout {
    if prefireSnapshot.isScreen {
        return .device(config: prefireSnapshot.device.imageConfig)
    }
    if let size = prefireSnapshot.device.size {
        return .fixed(width: size.width, height: size.height)
    }
    return .sizeThatFits
}

private extension DeviceConfig {
    var imageConfig: ViewImageConfig { ViewImageConfig(safeArea: safeArea, size: size, traits: traits) }
}

private extension ViewImageConfig {
    var deviceConfig: DeviceConfig { DeviceConfig(safeArea: safeArea, size: size, traits: traits) }
}

private extension PreviewDevice {
    func snapshotDevice() -> ViewImageConfig? {
        switch rawValue {
        #if os(iOS)
        case "iPhone 16 Pro Max", "iPhone 15 Pro Max", "iPhone 14 Pro Max", "iPhone 13 Pro Max", "iPhone 12 Pro Max":
            return .iPhone13ProMax
        case "iPhone 16 Pro", "iPhone 15 Pro", "iPhone 14 Pro", "iPhone 13 Pro", "iPhone 12 Pro":
            return .iPhone13Pro
        case "iPhone 16", "iPhone 15", "iPhone 14", "iPhone 13", "iPhone 12", "iPhone 11", "iPhone 10", "iPhone X":
            return .iPhoneX
        case "iPhone 6", "iPhone 6s", "iPhone 7", "iPhone 8", "iPhone SE (2nd generation)", "iPhone SE (3rd generation)":
            return .iPhone8
        case "iPhone 6 Plus", "iPhone 6s Plus", "iPhone 8 Plus":
            return .iPhone8Plus
        case "iPhone SE (1st generation)":
            return .iPhoneSe
        case "iPad":
            return .iPad10_2
        case "iPad Mini":
            return .iPadMini
        case "iPad Pro 11":
            return .iPadPro11
        case "iPad Pro 12.9":
            return .iPadPro12_9
        #elseif os(tvOS)
        case "Apple TV":
            return .tv
        #endif
        default: return nil
        }
    }

    func snapshotDeviceConfig() -> DeviceConfig? {
        snapshotDevice()?.deviceConfig
    }
}
#endif

#if os(macOS)
private extension PreviewDevice {
    func snapshotDeviceConfig() -> DeviceConfig? { nil }
}
#endif
"""#
}
