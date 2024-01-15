import Foundation
@testable import prefire
import XCTest

class PreviewLoaderTests: XCTestCase {

    func test_loadRawPreviewBodies() {
        let target = "PrefireTests"
        let sources = ""
        let result = PreviewLoader.loadRawPreviewBodies(for: target, and: sources)?.first

        XCTAssertEqual(result, previewRepresentation)
    }
}

import SwiftUI

let previewRepresentation = "        DeveloperToolsSupport.Preview {\n            Text(\"TestView\")\n        }\n"

#Preview {
    Text("TestView")
}
