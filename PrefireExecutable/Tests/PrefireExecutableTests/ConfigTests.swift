import Foundation
@testable import PrefireExecutable
import XCTest

class ConfigTests: XCTestCase {
    private let prefireConfigString = """
        test_configuration:
          - target: PrefireExample
          - test_file_path: PrefireExampleTests/PreviewTests.generated.swift
          - template_file_path: CustomPreviewTests.stencil
          - simulator_device: "iPhone15,2"
          - required_os: 17
        playbook_configuration:
          - imports:
              - UIKit
              - Foundation
          - testable_imports:
              - SwiftUI
    """

    func test_successCreateConfig() {
        let config = Config.from(configDataString: prefireConfigString, verbose: false)

        XCTAssertEqual(config?.target, "PrefireExample")
        XCTAssertEqual(config?.testFilePath, "PrefireExampleTests/PreviewTests.generated.swift")
        XCTAssertEqual(config?.template, "CustomPreviewTests.stencil")
        XCTAssertEqual(config?.device, "iPhone15,2")
        XCTAssertEqual(config?.osVersion, "17")
        XCTAssertEqual(config?.imports, ["UIKit", "Foundation"])
        XCTAssertEqual(config?.testableImports, ["SwiftUI"])
    }
}
