import Foundation
@testable import prefire
import XCTest

class ConfigDecoderTests: XCTestCase {
    private let prefireConfigString = """
        test_configuration:
          - target: PrefireExample
          - test_target_path: ${TARGET_DIR}/MyTests
          - test_file_path: ${TARGET_DIR}/PrefireExampleTests/PreviewTests.generated.swift
          - template_file_path: CustomPreviewTests.stencil
          - simulator_device: "iPhone15,2"
          - required_os: 17
          - snapshot_devices:
              - iPhone 15
              - iPad
          - preview_default_enabled: true
          - imports:
              - UIKit
              - SwiftUI
          - testable_imports:
              - Prefire
          - draw_hierarchy_in_key_window_default_enabled: true
          - full_page_snapshots: true
        playbook_configuration:
          - template_file_path: CustomModels.stencil
          - imports:
              - UIKit
              - Foundation
          - testable_imports:
              - SwiftUI
          - preview_default_enabled: false
    """
    
    private let prefireConfigStringWithWhiteSpaces = """
        test_configuration: 
          - target: PrefireExample   
          - test_target_path: ${TARGET_DIR}/MyTests   
          - test_file_path: ${TARGET_DIR}/PrefireExampleTests/PreviewTests.generated.swift 
          - template_file_path: CustomPreviewTests.stencil 
          - simulator_device: "iPhone15,2" 
          - required_os: 17 
          - snapshot_devices:  
              - iPhone 15   
              - iPad 
          - preview_default_enabled: true 
          - imports: 
              - UIKit 
              - SwiftUI 
          - testable_imports: 
              - Prefire 
          - draw_hierarchy_in_key_window_default_enabled: true 
        playbook_configuration: 
          - template_file_path: CustomModels.stencil 
          - imports: 
              - UIKit 
              - Foundation  
          - testable_imports: 
              - SwiftUI 
          - preview_default_enabled: false 
    """

    private let env = ["TARGET_DIR":"/User/Tests"]

    func test_successDecodeConfig() {
        let config = ConfigDecoder().decode(from: prefireConfigString, env: env)

        XCTAssertEqual(config.tests.target, "PrefireExample")
        XCTAssertEqual(config.tests.testTargetPath, "/User/Tests/MyTests")
        XCTAssertEqual(config.tests.testFilePath, "/User/Tests/PrefireExampleTests/PreviewTests.generated.swift")
        XCTAssertEqual(config.tests.template, "CustomPreviewTests.stencil")
        XCTAssertEqual(config.tests.device, "iPhone15,2")
        XCTAssertEqual(config.tests.osVersion, "17")
        XCTAssertEqual(config.tests.snapshotDevices, ["iPhone 15", "iPad"])
        XCTAssertEqual(config.tests.previewDefaultEnabled, true)
        XCTAssertEqual(config.tests.imports, ["UIKit", "SwiftUI"])
        XCTAssertEqual(config.tests.testableImports, ["Prefire"])
        XCTAssertEqual(config.tests.drawHierarchyInKeyWindowDefaultEnabled, true)
        XCTAssertEqual(config.tests.fullPageSnapshots, true)
        XCTAssertEqual(config.playbook.imports, ["UIKit", "Foundation"])
        XCTAssertEqual(config.playbook.testableImports, ["SwiftUI"])
        XCTAssertEqual(config.playbook.template, "CustomModels.stencil")
        XCTAssertEqual(config.playbook.previewDefaultEnabled, false)
    }
    
    func test_successDecodeConfig_with_whiteSpaces() {
        let config = ConfigDecoder().decode(from: prefireConfigStringWithWhiteSpaces, env: env)

        XCTAssertEqual(config.tests.target, "PrefireExample")
        XCTAssertEqual(config.tests.testTargetPath, "/User/Tests/MyTests")
        XCTAssertEqual(config.tests.testFilePath, "/User/Tests/PrefireExampleTests/PreviewTests.generated.swift")
        XCTAssertEqual(config.tests.template, "CustomPreviewTests.stencil")
        XCTAssertEqual(config.tests.device, "iPhone15,2")
        XCTAssertEqual(config.tests.osVersion, "17")
        XCTAssertEqual(config.tests.snapshotDevices, ["iPhone 15", "iPad"])
        XCTAssertEqual(config.tests.previewDefaultEnabled, true)
        XCTAssertEqual(config.tests.imports, ["UIKit", "SwiftUI"])
        XCTAssertEqual(config.tests.testableImports, ["Prefire"])
        XCTAssertEqual(config.tests.drawHierarchyInKeyWindowDefaultEnabled, true)
        XCTAssertEqual(config.playbook.imports, ["UIKit", "Foundation"])
        XCTAssertEqual(config.playbook.testableImports, ["SwiftUI"])
        XCTAssertEqual(config.playbook.template, "CustomModels.stencil")
        XCTAssertEqual(config.playbook.previewDefaultEnabled, false)
    }

    func test_decodeConfig_replacesEveryEnvKeyInValue() {
        let configString = """
        test_configuration:
          - test_target_path: "${PROJECT_DIR}/${MODULE}/Tests"
          - sources:
            - ${PROJECT_DIR}/${MODULE}/Sources
        """
        let env = ["PROJECT_DIR": "/User/Project", "MODULE": "Feature"]

        let config = ConfigDecoder().decode(from: configString, env: env)

        XCTAssertEqual(config.tests.testTargetPath, "/User/Project/Feature/Tests")
        XCTAssertEqual(config.tests.sources, ["/User/Project/Feature/Sources"])
    }

    func test_decodeConfig_keepsUnknownKeysAndTargetPlaceholders() {
        let configString = """
        test_configuration:
          - test_target_path: "${PROJECT_DIR}/${UNKNOWN}/${TARGET}/${TEST_TARGET}"
        """
        let env = ["PROJECT_DIR": "/User/Project", "TARGET": "EnvTarget", "TEST_TARGET": "EnvTestTarget"]

        let config = ConfigDecoder().decode(from: configString, env: env)

        XCTAssertEqual(config.tests.testTargetPath, "/User/Project/${UNKNOWN}/${TARGET}/${TEST_TARGET}")
    }
}
