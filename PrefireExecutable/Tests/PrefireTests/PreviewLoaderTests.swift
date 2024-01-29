import Foundation
@testable import prefire
import XCTest

class PreviewLoaderTests: XCTestCase {
    func test_loadRawPreviewBodies() {
        #if swift(>=5.9)
        let target = "PrefireTests"
        let sources = ""
        let result = PreviewLoader.loadRawPreviewBodies(for: target, and: sources)?.first

        XCTAssertEqual(result?.trimmingCharacters(in: .whitespacesAndNewlines), previewRepresentation.trimmingCharacters(in: .whitespacesAndNewlines))
        #endif
    }
}

import SwiftUI

let previewRepresentation = "        DeveloperToolsSupport.Preview {\n            Text(\"TestView\")\n        }\n"

#if swift(>=5.9)
#Preview {
    Text("TestView")
}
#endif
