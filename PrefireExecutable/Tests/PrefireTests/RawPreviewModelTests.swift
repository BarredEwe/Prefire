import Foundation
@testable import prefire
import XCTest

class RawPreviewModelTests: XCTestCase {
    func test_initWithName() {
        let previewBodyWithName = """
        #Preview("TestViewName", traits: .sizeThatFitsLayout) {
            Text("TestView")
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithName, filename: "Test")

        XCTAssertEqual(rawPreviewModel.body, "    Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel.traits, ".sizeThatFitsLayout")
    }

    func test_initWithoutName() {
        let previewBodyWithoutName = """
        #Preview(traits: .sizeThatFitsLayout) {
            VStack {
                Text("TestView")
            }
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithoutName, filename: "TestView")

        XCTAssertEqual(rawPreviewModel.body, "    VStack {\n        Text(\"TestView\")\n    }")
        XCTAssertEqual(rawPreviewModel.displayName, "TestView")
        XCTAssertEqual(rawPreviewModel.traits, ".sizeThatFitsLayout")
    }
}
