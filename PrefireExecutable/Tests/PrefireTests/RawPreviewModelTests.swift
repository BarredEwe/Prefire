import Foundation
@testable import prefire
import XCTest

class RawPreviewModelTests: XCTestCase {
    func test_initWithName() {
        #if swift(>=5.9)
        let previewBodyWithName = """
            DeveloperToolsSupport.Preview("TestViewName", traits: .sizeThatFitsLayout) {
                Text("TestView")
            }
        }
        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithName)

        XCTAssertEqual(rawPreviewModel.body, "        Text(\"TestView\")\n")
        XCTAssertEqual(rawPreviewModel.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel.traits, ".sizeThatFitsLayout")
        #endif
    }

    func test_initWithoutName() {
        #if swift(>=5.9)
        let previewBodyWithoutName = """
            DeveloperToolsSupport.Preview(traits: .sizeThatFitsLayout) {
                VStack {
                    Text("TestView")
                }
            }
        }
        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithoutName)

        XCTAssertEqual(rawPreviewModel.body, "        VStack {\n            Text(\"TestView\")\n        }\n")
        XCTAssertEqual(rawPreviewModel.displayName, "VStack")
        XCTAssertEqual(rawPreviewModel.traits, ".sizeThatFitsLayout")
        #endif
    }
}
