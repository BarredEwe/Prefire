import Foundation
@testable import prefire
import XCTest

class PreviewLoaderTests: XCTestCase {
    var previewRepresentations = [
        "        DeveloperToolsSupport.Preview {\n            Text(\"TestView\")\n        }\n",
        "        DeveloperToolsSupport.Preview {\n            Text(\"TestView_Prefire\")\n                .prefireEnabled()\n        }\n"
    ]

    var previewText = ["TestView", "TestView_Prefire", "TestView_Ignored"].map({ "\"" + $0 + "\"" })
    let source = #file

    func test_loadRawPreviewBodiesDefaultEnable() {
        #if swift(>=5.9)
        let target = "PrefireTests"
        let sources = [source]

        let bodies = PreviewLoader.loadRawPreviewBodies(for: target, and: sources, defaultEnabled: true)?
            .filter { $0.contains(previewText[0]) || $0.contains(previewText[1]) || $0.contains(previewText[2]) }

        XCTAssertEqual(bodies?.count, 2)
        XCTAssertEqual(bodies?[0].trimmingCharacters(in: .whitespacesAndNewlines), previewRepresentations[0].trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertEqual(bodies?[1].trimmingCharacters(in: .whitespacesAndNewlines), previewRepresentations[1].trimmingCharacters(in: .whitespacesAndNewlines))
        #endif
    }

    func test_loadRawPreviewBodiesDefaultDisabled() {
        #if swift(>=5.9)
        let target = "PrefireTests"
        let sources = [source]

        let bodies = PreviewLoader.loadRawPreviewBodies(for: target, and: sources, defaultEnabled: false)?
            .filter { $0.contains(previewText[0]) || $0.contains(previewText[1]) || $0.contains(previewText[2]) }

        XCTAssertEqual(bodies?.count, 1)
        XCTAssertEqual(bodies?[0].trimmingCharacters(in: .whitespacesAndNewlines), previewRepresentations[1].trimmingCharacters(in: .whitespacesAndNewlines))
        #endif
    }
}

import SwiftUI

#if swift(>=5.9)
#Preview {
    Text("TestView")
}

#Preview {
    Text("TestView_Prefire")
        .prefireEnabled()
}

#Preview {
    Text("TestView_Ignored")
        .prefireIgnored()
}
#endif

extension View {
    func prefireEnabled() -> some View {
        self
    }

    func prefireIgnored() -> some View {
        self
    }
}
