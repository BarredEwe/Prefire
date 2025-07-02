import Foundation
@testable import PrefireCore
import XCTest

class RawPreviewModelTests: XCTestCase {
    func test_initWithName() {
        let previewBodyWithName = """
        #Preview("TestViewName", traits: .sizeThatFitsLayout) {
            Text("TestView")
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithName, filename: "Test")

        XCTAssertEqual(rawPreviewModel?.body, "    Text(\"TestView\")")
        XCTAssertEqual(rawPreviewModel?.properties, nil)
        XCTAssertEqual(rawPreviewModel?.displayName, "TestViewName")
        XCTAssertEqual(rawPreviewModel?.traits, ".sizeThatFitsLayout")
    }

    func test_initWithoutName() {
        let previewBodyWithoutName = """
        #Preview(traits: .sizeThatFitsLayout) {
            @Previewable @State var name: String = "TestView"

            VStack {
                Text(name)
            }
            .snapshot(delay: 8)
        }

        """
        let rawPreviewModel = RawPreviewModel(from: previewBodyWithoutName, filename: "TestView")
        
        XCTAssertEqual(rawPreviewModel?.body, "\n    VStack {\n        Text(name)\n    }\n    .snapshot(delay: 8)")
        XCTAssertEqual(rawPreviewModel?.properties, "    @State var name: String = \"TestView\"")
        XCTAssertEqual(rawPreviewModel?.displayName, "TestView")
        XCTAssertEqual(rawPreviewModel?.traits, ".sizeThatFitsLayout")
    }
}
