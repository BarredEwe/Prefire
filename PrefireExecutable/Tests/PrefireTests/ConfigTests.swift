import Foundation
@testable import prefire
import XCTest

class ConfigTests: XCTestCase {
    private let prefireConfigString = """
        test_configuration:
          - target: PrefireExample
          - test_file_path: PrefireExampleTests/PreviewTests.generated.swift
          - template_file_path: CustomPreviewTests.stencil
          - simulator_device: "iPhone15,2"
          - required_os: 17
          - preview_default_enabled: true
          - imports:
              - UIKit
              - SwiftUI
          - testable_imports:
              - Prefire
        playbook_configuration:
          - imports:
              - UIKit
              - Foundation
          - testable_imports:
              - SwiftUI
    """

    func test_successCreateConfig() {
        let config = Config(from: prefireConfigString)

        XCTAssertEqual(config?.tests.target, "PrefireExample")
        XCTAssertEqual(config?.tests.testFilePath, "PrefireExampleTests/PreviewTests.generated.swift")
        XCTAssertEqual(config?.tests.template, "CustomPreviewTests.stencil")
        XCTAssertEqual(config?.tests.device, "iPhone15,2")
        XCTAssertEqual(config?.tests.osVersion, "17")
        XCTAssertEqual(config?.tests.previewDefaultEnabled, true)
        XCTAssertEqual(config?.tests.imports, ["UIKit", "SwiftUI"])
        XCTAssertEqual(config?.tests.testableImports, ["Prefire"])
        XCTAssertEqual(config?.playbook.imports, ["UIKit", "Foundation"])
        XCTAssertEqual(config?.playbook.testableImports, ["SwiftUI"])
    }
}
