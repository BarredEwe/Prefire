import Foundation
@testable import prefire
import XCTest

class RawPreviewModelTests: XCTestCase {
    func test_initWithName() {
        #if swift(>=5.9)
        let previewBodyWithName = """
        #Preview("TestViewName", traits: .sizeThatFitsLayout) {
            Text("TestView")
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithName, filename: "Test")

        XCTAssertEqual(rawPreviewModel.body, "    Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel.traits, ".sizeThatFitsLayout")
        #endif
    }

    func test_initWithoutName() {
        #if swift(>=5.9)
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
        #endif
    }
}
