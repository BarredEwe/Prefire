import Foundation
@testable import prefire
import XCTest

class RawPreviewModelTests: XCTestCase {
    var previewBody = """
        DeveloperToolsSupport.Preview("TestViewName", traits: .sizeThatFitsLayout) {
            Text("TestView")
        }
    }
"""

    func test_init() {
        #if swift(>=5.9)
        let rawPreviewModel = RawPreviewModel(from: previewBody)

        XCTAssertEqual(rawPreviewModel.body, "            Text(\"TestView\")\n")
        XCTAssertEqual(rawPreviewModel.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel.traits, ".sizeThatFitsLayout")
        #endif
    }
}
