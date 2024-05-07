import Foundation
@testable import prefire
import XCTest

class PreviewLoaderTests: XCTestCase {
    var previewRepresentations = [
        "#Preview {\n    Text(\"TestView\")\n}\n",
        "#Preview {\n    Text(\"TestView_Prefire\")\n        .prefireEnabled()\n}\n"
    ]

    let source = #file

    func test_loadRawPreviewBodiesDefaultEnable() {
        #if swift(>=5.9)
        let bodies = PreviewLoader.loadRawPreviewBodies(for: [source], defaultEnabled: true)

        XCTAssertEqual(bodies?.count, 2)
        XCTAssertEqual(bodies?[0], previewRepresentations[0])
        XCTAssertEqual(bodies?[1], previewRepresentations[1])
        #endif
    }

    func test_loadRawPreviewBodiesDefaultDisabled() {
        #if swift(>=5.9)
        let bodies = PreviewLoader.loadRawPreviewBodies(for: [source], defaultEnabled: false)

        XCTAssertEqual(bodies?.count, 1)
        XCTAssertEqual(bodies?[0], previewRepresentations[1])
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
